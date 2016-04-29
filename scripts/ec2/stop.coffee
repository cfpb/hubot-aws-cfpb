# Description:
#   Stop ec2 instance
#
# Commands:
#   hubot ec2 stop --instance_id=[instance_id] - Stop the Instance
#
# Notes:
#   --instance_id=***   : [required] One instance ID.
#   --dry-run           : [optional] Checks whether the api request is right. Recommend to set before applying to real asset.

getArgParams = (arg) ->
  dry_run = if arg.match(/--dry-run/) then true else false

  ins_id_capture = /--instance_id=(.*?)( |$)/.exec(arg)
  ins_id = if ins_id_capture then ins_id_capture[1] else null

  return {dry_run: dry_run, ins_id: ins_id}

module.exports = (robot) ->
  robot.respond /ec2 stop(.*)$/i, (msg) ->
    unless require('../../auth.coffee').canAccess(robot, msg.envelope.user)
      msg.send "You cannot access this feature. Please contact with admin"
      return

    arg_params = getArgParams(msg.match[1])
    ins_id  = arg_params.ins_id
    dry_run = arg_params.dry_run

    msg.send "Stopping instance_id=#{ins_id}, dry-run=#{dry_run}..."

    aws = require('../../aws.coffee').aws()
    ec2 = new aws.EC2({apiVersion: '2014-10-01'})

    creator_email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL || "unknown"

    params = {
      InstanceIds: [ins_id],
      Filters: [{ Name: 'tag:Creator', Values: [creator_email] }]
    }

    ec2.describeInstances (params), (err, res) ->
      
      unless res.Reservations.length
        msg.send "Permission denied to stop this instance. Only the creator can stop this instance. "
        return 

      ec2.stopInstances { DryRun: dry_run, InstanceIds: [ins_id] }, (err, res) ->
        if err
          msg.send "Error: #{err}"
        else
          messages = []
          for ins in res.StoppingInstances
            id     = ins.InstanceId
            state  = ins.CurrentState.Name

            messages.push("#{id}\t#{state}")

          messages.sort()
          message = messages.join "\n"
          msg.send message
