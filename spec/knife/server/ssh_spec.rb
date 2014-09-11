# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
# Copyright:: Copyright (c) 2012 Fletcher Nichol
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "net/ssh/test"

require "knife/server/ssh"

# Terrible hack to deal with Net::SSH:Test::Extensions which monkey patches
# `IO.select` with a version for testing Net::SSH code. Unfortunetly this
# impacts other code, so we'll "un-patch" this after each spec and "re-patch"
# it before the next one.

def depatch_io
  IO.class_exec do
    class << self
      alias_method :select, :select_for_real
    end
  end
end

def repatch_io
  IO.class_exec do
    class << self
      alias_method :select, :select_for_test
    end
  end
end

# Major hack-and-a-half to add basic `Channel#request_pty` support to
# Net::SSH's testing framework. The `Net::SSH::Test::LocalPacket` does not
# recognize the `"pty-req"` request type, so bombs out whenever this channel
# request is sent.
#
# This "make-work" fix adds a method (`#sends_request_pty`) which works just
# like `#sends_exec` expcept that it enqueues a patched subclass of
# `LocalPacket` which can deal with the `"pty-req"` type.
#
# An upstream patch to Net::SSH will be required to retire this yak shave ;)

module Net
  module SSH
    module Test
      # Dat monkey patch
      class Channel
        def sends_request_pty
          pty_data = ["xterm", 80, 24, 640, 480, "\0"]

          script.events << Class.new(Net::SSH::Test::LocalPacket) do
            def types
              if @type == 98 && @data[1] == "pty-req"
                @types ||= [
                  :long, :string, :bool, :string,
                  :long, :long, :long, :long, :string
                ]
              else
                super
              end
            end
          end.new(:channel_request, remote_id, "pty-req", false, *pty_data)
        end
      end
    end
  end
end

# Quick-and-dirty port of MiniTest's assert method, needed for Net::SSH:Test's
# #assert_scripted method
def assert(test, msg = nil)
  unless test
    msg ||= "Failed assertion, no message given."
    msg = msg.call if Proc == msg
    raise msg
  end
  true
end

describe Knife::Server::SSH do
  include Net::SSH::Test

  let(:ssh_options) do
    { :host => "wadup.example.com", :user => "bob",
      :keys => "/tmp/whoomp.key", :port => "2222" }
  end

  let(:ssh_connection) { connection }

  subject { Knife::Server::SSH.new(ssh_options) }

  before do
    repatch_io
    allow(Net::SSH).to receive(:start).and_yield(ssh_connection)
  end

  after do
    depatch_io
  end

  it "passes ssh options to ssh sessions" do
    write_story do |channel|
      channel.sends_exec(
        %{sudo USER=root HOME="$(getent passwd root | cut -d : -f 6)" } \
        "bash -c 'wat'"
      )
      channel.gets_exit_status(0)
    end
    expect(Net::SSH).to receive(:start).with("wadup.example.com", "bob",
      :keys => "/tmp/whoomp.key", :port => "2222")

    assert_scripted { subject.exec! "wat" }
  end

  it "sets default user to root" do
    write_story do |channel|
      channel.sends_exec("wat")
      channel.gets_exit_status(0)
    end
    ssh_options.delete(:user)
    expect(Net::SSH).to receive(:start).
      with(anything, "root", anything)

    assert_scripted { Knife::Server::SSH.new(ssh_options).exec!("wat") }
  end

  it "sets default port to 22" do
    write_story do |channel|
      channel.sends_exec(
        %{sudo USER=root HOME="$(getent passwd root | cut -d : -f 6)" } \
        "bash -c 'wat'"
      )
      channel.gets_exit_status(0)
    end
    ssh_options.delete(:port)
    expect(Net::SSH).to receive(:start).
      with(anything, anything, hash_including(:port => "22"))

    assert_scripted { Knife::Server::SSH.new(ssh_options).exec!("wat") }
  end

  it "does not add sudo to the command if user is root" do
    write_story do |channel|
      channel.sends_exec("zappa")
      channel.gets_exit_status(0)
    end
    ssh_options[:user] = "root"

    assert_scripted { Knife::Server::SSH.new(ssh_options).exec!("zappa") }
  end

  it "adds sudo to the command if user is not root" do
    write_story do |channel|
      channel.sends_exec(
        %{sudo USER=root HOME="$(getent passwd root | cut -d : -f 6)" } \
        "bash -c 'zappa'"
      )
      channel.gets_exit_status(0)
    end

    assert_scripted { Knife::Server::SSH.new(ssh_options).exec!("zappa") }
  end

  it "returns the output of ssh command" do
    write_story do |channel|
      channel.sends_exec("youdoitnow")
      channel.gets_data("okthen")
      channel.gets_exit_status(0)
    end
    ssh_options[:user] = "root"

    assert_scripted { expect(subject.exec!("youdoitnow")).to eq("okthen") }
  end

  def write_story
    story do |script|
      channel = script.opens_channel
      channel.sends_request_pty
      yield channel if block_given?
      channel.gets_close
      channel.sends_close
    end
  end
end
