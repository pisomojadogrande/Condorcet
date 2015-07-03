#!/usr/bin/env ruby
require 'swf_client'
require 'json'

swf = SwfClient.instance.client
domain = SwfClient.instance.domain
execution = SwfClient.instance.current_workflow_execution

execution_details = swf.describe_workflow_execution(
  :domain => domain.name,
  :execution => execution
)
task_list = execution_details.execution_configuration.task_list
puts task_list.inspect

while true
  r = swf.poll_for_activity_task(
    :domain => domain.name,
    :task_list => task_list,
    :identity => 'PopulateCandidatesActor'
  )
  case r.activity_type.name
  when 'PopulateCandidates'
    result = [ 'foo', 'bar', 'baz', 'quux' ]
    swf.respond_activity_task_completed(
      :task_token => r.task_token,
      :result => result.to_json
    )
  when 'RegisterVoters'
    puts "Register some voters:"
    while true
      line = STDIN.readline.chomp
      puts "Voter: #{line}"
      break if line.empty?
      swf.signal_workflow_execution(
        :domain => domain.name,
        :workflow_id => execution.workflow_id,
        :run_id => execution.run_id,
        :signal_name => 'NewVoter',
        :input => line
      )
    end
    swf.respond_activity_task_completed(
      :task_token => r.task_token
    )
    exit 0
  else
    puts r.inspect
  end
end
