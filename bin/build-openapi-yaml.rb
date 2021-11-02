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
  opts.banner = "Usage: check-apis-against-client-json.rb [options]"

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

def process_file(fn, schemas, options)
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

files = []
schemas = {}
components = {}
spec = {}
spec["components"] = components

if options[:file]
  files = Dir.glob(options[:sourcedir]+"/main/domain/*"+options[:file]+"*")
else
  files = Dir.glob(options[:sourcedir]+"/main/domain/*")
end

if options[:verbose] 
  puts "Checking files: "
  puts files
end


files.each do |fn|
  process_file(fn, schemas, options)
end

components["schemas"] = schemas

puts %Q(
openapi: "3.0.0"
info:
  version: 1.0.0
  title: Swagger Petstore
  license:
    name: MIT
servers:
  - url: http://petstore.swagger.io/v1
paths:
  /pets:
    get:
      summary: List all pets
      responses:
        '200':
          description: A paged array of pets
          content:
            application/json:   
              schema:
                $ref: "#/components/schemas/UserAction"
)

# https://stackoverflow.com/questions/21251309/how-to-remove-on-top-of-a-yaml-file

puts spec.to_yaml.gsub(/^---/,'')

