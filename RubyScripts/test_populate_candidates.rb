#!/usr/bin/env ruby
require 'swf_client'

swf = SwfClient.instance.client
domain = SwfClient.instance.domain

r = swf.list_open_workflow_executions(
  :domain => domain.name,
  :start_time_filter => { :oldest_date => Time.now - 3600 },
  :type_filter => { :name => SwfClient.instance.workflow_type.name }
)
execution = r[:execution_infos].first.execution
puts execution.inspect # has [:workflow_id], [:run_id]