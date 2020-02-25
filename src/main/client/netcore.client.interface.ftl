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

using System;
using System.Collections.Generic;
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
  public interface IFusionAuthAsyncClient {
    [#list apis as api]

    /// <summary>
      [#list api.comments as comment]
    /// ${comment}
      [/#list]
    /// This is an asynchronous method.
    /// </summary>
      [#list api.params![] as param]
        [#if !param.constant??]
    /// <param name="${param.name}"> ${param.comments?join("\n    /// ")}</param>
        [/#if]
      [/#list]
    /// <returns>
    /// When successful, the response will contain the log of the action. If there was a validation error or any
    /// other type of error, this will return the Errors object in the response. Additionally, if FusionAuth could not be
    /// contacted because it is down or experiencing a failure, the response will contain an Exception, which could be an
    /// IOException.
    /// </returns>
     [#if api.deprecated??]
    [Obsolete("${api.deprecated?replace("{{renamedMethod}}",(api.renamedMethod!'')?cap_first + "Async")}")]
     [/#if]
    Task<ClientResponse<${global.convertType(api.successResponse, "csharp")}>> ${api.methodName?cap_first}Async(${global.methodParameters(api, "csharp")});
    [/#list]
  }

 public interface IFusionAuthSyncClient {
   [#list apis as api]

   /// <summary>
     [#list api.comments as comment]
   /// ${comment}
     [/#list]
   /// </summary>
     [#list api.params![] as param]
       [#if !param.constant??]
   /// <param name="${param.name}"> ${param.comments?join("\n    /// ")}</param>
       [/#if]
     [/#list]
   /// <returns>
   /// When successful, the response will contain the log of the action. If there was a validation error or any
   /// other type of error, this will return the Errors object in the response. Additionally, if FusionAuth could not be
   /// contacted because it is down or experiencing a failure, the response will contain an Exception, which could be an
   /// IOException.
   /// </returns>
    [#if api.deprecated??]
   [Obsolete("${api.deprecated?replace("{{renamedMethod}}",(api.renamedMethod!'')?cap_first + "Async")}")]
    [/#if]
   ClientResponse<${global.convertType(api.successResponse, "csharp")}> ${api.methodName?cap_first}(${global.methodParameters(api, "csharp")});
   [/#list]
 }
}
