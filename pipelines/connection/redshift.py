import os

import boto3
import psycopg2

ssm = boto3.client('ssm')
env = os.environ['environment']
manyMappingList = ['db', 'bucketname']


# connection.makeConn(schema)
# connection.getParameters(platform,client,resource,['bucketName','roleArn'])
class connection:

    def __init__(self, platform="a2i", resource="redshift", client="axiom"):
        self._platform = platform
        self._resource = resource
        self._client = client

    def get_variables(self):
        return self._platform, self._resource, self._client

    def set_variables(self, platform, resource, client):
        self._platform = platform
        self._resource = resource
        self._client = client

    def ssmGetParameters(self, name):
        param = ssm.get_parameter(Name=name, WithDecryption=True)
        param_value = param['Parameter']['Value']
        return param_value

    def getParameters(self, parameterList):
        parameter_dict = {}
        platform, resource, client = self.get_variables()
        profileName = '/' + platform + '/' + 'env/' + env + '/profile'
        profile = self.ssmGetParameters(profileName)
        paramPrefix = '/' + platform + '/' + profile + '/' + resource

        for parameter in parameterList:
            if parameter in manyMappingList:
                path = paramPrefix + "/" + parameter + "/" + client
            else:
                path = paramPrefix + "/" + parameter
            parameter_dict[parameter] = self.ssmGetParameters(path)
        return parameter_dict

    def makeConn(self, schemaName):
        username = "batch_" + schemaName.lower()
        parameter_dict = self.getParameters(['db', 'port', 'host', 'users/'+username])
        conn = psycopg2.connect(dbname=parameter_dict['db'],
                                user=username,
                                password=parameter_dict['users/'+username],
                                port=parameter_dict['port'],
                                host=parameter_dict['host'])
        parameter_dict.clear()
        return conn