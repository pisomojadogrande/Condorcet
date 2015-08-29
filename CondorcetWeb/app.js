var express = require('express');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');
var debug = require('debug')('CondorcetWeb:app');
var error = require('debug')('CondorcetWeb:error');

var swf = require('./swf_client');
var routes = require('./routes/index');
var users = require('./routes/users');

var app = express();

// Comes from process.env.NODE_ENV
debug('env=%s', app.get('env'));

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

// uncomment after placing your favicon in /public
//app.use(favicon(__dirname + '/public/favicon.ico'));
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));


function setupRoutes(uri) {

  debug("Routes at " + uri);
  app.use(uri, routes);
  //app.use('/users', users);

  // catch 404 and forward to error handler
  app.use(function(req, res, next) {
    error('404 ' + req.query);
    var err = new Error('Not Found');
    err.status = 404;
    next(err);
  });
  
  // error handlers
  
  // development error handler
  // will print stacktrace
  if (app.get('env') === 'development') {
    app.use(function(err, req, res, next) {
      res.status(err.status || 500);
      res.render('error', {
        message: err.message,
        error: err
      });
    });
  }
  
  // production error handler
  // no stacktraces leaked to user
  app.use(function(err, req, res, next) {
    res.status(err.status || 500);
    res.render('error', {
      message: err.message,
      error: {}
    });
  });  
}

if (process.env.FAKE) {
  debug("FAKE set to " + process.env.FAKE);
  setupRoutes("/" + process.env.FAKE);
} else {
  swf.pollForActivity().then(function(activity) {
    debug("activity: " + JSON.stringify(activity));
    var uri = "/" + activity.input;
    setupRoutes(uri);
    
    var metadataService = new AWS.MetadataService();
    metadataService.request('/latest/meta-data/public-hostname', function(err, data) {
      if (err && err.code == "ENETUNREACH") {
        debug("ENETUNREACH from metadata service. Probably running on localhost");
        err = null;
        data = 'localhost';
      }
      if (err) error("Metadata service: " + JSON.stringify(err));
      if (data) {
        debug("public-hostname " + JSON.stringify(data));
        var url = "http://" + data + ":" + app.get('port') + uri;
        debug("url: " + url);
        swf.sendSignal("adminUrl", url);
      }
    });
  }).catch(function(err) {
    debug("pollForActivity error" + err);
  });  
}





module.exports = app;
