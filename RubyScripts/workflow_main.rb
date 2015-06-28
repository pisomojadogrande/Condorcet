#!/usr/bin/env ruby
require 'aws-sdk' # gem install aws-sdk

DOMAIN_NAME = 'CondorcetVote'
WORKFLOW_TYPE_NAME = 'TestWorkflowType'

access_key_id = ENV['AWS_ACCESS_KEY']
secret_key = ENV['AWS_SECRET_KEY']

Aws.config[:region] = 'us-east-1'

swf = Aws::SWF::Client.new :access_key_id => access_key_id, :secret_access_key => secret_key

domain = swf.list_domains(:registration_status => 'REGISTERED').domain_infos.find { |d| d.name == DOMAIN_NAME }
puts domain.inspect

workflow_type = swf.list_workflow_types(
  :domain => domain.name,
  :name => WORKFLOW_TYPE_NAME,
  :registration_status => 'REGISTERED'
)
puts workflow_type.inspect
