[#import "_macros.ftl" as global/]
[#function parameter_value param]
  [#if param.constant?? && param.constant]
    [#if param.value?starts_with("search")]
      [#return "$" + param.value/] [#-- Hack for the search functions --]
    [#else]
      [#return param.value/]
    [/#if]
  [#else]
    [#return "$" + param.name/]
  [/#if]
[/#function]
<?php
namespace FusionAuth;

/*
 * Copyright (c) 2018-${.now?string('yyyy')}, FusionAuth, All Rights Reserved
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

/**
 * Client that connects to a FusionAuth server and provides access to the full set of FusionAuth APIs.
 * <p/>
 * When any method is called the return value is always a ClientResponse object. When an API call was successful, the
 * response will contain the response from the server. This might be empty or contain an success object or an error
 * object. If there was a validation error or any other type of error, this will return the Errors object in the
 * response. Additionally, if FusionAuth could not be contacted because it is down or experiencing a failure, the response
 * will contain an Exception, which could be an IOException.
 *
 * @author Brian Pontarelli
 */
class FusionAuthClient
{
  /**
   * @var string
   */
  private $apiKey;

  /**
   * @var string
   */
  private $baseURL;

  /**
   * @var string
   */
  private $tenantId;

  /**
   * @var int
   */
  public $connectTimeout = 2000;

  /**
   * @var int
   */
  public $readTimeout = 2000;

  public function __construct($apiKey, $baseURL)
  {
    include_once 'RESTClient.php';
    $this->apiKey = $apiKey;
    $this->baseURL = $baseURL;
  }

  public function withTenantId($tenantId) {
    $this->tenantId = $tenantId;
    return $this;
  }

[#list apis as api]
  /**
  [#list api.comments as comment]
   * ${comment}
  [/#list]
   *
  [#list api.params![] as param]
    [#if !param.constant??]
   * @param ${global.convertType(param.javaType, "php")} $${param.name} ${param.comments?join("\n  *     ")}
    [/#if]
  [/#list]
   *
   * @return ClientResponse The ClientResponse.
   * @throws \Exception
[#if api.deprecated??]
   * @deprecated ${api.deprecated?replace("{{renamedMethod}}", api.renamedMethod!'')}
[/#if]
   */
  public function ${api.methodName}(${global.methodParameters(api, "php")})
  {
    [#assign formPost = false/]
    [#assign hasFormParams = false/]
    [#list api.params![] as param]
      [#if param.type == "form" || param.type == "formBody"][#assign formPost = true/][/#if]
      [#if param.type == "form"][#assign hasFormParams = true/][/#if]
    [/#list]
    [#if formPost]
    $post_data = array(
      [#list api.params![] as param]
        [#if param.type == "form"]
      '${param.name}' => ${(param.constant?? && param.constant)?then("'"+param.value+"'", "$"+param.name)}[#if param?has_next],[/#if]
        [#elseif param.type == "formBody"]
          [#-- Lookup the domain object by javaType --]
          [#list domain as d]
            [#if d.type == param.javaType]
              [#-- Iterate through all fields in the domain object --]
              [#list d.fields as fieldName, field]
                 [#if field.type == "String"]
      [#if fieldName?is_first && !hasFormParams][#else],[/#if]'${fieldName}' => $request->${fieldName}
                 [#else]
      [#if fieldName?is_first && !hasFormParams][#else],[/#if]'${fieldName}' => ($request->${fieldName} !== null ? (string)$request->${fieldName} : null)
                [/#if]
              [/#list]
            [/#if]
          [/#list]
        [/#if]
      [/#list]
    );
    [/#if]
    return $this->start[#if api.anonymous??]Anonymous[/#if]()->uri("${api.uri}")
    [#if api.authorization??]
        ->authorization(${api.authorization?replace("+ ", ". $")})
    [/#if]
    [#list api.params![] as param]
      [#if param.type == "urlSegment"]
        ->urlSegment(${(param.constant?? && param.constant)?then(param.value, "$" + param.name)})
      [#elseif param.type == "urlParameter"]
        ->urlParameter("${param.parameterName}", ${parameter_value(param)})
      [#elseif param.type == "queryBody"]
        [#list domain as d]
          [#if d.type == param.javaType]
            [#list d.fields as fieldName, field]
              [#if field.type == "String"]
        ->urlParameter("${fieldName}", $request->${fieldName})
              [#else]
        ->urlParameter("${fieldName}", $request->${fieldName} !== null ? (string)$request->${fieldName} : null)
              [/#if]
            [/#list]
          [/#if]
        [/#list]
      [#elseif param.type == "body"]
        ->bodyHandler(new JSONBodyHandler($${param.name}))
      [/#if]
    [/#list]
    [#if formPost]
        ->bodyHandler(new FormDataBodyHandler($post_data))
    [/#if]
        ->${api.method}()
        ->go();
  }

[/#list]

  private function start()
  {
    return $this->startAnonymous()->authorization($this->apiKey);
  }

  private function startAnonymous()
  {
    $rest = new RESTClient();
    if (isset($this->tenantId)) {
      $rest->header("X-FusionAuth-TenantId", $this->tenantId);
    }
    return $rest->url($this->baseURL)
        ->connectTimeout($this->connectTimeout)
        ->readTimeout($this->readTimeout)
        ->successResponseHandler(new JSONResponseHandler())
        ->errorResponseHandler(new JSONResponseHandler());
  }
}
