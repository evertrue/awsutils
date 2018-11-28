# Awsutils
[![Travis (.org)](https://img.shields.io/travis/org/evertrue/awsutils.svg)](https://travis-ci.org/evertrue/awsutils)
[![Gem](https://img.shields.io/gem/v/awsutils.svg)](https://rubygems.org/gems/awsutils)

A set of useful tools for interacting with Amazon Web Services (AWS)

## Installation

Add this line to your application's Gemfile:

    gem 'awsutils'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install awsutils

## Usage

awslogs
-------
Dumps logs from CloudWatch Logs for easy grepping (see `awslogs --help` for details).

ec2listmachines
---------------
Show a list of all EC2 instances in your account.

ec2info
-------
Display very detailed info about a single instance (-s/--short for a concise version).

ec2addsg
--------
Create an EC2 security group with a set of pre-defined (from a YAML file) rules.  Here's an example YAML file:

```YAML
  ---
  - source: 1.2.3.4/32
    proto: tcp
    port: !ruby/range
      begin: 22
      end: 22
    source: sample_group
    proto: tcp
    port: !ruby/range
      begin: 22
      end: 22
  - dest: eherot_test
    proto: tcp
    port: !ruby/range
      begin: 22
      end: 22
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
