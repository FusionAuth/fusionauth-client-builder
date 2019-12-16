[#--noinspection ALL--]
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

const RESTClient = require('./RESTClient.js');
var Promise = require('promise');
var querystring = require('querystring');

const FusionAuthClient = function(apiKey, host) {
  this.apiKey = apiKey;
  this.host = host;
  this.tenantId = null;
};

FusionAuthClient.constructor = FusionAuthClient;
//noinspection JSUnusedGlobalSymbols
FusionAuthClient.prototype = {

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
   * @return {Promise<ClientResponse<${global.convertType(api.successResponse, "js")}>>} A Promise for the FusionAuth call.
   */
  ${api.methodName}: function(${global.methodParameters(api, "js")}) {
    [#assign formPost = false/]
    [#list api.params![] as param]
      [#if param.type == "form"][#assign formPost = true/][/#if]
    [/#list]
    [#if formPost]
    var body = {
      [#list api.params![] as param]
        [#if param.type == "form"]
      ${param.name}: ${(param.constant?? && param.constant)?then("\""+param.value+"\"", param.name)}[#if param?has_next],[/#if]
        [/#if]
      [/#list]
    };
    [/#if]
    return new Promise((resolve, reject) => {
      this._start[#if api.anonymous??]Anonymous[/#if]()
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
          .setFormBody(body)
      [/#if]
          .${api.method}()
          .go(this._responseHandler(resolve, reject));
    });
  },

[/#list]
  /* ===================================================================================================================
   * Private methods
   * ===================================================================================================================*/

  /**
   * Require a parameter to be defined, if null or un-defined this throws an exception.
   * @param {Object} value The value that must be defined.
   * @param {string} name The name of the parameter.
   * @private
   */
  _requireNonNull: function(value, name) {
    if (typeof value === 'undefined' || value === null) {
      throw new Error(name + ' parameter is required.');
    }
  },

  /**
   * Returns a function to handle the promises for each call.
   *
   * @param {Function} resolve The promise's resolve function.
   * @param {Function} reject The promise's reject function.
   * @returns {Function} The function that will call either the resolve or reject functions based on the ClientResponse.
   * @private
   */
  _responseHandler: function(resolve, reject) {
    return function(response) {
      if (response.wasSuccessful()) {
        resolve(response);
      } else {
        reject(response);
      }
    };
  },

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
    const client = new RESTClient().setUrl(this.host);

    if (this.tenantId !== null && typeof(this.tenantId) !== 'undefined') {
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
    ${global.convertType(type.type, "js")}[#if type.typeArguments?has_content]<[#list type.typeArguments as typeArgument][@printType typeArgument/][#sep], [/#sep][/#list]>[/#if][#t]
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
  ${value.name}: '${(value.args![])[0]!value.name}'[#sep],[/#sep]
    [#else]
  ${value.name!value}: '${value.name!value}'[#sep],[/#sep]
    [/#if]
  [/#list]
};
[/#if]

[/#list]
[#-- @formatter:on --]

module.exports = FusionAuthClient;