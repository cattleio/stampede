#!/usr/bin/python3

import socket
import os
import time

s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
e = os.getenv('NOTIFY_SOCKET')

print(e)

if e is not None:
    s.connect(e)
    s.sendall(bytes("READY=1", "UTF-8"))
    s.close()
    time.sleep(10)
