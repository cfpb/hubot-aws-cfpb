class Subnet
  util = require 'util'
  cson = require 'cson'
  ec2 = require('../../ec2.coffee')

  withValidSubnet: (env, instances, cb)->

    console.log "Inspecting instance [#{instances}] for proper subnet"
    config = cson.parseCSONFile env.HUBOT_AWS_EC2_RUN_CONFIG
    validSubnet = config["NetworkInterfaces"][0]["SubnetId"]

    params = {}
    params['Filters'] = [
                         {Name: 'instance-id', Values: instances},
                         {Name: 'subnet-id', Values: [validSubnet]}
                        ]
    ec2.describeInstances params, (err, res) ->
        if err
          cb(err)
        else
          if res.Reservations.length == instances.length
            cb(null)
          else
            cb("Instance #{instances} does not exist in the approved subnet")

module.exports = new Subnet
