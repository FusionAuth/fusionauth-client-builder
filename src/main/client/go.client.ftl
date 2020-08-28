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

package fusionauth

import (
  "bytes"
  "encoding/json"
  "fmt"
  "io"
  "net/http"
  "net/http/httputil"
  "net/url"
  "path"
  "strconv"
  "strings"
  "time"
)

// NewClient creates a new FusionAuthClient
// if httpClient is nil then a DefaultClient is used
func NewClient(httpClient *http.Client, baseURL *url.URL, apiKey string) *FusionAuthClient {
  if httpClient == nil {
    httpClient = &http.Client{
      Timeout: 5 * time.Minute,
    }
  }
  c := &FusionAuthClient{
    HTTPClient: httpClient,
    BaseURL:    baseURL,
    APIKey:     apiKey,
  }

  return c
}

// SetTenantId sets the tenantId on the client
func (c *FusionAuthClient) SetTenantId(tenantId string)  {
  c.TenantId = tenantId
}

// FusionAuthClient describes the Go Client for interacting with FusionAuth's RESTful API
type FusionAuthClient struct {
  HTTPClient *http.Client
  BaseURL    *url.URL
  APIKey     string
  Debug      bool
  TenantId   string
}

type restClient struct {
  Body        io.Reader
  Debug       bool
  ErrorRef    interface{}
  Headers     map[string]string
  HTTPClient  *http.Client
  Method      string
  ResponseRef interface{}
  Uri         *url.URL
}

func (c *FusionAuthClient) Start(responseRef interface{}, errorRef interface{}) *restClient {
  return c.StartAnonymous(responseRef, errorRef).WithAuthorization(c.APIKey)
}

func (c *FusionAuthClient) StartAnonymous(responseRef interface{}, errorRef interface{}) *restClient {
  rc := &restClient{
    Debug:       c.Debug,
    ErrorRef:    errorRef,
    Headers:     make(map[string]string),
    HTTPClient:  c.HTTPClient,
    ResponseRef: responseRef,
  }
  rc.Uri, _ = url.Parse(c.BaseURL.String())
  if c.TenantId != "" {
    rc.WithHeader("X-FusionAuth-TenantId", c.TenantId)
  }
  rc.WithHeader("Content-Type", "text/plain")
  rc.WithHeader("Accept", "application/json")
  return rc
}

func (rc *restClient) Do() error {
  req, err := http.NewRequest(rc.Method, rc.Uri.String(), rc.Body)
  if err != nil {
    return err
  }
  for key, val := range rc.Headers {
    req.Header.Set(key, val)
  }
  resp, err := rc.HTTPClient.Do(req)
  if err != nil {
    return err
  }
  defer resp.Body.Close()
  if rc.Debug {
    responseDump, _ := httputil.DumpResponse(resp, true)
    fmt.Println(string(responseDump))
  }
  if resp.StatusCode < 200 || resp.StatusCode > 299 {
    if rc.ErrorRef != nil {
      err = json.NewDecoder(resp.Body).Decode(rc.ErrorRef)
    }
  } else {
    rc.ErrorRef = nil
    if _, ok := rc.ResponseRef.(*BaseHTTPResponse); !ok {
      err = json.NewDecoder(resp.Body).Decode(rc.ResponseRef)
    }
  }
  rc.ResponseRef.(StatusAble).SetStatus(resp.StatusCode)
  return err
}

func (rc *restClient) WithAuthorization(key string) *restClient {
  if key != "" {
    rc.WithHeader("Authorization", key)
  }
  return rc
}

func (rc *restClient) WithFormData(formBody url.Values) *restClient {
  rc.WithHeader("Content-Type", "application/x-www-form-urlencoded")
  rc.Body = strings.NewReader(formBody.Encode())
  return rc
}

func (rc *restClient) WithHeader(key string, value string) *restClient {
  rc.Headers[key] = value
  return rc
}

func (rc *restClient) WithJSONBody(body interface{}) *restClient {
  rc.WithHeader("Content-Type", "application/json")
  buf := new(bytes.Buffer)
  json.NewEncoder(buf).Encode(body)
  rc.Body = buf
  return rc
}

func (rc *restClient) WithMethod(method string) *restClient {
  rc.Method = method
  return rc
}

func (rc *restClient) WithParameter(key string, value interface{}) *restClient {
  q := rc.Uri.Query()
  if x, ok := value.([]string); ok {
    for _, i := range x {
      q.Add(key, i)
    }
  } else {
    q.Add(key, fmt.Sprintf("%v", value))
  }
  rc.Uri.RawQuery = q.Encode()
  return rc
}

func (rc *restClient) WithUri(uri string) *restClient {
  rc.Uri.Path = path.Join(rc.Uri.Path, uri)
  return rc
}

func (rc *restClient) WithUriSegment(segment string) *restClient {
  if segment != "" {
    rc.Uri.Path = path.Join(rc.Uri.Path, "/"+segment)
  }
  return rc
}

[#-- @formatter:off --]
[#-- Ignoring these few following APIs due to currently being unable to convert the json response into the actual IdentityProvider type. Need a conversion utility. --]
[#assign ignoredAPIs = ["CreateIdentityProvider","RetrieveIdentityProvider","RetrieveIdentityProviders","UpdateIdentityProvider"]/]
[#list apis as api]
  [#if !(ignoredAPIs?seq_contains(api.methodName?cap_first))]
// ${api.methodName?cap_first}
  [#list api.comments as comment]
//${(comment == "")?then('', ' ' +comment)}
  [/#list]
  [#list api.params![] as param]
    [#if !param.constant??]
//   ${global.optional(param, "go")}${global.convertType(param.javaType, "go")} ${global.convertValue(param.name, "go")} ${param.comments?join("\n//   ")}
    [/#if]
  [/#list]
  [#assign parameters = global.methodParameters(api, "go")/]
  [#if api.deprecated??]
//
// Deprecated: ${api.deprecated?replace("{{renamedMethod}}", (api.renamedMethod!'')?cap_first)}
  [/#if]
func (c *FusionAuthClient) ${api.methodName?cap_first}(${parameters}) (*[#if api.successResponse == "Void"]BaseHTTPResponse[#else]${global.convertType(api.successResponse, "go")}[/#if][#if api.errorResponse != "Void"], *${global.convertType(api.errorResponse, "go")}[/#if], error) {
    var resp [#if api.successResponse == "Void"]BaseHTTPResponse[#else]${global.convertType(api.successResponse, "go")}[/#if]
  [#if api.errorResponse != "Void"]
    var errors ${global.convertType(api.errorResponse, "go")}
  [/#if]
  [#assign formPost = false/]
  [#list api.params![] as param]
    [#if param.type == "form"][#assign formPost = true/][/#if]
  [/#list]
  [#if formPost]
    formBody := url.Values{}
    [#list api.params![] as param]
      [#if param.type == "form"]
    formBody.Set("${param.name}", ${(param.constant?? && param.constant)?then("\""+param.value+"\"", global.convertValue(param.name, "go"))})
      [/#if]
    [/#list]
  [/#if]

  [#if api.errorResponse != "Void"]
    restClient := c.Start[#if api.anonymous??]Anonymous[/#if](&resp, &errors)
    err := restClient.WithUri("${api.uri}").
  [#else]
    err := c.Start[#if api.anonymous??]Anonymous[/#if](&resp, nil).
             WithUri("${api.uri}").
  [/#if]
  [#if api.authorization??]
             WithAuthorization(${api.authorization}).
  [/#if]
  [#list api.params![] as param]
    [#if param.type == "urlSegment"]
      [#if !param.constant?? && param.javaType == "Integer"]
        WithUriSegment(strconv.Itoa(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))})).
      [#else]
       WithUriSegment(${(param.constant?? && param.constant)?then(param.value,  global.convertValue(param.name, "go"))}).
      [/#if]
    [#elseif param.type == "urlParameter"]
      [#if param.javaType??][#assign goType = global.convertType(param.javaType, "go")/][/#if]
      [#if param.value?? && param.value == "true"]
        WithParameter("${param.parameterName}", strconv.FormatBool(true)).
      [#elseif param.value?? && param.value == "false"]
        WithParameter("${param.parameterName}", strconv.FormatBool(false)).
      [#elseif !param.constant?? && goType == "bool"]
        WithParameter("${param.parameterName}", strconv.FormatBool(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))})).
      [#elseif !param.constant?? && goType == "[]string"]
        WithParameter("${param.parameterName}", ${global.convertValue(param.name, "go")}).
      [#elseif !param.constant?? && goType == "interface{}"]
        WithParameter("${param.parameterName}", ${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}.(string)).
      [#elseif !param.constant?? && goType == "int"]
        WithParameter("${param.parameterName}", strconv.Itoa(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))})).
      [#elseif !param.constant?? && goType == "int64"]
        WithParameter("${param.parameterName}", strconv.FormatInt(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))}, 10)).
      [#elseif !param.constant?? && goType == "string"]
        WithParameter("${param.parameterName}", ${(param.constant?? && param.constant)?then("\""+param.value+"\"", global.convertValue(param.name, "go"))}).
      [#else]
        WithParameter("${param.parameterName}", string(${(param.constant?? && param.constant)?then(param.value, global.convertValue(param.name, "go"))})).
      [/#if]
    [#elseif param.type == "body"]
      WithJSONBody(${global.convertValue(param.name, "go")}).
    [/#if]
  [/#list]
  [#if formPost]
    WithFormData(formBody).
  [/#if]
    WithMethod(http.Method${api.method?capitalize}).
    Do()
  [#if api.errorResponse != "Void"]
    if restClient.ErrorRef == nil {
      return &resp, nil, err
    }
    return &resp, &errors, err
  [#else]
    return &resp, err
  [/#if]
}

  [/#if]
[/#list]
[#-- @formatter:on --]
