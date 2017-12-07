# Description:
#   Provides conveniences around certain tags we want to manage
#
# Commands:
#   hubot ec2 reserve <instance_id>  --ReservationUser --ReservationBranch --ReservationDescription
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

tags = require './tags'
ec2 = require('../../ec2.coffee')


reserveForDeploy = (msg, instance, reservation) ->
  tags.addReservation(msg, instance, reservation)
  msg.send "Reservation added to #{instance}. #{reservation} "


#credit: https://github.com/yoheimuta/hubot-aws/blob/master/scripts/ec2/create_tags.coffee
getReservationTags = (args) ->
  reservationUser = /--ReservationUser=(\w+)( |$)/.exec(args)[1]
  reservationTime = Date.now().toString()
  reservationBranch = /--ReservationBranch=(\w+)( |$)/.exec(args)[1]
  reservationDescription = /--ReservationDescription="(.*?)"/.exec(args)[1]

  reservationTags = [
    {Key: 'ReservationUser', Value: reservationUser},
    {Key: 'ReservationTime', Value: reservationTime},
    {Key: 'ReservationBranch', Value: reservationBranch},
    {Key: 'ReservationDescription', Value: reservationDescription}
  ]
  return reservationTags

module.exports = (robot) ->
  robot.respond /ec2 reserve (.*)$/i, (msg) ->
    instance = msg.match[1].split(/\s+/)[0]
    reservation = getReservationTags(msg.match[1])
    reserveForDeploy(msg, instance, reservation)

