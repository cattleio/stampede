#!/bin/bash
set -e

trap "exit 2" SIGINT SIGTERM

cd $(dirname $0)

CURRENT_MACHINES=
COUNT=0
RUN_ID=$(uuidgen)
LOCK_DIR=/keys/_stampede/locks
ETCD_URL="http://$(ip route get 8.8.8.8 | grep via | awk '{print $7}'):4001/v2"

error()
{
    echo "ERROR:" "$@" 1>&2
}

info()
{
    echo "INFO :" "$@" 1>&2
}

debug()
{
    if [ -n "$DEBUG" ]; then
        echo "DEBUG :" "$@" 1>&2
    fi
}

do_sleep()
{
    if [ -z "$FIRST_SLEEP" ]; then
        FIRST_SLEEP=true
        return
    fi

    COUNT=$((COUNT+1))
    sleep 1
}

every()
{
    if [[ $(($COUNT % $1)) == 0 ]]; then
        return 0
    fi
    return 1
}

put()
{
    curl -s --fail -L -XPUT ${ETCD_URL}"$@"
}

get()
{
    curl -s --fail -L ${ETCD_URL}"$@"
}

delete()
{
    curl -s --fail -L -XDELETE ${ETCD_URL}"$@"
}

touch_locks()
{
    while sleep 2; do
        if [ ! -e /proc/$$ ]; then
            exit
        fi

        for lock in locks/*; do
            local lock_id=${lock##locks/}

            if [[ -e $lock && "$(cat $lock 2>/dev/null)" == $RUN_ID ]]; then
                debug Updating lock $lock_id
                put ${LOCK_DIR}/${lock_id}'?prevExists=true&prevValue='$RUN_ID -d value=$RUN_ID -d ttl=5 >/dev/null || info "Didn't update" $lock_id
            fi
        done
    done
}

do_lock()
{
    if ! put ${LOCK_DIR}/${1}'?prevExist=false' -d value=$RUN_ID -d ttl=5 > /dev/null; then
        return 1
    fi
    mkdir -p locks
    echo $RUN_ID > locks/$1
    debug Locked $1
}

do_unlock()
{
    if [[ -e locks/$1 && "$(<locks/$1)" == $RUN_ID ]]; then
        rm locks/$1
    fi

    if ! delete ${LOCK_DIR}/${1}'?prevValue='$RUN_ID >/dev/null; then
        error Failed to unlock $1
        return 0
    fi

    debug Unlocked $1
}

lock()
{
    local lock=$1

    if [ "$#" -gt 1 ]; then
        shift 1
    fi

    do_lock $lock || return 0
    local exit=0
    eval "$@" || exit=$?
    do_unlock $lock

    if [ "$exit" != 0 ]; then
        error "FAILED:" "$@"
    fi

    return $exit
}


check_fleet()
{
    if [ "$(machines | wc -l)" == 0 ]; then
        error 'Fleet/Etcd is not running'
        exit 1
    fi
}

machines()
{
    fleetctl list-machines --no-legend -l --fields=machine
}

install_units_on_machine()
{
    local machine=$1
    local unit_file=units/$2
    local md5=$(md5sum $unit_file | awk '{print $1}')
    local unit_name=$(echo $2 | sed 's/MACHINE/'${machine:0:6}${md5:0:6}'/')
    local short_name=$(echo $2 | sed 's/.MACHINE.*//'g)
    local output=installed-units/$unit_name
    local found=false
    local existing

    mkdir -p $(dirname $output)
    cat $unit_file | sed 's/%MACHINE%/'$machine'/g' > $output

    for existing in $(fleetctl list-units --fields unit,machine -l --no-legend | grep $machine | awk '{print $1}' | grep '^'"$short_name"); do
        info Existing $existing for $machine
        if [ "$existing" = "$unit_name" ]; then
            found=true
        else
            info Removing existing $existing from $machine
            fleetctl stop $existing
            fleetctl destroy $existing
        fi
    done

    if [ "$found" = "false" ]; then
        info Installing/Starting unit $unit_name on $machine
    fi

    fleetctl start $output
}

install_units()
{
    local machine
    local unit
    local units=$(cd units; ls -1)

    for machine in $MACHINES; do
        for unit in $units; do
            install_units_on_machine $machine $unit
        done
    done
}

check_units()
{
    MACHINES=$(machines)

    if [ "$CURRENT_MACHINES" != "$MACHINES" ]; then
        install_units
        CURRENT_MACHINES="$MACHINES"
    fi
}

check_fleet
touch_locks $$ &

while do_sleep; do
    every 5 && {
        lock check_units
    }
done
