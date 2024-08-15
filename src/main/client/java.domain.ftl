[#-- @ftlvariable name="packages" type="String[]" --]
[#-- @ftlvariable name="types_in_use" type="String[]" --]
/*
 * Copyright (c) 2018-2024, FusionAuth, All Rights Reserved
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

[#function replaceKeywords value]
  [#return value?replace("\\b(?=implicit)|\\b(?=event)", "@", "ir")]
[/#function]

[#macro printType type isDeclaration=false isTypeArgument=false]
  [#if type.type??]
    [#local convertedType = global.convertType(type.type, "java")/]
    [#if isDeclaration]
      [#local convertedType = convertedType?replace("IDictionary", "Dictionary")/]
    [/#if]
    [#if isTypeArgument]
      [#local convertedType = convertedType?replace("?", "")/]
    [/#if]
    ${convertedType}[#t]
    [#if type.typeArguments?has_content && convertedType != "object"]
      <[#list type.typeArguments as typeArgument][@printType type=typeArgument isTypeArgument=true/][#sep], [/#sep][/#list]>[#t]
    [/#if]
    [#if isDeclaration]
      [#list type.extends![]]
        : [#t]
        [#items as extends]
          [@printType extends isDeclaration/][#sep], [/#sep][#t]
        [/#items]
        [#if type.type == "BaseIdentityProvider"]
          , IdentityProvider[#t]
        [/#if]
      [/#list]
    [/#if]
  [#else]
    ${replaceKeywords(type.name)}[#t]
  [/#if]
[/#macro]
package ${domain_item.packageName};

import io.fusionauth.domain.*;
import java.util.*;


[#if domain_item.description??]
${domain_item.description?replace("\n(?!$)", "\n  ", "r")}[#rt]
[/#if]
[#if domain_item.fields??]
public class [@printType domain_item true/] {
  [#list domain_item.fields?keys as fieldName]
    [#if !fieldName?is_first]

    [/#if]
    [#assign field = domain_item.fields[fieldName]]
    [#if field.description??]
  ${field.description}[#rt]
    [/#if]
    [#if field.type == "BaseIdentityProvider"]
  // Due to c#'s lack of generics we have to use an empty interface for this.
  // The concrete classes all implement BaseIdentityProvider
  // This also allows for serialization to and from json
  public IdentityProvider ${replaceKeywords(fieldName)};
      [#continue/]
    [#elseif field.type == "List" && field.typeArguments[0].type == "BaseIdentityProvider"]
  // Due to c#'s lack of generics we have to use an empty interface for this.
  // The concrete classes all implement BaseIdentityProvider
  // This also allows for serialization to and from json
  public List<IdentityProvider> ${replaceKeywords(fieldName)};
      [#continue/]
    [/#if]
    [#if field.anySetter?? && field.anySetter]
  public dynamic this[string claim] {
    get => ${replaceKeywords(fieldName)}[claim];
    set => ${replaceKeywords(fieldName)}[claim] = value;
  }

  [JsonExtensionData]
  private readonly Dictionary<string, dynamic> ${global.scrubName(replaceKeywords(fieldName))} = new Dictionary<string, dynamic>();
    [#else]
  [#if domain_item.type == "JWT" && domain_item.packageName == "io.fusionauth.jwt.domain" && field.type == "ZonedDateTime"]
  [#-- per https://github.com/FusionAuth/fusionauth-issues/issues/1362 JWT DateTimeOffsets need to be parsed as seconds, as opposed to milliseconds
  --]
  [JsonConverter(typeof(DateTimeOffsetSecondsConverter))]
  [/#if]
  public [@printType field/] ${global.scrubName(replaceKeywords(fieldName))};
    [/#if]
  [/#list]
}
[#else]
    [#assign useCustomNames = global.needsConverter(domain_item)]
    [#assign useStringName = global.needsConverterNoArgs(domain_item)]
public enum ${domain_item.type} {
  [#list domain_item.enum as value]
    [#if useStringName]
      [EnumMember(Value = "${value}")]
       ${value?string?cap_first}[#rt/]
    [#elseif value?is_string]
      ${replaceKeywords(value)}[#rt/]
    [#else]
      [#if useCustomNames]
      [EnumMember(Value = "${(value.args![])[0]!value.name}")]
      [/#if]
      ${replaceKeywords(value.name)}[#rt/]
    [/#if]
    [#lt][#sep], [/#sep]
  [/#list]
}
[/#if]
