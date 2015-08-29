# Condorcet

## RubyScripts
This is where the SWF decider logic lives, as well as some test helpers for moving the SWF decider along.

## CondorcetWeb
This is a NodeJS web app that makes input pages available according to the tasks issued it by the SWF decider.

Useful environment variables:
* $env:FAKE = "test" -- Rather than waiting for an SWF task to tell it where to put up the UI, put it up at /test immediately.  Useful for working on the UI.
* $env:DEBUG = "CondorcetWeb:*" -- Turn on npm logging.  Try a value of "*" to see all the debug messages.

To run it from Windows:
 cd CondorcetWeb
 npm start
 