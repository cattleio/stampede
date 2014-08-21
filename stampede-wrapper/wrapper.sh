#/bin/bash
set -e

########################################################################
# WARNING:                                                             #
#   On a scale of 1 to 10, we're at 11 in terms of hacks in this file. #
#   You might live a happier life never knowing what really goes on in #
#   this file.  You've been warned.                                    #
########################################################################

COMMON_ARGS="--privileged -e CATTLE_SCRIPT_DEBUG=${CATTLE_SCRIPT_DEBUG}"
SERVICE=$ARGS
STAMPEDE_PORT=${STAMPEDE_PORT:-8080}
STAMPEDE_VERSION=${STAMPEDE_VERSION:-dev}
CATTLE_VERSION=${CATTLE_VERSION:-dev}

DOCKER_ARGS=
IMAGE=
PIDFILE=
HOST_MNTS=

if [ -n "$CATTLE_SCRIPT_DEBUG" ] || echo "${@}" | grep -q -- --debug; then
    export CATTLE_SCRIPT_DEBUG=true
    export PS4='[${BASH_SOURCE##*/}:${LINENO}] '
    set -x
fi

info()
{
    echo "INFO : $@"
}

pull()
{
    if docker inspect $1 >/dev/null 2>&1; then
        return 0
    fi

    info "Pulling $1"
    docker pull $1
    info "Done pulling $1"
}

notify()
{
    TEXT=$1
    PROP=$2
    CHECK_VALUE=$3

    if [ "$NOTIFY_SOCKET" = "" ]; then
        return 0
    fi

    while true; do
        echo "$TEXT" | ncat -u -U $NOTIFY_SOCKET
        if [ "$(systemctl show -p $PROP $SERVICE)" = "${PROP}=${CHECK_VALUE}" ]; then
            break
        else
            sleep 1
        fi
    done
}

ready()
{
    if [ -n "$MAINPID" ] && [ ! -e /proc/$MAINPID ]; then
        mainpid $$
    fi

    notify "READY=1" SubState running

    # Catch situation in which docker logs is polling a stopped containers
    # and holding open the cgroup
    if [ -n "$LOG_PID" ] && [ -n "$MAINPID" ]; then
        for i in {1..10}; do
            if [ ! -e /proc/$LOG_PID ]; then
                break
            fi

            if [ ! -e /proc/$MAINPID ]; then
                kill $LOG_PID 2>/dev/null || true
                break
            fi

            sleep 1
        done
    fi
}

mainpid()
{
    notify "MAINPID=$1" MainPID $1
    MAINPID=$1
}

setup_ips()
{
    if [ -e /etc/environment ]; then
        source /etc/environment
    fi

    PUBLIC_IP=$COREOS_PUBLIC_IPV4
    PRIVATE_IP=$COREOS_PRIVATE_IPV4

    if [ -n "${STAMPEDE_PRIVATE_IP}" ]; then
        PRIVATE_IP=${STAMPEDE_PRIVATE_IP}
    fi

    if [ -n "${STAMPEDE_PUBLIC_IP}" ]; then
        PUBLIC_IP=${STAMPEDE_PUBLIC_IP}
    fi

    if [ -z "$PRIVATE_IP" ]; then
        PRIVATE_IP="$(ip route get 8.8.8.8 | grep via | awk '{print $7}')"
    fi

    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=${PRIVATE_IP}
    fi
}

getpid()
{
    if [ -e $PIDFILE ]; then
        cat $PIDFILE
    fi
}

run_foreground()
{
    docker run "$@" | bash &
    for i in {1..10}; do
        PID=$(getpid)
        if [ -n "$PID" ] && [ "$PID" != "0" ]; then
            break
        fi
        PID=
        sleep 1
    done

    if [ -z "$PID" ]; then
        exit 1
    fi
}

run_background()
{
    PIDFILE=/var/run/${NAME}.pid

    if [ -e ${PIDFILE} ]; then
        rm -f ${PIDFILE}
    fi

    /opt/bin/systemd-docker ${SYSTEMD_ARGS} --pid-file=${PIDFILE} run --rm "$@" &

    for i in {1..10}; do
        if [ ! -e $PIDFILE ]; then
            sleep 1
        else
            exit 0
        fi
    done

    exit 1
}

run()
{
    if [ -z "$PIDFILE" ]; then
        run_background "$@"
    else
        if docker inspect $NAME >/dev/null 2>&1; then
            docker rm -f $NAME
        fi

        run_foreground "$@"

        mainpid $PID
        ready
    fi
}

setup_hostmnts()
{
    for MNT in $HOST_MNTS; do
        if [ ! -e $MNT ]; then
            mkdir -p $MNT
        fi
        COMMON_ARGS="${COMMON_ARGS} -v ${MNT}:/host${MNT}"
    done
}

setup_args()
{
    TAG=${STAMPEDE_VERSION}
    NAME=$(echo $1 | cut -f1 -d.)

    case $NAME in
    cattle-stampede-agent)
        HOST_MNTS="/lib/modules /proc /run /var/lib/docker /var/lib/cattle /opt/bin"
        DOCKER_ARGS="-e CATTLE_EXEC_AGENT=true -e CATTLE_ETCD_REGISTRATION=true -e CATTLE_AGENT_IP=${PUBLIC_IP} -e CATTLE_LIBVIRT_REQUIRED=true"
        ;;
    cattle-libvirt)
        TAG=${CATTLE_LIBVIRT_VERSION}
        HOST_MNTS="/lib/modules /proc /run /var/lib/docker /var/lib/cattle"
        PIDFILE=/run/cattle/libvirt/libvirtd.pid
        ;;
    cattle-stampede-server)
        SYSTEMD_ARGS="--notify"
        DOCKER_ARGS="-i -v /var/lib/cattle:/var/lib/cattle -e PORT=${STAMPEDE_PORT} -p ${STAMPEDE_PORT}:8080 -e PRIVATE_MACHINE_IP=${PRIVATE_IP} -e PUBLIC_MACHINE_IP=${PUBLIC_IP} -e CATTLE_AGENT_INSTANCE_IMAGE_TAG=${CATTLE_AGENT_INSTANCE_IMAGE_TAG}"
        ;;
    cattle-stampede)
        HOST_MNTS="/proc"
        DOCKER_ARGS="-e PORT=${STAMPEDE_PORT}"
        ;;
    *)
        echo "Invalid unit name $1"
        exit 1
        ;;
    esac

    IMAGE="$(echo $NAME | sed 's!cattle-!cattle/!'):${TAG}"
}

setup_ips
setup_args $SERVICE
setup_hostmnts

pull cattle/agent-instance:${CATTLE_VERSION}
pull $IMAGE

run $COMMON_ARGS --name $NAME $DOCKER_ARGS $IMAGE
