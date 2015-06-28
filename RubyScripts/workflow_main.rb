#!/usr/bin/env ruby
require 'aws-sdk' # gem install aws-sdk

DOMAIN_NAME = 'CondorcetVote'
WORKFLOW_TYPE_NAME = 'TestWorkflowType'
TASK_LIST_NAME = 'TestTaskList'
DECIDER_IDENTITY = 'TestDecider'

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

puts "Starting poll for #{TASK_LIST_NAME}"
decision_task = swf.poll_for_decision_task(
  :domain => domain.name,
  :task_list => { :name => TASK_LIST_NAME },
  :identity => DECIDER_IDENTITY
)
puts decision_task.inspect
