# Description:
#   Commands for reserving ec2 instances and listing existing reservations
#
# Commands:
#   hubot ec2 reserve <instance-id-nickname> <branch-name> <reservation comment> - Reserve an Instance
#   hubot ec2 unreserve <instance-id-nickname> - Unreserve an Instance
#   hubot ec2 reserve-ls - Displays a list of currently reserved Instances
#

_ = require 'underscore'
cson = require 'cson'
ec2 = require('../../ec2.coffee')
moment = require 'moment'
tags = require './tags'
mdTable = require('markdown-table')


RESERVE_TAGS = {
  user: 'ReservationUser',
  time: 'ReservationTime',
  branch: 'ReservationBranch',
  description: 'ReservationDescription',
}

RESERVE_CONFIG_ENV_VAR = "HUBOT_AWS_RESERVE_CONFIG"

try
  INSTANCE_ID_MAP = cson.parseCSONFile process.env[RESERVE_CONFIG_ENV_VAR]
catch e
  # TODO switch to `robot.logger()` here _without_ constantly reparsing config file
  if e.name == "TypeError"
    console.log "#{RESERVE_CONFIG_ENV_VAR} is not defined"
  else
    console.log "#{RESERVE_CONFIG_ENV_VAR} could not be loaded " +
                "(#{process.env.HUBOT_AWS_RESERVE_CONFIG})"
  INSTANCE_ID_MAP = {}


getReservationTags = (msg) ->
  args = if msg.match[1] then msg.match[1].trim().split(/\s+/).slice(1) else []
  if args.length < 2
    []
  else
    [
      {Key: RESERVE_TAGS.user, Value: msg.message.user.name},
      {Key: RESERVE_TAGS.time, Value: Date.now().toString()},
      {Key: RESERVE_TAGS.branch, Value: args[0]},
      {Key: RESERVE_TAGS.description, Value: args.slice(1).join(" ")},
    ]

formatReservationsList = (instances) ->
  if not instances.length
    return '[None]'

  getTag = (_tags, tag) -> _.first(t.Value for t in _tags when t.Key is tag) || ''

  instanceMap = _.invert(INSTANCE_ID_MAP)

  rows = (
    {
      id: instanceMap[i.InstanceId] || "UNKNOWN",
      resUser: getTag(i.Tags, RESERVE_TAGS.user),
      resTime: getTag(i.Tags, RESERVE_TAGS.time),
      resBranch: getTag(i.Tags, RESERVE_TAGS.branch),
      resDescrip: getTag(i.Tags, RESERVE_TAGS.description),
      state: i.State.Name,
    } for i in instances
  ).sort (a, b) -> a.id > b.id

  timeFmt = "MMM Do YYYY, h:mm a"
  tableHead = [
    'instance', 'user', 'reserved time', 'branch', 'comment', 'status'
  ]
  tableRows = (
    [
      r.id,
      r.resUser,
      moment(parseInt(r.resTime)).format(timeFmt),
      r.resBranch,
      r.resDescrip,
      r.state,
    ] for r in rows
  )
  tableRows.unshift tableHead
  mdTable tableRows, {align: 'l'}

module.exports = (robot) ->
  robot.respond /ec2 reserve (.*)$/i, (msg) ->
    instance = msg.match[1].trim().split(/\s+/)[0]
    if !INSTANCE_ID_MAP[instance]
      validInstanceIDs = Object.keys(INSTANCE_ID_MAP).join(", ")
      return msg.send "Unknown instance nickname. Choose from: #{validInstanceIDs}"

    reservationTags = getReservationTags(msg)
    if !reservationTags.length
      msg.send "Cannot reserve: please provide a branch and a comment"
    else
      tags.addReservation(msg, INSTANCE_ID_MAP[instance], reservationTags)
      msg.send "Reservation added to #{instance}."

  robot.respond /ec2 unreserve (.*)$/i, (msg) ->
    instance = msg.match[1].trim().split(/\s+/)[0]
    if !INSTANCE_ID_MAP[instance]
      return msg.send "Unknown instance: #{instance}"
    reservationTags = [
      {Key: RESERVE_TAGS.user, Value: "--"},
      {Key: RESERVE_TAGS.time, Value: Date.now().toString()},
      {Key: RESERVE_TAGS.branch, Value: "--"},
      {Key: RESERVE_TAGS.description, Value: "--"},
    ]
    tags.addReservation(msg, INSTANCE_ID_MAP[instance], reservationTags)
    msg.send "Unreserved instance: #{instance}."

  robot.respond /ec2 reserve-ls$/i, (msg) ->
    params = {
      Filters: [
        {
          Name: 'tag-key',
          Values: [RESERVE_TAGS.user]
        }
      ]
    }
    ec2.describeInstances params, (err, res) ->
      if err
        msg.send "DescribeInstancesError: #{err}"
      else
        instances = _.flatten(i for i in (r.Instances for r in res.Reservations))
        msg.send(formatReservationsList(instances))
