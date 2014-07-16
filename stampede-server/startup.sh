#!/bin/bash
set -e

trap "exit 1" SIGINT SIGTERM

cd $(dirname $0)

PORT=${PORT:-8080}
MASTER_KEY=/keys/cattle/stampede/master
PUBLIC_MASTER_KEY=/keys/cattle/stampede/master_public
REGISTRATION_KEY=/keys/cattle/registration_url
ETCD_URL="http://$(ip route get 8.8.8.8 | grep via | awk '{print $3}'):4001/v2"

put()
{
    curl -s --fail -L -XPUT ${ETCD_URL}"$@"
}

get()
{
    curl -s --fail -L ${ETCD_URL}"$@"
}

get_master()
{
    get ${MASTER_KEY}'?consistent=true' | jq -r .node.value
}

set_master()
{
    put ${MASTER_KEY}'?prevExist=false' -d value=${PRIVATE_MACHINE_IP} > /dev/null
}

set_master_public_ip()
{
    put ${PUBLIC_MASTER_KEY} -d value=$PUBLIC_MACHINE_IP
}

run_master()
{
    set_master_public_ip
    exec /usr/share/cattle/cattle.sh --notify /done.sh --notify-error /error.sh
}

run_not_master()
{
    iptables -t nat -I PREROUTING -i eth0 -p tcp --dport 8080 -j DNAT --to ${MASTER}:${PORT}
    iptables -t nat -I POSTROUTING -o eth0 -p tcp --dport $PORT -d ${MASTER} -j MASQUERADE

    /notify.py >/tmp/cattle-success 2>&1

    while true; do
        sleep 5
    done
}

if [ -z "${PRIVATE_MACHINE_IP}" ] || [ -z "${PUBLIC_MACHINE_IP}" ]; then
    echo "Failed to determine host IP, please ensure PUBLIC_MACHINE_IP and PRIVATE_MACHINE_IP are set"
    exit 1
fi

if [ "$(get_master)" != "${PRIVATE_MACHINE_IP}" ]; then
    set_master || true
fi

MASTER="$(get_master)"

echo "Master" $MASTER
echo "Public IP" ${PUBLIC_MACHINE_IP}
echo "Private IP" ${PRIVATE_MACHINE_IP}

if [ -z "$MASTER" ]; then
    echo "Failed to determine master"
    exit 1
fi

if [ -z "${PRIVATE_MACHINE_IP}" ]; then
    echo "Failed to determine local machine IP"
    exit 1
fi

if [ "$MASTER" = "${PRIVATE_MACHINE_IP}" ]; then
    run_master
else
    run_not_master
fi
