AWS = require('aws-sdk');
debug = require('debug')('CondorcetWeb:swf');
error = require('debug')('CondorcetWeb:error');

AWS.config.region = 'us-east-1';
if (process.env.AWS_ACCESS_KEY && process.env.AWS_SECRET_KEY) {
    debug("Using AWS creds from environment");
    var creds = new AWS.Credentials(process.env.AWS_ACCESS_KEY, process.env.AWS_SECRET_KEY);
    AWS.config.credentials = creds;
} else {
    debug("No AWS creds in environment; we assume this is an EC2 instance with an appropriate IAM role");
}

var swf = new AWS.SWF();
swf.listDomains({registrationStatus: 'REGISTERED'}, function(err, data) {
    if (err) {
        debug('ERROR %s', err);
    } else {
        debug("%d domains", data.domainInfos.length);
        for (var i = 0; i < data.domainInfos.length; i++) {
            debug("Domain %d: Name %s", i, data.domainInfos[i].name);
        }
    }
});

function getMostRecentWorkflowExecution(callback) {
    var oneHourAgo = new Date;
    oneHourAgo.setTime(oneHourAgo.getTime() - 3600*1000);
    swf.listOpenWorkflowExecutions(
        {
            domain: 'CondorcetVote',
            startTimeFilter: {
                oldestDate: oneHourAgo
            }
        },
        function(err, data) {
            var execution = null;
            if (data) {
                debug("%d executions started in the last hour", data.executionInfos.length);
                debug("Found execution %s started at %s", data.executionInfos[0].execution.workflowId, data.executionInfos[0].startTimestamp);
                execution = data.executionInfos[0].execution;
            }
            callback(err, execution);
        }
    );
}

function pollForWorkflowExecution(callback) {
    var intervalId = setInterval(function() {
        getMostRecentWorkflowExecution(function(err, execution) {
            if (err) {
                error("Error listing workflow executions " + err);
            } else if (execution) {
                clearInterval(intervalId);
                callback(null, execution);
            } else {
                debug("No workflow running");
            }
        })
    }, 5000);
}

module.exports = {
    pollForActivity: function(err, onActivityReady) {
        pollForWorkflowExecution(function(err, execution) {
            if (execution) {
                debug("done polling")
                // TODO: Start polling for an activity
            }
        })
    }
};