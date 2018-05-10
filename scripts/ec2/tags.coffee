ec2 = require('../../ec2.coffee')
moment = require('moment')
validator = require('validator')


tags =

  DEFAULT_SCHEDULE: "8:18"

  SCHEDULE_TAG: "RunSchedule"

  # convert our concise schedule strings ("8:18") to the new UTC-based format
  formatSchedule: (hours) ->
    [_, start, stop] = hours.match /^(\d{1,2}):(\d{1,2})$/

    invalidHours = [start, stop]
      .map((e) -> validator.isInt(e, {min: 0, max: 24}))
      .some((e) -> !e)
    if invalidHours
      throw new Error("Start/stop hours must be between 0 and 24")

    startUtc = moment({hour: start, minute: 0}).utc().hour().toString()
    stopUtc = moment({hour: stop, minute: 0}).utc().hour().toString()
    [
      "#{startUtc.padStart(2, '0').padEnd(4, '0')}",
      "#{stopUtc.padStart(2, '0').padEnd(4, '0')}",
      "utc",
      "mon,tue,wed,thu,fri",
    ].join ";"

  addSchedule: (msg, instances, schedule = tags.DEFAULT_SCHEDULE) ->
    try
      scheduleFmt = if schedule then tags.formatSchedule(schedule) else ""
    catch e
      return msg.send(
        "Error parsing schedule; verify correct 24-hour format (eg '8:18')."
      )

    ec2.createTags(
      {Resources: instances, Tags: [Key: tags.SCHEDULE_TAG, Value: scheduleFmt]},
      (err, res) ->
        if err
          console.log "Error creating tags: #{err}"
          if msg
            return msg.send "Error creating tags: #{err}" if err
    )

  removeSchedule: (msg, instances) ->
    return tags.addSchedule(msg, instances, "")

  addReservation:(msg, instance, content) ->
    ec2.createTags {Resources: [instance], Tags: content}, (err, res) ->
      if msg
        return msg.send "Error creating tags: #{err}" if err


module.exports = tags
