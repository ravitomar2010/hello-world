import boto3

# define the connection
session = boto3.Session(profile_name='stage')
ec2 = session.resource('ec2')

#Use the filter() method of the instances collection to retrieve all stopped EC2 instances with tag office-hours-instance.
Instances = ec2.instances.filter(
  Filters = [{
      'Name': 'tag:office-hours-instance',
      'Values': ['true']
    },
    {
      'Name': 'instance-state-name',
      'Values': ['stopped']
    }
  ])

StoppedInstances = []
for instance in Instances:
  # for each instance, append to array instance id
  StoppedInstances.append(instance.id)

if len(StoppedInstances) > 0:

  #Print stopped instances separated by comas
  print ("Stopped instances are ", end='')
  print(', '.join(StoppedInstances))

  # perform the start
  ec2.instances.filter(InstanceIds=StoppedInstances).start()
  print ("Started")
else:
  print ("No instances to start.")
