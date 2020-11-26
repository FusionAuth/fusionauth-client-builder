[#import "_macros.ftl" as global/]

need to handle auth
params.constant

openapi: "3.0.3"
info:
  title: FusionAuth API
  version: 1.21.0
servers:
  url: https://local.fusionauth.io
paths: 
[#list apis as api]
  ${api.uri}:
    ${api.method}:
      operationId: ${api.methodName}
      [#if api.deprecated??]
      deprecated: true
      [/#if]
      summary: |-
        [#list api.comments as comment] ${comment} [/#list]
      parameters: 
        [#list api.params![] as param]
        [#if param.type != "body"]
        - name: ${param.name}
          [#if param.type == "urlSegment"] TODO need to tie this back to the paths object
          in: path
          required: true
          [/#if]
          [#if param.type == "urlParameter"]
          in: query
          [/#if]
          description: |-
            [#list api.comments as comment] ${comment} [/#list]
          schema:
            [#if !param.constant??]
              type: ${global.convertType(param.javaType, "openapi")}
            [#else]
              type: string
            [/#if]
        [/#if]
        [/#list]
      [#if api.method != "get"]
      requestBody: 
        description:
        required: 
        content:
        [#list api.params![] as param]
        [#if param.type == "body"] 
          TODO
          - name: ${param.name}
        [/#if]
        [/#list]
      [/#if]
      responses: 
        '200': 
          description: 
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/${api.successResponse}'
        default:
          description: 
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/${api.errorResponse}'

[/#list]
components:
  schemas:
    TODO, pull from domain objects
  responses:
  parameters:
  examples:
  requestBodies:
  headers: 
    - X-FusionAuth-TenantId
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
      schema: bearer
security:
  - ApiKeyAuth: []
  - JwtBearer: []
externalDocs:
  description: FusionAuth documentation
  url: https://fusionauth.io/docs/v1/tech/

