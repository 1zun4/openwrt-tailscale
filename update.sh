#!/usr/bin/env bash

set -e

RELEASE="24.10.0"
VERSION="1.80.3" # tailscale_1.80.3-r1_arm_cortex-a7_neon-vfpv4.ipk
PACKAGE="tailscale_${VERSION}-r1_ARCH.ipk"

ARCHES=$(curl -s https://downloads.openwrt.org/releases/${RELEASE}/packages/ | grep -oP '(?<=href=")[^/]+(?=/")')

mkdir -p ./dist

for ARCH in $ARCHES; do
    {
        (
            PACKAGE_NAME=${PACKAGE//ARCH/${ARCH}}
            echo "Downloading ${PACKAGE_NAME}"

            curl -f -s \
                -o ./dist/${PACKAGE_NAME} \
                --header 'X-GitHub: github.com/du-cki/openwrt-tailscale' \
                "https://downloads.openwrt.org/releases/${RELEASE}/packages/${ARCH}/packages/${PACKAGE_NAME}" > /dev/null
        ) || true
    } &
done

wait # waits for all subshells (downloads) to finish

if [ ! -f ./dist/*.ipk ]; then
    echo "Failed to download any packages"
    exit 1
fi

cd ./dist

for package in *.ipk; do
    STARTING_SIZE=$(du -sb ${package} | awk '{ print $1 }')

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

find . ! -name '*.ipk' -delete # Clean up
