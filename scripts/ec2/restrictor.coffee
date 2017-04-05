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

    params = restrictor.addInstanceFilter msg, params, instances
    params = restrictor.addSubnetFilter msg, params
    console.log util.inspect(params, false, null)

    # params is a bus for all args passed to the command, so we need to strip out all but the valid ec2 filters we're sending
    ec2Params = {Filters: params['Filters']}
    ec2.describeInstances ec2Params, (err, res) ->
        if err
          console.log util.inspect(err, false, null)
          cb(err)
        else
          # the Reservations data will contain *at least* all the instances we're filtering on, and possibly any other instances that were created/stopped/started in the same command
          # thus we can safely ignore the existence of additional Reservations in this check because we know the ones we care about will be in here if all filter criteria are successfully met
          if res.Reservations.length >= instances.length
            cb(null)
          else
            console.log res.Reservations.length
            console.log util.inspect(res.Reservations, false, null)
            cb("Operation not permitted. Instance #{instances} does not exist in the approved subnet or wasn't created by you")

module.exports = restrictor
