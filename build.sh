#!/bin/bash
set -e
set -o pipefail

cd $(dirname $0)

if [ -n "$BUILD_PREFIX" ]; then
    BUILD_PREFIX=${BUILD_PREFIX}/
fi

if [ -n "$CATTLE_SCRIPT_DEBUG" ] || echo "${@}" | grep -q -- --debug; then
    export CATTLE_SCRIPT_DEBUG=true
    export PS4='[${BASH_SOURCE##*/}:${LINENO}] '
    set -x
fi


IMAGES="$@"
DIST=${BUILD_PREFIX}dist
BUILD=${BUILD_PREFIX}build
BASE_DIR=$(pwd)

unit_file()
{
    cat ${BASE_DIR}/stampede-wrapper/service.template | sed \
        -e 's/CATTLE_VERSION=dev/CATTLE_VERSION='$CATTLE_VERSION'/g' \
        -e 's/CATTLE_LIBVIRT_VERSION=dev/CATTLE_LIBVIRT_VERSION='$CATTLE_LIBVIRT_VERSION'/g' \
        -e 's/STAMPEDE_VERSION=dev/STAMPEDE_VERSION='$STAMPEDE_VERSION'/g' \
        -e 's/%NAME%/'"$1"'/g'
}

source version

STAMPEDE_VERSION=$(echo $STAMPEDE_VERSION | sed 's/-SNAPSHOT/-SNAPSHOT-'$(uuidgen)'/g')

for i in $DIST $BUILD; do
    if [ -e $i ]; then
        rm -rf $i
    fi
    mkdir $i
done

if [ -z "$IMAGES" ]; then
    IMAGES=$(find stampede* -name stampede\* -type d -exec basename {} \; | sort -u)
fi

for i in $IMAGES; do
    cp -rp $i $BUILD/$i

    IMAGE=cattle/${i}:${STAMPEDE_VERSION}
    pushd $BUILD/$i

    if [ "$i" = "stampede" ]; then
        mkdir -p units
        unit_file "Stampede : Agent" > units/cattle-stampede-agent.MACHINE.service
        unit_file "Stampede : Libvirt" > units/cattle-libvirt.MACHINE.service
        unit_file "Stampede : Server" > units/cattle-stampede-server.MACHINE.service
    fi

    sed -i -e 's/:dev/:'$CATTLE_VERSION'/g' Dockerfile
    echo Building $IMAGE
    docker build -t $IMAGE . | sed 's!^!'$IMAGE' : !g'
    echo Done building $IMAGE

    popd
    echo $IMAGE >> $DIST/images
done

unit_file "Stampede : Manager" | sed '/X-ConditionMachineID/d' > $DIST/cattle-stampede.service

echo
echo '======================================================='
cat $DIST/cattle-stampede.service | grep 'Environment=' | sed 's/^[^=]*=/export /g'
cat $DIST/cattle-stampede.service | grep 'ExecStart=' | sed -e 's/^[^=]*=//g' -e 's/%n/cattle-stampede.service/'
echo '======================================================='
echo
echo Done: TAG $STAMPEDE_VERSION
