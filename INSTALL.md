# Installation instructions

This is intended to run as a plugin in our instance of hubot: https://github.com/cfpb/CFPBot

This module will be included in `package.json` and `external-scripts.json`

## Configuration

### ec2.json

Create an ec2.json file and put it in your `CFPBot` directory:

```
{
  "MinCount": 1,
  "MaxCount": 1,
  "DryRun": false,
  "ImageId": "ami-ask-for-it",
  "KeyName": "ask-for-it",
  "InstanceType": "ask-for-it",
  "Placement": {
    "AvailabilityZone": "ask-for-it"
  },
  "NetworkInterfaces": [
    {
      "Groups": [
        "sg-ask-for-it"
      ],
      "SubnetId": "subnet-ask-for-it",
      "DeviceIndex": 0,
      "AssociatePublicIpAddress": false
    }
  ]
}

```

### Environment variables

Add these to your `.env` file and source it prior to running the bot:

```
export HUBOT_AWS_REGION="us-east-1"
export HUBOT_AWS_EC2_RUN_CONFIG="ec2.json"
export HUBOT_AWS_CAN_ACCESS_ROLE="ec2"
export HUBOT_AUTH_ADMIN="1"
export HUBOT_AWS_DEFAULT_CREATOR_EMAIL="ask-for-it"
export HUBOT_AWS_ACCESS_KEY_ID="ask-for-it"
export HUBOT_AWS_SECRET_ACCESS_KEY="ask-for-it"

export HUBOT_AWS_EC2_RUN_USERDATA_PATH=ec2-user-data.txt

```

### user-data

If you have static user-data to add at instance launch, include it in `ec2-user-data.txt` in your CFPBot directory

```
#!/bin/bash

echo "Adding public keys..."

echo "ssh-rsa and so on and so forth" >> /home/some-user/.ssh/authorized_keys

```