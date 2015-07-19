AWS = require('aws-sdk');
Promise = require('promise');
debug = require('debug')('CondorcetWeb:swf');
error = require('debug')('CondorcetWeb:error');

var DOMAIN_NAME = 'CondorcetVote';
var RETRIES_MAX = 5;

AWS.config.region = 'us-east-1';
if (process.env.AWS_ACCESS_KEY && process.env.AWS_SECRET_KEY) {
    debug("Using AWS creds from environment");
    var creds = new AWS.Credentials(process.env.AWS_ACCESS_KEY, process.env.AWS_SECRET_KEY);
    AWS.config.credentials = creds;
} else {
    debug("No AWS creds in environment; we assume this is an EC2 instance with an appropriate IAM role");
}

var swf = new AWS.SWF();

function pollForWorkflowExecutionPromise() {
    return new Promise(function(resolve, reject) {
        var listOpenWorkflowExecutions = Promise.denodeify(swf.listOpenWorkflowExecutions.bind(swf));
        var oneHourAgo = new Date;
        oneHourAgo.setTime(oneHourAgo.getTime() - 3600*1000);
        var retries = 0;
        var intervalId = setInterval(function() {
            listOpenWorkflowExecutions({
                domain: DOMAIN_NAME,
                startTimeFilter: {
                    oldestDate: oneHourAgo
                }
            }).then(function(data) {
                debug("%d executions started in the last hour", data.executionInfos.length);
                retries = 0;
                if (data.executionInfos.length > 0) {
                    debug("Found execution %s started at %s", data.executionInfos[0].execution.workflowId, data.executionInfos[0].startTimestamp);
                    clearInterval(intervalId);
                    resolve(data.executionInfos[0].execution);
                } // else continue polling
            }).catch(function(err) {
                retries++;
                error("pollForWorkflowExecution " + err);
                if (retries > RETRIES_MAX) {
                    reject(err);
                }
            });
        }, 5000);
    });
}

function loopingPollForActivity(taskList, callback) {
    debug("Polling %s for activity", taskList);
    swf.pollForActivityTask({
        domain: DOMAIN_NAME,
        taskList: taskList,
        identity: 'CondorcetWeb'
    }, function(err, data) {
        if (err) error("pollForActivityTask " + err);
        if (data) {
            callback(data);
        } else {
            loopingPollForActivity(taskList, callback);
        }
    })
}

function loopingPollForActivityPromise(taskList) {
    return new Promise(function(resolve, reject) {
        loopingPollForActivity(taskList, function(data) {
            resolve(data);
        });
    });
}

module.exports = {
    
    activity: null,
    
    taskList: null,
    
    workflowId: null,
    
    pollForActivity: function() {
        return new Promise(function(resolve, reject) {
            pollForWorkflowExecutionPromise().then(function(execution) {
                var describeWorkflowExecution = Promise.denodeify(swf.describeWorkflowExecution.bind(swf));
                return describeWorkflowExecution({
                    domain: DOMAIN_NAME,
                    execution: execution
                });
            }).then(function(data) {
                debug("Execution " + JSON.stringify(data));
                taskList = data.executionConfiguration.taskList;
                workflowId = data.executionInfo.execution.workflowId;
                return taskList;
            }).then(function(taskList) {
                return loopingPollForActivityPromise(taskList)
            }).then(function(data) {
                debug("Activity " + JSON.stringify(data));
                activity = data;
                resolve(data);
            }).catch(function(err) {
                error("pollForActivity: " + JSON.stringify(err));
                reject(err);
            });
        });
    },
    
    sendSignal: function(signalName, signalValue) {
        swf.signalWorkflowExecution({
            domain: DOMAIN_NAME,
            signalName: signalName,
            workflowId: workflowId,
            input: signalValue
        }, function(err, data) {
           if (err) error("Error sending signal " + signalName); 
        });
    },

    heartbeatInterval: setInterval(function() {
        if (this.activity) {
            swf.recordActivityTaskHeartbeat({
                taskToken: this.activity.taskToken
            }, function(err) {
                if (err) error("Error sending heartbeat");
            });
        }
    }, 5000)
};