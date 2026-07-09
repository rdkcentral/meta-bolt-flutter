#!/bin/bash
# env: REPO_ROOT,HOST_UID,HOST_GID,FLUTTER_PROJECT_SOURCE_CODE_PATH,FLUTTER_BOLT_NAME,STB_IP,FLUTTER_APPLICATION_RECIPE

export REPO_ROOT

cd "${REPO_ROOT}"

# need some git config, otherwise repo refuses to cooperate
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
# Disable color output to avoid interactive prompts from repo.
git config --global color.ui false

# Disable host key checks inside the container to avoid interactive SSH prompts.
! [ -d ~/.ssh ] && mkdir ~/.ssh
cat > ~/.ssh/config <<EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

. setup-environment

if [ -d "${REPO_ROOT}/build" ] && [ -f "${REPO_ROOT}/build/conf/local.conf" ]
then
    cd "${REPO_ROOT}/build"
    awk -f - conf/local.conf >conf/local.conf.updated <<EOF
/@START flutter-bolt-dev/    {DELETING="1"}
/@END flutter-bolt-dev/      {DELETING="0"}
!/@END flutter-bolt-dev/     {if (DELETING!="1") print}
EOF

    mv conf/local.conf.updated conf/local.conf

    # add new flutter-bolt-dev block; setup externalsrc for the current app
    cat >> conf/local.conf <<EOF
## @START flutter-bolt-dev
INHERIT += "externalsrc"
EXTERNALSRC:pn-${FLUTTER_APPLICATION_RECIPE} = "${FLUTTER_PROJECT_SOURCE_CODE_PATH}"
EXTERNALSRC_BUILD:pn-${FLUTTER_APPLICATION_RECIPE} = "${FLUTTER_PROJECT_SOURCE_CODE_PATH}/yocto_build"
## @END flutter-bolt-dev
EOF

fi

export FLUTTER_BOLT_CONFIG="$(jq -r '.config' < "${REPO_ROOT}/package-configs/${FLUTTER_BOLT_NAME}.bolt.json")"

ID="$(jq -r '.id' < "${REPO_ROOT}/package-configs/${FLUTTER_BOLT_CONFIG}")"
VER="$(jq -r '.version' < "${REPO_ROOT}/package-configs/${FLUTTER_BOLT_CONFIG}")"
export FLUTTER_OUTPUT_BOLT_NAME="${ID}+${VER}"

REMOVE_FROM_RM="RM_WORK_EXCLUDE:append = \" ${FLUTTER_APPLICATION_RECIPE} ${FLUTTER_APPLICATION_RECIPE}-bolt-image\""
if ! grep -q "${REMOVE_FROM_RM}" ${REPO_ROOT}/build/conf/local.conf; then
    echo -e "\n${REMOVE_FROM_RM}" >> ${REPO_ROOT}/build/conf/local.conf
fi