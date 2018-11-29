require 'spec_helper'
require 'awsutils/ec2lsgrp'
require 'byebug'

describe AwsUtils::Ec2LsGrp do
  let(:ec2lsgrp) { AwsUtils::Ec2LsGrp.new }
  let(:fog) { Fog::Compute::AWS.new }
  let(:local_group_name) { 'test_group' }

  before(:each) do
    Fog.mock!
    Fog::Mock.reset
    allow(ec2lsgrp).to receive(:puts)
  end

  describe '#group' do
    let(:group_set) do
      [
        object_double(
          'security_groups',
          name: 'test_group',
          group_id: 'sg-a1b2c3d4'
        )
      ]
    end

    before { allow(ec2lsgrp).to receive(:groups).and_return group_set }

    context 'search by valid name' do
      it 'return the group object' do
        expect(ec2lsgrp.send('group', 'test_group')).to eq group_set.first
      end
    end

    context 'search by valid ID' do
      it 'return the group object' do
        expect(ec2lsgrp.send('group', 'sg-a1b2c3d4')).to eq group_set.first
      end
    end

    context 'search by invalid name' do
      it 'return nil' do
        expect(ec2lsgrp.send('group', 'invalid_group')).to eq nil
      end
    end

    context 'search by invalid ID' do
      it 'return nil' do
        expect(ec2lsgrp.send('group', 'sg-00000000')).to eq nil
      end
    end
  end

  context 'specify no arguments' do
    before do
      allow(ec2lsgrp).to receive(:search).and_return nil
    end

    it 'raise ArgumentError' do
      expect { ec2lsgrp.run }.to raise_error(
        ArgumentError,
        'Please specify a security group'
      )
    end
  end

  context 'search for a group' do
    context 'by a name that does not exist' do
      before do
        allow(ec2lsgrp).to receive(:search).and_return 'bad-group-name'
      end

      it 'should raise GroupDoesNotExist exception' do
        expect { ec2lsgrp.run }.to raise_error AwsUtils::GroupDoesNotExist
      end
    end

    context 'by an id that does not exist' do
      before do
        allow(ec2lsgrp).to receive(:search).and_return 'sg-a1b2c3d4'
      end

      it 'should raise GroupDoesNotExist exception' do
        expect { ec2lsgrp.run }.to raise_error AwsUtils::GroupDoesNotExist
      end
    end

    context 'with no permissions' do
      let(:local_group_obj) do
        group_obj = fog.security_groups.create(
          'description' => '',
          'name' => local_group_name
        )
        fog.security_groups.get_by_id(group_obj.group_id)
      end

      before do
        allow(ec2lsgrp).to receive(:search).and_return local_group_name
      end

      it 'searches for the group by id' do
        expect(ec2lsgrp).to receive(:group).with(local_group_name)
                                           .and_return(local_group_obj)
        ec2lsgrp.run
      end
    end

    context 'with source group belonging to same userid' do
      let(:dummy_group_name) { 'dummy_group' }

      let(:dummy_group_obj) do
        group_obj = fog.security_groups.create(
          'description' => 'Dummy Group',
          'name' => dummy_group_name
        )
        fog.security_groups.get_by_id(group_obj.group_id)
      end

      let(:local_group_obj) do
        group_obj = fog.security_groups.create(
          'description' => '',
          'name' => local_group_name
        )
        group_obj.authorize_port_range(
          8080..8080,
          group: { dummy_group_obj.owner_id => dummy_group_obj.group_id }
        )
        fog.security_groups.get_by_id(group_obj.group_id)
      end

      before do
        allow(ec2lsgrp).to receive(:search).and_return local_group_name
      end

      it 'prints a source group list containing only groupName' do
        allow(ec2lsgrp).to receive(:owner_id).and_return local_group_obj.owner_id
        expect do
          ec2lsgrp.perms_out('incoming', local_group_obj.ip_permissions)
        end.to output(/  \d+ groups: #{dummy_group_obj.group_id} \(#{dummy_group_name}\); /).to_stdout
      end
    end

    context 'with source group belonging to another userid' do
      let(:dummy_group_obj) do
        group_obj = fog.security_groups.create(
          'description' => 'Dummy Group',
          'name' => 'dummy_group'
        )
        fog.security_groups.get_by_id(group_obj.group_id)
      end

      let(:dummy_group_name) do
        fog.security_groups.get_by_id(dummy_group_obj.group_id).name
      end

      let(:local_group_obj) do
        group_obj = fog.security_groups.create(
          'description' => '',
          'name' => local_group_name
        )
        group_obj.authorize_port_range(
          8080..8080,
          group: { 'amazon-elb' => dummy_group_obj.group_id }
        )
        fog.security_groups.get_by_id(group_obj.group_id)
      end

      before do
        allow(ec2lsgrp).to receive(:search).and_return local_group_name
      end

      it 'prints a source group list containing userId and groupName' do
        expect do
          ec2lsgrp.perms_out('incoming', local_group_obj.ip_permissions)
        end.to output(/  \d+ groups: #{dummy_group_obj.group_id} \(#{dummy_group_name}, owner: amazon-elb\); /).to_stdout
      end
    end
  end
end
