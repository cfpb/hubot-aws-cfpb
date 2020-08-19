# Description:
#   Provides conveniences around certain tags we want to manage
#
# Commands:
#   hubot ec2 schedule <instance_id> [<instance_id> ...] --start=start_hour --stop=stop_hour Adds an appropriate Schedule tag to the Instance(s). Start and stop default to 8 AM to 6 PM
#   hubot ec2 unschedule <instance_id> [<instance_id> ...] Removes the Schedule tag from the Instance(s)
#
# Notes:
#   instance_id : [required] The ID of one or more instances to modify tags. For example, i-0acec691.
#   --start : On a 24 hour clock, what hour of the day to tag the instance to be started.
#   --stop : On a 24 hour clock, what hour of the day to tag the instance to be stopped.
#   --start and --stop **only results in a tag being added to the instance**. Other automations are responsible for implementing stop and start

cson = require 'cson'
restrictor = require './restrictor'
tags = require './tags'
util = require 'util'
ec2 = require('../../ec2.coffee')

# 8 am to 6 pm
DEFAULT_SCHEDULE_START = 8
DEFAULT_SCHEDULE_STOP = 18

createInstancesArray = (instance_ids) ->
  instances = []
  instance_ids = instance_ids.replace /^\s+|\s+$/g, ""
  for i in instance_ids.split /\s+/
    if i and i.match(/^i-/)
      instances.push(i)

  return instances

scheduleIfAuthorized = (msg, instances, schedule, err) ->
  return (err) ->
    return msg.send "Error! #{err}" if err
    tags.addSchedule(msg, instances, schedule)
    msg.send "Schedule added to #{instances}. Those instances will now start and stop on a schedule of #{schedule}"


unscheduleIfAuthorized = (msg, instances, err) ->
  return (err) ->
    return msg.send "Error! #{err}" if err
    tags.removeSchedule(msg, instances)
    msg.send "Schedule removed from #{instances}"

#credit: https://github.com/yoheimuta/hubot-aws/blob/master/scripts/ec2/create_tags.coffee
getScheduleOptions = (args) ->

  start_capture = /--start=(\d*?)( |$)/.exec(args)
  start = if start_capture && (start_capture[1] >= 0 && start_capture[1] <= 24) then start_capture[1] else DEFAULT_SCHEDULE_START
  stop_capture = /--stop=(\d*?)( |$)/.exec(args)
  stop = if stop_capture && (stop_capture[1] >= 0 && stop_capture[1] <= 24) then stop_capture[1] else DEFAULT_SCHEDULE_STOP

  return {start: start, stop: stop}

module.exports = (robot) ->
  robot.respond /ec2 schedule(.*)$/i, (msg) ->

    instances = createInstancesArray(msg.match[1])
    return msg.send "One or more instance_ids are required" if instances.length < 1

    options = getScheduleOptions(msg.match[1])
    schedule = "#{options.start}:#{options.stop}"

    arg_params = restrictor.addUserCreatedFilter(msg, {})
    restrictor.authorizeOperation(msg, arg_params, instances, scheduleIfAuthorized(msg, instances, schedule))

  robot.respond /ec2 unschedule(.*)$/i, (msg) ->
    instances = createInstancesArray(msg.match[1])
    return msg.send "One or more instance_ids are required" if instances.length < 1

    arg_params = restrictor.addUserCreatedFilter(msg, {})
    restrictor.authorizeOperation(msg, arg_params, instances, unscheduleIfAuthorized(msg, instances))
