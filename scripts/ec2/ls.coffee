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

getArgParams = (arg, filter="all", opt_arg="") ->
  instances = []
  if arg
    for av in arg.split /\s+/
      if av and not av.match(/^--/)
        instances.push(av)

  params = {}

  if filter == "mine"
    params['Filters'] = [{ Name: 'tag:Creator', Values: [opt_arg] }]
  else if filter == "chat"
    params['Filters'] = [{ Name: 'tag:CreatedByApplication', Values: [filter] }]
  else if instances.length
    params['InstanceIds'] = instances

  if Object.keys(params).length > 0
    return params 
  else 
    return null

listEC2Instances = (ec2, params, complete, error) ->
  ec2.describeInstances params, (err, res) ->
    if err
      error(err)
    else
      instances = []
      for reservation in res.Reservations
        for instance in reservation.Instances
          instances.push(instance)

      complete(instances)

get_expiration_tag = (tags) ->
  expiration_tags = tags.filter (tag) -> tag.Key = "ExpireDate"

  unless expiration_tags.length
    return moment() 
  return moment(expiration_tags[0].Value).format('YYYY-MM-DD')

instance_will_expire_soon = (instance) -> 
  expiration_tag = instance.Tags.filter get_expiration_tag
  DAYS_CONSIDERED_SOON = 2
  will_be_expired_in_x_days = expiration_tag < moment().add(DAYS_CONSIDERED_SOON, 'days') 
  is_not_expired_now = expiration_tag > moment()
  return will_be_expired_in_x_days and not is_not_expired_now

instance_has_expired = (instance) -> 
  expiration_tag = instance.Tags.filter get_expiration_tag
  is_not_expired_now = expiration_tag > moment()
  return is_not_expired_now

handle_instances_that_will_expire_soon = (instances) ->
  true

handle_instances_that_have_expired = (instances) ->
  true

handle_all_instances = (instances) ->
  true

handle_instances = (instances) ->
  instances_that_will_expire = instances.filter instance_will_expire_soon
  instances_that_have_expired = instances.filter instance_has_expired

  handle_instances_that_will_expire_soon(instances_that_will_expire)
  handle_instances_that_have_expired(instances_that_have_expired)
  handle_all_instances(instances)

handle_ec2_instance = (robot, ec2) ->
  robot.messageRoom "l33t room", "before list instances"
  # listEC2Instances(ec2, {}, handle_instances, ->)  

ec2_setup_polling = (robot, ec2) ->
  setInterval ->
    handle_ec2_instance(robot, ec2)?
  , 1000 * 60 * 1

messages_from_ec2_instances = (instances) ->
  messages = []
  for instance in instances
    name = '[NoName]'
    for tag in instance.Tags when tag.Key is 'Name'
      name = tag.Value

    messages.push({
      time   : moment(instance.LaunchTime).format('YYYY-MM-DD HH:mm:ssZ')
      state  : instance.State.Name
      id     : instance.InstanceId
      image  : instance.ImageId
      az     : instance.Placement.AvailabilityZone
      subnet : instance.SubnetId
      type   : instance.InstanceType
      ip     : instance.PrivateIpAddress
      name   : name || '[NoName]'
    })

  messages.sort (a, b) ->
      moment(a.time) - moment(b.time)
  return tsv.stringify(messages) || '[None]'

error_ec2_instances = (msg, err) ->
  return (err) -> 
    msg.send "DescribeInstancesError: #{err}"

complete_ec2_instances = (msg, instances) ->
  return (instances) -> 
    msg.send messages_from_ec2_instances(instances)

module.exports = (robot) ->
  aws = require('../../aws.coffee').aws()
  ec2 = new aws.EC2({apiVersion: '2014-10-01'})

  ec2_setup_polling(robot, ec2)

  robot.respond /ec2 ls(.*)$/i, (msg) ->
    arg_params = getArgParams(msg.match[1])
    msg_txt = "Fetching instances..."
    msg.send msg_txt

    listEC2Instances(ec2, arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))


  robot.respond /ec2 mine$/i, (msg) ->
    creator_email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL || "unknown"
    msg_txt = "Fetching instances created by #{creator_email} ..."
    msg.send msg_txt
    arg_params = getArgParams(msg.match[1], "mine", creator_email)

    listEC2Instances(ec2, arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))


  robot.respond /ec2 chat$/i, (msg) ->
    msg_txt = "Fetching instances created via chat ..."
    msg.send msg_txt
    arg_params = getArgParams(msg.match[1], "chat")

    listEC2Instances(ec2, arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

