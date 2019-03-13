## FusionAuth Client Builder ![semver 2.0.0 compliant](http://img.shields.io/badge/semver-2.0.0-brightgreen.svg?style=flat-square)


Then, perform an integration build of the project by running:
```bash
$ sb int
```

For more information, checkout [savantbuild.org](http://savantbuild.org/).

## Build a client library

### Setup Savant

Linux or macOS

```bash
$ mkdir ~/savant
$ cd ~/savant
$ wget http://savant.inversoft.org/org/savantbuild/savant-core/1.0.0/savant-1.0.0.tar.gz
$ tar xvfz savant-1.0.0.tar.gz
$ ln -s ./savant-1.0.0 current
$ export PATH=$PATH:~/savant/current/bin/
```

You may optionally want to add `~/savant/current/bin` to your PATH that is set in your profile. You'll also need to ensure that you have Java installed and the environment variable  `JAVA_HOME` is set. 

### Building 



Listing build targets

```
> sb --listTargets
```

Building a single library

To build a single client library, you'll want to have the corresponding repo checked out in the same parent directory.

For example, your directory structure should look something like the following:

```
-- fusionauth
  | 
  fusionauth-client-builder
  |
  fusionauth-java-client
```

The client builder will assume the project is in the same parent directory.

```
> sb build-java
```

Building all clients

```
> sb build-all
```
