#!/usr/bin/env ruby
require 'swf_client'
require 'securerandom'
require 'json'

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
  :task_start_to_close_timeout => '120'
)
puts "Started execution #{task_list[:name]}: #{r.inspect}"
run_id = r[:run_id]

def dump_decision_task_event(e)
  puts "Event #{e.event_type} id=#{e.event_id} @#{e.event_timestamp}"
  case e.event_type
  when 'WorkflowExecutionStarted'
    puts "workflow_execution_started_event_attributes=#{e.workflow_execution_started_event_attributes.inspect}"
  when 'WorkflowExecutionCompleted'
    puts "workflow_execuution_completed_event_attributes=#{e.workflow_execution_completed_event_attributes.inspect}"
  when 'WorkflowExecutionFailed'
    puts "workflow_execution_failed_event_attributes=#{e.workflow_execution_failed_event_attributes.inspect}"
  when 'WorkflowExecutionTerminated'
    puts "workflow_execution_terminated_event_attributes=#{e.workflow_execution_terminated_event_attributes.inspect}"
  when 'WorkflowExecutionTimedOutEventAttributes'
    puts "workflow_execution_timed_out_event_attributes=#{e.workflow_execution_timed_out_event_attributes.inspect}"
  when 'DecisionTaskScheduled'
    puts "decision_task_scheduled_event_attributes=#{e.decision_task_scheduled_event_attributes.inspect}"
  when 'DecisionTaskStarted'
    puts "decision_task_started_event_attributes=#{e.decision_task_started_event_attributes.inspect}"
  when 'ActivityTaskScheduled'
    puts "activity_task_scheduled_event_attributes=#{e.activity_task_scheduled_event_attributes}"
  when 'ActivityTaskStarted'
    puts "activity_task_started_event_attributes=#{e.activity_task_started_event_attributes}"
  when 'ActivityTaskCompleted'
    puts "activity_task_completed_event_attributes=#{e.activity_task_completed_event_attributes}"
  when 'ActivityTaskTimedOut'
    puts "activity_task_timed_out_event_attributes=#{e.activity_task_timed_out_event_attributes}"
  when 'ScheduleActivityTaskFailed'
    puts "schedule_activity_task_failed_event_attributes=#{e.schedule_activity_task_failed_event_attributes.inspect}"
  end
end

def update_context(execution, last_activity_type, last_activity_result)
  swf = SwfClient.instance.client
  execution_detail = swf.describe_workflow_execution(
    :domain => SwfClient.instance.domain.name,
    :execution => execution
  )
  current_context = execution_detail.latest_execution_context
  puts "Updating context (#{current_context}) with activity=#{last_activity_type}, result=#{last_activity_result}"
  
  state = {}
  current_context and state = JSON.load(current_context)
  
  case last_activity_type
  when 'PopulateCandidates'
    state['candidates'] = last_activity_result
  end
  
  state
end

def make_decision(decision_task, task_list, last_activity_type, last_activity_result)
  new_context = update_context decision_task.workflow_execution, last_activity_type, last_activity_result
  puts "Making decision based on \'#{new_context.inspect}\'"
  
  if new_context.has_key?('candidates')
    puts 'Done; completing workflow'
    decision = {
      :decision_type => 'CompleteWorkflowExecution',
      :complete_workflow_execution_decision_attributes => {
        :result => "DONE: #{new_context['candidates']}"
      }
    }
  else
    puts 'Scheduling PopulateCandidates'
    decision = {
      :decision_type => 'ScheduleActivityTask',
      :schedule_activity_task_decision_attributes => {
        :activity_type => SwfClient.instance.activity_type('PopulateCandidates'),
        :activity_id => SecureRandom.uuid,
        :task_list => task_list
      }
    }
  end
  SwfClient.instance.client.respond_decision_task_completed(
    :task_token => decision_task.task_token,
    :decisions => [ decision ],
    :execution_context => new_context.to_json
  )
end

next_page_token = nil
next_execution_context = nil
while SwfClient.instance.current_workflow_execution
  puts "Starting poll for #{task_list[:name]}"
  decision_task = swf.poll_for_decision_task(
    :domain => domain.name,
    :task_list => task_list,
    :identity => DECIDER_IDENTITY,
    :next_page_token => next_page_token
  )
  next_page_token = decision_task.next_page_token
  puts "Decision task, previous_started_event_id=#{decision_task.previous_started_event_id}: #{decision_task.events.count} events"
  puts "Next page token #{next_page_token}"
  puts "Decision task token: #{decision_task.task_token}"
  
  decision_task.events or next

  events_since_last_decision = decision_task.events.select {|e| e.event_id > decision_task.previous_started_event_id } 
  activity_type = nil
  activity_result = nil
  events_since_last_decision.each do |e|
    dump_decision_task_event e
    case e.event_type
    when 'ActivityTaskScheduled'
      activity_type = e.activity_task_scheduled_event_attributes.activity_type.name
    when 'ActivityTaskCompleted'
      activity_result = e.activity_task_completed_event_attributes.result
    when 'DecisionTaskStarted'
      make_decision decision_task, task_list, activity_type, activity_result
    end
  end
end

execution_detail = swf.describe_workflow_execution(
  :domain => domain.name,
  :execution => {
    :workflow_id => WORKFLOW_ID,
    :run_id => run_id
  }
)
puts "Done.  Execution detail: #{execution_detail.inspect}"