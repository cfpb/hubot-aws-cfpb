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

util = require 'util'

getArgParams = (arg) ->
  dry_run = if arg.match(/--dry-run/) then true else false
  start_instances = if arg.match(/--do-not-start/) then false else true

  return {dry_run: dry_run, start_instances: start_instances}

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

    dry_run = arg_params.dry_run
    start_instances = arg_params.start_instances

    if instances.length < 1
      msg.send "One or more instance_ids are required"
      return

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
      Resources: instances
      Tags: [
        { Key: 'ExpireDate', Value: expireDatePretty }
      ]

    if dry_run
      msg.send util.inspect(params, false, null)
      return

    aws = require('../../aws.coffee').aws()
    ec2 = new aws.EC2({apiVersion: '2014-10-01'})

    ec2.createTags params, (err, res) ->
      if err
        msg.send "Error: #{err}"
      else
        msg.send "Successfully extended the expiration date to #{expireDatePretty}"
        msg.send util.inspect(res, false, null)

        # TODO break start_instances out into a decoupled function
        # Start instances after extending the expiration date
        if start_instances
          start_params =
            InstanceIds: instances

          msg.send "Ensuring the following instances are running: [#{instances}]"
          ec2.startInstances start_params, (err, res) ->
            if err
              msg.send "Error: #{err}"
            else
              msg.send util.inspect(res, false, null)
