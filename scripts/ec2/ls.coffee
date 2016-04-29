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
#   hubot ec2 filter sometext - Filters instances starting with 'sometext'


moment = require 'moment'
util   = require 'util'
tsv    = require 'tsv'

ec2 = require('../../ec2.coffee')

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
  else if filter == "filter" and instances.length
    params['Filters'] = [{ Name: 'tag:Name', Values: ["#{instances[0]}*"] }]  
  else if instances.length
    params['InstanceIds'] = instances

  if Object.keys(params).length > 0
    return params 
  else 
    return null

listEC2Instances = (params, complete, error) ->
  ec2.describeInstances params, (err, res) ->
    if err
      error(err)
    else
      instances = []
      for reservation in res.Reservations
        for instance in reservation.Instances
          instances.push(instance)

      complete(instances)

get_expiration_tag = (tag) ->
  return tag.Key == "ExpireDate"

instance_will_expire_soon = (instance) -> 
  expiration_tag = instance.Tags.filter get_expiration_tag
  if expiration_tag.length == 0
    return false

  expiraton_moment = moment(expiration_tag[0].Value).format('YYYY-MM-DD')
  DAYS_CONSIDERED_SOON = 2
  will_be_expired_in_x_days = expiration_tag < moment().add(DAYS_CONSIDERED_SOON, 'days') 
  is_not_expired_now = expiration_tag > moment()
  return will_be_expired_in_x_days and not is_not_expired_now

instance_has_expired = (instance) -> 
  expiration_tag = instance.Tags.filter get_expiration_tag
  if expiration_tag.length == 0
    return false

  is_not_expired_now = expiration_tag > moment()
  return is_not_expired_now

handle_instances = (robot) ->
  return (instances) ->
    instances_that_will_expire = instances.filter instance_will_expire_soon
    instances_that_have_expired = instances.filter instance_has_expired

    robot.messageRoom process.env.HUBOT_EC2_MENTION_ROOM, "Instances that will expire soon...\n" + 
      messages_from_ec2_instances(instances_that_will_expire)

    robot.messageRoom process.env.HUBOT_EC2_MENTION_ROOM, "Instances that have expired...\n" + 
      messages_from_ec2_instances(instances_that_have_expired)

handle_ec2_instance = (robot) ->
  if process.env.HUBOT_EC2_MENTION_ROOM
    listEC2Instances({}, handle_instances(robot), ->)  
    
ec2_setup_polling = (robot) ->
  setInterval ->
    handle_ec2_instance(robot)?
  , 1000 * 60 * 60 * 8

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
  
  ec2_setup_polling(robot)

  robot.respond /ec2 ls(.*)$/i, (msg) ->
    arg_params = getArgParams(arg=msg.match[1])
    msg.send "Fetching instances..."

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

  robot.respond /ec2 filter(.*)$/i, (msg) ->
    arg_params = getArgParams(arg=msg.match[1], filter="filter")
    msg.send "Fetching filtered instances..."

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

  robot.respond /ec2 mine$/i, (msg) ->
    creator_email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL || "unknown"
    msg.send "Fetching instances created by #{creator_email} ..."
    arg_params = getArgParams(arg=msg.match[1], filter="mine", opt_arg=creator_email)

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))


  robot.respond /ec2 chat$/i, (msg) ->
    msg.send "Fetching instances created via chat ..."
    arg_params = getArgParams(arg=msg.match[1], filter="chat")

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

