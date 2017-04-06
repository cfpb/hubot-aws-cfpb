
cson = require 'cson'
ec2 = require('../../ec2.coffee')
util = require 'util'

# Expose to other scripts
tags =

  addSchedule: (msg, instances, schedule="8:18") ->
    ec2.createTags {Resources: instances, Tags: [Key: "Schedule", Value: schedule]}, (err, res) ->
      if err
        console.log "Error creating tags: #{err}"
        if msg
          return msg.send "Error creating tags: #{err}" if err

  removeSchedule: (msg, instances) ->
    return tags.addSchedule(msg, instances, "")

module.exports = tags

