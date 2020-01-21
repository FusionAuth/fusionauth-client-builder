[#import "_macros.ftl" as global/]
/*
 * Copyright (c) 2018-2020, FusionAuth, All Rights Reserved
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied. See the License for the specific
 * language governing permissions and limitations under the License.
 */

using System;
using System.Collections.Generic;
using System.Net.Http;
using io.fusionauth.domain;
using io.fusionauth.domain.api;
using io.fusionauth.domain.api.email;
using io.fusionauth.domain.api.identityProvider;
using io.fusionauth.domain.api.jwt;
using io.fusionauth.domain.api.passwordless;
using io.fusionauth.domain.api.report;
using io.fusionauth.domain.api.twoFactor;
using io.fusionauth.domain.api.user;
using io.fusionauth.domain.oauth2;

namespace io.fusionauth {
  public class FusionAuthClient {
    public readonly string apiKey;

    public readonly string host;

    public readonly string tenantId;

    public IRESTClientBuilder clientBuilder;

    public FusionAuthClient(string apiKey, string host, string tenantId = null) {
      this.apiKey = apiKey;
      this.host = host;
      this.tenantId = tenantId;

      clientBuilder = new DefaultRESTClientBuilder();
    }

    public IRESTClient buildClient() {
      return buildAnonymousClient().withAuthorization(apiKey);
    }

    public IRESTClient buildAnonymousClient() {
      var client = clientBuilder.build(host);

      if (tenantId != null) {
        client.withHeader("X-FusionAuth-TenantId", tenantId);
      }

      return client;
    }

    [#list apis as api]

     /// <summary>
      [#list api.comments as comment]
     /// ${comment}
      [/#list]
     /// </summary>
     ///
      [#list api.params![] as param]
        [#if !param.constant??]
     /// <param name="${param.name}"> ${param.comments?join("\n     /// ")}</param>
        [/#if]
      [/#list]
     /// <returns>When successful, the response will contain the log of the action. If there was a validation error or any
     /// other type of error, this will return the Errors object in the response. Additionally, if FusionAuth could not be
     /// contacted because it is down or experiencing a failure, the response will contain an Exception, which could be an
     /// IOException.</returns>
     [#if api.deprecated??]
    [Obsolete("${api.deprecated?replace("{{renamedMethod}}", (api.renamedMethod!'')?cap_first)}")]
     [/#if]
    public ClientResponse<${global.convertType(api.successResponse, "csharp")}> ${api.methodName?cap_first}(${global.methodParameters(api, "csharp")}) {
      [#assign formPost = false/]
      [#list api.params![] as param]
        [#if param.type == "form"][#assign formPost = true/][/#if]
      [/#list]
      [#if formPost]
      List<KeyValuePair<string, string>> body = new List<KeyValuePair<string, string>> {
        [#list api.params![] as param]
          [#if param.type == "form"]
          { new KeyValuePair<string, string>("${param.name}", ${(param.constant?? && param.constant)?then("\""+param.value+"\"", param.name)}) },
          [/#if]
        [/#list]
      };
      [/#if]
      return build[#if api.anonymous??]Anonymous[/#if]Client()
          .withUri("${api.uri}")
      [#if api.authorization??]
          .withAuthorization(${api.authorization})
      [/#if]
      [#list api.params![] as param]
        [#if param.type == "urlSegment"]
          .withUriSegment(${(param.constant?? && param.constant)?then(param.value, param.name)})
        [#elseif param.type == "urlParameter"]
          .withParameter("${param.parameterName}", ${(param.constant?? && param.constant)?then(param.value, param.name)})
        [#elseif param.type == "body"]
          .withJSONBody(${param.name})
        [/#if]
      [/#list]
      [#if formPost]
          .withFormData(new FormUrlEncodedContent(body))
      [/#if]
          .withMethod("${api.method?cap_first}")
          .go<${global.convertType(api.successResponse, "csharp")}>();
    }
    [/#list]

  }

  internal class DefaultRESTClientBuilder : IRESTClientBuilder {
    public IRESTClient build(string host) {
      return new DefaultRESTClient(host);
    }
  }
}
