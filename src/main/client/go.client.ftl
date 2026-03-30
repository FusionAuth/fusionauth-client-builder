[#import "_macros.ftl" as global/]
/*
* Copyright (c) 2019-${.now?string('yyyy')}, FusionAuth, All Rights Reserved
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
  "context"
  "encoding/json"
  "fmt"
  "io"
  "math"
  "math/rand"
  "net/http"
  "net/http/httputil"
  "net/url"
  "os"
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

// NewClientWithRetryConfiguration creates a new FusionAuthClient with the provided retry configuration.
// if httpClient is nil then a DefaultClient is used.
// Use NewBasicRetryConfiguration for sensible retry defaults.
func NewClientWithRetryConfiguration(httpClient *http.Client, baseURL *url.URL, apiKey string, retryConfiguration *RetryConfiguration) *FusionAuthClient {
  if httpClient == nil {
    httpClient = &http.Client{
      Timeout: 5 * time.Minute,
    }
  }
  c := &FusionAuthClient{
    HTTPClient:         httpClient,
    BaseURL:            baseURL,
    APIKey:             apiKey,
    RetryConfiguration: retryConfiguration,
  }

  return c
}

// SetTenantId sets the tenantId on the client
func (c *FusionAuthClient) SetTenantId(tenantId string) {
  c.TenantId = tenantId
}

// RetryConfiguration configures automatic retry of failed HTTP requests.
// A nil RetryConfiguration (the default) means no retries are performed.
// Use NewBasicRetryConfiguration for sensible retry defaults.
type RetryConfiguration struct {
  // AllowNonIdempotentRetries when true, all HTTP methods including POST will be retried.
  // Defaults to false, meaning only idempotent methods (GET, PUT, DELETE, PATCH, HEAD) are retried.
  AllowNonIdempotentRetries bool
  // BackoffMultiplier is the multiplier applied to the delay between each retry attempt. Defaults to 2.0.
  BackoffMultiplier float64
  // InitialDelay is the initial delay before the first retry. Defaults to 100ms.
  InitialDelay time.Duration
  // Jitter is the maximum random jitter multiplier added to every delay, in the range [0.0, 1.0].
  // Actual jitter is randomly chosen between 0.0 and this value. Defaults to 0.20.
  Jitter float64
  // MaxDelay is the maximum delay between retry attempts. Defaults to 30s.
  MaxDelay time.Duration
  // MaxRetries is the number of additional attempts after the initial request.
  // 0 effectively disables retries. Defaults to 4.
  MaxRetries int
  // RetryFunction is an optional function called to determine if a response warrants a retry,
  // in addition to the built-in retryable status code checks. Return true to retry.
  RetryFunction func(statusCode int, body []byte) bool
  // RetryOnNetworkError when true, requests that fail due to network errors will be retried. Defaults to true.
  RetryOnNetworkError bool
  // RetryableStatusCodes is the set of HTTP status codes that trigger a retry.
  // Defaults to {429, 500, 502, 503, 504}.
  RetryableStatusCodes map[int]struct{}
}

// NewBasicRetryConfiguration returns a RetryConfiguration with sensible defaults.
// It retries on status codes 429, 500, 502, 503, 504 and on retryableConflict (409) errors,
// using exponential backoff with 20% jitter.
func NewBasicRetryConfiguration() *RetryConfiguration {
  return &RetryConfiguration{
    BackoffMultiplier:   2.0,
    InitialDelay:        100 * time.Millisecond,
    Jitter:              0.20,
    MaxDelay:            30 * time.Second,
    MaxRetries:          4,
    RetryOnNetworkError: true,
    RetryableStatusCodes: map[int]struct{}{
      429: {},
      500: {},
      502: {},
      503: {},
      504: {},
    },
    RetryFunction: func(statusCode int, body []byte) bool {
      return statusCode == http.StatusConflict && bytes.Contains(body, []byte("[retryableConflict]"))
    },
  }
}

// RetryConfigurationFromEnv returns NewBasicRetryConfiguration if the FUSIONAUTH_ENABLE_RETRY
// environment variable is set to "true", otherwise returns nil (no retries).
// This is useful for Terraform providers and other tools that want to opt-in to retries via
// an environment variable.
func RetryConfigurationFromEnv() *RetryConfiguration {
  if os.Getenv("FUSIONAUTH_ENABLE_RETRY") == "true" {
    return NewBasicRetryConfiguration()
  }
  return nil
}

func (cfg *RetryConfiguration) validate() error {
  if cfg.MaxRetries < 0 {
    return fmt.Errorf("RetryConfiguration: MaxRetries must be non-negative")
  }
  if cfg.InitialDelay < 0 {
    return fmt.Errorf("RetryConfiguration: InitialDelay must be non-negative")
  }
  if cfg.MaxDelay < 0 {
    return fmt.Errorf("RetryConfiguration: MaxDelay must be non-negative")
  }
  if cfg.Jitter < 0.0 || cfg.Jitter > 1.0 {
    return fmt.Errorf("RetryConfiguration: Jitter must be in the range [0.0, 1.0]")
  }
  if cfg.BackoffMultiplier < 0 {
    return fmt.Errorf("RetryConfiguration: BackoffMultiplier must be non-negative")
  }
  return nil
}

func (cfg *RetryConfiguration) calculateDelay(attempt int) time.Duration {
  backoff := float64(cfg.InitialDelay) * math.Pow(cfg.BackoffMultiplier, float64(attempt-1))
  if float64(cfg.MaxDelay) > 0 && backoff > float64(cfg.MaxDelay) {
    backoff = float64(cfg.MaxDelay)
  }
  if cfg.Jitter > 0 {
    backoff *= 1.0 + rand.Float64()*cfg.Jitter
  }
  return time.Duration(backoff)
}

// FusionAuthClient describes the Go Client for interacting with FusionAuth's RESTful API
type FusionAuthClient struct {
  HTTPClient         *http.Client
  BaseURL            *url.URL
  APIKey             string
  Debug              bool
  TenantId           string
  RetryConfiguration *RetryConfiguration
}

type restClient struct {
  Body               io.Reader
  bodyBytes          []byte
  Debug              bool
  ErrorRef           interface{}
  Headers            map[string]string
  HTTPClient         *http.Client
  Method             string
  ResponseRef        interface{}
  RetryConfiguration *RetryConfiguration
  Uri                *url.URL
}

func (c *FusionAuthClient) Start(responseRef interface{}, errorRef interface{}) *restClient {
  return c.StartAnonymous(responseRef, errorRef).WithAuthorization(c.APIKey)
}

func (c *FusionAuthClient) StartAnonymous(responseRef interface{}, errorRef interface{}) *restClient {
  rc := &restClient{
    Debug:              c.Debug,
    ErrorRef:           errorRef,
    Headers:            make(map[string]string),
    HTTPClient:         c.HTTPClient,
    ResponseRef:        responseRef,
    RetryConfiguration: c.RetryConfiguration,
  }
  rc.Uri, _ = url.Parse(c.BaseURL.String())
  if c.TenantId != "" {
    rc.WithHeader("X-FusionAuth-TenantId", c.TenantId)
  }

  rc.WithHeader("Accept", "application/json")
  return rc
}

func (rc *restClient) Do(ctx context.Context) error {
  if rc.RetryConfiguration != nil {
    if err := rc.RetryConfiguration.validate(); err != nil {
      return err
    }
  }

  // Buffer the request body once so it can be replayed on retries.
  if rc.Body != nil {
    b, err := io.ReadAll(rc.Body)
    if err != nil {
      return err
    }
    rc.bodyBytes = b
    rc.Body = nil
  }

  maxAttempts := 1
  if rc.RetryConfiguration != nil && rc.RetryConfiguration.MaxRetries > 0 {
    maxAttempts = 1 + rc.RetryConfiguration.MaxRetries
  }

  for attempt := 0; attempt < maxAttempts; attempt++ {
    if attempt > 0 {
      delay := rc.RetryConfiguration.calculateDelay(attempt)
      if delay > 0 {
        select {
        case <-ctx.Done():
          return ctx.Err()
        case <-time.After(delay):
        }
      }
    }

    var body io.Reader
    if rc.bodyBytes != nil {
      body = bytes.NewReader(rc.bodyBytes)
    }
    req, err := http.NewRequestWithContext(ctx, rc.Method, rc.Uri.String(), body)
    if err != nil {
      return err
    }
    for key, val := range rc.Headers {
      req.Header.Set(key, val)
    }

    resp, err := rc.HTTPClient.Do(req)
    if err != nil {
      // Retry on network error if configured and method is retryable.
      if attempt < maxAttempts-1 && rc.RetryConfiguration != nil &&
        rc.RetryConfiguration.RetryOnNetworkError && rc.isMethodRetryable() {
        continue
      }
      return err
    }
    respBody, readErr := io.ReadAll(resp.Body)
    resp.Body.Close()
    if readErr != nil {
      return readErr
    }

    if rc.Debug {
      resp.Body = io.NopCloser(bytes.NewReader(respBody))
      responseDump, _ := httputil.DumpResponse(resp, true)
      fmt.Println(string(responseDump))
    }

    // Check whether this response should trigger a retry.
    if attempt < maxAttempts-1 && rc.RetryConfiguration != nil && rc.isMethodRetryable() {
      if rc.shouldRetry(resp.StatusCode, respBody) {
        continue
      }
    }

    if resp.StatusCode < 200 || resp.StatusCode > 299 {
      if err = json.NewDecoder(bytes.NewReader(respBody)).Decode(rc.ErrorRef); err == io.EOF {
        err = nil
      }
    } else {
      rc.ErrorRef = nil
      if _, ok := rc.ResponseRef.(*BaseHTTPResponse); !ok {
        err = json.NewDecoder(bytes.NewReader(respBody)).Decode(rc.ResponseRef)
      }
    }
    rc.ResponseRef.(StatusAble).SetStatus(resp.StatusCode)
    return err
  }
  return nil
}

// isMethodRetryable returns true if the HTTP method is safe to retry.
// Idempotent methods (GET, PUT, DELETE, PATCH, HEAD) are always retryable.
// POST is retryable only when AllowNonIdempotentRetries is true.
func (rc *restClient) isMethodRetryable() bool {
  if rc.RetryConfiguration.AllowNonIdempotentRetries {
    return true
  }
  switch rc.Method {
  case http.MethodGet, http.MethodPut, http.MethodDelete, http.MethodPatch, http.MethodHead:
    return true
  }
  return false
}

// shouldRetry returns true if the status code or body indicates a retryable failure.
func (rc *restClient) shouldRetry(statusCode int, body []byte) bool {
  if _, ok := rc.RetryConfiguration.RetryableStatusCodes[statusCode]; ok {
    return true
  }
  if rc.RetryConfiguration.RetryFunction != nil {
    return rc.RetryConfiguration.RetryFunction(statusCode, body)
  }
  return false
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
[#assign ignoredAPIs = ["CreateIdentityProvider","IntrospectAccessToken","IntrospectAccessTokenWithRequest","IntrospectClientCredentialsAccessToken","IntrospectClientCredentialsAccessTokenWithRequest","RetrieveIdentityProvider","RetrieveIdentityProviders","RetrieveUserInfoFromAccessToken","UpdateIdentityProvider"]/]
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
    return c.${api.methodName?cap_first}WithContext(context.TODO()[#list api.params![] as param][#if !param.constant??], ${global.convertValue(param.name, "go")}[/#if][/#list])
}

// ${api.methodName?cap_first}WithContext
  [#list api.comments as comment]
//${(comment == "")?then('', ' ' +comment)}
  [/#list]
  [#list api.params![] as param]
    [#if !param.constant??]
//   ${global.optional(param, "go")}${global.convertType(param.javaType, "go")} ${global.convertValue(param.name, "go")} ${param.comments?join("\n//   ")}
    [/#if]
  [/#list]
  [#if api.deprecated??]
//
// Deprecated: ${api.deprecated?replace("{{renamedMethod}}", (api.renamedMethod!'')?cap_first+"WithContext")}
  [/#if]
func (c *FusionAuthClient) ${api.methodName?cap_first}WithContext(ctx context.Context[#if (parameters?length > 0)], [/#if]${parameters}) (*[#if api.successResponse == "Void"]BaseHTTPResponse[#else]${global.convertType(api.successResponse, "go")}[/#if][#if api.errorResponse != "Void"], *${global.convertType(api.errorResponse, "go")}[/#if], error) {
    var resp [#if api.successResponse == "Void"]BaseHTTPResponse[#else]${global.convertType(api.successResponse, "go")}[/#if]
  [#if api.errorResponse != "Void"]
    var errors ${global.convertType(api.errorResponse, "go")}
  [/#if]
  [#assign formPost = false/]
  [#list api.params![] as param]
    [#if param.type == "form" || param.type == "formBody"][#assign formPost = true/][/#if]
  [/#list]
  [#if formPost]
    formBody := url.Values{}
    [#list api.params![] as param]
      [#if param.type == "form"]
    formBody.Set("${param.name}", ${(param.constant?? && param.constant)?then("\""+param.value+"\"", global.convertValue(param.name, "go"))})
      [#elseif param.type == "formBody"]
        [#-- Lookup the domain object by javaType --]
        [#list domain as d]
          [#if d.type == param.javaType]
            [#-- Iterate through all fields in the domain object --]
            [#list d.fields as fieldName, field]
              [#if field.type == "UUID" || field.type == "String"]
    formBody.Set("${fieldName}", request.${global.toCamelCase(fieldName)?cap_first})
              [#else]
    if request.${global.toCamelCase(fieldName)?cap_first} != nil {
        formBody.Set("${fieldName}", fmt.Sprintf("%v", request.${global.toCamelCase(fieldName)?cap_first}))
    }
              [/#if]
            [/#list]
          [/#if]
        [/#list]
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
    [#elseif param.type == "queryBody"]
      [#list domain as d]
        [#if d.type == param.javaType]
          [#list d.fields as fieldName, field]
            [#if field.type == "UUID" || field.type == "String"]
        WithParameter("${fieldName}", request.${global.toCamelCase(fieldName)?cap_first}).
            [#else]
        WithParameter("${fieldName}", fmt.Sprintf("%v", request.${global.toCamelCase(fieldName)?cap_first})).
            [/#if]
          [/#list]
        [/#if]
      [/#list]
    [#elseif param.type == "body"]
      WithJSONBody(${global.convertValue(param.name, "go")}).
    [/#if]
  [/#list]
  [#if formPost]
    WithFormData(formBody).
  [/#if]
    WithMethod(http.Method${api.method?capitalize}).
    Do(ctx)
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
