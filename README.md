# <a name="title"></a> Knife::Server

[![Build Status](https://secure.travis-ci.org/fnichol/knife-server.png?branch=master)](http://travis-ci.org/fnichol/knife-server) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/fnichol/knife-server)

An Opscode Chef knife plugin to manage Chef Servers. Bootstrap a new Chef
Server on Amazon's EC2 or a standalone server. Backup and restore your Chef
Server or Hosted Chef's node, role, data bag, and environment JSON data.

## <a name="usage"></a> Usage

Follow the [installation](#installation) instructions, then you are ready
to create your very own Chef Server running Ubuntu on Amazon's EC2 service:

```bash
$ knife server bootstrap ec2 --ssh-user ubuntu \
  --node-name chefapalooza.example.com
```

Or maybe you want to try out a Chef Server using [Vagrant][vagrant_site]?

```bash
$ cat <<VAGRANTFILE > Vagrantfile
Vagrant::Config.run do |config|
  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.network :hostonly, "192.168.33.11"
  config.vm.customize ["modifyvm", :id, "--memory", 2048]
end
VAGRANTFILE
$ vagrant up
$ knife server bootstrap standalone --ssh-user vagrant \
  --node-name chefapalooza.example.com --host 192.168.33.11
```

Taking a backup of all node, role, data bag, and environment data is also a
snap:

```bash
$ knife server backup
```

Restoring all that data isn't too hard either:

```bash
$ knife server restore
```

Let's say you have all your roles, environments, and data bags in a Git
repository (remember, Infrastructure as Code) and you want to build a
new Chef Server. Try this:

```bash
$ knife server backup nodes --backup-dir /tmp/old_server
$ knife server bootstrap ec2 --ssh-user ubuntu \
  --node-name chef.example.com
$ knife server restore nodes --backup-dir /tmp/old_server
```

Now fire up your cookbooks, roles, environments, and data bags. Good to go!
Well except for old client keys on your nodes, but this is being looked into.

See [below](#subcommands) for more details.

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

### <a name="installation-knife"></a> knife.rb Setup

When creating a Chef Server the validation key and admin client key will
be installed on your workstation. Therefore, several knife configuration
options are required (descriptions courtesy of the [Chef wiki][wiki_knife]):

* `node_name`: User or client identity (i.e., name) to use for authenticating
  requests to the Chef Server.
* `client_key`: Private key file to authenticate to the Chef server.
  Corresponds to the -k or --key option
* `validation_key`: Specifies the private key file to use when bootstrapping
  new hosts. See knife-client(1) for more information about the validation
  client.

For example:

```ruby
node_name       "gramsay"
client_key      "#{ENV['HOME']}/.chef.d/gramsay.pem"
validation_key  "#{ENV['HOME']}/.chef.d/chef-validator.pem"
```

Most options can be passed to the knife subcommands explicitly but this
quickly becomes tiring, repetitive, and error-prone. A better solution is to
add some of the common configuration to your `~/.chef/knife.rb` or your
projects `.chef/knife.rb` file like so:

```ruby
knife[:aws_access_key_id] = "MY_KEY"
knife[:aws_secret_access_key] = "MY_SECRET"
knife[:region] = "us-west-2"
knife[:availability_zone] = "us-west-2a"
knife[:flavor] = "t1.micro"
```

Better yet, why not try a more generic [knife.rb][chef_bootstrap_knife_rb] file
from the [chef-bootstrap-repo][chef_bootstrap_repo] project?

## <a name="subcommands"></a> Subcommands

### <a name="knife-server-bootstrap"></a> knife server bootstrap (Common Options)

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

**Note** `knife server bootstrap` can not be invoked directly; a subcommand
must be selected which determines the provisioning strategy.

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

Your AWS access key ID.

This option is **required**.

##### --aws-secret-access-key SECRET (-K)

Your AWS API secret access key.

This option is **required**.

##### --region REGION

The desired AWS region, such as `"us-east-1"` or `"us-west-2"`.

The default value is `"us-east-1"` but is strongly encouraged to be set
explicitly.

##### --ssh-key KEY (-S)

The AWS SSH key id.

##### --flavor FLAVOR (-f)

The flavor of EC2 instance (m1.small, m1.medium, etc).

The default value is `"m1.small"`.

##### --image IMAGE (-I)

The AMI for the EC2 instance.

##### --availability-zone ZONE (-Z)

The availability zone for the EC2 instance.

The default value is `"us-east-1b"`.

##### --groups X,Y,Z (-G)

The security groups for this EC2 instance.

The default value is `"infrastructure"`.

##### --tags T=V\[,T=V,...\] (-T)

The tags for this EC2 instance.

The resulting set will include:

* `"Node=#{config[:chef_node_name]}"`
* `"Role=chef_server"`

##### --ebs-size SIZE

The size of the EBS volume in GB, for EBS-backed instances.

##### --ebs-no-delete-on-term

Do not delete EBS volumn on instance termination.

### <a name="knife-server-bootstrap-standalone"></a> knife server bootstrap standalone
Provisions a standalone server that is reachable on the network and sets up
an Open Source Chef Server as described [above](#knife-server-bootstrap). You
are responsible for providing the server so it could be a physical machine,
Vagrant VM with host-only or bridged networking, or a cloud server instance
with a known IP address or host name.

#### Configuration

##### --host FQDN_OR_IP (-H)

Host name or IP address of the host to bootstrap.

This option is **required**.

##### --ssh-password PASSWORD (-P)

The SSH password used when bootstrapping the Chef Server node. If no password
is provided but an SSH key-based authentication fails, then you will be
prompted interactively for a password. In other words, if your server
requires password authentication you can skip this option and type it in after
the plugin starts.

### <a name="knife-server-backup"></a> knife server backup

Pulls Chef data primitives from a Chef Server as JSON for backup. Backups can
be taken of:

* nodes
* roles
* environments
* data bags

A big thanks to [Steven Danna][stevendanna] and [Joshua Timberman][jtimberman]
for the [BackupExport][backup_export] knife plugin which was the inspiration
for this implementation.

#### Configuration

##### COMPONENT[ COMPONENT ...]

The following component types are valid:

* `nodes`
* `roles`
* `environments`
* `data_bags` (note the underscore character)

When no component types are specified, all will be selected for backup.
This is equivalent to invoking:

```bash
$ knife server backup nodes roles environments data_bags
```

##### --backup-dir DIR (-D)

The directory to host backup files. A sub-directory for each data primitive
type will be created. For example if the `backup-dir` was `/backups/chef`
then all all node JSON representations would be written to
`/backups/chef/nodes` and data bag JSON representations would be written to
`/backups/chef/data_bags`.

The default uses the `:file_backup_path` configuration option, the
`:chef_server_url` and the current time to construct a unique directory
(within a second). For example, if the time was "2012-04-01 08:47:11 UTC", and
given the following configuration (in **knife.rb**):

```ruby
file_backup_path  = "/var/chef/backups"
chef_server_url   = "https://api.opscode.com/organizations/coolinc"
```

then a backup directory of
`/var/chef/backups/api.opscode.com_20120401T084711-0000` would be created.

### <a name="knife-server-restore"></a> knife server restore

Restores Chef data primitives from JSON backups to a Chef Server. You can
restore some or all of:

* nodes
* roles
* environments
* data bags

A big thanks to [Steven Danna][stevendanna] and [Joshua Timberman][jtimberman]
for the [BackupRestore][backup_restore] knife plugin which was the inspiration
for this implementation.

#### Configuration

##### COMPONENT[ COMPONENT ...]

The following component types are valid:

* `nodes`
* `roles`
* `environments`
* `data_bags` (note the underscore character)

When no component types are specified, all will be selected for restore.
This is equivalent to invoking:

```bash
$ knife server restore nodes roles environments data_bags \
  --backup-dir /my/backup/dir
```

##### --backup-dir DIR (-D)

The directory to containing backup JSON files. A sub-directory for each data
primitive type is expected (the `knife server backup` subcommand provides
this format).

This option is **required**.

## <a name="roadmap"></a> Roadmap

* Support for other platforms (alternative bootstrap templates)
* Support for Rackspace provisioning (use knife-rackspace gem)
* knife server backup backed by s3 (fog api)
* knife server restore from s3 archive (fog api)

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

[backup_export]:            https://github.com/stevendanna/knife-hacks/blob/master/plugins/backup_export.rb
[backup_restore]:           https://github.com/stevendanna/knife-hacks/blob/master/plugins/backup_restore.rb
[chef_bootstrap_knife_rb]:  https://github.com/fnichol/chef-bootstrap-repo/blob/master/.chef/knife.rb
[chef_bootstrap_repo]:      https://github.com/fnichol/chef-bootstrap-repo/
[jtimberman]:               https://github.com/jtimberman
[knife-ec2]:                https://github.com/opscode/knife-ec2
[stevendanna]:              https://github.com/stevendanna
[vagrant_site]:             http://vagrantup.com/
[wiki_knife]:               http://wiki.opscode.com/display/chef/Knife#Knife-Knifeconfiguration
