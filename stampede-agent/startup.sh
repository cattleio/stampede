#!/bin/bash

mkdir -p /host/opt/bin
mkdir -p /host/var/lib/cattle/stampede/scripts

tar cf - -C /files/opt . | tar xf - -C /host/opt/bin
tar cf - -C /files/home . | tar xf - -C /host/var/lib/cattle/stampede/scripts

exec /agent-env.sh
