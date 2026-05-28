#!/bin/bash

set -ev

# REPO_ROOT,HOST_UID,HOST_GID,FLUTTER_PROJECT_SOURCE_CODE_PATH,FLUTTER_BOLT_NAME,STB_IP,FLUTTER_APPLICATION_RECIPE
cd ${REPO_ROOT}/build

if ! grep "EXTERNALSRC:pn-${FLUTTER_APPLICATION_RECIPE}" conf/local.conf >/dev/null
then
cat >> conf/local.conf <<EOF
INHERIT += "externalsrc"
EXTERNALSRC:pn-${FLUTTER_APPLICATION_RECIPE} = "/home/tomasz.karczewski/copilot/flutter-wonderous-app"
EXTERNALSRC_BUILD:pn-${FLUTTER_APPLICATION_RECIPE} = "/home/tomasz.karczewski/copilot/flutter-wonderous-app/yocto_build"
PUBSPEC_IGNORE_LOCKFILE:pn-${FLUTTER_APPLICATION_RECIPE} = "0"
FLUTTER_APP_RUNTIME_MODES:pn-${FLUTTER_APPLICATION_RECIPE} = "debug"
EOF
fi

if ! [ -d ${REPO_ROOT}/bolts ]
then
    mkdir ${REPO_ROOT}/bolts
fi

cd ${REPO_ROOT}/build

bitbake bolt-env && hash bolt
bitbake base-bolt-image
bitbake flutter-auto-3-38-3-runtime-bolt-image

# to make base bolt, need to give path to *meta-bolt* package-config
echo "${REPO_ROOT}/deps/bolt" >> ${REPO_ROOT}/conf/setup.done

cd ${REPO_ROOT}/bolts

bolt make base
bolt make flutter.runtime.flutter-auto.v3_38_3

bolt make ${FLUTTER_BOLT_NAME}
