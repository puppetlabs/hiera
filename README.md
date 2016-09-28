# Hiera

[![Build Status](https://travis-ci.org/puppetlabs/hiera.png?branch=master)](https://travis-ci.org/puppetlabs/hiera)

A simple pluggable Hierarchical Database.

-
**Tutorials:** Check the docs directory for tutorials.

## Why?

Hierarchical data is a good fit for the representation of infrastructure information.
Consider the example of a typical company with 2 datacenters and on-site development,
staging etc.

All machines need:

 - ntp servers
 - sysadmin contacts

By thinking about the data in a hierarchical manner you can resolve these to the most
correct answer easily:

<pre>
     /------------- DC1 -------------\             /------------- DC2 -------------\
    | ntpserver: ntp1.dc1.example.com |           | ntpserver: ntp1.dc2.example.com |
    | sysadmin: dc1noc@example.com    |           |                                 |
    | classes: users::dc1             |           | classes: users::dc2             |
     \-------------------------------/             \-------------------------------/
                                \                      /
                                  \                  /
                           /------------- COMMON -------------\
                          | ntpserver: 1.pool.ntp.org          |
                          | sysadmin: "sysadmin@%{domain}"     |
                          | classes: users::common             |
                           \----------------------------------/
</pre>

In this simple example machines in DC1 and DC2 have their own NTP servers, additionaly
DC1 has its own sysadmin contact - perhaps because its a remote DR site - while DC2
and all the other environments would revert to the common contact that would have the
machines domain fact expanded into the result.

The _classes_ variable can be searched using the array method which would build up a
list of classes to include on a node based on the hierarchy.  Machines in DC1 would have
the classes _users::common_ and _users::dc1_.

The other environment like development and staging would all use the public NTP infrastructure.

This is the data model that extlookup() have promoted in Puppet, Hiera has taken this
data model and extracted it into a standalone project that is pluggable and have a few
refinements over extlookup.

## Enhancements over Extlookup

Extlookup had just one backend, Hiera can be extended with your own backends and represent
a few enhancements over the base Extlookup approach thanks to this.

### Multiple backends are queried

If you have a YAML and Puppet backend loaded and your users provide module defaults in the
Puppet backend you can use your YAML data to override the Puppet data.  If the YAML doesnt
provide an answer the Puppet backend will get an opportunity to provide an answer.

### More scope based variable expansion

Extlookup could parse data like %{foo} into a scope lookup for the variable foo.  Hiera
retains this ability and any Arrays or Hashes will be recursively searched for all strings
that will then be parsed.

The datadir and defaults are now also subject to variable parsing based on scope.

### No CSV support by default

We have not at present provided a backward compatible CSV backend.  A converter to
YAML or JSON should be written. When the CSV backend was first chosen for Puppet the
Puppet language only supports strings and arrays of strings which mapped well to CSV.
Puppet has become (a bit) better wrt data and can now handle hashes and arrays of hashes
so it's a good time to retire the old data format.

### Array Searches

Hiera can search through all the tiers in a hierarchy and merge the result into a single
array.  This is used in the hiera-puppet project to replace External Node Classifiers by
creating a Hiera compatible include function.

### Qualified Key Lookup
You can use a qualified key to lookup a value that is contained inside a hash or array:

<pre>
$ hiera user
{"name"=>"kim", "home"=>"/home/kim"}
$ hiera user.name
kim
</pre>

<pre>
$ hiera ssh_users
["root", "jeff", "gary", "hunter"]
$ hiera ssh_users.0
root
</pre>

### Use quotes to disable qualified key behavior
In case you have dotted keys and thus want to avoid using the qualified key semantics, you
can put segments of a dotted key, or the whole key, within quotes.

Given the following data:

<pre>
# yaml
a:
  b.c:
    d: 'Data for a => b.c => d'
</pre>

it is possible to do a lookup of the data like this:

<pre>
$ hiera 'a."b.c".d'
Data for a => b.c => d
</pre>

Quoting works in interpolation expressions as well.

Interpolating from global scope:

<pre>
# yaml
other.key: 'scope data: %{a."b.c".d}'
</pre>

or using an interpolation method:

<pre>
# yaml
a:
  b.c:
    d: 'Data for a => b.c => d'
other.key: 'hiera data %{hiera("a.''b.c''.d")}'
</pre>

Note that two single quotes are used to escape a single quote inside a single quoted string
(that's YAML syntax, not Hiera) and that the quoted key must be quoted in turn.

## Future Enhancements

 * More backends should be created
 * A webservice that exposes the data
 * Tools to help maintain the data files.  Ideally this would be Foreman and Dashboard
   with their own backends

## Installation

Hiera is available as a Gem called _hiera_ and out of the box it comes with just a single
YAML backend.

Hiera is also available as a native package via apt (http://apt.puppetlabs.com) and yum (http://yum.puppetlabs.com). Instructions for adding these repositories can be found at http://docs.puppetlabs.com/guides/installation.html#debian-and-ubuntu and http://docs.puppetlabs.com/guides/installation.html#enterprise-linux respectively.

At present JSON (github/ripienaar/hiera-json) and Puppet (hiera-puppet) backends are availble.

## Configuration

You can configure Hiera using a YAML file or by providing it Hash data in your code.  There
isn't a default config path - the CLI script will probably assume _/etc/hiera.yaml_ though.
The default data directory for file based storage is _/var/lib/hiera_.

A sample configuration file can be seen here:

<pre>
---
:backends:
  - yaml
  - puppet

:logger: console

:hierarchy:
  - "sites/%{location}"
  - common

:yaml:
   :datadir: /etc/puppetlabs/code/hieradata

:puppet:
   :datasource: data
</pre>

This configuration will require YAML files in  _/etc/puppetlabs/code/hieradata_ these need to contain
Hash data, sample files matching the hierarchy described in the _Why?_ section are below:

_/etc/puppetlabs/code/hieradata/sites/dc1.yaml_:
<pre>
---
ntpserver: ntp1.dc1.example.com
sysadmin: dc1noc@example.com
</pre>

_/etc/puppetlabs/code/hieradata/sites/dc2.yaml_:
<pre>
---
ntpserver: ntp1.dc2.example.com
</pre>

_/etc/puppetlabs/code/hieradata/common.yaml_:
<pre>
---
sysadmin: "sysadmin@%{domain}"
ntpserver: 1.pool.ntp.org
</pre>

## Querying from CLI

You can query your data from the CLI.  By default the CLI expects a config file in _/etc/hiera.yaml_
but you can pass _--config_ to override that.

This example searches Hiera for node data.  Scope is loaded from a Puppet created YAML facts
store as found on your Puppet Masters.

If no data is found and the facts had a location=dc1 fact the default would be _sites/dc1_

<pre>
$ hiera acme_version 'sites/%{location}' --yaml /opt/puppetlabs/puppet/cache/yaml/facts/example.com.yaml
</pre>

You can also supply extra facts on the CLI, assuming Puppet facts did not have a location fact:

<pre>
$ hiera acme_version 'sites/%{location}' location=dc1 --yaml /opt/puppetlabs/puppet/cache/yaml/facts/example.com.yaml
</pre>

Or if you use MCollective you can fetch the scope from a remote node's facts:

<pre>
$ hiera acme_version 'sites/%{location}' -m box.example.com
</pre>

You can also do array merge searches on the CLI:

<pre>
$ hiera -a classes location=dc1
["users::common", "users::dc1"]
</pre>

## Querying from code

This is the same query programatically as in the above CLI example:

<pre>
require 'rubygems'
require 'hiera'
require 'puppet'

# load the facts for example.com
scope = YAML.load_file("/opt/puppetlabs/puppet/cache/yaml/facts/example.com.yaml")

# create a new instance based on config file
hiera = Hiera.new(:config => "/etc/puppetlabs/code/hiera.yaml")

# resolve the 'acme_version' variable based on scope
#
# given a fact location=dc1 in the facts file this will default to a branch sites/dc1
# and allow hierarchical overrides based on the hierarchy defined in the config file
puts "ACME Software Version: %s" % [ hiera.lookup("acme_version", "sites/%{location}", scope) ]
</pre>

## Extending

There exist 2 backends at present in addition to the bundled YAML one.

### JSON

This can be found on github under _ripienaar/hiera-json_.  This is a good example
of file based backends as Hiera provides a number of helpers to make writing these
trivial.

### Puppet

This is much more complex and queries the data from the running Puppet state, it's found
on GitHub under _ripienaar/hiera-puppet_.

This is a good example to learn how to map your internal program state into what Hiera
wants as I needed to do with the Puppet Scope.

It includes a Puppet Parser Function to query the data from within Puppet.

When used in Puppet you'd expect Hiera to log using the Puppet infrastructure, this
plugin includes a Puppet Logger plugin for Hiera that uses the normal Puppet logging
methods for all logging.

## License

See LICENSE file.

## Support

Please log tickets and issues at our [JIRA tracker](http://tickets.puppetlabs.com).  A [mailing
list](https://groups.google.com/forum/?fromgroups#!forum/puppet-users) is
available for asking questions and getting help from others. In addition there
is an active #puppet channel on Freenode.

We use semantic version numbers for our releases, and recommend that users stay
as up-to-date as possible by upgrading to patch releases and minor releases as
they become available.

Bugfixes and ongoing development will occur in minor releases for the current
major version. Security fixes will be backported to a previous major version on
a best-effort basis, until the previous major version is no longer maintained.


For example: If a security vulnerability is discovered in Hiera 1.3.0, we
would fix it in the 1 series, most likely as 1.3.1. Maintainers would then make
a best effort to backport that fix onto the latest Hiera release they carry.

Long-term support, including security patches and bug fixes, is available for
commercial customers. Please see the following page for more details:

[Puppet Enterprise Support Lifecycle](http://puppetlabs.com/misc/puppet-enterprise-lifecycle)

## MAINTAINERS

* Thomas Hallgren
* Henrik Lindberg
