[#-- @ftlvariable name="domain_item" type="" --]
[#-- @ftlvariable name="packages" type="String[]" --]
[#-- @ftlvariable name="types_in_use" type="String[]" --]
[#import "_macros.ftl" as global/]
[#assign useCustomNames = global.needsConverter(domain_item)]
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
[#macro printType type isDeclaration=false isTypeArgument=false]
  [#if type.type??]
    ${type.type?replace("*", "?")}[#t]
  [#else]
    ${type.name}[#t]
  [/#if]
  [#if type.typeArguments?has_content && type.type != "Object"]
    <[#list type.typeArguments as typeArgument][@printType typeArgument isDeclaration true/][#sep], [/#sep][/#list]>[#t]
  [/#if]
  [#if isDeclaration]
    [#list type.extends![]]
 extends [#rt]
      [#items as extends]
        [@printType extends isDeclaration/][#sep], [/#sep][#t]
      [/#items]
    [/#list]
  [/#if]
[/#macro]
package ${domain_item.packageName};

import java.net.*;
import java.time.*;
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
import io.fusionauth.domain.webauthn.*;
import io.fusionauth.jwt.domain.*;

[#if useCustomNames]
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
[/#if]

[#if domain_item.description??]
${domain_item.description}[#rt]
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
  public [@printType field/] ${global.scrubName(fieldName)};
  [/#list]
}
[#else]
public enum ${domain_item.type} {
  [#list domain_item.enum as value]
    [#if value?is_string]
  ${value}[#rt/]
    [#else]
  ${value.name}[#rt/]
      [#if useCustomNames]
        ("${(value.args![])[0]!value.name}")[#t]
      [/#if]
    [/#if]
    [#lt][#sep],
[/#sep][#if !value?has_next];[/#if]
  [/#list]
  [#if useCustomNames]

  private static final Map<String, ${domain_item.type}> nameMap = new HashMap<>(${domain_item.type}.values().length);

  private final String customName;

  ${domain_item.type}(String customName) {
    this.customName = customName;
  }

  @JsonCreator
  public static ${domain_item.type} forValue(String value) {
    return nameMap.get(value);
  }

  @JsonValue
  public String customName() {
    return customName;
  }

  static {
    for (${domain_item.type} value : ${domain_item.type}.values()) {
      nameMap.put(value.customName(), value);
    }
  }
  [/#if]
}
[/#if]