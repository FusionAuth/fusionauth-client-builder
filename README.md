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
wget http://savant.inversoft.org/org/savantbuild/savant-core/2.0.0-RC.6/savant-2.0.0-RC.6.tar.gz
tar xvfz savant-2.0.0-RC.6.tar.gz
ln -s ./savant-2.0.0-RC.6 current
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
├── fusionauth-openapi
├── fusionauth-php-client
├── fusionauth-python-client
├── fusionauth-ruby-client
├── fusionauth-swift-client
├── fusionauth-typescript-client
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

## Adding a new language

If you want to help us directly support and publish a new language, there are a few ways you can help.

We start with a JSON DSL to define [each API operation](https://github.com/FusionAuth/fusionauth-client-builder/tree/master/src/main/api).

We then build the code using a template. For example, here is [the ruby template](https://github.com/FusionAuth/fusionauth-client-builder/blob/master/src/main/client/ruby.client.ftl)

This ruby template then produces the ruby client:

https://github.com/FusionAuth/fusionauth-ruby-client

https://github.com/FusionAuth/fusionauth-ruby-client/blob/master/lib/fusionauth/fusionauth_client.rb

So if you wanted to add support for a new language, such as elixir, you want to:

* Find an existing supported language which is close to it in terms of syntax and style. In this case, ruby would be a good candidate.
* Copy the ruby [client template](https://github.com/FusionAuth/fusionauth-client-builder/blob/master/src/main/client/ruby.client.ftl) to `elixir.client.ftl` 
* Start hacking on it. 

With that template complete, we can then build the Elixir client each time we release.

Feel free to open an issue in our issues tracker, either here or in [the central one](https://github.com/FusionAuth/fusionauth-issues/issues) to let us know about your efforts or to ask for help.
