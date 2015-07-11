AWS = require('aws-sdk');
debug = require('debug')('CondorcetWeb:swf')

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

module.exports = swf;