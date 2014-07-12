#!/bin/bash

NAME=$(basename $0)
TARGET=$(basename "$(readlink $0)")
PID=

get_pid()
{
    PID=$(docker inspect --format '{{.State.Pid}}' $1)

    if [ -z "$PID" ]; then
        echo Container $1 is not running
        exit 1
    fi
}

enter()
{
    exec sudo nsenter -m -u -i -n -p -t $PID -- "$@"
}

call()
{
    exec sudo nsenter -m -t $PID -- $NAME "$@"
}

if [ "$NAME" = "bootstrap.sh" ]; then
    echo Do not invoke $0 directly
    exit 1
fi

if [ "$TARGET" = "bootstrap.sh" ]; then
    get_pid $NAME
    enter "$@"
else
    get_pid $TARGET
    call "$@"
fi
