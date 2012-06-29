# Getting Started

Hiera is a simple hierarchal database which provides an easy to use interface
for looking up data using a key.

    $ hiera puppetlabs_home_page
    http://puppetlabs.com

## Installation

We are going to install Hiera using Rubygems, so now is a good time to make
sure you meet the prerequisites.

### Prerequisites

 * Ruby 1.8.5+
 * Rubygems 1.3.0+

### Installing Hiera via Rubygems

    $ gem install hiera
    Successfully installed hiera-0.3.0
    1 gem installed
    Installing ri documentation for hiera-0.3.0...
    Installing RDoc documentation for hiera-0.3.0...

Make sure we can run the hiera command:

    $ hiera -v
    0.3.0

-

**Note:** Some Linux distributions such as Debian squeeze do not put the gem bin
directory (`/var/lib/gems/1.8/bin`) in your PATH by default. You may have
to call hiera using the full path:

    $ /var/lib/gems/1.8/bin/hiera -v
    0.3.0

## Configuration

Before using Hiera we need to create a configuration file. By default Hiera
attempts to load `hiera.yaml` from the `/etc/` directory. Lets create that
file now:

    $ vim /etc/hiera.yaml
    ---
    :backends:
      - yaml

    :hierarchy:
      - global

    :yaml:
      :datadir: /var/lib/hiera/data

-

**Note:** If Hiera cannot locate `/etc/hiera.yaml` you will receive the follow
error when trying to lookup a value:

    $ hiera key
    Failed to start Hiera: RuntimeError: Config file /etc/hiera.yaml not found

You can specify a different configuration file using the `--config` option:

    $ hiera --config ~/hiera.yaml key

## Adding data

With configuration out of the way, lets add some data. The yaml backend
expects to find data files under the `datadir` we configured earlier.

Create the `/var/lib/hiera/data` data directory:

    $ mkdir -p /var/lib/hiera/data

For each source in the `hierarchy`, the yaml backend will search for a
corresponding YAML file under the `datadir`.

For example, our `hierarchy` consists of a single source named `global`. The
yaml backend will look for `/var/lib/hiera/data/global.yaml`, and if missing
skips it and move on to the next source in the hierarchy.

Lets add some data to the `global` source:

    $ vim /var/lib/hiera/data/global.yaml
    ---
    driftfile: '/etc/ntp/drift'
    ntpservers:
      - '0.north-america.pool.ntp.org'
      - '1.north-america.pool.ntp.org'

## Looking up data

Now that we have our configuration setup and some data, lets lookup the
'driftfile' key:

    $ /var/lib/gems/1.8/bin/hiera driftfile
    /etc/ntp/drift

We get extacaly what we expected, '/etc/ntp/drift'.

Running the lookup command with the `--debug` flag, we can see the details
of how Hiera lookups data:

    $ /var/lib/gems/1.8/bin/hiera driftfile --debug
    DEBUG: Thu Jun 28 09:54:04 -0400 2012: Hiera YAML backend starting
    DEBUG: Thu Jun 28 09:54:04 -0400 2012: Looking up driftfile in YAML backend
    DEBUG: Thu Jun 28 09:54:04 -0400 2012: Looking for data source global
    /etc/ntp/drift

