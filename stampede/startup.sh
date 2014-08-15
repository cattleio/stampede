#!/bin/bash
set -e

NS="nsenter --mount=/host/proc/1/ns/mnt --net=/host/proc/1/ns/net -F -- "
MANAGER=/var/lib/cattle/stampede/manager
PORT=${PORT:-8080}
ETCD_URL="http://$(ip route get 8.8.8.8 | grep via | awk '{print $3}'):4001/v2/keys"
MASTER_URL="${ETCD_URL}/cattle/stampede/master"
PUBLIC_MASTER_URL="${ETCD_URL}/cattle/stampede/master_public"

export REGISTRATION_URL="${ETCD_URL}/cattle/registration_url"

cd $(dirname $0)

if [ ! -e /host/proc/1 ]; then
    echo "Missing host proc"
    exit 1
fi

info()
{
    echo 'INFO :' "$@"
}

setup()
{
    SLEEP=0
    FIRST=true

    while sleep $SLEEP; do
        SLEEP=5
        MASTER="$(curl -s $MASTER_URL | jq -r .node.value)"
        PUBLIC_MASTER="$(curl -s $PUBLIC_MASTER_URL | jq -r .node.value)"

        if [[ -z "$MASTER" || "$MASTER" = "null" || -z "${PUBLIC_MASTER_URL}" || "${PUBLIC_MASTER_URL}" = "null" ]]; then
            info "Waiting for master, Docker images are probably still pulling"
            continue
        fi

        if [ "$(curl -s http://${MASTER}:${PORT}/ping)" != "pong" ]; then
            info Waiting for http://${MASTER}:${PORT}/ping
            continue
        fi
         
        export CATTLE_URL=http://${MASTER}:${PORT}
        ./stampede_config.py || continue
        SLEEP=900

        if [ "$FIRST" = "true" ]; then
            FIRST=false
            if [ -n "$PUBLIC_MASTER" ]; then
                info Stampede is now ready at http://${PUBLIC_MASTER}:${PORT}
            else
                info Stampede is now ready at $CATTLE_URL
            fi
        fi
    done
}

run()
{
    $NS mkdir -p $MANAGER
    tar cf - run.sh units | $NS tar xvf - -C $MANAGER | xargs -I{} echo INFO : Installing $MANAGER/'{}'
    info Running $MANAGER/run.sh
    exec $NS $MANAGER/run.sh
}

setup &
run
