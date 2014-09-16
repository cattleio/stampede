#!/bin/bash

config()
{
    if [ -e $1 ]; then
        return
    fi

    echo 'Creating:' $1

    NETWORK=private
    if [ -n "$2" ]; then
        NETWORK=$2
    fi
        

    cat > $1 << EOF
#cloud-config
coreos:
    units:
      - name: etcd.service
        command: start
      - name: fleet.service
        command: start
    etcd:
        discovery: $(curl -sL https://discovery.etcd.io/new)
        addr: \$${NETWORK}_ipv4:4001
        peer-addr: \$${NETWORK}_ipv4:7001
EOF
}

deploy()
{
    REGION=$1
    SIZE=$2
    NAME=$3
    CLOUD_CONFIG=$4
    curl -s --request POST "https://api.digitalocean.com/v2/droplets" \
         --header "Content-Type: application/json" \
         --header "Authorization: Bearer $TOKEN" \
         --data '{"region":"'"${REGION}"'",
             "image":"coreos-alpha",
             "size":"'"$SIZE"'",
             "user_data": "'"$(cat ${CLOUD_CONFIG})"'",
             "ssh_keys":["'"$SSH_KEY_ID"'"],
             "private_networking":true,
             "name":"'$NAME'"}' | jq -r '"Created id: \(.droplet.id) \(.droplet.name)"'
}

if [[ -z "$TOKEN" || -z "$SSH_KEY_ID" ]]; then
    echo TOKEN and SSH_KEY_ID env variables must be set 1>&2
    exit 1
fi

if [ ! -x "$(which jq)" ]; then
    echo "Sorry, you need jq for this" 1>&2
    exit 1
fi

config cloud-config-mgmt.yaml
config cloud-config-nyc3.yaml
config cloud-config-sfo1.yaml public

for i in {1..3}; do
    deploy nyc3 16gb mgmt$i cloud-config-mgmt.yaml
done

for i in {1..105}; do
    # NYC3 2GB
    deploy nyc3 2gb nyc3-node$i cloud-config-nyc3.yaml
    # SFO1 2GB
    deploy sfo1 2gb sfo1-node$i cloud-config-sfo1.yaml
done
