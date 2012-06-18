# <a name="title"></a> Knife::Server [![Build Status](https://secure.travis-ci.org/fnichol/knife-server.png?branch=master)](http://travis-ci.org/fnichol/knife-server)

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

#### Common Configuration

##### chef\_node\_name

##### platform

##### ssh\_user

##### ssh\_port

##### identity\_file

##### prerelease

##### bootstrap\_version

##### template\_file

##### distro

##### webui\_password

##### amqp\_password

### <a name="knife-server-bootstrap-ec2"></a> knife server bootstrap ec2

#### Configuration

## <a name="roadmap"></a> Roadmap

* Support for other platforms (alternative bootstrap templates)
* Support for Rackspace provisioning (use knife-rackspace gem)
* Support for standalone server provisioning

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
