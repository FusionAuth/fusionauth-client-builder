[#-- @ftlvariable name="domain_item" type="java.lang.Object" --]
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
  [#if (type.final!false) && (type.static!false)]
   static final ${type.type}[#t]
  [#else]
   ${type.type}[#t]
  [/#if]
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
[#assign jdkImports = false]
[#assign firstEntry = true]
[#list domain_item.imports![] as class]
[#if !class?string?starts_with("io.fusionauth") &&
     !class?string?starts_with("com.inversoft") &&
     !class?string?starts_with("java.lang")]
[#if firstEntry]

[/#if]
import ${class};
[#assign jdkImports = true]
[#assign firstEntry = false]
[/#if]
[/#list]
[#if jdkImports]

[/#if]
[#assign firstEntry = true]
[#list domain_item.imports![] as class]
[#if class?string?starts_with("io.fusionauth") &&
     class?string != "io.fusionauth.domain.Buildable" &&
     class?string != "com.inversoft.mybatis.JSONColumnable" &&
     [#-- Don't import classes in the same package, starts with, and remainder can only have one dot --]
     !(class?string?starts_with(domain_item.packageName) && !class?string?substring(class?string?index_of(domain_item.packageName) + 1)?contains("."))]
[#if firstEntry]

[/#if]
import ${class};
[#assign firstEntry = false]
[/#if]
[/#list]
[#if domain_item.description??]
${domain_item.description?replace("\n(?!$)", "\n  ", "r")}[#rt]
[#else]

/**
 * @author FusionAuth
 */
[/#if]
[#if (domain_item.objectType!'') == "Interface"]
public interface [@printType domain_item true/] {
}
[#elseif (domain_item.objectType!'') == "Object"]
public class [@printType domain_item true/] {
  [#list domain_item.fields?keys as fieldName]
    [#if !fieldName?is_first]

    [/#if]
    [#assign field = domain_item.fields[fieldName]]
    [#if field.description??]
  ${field.description}[#rt]
    [/#if]
  [#if (field.final!false) && (field.static!false) && field.defaultValue??]
  public [@printType field/] ${global.scrubName(replaceKeywords(fieldName))} = [#if field.type == "UUID"]UUID.fromString("${field.defaultValue}")[#elseif field.type == "String"]"${field.defaultValue}"[#elseif field.type == "URI"]URI.create("${field.defaultValue}")[/#if];
  [#else]
  public [@printType field/] ${global.scrubName(replaceKeywords(fieldName))};
  [/#if]
  [/#list]
}
[#elseif (domain_item.objectType!'') == "Enum"]
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
