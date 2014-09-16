#!/bin/bash

for i in $(tugboat droplets | grep node | awk '{print $3}' | sed 's/,//'); do
    ping -c 1 $i >/dev/null || echo Bad $i
done
