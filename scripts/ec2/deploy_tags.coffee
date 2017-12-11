# Description:
#   Provides conveniences around certain tags we want to manage
#
# Commands:
#   hubot ec2 reserve <instance_id>  --ReservationUser=<username> --ReservationBranch=<branch> --ReservationDescription="description text"
#   Adds an appropriate reserved deployment tag to the instance(s). 
#  
# Example:
#   hubot ec2 reserve i-XXXXXXXX --ReservationUser=my-name --ReservationBranch=branch-name --ReservationDescription="my reservation explanation"

tags = require './tags'
ec2 = require('../../ec2.coffee')


reserveForDeploy = (msg, instance, reservation) ->
  tags.addReservation(msg, instance, reservation)
  msg.send "Reservation added to #{instance}. #{reservation} "

getReservationTags = (args) ->
  reservationUser = /--ReservationUser=(.*?)( |$)/.exec(args)[1]
  reservationTime = Date.now().toString()
  reservationBranch = /--ReservationBranch=(.*?)( |$)/.exec(args)[1]
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
