util = require 'util'
cson = require 'cson'
ec2 = require('../../ec2.coffee')

restrictor =

  ensureFilters: (params) ->
    if not params['Filters']
      params['Filters'] = []
    return params

  addInstanceFilter: (msg, params, instances) ->
    params = restrictor.ensureFilters(params)
    params['InstanceIds'] = instances
    return params

  addSubnetFilter: (msg, params) ->
    params = restrictor.ensureFilters(params)
    config = cson.parseCSONFile process.env.HUBOT_AWS_EC2_RUN_CONFIG
    validSubnet = config["NetworkInterfaces"][0]["SubnetId"]
    params['Filters'].push {Name: 'subnet-id', Values: [validSubnet]}
    return params

  addUserCreatedFilter: (msg, params) ->
    params = restrictor.ensureFilters(params)
    email = msg.message.user["email_address"] || process.env.HUBOT_AWS_DEFAULT_CREATOR_EMAIL
    params['Filters'].push {Name: 'tag:Creator', Values:[email]}
    return params


  authorizeOperation: (msg, params, instances, cb) ->

    console.log "Inspecting instance [#{instances}] for permission to run this operation"
    console.log util.inspect(params, false, null)

    # params is a bus for all args passed to the command, so we need to strip out all but the valid ec2 filters we're sending
    ec2Params = restrictor.ensureFilters(params)
    ec2Params = {Filters: params['Filters']}

    ec2Params = restrictor.addInstanceFilter msg, ec2Params, instances
    ec2Params = restrictor.addSubnetFilter msg, ec2Params
    console.log "Passing these ec2Params..."
    console.log util.inspect(ec2Params, false, null)

    ec2.describeInstances ec2Params, (err, res) ->
        if err
          console.log "Error in describe Instances"
          console.log util.inspect(err, false, null)
          cb(err)
        else
          if res.Reservations.length >= instances.length
            console.log "Operation authorized... result:"
            console.log util.inspect(res.Reservations, false, null)
            cb(null)
          else
            console.log "Operation not authorized... #{res.Reservations.length} result(s) found. Result:"
            console.log util.inspect(res, false, null)
            cb("Operation not permitted. Instance #{instances} does not exist in the approved subnet or wasn't created by you")

module.exports = restrictor
