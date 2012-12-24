## 0.3.4.dev (unreleased)


## 0.3.3 (December 24, 2012)

### Bug fixes

* Pull request [#15](https://github.com/fnichol/knife-server/pull/15): Fix
  identity-file when `nil` is passed in. ([@erikh][])


## 0.3.2 (December 19, 2012)

### Improvements

* Pull request [#13](https://github.com/fnichol/knife-server/pull/13): Relax
  version constraint on knife-ec2 gem. ([@wpeterson][])
* Issue [#9](https://github.com/fnichol/knife-server/issues/9): Highlight the
  need to create set various knife.rb configuration settings. ([@fnichol][])
* Issue [#10](https://github.com/fnichol/knife-server/issues/10),
  [#5](https://github.com/fnichol/knife-server/issues/5): Add more
  instructions in knife.rb setup section as using Knife may be new to many
  users of this gem. ([@fnichol][])


## 0.3.1 (December 12, 2012)

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


## 0.3.0 (July 7, 2012)

### New features

* Add `knife server restore` subcommand to restore data components (nodes,
  roles, environments, data bags) from the workstation's file system.
  ([@fnichol][])


## 0.2.2 (July 4, 2012)

### New features

* Add `knife server bootstrap standalone` subcommand to setup any server
  accessible via SSH. ([@fnichol][])

### Improvements

* Add Code Climate badge to README. ([@fnichol][])


## 0.2.1 (July 3, 2012)

### Improvements

* Move knife plugin requires into dep block for speedier knife loads. Source:
  http://wiki.opscode.com/display/chef/Knife+Plugins. ([@fnichol][])


## 0.2.0 (July 3, 2012)

### Bug fixes

* Issue [#2](https://github.com/fnichol/knife-server/issues/2): Improve
  documentation to clarify `knife server bootstrap` is not a proper
  subcommand. ([@fnichol][])

### New features

* Add `knife server backup` subcommand to backup data components (nodes,
  roles, environments, data bags) to the workstation's file system.
  ([@fnichol][])


## 0.1.0 (June 23, 2012)

The initial release.

[@erikh]: https://github.com/erikh
[@fnichol]: https://github.com/fnichol
[@iafonov]: https://github.com/iafonov
[@stormsilver]: https://github.com/stormsilver
[@wpeterson]: https://github.com/wpeterson
[@xdissent]: https://github.com/xdissent
