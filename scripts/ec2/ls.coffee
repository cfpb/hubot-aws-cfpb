# Description:
#   List ec2 instances info
#   Show detail about an instance if specified an instance id
#   Filter ec2 instances info if specified an instance name
# Configurations:
#   HUBOT_AWS_DEFAULT_CREATOR_EMAIL: [required] An email address to be used for tagging the new instance
#
# Commands:
#   hubot ec2 ls - Displays Instances
#   hubot ec2 mine - Displays Instances I've created, based on user email
#   hubot ec2 chat - Displays Instances created via chat

# Notes:
#   --instance_id=***     : [optional] The id of an instance. If omit it, returns info about all instances.
#   --instance_filter=*** : [optional] The name to be used for filtering return values by an instance name.

moment = require 'moment'
util   = require 'util'
tsv    = require 'tsv'

getArgParams = (arg) ->
  ins_id_capture = /--instance_id=(.*?)( |$)/.exec(arg)
  ins_id = if ins_id_capture then ins_id_capture[1] else ''

  # filter by instance name
  ins_filter_capture = /--instance_filter=(.*?)( |$)/.exec(arg)
  ins_filter = if ins_filter_capture then ins_filter_capture[1] else ''

  return {
    ins_id: ins_id,
    ins_filter: ins_filter
  }

listEC2Instances = (ec2, msg, filter = "all", opt_arg = "") ->
  arg_params = getArgParams(msg.match[1])
  ins_id  = arg_params.ins_id
  ins_filter = arg_params.ins_filter

  params = {}

  if ins_id
    params['InstanceIds'] = [ins_id]

  if filter == "mine"
    params['Filters'] = [{ Name: 'tag:Creator', Values: [opt_arg] }]
  else if filter == "chat"
    params['Filters'] = [{ Name: 'tag:CreatedByApplication', Values: [filter] }]

  ec2.describeInstances (params), (err, res) ->
    if err
      msg.send "DescribeInstancesError: #{err}"
    else
      if ins_id
        msg.send util.inspect(res, false, null)

        ec2.describeInstanceAttribute { InstanceId: ins_id, Attribute: 'userData' }, (err, res) ->
          if err
            msg.send "DescribeInstanceAttributeError: #{err}"
          else if res.UserData.Value
            msg.send new Buffer(res.UserData.Value, 'base64').toString('ascii')
      else
        messages = []
        for data in res.Reservations
          ins = data.Instances[0]

          name = '[NoName]'
          for tag in ins.Tags when tag.Key is 'Name'
            name = tag.Value

          messages.push({
            time   : moment(ins.LaunchTime).format('YYYY-MM-DD HH:mm:ssZ')
            state  : ins.State.Name
            id     : ins.InstanceId
            image  : ins.ImageId
            az     : ins.Placement.AvailabilityZone
            subnet : ins.SubnetId
            type   : ins.InstanceType
            ip     : ins.PrivateIpAddress
            name   : name || '[NoName]'
          })

        messages.sort (a, b) ->
          moment(a.time) - moment(b.time)
        message = tsv.stringify(messages) || '[None]'
        msg.send message


module.exports = (robot) ->

  robot.respond /ec2 ls(.*)$/i, (msg) ->
    arg_params = getArgParams(msg.match[1])
    ins_id  = arg_params.ins_id
    ins_filter = arg_params.ins_filter
    msg_txt = "Fetching #{ins_id || 'all (instance_id is not provided)'}"
    msg_txt += " containing '#{ins_filter}' in name" if ins_filter 
    msg_txt += "..."
    msg.send msg_txt

    aws = require('../../aws.coffee').aws()
    ec2 = new aws.EC2({apiVersion: '2014-10-01'})
    listEC2Instances(ec2, msg)


  robot.respond /ec2 mine$/i, (msg) ->

    creator_email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL

    msg_txt = "Fetching instances created by #{creator_email} ..."
    msg.send msg_txt

    aws = require('../../aws.coffee').aws()
    ec2 = new aws.EC2({apiVersion: '2014-10-01'})
    listEC2Instances(ec2, msg, "mine", creator_email)

    
  # TODO: I'm not a fan of this listener... what would be more intuitive? ec2 ls chat? maybe make all of these forms of 'ec2 ls... ? '
  robot.respond /ec2 chat$/i, (msg) ->

    msg_txt = "Fetching instances created via chat ..."
    msg.send msg_txt

    aws = require('../../aws.coffee').aws()
    ec2 = new aws.EC2({apiVersion: '2014-10-01'})
    listEC2Instances(ec2, msg, "chat")


handle_ec2_instance = (robot) ->
  robot.messageRoom process.env.EC2_ROOM, "Test message"

ec2_setup_polling = (robot) ->
  setInterval ->
    handle_ec2_instance(robot)?
  , 1000 * 60 * 1

  if twitter_query(robot)?
    twitter_search(robot)
