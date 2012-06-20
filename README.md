# <a name="title"></a> Knife::Server [![Build Status](https://secure.travis-ci.org/fnichol/knife-server.png?branch=master)](http://travis-ci.org/fnichol/knife-server) [![Dependency Status](https://gemnasium.com/fnichol/knife-server.png)](https://gemnasium.com/fnichol/knife-server)

TODO: Write a gem description

## <a name="usage"></a> Usage

TODO: Write usage instructions here

## <a name="installation"></a> Installation

Add this line to your application's Gemfile:

```ruby
gem 'knife-server'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install knife-server
```

## <a name="subcommands"></a> Subcommands

### <a name="knife-server-bootstrap"></a> knife server bootstrap

These subcommands will install and configure an Open Source Chef Server on
several different clouds/environments. The high level step taken are as
follows:

1. Provision or use a node and install the Chef Server software fronted by
   an Apache2 instance handling SSL for the API port (TCP/443) and the
   WebUI web application (TCP/444).
2. Fetch the validation key from the server and install it onto the
   workstation issuing the knife subcommand. The validation key will be
   installed at the path defined in the knife `validation_key` variable.
   If a key already exists at that path a backup copy will be made in the
   same directory.
3. Create an initial admin client key called `root` in the root user's account
   on the server which can be used for local administration of the Chef
   Server.
4. Create an admin client key with the name defined in the knife
   `node_name` configuration variable and install it onto the workstation
   issuing the knife subcommand. The client key will be installed at the
   path defined in the knife `client_key` configuration variable. If a key
   already exists at that path a backup copy will be made in the same
   directory.

#### Common Configuration

##### --node-name NAME (-N)

The name of your new Chef Server. The hostname of the system will be set to
this value and the self signed SSL certificate will use this value as its CN.
Ideally this will correspond to the A or CNAME DNS record.

This option is **required**.

##### --platform PLATFORM (-P)

The platform type that will be bootstrapped. By convention a bootstrap
template of `chef-server-#{platform}.erb` will be searched for in the
template lookup locations (gems, .chef directory, etc.).

The default value is `"debian"` which support Debian and Ubuntu platforms.

##### --ssh-user USER (-x)

The SSH username used when bootstrapping the Chef Server node. Note that the
some Amazon Machine Images (AMIs) such as the official Canonical Ubuntu images
use non-root SSH users (`"ubuntu"` for Ubuntu AMIs).

The default value is `"root"`.

##### --ssh-port PORT (-p)

The SSH port used when bootstrapping the Chef Server node.

The default value is `"22"`.

##### --identity-file IDENTITY\_FILE (-i)

The SSH identity file used for authentication.

##### --prerelease

Installs a pre-release Chef gem rather than a stable release version.

##### --bootstrap-version VERSION

The version of Chef to install.

##### --template-file TEMPLATE

The full path to location of template to use.

##### --distro DISTRO (-d)

Bootstraps the Chef Server using a particular bootstrap template.

The default is `"chef-server-#{platform}"`.

##### --webui-password PASSWORD

The initial password for the WebUI admin account.

The default value is `"chefchef"`.

##### --amqp-password PASSWORD

The initial password for AMQP.

The default value is `"chefchef"`.

### <a name="knife-server-bootstrap-ec2"></a> knife server bootstrap ec2

Provisions an EC2 instance on the Amazon Web Services (AWS) cloud and sets
up an Open Source Chef Server as described [above](#knife-server-bootstrap).
In addition, the following steps are taken initially:

1. Create and configure an EC2 Security Group called **"infrastructure"** for
   the Chef Server instance. TCP ports 22, 443, and 444 are permitted inbound
   for SSH, the API endpoint, and the WebUI web application respectively.
2. An EC2 instance will be provisioned using configuration and/or defaults
   present using the [knife-ec2][knife-ec2] plugin.

#### Configuration

##### --aws-access-key-id KEY (-A)

##### --aws-secret-access-key SECRET (-K)

##### --region REGION

##### --ssh-key KEY (-S)

##### --flavor FLAVOR (-f)

##### --image IMAGE (-I)

##### --availability-zone ZONE (-Z)

##### --security-groups X,Y,Z (-G)

##### --tags T=V\[,T=V,...\] (-T)

##### --ebs-size SIZE

##### --ebs-no-delete-on-term

## <a name="roadmap"></a> Roadmap

* Support for other platforms (alternative bootstrap templates)
* Support for Rackspace provisioning (use knife-rackspace gem)
* Support for standalone server provisioning
* knife server backup {nodes,roles,environments,data bags,all}
* knife server backup backed by s3 (fog api)
* knife server backup backed by local filesystem
* knife server restore {nodes,roles,environments,data bags,all}
* knife server restore from s3 archive (fog api)
* knife server restore from by local filesystem

## <a name="development"></a> Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## <a name="authors"></a> Authors

Created and maintained by [Fletcher Nichol][fnichol] (<fnichol@nichol.ca>)

## <a name="license"></a> License

Apache License, Version 2.0 (see [LICENSE][license])

[license]:      https://github.com/fnichol/knife-server/blob/master/LICENSE
[fnichol]:      https://github.com/fnichol
[repo]:         https://github.com/fnichol/knife-server
[issues]:       https://github.com/fnichol/knife-server/issues
[contributors]: https://github.com/fnichol/knife-server/contributors

[knife-ec2]:    https://github.com/opscode/knife-ec2
