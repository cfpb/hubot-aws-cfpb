# Description:
#   Provides conveniences around certain tags we want to manage
#
# Commands:
#   hubot ec2 reserve <instance_id> [<instance_id> ...] --ReservationUser --ReservationBranch --ReservationDescription
#   Adds an appropriate reserved deployment tag to the instance(s). 
#  
# Notes:
#instance_id : [required] The ID of one or more instances to modify tags. For example, i-0acec691.
# Tags might be something like:
#
# ReservationUser = user who kicked off the build
# ReservationTime = current date/time
# ReservationBranch = branch name that was deployed
# ReservationDescription = whatever the user types as the description

cson = require 'cson'
restrictor = require './restrictor'
tags = require './tags'
util = require 'util'
ec2 = require('../../ec2.coffee')


reserveIfAuthorized = (msg, instances, reservation, err) ->
  return (err) ->
    return msg.send "Error! #{err}" if err
    tags.addReservation(msg, instances, reservation)
    msg.send "Schedule added to #{instances}. Those instances will now start and stop on a schedule of #{schedule}"



#credit: https://github.com/yoheimuta/hubot-aws/blob/master/scripts/ec2/create_tags.coffee
getReservationTags = (args) ->

  reservationUser = /--ReservatonUser=(\d*?)( |$)/.exec(args)
  reservationTime = Date.now()
  reservationBranch = /--ReservationBranch=(\d*?)( |$)/.exec(args)
  reservationDescription = /--ReservationDescription=(\d*?)( |$)/.exec(args)

  tags = [
    { Key: 'ReservationUser', Value: reservationUser },
    { Key: 'ReservationTime', Value: reservationTime },
    { Key: 'ReservationBranch', Value: reservationBranch },
    { Key: 'ReservationDescription', Value:  reservationDescription}
  ]

  return tags

module.exports = (robot) ->
  robot.respond /ec2 reserve (.*)$/i, (msg) ->

    instances = createInstancesArray(msg.match[1])
    return msg.send "One or more instance_ids are required" if instances.length < 1

    reservation = getReservationTags(msg.match[1])

    arg_params = restrictor.addUserCreatedFilter(msg, {})
    restrictor.authorizeOperation(msg, arg_params, instances, reserveIfAuthorized(msg, instances, reservation))

