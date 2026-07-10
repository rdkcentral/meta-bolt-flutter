#!/bin/bash

set -ev

if [ -z "${SSTATE_PATH}" ] || [ -z "${DOWNLOADS_PATH}" ]
then
    echo "Error: Missing cache environment."
    [ -z "${DOWNLOADS_PATH}" ] && echo "  Missing: DOWNLOADS_PATH"
    [ -z "${SSTATE_PATH}" ] && echo "  Missing: SSTATE_PATH"
    echo "Start first-time init with --downloads-path and --sstate-path, or with --init-cache-path."
    exit 1
fi

if [ -n "${DOWNLOADS_PATH}" ] && ! grep -q '^DL_DIR' "${REPO_ROOT}/build/conf/local.conf"
then
    echo DL_DIR=\"${DOWNLOADS_PATH}\" >> ${REPO_ROOT}/build/conf/local.conf
fi

if [ -n "${SSTATE_PATH}" ] && ! grep -q '^SSTATE_DIR' "${REPO_ROOT}/build/conf/local.conf"
then
    echo SSTATE_DIR=\"${SSTATE_PATH}\" >> ${REPO_ROOT}/build/conf/local.conf
fi

if ! [ -d ${REPO_ROOT}/build/bolts ]
then
    mkdir ${REPO_ROOT}/build/bolts
fi

cd ${REPO_ROOT}/build

if ! grep -q rm_work conf/local.conf
then
    if [ -z "${INIT_CACHE_PATH}" ]
    then
        echo 'INHERIT += "rm_work"' >> conf/local.conf
        echo RM_WORK_EXCLUDE:append:class-native = \" \${PN}\" >> conf/local.conf
        echo RM_WORK_EXCLUDE:append:class-nativesdk = \" \${PN}\" >> conf/local.conf
    fi
fi

if [ -n "${INIT_CACHE_PATH}" ] && ! grep -q '^INHERIT:remove = "rm_work"$' conf/local.conf
then
    echo 'INHERIT:remove = "rm_work"' >> conf/local.conf
fi

bitbake nodejs-native

bitbake bolt-env && hash bolt
bitbake base-bolt-image

# Add the meta-bolt package-config location so `bolt make base` can resolve it.
echo "${REPO_ROOT}/deps/bolt" >> ${REPO_ROOT}/build/conf/setup.done

cd ${REPO_ROOT}/build/bolts

bolt make base
bolt make flutter.runtime.flutter-auto.v3_38_3
bolt make flutter.runtime.flutter-auto-debug.v3_38_3
bolt make flutter.runtime.flutter-auto-profile.v3_38_3
