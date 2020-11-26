[#import "_macros.ftl" as global/]

need to handle auth
params.constant

openapi: "3.0.0"
info:
  title: Simple API overview
  version: 1.0.0
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
[#if param.javaType == "UUID"]
            type: string
            format: uuid
[/#if]
            
[/#if]
    [#if !param.constant??]
    # @param ${camel_to_underscores(param.name?replace("end", "_end"))} [${global.convertType(param.javaType, "ruby")}] ${param.comments?join("\n    #     ")}
    [/#if]
  [/#list]
[#if api.method != "get"]
      requestBody: 
        description:
        required: 
        content:
[#list api.params![] as param]
[#if param.type != "body"] 
TODO
          - name: ${param.name}
[/#if]
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

  

    #
  [#list api.params![] as param]
    [#if !param.constant??]
    # @param ${camel_to_underscores(param.name?replace("end", "_end"))} [${global.convertType(param.javaType, "ruby")}] ${param.comments?join("\n    #     ")}
    [/#if]
  [/#list]
    # @return [FusionAuth::ClientResponse] The ClientResponse object.
[#if api.deprecated??]
    # @deprecated ${api.deprecated?replace("{{renamedMethod}}", camel_to_underscores(api.renamedMethod!''))}
[/#if]
    def ${camel_to_underscores(api.methodName)}(${global.methodParameters(api, "ruby")})
      [#assign formPost = false/]
      [#list api.params![] as param]
        [#if param.type == "form"][#assign formPost = true/][/#if]
      [/#list]
      [#if formPost]
      body = {
        [#list api.params![] as param]
          [#if param.type == "form"]
        "${param.name}" => ${(param.constant?? && param.constant)?then("\""+param.value+"\"", param.name)}[#if param?has_next],[/#if]
          [/#if]
        [/#list]
      }
      [/#if]
      start[#if api.anonymous??]Anonymous[/#if].uri('${api.uri}')
      [#if api.authorization??]
          .authorization(${api.authorization?replace('encodedJWT', 'encoded_jwt')?replace('\"', '\'')})
      [/#if]
      [#list api.params![] as param]
        [#if param.type == "urlSegment"]
          .url_segment(${(param.constant?? && param.constant)?then(param.value, camel_to_underscores(param.name))})
        [#elseif param.type == "urlParameter"]
          .url_parameter('${param.parameterName}', ${(param.constant?? && param.constant)?then(param.value, camel_to_underscores(param.name?replace("end", "_end")))})
        [#elseif param.type == "body"]
          .body_handler(FusionAuth::JSONBodyHandler.new(${camel_to_underscores(param.name)}))
        [/#if]
      [/#list]
      [#if formPost]
          .body_handler(FusionAuth::FormDataBodyHandler.new(body))
      [/#if]
          .${api.method}()
          .go()
    end

[/#list]

