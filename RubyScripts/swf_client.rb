require 'singleton'
require 'aws-sdk' # gem install aws-sdk

class SwfClient
  include Singleton
  
  attr_reader :client

  DOMAIN_NAME = 'CondorcetVote'
  WORKFLOW_TYPE_NAME = 'TestWorkflowType'
  
  def initialize
    access_key_id = ENV['AWS_ACCESS_KEY']
    secret_key = ENV['AWS_SECRET_KEY']

    Aws.config[:region] = 'us-east-1'

    @client = Aws::SWF::Client.new :access_key_id => access_key_id, :secret_access_key => secret_key
  end
  
  def domain
    unless @domain
      @domain = @client.list_domains(:registration_status => 'REGISTERED').domain_infos.find { |d| d.name == DOMAIN_NAME }
    end
    @domain
  end
  
  def workflow_type
    unless @workflow_type
      @workflow_type = @client.list_workflow_types(
        :domain => @domain.name,
        :name => WORKFLOW_TYPE_NAME,
        :registration_status => 'REGISTERED'
      ).type_infos.first.workflow_type
    end
    @workflow_type
  end
  
  def ensure_activity_type_registered(name, description)
    begin
      @client.register_activity_type(
        :domain => domain.name,
        :name => name,
        :version => '0.1',
        :description => description
      )
    rescue Aws::SWF::Errors::TypeAlreadyExistsFault => e
      # okay
    end
  end
  
  def current_workflow_execution(seconds_ago = 3600)
    r = @client.list_open_workflow_executions(
      :domain => domain.name,
      :start_time_filter => { :oldest_date => Time.now - seconds_ago },
      :type_filter => { :name => SwfClient.instance.workflow_type.name }
    )
    if r[:execution_infos].empty?
      nil
    else
      r[:execution_infos].first.execution # has [:workflow_id], [:run_id]
    end
  end
  
  def current_workflow_task_list(seconds_ago = 3600)
    execution = current_workflow_execution seconds_ago
    execution or raise "No open workflows for #{domain.name}"
    workflow_execution_description = @client.describe_workflow_execution(
      :domain => domain.name,
      :execution => execution
    )
    #puts workflow_execution_description.inspect
    workflow_execution_description.execution_configuration.task_list
  end
end
