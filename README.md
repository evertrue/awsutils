# Awsutils

A set of useful tools for interacting with Amazon Web Services (AWS)

## Installation

Add this line to your application's Gemfile:

    gem 'awsutils'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install awsutils

## Usage

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
  - source: 76.19.192.82/32
    proto: tcp
    port: !ruby/range
      begin: 22
      end: 22
    source: 75.147.22.123/32
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
