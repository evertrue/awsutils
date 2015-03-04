require "spec_helper"
require 'awsutils/ec2addsg'

describe AwsUtils::Ec2AddSecurityGroup do
  it "takes security_group name" do
    group_name = 'rspec_test_group'
    ARGV = ['-N', group_name, '-d', 'rspec test group description']
    sg = AwsUtils::Ec2AddSecurityGroup.new
    expect(sg.name).to eq(group_name)
  end
end
