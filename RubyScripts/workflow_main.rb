#!/usr/bin/env ruby
require 'securerandom'
require 'swf_client'
require 'decision_logic'

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
execution = {
  :workflow_id => WORKFLOW_ID,
  :run_id => r.run_id
}

decision_logic = DecisionLogic.new task_list
next_page_token = nil
while SwfClient.instance.is_open? execution
  puts "Starting poll for #{task_list[:name]}"
  decision_task = swf.poll_for_decision_task(
    :domain => domain.name,
    :task_list => task_list,
    :identity => DECIDER_IDENTITY,
    :next_page_token => next_page_token
  )
  next_page_token = decision_task.next_page_token
  #puts "Decision task, previous_started_event_id=#{decision_task.previous_started_event_id}: #{decision_task.events.count} events"
  puts "Next page token #{next_page_token}"
  puts "Decision task token: #{decision_task.task_token}"
  
  decision_task.events or next
  decision_task.events.each do |e|
    decision_logic.add_event e
  end
  
  decisions = decision_logic.pop_decisions
  swf.respond_decision_task_completed(
    :task_token => decision_task.task_token,
    :decisions => decisions
  )
end

execution_detail = swf.describe_workflow_execution(
  :domain => domain.name,
  :execution => execution
)
puts "Done.  Execution detail: #{execution_detail.inspect}"

terminal_event = SwfClient.instance.terminal_event execution
SwfClient.dump_decision_task_event terminal_event
