
# hubot-aws-cfpb

This is a Hubot plugin. 
We use this module for running a small subset of AWS ec2 commands via chat. 

## Credit & divergence

This project was originally a fork of https://github.com/yoheimuta/hubot-aws. 
We removed significant functionality from the original application, diverged in the command format, and added, removed, 
and enhanced the commands for our specific purposes. 

## Contributing

These changes are quite specific to our usage and highly unlikely to be reusable.

More generic, reusable contributions should be made to https://github.com/yoheimuta/hubot-aws, not here.

Contributions specific to our usage can be made here. See [CONTRIBUTING](CONTRIBUTING.md)

## Configuration

See [INSTALL](INSTALL.md)

## Commands

### List Instances

#### Chat and my Instances
```
cfpbot ec2 [mine|chat]
```
This command will list the instances created by chat bot. 
* mine - will list all instances you have created
* chat - will list all instances that the chat bot has created.

#### Filter instances
```
cfpbot ec2 filter [search_text]
```
This command will show all instances that have the 'search_text' in the name.

### Creating, Stopping & Extending

#### Create Instances
```ruby
cfpbot ec2 run [name] [desc] 
```
This command will create a new ec2-instance. 
* name - The tag name that will be given to this ec2 instance.
* desc - The tag desc that will be given to this ec2 instance

#### Stop Instances
```ruby
cfpbot ec2 stop --instance_id=[instance_id]
```
This command will stop, not terminate, an ec2-instance of a given id. It will only allow you to stop instances that you created. 
* instance_id - The instance id of the ec2 instance which you can get from the `List Instances` commands.

#### Resume Instances
```ruby
cfpbot ec2 start [instance_id]
```
This command will start an ec2-instance of a given id. 
* instance_id - The instance id of the ec2 instance which you can get from the `List Instances` commands.

#### Extend an Instance's Expiration Date
```ruby
cfpbot ec2 extend [instance_id]
```
This command will add two weeks to the expiration date of an ec2-instance created by cfpbot.
* instance_id - The instance id of the ec2 instance which you can get from the `List Instances` commands.



