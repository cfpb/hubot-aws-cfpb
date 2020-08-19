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
#   hubot ec2 filter sometext - Filters Instances whose name (name tag value) contains 'sometext'
#   hubot ec2 expired - Displays Instances that have expired
#   hubot ec2 expiring - Displays Instances that are expiring within 2 days
#   hubot ec2 windows - Displays Instances running the Windows OS
#
gist = require 'quick-gist'
mdTable = require('markdown-table')
moment = require 'moment'
_ = require 'underscore'
tsv = require 'tsv'
tags = require './tags'
util = require 'util'

EXPIRED_MESSAGE = "Instances that have expired \n"
EXPIRES_SOON_MESSAGE = "Instances that will expire soon \n"
USER_EXPIRES_SOON_MESSAGE = "List of your instances that will expire soon: \n"
EXTEND_COMMAND = "\nIf you wish to extend run 'cfpbot ec2 extend [instanceIds]'"
DAYS_CONSIDERED_SOON = 2

ec2 = require('../../ec2.coffee')

getArgParams = (arg, filter = "all", opt_arg = "") ->
  filterValues = []
  if arg
    for av in arg.split /\s+/
      if av and not av.match(/^--/)
        filterValues.push(av)

  #console.log "filterValues are: "
  #console.log util.inspect(filterValues, false, null)

  params = {}

  if filter == "mine"
    params['Filters'] = [{Name: 'tag:Creator', Values: [opt_arg]}]
  else if filter == "chat"
    params['Filters'] = [{Name: 'tag:CreatedByApplication', Values: [filter]}]
  else if filter == "windows"
    params['Filters'] = [{Name: 'platform', Values: [filter]}]  
  else if filter == "filter" and filterValues.length
    params['Filters'] = [{Name: 'tag-value', Values: ["*#{filterValues[0]}*"]}]
  else if filterValues.length
    params['InstanceIds'] = filterValues

  if Object.keys(params).length > 0
    return params
  else
    return null

listEC2Instances = (params, complete, error) ->

  console.log util.inspect(params, false, null)


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

  expiration_moment = moment(expiration_tag[0].Value).format('YYYY-MM-DD')
  will_be_expired_in_x_days = expiration_moment <= moment().add(DAYS_CONSIDERED_SOON, 'days').format('YYYY-MM-DD')
  is_not_expired_now = expiration_moment < moment().format('YYYY-MM-DD')
  return will_be_expired_in_x_days and not is_not_expired_now and instance.State.Name == "running"

instance_has_expired = (instance) ->
  expiration_tag = instance.Tags.filter get_expiration_tag
  if expiration_tag.length == 0
    return false

  expiration_moment = moment(expiration_tag[0].Value).format('YYYY-MM-DD')

  is_not_expired_now = expiration_moment < moment().format('YYYY-MM-DD')
  return is_not_expired_now and instance.State.Name == "running"

extract_message = (instances, msg)->
  return msg + messages_from_ec2_instances(instances)

get_instance_tag = (instance, key, default_value = "")->
  tags_ = _.filter(instance.Tags, (tag)-> return tag.Key == key)
  if not _.isEmpty(tags_)
    return tags_[0].Value
  else
    return default_value

list_expiring_msg = (msg)->
  return (instances)->
    instances_that_will_expire = instances.filter instance_will_expire_soon
    handle_sending_message msg, extract_message(instances_that_will_expire, EXPIRES_SOON_MESSAGE)

list_expired_msg = (msg)->
  return (instances)->
    instances_that_expired = instances.filter instance_has_expired
    handle_sending_message msg, extract_message(instances_that_expired, EXPIRED_MESSAGE)

handle_instances = (robot) ->
  msg_room = (msg_text, room = process.env.HUBOT_EC2_MENTION_ROOM) ->
    robot.messageRoom room, msg_text

  return (instances) ->
    instances_that_expired = instances.filter instance_has_expired
    instances_that_will_expire = instances.filter instance_will_expire_soon

    if instances_that_will_expire.length
      msg_text_expire_soon = extract_message(instances_that_will_expire, EXPIRES_SOON_MESSAGE)
      msg_room(msg_text_expire_soon)

      for user in _.values(robot.brain.data.users)
        creator_email = user.email_address || ""
        user_id = user.id

        user_instances = _.filter(instances_that_will_expire, (this_instance)-> return get_instance_tag(this_instance, 'Creator').toLowerCase() == creator_email.toLowerCase())

        if user_instances.length
          msg_text_expire_soon = extract_message(user_instances, USER_EXPIRES_SOON_MESSAGE) + EXTEND_COMMAND
          msg_room(msg_text_expire_soon, user.name)

    instanceIdsToStop = _.pluck(instances_that_expired, 'InstanceId')
    if instanceIdsToStop.length
      console.log "Stopping expired EC2 instances: #{instanceIdsToStop}"

      ec2.stopInstances {InstanceIds: instanceIdsToStop}, (err, res) ->
        if err
          msg_room(err)
        else
          tags.removeSchedule(null, instanceIdsToStop)


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

  getTag = (_tags, tag) -> _.first(t.Value for t in _tags when t.Key is tag) || ''

  for instance in instances
    messages.push({
      time: moment(instance.LaunchTime).format('YYYY-MM-DD')
      state: instance.State.Name
      id: instance.InstanceId
      type: instance.InstanceType
      ip: instance.PrivateIpAddress
      name: getTag(instance.Tags, 'Name') || '[NoName]'
      description: getTag(instance.Tags, 'Description') || ''
      expiration: getTag(instance.Tags, 'ExpireDate') || ''
      schedule: getTag(instance.Tags, tags.SCHEDULE_TAG) || ''
      backup: getTag(instance.Tags, 'Backup') || '[None]'
      creator: getTag(instance.Tags, 'Creator') || '[None]'
    })

  messages.sort (a, b) ->
    moment(a.time) - moment(b.time)

  if messages.length
    tableHead = [
      'id',
      'ip',
      'name',
      'creator',
      'state',
      'description',
      'type',
      'launched',
      'expires',
      'schedule',
      'backup',
    ]
    tableRows = (
      [
        m.id,
        m.ip,
        m.name,
        m.creator,
        m.state,
        m.description,
        m.type,
        m.time,
        m.expiration,
        m.schedule,
        m.backup,
      ] for m in messages
    )
    tableRows.unshift tableHead
    table = mdTable tableRows, {align: 'l'}
    return "\n#{table}"
  else
    return "\n[None]\n"

error_ec2_instances = (msg, err) ->
  return (err) ->
    msg.send "DescribeInstancesError: #{err}"

handle_sending_message = (msg, messages) ->
  if messages.length < 1000
    msg.send messages
  else
    gistOpts = {content: messages, enterpriseOnly: true, fileExtension: 'md'}
    gist gistOpts, (err, resp, data) ->
      url = data.html_url
      msg.send "View instances at: " + url

complete_ec2_instances = (msg, instances) ->
  return (instances) ->
    handle_sending_message msg, messages_from_ec2_instances(instances)

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

    listEC2Instances(null, list_expiring_msg(msg), error_ec2_instances(msg))

  robot.respond /ec2 expired$/i, (msg)->
    msg.send "Fetching all instances that are expired"

    listEC2Instances(null, list_expired_msg(msg), error_ec2_instances(msg))

  robot.respond /ec2 windows$/i, (msg)->
    msg.send "Fetching all windows instances ..."
    arg_params = getArgParams(arg = msg.match[1], filter = "windows")

    listEC2Instances(arg_params, complete_ec2_instances(msg), error_ec2_instances(msg))
