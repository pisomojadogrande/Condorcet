#!/usr/bin/env ruby
require 'swf_client'

swf = SwfClient.instance.client
domain = SwfClient.instance.domain
task_list = SwfClient.instance.current_workflow_task_list

puts task_list.inspect

r = swf.poll_for_activity_task(
  :domain => domain.name,
  :task_list => task_list,
  :identity => 'PopulateCandidates'
)
puts r.inspect