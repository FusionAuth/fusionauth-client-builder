#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'optparse'
require 'yaml'

#TODO status codes



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
  ["boolean", "String", "UUID", "Object", "int", "integer", "Set", "URI", "SortedSet", "long", "double", "char", "Array"].include? type
end

def convert_primitive(type)
  if type == "boolean"
    return {"type" => "boolean"}
  end

  if type == "Array"
    return {"type" => "string", "format" => "binary"}
  end

  if type == "URI"
    return {"type" => "string", "format" => "URI"} # TODO not sure if that is correct?
  end
  if type == "Object"
    return {"type" => "object"}
  end
  if type == "Set" || type == "SortedSet"
    return {"type" => "array", "uniqueItems" => true, "items" => {}}
  end

  if type == "UUID"
    return {"type" => "string", "format" => "uuid"}
  end

  if type == "String" || type == "char"
    return {"type" => "string"}
  end

  if type == "integer" || type == "int"
    return {"type" => "integer"}
  end

  if type == "long"
    return {"type" => "integer", "format" => "int64"}
  end

  if type == "double"
    return {"type" => "number", "format" => "double"}
  end
end

def make_ref(type)
  if type == "Void"
    return nil
  end
  return '#/components/schemas/'+type
end

def process_domain_file(fn, schemas, options)
  if options[:verbose] 
    puts "processing "+fn
  end

  f = File.open(fn)
  fs = f.read
  json = JSON.parse(fs)
  f.close

  objectname = json["type"]
  openapiobj = {}
  if json["description"]
    openapiobj["description"] = json["description"].gsub('/','').gsub(/@au.*/,'').gsub('*','').gsub(/\n/,'').gsub("\n",'').delete("\n").strip
  end
  openapiobj["type"] = "object"


  # TODO What about ENUMS in an existing data model with fields?
  # TODO authentication schemes
  if json["enum"] 
    openapiobj["type"] = "string"
    openapiobj["enum"] = json["enum"]
  end

  extends = json["extends"]
  fields = json["fields"]

  # if we extend a class, we need to add those fields to our existing fields
  extends && extends.length > 0 && extends.each do |ex|
    unless fields && fields.length > 0
      fields = {}
    end
    if ["HashMap", "TreeMap", "LinkedHashMap"].include? ex["type"]
      # these are java builtins classes TODO unsure if this will cause issues
      next
    end
    # only happens for domain classes
    files = Dir.glob(options[:sourcedir]+"/main/domain/io.fusionauth.domain.*"+ex["type"]+".json")
    file = files[0]
    ef = File.open(file)
    efs = ef.read
    ejson = JSON.parse(efs)
    fields = fields.merge(ejson["fields"])
  end

  if fields
    properties = {}
    openapiobj["properties"] = properties
    fields.each do |k,v|
      properties[k] = {}
      v.each do |k2,v2|
        if k2 == "type" 
          if is_primitive(v2)
            properties[k] = convert_primitive(v2)
          elsif v2 == "List"
            listElementType = fields[k]["typeArguments"][0]["type"]
            addListValue(properties[k],k2,listElementType, k, objectname)
            
          elsif v2 == "Map"
            properties[k][k2] = "object"
            properties[k]["additionalProperties"] = {}
            # could make recursive, but how deep do we need to go

            # keytype is always going to be a string? # TODO check on this

            mapKeyType = fields[k]["typeArguments"][0]["type"]
            mapValueType = fields[k]["typeArguments"][1]["type"]
            if is_primitive(mapValueType)
              properties[k]["additionalProperties"] = convert_primitive(mapValueType)
            elsif mapValueType == "List"
              listElementType = fields[k]["typeArguments"][1]["typeArguments"][0]["type"]
              addListValue(properties[k],k2,listElementType)
            elsif mapValueType == "D" && k == "applicationConfiguration" && objectname.match(/IdentityProvider$/) 
              if objectname.match(/BaseIdentityProvider$/)
                # remove this one, we don't need to provide anything for the BaseIdentityProvider application config.properties, I think
                properties.delete(k)
              else
                identityproviderconfigrefname = objectname.sub("IdentityProvider","") + "ApplicationConfiguration"
                properties[k]["additionalProperties"]['$ref'] = make_ref(identityproviderconfigrefname)
              end
            else
              properties[k]["additionalProperties"]['$ref'] = make_ref(mapValueType)
            end
          else
            # omit type, put in ref
            properties[k]['$ref'] = make_ref(v2)
          end
        end
      end
    end
  end

  schemas[objectname] = openapiobj 

end

def addListValue(hash,key,listElementType,rootkey=nil,objectname=nil)
  hash[key] = "array"
  hash["items"] = {}
  if is_primitive(listElementType)
    hash["items"] = convert_primitive(listElementType)
  elsif listElementType == "T" && rootkey == "results" && objectname == "SearchResults"
    # TODO not sure this works
    hash["items"] = {"type" => "object"}
  else
    hash["items"]['$ref'] = make_ref(listElementType)
  end
end

def param_optional(comments_arr)
  if comments_arr && comments_arr[0].include?("(Optional)") 
    return true
  end
  return false
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
  if json["params"]
    uri_without_optional = uri
    segmentparams = json["params"].select{|p| p["type"] == "urlSegment"}
    segmentparams.each do |p|
      if p["constant"] == true
        uri = uri + "/"+p["value"].delete('"')
        uri_without_optional = uri_without_optional + "/"+p["value"].delete('"')
        next
      end
      
      if param_optional(p["comments"]) 
        uri = uri + "/{"+p["name"]+"}"
      else
        uri = uri + "/{"+p["name"]+"}"
        uri_without_optional = uri_without_optional + "/{"+p["name"]+"}"
      end

    end

    if options[:verbose] 
      puts "adding path for " + uri
    end
    # builds for full uri
    build_path(uri, json, paths, true, options)

    # only support an optional parameter on the last url segment
    if uri_without_optional != uri
      if options[:verbose] 
        puts "adding path for " + uri_without_optional
      end
      build_path(uri_without_optional, json, paths, false, options)
    end 
  end

end

def build_path(uri, json, paths, include_optional_segement_param, options)

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
  
  if jsonparams
    params = []
    openapiobj["parameters"] = params
    segmentparams = jsonparams.select{|p| p["type"] == "urlSegment"}
    queryparams = jsonparams.select{|p| p["type"] == "urlParameter"}
    bodyparams = jsonparams.select{|p| p["type"] == "body"}
  
    queryparams.each do |p|
      params << build_openapi_paramobj(p, "query")
    end

    segmentparams.each do |p|
      if p["constant"] == true
        next
      end

      if param_optional(p["comments"])
        if include_optional_segement_param
          # we have an optional param but it is in the URI, so we want to add it to the parameters
          params << build_openapi_paramobj(p, "path")
        end
      else
        params << build_openapi_paramobj(p, "path")
      end
    end

    if bodyparams && bodyparams.length > 0
      openapiobj["requestBody"] = {}
      openapiobj["requestBody"]["content"] = {}
      openapiobj["requestBody"]["content"]["application/json"] = {}
      openapiobj["requestBody"]["content"]["application/json"]["schema"] = {}
      openapiobj["requestBody"]["content"]["application/json"]["schema"]["$ref"] = make_ref(bodyparams[0]["javaType"])
    end
  end

  openapiobj["responses"] = {}
  openapiobj["responses"]['200'] = {}
  build_nested_content_response(openapiobj["responses"]['200'], make_ref(json["successResponse"]), "Success")

  openapiobj["responses"]['default'] = {}
  build_nested_content_response(openapiobj["responses"]['default'], make_ref(json["errorResponse"]), "Error")

end

def build_openapi_paramobj(jsonparamobj, paramtype)
  paramobj = {}
  paramobj["name"] = jsonparamobj["name"]
  paramobj["in"] = paramtype
  paramobj["schema"] = {}
  paramobj["schema"]["type"] = "string"
  
  if paramtype == "path"
    paramobj["required"] = true
  end
  if jsonparamobj["comments"] && jsonparamobj["comments"][0]
    paramobj["description"] = jsonparamobj["comments"].join(" ").gsub('(Optional)','').gsub("\n",'').delete("\n").strip
  end
  return paramobj
end

def build_nested_content_response(hash, ref, description)
  hash["description"] = description
  
  if ref
    hash["content"] = {}
    hash["content"]["application/json"] = {}
    hash["content"]["application/json"]["schema"] = {}
    hash["content"]["application/json"]["schema"]['$ref'] = ref
  end
end

domain_files = []
api_files = []
schemas = {}
components = {}
paths = {}
spec = {}
spec["paths"] = paths
spec["components"] = components


if options[:file]
  api_files = Dir.glob(options[:sourcedir]+"/main/api/*"+options[:file]+"*")
  domain_files = Dir.glob(options[:sourcedir]+"/main/domain/*"+options[:file]+".json")
else
  api_files = Dir.glob(options[:sourcedir]+"/main/api/*")
  domain_files = Dir.glob(options[:sourcedir]+"/main/domain/*")
end

if options[:verbose] 
  puts "Processing files: "
  puts api_files
  puts domain_files
end

domain_files.each do |fn|
  process_domain_file(fn, schemas, options)
end

schemas["ZonedDateTime"] = {}
schemas["ZonedDateTime"]["description"] = "A date-time with a time-zone in the ISO-8601 calendar system, such as 2007-12-03T10:15:30+01:00 Europe/Paris."
schemas["ZonedDateTime"]["example"] = "2007-12-03"
schemas["ZonedDateTime"]["type"] = "string"
schemas["Locale"] = {}
schemas["Locale"]["description"] = "A Locale object represents a specific geographical, political, or cultural region."
schemas["Locale"]["example"] = "en_US"
schemas["Locale"]["type"] = "string"
schemas["LocalDate"] = {}
schemas["LocalDate"]["description"] = "A date without a time-zone in the ISO-8601 calendar system, such as 2007-12-03."
schemas["LocalDate"]["example"] = "2007-12-03"
schemas["LocalDate"]["pattern"] = "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$"
schemas["LocalDate"]["type"] = "string"
schemas["ZoneId"] = {}
schemas["ZoneId"]["description"] = "Timezone Identifier"
schemas["ZoneId"]["example"] = "America/Denver"
schemas["ZoneId"]["pattern"] = "^\w+/\w+$"
schemas["ZoneId"]["type"] = "string"


components["schemas"] = schemas

api_files.each do |fn|
  process_api_file(fn, paths, options)
end

puts %Q(
openapi: "3.0.3"
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

# TODO handle security components
# TODO validate using openapi tool
# TODO handle {} in component schema
# TODO handle $ in names
# TODO custom deserializers? IdentityProviderRequestDeserializer
