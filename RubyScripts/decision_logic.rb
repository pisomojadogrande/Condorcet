require 'securerandom'
require 'json'
require 'swf_client'

class DecisionLogic
  attr_reader :execution_context
  attr_reader :decisions
  
  def initialize(task_list)
    @task_list = task_list
    @execution_context = ''
    @decisions = []
    @activity_tasks = []
    @highest_event_id = 0
  end
  
  def add_event(e)
    e.event_id <= @highest_event_id and return
    @highest_event_id = e.event_id
    
    SwfClient.dump_decision_task_event e
    
    case e.event_type
    when 'WorkflowExecutionStarted'
      start_workflow_execution
    when 'WorkflowExecutionSignaled'
      attrs = e.workflow_execution_signaled_event_attributes
      signal(attrs.signal_name, attrs.input)
    when 'ActivityTaskScheduled'
      activity_task = {
        :activity_type => e.activity_task_scheduled_event_attributes.activity_type.name,
        :scheduled_event_id => e.event_id
      }
      @activity_tasks.push activity_task
    when 'ActivityTaskCompleted'
      scheduled_event_id = e.activity_task_completed_event_attributes.scheduled_event_id
      activity_task = @activity_tasks.find {|a| a[:scheduled_event_id] == scheduled_event_id}
      activity_task[:completed_event_id] = e.event_id
      activity_task[:result] = e.activity_task_completed_event_attributes.result
      complete_activity activity_task
    end
  end
  
  def pop_decisions
    decisions = @decisions
    @decisions = []
    decisions
  end
  
  private
  
  def schedule_task_decision(activity_type)
    {
      :decision_type => 'ScheduleActivityTask',
      :schedule_activity_task_decision_attributes => {
        :activity_type => SwfClient.instance.activity_type(activity_type),
        :activity_id => SecureRandom.uuid,
        :task_list => @task_list
      }
    }
  end
  
  def start_workflow_execution
    @decisions.push schedule_task_decision('PopulateCandidates')
  end
  
  def signal(signal_name, input)
    case signal_name
    when 'NewVoter'
      @voters = @voters || []
      @voters.push input
    end
  end
  
  def complete_activity(activity_task)
    case activity_task[:activity_type]
    when 'PopulateCandidates'
      @candidates = JSON.load activity_task[:result]
      @decisions.push schedule_task_decision('RegisterVoters')
    when 'RegisterVoters'
      decision = {
        :decision_type => 'CompleteWorkflowExecution',
        :complete_workflow_execution_decision_attributes => {
          :result => "DONE: Candidates=#{@candidates.inspect}; voters=#{@voters.inspect}"
        }
      }
      @decisions.push decision
    end
  end
  
end
