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
  ([@fnicho][])
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

* Pull request [#15](https://github.com/fnichol/knife-server/pull/15): Fix
  identity-file when `nil` is passed in. ([@erikh][])


## 0.3.2 / 2012-12-19

### Improvements

* Pull request [#13](https://github.com/fnichol/knife-server/pull/13): Relax
  version constraint on knife-ec2 gem. ([@wpeterson][])
* Issue [#9](https://github.com/fnichol/knife-server/issues/9): Highlight the
  need to create set various knife.rb configuration settings. ([@fnichol][])
* Issue [#10](https://github.com/fnichol/knife-server/issues/10),
  [#5](https://github.com/fnichol/knife-server/issues/5): Add more
  instructions in knife.rb setup section as using Knife may be new to many
  users of this gem. ([@fnichol][])


## 0.3.1 / 2012-12-12

### Bug fixes

* Pull request [#7](https://github.com/fnichol/knife-server/pull/11): Fix
  identity-file flag for bootstrapping. ([@xdissent][])
* Pull request [#11](https://github.com/fnichol/knife-server/pull/11): Fix
  identity-file flag for EC2 bootstrapping. ([@erikh][])
* Pull request [#8](https://github.com/fnichol/knife-server/pull/8): Merge
  server config to Ec2ServerCreate config. ([@stormsilver][])

### Improvements

* Pull request [#3](https://github.com/fnichol/knife-server/pull/3): Set
  server hostname even if /etc/hostname is not present. ([@iafonov][])
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

* Issue [#2](https://github.com/fnichol/knife-server/issues/2): Improve
  documentation to clarify `knife server bootstrap` is not a proper
  subcommand. ([@fnichol][])

### New features

* Add `knife server backup` subcommand to backup data components (nodes,
  roles, environments, data bags) to the workstation's file system.
  ([@fnichol][])


## 0.1.0 / 2012-06-23

The initial release.

[@danryan]: https://github.com/danryan
[@erikh]: https://github.com/erikh
[@fnichol]: https://github.com/fnichol
[@iafonov]: https://github.com/iafonov
[@stormsilver]: https://github.com/stormsilver
[@wpeterson]: https://github.com/wpeterson
[@xdissent]: https://github.com/xdissent
