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
  "encoding/base64"
  "encoding/json"
  "fmt"
  "io"
  "net/http"
  "net/http/httputil"
  "net/url"
  "strconv"
  "strings"
)

// NewFusionAuthClient creates a new FusionAuthClient
// if httpClient is nil then a DefaultClient is used
func NewFusionAuthClient(httpClient *http.Client, baseURL *url.URL, apiKey string) *FusionAuthClient {
  if httpClient == nil {
    httpClient = http.DefaultClient
  }
  c := &FusionAuthClient{
    HTTPClient: httpClient,
    BaseURL:    baseURL,
    APIKey:     apiKey}

  return c
}

// URIWithSegment returns a string with a "/" delimiter between the uri and segment
// If segment is not set (""), just the uri is returned
func URIWithSegment(uri, segment string) string {
	if segment == "" {
		return uri
	}
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
	if c.APIKey != "" {
		// Send the API Key, but only if it is set
		req.Header.Set("Authorization", c.APIKey)
	}
	req.Header.Set("Accept", "application/json")
	return req, nil
}

// Do makes the request to the FusionAuth API endpoint and decodes the response
func (c *FusionAuthClient) Do(req *http.Request, v interface{}, e interface{}) (*http.Response, error) {
  resp, err := c.HTTPClient.Do(req)
  if err != nil {
    return nil, err
  }
  defer resp.Body.Close()
  if c.Debug {
    responseDump, _ := httputil.DumpResponse(resp, true)
    fmt.Println(string(responseDump))
  }
  if resp.StatusCode < 200 || resp.StatusCode > 299 {
    if e != nil {
      err = json.NewDecoder(resp.Body).Decode(e)
    }
  } else {
    err = json.NewDecoder(resp.Body).Decode(v)
  }
  return resp, err
}

// FusionAuthClient describes the Go Client for interacting with FusionAuth's RESTful API
type FusionAuthClient struct {
  HTTPClient *http.Client
  BaseURL    *url.URL
  APIKey     string
  Debug      bool
}

[#-- @formatter:off --]
[#-- Ignoring these few following APIs due to currently being unable to convert the json response into the actual IdentityProvider type. Need a conversion utility. --]
[#assign ignoredAPIs = ["CreateIdentityProvider","RetrieveIdentityProvider","RetrieveIdentityProviders","UpdateIdentityProvider"]/]
[#list apis as api]
  [#if !(ignoredAPIs?seq_contains(api.methodName?cap_first))]
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
func (c *FusionAuthClient) ${api.methodName?cap_first}(${parameters}) (*[#if api.successResponse == "Void"]BaseHTTPResponse[#else]${global.convertType(api.successResponse, "go")}[/#if][#if api.errorResponse != "Void"], *${global.convertType(api.errorResponse, "go")}[/#if], error) {
    method := http.Method${api.method?capitalize}
    uri := "${api.uri}"
    var body interface{}
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
    if err != nil {
      return nil, [#if api.errorResponse != "Void"]nil, [/#if]err
    }
  [#list api.params![] as param]
    [#if param.type == "urlParameter"]
    q := req.URL.Query()
      [#break]
    [/#if]
  [/#list]
  [#list api.params![] as param]
    [#if param.type == "urlParameter"]
      [#if param.javaType??][#assign goType = global.convertType(param.javaType, "go")/][/#if]
      [#if param.value?? && param.value == "true"]
    q.Add("${param.parameterName}", strconv.FormatBool(true))
      [#elseif param.value?? && param.value == "false"]
    q.Add("${param.parameterName}", strconv.FormatBool(false))
      [#elseif !param.constant?? && goType == "bool"]
    q.Add("${param.parameterName}", strconv.FormatBool(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}))
      [#elseif !param.constant?? && goType == "[]string"]
    for _, ${global.convertValue(param.parameterName, "go")} := range ${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))} {
 		  q.Add("${param.parameterName}", ${global.convertValue(param.parameterName, "go")})
 	  }
      [#elseif !param.constant?? && goType == "interface{}"]
    q.Add("${param.parameterName}", ${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}.(string))
      [#elseif !param.constant?? && goType == "int"]
    q.Add("${param.parameterName}", strconv.Itoa(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}))
      [#elseif !param.constant?? && goType == "int64"]
    q.Add("${param.parameterName}", strconv.FormatInt(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}, 10))
      [#else]
    q.Add("${param.parameterName}", string(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}))
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
    var resp [#if api.successResponse == "Void"]interface{}[#else]${global.convertType(api.successResponse, "go")}[/#if]
    [#if api.errorResponse != "Void"]
    var errors ${global.convertType(api.errorResponse, "go")}
    [/#if]
    httpResponse, err := c.Do(req, &resp[#if api.errorResponse != "Void"], &errors[#else], nil[/#if])
  [#if api.successResponse != "Void"]
    if httpResponse != nil {
      resp.StatusCode = httpResponse.StatusCode
      [#if api.errorResponse != "Void"]
      if resp.StatusCode >= 200 && resp.StatusCode <= 299 {
        return [#if api.successResponse != "Void"]&resp,[#else]&baseResponse,[/#if] nil, err
      }
      [/#if]
    }
  [#else]
    baseResponse := BaseHTTPResponse{StatusCode: httpResponse.StatusCode}
    if httpResponse != nil {
      baseResponse.StatusCode = httpResponse.StatusCode
    }
  [/#if]
    return [#if api.successResponse != "Void"]&resp,[#else]&baseResponse,[/#if][#if api.errorResponse != "Void"] &errors,[/#if] err
}

  [/#if]
[/#list]
[#-- @formatter:on --]

// ExchangeOAuthCodeForAccessToken
// Exchanges an OAuth authorization code for an access token.
//   string code The OAuth authorization code.
//   string clientID The OAuth client_id.
//   string clientSecret (Optional: use "" to disregard this parameter) The OAuth client_secret used for Basic Auth.
//   string redirectURI The OAuth redirect_uri.
func (c *FusionAuthClient) ExchangeOAuthCodeForAccessToken(code string, clientID string, clientSecret string, redirectURI string) (interface{}, *Errors, error) {
  // URL
  rel := &url.URL{Path: "/oauth2/token"}
  u := c.BaseURL.ResolveReference(rel)
  // Body
  body := url.Values{}
  body.Set("code", code)
  body.Set("grant_type", "authorization_code")
  body.Set("client_id", clientID)
  body.Set("redirect_uri", redirectURI)
  encodedBody := strings.NewReader(body.Encode())
  // Request
  method := http.MethodPost
  req, err := http.NewRequest(method, u.String(), encodedBody)
  req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
  // Basic Auth (optional)
  if clientSecret != "" {
    credentials := clientID + ":" + clientSecret
    encoded := base64.StdEncoding.EncodeToString([]byte(credentials))
    req.Header.Set("Authorization", "Basic " + encoded)
  }
  var resp interface{}
  var errors Errors
  _, err = c.Do(req, &resp, &errors)
  return resp, &errors, err
}
