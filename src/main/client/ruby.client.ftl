[#import "_macros.ftl" as global/]
require 'ostruct'
require 'fusionauth/rest_client'

#
# Copyright (c) 2018-${.now?string('yyyy')}, FusionAuth, All Rights Reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#

module FusionAuth
  #
  # This class is the the Ruby client library for the FusionAuth CIAM Platform {https://fusionauth.io}
  #
  # Each method on this class calls one of the APIs for FusionAuth. In most cases, the methods will take either a Hash, an
  # OpenStruct or any object that can be safely converted to JSON that conforms to the FusionAuth API interface. Likewise,
  # most methods will return an OpenStruct that contains the response JSON from FusionAuth.
  #
  # noinspection RubyInstanceMethodNamingConvention,RubyTooManyMethodsInspection,RubyParameterNamingConvention
  class FusionAuthClient
    attr_accessor :api_key, :base_url, :connect_timeout, :read_timeout, :tenant_id

    def initialize(api_key, base_url)
      @api_key = api_key
      @base_url = base_url
      @connect_timeout = 1000
      @read_timeout = 2000
      @tenant_id = nil
    end

    def set_tenant_id(tenant_id)
      @tenant_id = tenant_id
    end

[#list apis as api]
    #
  [#list api.comments as comment]
    # ${comment}
  [/#list]
    #
  [#list api.params![] as param]
    [#if !param.constant??]
    # @param ${camel_to_underscores(param.name?replace("end", "_end"))} [${global.convertType(param.javaType, "ruby")}] ${param.comments?join("\n    #     ")}
    [/#if]
  [/#list]
    # @return [FusionAuth::ClientResponse] The ClientResponse object.
[#if api.deprecated??]
    # @deprecated ${api.deprecated?replace("{{renamedMethod}}", camel_to_underscores(api.renamedMethod!''))}
[/#if]
    def ${camel_to_underscores(api.methodName)}[#if (api.params![])?filter(p -> !p.constant??)?has_content](${global.methodParameters(api, "ruby")})[/#if]
      [#assign formPost = false/]
      [#assign hasFormParams = false/]
      [#list api.params![] as param]
        [#if param.type == "form" || param.type == "formBody"][#assign formPost = true/][/#if]
        [#if param.type == "form"][#assign hasFormParams = true/][/#if]
      [/#list]
      [#if formPost]
      form_parameters = {
        [#list api.params![] as param]
          [#if param.type == "form"]
        "${param.name}" => ${(param.constant?? && param.constant)?then("'"+param.value+"'", camel_to_underscores(param.name))},
          [#elseif param.type == "formBody"]
            [#-- Lookup the domain object by javaType --]
            [#list domain as d]
              [#if d.type == param.javaType]
                [#-- Iterate through all fields in the domain object --]
                [#list d.fields as fieldName, field]
                  [#if field.type == "String"]
        "${fieldName}" => request.${fieldName},
                  [#else]
        "${fieldName}" => (request.${fieldName}.to_s unless request.${fieldName}.nil?),
                  [/#if]
                [/#list]
              [/#if]
            [/#list]
          [/#if]
        [/#list]
      }
      [/#if]
      start[#if api.anonymous??]Anonymous[/#if].uri('${api.uri}')
      [#if api.authorization??]
          .authorization(${api.authorization?replace('encodedJWT', 'encoded_jwt')?replace('\"', '\'')})
      [/#if]
      [#list api.params![] as param]
        [#if param.type == "urlSegment"]
          .url_segment(${(param.constant?? && param.constant)?then(param.value, camel_to_underscores(param.name))})
        [#elseif param.type == "urlParameter"]
          .url_parameter('${param.parameterName}', ${(param.constant?? && param.constant)?then(param.value, camel_to_underscores(param.name?replace("end", "_end")))})
        [#elseif param.type == "body"]
          .body_handler(FusionAuth::JSONBodyHandler.new(${camel_to_underscores(param.name)}))
        [/#if]
      [/#list]
      [#if formPost]
          .body_handler(FusionAuth::FormDataBodyHandler.new(form_parameters))
      [/#if]
          .${api.method}
          .go
    end

[/#list]
    #
    # Starts the HTTP call
    #
    # @return [RESTClient] The RESTClient
    #
    private
    def start
      startAnonymous.authorization(@api_key)
    end

    private
    def startAnonymous
      client = RESTClient.new
                        .success_response_handler(FusionAuth::JSONResponseHandler.new(OpenStruct))
                        .error_response_handler(FusionAuth::JSONResponseHandler.new(OpenStruct))
                        .url(@base_url)
                        .connect_timeout(@connect_timeout)
                        .read_timeout(@read_timeout)
      if @tenant_id != nil
        client.header("X-FusionAuth-TenantId", @tenant_id)
      end
      client
    end
  end
end

