# Description:
#   Ensures the provided instances are started
#
# Commands:
#   hubot ec2 start <instance_id> [<instance_id> ...]
#
# Notes:
#   instance_id : [required] The ID of one or more instances to tag. For example, i-0acec691.
#   --dry-run  : [optional] Checks whether the api request is right. Recommend to set before applying to real asset.

ec2 = require('../../ec2.coffee')
restrictor = require './restrictor'
tags = require './tags'
util = require 'util'

getArgParams = (arg) ->
  dry_run = if arg.match(/--dry-run/) then true else false
  return {dry_run: dry_run}


startInstances = (msg, params, instances, err) ->
  return (err) ->
    return msg.send "Error! #{err}" if err

    dry_run = params.dry_run
    msg.send "Starting instances=[#{instances}] dry-run=#{dry_run}..."

    params = {InstanceIds: instances, DryRun: dry_run}

    if dry_run
      msg.send util.inspect(params, false, null)

    ec2.startInstances params, (err, res) ->
      return msg.send "Error! #{err}" if err

      msg.send "Success! The instances are starting"
      tags.addSchedule(msg, instances)
      msg.send util.inspect(res, false, null)



module.exports = (robot) ->
  robot.respond /ec2 start(.*)$/i, (msg) ->
    unless require('../../auth.coffee').canAccess(robot, msg.envelope.user)
      msg.send "You cannot access this feature. Please contact with admin"
      return

    arg_value = msg.match[1]
    arg_params = getArgParams(arg_value)

    instances = []
    for av in arg_value.split /\s+/
      if av and not av.match(/^--/)
        instances.push(av)

    if instances.length < 1
      msg.send "One or more instance_ids are required"
      return

    arg_params = restrictor.addUserCreatedFilter(msg, arg_params)
    restrictor.authorizeOperation(msg, arg_params, instances, startInstances(msg, arg_params, instances))
