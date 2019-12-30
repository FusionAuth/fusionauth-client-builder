[#import "_macros.ftl" as global/]
/*
 * Copyright (c) 2018-2019, FusionAuth, All Rights Reserved
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

'use strict';

var FusionAuthClient = function(apiKey, host) {
  this.apiKey = apiKey;
  this.host = host;
  this.tenantId = null;
};

FusionAuthClient.constructor = FusionAuthClient;
//noinspection JSUnusedGlobalSymbols
FusionAuthClient.prototype = {

  /**
   * Sets the tenantId on the client.
   *
   * @param tenantId
   */
  setTenantId: function(tenantId) {
    this.tenantId = tenantId;
    return this;
  },

[#list apis as api]
  /**
  [#list api.comments as comment]
   * ${comment}
  [/#list]
   *
  [#list api.params![] as param]
    [#if !param.constant??]
   * @param {${global.optional(param, "js")}${global.convertType(param.javaType, "js")}} ${param.name} ${param.comments?join("\n   *    ")}
    [/#if]
  [/#list]
   * @param {Function} callBack The response handler call back. This function will be passed the ClientResponse object.
[#if api.deprecated??]
   *
   * @deprecated ${api.deprecated?replace("{{renamedMethod}}", api.renamedMethod!'')}
[/#if]
   */
  [#assign parameters = global.methodParameters(api, "js")/]
  ${api.methodName}: function(${parameters}${parameters?has_content?then(', callBack', 'callBack')}) {
    [#assign formPost = false/]
    [#list api.params![] as param]
      [#if param.type == "form"][#assign formPost = true/][/#if]
    [/#list]
    [#if formPost]
      var body = new FormData();
      [#list api.params![] as param]
        [#if param.type == "form"]
      body.append('${param.name}', ${(param.constant?? && param.constant)?then("'"+param.value+"'", param.name)});
        [/#if]
      [/#list]
    [/#if]
      return this._start[#if api.anonymous??]Anonymous[/#if]()
      [#if api.method == "post" && !formPost && !global.hasBodyParam(api.params![])]
          .header('Content-Type', 'text/plain')
      [/#if]
          .uri('${api.uri}')
      [#if api.authorization??]
          .authorization(${api.authorization?replace('\"', '\'')})
      [/#if]
      [#list api.params![] as param]
        [#if param.type == "urlSegment"]
          .urlSegment(${(param.constant?? && param.constant)?then(param.value, param.name)})
        [#elseif param.type == "urlParameter"]
          .urlParameter('${param.parameterName}', ${(param.constant?? && param.constant)?then(param.value, param.name)})
        [#elseif param.type == "body"]
          .setJSONBody(${param.name})
        [/#if]
      [/#list]
      [#if formPost]
          .setFormData(body)
      [/#if]
          .${api.method}()
          .go(callBack);
  },

[/#list]
  /* ===================================================================================================================
   * Private methods
   * ===================================================================================================================*/

  /**
   * creates a rest client
   *
   * @returns {RESTClient} The RESTClient that will be used to call.
   * @private
   */
  _start: function() {
    return this._startAnonymous().authorization(this.apiKey);
  },

  _startAnonymous: function() {
    let client = new RESTClient().setUrl(this.host);
    if (this.tenantId != null) {
      client.header('X-FusionAuth-TenantId', this.tenantId);
    }
    return client;
  }
};

/**
 * A 128 bit UUID in string format "8-4-4-4-12", for example "58D5E212-165B-4CA0-909B-C86B9CEE0111".
 *
 * @typedef {string} UUIDString
 */

[#macro printType type]
  [#if type.type??]
      ${global.convertType(type.type, "js")}[#t][#if type.typeArguments?has_content]
  <[#list type.typeArguments as typeArgument][@printType typeArgument/][#sep], [/#sep][/#list]>[/#if][#t]
  [#else]
    ${type.name}[#t]
  [/#if]
[/#macro]

[#-- @formatter:off --]
[#list domain?sort_by("type") as d]
[#if d.fields??]
[#-- Use interface here because classes require the correct order for declaration if it extends something --]
[#-- Interfaces are also only for type checking so they can result in smaller compiled code --]
/**
  [#if d.description?has_content]
    ${global.innerComment(d.description)}[#lt]
 *
  [/#if]
 * @typedef {Object} ${global.convertType(d.type, "js")}
  [#if d.typeArguments?has_content]
 * @template {[#list d.typeArguments as typeArgument][@printType typeArgument/][#sep], [/#sep][/#list]}
  [/#if]
  [#if d.extends??]
    [#list d.extends as extends]
 * @extends [@printType extends/]
    [/#list]
  [/#if]
 *
  [#list d.fields?keys?sort as fieldName]
    [#assign field = d.fields[fieldName]/]
  [#if field.description??]
 * ${field.description}
  [/#if]
  [#if !field.anySetter?? || !field.anySetter]
 * @property {[@printType field/]} [${fieldName}]
  [/#if]
  [/#list]
 */

[#else]
/**
  [#if d.description?has_content]
    ${global.innerComment(d.description)}[#lt]
 *
  [/#if]
 * @readonly
 * @enum
 */
var ${d.type} = {
  [#list d.enum as value]
    [#if global.needsConverter(d)]
  ${value.name}: "${(value.args![])[0]!value.name}"[#sep],[/#sep]
    [#else]
  ${value.name!value}: "${value.name!value}"[#sep],[/#sep]
    [/#if]
  [/#list]
};
[/#if]

[/#list]
[#-- @formatter:on --]
