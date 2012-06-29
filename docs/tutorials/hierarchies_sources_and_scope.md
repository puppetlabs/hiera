# Hierarchies, Sources, and Scope

The key to mastering Hiera is understanding the following concepts:

 * Hierarchies
 * Sources
 * Scope

## Hierarchies

At the very core of Hiera are the data hierarchies, which are made up of
sources. Hierarchies are specified in Hiera configuration file `hiera.yaml` via the
`:hierarchy:` array.

    :hierarchy:
      - "%{certname}"
      - "%{environment}"
      - default

There are three sources in the above hierarchy, `%{certname}`, `%{environment}`,
and `default`. The first two sources, `%{certname}` and `%{environment}`,
represent dynamic sources which will be resolved at runtime. The third source
`default` is static.


When looking up a key Hiera iterates through each source in the hierarchy
starting with the first one in the list. In our case `%{certname}`. There is
no limit to the number of sources you can have. But lets not go crazy; try and
keep your hierarchy below 5 - 6 levels deep. Any more than this you should
start thinking about custom facts or how your data is organized.

### Order is important

Hiera uses the priority resolution type by default. This means Hiera stops at
the first source in the hierarchy that provides a non `nil` answer. The
behavior is a slightly different for the array and hash resolution types. Every
scope in the hierarchy will be searched, but data is appended not overridden!

## Sources

Each level of the hierarchy is represented by a source which comes in two
flavors, static and dynamic.

### Static sources

A source is considered static when it appears in the hierarchy as a simple
string.

    :hierarchy:
      - default

-
You should consider using a static source when you want a certain level in
the hierarchy to apply to all nodes.

### Dynamic sources

A source is considered dynamic when it appears in the hierarchy as a string
enclosed between `%{}` like this:

    :hierarchy:
      - %{certname}

Dynamic sources are interpolated by Hiera at runtime.

-
You should consider using a dynamic source when you want to provide different
data based on Facter Facts.

## Scope

A scope is a collection of key/value pairs:

    certname: agent.puppetlabs.com
    environment: production
    operatingsystem: Debian

If you are thinking scopes look a lot like Facter Facts you are on to
something. Hiera was designed around Facter Facts being the primary input
for scope.

### Source interpolation

Hiera uses the scope when interpolating sources in the hierarchy.

<img src='https://github.com/kelseyhightower/hiera/raw/maint/1.0rc/add_getting_started_tutorial/docs/images/hiera_hierarchy_resolution.png' />

Scopes can be empty, and when they are, dynamic sources are excluded from the
hierarchy at run time.

<img src='https://github.com/kelseyhightower/hiera/raw/maint/1.0rc/add_getting_started_tutorial/docs/images/hiera_hierarchy_resolution_empty_scope.png' />

### Feeding Hiera your scope

You can provide Hiera a scope via the command line using the `--yaml` or
`--json` options.

For example:

If we had the following scope:

    $ cat /tmp/scope.yaml
    ---
    certname: agent.example.com
    environment: production



You can feed it to Hiera like this:

    $ hiera --yaml /tmp/scope.yaml driftfile
    /etc/ntp/drift

-
**Note:** If you run into the follow error, you need to make sure Puppet is installed:

    Could not load YAML scope: LoadError: no such file to load -- puppet

The reason for this is that the scope yaml file could have been produced by
Puppet, and contained serialized objects. Since it would be desirable to use 
Hiera without Puppet, this restrict will be removed in the future.


