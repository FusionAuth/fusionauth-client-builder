#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'optparse'
require 'yaml'

# option handling
options = {}

# default options
options[:sourcedir] = "../src/"

OptionParser.new do |opts|
  opts.banner = "Usage: build-openapi-yaml.rb [options]"

  opts.on("-v", "--verbose", "Run verbosely.") do |v|
    options[:verbose] = v
  end

  opts.on("-d", "--source-directory", "Source directory.") do |v|
    options[:sourcedir] = v
  end

  opts.on("-f", "--file FILE", "Run for one file.") do |file|
    options[:file] = file
  end

  opts.on("-o", "--out FILE", "Ouput file.") do |outfile|
    options[:outfile] = outfile
  end

  opts.on("-h", "--help", "Prints this help.") do
    puts opts
    exit
  end
end.parse!

def is_primitive(type)
  return type == "boolean" || type == "String" || type == "UUID" || type == "Object"
end

def convert_primitive(type)
  if type == "boolean"
    return {"type" => "boolean"}
  end
  if type == "Object"
    return {"type" => "object"}
  end

  if type == "UUID"
    return {"type" => "string", "format" => "uuid"}
  end

  if type == "String"
    return {"type" => "string"}
  end

  if type == "integer"
    return {"type" => "integer"}
  end
end

def make_ref(type)
  return "'#/components/schemas/"+type+"'"
end

def process_domain_file(fn, schemas, options)
  if options[:verbose] 
    puts "processing "+fn
  end

  f = File.open(fn)
  fs = f.read
  json = JSON.parse(fs)
  f.close

  openapiobj = {}
  if json["description"]
    openapiobj["description"] = json["description"].gsub('/','').gsub(/@au.*/,'').gsub('*','').gsub(/\n/,'').gsub("\n",'').delete("\n").strip
  end
  openapiobj["type"] = "object"


  # TODO handle undefined types like UUID
  # TODO What about ENUMS in an existing data model with fields?
  # TODO authentication schemes
  # TODO handle extends, jam all fields on super classes onto object
  if json["enum"] 
    openapiobj["type"] = "string"
    openapiobj["enum"] = json["enum"]
  end


  if json["fields"]
    properties = {}
    openapiobj["properties"] = properties
    json["fields"] && json["fields"].each do |k,v|
      properties[k] = {}
      v.each do |k2,v2|
        if k2 == "type" 
          if is_primitive(v2)
            properties[k] = convert_primitive(v2)
          elsif v2 == "List"
            properties[k][k2] = "array"
            properties[k]["items"] = {}
            listElementType = json["fields"][k]["typeArguments"][0]["type"]
            if is_primitive(listElementType)
              properties[k]["items"] = convert_primitive(listElementType)
            else
              properties[k]["items"]['$ref'] = make_ref(listElementType)
            end
          elsif v2 == "Map"
            properties[k][k2] = "object"
            properties[k]["additionalProperties"] = {}
            mapElementType = json["fields"][k]["typeArguments"][1]["type"]
            if is_primitive(mapElementType)
              properties[k]["additionalProperties"] = convert_primitive(mapElementType)
            else
              properties[k]["additionalProperties"]['$ref'] = make_ref(mapElementType)
            end
          else
            # omit type, put in ref
            properties[k]['$ref'] = make_ref(v2)
          end
        end
      end
    end
  end

  schemas[json["type"]] = openapiobj 

end

def process_api_file(fn, paths, options)
  if options[:verbose] 
    puts "processing "+fn
  end
  f = File.open(fn)
  fs = f.read
  json = JSON.parse(fs)
  f.close

  uri = json["uri"]

  # check to see if the url segments are optional
  # TODO need to handle all url segments, including constant ones
  if json["params"]
    segmentparams = json["params"].select{|p| p["type"] == "urlSegment"}
    segmentparams.each do |p|
      optional_param = false
      if p["comments"] && p["comments"][0].include?("(Optional)") 
        optional_param = true
      end
      if optional_param
        # builds optional param path, no need to add segments
        addsegmentparams = false
        build_path(uri, json, paths, addsegmentparams, options)
        if options[:verbose] 
          puts "adding optional path for " + uri
        end
      end

      uri = uri + "/{"+p["name"]+"}"
      addsegmentparams = true
      build_path(uri, json, paths, addsegmentparams, options)
      if options[:verbose] 
        puts "adding path for " + uri
      end
    end
  end

end
 
def build_path(uri, json, paths, addsegmentparams, options)

  method = json["method"]
  desc = json["comments"].join(" ").delete("\n").strip
  operationId = json["methodName"]
  jsonparams = json["params"]

  if not paths[uri] 
    paths[uri] = {}
  end

  openapiobj = {}
  paths[uri][method] = openapiobj

  openapiobj["description"] = desc
  openapiobj["operationId"] = operationId

  # TODO should we handle type form, notUsed? that is used for oauth token exchange
  # TODO need to handle body params
  
  if jsonparams
    params = []
    openapiobj["parameters"] = params
    segmentparams = jsonparams.select{|p| p["type"] == "urlSegment"}
    queryparams = jsonparams.select{|p| p["type"] == "urlParameter"}
    bodyparams = jsonparams.select{|p| p["type"] == "body"}
  
    queryparams.each do |p|
      paramobj = {}
      paramobj["name"] = p["name"]
      paramobj["in"] = "query"
      if p["comments"] && p["comments"][0]
        paramobj["description"] = p["comments"].join(" ").gsub('(Optional)','').gsub("\n",'').delete("\n").strip
      end
      params << paramobj
    end

    if addsegmentparams
      segmentparams.each do |p|
        if p["constant"] == true
          next
        end
        paramobj = {}
        paramobj["name"] = p["name"]
        paramobj["in"] = "path"
        # TODO need to handle case where it is missing
        paramobj["required"] = true
        if p["comments"] && p["comments"][0]
          paramobj["description"] = p["comments"].join(" ").gsub('(Optional)','').gsub("\n",'').delete("\n").strip
        end
        params << paramobj
      end
    end
  end

  openapiobj["responses"] = {}
  openapiobj["responses"]['200'] = {}
  build_nested_content_response(openapiobj["responses"]['200'], make_ref(json["successResponse"]))

  openapiobj["responses"]['default'] = {}
  build_nested_content_response(openapiobj["responses"]['default'], make_ref(json["errorResponse"]))

end

def build_nested_content_response(hash, ref)
  hash["content"] = {}
  hash["content"]["application/json"] = {}
  hash["content"]["application/json"]["schema"] = {}
  hash["content"]["application/json"]["schema"]['$ref'] = ref
end

domain_files = []
schemas = {}
components = {}
paths = {}
spec = {}
spec["paths"] = paths
spec["components"] = components

domain_files = Dir.glob(options[:sourcedir]+"/main/domain/*")

if options[:file]
  api_files = Dir.glob(options[:sourcedir]+"/main/api/*"+options[:file]+"*")
else
  api_files = Dir.glob(options[:sourcedir]+"/main/api/*")
end

if options[:verbose] 
  puts "Processing files: "
  puts domain_files
  puts api_files
end

domain_files.each do |fn|
  process_domain_file(fn, schemas, options)
end
components["schemas"] = schemas

api_files.each do |fn|
  process_api_file(fn, paths, options)
end

puts %Q(
openapi: "3.1.0"
info:
  version: 1.0.0
  title: FusionAuth API
  license:
    name: Apache2
servers:
  - url: http://localhost:9011
)

# https://stackoverflow.com/questions/21251309/how-to-remove-on-top-of-a-yaml-file

puts spec.to_yaml.gsub(/^---/,'')

