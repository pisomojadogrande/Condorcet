#!/usr/bin/env ruby
require 'swf_client'
require 'securerandom'

WORKFLOW_TYPE_NAME = 'TestWorkflowType'
WORKFLOW_ID = 'TestWorkflowId'
DECIDER_IDENTITY = 'TestDecider'

swf_helper = SwfClient.instance

swf = swf_helper.client

domain = swf_helper.domain
puts domain.inspect

workflow_type = swf.list_workflow_types(
  :domain => domain.name,
  :name => WORKFLOW_TYPE_NAME,
  :registration_status => 'REGISTERED'
)
puts workflow_type.inspect

task_list = SecureRandom.uuid

r = swf.start_workflow_execution(
  :domain => domain.name,
  :workflow_id => WORKFLOW_ID,
  :workflow_type => { :name => WORKFLOW_TYPE_NAME, :version => '0.1' },
  :task_list => { :name => task_list },
  :input => 'Some input string',
  :execution_start_to_close_timeout => '120', # Time me out in 2mins
)
puts "Started execution #{task_list}: #{r.inspect}"

def dump_decision_task_event(e)
  puts "Event #{e.event_type} id=#{e.event_id} @#{e.event_timestamp}"
  case e.event_type
  when 'WorkflowExecutionStarted'
    puts "\tworkflow_execution_started_event_attributes=#{e.workflow_execution_started_event_attributes.inspect}"
  when 'DecisionTaskScheduled'
    puts "\tdecision_task_scheduled_event_attributes=#{e.decision_task_scheduled_event_attributes.inspect}"
  when 'DecisionTaskStarted'
    puts "\tdecision_task_started_event_attribute=#{e.decision_task_started_event_attributes.inspect}"
  end
end

puts "Starting poll for #{task_list}"
decision_task = swf.poll_for_decision_task(
  :domain => domain.name,
  :task_list => { :name => task_list },
  :identity => DECIDER_IDENTITY
)
decision_task.events.each { |e| dump_decision_task_event e }
