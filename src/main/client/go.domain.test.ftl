/*
* Copyright (c) FusionAuth, All Rights Reserved
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

package fusionauth

import(
  "fmt"
  "testing"
)

[#assign ignoredTypes = ["HTTPHeaders","IntrospectResponse","LocalizedIntegers","LocalizedStrings","UserinfoResponse","ApplicationEvent"]/]
[#list domain as d]
  [#if !(ignoredTypes?seq_contains(d.type))]
    [#if d.enum??]

func Test_${d.type}ImplementsStringer(t *testing.T) {
  var enum interface{} = ${d.type}("Test")
  if _, ok := enum.(fmt.Stringer); !ok {
    t.Errorf("${d.type} does not implement stringer interface\n")
  }
}
    [/#if]
  [/#if]
[/#list]
