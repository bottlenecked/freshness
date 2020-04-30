# Changelog

## v0.2.5
- add debug usage docs
- bug: count pending connections among all open

## v0.2.4
- add Debug module
- make sure connection is open before returning

## v0.2.3
- bug: update pool on request error

## v0.2.2
- mapped mint request error 3-element tuple to 2-element error tuple

## v0.2.0
- fixed bug where only last batch of data was returned
- grouped responses into a Response struct

## v0.1.0
- initial pooling support
- support for simple requests (tested for HTTP1 only)