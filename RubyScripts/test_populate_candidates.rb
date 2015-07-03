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
  if r[:activity_type][:name] == 'PopulateCandidates'
    result = [ 'foo', 'bar', 'baz', 'quux' ]
    swf.respond_activity_task_completed(
      :task_token => r[:task_token],
      :result => result.to_json
    )
    exit 0  
  else
    puts r.inspect
  end
end
