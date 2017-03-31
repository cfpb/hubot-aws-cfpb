# Description:
#   Sets the ExpireDate tag to 2 weeks from now for the specified Amazon EC2 resource
#
# Commands:
#   hubot ec2 extend <instance_id> [<instance_id> ...]
#
# Notes:
#   instance_id : [required] The ID of one or more instances to tag. For example, i-0acec691.
#   --do-not-start: [optional] Overrides the default action of starting instances after updating the ExpireDate
#   --dry-run  : [optional] Checks whether the api request is right. Recommend to set before applying to real asset.

ec2 = require('../../ec2.coffee')
restrictor = require './restrictor'
tags = require './tags'
util = require 'util'

getArgParams = (arg) ->
  dry_run = if arg.match(/--dry-run/) then true else false
  start_instances = if arg.match(/--do-not-start/) then false else true

  return {dry_run: dry_run, start_instances: start_instances}

extendInstances = (msg, params, instances, err) ->
  return (err) ->
    return msg.send "Error! #{err}" if err

    dry_run = params.dry_run
    start_instances = params.start_instances

    msg.send "Extending ExpireDate for instances=[#{instances}] dry-run=#{dry_run}..."

    expireDate = new Date
    expireDate.setDate(expireDate.getDate() + 14)
    expdd = expireDate.getDate()
    expmm = expireDate.getMonth() + 1
    expyyyy = expireDate.getFullYear()
    if expdd < 10
      expdd = '0' + expdd
    if expmm < 10
      expmm = '0' + expmm
    expireDatePretty = "#{expyyyy}-#{expmm}-#{expdd}"

    params =
      DryRun: dry_run
      Resources: instances
      Tags: [
        { Key: 'ExpireDate', Value: expireDatePretty }
      ]

    if dry_run
      msg.send util.inspect(params, false, null)

    ec2.createTags params, (err, res) ->
      return msg.send "Error! #{err}" if err

      tags.addSchedule(msg, instances)

      msg.send "Successfully extended the expiration date to #{expireDatePretty}"
      msg.send "\nThis instance defaults to running between 8 AM and 6 PM. You can change that schedule with the `ec2 schedule` command. See `bot help ec2 schedule` for details\n"

      # TODO break start_instances out into a decoupled function
      # Start instances after extending the expiration date
      if start_instances
        start_params =
          InstanceIds: instances

        msg.send "Ensuring the following instances are running: [#{instances}]"
        ec2.startInstances start_params, (err, res) ->
          return msg.send "Error! #{err}" if err
          msg.send util.inspect(res, false, null)


module.exports = (robot) ->
  robot.respond /ec2 extend(.*)$/i, (msg) ->
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
    restrictor.authorizeOperation(msg, arg_params, instances, extendInstances(msg, arg_params, instances))
