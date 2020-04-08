[#--noinspection ALL--]
[#import "_macros.ftl" as global/]
/*
* Copyright (c) 2020, FusionAuth, All Rights Reserved
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

import 'dart:io';
import 'FusionAuthRESTClient.dart';
import 'FusionAuthDomain.dart';

typedef RESTClientFactory = FusionAuthRESTClient Function<ReturnType, ErrorReturnType>(String host, HttpClient httpClient);

FusionAuthRESTClient<ReturnType, ErrorReturnType> DefaultFusionAuthRESTClientFactory<ReturnType, ErrorReturnType>(host, httpClient) {
  return FusionAuthRESTClient<ReturnType, ErrorReturnType>(host, httpClient);
}

class FusionAuthClient {
  HttpClientCredentials credentials;
  String apiKey;
  String host;
  String tenantId;
  RESTClientFactory fusionAuthRESTClientFactory = DefaultFusionAuthRESTClientFactory;

  FusionAuthClient(
    this.apiKey,
    this.host,
    this.tenantId
  );

  /// Sets the tenant id, that will be included in the X-FusionAuth-TenantId header.
  ///
  /// @param {string | null} tenantId The value of the X-FusionAuth-TenantId header.
  /// @returns {FusionAuthClient}
  FusionAuthClient setTenantId(String tenantId) {
    this.tenantId = tenantId;
    return this;
  }

  /// Sets whether and how cookies will be sent with each request.
  ///
  /// @param value The value that indicates whether and how cookies will be sent.
  /// @returns {FusionAuthClient}
  FusionAuthClient setRequestCredentials(HttpClientCredentials value) {
    credentials = value;
    return this;
  }

  /// Sets the builder for the rest client so that it can be overridden/subclassed/or altered before client use.
  FusionAuthClient setRESTClientFactory(RESTClientFactory restClientFactory) {
    fusionAuthRESTClientFactory = restClientFactory;
    return this;
  }

[#-- @formatter:off --]
[#list apis as api]
  [#list api.comments as comment]
  /// ${comment}
  [/#list]
  ///
  [#list api.params![] as param]
    [#if !param.constant??]
  /// @param {${global.optional(param, "ts")}${global.convertType(param.javaType, "dart")}} ${param.name} ${param.comments?join("\n  ///    ")}
    [/#if]
  [/#list]
  /// @returns {Promise<ClientResponse<${global.convertType(api.successResponse, "dart")}>>}
  [#if api.deprecated??]
  ///
  /// @deprecated ${api.deprecated?replace("{{renamedMethod}}", api.renamedMethod!'')}
  [/#if]
  [#assign parameters = global.methodParameters(api, "dart")/]
  Future<ClientResponse<${global.convertType(api.successResponse, "dart")}, ${global.convertType(api.errorResponse, "dart")}>> ${api.methodName}(${parameters}) {
  [#assign formPost = false/]
  [#list api.params![] as param]
    [#if param.type == "form"][#assign formPost = true/][/#if]
  [/#list]
  [#if formPost]
    var body = Map<String, dynamic>();
    [#list api.params![] as param]
      [#if param.type == "form"]
    body['${param.name}'] = ${(param.constant?? && param.constant)?then("'"+param.value+"'", param.name)};
      [/#if]
    [/#list]
  [/#if]
    return _start[#if api.anonymous??]Anonymous[/#if]<${global.convertType(api.successResponse, "dart")}, ${global.convertType(api.errorResponse, "dart")}>()
  [#if api.method == "post" && !formPost && !global.hasBodyParam(api.params![])]
        .withHeader('Content-Type', 'text/plain')
  [/#if]
        .withUri('${api.uri}')
  [#if api.authorization??]
        .withAuthorization(${api.authorization?replace('\"', '\'')})
  [/#if]
  [#list api.params![] as param]
    [#if param.type == "urlSegment"]
        .withUriSegment(${(param.constant?? && param.constant)?then(param.value, param.name)})
    [#elseif param.type == "urlParameter"]
        .withParameter('${param.parameterName}', ${(param.constant?? && param.constant)?then(param.value, param.name)})
    [#elseif param.type == "body"]
        .withJSONBody(${param.name})
    [/#if]
  [/#list]
  [#if formPost]
        .withFormData(body)
  [/#if]
        .withMethod('${api.method?upper_case}')
        [#if api.successResponse != "Void"]
        .withResponseHandler(defaultResponseHandlerBuilder((d) => ${global.convertType(api.successResponse, "dart")}.fromJson(d)))
        [/#if]
        .go();
  }

[/#list]
[#-- @formatter:on --]

  /* ===================================================================================================================
   * Private methods
   * ===================================================================================================================*/

  final HttpClient _httpClient = HttpClient();

  FusionAuthRESTClient _start<RT, ERT>() {
    return _startAnonymous<RT, ERT>()
        .withAuthorization(apiKey);
  }

  FusionAuthRESTClient _startAnonymous<RT, ERT>() {
    var client = fusionAuthRESTClientFactory<RT, ERT>(host, _httpClient);

    if (tenantId != null) {
      client.withHeader('X-FusionAuth-TenantId', tenantId);
    }

    if (credentials != null) {
      client.withCredentials(credentials);
    }

    return client;
  }
}
