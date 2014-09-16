#!/usr/bin/env python

import cattle
import sys

ZK_NODES = 3
REDIS_NODES = 3
API_SERVER_NODES = 3
PROCESS_SERVER_NODES = 3
AGENT_SERVER_NODES = 3
MYSQL_COMPUTE = 1
# Set if you want to override the cattle.jar in the Docker image with a custom one
URL = ''
TAG = 'latest'

client = cattle.from_env()

def wait(c):
    return client.wait_success(c, timeout=120)

deleted = []
for c in client.list_container(removed_null=True):

    if c.name != 'Agent':
        client.delete(c)
        print 'Deleting', c.name
        deleted.append(c)

print 'Waiting for deleting'
for c in deleted:
    wait(c)
print 'Done'



def set_link(instance, name, target):
    instance = wait(instance)

    for link in instance.instanceLinks():
        if link.linkName == name:
            print 'Linking {} to {}'.format(instance.name, target.name)
            wait(client.update(link, targetInstanceId=target.id))


def deploy_zk():
    # Deploying ZK is complicated....
    # Create dummy ZK to link against, then we will create the circle
    # We want it to be stopped so that ZooKeeper doesn't actually connect
    print 'Creating Dummy ZK node'
    zk_dummy = wait(client.create_container(imageUuid='docker:ibuildthecloud/zookeeper',
                                            name='zk_dummy'))
    zk_dummy = wait(zk_dummy.stop())
    zks = []

    for i in range(1, ZK_NODES + 1):
        links = {}
        for j in range(1, ZK_NODES + 1):
            if j != i:
                links['zk{}'.format(j)] = zk_dummy.id


        zk = client.create_container(imageUuid='docker:ibuildthecloud/zookeeper',
                                     name='zk{}'.format(i),
                                     environment={
                                         'ID': i
                                     },
                                     instanceTriggeredStop='restart',
                                     instanceLinks=links)
        print 'Created', zk.name
        zks.append(wait(zk))

    for zk_target in zks:
        for zk in zks:
            set_link(zk, zk_target.name, zk_target)

    client.delete(zk_dummy)

    return zks


def deploy_redis():
    print 'Create Redis'
    redises = []
    for i in range(1, REDIS_NODES + 1):
        redis = client.create_container(imageUuid='docker:ibuildthecloud/redis',
                                        instanceTriggeredStop='restart',
                                        name='redis{}'.format(i))
        print 'Created', redis.name
        redises.append(redis)

    return redises

def haproxy(targets, name, listen_port):
    links = {}
    for i, c in enumerate(targets):
        links['TARGET{}'.format(i)] = wait(c).id

    return client.create_container(imageUuid='docker:ibuildthecloud/haproxy',
                                   instanceLinks=links,
                                   instanceTriggeredStop='restart',
                                   name=name,
                                   ports=['{}:80'.format(listen_port)])


zookeepers = deploy_zk()
redises = deploy_redis()

mysql = client.create_container(imageUuid='docker:ibuildthecloud/mysql',
                                compute=MYSQL_COMPUTE,
                                instanceTriggeredStop='restart',
                                ports=['9082:80'],
                                name='mysql')
print 'Created', mysql.name

graphite = client.create_container(imageUuid='docker:ibuildthecloud/graphite',
                                   instanceTriggeredStop='restart',
                                   ports=['9083:80'],
                                   name='graphite')
print 'Created', graphite.name

es = client.create_container(imageUuid='docker:ibuildthecloud/logstash',
                             instanceTriggeredStop='restart',
                             ports=['9200:9200'],
                             name='logstash/elasticache')
print 'Created', es.name

kibana = client.create_container(imageUuid='docker:ibuildthecloud/kibana',
                                 name='Kibana',
                                 instanceTriggeredStop='restart',
                                 ports=['9081:80'],
                                 environment={
                                     'ES_PORT_9200_TCP_ADDR': wait(es).hosts()[0].ipAddresses()[0].address,
                                     'ES_PORT_9200_TCP_PORT': '9200'
                                 })
print 'Created', kibana.name

print 'Create Cattle'
links = {
    'gelf': wait(es).id,
    'graphite': wait(graphite).id
}

instances = []
instances.extend(zookeepers)
instances.extend(redises)
instances.append(mysql)

for c in instances:
    links[c.name] = wait(c).id

api_servers = []
agent_servers = []

for i in range(1, API_SERVER_NODES + 1):
    c = client.create_container(imageUuid='docker:cattle/api-server:{}'.format(TAG),
                                name='API Server {}'.format(i),
                                environment={
                                    'URL': URL,
                                    'CATTLE_CATTLE_SERVER_ID': 'apiserver{}'.format(i)
                                },
                                instanceTriggeredStop='restart',
                                instanceLinks=links)
    print 'Created', c.name
    api_servers.append(c)

for i in range(1, PROCESS_SERVER_NODES + 1):
    c = client.create_container(imageUuid='docker:cattle/process-server:{}'.format(TAG),
                                name='Process Server {}'.format(i),
                                environment={
                                    'URL': URL,
                                    'CATTLE_JAVA_OPTS': '-Xmx1024m',
                                    'CATTLE_CATTLE_SERVER_ID': 'processserver{}'.format(i)
                                },
                                instanceTriggeredStop='restart',
                                instanceLinks=links)
    print 'Created', c.name

for i in range(1, AGENT_SERVER_NODES + 1):
    c = client.create_container(imageUuid='docker:cattle/agent-server:{}'.format(TAG),
                                name='Agent Server {}'.format(i),
                                environment={
                                    'URL': URL,
                                    'CATTLE_JAVA_OPTS': '-Xmx1024m',
                                    'CATTLE_CATTLE_SERVER_ID': 'agentserver{}'.format(i)
                                },
                                instanceTriggeredStop='restart',
                                instanceLinks=links)
    print 'Created', c.name
    agent_servers.append(c)


h1 = haproxy(api_servers, 'Api Servers Load Balancer', 8080)
print 'Created', h1.name

h2 = haproxy(agent_servers, 'Agent Servers Load Balancer', 8081)
print 'Created', h2.name

wait(h1)
wait(h2)
