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
end
