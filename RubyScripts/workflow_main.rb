#!/usr/bin/env ruby
require 'aws-sdk' # gem install aws-sdk
require 'securerandom'

DOMAIN_NAME = 'CondorcetVote'
WORKFLOW_TYPE_NAME = 'TestWorkflowType'
WORKFLOW_ID = 'TestWorkflowId'
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

task_list = SecureRandom.uuid

r = swf.start_workflow_execution(
  :domain => DOMAIN_NAME,
  :workflow_id => WORKFLOW_ID,
  :workflow_type => { :name => WORKFLOW_TYPE_NAME, :version => '0.1' },
  :task_list => { :name => task_list },
  :input => 'Some input string',
  :execution_start_to_close_timeout => '120', # Time me out in 2mins
)
puts "Started execution #{task_list}: #{r.inspect}"

puts "Starting poll for #{task_list}"
decision_task = swf.poll_for_decision_task(
  :domain => domain.name,
  :task_list => { :name => task_list },
  :identity => DECIDER_IDENTITY
)
decision_task.events.each do |e|
  puts "Event #{e.event_type} id=#{e.event_id} @#{e.event_timestamp}"
end
