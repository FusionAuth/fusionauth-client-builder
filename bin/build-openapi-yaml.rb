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
options[:outfile] = "openapi.yaml"
options[:apiversion] = "1.0.0"

# openapi component that defines our api key auth
api_key_auth_name = "ApiKeyAuth"

OptionParser.new do |opts|
  opts.banner = "Usage: build-openapi-yaml.rb [options]"

  opts.on("-v", "--verbose", "Run verbosely.") do |v|
    options[:verbose] = v
  end

  opts.on("-a", "--api-version SEMVER", "The api version for this build.") do |av|
    options[:apiversion] = av
  end

  opts.on("-d", "--source-directory DIR", "Source directory.") do |d|
    options[:sourcedir] = d
  end

  opts.on("-f", "--file FILE", "Run for one file.") do |file|
    options[:file] = file
  end

  opts.on("-o", "--out FILE", "Output file. Default is openapi.yaml.") do |outfile|
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

def add_identity_provider_field(schemas, identity_providers)
  schemas["IdentityProviderField"] = {}
  schemas["IdentityProviderField"]["oneOf"] = []
  identity_providers.each do |idp|
    schemas["IdentityProviderField"]["oneOf"] << {"$ref" => make_ref(idp) }
  end
end

def make_ref(type,packageName = nil)
  if type == "Void"
    return nil
  end
  objectName = modify_type(packageName,type)
  return '#/components/schemas/'+objectName
end

def modify_type(packageName,objectName)
  # collisions in a few cases
  if objectName == "LambdaConfiguration"
    if packageName.match(/connector/)
      return "Connector"+objectName
    elsif packageName.match(/provider/)
      return "Provider"+objectName
    end
  end
  return objectName
end

def process_domain_file(fn, schemas, options, identity_providers)
  if options[:verbose] 
    puts "processing "+fn
  end

  f = File.open(fn)
  fs = f.read
  json = JSON.parse(fs)
  f.close

  packagename = json["packageName"]
  objectname = modify_type(packagename,json["type"])
  openapiobj = {}
  if json["description"]
    openapiobj["description"] = json["description"].gsub('/','').gsub(/@au.*/,'').gsub('*','').gsub(/\n/,'').gsub("\n",'').delete("\n").strip
  end
  openapiobj["type"] = "object"


  # TODO What about ENUMS in an existing data model with fields?
  if json["enum"] 
    openapiobj["type"] = "string"
    # some enums have name attribute, other are just plain strings
    if json["enum"][0] && json["enum"][0]["name"]
      openapiobj["enum"] = json["enum"].map {|e| e["name"] }
    else
      openapiobj["enum"] = json["enum"]
    end
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
            addListValue(properties[k],k2,listElementType,identity_providers, k, objectname)
            
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
              addListValue(properties[k],k2,listElementType,identity_providers)
            elsif mapValueType == "D" && k == "applicationConfiguration" && objectname.match(/IdentityProvider$/) 
              if objectname.match(/BaseIdentityProvider$/) or objectname.match(/BaseSAMLv2IdentityProvider$/)
                # remove this one, we don't need to provide anything for the BaseIdentityProvider or BaseSAMLv2IdentityProvider application config.properties, I think
                properties.delete(k)
              else
                identityproviderconfigrefname = objectname.sub("IdentityProvider","") + "ApplicationConfiguration"
                properties[k]["additionalProperties"]['$ref'] = make_ref(identityproviderconfigrefname)
              end
            else
              properties[k]["additionalProperties"]['$ref'] = make_ref(mapValueType)
            end

            # no additional properties
            if properties[k]["additionalProperties"].length == 0
              properties[k].delete("additionalProperties")
            end
          else
            if v2.match(/BaseIdentityProvider$/)
               # special handling of this. We create IdentityProviderField elsewhere
               # see https://github.com/OpenAPITools/openapi-generator/issues/10880#issuecomment-995243186 for why
               properties[k]["$ref"] = make_ref('IdentityProviderField')
 
            else
              # put in ref
              properties[k]['$ref'] = make_ref(v2, packagename)
            end
          end
        end
      end
    end
  end

  schemas[objectname] = openapiobj 

end

def addListValue(hash,key,listElementType,identity_providers,rootkey=nil,objectname=nil)
  hash[key] = "array"
  hash["items"] = {}
  if is_primitive(listElementType)
    hash["items"] = convert_primitive(listElementType)
  elsif listElementType == "T" && rootkey == "results" && objectname == "SearchResults"
    # TODO not sure this works, test it out
    hash["items"] = {"type" => "object"}
  elsif listElementType.match(/BaseIdentityProvider$/)
    # special handling of this. We create IdentityProviderField elsewhere
    # see https://github.com/OpenAPITools/openapi-generator/issues/10880#issuecomment-995243186 for why
    hash["items"] = {}
    hash["items"]["$ref"] = make_ref('IdentityProviderField')
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

def process_rawpaths(rawpaths, options)

  new_paths = {}
  # take the list of paths at [uri][method] which are duplicates and then merge them

  # walk keys of paths to get uri
  # then walk keys of paths[uri] to get methods
  # then walk array of paths[uri][method] to get things to merge
  rawpaths.each do |uri, methods|
    new_paths[uri] = {}

    methods.each do |method, pathobjs| 

      if pathobjs.length == 1
        # no merging needed
        new_paths[uri][method] = pathobjs[0]
      else
        orig_object = pathobjs[0]
     
        pathobjs.drop(1).each do |pathobj|
          if options[:verbose] 
            puts "merging in " + uri.to_s + " " + method.to_s +  " operationId: " + pathobj["operationId"].to_s
          end
          orig_object = merge_operations(pathobj, orig_object, uri, method)
        end
        new_paths[uri][method] = orig_object 
      end
    end
  end

  return new_paths
end

def process_api_file(fn, paths, options)
  if options[:verbose] 
    puts "processing "+fn
  end
  f = File.open(fn)
  fs = f.read
  json = JSON.parse(fs)
  f.close

  if json["deprecated"]
    if options[:verbose] 
      puts "skipping deprecated "+fn
    end
    return
  end

  method = json["method"]
  uri = json["uri"]
  include_optional_segment_param = false
  uri_without_optional = uri

  # check to see if the url segments are optional
  if json["params"]
    include_optional_segment_param = true
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
  end

  if options[:verbose]
    puts "adding path for " + uri
  end

  # builds for full uri, including optional path params at end
  build_path(uri, json, paths, include_optional_segment_param, options)

  # only support an optional parameter on the last url segment
  if uri_without_optional != uri
    if options[:verbose]
      puts "adding path for " + uri_without_optional
    end
    build_path(uri_without_optional, json, paths, false, options)
  end
end

# build new operation id for operations that have multiple parameters all going to the same endpoint
def build_operation_id(new_api_object, old_api_object, uri, method)
  # builds nice operationId if we have multiple operations.

  prefix = ""
  if method == "get"
    prefix = "retrieve"
  elsif method == "put"
    prefix = "update"
  elsif method == "delete"
    prefix = "delete"
  elsif method == "patch"
    prefix = "patch"
  elsif method == "post"
    prefix = "create"
  end
  suffix = ""
  if uri[-1] == "}"
    suffix = "WithId"
  end
  uri_array = uri.split("/")
  operation_name = uri_array[2]

  # user has sub paths, and isn't a path param in disguise
  if operation_name == "user" && uri_array[3] && uri_array[3][-1] != "}"
    if uri_array[3] != "action"
      operation_name = uri_array[2]+ "-" + uri_array[3]
    else 
      # need this because there are both /api/user/action and /api/user-action endpoints, and this code gives them the same name
      operation_name = uri_array[2]+ "-" + "actioning"
    end
  elsif operation_name == "identity-provider" && uri_array[3] && uri_array[3][-1] != "}"
    # /api/identity-provider/link, /api/identity-provider/lookup, etc
    operation_name = uri_array[2]+ "-" + uri_array[3]
  end
  operation_name = operation_name.split("-").map{|e| e.capitalize}.join("")

  operation_name[0] = operation_name[0].capitalize # just capitalize first letter

  return prefix + operation_name + suffix

end

def merge_operations(new_api_object, old_api_object, uri, method)
  new_api_object["description"] += " OR " + old_api_object["description"]
  new_api_object["operationId"] = build_operation_id(new_api_object, old_api_object, uri, method)
  queryparamstoadd = old_api_object["parameters"].select{|p| p["in"] == "query"}
  # query params we add
  # path params are handled in the if uri_without_optional != uri code path
  # only problem would be if two different operations took different path params in same location but we don't have that
  oldparamstohandle = old_api_object["parameters"].select{|p| p["in"] != "query" && p["in"] != "path" }
  newparamstohandle = new_api_object["parameters"].select{|p| p["in"] != "query" && p["in"] != "path"}
  if oldparamstohandle & newparamstohandle != newparamstohandle 
    p "Saw some new params that were not query params. Doh! "
  end
  new_api_object["parameters"] += queryparamstoadd

  #remove dups
  new_api_object["parameters"] = new_api_object["parameters"].uniq { |p| p["name"] }

  # make sure if we have a requestBody, we pass that along in the merge. This will blow up if we have two operations that take request bodies but don't have the same request body
  if old_api_object["requestBody"] && !new_api_object["requestBody"]
    new_api_object["requestBody"] = old_api_object["requestBody"]
  end

  return new_api_object
end

def build_path(uri, json, paths, include_optional_segment_param, options)

  method = json["method"]
  desc = json["comments"].join(" ").delete("\n").strip
  operationId = json["methodName"]
  if include_optional_segment_param
    operationId += "WithId"
  end
  jsonparams = json["params"]

  if not paths[uri] 
    paths[uri] = {}
  end

  # create an array of paths all with this uri and method. Later we will process them.
  if not paths[uri][method]
    paths[uri][method] = []
  end

  openapiobj = {}
  paths[uri][method] << openapiobj

  openapiobj["description"] = desc
  openapiobj["operationId"] = operationId
  if json["anonymous"] == true
    openapiobj["security"] = []
  end
  

  params = []
  openapiobj["parameters"] = params

  if jsonparams
    segmentparams = jsonparams.select{|p| p["type"] == "urlSegment"}
    queryparams = jsonparams.select{|p| p["type"] == "urlParameter"}
    bodyparams = jsonparams.select{|p| p["type"] == "body"}
  
    queryparams.each do |p|
      params << build_openapi_paramobj(p, "query")
    end

    segmentparams.each do |p|
      if p["constant"] == true
        # ignore this, we build it elsewhere
        next
      end

      if param_optional(p["comments"])
        if include_optional_segment_param
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

  add_header_params(params,json)

  openapiobj["responses"] = {}
  openapiobj["responses"]['200'] = {}
  build_nested_content_response(openapiobj["responses"]['200'], make_ref(json["successResponse"]), "Success")

  openapiobj["responses"]['default'] = {}
  build_nested_content_response(openapiobj["responses"]['default'], make_ref(json["errorResponse"]), "Error")

end

def add_header_params(params, json)

   # TODO this info should be shoved into the api definition JSON in client builder. This is currently absent and only available in the docs or code or here
   apis_requiring_tenant_header = ["tenant","user-action","entity","user/family","user","two-factor","user/comment","application","email/template","user/registration","group","consent"]

   apis_with_optional_tenant_header = ["login", "passwordless", "identity-provider/login","jwt"]
   
   no_header_needed = true
   required = false
   if apis_requiring_tenant_header.include? json["uri"].gsub("/api/","")
     required = true
     no_header_needed = false
   end
   if apis_with_optional_tenant_header.include? json["uri"].gsub("/api/","")
     required = false
     no_header_needed = false
   end

   if no_header_needed
     # no tenant header there
     return
   end
   header_param = {}
   header_param["in"] = "header"
   header_param["name"] = "X-FusionAuth-TenantId"
   header_param["description"] = "The unique Id of the tenant used to scope this API request. Only required when there is more than one tenant and the API key is not tenant-scoped."
   header_param["required"] = false
   header_param["schema"] = {}
   header_param["schema"]["type"] = "string"
   header_param["schema"]["format"] = "UUID"

   params << header_param
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

def build_security_schemes(api_key_auth_name)
  security_schemes = {}
  security_schemes[api_key_auth_name] = {}
  security_schemes[api_key_auth_name]["type"] = "apiKey"
  security_schemes[api_key_auth_name]["name"] = "Authorization"
  security_schemes[api_key_auth_name]["in"] = "header"

  # TODO we don't have a way in the json to designate these api calls. need to extend the metadata
  #security_schemes["jwt"] = {}
  #security_schemes["jwt"]["type"] = "http"
  #security_schemes["jwt"]["scheme"] = "Bearer"

  return security_schemes
end

######### processing starts

domain_files = []
api_files = []
schemas = {}
components = {}

# have to do additional processing on paths
rawpaths = {}

spec = {}
spec["components"] = components

if options[:file]
  api_files = Dir.glob(options[:sourcedir]+"/main/api/*"+options[:file]+"*")
  #domain_files = Dir.glob(options[:sourcedir]+"/main/domain/*"+options[:file]+".json")
  domain_files = Dir.glob(options[:sourcedir]+"/main/domain/*")
else
  api_files = Dir.glob(options[:sourcedir]+"/main/api/*")
  domain_files = Dir.glob(options[:sourcedir]+"/main/domain/*")
end

if options[:verbose] 
  puts "Processing files: "
  puts api_files
  puts domain_files
end

# gather all the identity providers
identity_providers = []
domain_files.each do |fn|
  f = File.open(fn)
  fs = f.read
  json = JSON.parse(fs)
  f.close
  if json["extends"] && json["extends"][0]["type"] == "BaseIdentityProvider" && json["type"] != "BaseSAMLv2IdentityProvider"
    identity_providers << json["type"]
  end
  if json["extends"] && json["extends"][0]["type"] == "BaseSAMLv2IdentityProvider"
    identity_providers << json["type"]
  end
end

domain_files.each do |fn|
  if fn.match(/io.fusionauth.domain.provider.BaseIdentityProvider.json/)
    next
  end
  if fn.match(/io.fusionauth.domain.provider.BaseSAMLv2IdentityProvider.json/)
    next
  end
  process_domain_file(fn, schemas, options,identity_providers)
end

schemas["ZonedDateTime"] = {}
schemas["ZonedDateTime"]["description"] = "The number of milliseconds since the unix epoch: January 1, 1970 00:00:00 UTC. This value is always in UTC."
schemas["ZonedDateTime"]["example"] = "1659380719000"
schemas["ZonedDateTime"]["type"] = "integer"
schemas["ZonedDateTime"]["format"] = "int64"
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

add_identity_provider_field(schemas, identity_providers)

components["schemas"] = schemas
components["securitySchemes"] = build_security_schemes(api_key_auth_name)

api_files.each do |fn|
  process_api_file(fn, rawpaths, options)
end

spec["paths"] = process_rawpaths(rawpaths, options)

File.open(options[:outfile], "w") do |f|

  # header
  f.write %Q(
openapi: "3.0.3"
info:
  version: #{options[:apiversion]}
  title: FusionAuth API
  description: "This is a FusionAuth server. Find out more at [https://fusionauth.io](https://fusionauth.io). You need to [set up an API key](https://fusionauth.io/docs/v1/tech/apis/authentication#managing-api-keys) in the FusionAuth instance you are using to test out the API calls."
  license:
    name: Apache2
servers:
  - url: http://localhost:9011
  - url: https://sandbox.fusionauth.io
security:
  - #{api_key_auth_name}: []
)

  # components and paths
  # https://stackoverflow.com/questions/21251309/how-to-remove-on-top-of-a-yaml-file
  f.write spec.to_yaml.gsub(/^---/,'')
end

# TODO handle {} in component schema ? 
# TODO custom deserializers? IdentityProviderRequestDeserializer or is that handled by openapi?

# not defined anywhere, we don't support this yet
# TODO more status codes

# TODO cookies
# TODO anyof https://github.com/swagger-api/swagger-codegen/issues/10011 
# TODO content -type is sent on GETs https://github.com/swagger-api/swagger-codegen/issues/8310
# TODO should we handle type form, notUsed? that is used for oauth token exchange
  
