aws_api = require 'aws-sdk'
aws_api.config.accessKeyId     = process.env.HUBOT_AWS_ACCESS_KEY_ID
aws_api.config.secretAccessKey = process.env.HUBOT_AWS_SECRET_ACCESS_KEY
aws_api.config.region          = process.env.HUBOT_AWS_REGION

module.exports = new aws_api.EC2({apiVersion: '2014-10-01'})
