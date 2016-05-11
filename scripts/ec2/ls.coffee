# Description:
#   List ec2 instances info
#   Show detail about an instance if specified an instance id
#   Filter ec2 instances info if specified an instance name
# Configurations:
#   HUBOT_AWS_DEFAULT_CREATOR_EMAIL: [required] An email address to be used for tagging the new instance
#
# Commands:
#   hubot ec2 ls - Displays Instances
#   hubot ec2 ls instance_id - Displays details about 'instance_id'
#   hubot ec2 mine - Displays Instances I've created, based on user email
#   hubot ec2 chat - Displays Instances created via chat
#   hubot ec2 filter sometext - Filters instances whose name (name tag value) contains 'sometext'
#   hubot ec2 expired - Displays instances that have expired
#   hubot ec2 expiring - Displays instances that are expiring within 2 days
#
gist = require 'quick-gist'
moment = require 'moment'
_ = require 'underscore'
tsv = require 'tsv'

EXPIRED_MESSAGE = "Instances that have expired \n"
EXPIRES_SOON_MESSAGE = "Instances that will expire soon \n"
USER_EXPIRES_SOON_MESSAGE = "List of your instances that will expire soon: \n"
EXTEND_COMMAND = "\nIf you wish to extend run 'cfpbot ec2 extend [instanceIds]'"
DAYS_CONSIDERED_SOON = 2


ec2 = require('../../ec2.coffee')

getArgParams = (arg, filter = "all", opt_arg = "") ->
  instances = []
  if arg
    for av in arg.split /\s+/
      if av and not av.match(/^--/)
        instances.push(av)

  params = {}

  if filter == "mine"
    params['Filters'] = [{Name: 'tag:Creator', Values: [opt_arg]}]
  else if filter == "chat"
    params['Filters'] = [{Name: 'tag:CreatedByApplication', Values: [filter]}]
  else if filter == "filter" and instances.length
    params['Filters'] = [{Name: 'tag:Name', Values: ["*#{instances[0]}*"]}]
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
  will_be_expired_in_x_days = expiraton_moment <= moment().add(DAYS_CONSIDERED_SOON, 'days').format('YYYY-MM-DD')
  is_not_expired_now = expiraton_moment < moment().format('YYYY-MM-DD')
  return will_be_expired_in_x_days and not is_not_expired_now

instance_has_expired = (instance) ->
  expiration_tag = instance.Tags.filter get_expiration_tag
  if expiration_tag.length == 0
    return false

  expiraton_moment = moment(expiration_tag[0].Value).format('YYYY-MM-DD')

  is_not_expired_now = expiraton_moment < moment().format('YYYY-MM-DD')
  return is_not_expired_now

extract_message = (instances, msg)->
  return msg + messages_from_ec2_instances(instances)

get_instance_tag = (instance, key, default_value = "")->
  tags = _.filter(instance.Tags, (tag)-> return tag.Key == key)
  if not _.isEmpty(tags)
    return tags[0].Value
  else
    return default_value

list_expiring_msg = (msg)->
  return (instances)->
    instances_that_will_expire = instances.filter instance_will_expire_soon
    msg_text_expire_soon = extract_message(instances_that_will_expire, EXPIRES_SOON_MESSAGE)
    msg.send(msg_text_expire_soon)

list_expired_msg = (msg)->
  return (instances)->
    instances_that_expired = instances.filter instance_has_expired
    msg_text_expired = extract_message(instances_that_expired, EXPIRED_MESSAGE)
    msg.send(msg_text_expired)

handle_instances = (robot) ->
  msg_room = (msg_text, room = process.env.HUBOT_EC2_MENTION_ROOM) ->
    robot.messageRoom room, msg_text

  return (instances) ->
    instances_that_expired = instances.filter instance_has_expired
    instances_that_will_expire = instances.filter instance_will_expire_soon

    msg_text_expired = extract_message(instances_that_expired, EXPIRED_MESSAGE)
    msg_text_expire_soon = extract_message(instances_that_will_expire, EXPIRES_SOON_MESSAGE)

    msg_room(msg_text_expired)
    msg_room(msg_text_expire_soon)

    for user in _.values(robot.brain.data.users)
      creator_email = user.email_address || "_DL_CFPB_Software_Delivery_Team@cfpb.gov"
      user_id = user.id || 1

      user_instances = _.filter(instances_that_will_expire, (this_instance)-> return get_instance_tag(this_instance, 'Creator') == creator_email)

      if user_instances
        msg_text_expire_soon = extract_message(user_instances, USER_EXPIRES_SOON_MESSAGE) + EXTEND_COMMAND

    msg_room(msg_text_expired)
    msg_room(msg_text_expire_soon)

    for user in _.values(robot.brain.data.users)
      creator_email = user.email_address || "_DL_CFPB_Software_Delivery_Team@cfpb.gov"
      user_id = user.id || 1

      user_instances = _.filter(instances_that_will_expire, (this_instance)-> return get_instance_tag(this_instance, 'Creator') == creator_email)

      if user_instances
        msg_text_expire_soon = extract_message(user_instances, USER_EXPIRES_SOON_MESSAGE) + EXTEND_COMMAND
        robot.send({user: user_id}, msg_text_expire_soon)

    ec2.stopInstances {InstanceIds: _.pluck(instances_that_expired, 'InstanceId')}, (err, res) ->
      if err
        msg_room(res)


handle_ec2_instance = (robot) ->
  if process.env.HUBOT_EC2_MENTION_ROOM
    params = getArgParams(null, filter = "chat")
    listEC2Instances(params, handle_instances(robot), ->)

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
      time: moment(instance.LaunchTime).format('YYYY-MM-DD HH:mm:ssZ')
      state: instance.State.Name
      id: instance.InstanceId
      image: instance.ImageId
      az: instance.Placement.AvailabilityZone
      subnet: instance.SubnetId
      type: instance.InstanceType
      ip: instance.PrivateIpAddress
      name: name || '[NoName]'
    })

  messages.sort (a, b) ->
    moment(a.time) - moment(b.time)
  return tsv.stringify(messages) || '[None]'


error_ec2_instances = (msg, err) ->
  return (err) ->
    msg.send "DescribeInstancesError: #{err}"

complete_ec2_instances = (msg, instances) ->
  return (instances) ->
    msgs = messages_from_ec2_instances(instances)
    if msgs.length < 1000
      msg.send msgs
    else
      gist {content: msgs, enterpriseOnly: true}, (err, resp, data) ->
        url = data.html_url
        msg.send "View instances at: " + url

module.exports = (robot) ->
  ec2_setup_polling(robot)

  robot.respond /ec2 ls(.*)$/i, (msg) ->
    arg_params = getArgParams(arg = msg.match[1])
    msg.send "Fetching instances..."

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

  robot.respond /ec2 filter(.*)$/i, (msg) ->
    arg_params = getArgParams(arg = msg.match[1], filter = "filter")
    msg.send "Fetching filtered instances..."

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

  robot.respond /ec2 mine$/i, (msg) ->
    creator_email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL || "unknown"
    msg.send "Fetching instances created by #{creator_email} ..."
    arg_params = getArgParams(arg = msg.match[1], filter = "mine", opt_arg = creator_email)

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))


  robot.respond /ec2 chat$/i, (msg) ->
    msg.send "Fetching instances created via chat ..."
    arg_params = getArgParams(arg = msg.match[1], filter = "chat")

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))

  robot.respond /ec2 expiring$/i, (msg)->
    msg.send "Fetching all instances expiring within #{DAYS_CONSIDERED_SOON} days"

    listEC2Instances(null, list_expiring_msg(msg), error_ec2_instances())

  robot.respond /ec2 expired$/i, (msg)->
    msg.send "Fetching all instances that are expired"

    listEC2Instances(null, list_expired_msg(msg), error_ec2_instances())
