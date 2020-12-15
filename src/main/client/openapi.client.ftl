[#import "_macros.ftl" as global/]

[#function hasRequestBody(obj)]
  [#return (obj!{}).type == "body"]
[/#function]

[#function hasAnyOtherParamTypeThanRequestBody(obj)]
  [#return (obj!{}).type != "body"]
[/#function]

[#macro buildEndpoint api]
      operationId: ${api.methodName}
      [#if api.deprecated??]
      deprecated: true
      [/#if]
      summary: |-
        [#list api.comments as comment] ${comment} [/#list]
      [#if (api.params![])?size > 0 && ((api.params?filter(hasAnyOtherParamTypeThanRequestBody))?size == 1)]
      parameters: 
        [#list api.params![] as param]
        [#if param.type != "body"]
        - name: ${param.name}
          [#if param.type == "urlSegment"] 
          in: path
          required: true
          [/#if]
          [#if param.type == "urlParameter"]
          in: query
          [/#if]
          description: |-
            [#list (param.comments)![] as comment] ${comment} [/#list]
          schema:
            [#if !param.constant??]
              type: ${global.convertType(param.javaType, "openapi")["type"]}
              [#if global.convertType(param.javaType, "openapi")["format"]??]
              format: ${global.convertType(param.javaType, "openapi")["format"]}
              [/#if]
            [#else]
              type: string
            [/#if]
        [/#if]
        [/#list]
      [/#if]
      [#if (api.params![])?size > 0 && ((api.params?filter(hasRequestBody))?size == 1)]
      requestBody: 
        [#list api.params![] as param]
        [#if param.type == "body"] 
        description: |-
          [#list param.comments as comment] ${comment} [/#list]
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/${param.javaType}'
        [/#if]
        [/#list]
      [/#if]
      responses: 
        '200': 
          [#if api.successResponse != "Void"]
          description: Returns the ${api.successResponse}
          content:
            application/json:
              schema:
                $ref: ${global.convertType(api.successResponse, "openapi")["type"]} 
          [#else]
          description: This API does not return a JSON response body. 
          [/#if]
        default:
          [#if api.errorResponse != "Void"]
          description: Returns the ${api.errorResponse}
          content:
            application/json:
              schema:
                $ref: ${global.convertType(api.errorResponse, "openapi")["type"]} 
          [#else]
          description: This API does not return a JSON response body when errors occur. 
          [/#if]

[/#macro]

[#list endpoints_w_optional_path_params!{} as uri, methods]
 ${uri}
  [#list methods as method, api]
    ${api.methodName}
    ${api.methodName}
        [#list api.params![] as param]
           ${param.name}
        [/#list]
  [/#list]
[/#list]

openapi: "3.0.3"
info:
  title: FusionAuth API
  version: 1.21.0
servers:
  - url: https://local.fusionauth.io
paths: 
[#list endpoints as uri, methods]
  [#if uri?contains("user-action") && !uri?contains("reason")]
  ${uri}:
  [#list methods as method, api]
    ${method}:
    [@buildEndpoint api /]
  [/#list]
  [/#if]
[/#list]

components:
  schemas:
[#list domain as dom]
[#if dom.type == "UserActionResponse" || dom.type == "UserActionRequest" 
     || dom.type == "UserAction"  
     || dom.type == "Error" 
     || dom.type == "Errors" 
     || dom.type == "TransactionType"
     || dom.type == "UserActionOption"
]
    ${dom.type}:
[#if (dom.enum![])?has_content  ]
      type: string
      enum:
[#list dom.enum![] as enum]
        - ${enum}
[/#list]
[/#if]
[#if (dom.fields!{})?has_content  ]
      type: object
      properties:
#        required: ["name"]
[#list dom.fields!{} as fieldname, object]
        ${fieldname}:
          [#if global.convertType(object.type, "openapi")["ref"]??]
          $ref: ${global.convertType(object.type, "openapi")["type"]}
          [#else]
          type: ${global.convertType(object.type, "openapi")["type"]}
          [/#if]
          [#if global.convertType(object.type, "openapi")["format"]??]
          format: ${global.convertType(object.type, "openapi")["format"]}
          [/#if]
          [#if global.convertType(object.type, "openapi")["type"] == "array"]
          items: 
            $ref: ${global.convertType(object.typeArguments[0]["type"], "openapi")["type"]}
          [/#if]
[/#list]
[/#if]
        
[/#if]
[/#list]
  headers: 
    X-FusionAuth-TenantId:
      schema:
        type: string
        format: uuid
  securitySchemes: 
    ApiKeyAuth:
      type: apiKey
      description: Your FusionAuth API key
      in: header
      name: Authorization
    JwtBearer:
      type: http
      description: A valid JWT
      scheme: bearer
security:
  - ApiKeyAuth: []
  - JwtBearer: []
externalDocs:
  description: FusionAuth documentation
  url: https://fusionauth.io/docs/v1/tech/
