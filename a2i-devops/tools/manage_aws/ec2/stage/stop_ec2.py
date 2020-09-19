import boto3

# define the connection
session = boto3.Session(profile_name='stage')
ec2 = session.resource('ec2')

#Use the filter() method of the instances collection to retrieve all running EC2 instances with tag office-hours-instance.
instances = ec2.instances.filter(
  Filters = [{
      'Name': 'tag:office-hours-instance',
      'Values': ['true']
    },
    {
      'Name': 'instance-state-name',
      'Values': ['running']
    }
  ])

RunningInstances = []
for instance in instances:
  # for each instance, append to array instance id
  RunningInstances.append(instance.id)

if len(RunningInstances) > 0:

  #Print running instances separated by comas
  print ("Running instances are ", end='')
  print(', '.join(RunningInstances))

  #perform the shutdown
  ec2.instances.filter(InstanceIds=RunningInstances).stop()
  print ("Stopped")
else:
  print ("No instances to shutdown.")
