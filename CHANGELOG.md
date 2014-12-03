## 1.4.0 / 2014-12-03

### Upstream changes

* Fix support for knife-openstack >= 1.0.0. ([@fnichol][])
* Fix support for knife-digtal_ocean >= 2.0.0. ([@fnichol][])


## 1.3.0 / 2014-09-14

### New features

* Pull request [#55][]: Add Digital Ocean support! ([@fnichol][])


## 1.2.0 / 2014-09-13

### Upstream changes

* Pull request [#48][], issue [#50][]: Fix issue affecting newer Knife/Chef versions dealing with nil default options. ([@dldinternet][], [@fnichol][])
* Patch specific versions of Chef to fix `knife configure` bug. ([@fnichol][])

### New features

* Pull request [#51][]: Add OpenStack support to knife-server command. ([@johnbellone][])
* Re-use existing private user key for omnibus bootstraps. ([@fnichol][])
* Add support for downloading packages from a URL using the `--url` flag. ([@fnichol][])

### Improvements

* Pull request [#43][]: Enable ssh on firewall. ([@taylor][])
* Add output when backing up and writing keys locally. ([@fnichol][])
* Issue [#28][]: Shunt stderr/ioctl warnings to a tmp log file for knife configure. ([@fnichol][])
* Issue [#9][], issue [#10][]: Validate that node_name & client_key are set when running plugins, giving the user a hint that their local knife.rb is not currently set up correctly. ([@fnichol][])
* Update download URL for Omnibus packages. ([@fnichol][])
* Update testing dependencies, upgrade to RSpec 3.x, freshen TravisCI build matrix, add style and complexity support. ([@fnichol][])


## 1.1.0 / 2013-07-26

### New features

* Pull request [#42][]: Add support for Linode (via the knife-linode gem). ([@fnichol][])

### Improvements

* Pull request [#41][]: Add new option pretty_print for knife server backup. ([@sawanoboly][])

## 1.0.1 / 2013-04-11

### Bug fixes

* Pull request [#29][]: Fix README typo in ssh password argument. ([@ranjib][])
* Pull request [#34][]: Fix AMQP_PASSWORD propagation. ([@erikh][])

### Improvements

* Pull request [#35][]: Add VPC support. ([@jssjr][])
* Pull request [#34][]: Provide better information when the package can't be
  downloaded. ([@erikh][])


## 1.0.0 / 2013-02-28

### Breaking Changes

* Default Chef Server installed is the latest Chef 11 (erchef) version from
  Omnibus packages via the `"chef11/omnibus"` template. All platform supported
  by the Omnibus packages should work out of the box. Chef Server 10 is still
  supported by setting the --bootstrap-version flag to "10". ([@fnichol][])
* WebUI is no longer configured to start up by default (--enable-webui flag
  introduced to re-enable). For more details, please read
  http://lists.opscode.com/sympa/arc/chef-dev/2013-02/msg00023.html.
  ([@fnichol][])
* The knife-ec2 gem is no longer a direct dependency; you must add install this
  gem or add it to your Gemfile in order to use `knife server bootstrap ec2`.
  ([@fnichol][])

### New features

* First class support for RHEL platform family nodes including CentOS,
  Scientific, RHEL, Amazon Linux, etc. Seriously, this is huge. ([@danryan][],
  [@erikh][])
* Support for installing Chef 11 (erchef) servers from Omnibus packages.
  ([@fnichol][])
* Add --log-level flag to help debug bootstrap template output. ([@fnichol][])
* Support all relevant options from `Chef::Knife::Bootstrap` and
  `Chef::Knife::Ec2ServerCreate` in the standalone and ec2 subcommands. This
  includes --bootstrap-version, ssh options, ebs options, etc. ([@fnichol][])
* An auto mode (set via --platform auto) which will detect the node's platform
  and run the appropriate template for Chef 10 servers. Currently only
  supported with standalone subcommand. ([@erikh][])

### Improvements

* Ensure config parameters are applied in the right order for Chef 10/11.
  ([@fnichol][])
* Add matrix build support to TravisCI for multiple versions of Chef.
  ([@fnichol][])
* Update README badges (better consistency). ([@fnichol][])
* Update CHANGLOG format headings for Vandamme/Gemnasium compatability.
  ([@fnichol][])
* Update README documentation with 1.0.0 changes. ([@fnichol][])


## 0.3.3 / 2012-12-24

### Bug fixes

* Pull request [#15][]: Fix identity-file when `nil` is passed in. ([@erikh][])


## 0.3.2 / 2012-12-19

### Improvements

* Pull request [#13][]: Relax version constraint on knife-ec2 gem.
  ([@wpeterson][])
* Issue [#9][]: Highlight the need to create set various knife.rb
  configuration settings. ([@fnichol][])
* Issue [#10][], [#5][]: Add more instructions in knife.rb setup section as
  using Knife may be new to many users of this gem. ([@fnichol][])


## 0.3.1 / 2012-12-12

### Bug fixes

* Pull request [#7][]: Fix identity-file flag for bootstrapping.
  ([@xdissent][])
* Pull request [#11][]: Fix identity-file flag for EC2 bootstrapping.
  ([@erikh][])
* Pull request [#8][]: Merge server config to Ec2ServerCreate config.
  ([@stormsilver][])

### Improvements

* Pull request [#3][]: Set server hostname even if /etc/hostname is not
  present. ([@iafonov][])
* Update usage section in README.


## 0.3.0 / 2012-07-07

### New features

* Add `knife server restore` subcommand to restore data components (nodes,
  roles, environments, data bags) from the workstation's file system.
  ([@fnichol][])


## 0.2.2 / 2012-07-04

### New features

* Add `knife server bootstrap standalone` subcommand to setup any server
  accessible via SSH. ([@fnichol][])

### Improvements

* Add Code Climate badge to README. ([@fnichol][])


## 0.2.1 / 2012-07-03

### Improvements

* Move knife plugin requires into dep block for speedier knife loads. Source:
  http://wiki.opscode.com/display/chef/Knife+Plugins. ([@fnichol][])


## 0.2.0 / 2012-07-03

### Bug fixes

* Issue [#2][]: Improve documentation to clarify `knife server bootstrap` is
  not a proper subcommand. ([@fnichol][])

### New features

* Add `knife server backup` subcommand to backup data components (nodes,
  roles, environments, data bags) to the workstation's file system.
  ([@fnichol][])


## 0.1.0 / 2012-06-23

The initial release.


<!--- The following link definition list is generated by PimpMyChangelog --->
[#2]: https://github.com/fnichol/knife-server/issues/2
[#3]: https://github.com/fnichol/knife-server/issues/3
[#5]: https://github.com/fnichol/knife-server/issues/5
[#7]: https://github.com/fnichol/knife-server/issues/7
[#8]: https://github.com/fnichol/knife-server/issues/8
[#9]: https://github.com/fnichol/knife-server/issues/9
[#10]: https://github.com/fnichol/knife-server/issues/10
[#11]: https://github.com/fnichol/knife-server/issues/11
[#13]: https://github.com/fnichol/knife-server/issues/13
[#15]: https://github.com/fnichol/knife-server/issues/15
[#28]: https://github.com/fnichol/knife-server/issues/28
[#29]: https://github.com/fnichol/knife-server/issues/29
[#34]: https://github.com/fnichol/knife-server/issues/34
[#35]: https://github.com/fnichol/knife-server/issues/35
[#41]: https://github.com/fnichol/knife-server/issues/41
[#42]: https://github.com/fnichol/knife-server/issues/42
[#43]: https://github.com/fnichol/knife-server/issues/43
[#48]: https://github.com/fnichol/knife-server/issues/48
[#50]: https://github.com/fnichol/knife-server/issues/50
[#51]: https://github.com/fnichol/knife-server/issues/51
[#55]: https://github.com/fnichol/knife-server/issues/55
[@danryan]: https://github.com/danryan
[@dldinternet]: https://github.com/dldinternet
[@erikh]: https://github.com/erikh
[@fnichol]: https://github.com/fnichol
[@iafonov]: https://github.com/iafonov
[@johnbellone]: https://github.com/johnbellone
[@jssjr]: https://github.com/jssjr
[@ranjib]: https://github.com/ranjib
[@sawanoboly]: https://github.com/sawanoboly
[@stormsilver]: https://github.com/stormsilver
[@taylor]: https://github.com/taylor
[@wpeterson]: https://github.com/wpeterson
[@xdissent]: https://github.com/xdissent
