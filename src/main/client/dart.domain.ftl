[#--noinspection ALL--]
[#import "_macros.ftl" as global/]
/*
* Copyright (c) 2019-2023, FusionAuth, All Rights Reserved
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

import 'package:json_annotation/json_annotation.dart';

import 'Converters.dart';

part 'FusionAuthDomain.g.dart';

[#assign dartExcludes=[
  "LocalizedIntegers",
  "LocalizedStrings",
  "HTTPHeaders",
  "IntrospectResponse",
  "UserinfoResponse",
  "LambdaConfiguration",
  "SearchResults"
]]

[#-- @formatter:off --]
[#macro printType type]
  [#if type.type??]
    ${global.convertType(type.type, "dart")}[#if type.typeArguments?has_content]<[#list type.typeArguments as typeArgument][@printType typeArgument/][#sep], [/#sep][/#list]>[/#if][#if type.extends??] extends [#list type.extends as extends][@printType extends/][#sep], [/#sep][/#list][/#if][#t]
  [#else]
    ${type.name}[#if type.extends??] extends [#list type.extends as extends][@printType extends/][#sep], [/#sep][/#list][/#if][#t]
  [/#if]
[/#macro]

[#list domain as d]
[#--Skip cases--]
[#if dartExcludes?seq_contains(d.type)]
  [#continue]
[/#if]
[#if d.description??]${d.description?replace("/\\*\\*\\n|\\s+\\*/", "", "r")?replace(" *", "///")}[/#if][#t]
[#if d.fields??]
[#-- Use interface here because classes require the correct order for declaration if it extends something --]
[#-- Interfaces are also only for type checking so they can result in smaller compiled code --]
@JsonSerializable([#if d.type == "BaseIdentityProvider"]createFactory: false[/#if])
class [@printType d/] {
  [#list d.fields?keys?sort as fieldName]
  [#assign field = d.fields[fieldName]/]
  [#assign scrubbedName = global.scrubName(fieldName)/]
  [#if field.description??]${field.description}[/#if][#t]
  [#if field.anySetter?? && field.anySetter]
  final Map<String, dynamic> _${scrubbedName} = Map<String, dynamic>();
  dynamic operator[](String index) => _${scrubbedName}[index]; // Get any other fields
  void operator[]=(String index, dynamic value) => _${scrubbedName}[index] = value; // Set any other fields
  [#else]
  [#if field.type == "BaseIdentityProvider" && field.typeArguments?size == 1 && field.typeArguments[0].type == '*']
  [#-- We have to convert the base identity provider explicitly/manually  --]
  @IdentityProviderConverter()
  [/#if]
  [#if field.type == "Map" && fieldName == "applicationConfiguration" && field.typeArguments[1].type == 'D']
  [#-- The dart json lib we are using can't convert generics like this  --]
  @IdentityProviderApplicationConfigurationConverter()
  [/#if]
  [#if fieldName != scrubbedName]
  @JsonKey(name: '${fieldName}')
  [/#if]
  [@printType field/] ${scrubbedName};
  [/#if]
  [/#list]

  ${d.type}([#list d.fields?keys?sort]{
    [#items as fieldName]
      [#if d.fields[fieldName].anySetter?? && d.fields[fieldName].anySetter][#continue][/#if]
      this.${global.scrubName(fieldName)}[#sep],[/#sep]
    [/#items]
  }[/#list]);

  [#if d.type != "BaseIdentityProvider"]
  factory ${d.type}.fromJson(Map<String, dynamic> json) => _$${d.type}FromJson(json);
  [#else]
  factory BaseIdentityProvider.fromJson(Map<String, dynamic> json) => BaseIdentityProviderFromJson(json);
  [/#if]
  @override
  Map<String, dynamic> toJson() => _$${d.type}ToJson(this);
}
[#else]
enum ${d.type} {
    [#list d.enum as value]
  @JsonValue('${value.name!value}')
  ${value.name!value}[#sep],[/#sep]
    [/#list]
}
[/#if]

[/#list]
[#-- @formatter:on --]
