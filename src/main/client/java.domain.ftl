[#-- @ftlvariable name="domain_item" type="" --]
[#-- @ftlvariable name="packages" type="String[]" --]
[#-- @ftlvariable name="types_in_use" type="String[]" --]
/*
 * Copyright (c) 2018-2023, FusionAuth, All Rights Reserved
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
   ${type.type}[#t]
  [#if type.typeArguments?has_content && type.type != "Object"]
    <[#list type.typeArguments as typeArgument][@printType type=typeArgument isTypeArgument=true/][#sep], [/#sep][/#list]>[#t]
  [/#if]
  [#if isDeclaration]
    [#if type.extends?? && type.extends.type?? && type.extends.type?string != "Object"]
 extends [@printType type.extends isDeclaration/][#rt]
    [/#if]
  [/#if]
[/#macro]
package ${domain_item.packageName};

import java.util.*;
import java.util.function.*;

import io.fusionauth.domain.*;
import io.fusionauth.domain.api.*;
import io.fusionauth.domain.api.cache.*;
import io.fusionauth.domain.api.email.*;
import io.fusionauth.domain.api.identityProvider.*;
import io.fusionauth.domain.api.jwt.*;
import io.fusionauth.domain.api.passwordless.*;
import io.fusionauth.domain.api.report.*;
import io.fusionauth.domain.api.twoFactor.*;
import io.fusionauth.domain.api.user.*;
import io.fusionauth.domain.connector.*;
import io.fusionauth.domain.email.*;
import io.fusionauth.domain.event.*;
import io.fusionauth.domain.form.*;
import io.fusionauth.domain.jwks.*;
import io.fusionauth.domain.jwt.*;
import io.fusionauth.domain.message.*;
import io.fusionauth.domain.message.sms.*;
import io.fusionauth.domain.messenger.*;
import io.fusionauth.domain.oauth2.*;
import io.fusionauth.domain.provider.*;
import io.fusionauth.domain.reactor.*;
import io.fusionauth.domain.search.*;
import io.fusionauth.domain.util.*;

[#if domain_item.description??]
${domain_item.description?replace("\n(?!$)", "\n  ", "r")}[#rt]
[#else]
/**
 * @author FusionAuth
 */
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
  public [@printType field/] ${global.scrubName(replaceKeywords(fieldName))};
  [/#list]
}
[#else]
  [#assign useCustomNames = global.needsConverter(domain_item)][#t/]
  [#assign useStringName = global.needsConverterNoArgs(domain_item)][#t/]
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