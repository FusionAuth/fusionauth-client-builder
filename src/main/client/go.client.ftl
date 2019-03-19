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

package client

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
)

// FusionAuthClient describes the Go Client for interacting with FusionAuth's RESTful API
type FusionAuthClient struct {
	BaseURL    *url.URL
	APIKey     string
	httpClient *http.Client
}

[#-- @formatter:off --]
[#list apis as api]
  [#list api.comments as comment]
   // ${comment}
  [/#list]
  [#list api.params![] as param]
    [#if !param.constant??]
   //   ${global.optional(param, "go")}${global.convertType(param.javaType, "go")} ${param.name} ${param.comments?join("\n   *    ")}
    [/#if]
  [/#list]
  [#assign parameters = global.methodParameters(api, "go")/]
func (c *FusionAuthClient) ${api.methodName}(${parameters})) (interface{}, error) {
    var body interface{}
    uri := ${api.uri}
    method := http.Method${api.method?capitalize}
  [#list api.params![] as param]
    [#if param.type == "urlSegment"]
    uri = uriWithSegment(uri, ${(param.constant?? && param.constant)?then(param.value, param.name)})
    [#elseif param.type == "body"]
    body = ${param.name}
    [/#if]
  [/#list]
  req, err := c.newRequest(method, uri, body)
  [#list api.params![] as param]
    [#if param.type == "urlParameter"]
    q := req.URL.Query()
    q.add("${param.parameterName}","${(param.constant?? && param.constant)?then(param.value, param.name)}")
    [#elseif param.type == "body"]
    req.Header.Set("Content-Type", "application/json")
    [/#if]
  [/#list]
  [#if api.method == "post" && !global.hasBodyParam(api.params![])]
    req.Header.Set("Content-Type", "text/plain")
  [/#if]
  [#if api.authorization??]
    req.Header.Set("Authorization", c.APIKey)
  [/#if]
  }

[/#list]
[#-- @formatter:on --]