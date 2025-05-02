[#import "_macros.ftl" as global/]
/*
 * Copyright (c) 2018-2023, FusionAuth, All Rights Reserved
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
using io.fusionauth.domain.api.user.verify;
using io.fusionauth.domain.oauth2;
using io.fusionauth.domain.provider;

namespace io.fusionauth {
  public class FusionAuthClient : IFusionAuthAsyncClient {
    public readonly string apiKey;

    public readonly string host;

    public readonly string tenantId;

    public readonly IRESTClientBuilder clientBuilder;

    public FusionAuthClient(string apiKey, string host, string tenantId = null, IRESTClientBuilder clientBuilder = null) {
      this.apiKey = apiKey;
      this.host = host;
      this.tenantId = tenantId;

      this.clientBuilder = clientBuilder ?? new DefaultRESTClientBuilder();
    }

    /**
     * Return a new instance of FusionAuthClient using the provided tenantId.
     * @param tenantId the tenantId to use for this client.
     */
    // ReSharper disable once ParameterHidesMember
    public FusionAuthClient withTenantId(string tenantId) {
      return tenantId == null ? this : new FusionAuthClient(apiKey, host, tenantId, clientBuilder);
    }

    /**
     * Return a new instance of FusionAuthClient using the provided tenantId.
     * @param tenantId the tenantId to use for this client.
     */
    // ReSharper disable once ParameterHidesMember
    public FusionAuthClient withTenantId(Guid? tenantId) {
      return tenantId == null ? this : new FusionAuthClient(apiKey, host, tenantId.ToString(), clientBuilder);
    }

    /**
     * Return a new instance of FusionAuthClient using the provided client builder.
     * @param clientBuilder the REST client builder to use for this client.
     */
    // ReSharper disable once ParameterHidesMember
    public FusionAuthClient withClientBuilder(IRESTClientBuilder clientBuilder) {
      return clientBuilder == null ? this : new FusionAuthClient(apiKey, host, tenantId, clientBuilder);
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
    [#-- C# supports method overloading, so exclude apis that are just overloads --]
    [#list apis?filter(api -> !(api.overload??)) as top_level_api]
      [#if top_level_api.overloads!false]
        [#assign overloads=[top_level_api] + apis?filter(other -> other.overload?? && other.overload == top_level_api.methodName) /]
      [#else]
        [#assign overloads=[top_level_api] /]
      [/#if]
    [#list overloads as api]
    [#assign is_overload = api.overload??/]

    /// <inheritdoc/>
     [#if api.deprecated??]
    [Obsolete("${api.deprecated?replace("{{renamedMethod}}",(api.renamedMethod!'')?cap_first + "Async")}")]
     [/#if]
    public Task<ClientResponse<${global.convertType(api.successResponse, "csharp")}>> ${is_overload?then(api.overload, api.methodName)?cap_first}Async(${global.methodParameters(api, "csharp")}) {
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
    [/#list]
  }

  internal class DefaultRESTClientBuilder : IRESTClientBuilder {
    public IRESTClient build(string host) {
      return new DefaultRESTClient(host);
    }
  }
}
