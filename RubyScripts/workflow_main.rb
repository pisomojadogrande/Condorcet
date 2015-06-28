#!/usr/bin/env ruby
require 'aws-sdk' # gem install aws-sdk

access_key_id = ENV['AWS_ACCESS_KEY']
secret_key = ENV['AWS_SECRET_KEY']

Aws.config[:region] = 'us-east-1'

swf = Aws::SWF::Client.new :access_key_id => access_key_id, :secret_access_key => secret_key

domain = swf.list_domains(:registration_status => 'REGISTERED').domain_infos.find { |d| d.name == 'CondorcetVote' }
puts domain.inspect
