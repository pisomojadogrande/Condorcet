#!/usr/bin/env ruby
require 'swf_client'
require 'json'

swf = SwfClient.instance.client
domain = SwfClient.instance.domain
task_list = SwfClient.instance.current_workflow_task_list

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
      swf.record_activity_task_heartbeat(
        :task_token => r.task_token,
        :details => line.chomp
      )
    end
    swf.respond_activity_task_completed(
      :task_token => r.task_token
    )
  else
    puts r.inspect
  end
end
