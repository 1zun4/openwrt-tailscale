#!/usr/bin/env bash

set -e

RELEASE="23.05.2"
VERSION="1.58.2"
PACKAGE="tailscale_${VERSION}-1_ARCH.ipk"

ARCHES=$(curl -s https://downloads.openwrt.org/releases/${RELEASE}/packages/ | grep -oP '(?<=href=")[^/]+(?=/")')

mkdir -p ./dist

for ARCH in $ARCHES; do
    {
        URL="https://downloads.openwrt.org/releases/${RELEASE}/packages/${ARCH}/packages/${PACKAGE//ARCH/${ARCH}}"
        echo "Downloading ${PACKAGE//ARCH/${ARCH}}"

        wget -q $URL -O ./dist/${PACKAGE//ARCH/${ARCH}} || true
    } &
done

wait

cd ./dist

for package in *.ipk; do
    STARTING_SIZE=$(du -sb ${package} | awk '{ print $1 }')

    echo "Patching ${package}"

    {
        mkdir ${package%%.ipk}
        pushd ${package%%.ipk}

        tar -xvf ../${package}

        mkdir data
        pushd data

        tar -xvf ../data.tar.gz
        echo -e '#!/bin/sh\ntrue\n' > usr/sbin/${package%%_*}
        tar --numeric-owner --group=0 --owner=0 -czf ../data.tar.gz *
        popd
        size=$(du -sb data | awk '{ print $1 }')
        rm -rf data

        mkdir control
        pushd control
        tar -xvf ../control.tar.gz
        sed -i "s/^Installed-Size.*/Installed-Size: ${size}/g" control
        tar --numeric-owner --group=0 --owner=0 -czf ../control.tar.gz *
        popd
        rm -rf control

        tar --numeric-owner --group=0 --owner=0 -cvzf ../${package} debian-binary data.tar.gz control.tar.gz
        popd

        rm -rf ${package%%.ipk}
    } > /dev/null

    FINAL_SIZE=$(du -sb ${package} | awk '{ print $1 }')
    echo "Patched ${package}, from ${STARTING_SIZE} to ${FINAL_SIZE} bytes"
done

# Clean up
find . ! -name '*.ipk' -delete
