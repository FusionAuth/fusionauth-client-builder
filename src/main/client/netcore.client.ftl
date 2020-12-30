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
using System.Threading.Tasks;
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
  public class FusionAuthClient : IFusionAuthAsyncClient {
    public readonly string apiKey;

    public readonly string host;

    public readonly string tenantId;

    public readonly IRESTClientBuilder clientBuilder;

    public FusionAuthClient(string apiKey, string host, string tenantId = null) {
      this.apiKey = apiKey;
      this.host = host;
      this.tenantId = tenantId;

      clientBuilder = new DefaultRESTClientBuilder();
    }

    /**
     * Return a new instance of FusionAuthClient using the provided tenantId.
     * @param tenantId the tenantId to use for this client.
     */
    // ReSharper disable once ParameterHidesMember
    public FusionAuthClient withTenantId(string tenantId) {
      return tenantId == null ? this : new FusionAuthClient(apiKey, host, tenantId);
    }

    /**
     * Return a new instance of FusionAuthClient using the provided tenantId.
     * @param tenantId the tenantId to use for this client.
     */
    // ReSharper disable once ParameterHidesMember
    public FusionAuthClient withTenantId(Guid? tenantId) {
      return tenantId == null ? this : new FusionAuthClient(apiKey, host, tenantId.ToString());
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

    /// <inheritdoc/>
     [#if api.deprecated??]
    [Obsolete("${api.deprecated?replace("{{renamedMethod}}",(api.renamedMethod!'')?cap_first + "Async")}")]
     [/#if]
    public Task<ClientResponse<${global.convertType(api.successResponse, "csharp")}>> ${api.methodName?cap_first}Async(${global.methodParameters(api, "csharp")}) {
      [#assign formPost = false/]
      [#list api.params![] as param]
        [#if param.type == "form"][#assign formPost = true/][/#if]
      [/#list]
      [#if formPost]
      var body = new Dictionary<string, string> {
        [#list api.params![] as param]
          [#if param.type == "form"]
          { "${param.name}", ${(param.constant?? && param.constant)?then("\""+param.value+"\"", param.name)} },
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
          .goAsync<${global.convertType(api.successResponse, "csharp")}>();
    }
    [/#list]
  }

  internal class DefaultRESTClientBuilder : IRESTClientBuilder {
    public IRESTClient build(string host) {
      return new DefaultRESTClient(host);
    }
  }
}
