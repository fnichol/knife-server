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

##### --platform PLATFORM (-P)

##### --ssh-user USER (-x)

##### --ssh-port PORT (-p)

##### --identity-file IDENTITY\_FILE (-i)

##### --prerelease

##### --bootstrap-version VERSION

##### --template-file TEMPLATE

##### --distro DISTRO (-d)

##### --webui-password PASSWORD

##### --amqp-password PASSWORD

### <a name="knife-server-bootstrap-ec2"></a> knife server bootstrap ec2

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
* knife server backup backed by s3
* knife server restore {nodes,roles,environments,data bags,all}
* knife server restore from s3 archive

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
