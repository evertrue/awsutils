require "spec_helper"
require 'awsutils/ec2addsg'

describe AwsUtils::Ec2AddSecurityGroup do
  it "takes security_group name" do
    name = "rspec_test_group"
    sg = AwsUtils::Ec2AddSecurityGroup.new( [name] )
    sg.name.should == name
  end
end