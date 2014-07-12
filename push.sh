#!/bin/bash

cd $(dirname $0)

if [ ! -e dist/images ]; then
    ./build.sh
fi

for i in $(<dist/images); do
    docker push $i
done

for i in $(<dist/images); do
    echo Pushed $i
done
