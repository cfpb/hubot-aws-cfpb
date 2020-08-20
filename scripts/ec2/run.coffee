# Description:
#   Run ec2 instance
#
# Configurations:
#   HUBOT_AWS_DEFAULT_CREATOR_EMAIL: [required] An email address to be used for tagging the new instance
#   HUBOT_AWS_EC2_RUN_CONFIG: [optional] Path to csonfile to be performs service operation based on. Required a config_path argument or this.
#   HUBOT_AWS_EC2_RUN_USERDATA_PATH: [optional] Path to userdata file.
#   HUBOT_AWS_EC2_REQUIRE_SSH_KEY: [optional] Require that a user have a public SSH key saved to their chat account. See https://github.com/catops/catops-keys
#
# Commands:
#   hubot ec2 run <instance_name> <instance_description> - Run an Instance; <instance_name> sets the Name tag, <instance_description> sets the Description tag
#
# Notes:
#   --image_id=***      : [optional] The ID of the AMI. If omit it, the ImageId of config is used
#   --config_path=***   : [optional] Config file path. If omit it, HUBOT_AWS_EC2_RUN_CONFIG is referred to.
#   --userdata_path=*** : [optional] Userdata file path to be not encoded yet. If omit it, HUBOT_AWS_EC2_RUN_USERDATA_PATH is referred to.
#   --squad=***         : [optional] Name of squad the instance belongs to. The public keys of everyone on the squad will be added to the instance. Requires `hubot-squads`.
#   --dry-run           : [optional] Checks whether the api request is right. Recommend to set before applying to real asset.

fs   = require 'fs'
cson = require 'cson'
util = require 'util'

tags_ = require './tags'


getArgParams = (arg) ->
  dry_run = if arg.match(/--dry-run/) then true else false

  image_id_capture = /--image_id=(.*?)( |$)/.exec(arg)
  image_id = if image_id_capture then image_id_capture[1] else null

  config_path_capture = /--config_path=(.*?)( |$)/.exec(arg)
  config_path = if config_path_capture then config_path_capture[1] else null

  userdata_path_capture = /--userdata_path=(.*?)( |$)/.exec(arg)
  userdata_path = if userdata_path_capture then userdata_path_capture[1] else null

  squad_capture = /--(squad|team)=(.*?)( |$)/.exec(arg)
  squad = if squad_capture then squad_capture[2] else null

  return {dry_run: dry_run, image_id: image_id, config_path: config_path, userdata_path: userdata_path, squad: squad}

module.exports = (robot) ->

  robot.respond /ec2 run(.*)$/i, (msg) ->

    unless require('../../auth.coffee').canAccess(robot, msg.envelope.user)
      msg.send "You cannot access this feature. Please contact with admin"
      return

    arg_value = msg.match[1]
    arg_params = getArgParams(arg_value)

    dry_run       = arg_params.dry_run
    image_id      = arg_params.image_id
    config_path   = arg_params.config_path
    userdata_path = arg_params.userdata_path
    squad         = arg_params.squad

    config_path ||= process.env.HUBOT_AWS_EC2_RUN_CONFIG
    unless fs.existsSync config_path
      msg.send "NOT FOUND HUBOT_AWS_EC2_RUN_CONFIG"
      return

    params = cson.parseCSONFile config_path

    params.ImageId = image_id if image_id

    ssh_key = ''

    # Check if a squad was specified and if squads exist in the brain
    if squad and robot.brain.data.squads and robot.brain.data.squads[squad]
      robot.brain.data.squads[squad].members.forEach (member) ->
        member = robot.brain.userForName(member)
        if member and member.key
          ssh_key += member.key + '\n'
        return
    # If we're not using squads, check for the user's key
    else if robot.brain.userForId(msg.envelope.user.id).key
      ssh_key = robot.brain.userForId(msg.envelope.user.id).key

    # If a key is required and we didn't find one, abort
    if !!process.env.HUBOT_AWS_EC2_REQUIRE_SSH_KEY and !ssh_key.length
      return msg.send "You need to set your SSH *public* key first. To do so, copy your ~/.ssh/id_rsa.pub into your clipboard, and then in chat say `#{robot.name} my public key is [your_ssh_key]`"


    curr_value = 0
    aws_instance_name = ""
    aws_instance_desc = ""
    arg_values = arg_value.split /\s+/

    for av in arg_values
      if not av.match(/^--/)
        if (curr_value == 1)
          aws_instance_name = av
        else if (curr_value > 1)
          aws_instance_desc += (av + " ")
        curr_value += 1

    if (aws_instance_name.length == 0)
      msg.send "An AWS instance name is required"
      msg.send "Example usage: ec2 run test_instance this is my description"
      return

    userData = """
      #!/bin/bash
      echo 'UserData inside of run.coffee'
      echo 'Copying user public key into authorized_keys'
      echo '#{ssh_key}' >> /home/ec2-user/.ssh/authorized_keys

      export INSTANCE_NAME=#{aws_instance_name}
    """
    init_file = ""

    userdata_path ||= process.env.HUBOT_AWS_EC2_RUN_USERDATA_PATH
    if fs.existsSync userdata_path
      init_file = fs.readFileSync userdata_path, 'utf-8'
      # params.UserData = new Buffer(init_file).toString('base64')

    userData += "\n" + init_file
    console.log "UserData is " + userData
    buf = new Buffer(userData)


    params.UserData = buf.toString('base64')
    msg.send "Requesting image_id=#{image_id}, config_path=#{config_path}, userdata_path=#{userdata_path}, dry-run=#{dry_run}..."



    # TODO: yank this out into functions; replace with moment.js goodness
    today = new Date
    dd = today.getDate()
    mm = today.getMonth() + 1
    yyyy = today.getFullYear()
    if dd < 10
      dd = '0' + dd
    if mm < 10
      mm = '0' + mm

    expireDate = new Date
    expireDate.setDate(expireDate.getDate() + 14)
    expdd = expireDate.getDate()
    expmm = expireDate.getMonth() + 1
    expyyyy = expireDate.getFullYear()
    if expdd < 10
      expdd = '0' + expdd
    if expmm < 10
      expmm = '0' + expmm


    user_email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL || "unknown"
    tags = [
      { Key: 'Name', Value: aws_instance_name },
      { Key: 'Description', Value: aws_instance_desc },
      { Key: 'Application', Value: '' },
      { Key: 'Creator', Value:  user_email},
      { Key: 'Software', Value: '' },
      { Key: 'BusinessOwner', Value: process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL || "unknown" },
      { Key: 'SysAdmin', Value: user_email },
      { Key: tags_.SCHEDULE_TAG, Value: tags_.formatSchedule(tags_.DEFAULT_SCHEDULE) },
      { Key: 'CreatedByApplication', Value: 'chat' },
      { Key: 'CreateDate', Value: "#{yyyy}-#{mm}-#{dd}"},
      { Key: 'ExpireDate', Value: "#{expyyyy}-#{expmm}-#{expdd}"}
    ]

    for t in tags
      msg.send "Adding new tag: tag_key=#{t['Key']}, tag_value=#{t['Value']}"

    if dry_run
      msg.send util.inspect(params, false, null)
      return

    ec2 = require('../../ec2.coffee')

    ec2.runInstances params, (err, res) ->
      if err
        msg.send "Error: #{err}"
      else
        messages = []
        for ins in res.Instances
          state = ins.State.Name
          id    = ins.InstanceId
          type  = ins.InstanceType
          for network in ins.NetworkInterfaces
            ip  = network.PrivateIpAddress

          messages.push("\n#{state}\t#{id}\t#{type}\t#{ip}\t#{aws_instance_name}\n")
          messages.push("\nIn about 10 minutes, you should be able to ssh in with ssh ec2-user@#{ip}\n")
          messages.push("\n**Note**: it'll be yum updating and applying hardening configs for 20+ minutes, but it should be usable during that time\n")
          messages.push("\nThis instance defaults to running between 8 AM and 6 PM. You can change that schedule with the `ec2 schedule` command. See `bot help ec2 schedule` for details\n")

        messages.sort()
        message = messages.join "\n"
        msg.send message

        params =
          Resources: [id]
          Tags: tags

        ec2.createTags params, (err, res) ->
            if err
              msg.send "Error creating tags: #{err}"
