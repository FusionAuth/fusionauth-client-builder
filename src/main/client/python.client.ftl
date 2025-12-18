[#import "_macros.ftl" as global/]
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

from deprecated import deprecated
from fusionauth.rest_client import RESTClient, JSONBodyHandler, FormDataBodyHandler


class FusionAuthClient:
    """The FusionAuthClient provides easy access to the FusionAuth API."""

    def __init__(self, api_key, base_url):
        """Constructs a new FusionAuthClient.

        Attributes:
            api_key: A string representing the API used to authenticate the API call to FusionAuth
            base_url: A string representing the URL use to access FusionAuth
        """
        self.api_key = api_key
        self.base_url = base_url
        self.tenant_id = None

    def set_tenant_id(self, tenant_id):
      """Sets the tenant_id on the client"""
      self.tenant_id = tenant_id

[#list apis as api]
[#if api.deprecated??]
    @deprecated("${api.deprecated?replace("{{renamedMethod}}", camel_to_underscores(api.renamedMethod!''))}")
[/#if]
    def ${camel_to_underscores(api.methodName)}(${global.methodParameters(api, "python")}):
        """
        ${api.comments?join("\n        ")}

        Attributes:
        [#list api.params![] as param]
          [#if !param.constant??]
            ${global.convertValue(param, "python")}: ${param.comments?join("\n                    ")}
          [/#if]
        [/#list]
        """
        [#assign formPost = false/]
        [#list api.params![] as param]
          [#if param.type == "form" || param.type == "formBody"][#assign formPost = true/][/#if]
        [/#list]
        [#if formPost]
        body = {
          [#list api.params![] as param]
            [#if param.type == "form"]
            "${param.name}": ${(param.constant?? && param.constant)?then("\""+param.value+"\"", param.name)},
            [#elseif param.type == "formBody"]
              [#-- Lookup the domain object by javaType --]
              [#list domain as d]
                [#if d.type == param.javaType]
                  [#-- Iterate through all fields in the domain object --]
                  [#list d.fields as fieldName, field]
                    [#if field.type == "String"]
            "${fieldName}": request.${fieldName},
                    [#else]
            "${fieldName}": str(request.${fieldName}) if request.${fieldName} is not None else None,
                    [/#if]
                  [/#list]
                [/#if]
              [/#list]
            [/#if]
          [/#list]
        }
        [/#if]
        return self.start[#if api.anonymous??]_anonymous[/#if]().uri('${api.uri}') \
          [#if api.authorization??]
            .authorization(${api.authorization?replace("encodedJWT", "encoded_jwt")}) \
          [/#if]
          [#list api.params![] as param]
            [#if param.type == "urlSegment"]
            .url_segment(${global.convertValue(param, "python")}) \
            [#elseif param.type == "urlParameter"]
            .url_parameter('${param.parameterName}', self.convert_true_false(${global.convertValue(param, "python")})) \
            [#elseif param.type == "queryBody"]
              [#list domain as d]
                [#if d.type == param.javaType]
                  [#list d.fields as fieldName, field]
                    [#if field.type == "String"]
            .url_parameter('${fieldName}', request.${fieldName}) \
                    [#else]
            .url_parameter('${fieldName}', str(request.${fieldName}) if request.${fieldName} is not None else None) \
                    [/#if]
                  [/#list]
                [/#if]
              [/#list]
            [#elseif param.type == "body"]
            .body_handler(JSONBodyHandler(${camel_to_underscores(param.name)})) \
            [/#if]
          [/#list]
          [#if formPost]
            .body_handler(FormDataBodyHandler(body)) \
          [/#if]
            .${api.method}() \
            .go()

[/#list]
    def convert_true_false(self,val):
        if val == True:
            return 'true'
        if val == False:
            return 'false'
        return val

    def start(self):
        return self.start_anonymous().authorization(self.api_key)

    def start_anonymous(self):
        client = RESTClient().url(self.base_url)
        if self.tenant_id is not None:
            client.header("X-FusionAuth-TenantId", self.tenant_id)

        return client
