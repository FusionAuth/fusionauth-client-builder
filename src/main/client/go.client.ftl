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
  "fmt"
  "io"
	"net/http"
  "net/http/httputil"
  "net/url"
)

// URIWithSegment returns a string with a "/" delimiter between the uri and segment
func URIWithSegment(uri, segment string) string {
	return uri + "/" + segment
}

// NewRequest creates a new request for the FusionAuth API call
func (c *FusionAuthClient) NewRequest(method, endpoint string, body interface{}) (*http.Request, error) {
	rel := &url.URL{Path: endpoint}
	u := c.BaseURL.ResolveReference(rel)
	var buf io.ReadWriter
	if body != nil {
		buf = new(bytes.Buffer)
		err := json.NewEncoder(buf).Encode(body)
		if err != nil {
			return nil, err
		}
	}
	req, err := http.NewRequest(method, u.String(), buf)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	return req, nil
}

// Do makes the request to the FusionAuth API endpoint and decodes the response
func (c *FusionAuthClient) Do(req *http.Request, v interface{}) (*http.Response, error) {
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	responseDump, _ := httputil.DumpResponse(resp, true)
	fmt.Println(string(responseDump))
	err = json.NewDecoder(resp.Body).Decode(v)
	return resp, err
}

// FusionAuthClient describes the Go Client for interacting with FusionAuth's RESTful API
type FusionAuthClient struct {
	BaseURL    *url.URL
	APIKey     string
	HTTPClient *http.Client
}

[#-- @formatter:off --]
[#list apis as api]
// ${api.methodName?cap_first}
  [#list api.comments as comment]
// ${comment}
  [/#list]
  [#list api.params![] as param]
    [#if !param.constant??]
//   ${global.optional(param, "go")}${global.convertType(param.javaType, "go")} ${param.name} ${param.comments?join("\n//   ")}
    [/#if]
  [/#list]
  [#assign parameters = global.methodParameters(api, "go")/]
func (c *FusionAuthClient) ${api.methodName?cap_first}(${parameters}) (interface{}, error) {
    var body interface{}
    uri := "${api.uri}"
    method := http.Method${api.method?capitalize}
  [#list api.params![] as param]
    [#if param.type == "urlSegment"]
      [#if !param.constant?? && param.javaType == "Integer"]
    uri = URIWithSegment(uri, string(${(param.constant?? && param.constant)?then(param.value, param.name)}))
      [#else]
    uri = URIWithSegment(uri, ${(param.constant?? && param.constant)?then(param.value, param.name)})
      [/#if]
    [#elseif param.type == "body"]
    body = ${param.name}
    [/#if]
  [/#list]
    req, err := c.NewRequest(method, uri, body)
  [#list api.params![] as param]
    [#if param.type == "urlParameter"]
    q := req.URL.Query()
      [#break]
    [/#if]
  [/#list]
  [#list api.params![] as param]
    [#if param.type == "urlParameter"]
      [#if param.value?? && param.value == "true"]
    q.Add("${param.parameterName}", strconv.FormatBool(true))
      [#elseif param.value?? && param.value == "false"]
    q.Add("${param.parameterName}", strconv.FormatBool(false))
      [#elseif !param.constant?? && param.javaType == "boolean"]
    q.Add("${param.parameterName}", strconv.FormatBool(${(param.constant?? && param.constant)?then(param.value, param.name)}))
      [#elseif !param.constant?? && global.convertType(param.javaType, "go") == "[]string"] 
    for _, ${param.parameterName} := range ${(param.constant?? && param.constant)?then(param.value, param.name)} {
 		  q.Add("${param.parameterName}", ${param.parameterName})
 	  }
      [#elseif !param.constant?? && global.convertType(param.javaType, "go") == "interface{}"]
    q.Add("${param.parameterName}", ${(param.constant?? && param.constant)?then(param.value, param.name)}.(string)) 
      [#else]
    q.Add("${param.parameterName}", string(${(param.constant?? && param.constant)?then(param.value, param.name)}))
      [/#if]
    [#elseif param.type == "body"]
    req.Header.Set("Content-Type", "application/json")
    [/#if]
  [/#list]
  [#if api.method == "post" && !global.hasBodyParam(api.params![])]
    req.Header.Set("Content-Type", "text/plain")
  [/#if]
  [#if api.authorization??]
    req.Header.Set("Authorization", ${api.authorization})
  [/#if]
    var resp interface{} 
    _, err = c.Do(req, &resp)
    return resp, err
}

[/#list]
[#-- @formatter:on --]