#!/bin/bash

for i in $(tugboat droplets | grep node | awk '{print $NF}' | sed 's/)//g'); do
    echo tugboat destroy -c -i $i
done
