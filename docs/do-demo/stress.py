from multiprocessing import Queue, Process
#from Queue import Queue
#from threading import Thread as Process
from cattle import from_env
import time


URL = 'http://mgmt1:8080/v1/schemas'
queue = Queue()
client = from_env(url=URL)
start = time.time()


def progress():
    done_count = 0
    error_count = 0

    while True:
        id = queue.get()
        if id is None:
            break

        c = client.by_id_container(id)
        c = client.wait_transitioning(c, timeout=10000)
        if c.state == 'running':
            print (c.firstRunningTS - c.createdTS)/1000, c.id, c.hosts()[0].name
            done_count += 1
        else:
            error_count += 1

        print time.time(), 'Done:', done_count, 'Error:',\
            error_count, 'Queue:', queue.qsize()

    print 'Total', (time.time() - start)


def run(count=50000, batch=1, interval=1.000):
    client = from_env(url=URL)
    unmanaged_network = client.list_network(uuid='unmanaged')[0]
    #network = client.list_network(uuid='managed-docker0')[0]

    remaining = count
    while remaining > 0:
        start = time.time()
        current_batch = min(batch, remaining)

        try:
            cs = client.create_container(imageUuid='docker:ibuildthecloud/helloworld',
                                         count=current_batch,
                                         networkIds=[unmanaged_network.id],
                                         #networkIds=[network.id],
                                         instanceTriggeredStop='restart',
                                         command='sleep 1000000')

            if cs.type == 'collection':
                for c in cs:
                    print 'Created', remaining, c.id, c.uuid
                    queue.put(c.id)
            else:
                print 'Created', remaining, cs.id, cs.uuid
                queue.put(cs.id)
        except Exception, e:
            print e

        remaining -= current_batch

        wait = interval - (time.time() - start)
        if wait > 0:
            print 'Sleep', wait
            time.sleep(wait)
        else:
            print 'Fall behind', wait

    queue.put(None)


Process(target=progress).start()
Process(target=run).start()
