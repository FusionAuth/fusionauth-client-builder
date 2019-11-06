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

[#function hackCollisions type name]
  [#local newName = name/]
  [#if name == "LambdaConfiguration"]
    [#if type.packageName?ends_with(".provider")]
      [#local newName = "Provider" + name/]
    [/#if]
  [/#if]
    [#return newName/]
[/#function]

package client

/**
* Base Response which contains the HTTP status code
*
* @author Matthew Altman
*/
type BaseHTTPResponse struct {
  StatusCode int `json:"statusCode,omitempty"`
}

[#assign ignoredTypes = ["HTTPHeaders","IntrospectResponse","JWKSResponse","LocalizedIntegers","LocalizedStrings","UserinfoResponse","ApplicationEvent"]/]
[#list domain?sort_by("type") as d]
  [#if !(ignoredTypes?seq_contains(d.type))]
    [#assign subPackage = getSubPackage(d.packageName)/]
    [#if d.description??]${d.description}[/#if][#t]
    [#if d.fields??]
type ${hackCollisions(d d.type)?cap_first} struct {
      [#if d.type?ends_with("Response")]
  BaseHTTPResponse
      [/#if]
      [#if d.extends??]
        [#list d.extends as ext]
  ${printType(ext, d)}
        [/#list]
      [/#if]
      [#list d.fields?keys?sort as fieldName]
        [#assign field = d.fields[fieldName]/]
  ${global.toCamelCase(fieldName)?right_pad(25)} ${printType(field, d)?right_pad(25)} `json:"${fieldName},omitempty"`
      [/#list]
}

    [#elseif d.enum??]
type ${d.type} string
const (
      [#list d.enum as value]
  ${d.type}_${global.toCamelCase(value.name!value)?right_pad(20)} ${d.type?right_pad(20)} = "${value.name!value}"
      [/#list]
)

    [/#if]
  [/#if]
[/#list]
