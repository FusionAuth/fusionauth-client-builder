## FusionAuth Client Builder ![semver 2.0.0 compliant](http://img.shields.io/badge/semver-2.0.0-brightgreen.svg?style=flat-square)


## Credits
Thanks to the following folks for your most excellent contributions!
* [@medhir](https://github.com/medhir) 
* [@tjpeden](https://github.com/tjpeden) 

## Contributing

If you want to help us directly support and publish this library, there are a few ways you can help.

We start with a JSON DSL to define each API ( https://github.com/FusionAuth/fusionauth-client-builder/tree/master/src/main/api ).

We then build the code using a template, for example, here is the ruby template : https://github.com/FusionAuth/fusionauth-client-builder/blob/master/src/main/client/ruby.client.ftl

This ruby template then produces the ruby client.

https://github.com/FusionAuth/fusionauth-ruby-client

https://github.com/FusionAuth/fusionauth-ruby-client/blob/master/lib/fusionauth/fusionauth_client.rb

You can pick the current client library template for the language closest to the language you want to support. Let's say it is ruby. You will copy the ruby client template (https://github.com/FusionAuth/fusionauth-client-builder/blob/master/src/main/client/ruby.client.ftl) to <language>.client.ftl and then start hacking on it.

With that template we can then build the <language> client each time we release.

You can also build a library any other way; the chances of us supporting custom builds are low, but you can add your library to the contrib repo: https://github.com/FusionAuth/fusionauth-contrib/

## Build a client library

### Setup Savant

Linux or macOS

```
mkdir ~/savant
cd ~/savant
wget http://savant.inversoft.org/org/savantbuild/savant-core/1.0.0/savant-1.0.0.tar.gz
tar xvfz savant-1.0.0.tar.gz
ln -s ./savant-1.0.0 current
export PATH=$PATH:~/savant/current/bin/
```

You may optionally want to add `~/savant/current/bin` to your PATH that is set in your profile so that this change persists. You'll also need to ensure that you have Java >= 8 installed and the environment variable  `JAVA_HOME` is set.

### Building

Listing each client library build targets

```
sb --listTargets
```

Building a single library

To build a single client library, you'll want to have the corresponding repo checked out in the same parent directory.

For example, your directory structure should look something like the following:

```
fusionauth
├── fusionauth-client-builder
├── fusionauth-android-client
├── fusionauth-csharp-client
├── fusionauth-java-client
├── fusionauth-javascript-client
├── fusionauth-node-client
├── fusionauth-php-client
├── fusionauth-python-client
├── fusionauth-ruby-client
├── fusionauth-swift-client
├── fusionauth-typescript-client
├── fusionauth-dart-client
└── go-client
```

The client builder will assume the project is in the same parent directory.

```
sb build-java
```

Building all clients

```
sb build-all
```

For more information on the Savant build tool, checkout [savantbuild.org](http://savantbuild.org/).


## OpenAPI support

This is experimental.

To build the YAML file:

```
cd bin && ruby ./build-openapi-yaml.rb
```

For options:

```
cd bin && ruby ./build-openapi-yaml.rb -h
```

To validate the YAML:

```
npm install -g @apidevtools/swagger-cli # one time
swagger-cli validate openapi.yaml 
```


### Test the YAML

```
pip3 install schemathesis # one time
schemathesis run -vvvv --checks not_a_server_error openapi.yaml --base-url http://localhost:9011 -H "Authorization: bf69486b-4733-4470-a592-f1bfce7af580" 
```

### Generate libraries

Install either Swagger: https://github.com/swagger-api/swagger-codegen/ or openapi: https://github.com/OpenAPITools/openapi-generator

Java

```
cd <dir>
swagger-codegen generate  --group-id io.fusionauth --artifact-id fusionauth-client-library-codegen --artifact-version 1.0.2-SNAPSHOT --api-package io.fusionauth.codegen.api  --invoker-package io.fusionauth.codegen.invoker --model-package io.fusionauth.codegen.model -l java -o . -i ../fusionauth-client-builder/bin/openapi.yaml
```

Ruby
```
npx @openapitools/openapi-generator-cli generate -i ../fusionauth-client-builder/bin/openapi.yaml -g ruby -o . 
```

### TODO

There are some flaws. While the specification is valid, the generated client libraries haven't been fully exercised.

In particular:

* polymorphic operations are not well supported by the client library generators. That means that identity provider requests and responses are not functional. I'm not sure if there are workarounds, but it seems like some work is being done. See https://github.com/swagger-api/swagger-codegen/issues/10011 for example.
* this file is generated from the fusionauth-client-builder JSON files, not from code. This means that there may be gaps when compared to the REST API.
* there's no information about what parameters are required or not, because that is not part of the API JSON files.
* there are certain operations, status codes and security mechanisms (JWT auth, cookies for auth) that are not currently supported, again, because they are not included in the API JSON files.
* oauth specific operations are not currently supported.

Rollout plan:

* Review with eng team, determine if current state is shippable to alpha users.
* Ask folks who commened on https://github.com/FusionAuth/fusionauth-issues/issues/614 or otherwise expressed interest in this to kick the tires.
* Determine what features need to be added to ship.
* Fix any outstanding issues/add features.
* Publish as 'tech preview' in docs. Close bugs for other SDKs.
* Let it burn in for a few months, fix any issues.
* Start publishing it as part of the release process. Maybe include it in the build? Maybe just on the download page.
* Go back and provide specs for previous releases so that folks can use apidiff functionality.
* Investigate bringing things closer to the code/fusionauth-app so that we don't need to maintain the API JSON files.
