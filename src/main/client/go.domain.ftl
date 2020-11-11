[#-- @ftlvariable name="packages" type="String[]" --]
[#-- @ftlvariable name="types_in_use" type="String[]" --]
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

[#import "_macros.ftl" as global/]

[#function printType type parent]
  [#local goType = global.convertType(type.type, "go")/]
  [#if goType == "List" || goType == "Array" || goType == "Set" || goType == "SortedSet"]
    [#return "[]" + printType(type.typeArguments?first, parent)/]
  [#elseif goType == "Map" || goType == "HashMap"]
    [#return "map[" + printType(type.typeArguments[0], parent) + "]" + printType(type.typeArguments[1], parent)/]
  [#else]
    [#return hackCollisions(parent, goType)/]
  [/#if]
[/#function]

[#assign ignoredPackages = ["api","email","event","jwt","oauth2","search"]/]
[#function getSubPackage package]
  [#local subPackage = ""/]
  [#list package?keep_after("io.fusionauth.domain.")?split(".") as pkg]
    [#if !(ignoredPackages?seq_contains(pkg))]
      [#local subPackage += pkg?cap_first/]
    [/#if]
  [/#list]
  [#return subPackage/]
[/#function]

[#macro addFunctions struct]
  [#if struct == "Errors" ]
func (e Errors) Present() bool {
	return len(e.FieldErrors) != 0 || len(e.GeneralErrors) != 0
}

func (e Errors) Error() string {
	var messages []string
	for _, generalError := range e.GeneralErrors {
		messages = append(messages, generalError.Message)
	}
	for fieldName, fieldErrors := range e.FieldErrors {
		var fieldMessages []string
		for _, fieldError := range fieldErrors {
			fieldMessages = append(fieldMessages, fieldError.Message)
		}
		messages = append(messages, fmt.Sprintf("%s: %s", fieldName, strings.Join(fieldMessages, ",")))
	}
	return strings.Join(messages, " ")
}

  [/#if]
[/#macro]

[#function hackCollisions type name]
  [#local newName = name/]
  [#if name == "LambdaConfiguration"]
    [#if type.packageName?ends_with(".provider")]
      [#local newName = "Provider" + name/]
    [#elseif type.packageName?ends_with(".connector")]
      [#local newName = "Connector" + name/]
    [/#if]
  [/#if]
    [#return newName/]
[/#function]

[#assign responseObjects = ["AccessToken","OpenIdConfiguration","OAuthValidationResult"]/]

package fusionauth

import(
  "fmt"
  "strings"
)

type StatusAble interface {
  SetStatus(status int)
}

/**
* Base Response which contains the HTTP status code
*
* @author Matthew Altman
*/
type BaseHTTPResponse struct {
  StatusCode int `json:"statusCode,omitempty"`
}

func (b *BaseHTTPResponse) SetStatus(status int) {
  b.StatusCode = status
}

[#assign ignoredTypes = ["HTTPHeaders","IntrospectResponse","LocalizedIntegers","LocalizedStrings","UserinfoResponse","ApplicationEvent"]/]
[#list domain?sort_by("type") as d]
  [#if !(ignoredTypes?seq_contains(d.type))]
    [#assign subPackage = getSubPackage(d.packageName)/]
    [#if d.description??]${d.description}[/#if][#t]
    [#if d.fields??]
type ${hackCollisions(d d.type)?cap_first} struct {
      [#if d.type?ends_with("Response") || responseObjects?seq_contains(d.type)]
  BaseHTTPResponse
      [/#if]
      [#if d.extends??]
        [#list d.extends as ext]
  ${printType(ext, d)}
        [/#list]
      [/#if]
      [#list d.fields?keys?sort as fieldName]
        [#assign field = d.fields[fieldName]/]
        [#assign fieldType = printType(field, d)/]
        [#if fieldType == "bool"]
  ${global.scrubName(global.toCamelCase(fieldName))?cap_first?right_pad(32)} ${fieldType?right_pad(34)} `json:"${fieldName}"`
        [#else]
  ${global.scrubName(global.toCamelCase(fieldName))?cap_first?right_pad(32)} ${fieldType?right_pad(34)} `json:"${fieldName},omitempty"`
        [/#if]
      [/#list]
}
      [#if d.type?ends_with("Response") || responseObjects?seq_contains(d.type)]
func (b *${hackCollisions(d d.type)?cap_first}) SetStatus(status int) {
  b.StatusCode = status
}
      [/#if]

[@addFunctions d.type/]
    [#elseif d.enum??]
type ${d.type} string
const (
      [#list d.enum as value]
        [#if d.type == "EventType" || d.type == "GrantType"]
  ${d.type}_${global.toCamelCase(value.name!value)?cap_first?right_pad(32)} ${d.type?right_pad(34)} = "${(value.args[0]?string)!value}"
        [#else]
  ${d.type}_${global.toCamelCase(value.name!value)?cap_first?right_pad(32)} ${d.type?right_pad(34)} = "${value.name!value}"
        [/#if]
      [/#list]
)

    [/#if]
  [/#if]
[/#list]
