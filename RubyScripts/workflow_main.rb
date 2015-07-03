#!/usr/bin/env ruby
require 'swf_client'
require 'securerandom'

WORKFLOW_ID = 'TestWorkflowId'
DECIDER_IDENTITY = 'TestDecider'

swf = SwfClient.instance.client

domain = SwfClient.instance.domain
puts domain.inspect

SwfClient.instance.ensure_activity_type_registered 'PopulateCandidates', 'Populate the set of candidates for the vote'

workflow_type = SwfClient.instance.workflow_type
puts workflow_type.inspect

task_list = { :name => SecureRandom.uuid }

r = swf.start_workflow_execution(
  :domain => domain.name,
  :workflow_id => WORKFLOW_ID,
  :workflow_type => { :name => workflow_type.name, :version => '0.1' },
  :task_list => task_list,
  :input => 'Some input string',
  :execution_start_to_close_timeout => '120', # Time me out in 2mins
)
puts "Started execution #{task_list[:name]}: #{r.inspect}"

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

puts "Starting poll for #{task_list[:name]}"
decision_task = swf.poll_for_decision_task(
  :domain => domain.name,
  :task_list => task_list,
  :identity => DECIDER_IDENTITY
)
decision_task.events.each do |e|
  dump_decision_task_event e
  if e.event_type == 'DecisionTaskStarted'
    puts 'Scheduling PopulateCandidates'
    swf.respond_decision_task_completed(
      :task_token => decision_task.task_token,
      :decisions => [
        {
          :decision_type => 'ScheduleActivityTask',
          :schedule_activity_task_decision_attributes => {
            :activity_type => {
              :name => 'PopulateCandidates',
              :version => '0.1'
            },
            :activity_id => SecureRandom.uuid,
            :task_list => task_list
          }
        }
      ]
    )
  end
end
