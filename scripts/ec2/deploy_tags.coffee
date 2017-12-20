# Description:
#   Commands for reserving ec2 instances and listing existing reservations
#
# Commands:
#   hubot ec2 reserve <instance_id>  --ReservationUser=<username> --ReservationBranch=<branch> --ReservationDescription="description text"
#   hubot ec2 reserve-ls - Displays a list of currently reserved instances
#

_ = require 'underscore'
ec2 = require('../../ec2.coffee')
moment = require 'moment'
tags = require './tags'
AsciiTable = require('ascii-table')


RESERVE_TAGS = {
  user: 'ReservationUser',
  time: 'ReservationTime',
  branch: 'ReservationBranch',
  description: 'ReservationDescription',
}

reserveForDeploy = (msg, instance, reservation) ->
  tags.addReservation(msg, instance, reservation)
  msg.send "Reservation added to #{instance}."

getReservationTags = (args) ->
  reservationUser = ///--#{RESERVE_TAGS.user}=(.*?)(\s+|$)///.exec(args)[1]
  reservationTime = Date.now().toString()
  reservationBranch = ///--#{RESERVE_TAGS.branch}=(.*?)(\s+|$)///.exec(args)[1]
  reservationDescription = ///--#{RESERVE_TAGS.description}="(.*?)"///.exec(args)[1]
  [
    {Key: RESERVE_TAGS.user, Value: reservationUser},
    {Key: RESERVE_TAGS.time, Value: reservationTime},
    {Key: RESERVE_TAGS.branch, Value: reservationBranch},
    {Key: RESERVE_TAGS.description, Value: reservationDescription},
  ]

formatReservationsList = (instances) ->
  if not instances.length
    return '[None]'

  getTag = (_tags, tag) -> _.first(t.Value for t in _tags when t.Key is tag) || ''

  rows = (
    {
      id: i.InstanceId,
      name: getTag(i.Tags, 'Name'),
      ip: i.PrivateIpAddress,
      state: i.State.Name,
      resUser: getTag(i.Tags, RESERVE_TAGS.user),
      resTime: getTag(i.Tags, RESERVE_TAGS.time),
      resBranch: getTag(i.Tags, RESERVE_TAGS.branch),
      resDescrip: getTag(i.Tags, RESERVE_TAGS.description)
    } for i in instances
  ).sort (a, b) -> parseInt(a.resTime) - parseInt(b.resTime)

  table = new AsciiTable()
  table.setHeading 'id', 'name', 'IP address', 'status', 'user', 'reserved time',
    'branch', 'comment'
  rows.forEach (r) ->
    table.addRow r.id, r.name, r.ip, r.state, r.resUser,
      moment(parseInt(r.resTime)).format("MMM Do YYYY, h:mm a"),
      r.resBranch, r.resDescrip

  '```\n' + table.toString() + '\n```\n'

module.exports = (robot) ->
  robot.respond /ec2 reserve (.*)$/i, (msg) ->
    instance = msg.match[1].split(/\s+/)[0]
    reservation = getReservationTags(msg.match[1])
    reserveForDeploy(msg, instance, reservation)

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
