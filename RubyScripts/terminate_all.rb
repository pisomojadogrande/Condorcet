#!/usr/bin/env ruby

require 'swf_client'

swf = SwfClient.instance.client

ex = SwfClient.instance.current_workflow_execution

if ex
  puts "Terminating #{ex.inspect}"
  swf.terminate_workflow_execution(
    :domain => SwfClient.instance.domain.name,
    :workflow_id => ex[:workflow_id],
    :reason => "Terminated by #{$0}"
  )
else
  puts "Nothing running"
end
