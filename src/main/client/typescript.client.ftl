[#--noinspection ALL--]
[#import "_macros.ftl" as global/]
/*
* Copyright (c) 2019, FusionAuth, All Rights Reserved
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

import IRESTClient from "./IRESTClient"
import DefaultRESTClientBuilder from "./DefaultRESTClientBuilder";
import IRESTClientBuilder from "./IRESTClientBuilder";
import ClientResponse from "./ClientResponse";
import {RequestCredentials} from "node-fetch";
import {URLSearchParams} from "url";

export class FusionAuthClient {
  public clientBuilder: IRESTClientBuilder = new DefaultRESTClientBuilder();
  public credentials: RequestCredentials;

  constructor(
    public apiKey: string,
    public host: string,
    public tenantId?: string,
  ) { }

  /**
   * Sets the tenant id, that will be included in the X-FusionAuth-TenantId header.
   *
   * @param {string | null} tenantId The value of the X-FusionAuth-TenantId header.
   * @returns {FusionAuthClient}
   */
  setTenantId(tenantId: string | null): FusionAuthClient {
    this.tenantId = tenantId;
    return this;
  }

  /**
   * Sets whether and how cookies will be sent with each request.
   * 
   * @param value The value that indicates whether and how cookies will be sent.
   * @returns {FusionAuthClient}
   */
  setRequestCredentials(value: RequestCredentials): FusionAuthClient {
    this.credentials = value;
    return this;
  }

[#-- @formatter:off --]
[#list apis as api]
  /**
  [#list api.comments as comment]
   * ${comment}
  [/#list]
   *
  [#list api.params![] as param]
    [#if !param.constant??]
   * @param {${global.optional(param, "ts")}${global.convertType(param.javaType, "ts")}} ${param.name} ${param.comments?join("\n   *    ")}
    [/#if]
  [/#list]
   * @returns {Promise<ClientResponse<${global.convertType(api.successResponse, "ts")}>>}
  [#if api.deprecated??]
   *
   * @deprecated ${api.deprecated?replace("{{renamedMethod}}", api.renamedMethod!'')}
  [/#if]
   */
  [#assign parameters = global.methodParameters(api, "ts")/]
  ${api.methodName}(${parameters}): Promise<ClientResponse<${global.convertType(api.successResponse, "ts")}>> {
  [#assign formPost = false/]
  [#list api.params![] as param]
    [#if param.type == "form"][#assign formPost = true/][/#if]
  [/#list]
  [#if formPost]
    let body = new URLSearchParams();

    [#list api.params![] as param]
      [#if param.type == "form"]
    body.append('${param.name}', ${(param.constant?? && param.constant)?then("'"+param.value+"'", param.name)});
      [/#if]
    [/#list]
  [/#if]
    return this.start[#if api.anonymous??]Anonymous[/#if]<${global.convertType(api.successResponse, "ts")}, ${global.convertType(api.errorResponse, "ts")}>()
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
        .withMethod("${api.method?upper_case}")
        .go();
  }

[/#list]
[#-- @formatter:on --]

  /* ===================================================================================================================
   * Private methods
   * ===================================================================================================================*/

  /**
   * creates a rest client
   *
   * @returns The RESTClient that will be used to call.
   * @private
   */
  private start<RT, ERT>(): IRESTClient<RT, ERT> {
    return this.startAnonymous<RT, ERT>()
               .withAuthorization(this.apiKey);
  }

  private startAnonymous<RT, ERT>(): IRESTClient<RT, ERT> {
    let client = this.clientBuilder.build<RT, ERT>(this.host);

    if (this.tenantId != null) {
      client.withHeader('X-FusionAuth-TenantId', this.tenantId);
    }

    if (this.credentials != null) {
      client.withCredentials(this.credentials);
    }

    return client;
  }
}

export default FusionAuthClient;

/**
 * A 128 bit UUID in string format "8-4-4-4-12", for example "58D5E212-165B-4CA0-909B-C86B9CEE0111".
 */
export type UUID = string;

[#-- @formatter:off --]
[#macro printType type]
  [#if type.type??]
    ${global.convertType(type.type, "ts")}[#if type.typeArguments?has_content]<[#list type.typeArguments as typeArgument][@printType typeArgument/][#sep], [/#sep][/#list]>[/#if][#if type.extends??] extends [#list type.extends as extends][@printType extends/][#sep], [/#sep][/#list][/#if][#t]
  [#else]
    ${type.name}[#if type.extends??] extends [#list type.extends as extends][@printType extends/][#sep], [/#sep][/#list][/#if][#t]
  [/#if]
[/#macro]

[#list domain?sort_by("type") as d]
[#if d.description??]${d.description}[/#if][#t]
[#if d.fields??]
[#-- Use interface here because classes require the correct order for declaration if it extends something --]
[#-- Interfaces are also only for type checking so they can result in smaller compiled code --]
export interface [@printType d/] {
  [#list d.fields?keys?sort as fieldName]
  [#assign field = d.fields[fieldName]/]
  [#if field.description??]${field.description}[/#if][#t]
  [#if field.anySetter?? && field.anySetter]
  [${global.scrubName(fieldName)}: string]: any; // Any other fields
  [#else]
  ${global.scrubName(fieldName)}?: [@printType field/];
  [/#if]
  [/#list]
}
[#else]
export enum ${d.type} {
  [#list d.enum as value]
    [#if global.needsConverter(d)]
  ${value.name} = "${(value.args![])[0]!value.name}"[#sep],[/#sep]
    [#else]
  ${value.name!value}[#sep],[/#sep]
    [/#if]
  [/#list]
}
[/#if]

[/#list]
[#-- @formatter:on --]
