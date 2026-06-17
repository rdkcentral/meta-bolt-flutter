#!/bin/bash

if [ -n "${FIRST_TIME_INIT_LOG}" ]; then
    mkdir -p "$(dirname "${FIRST_TIME_INIT_LOG}")"
    # redirect stdout of current process to tee cmd
    exec > >(tee "${FIRST_TIME_INIT_LOG}") 2>&1
fi

echo "first_time_init: starting with root ${REPO_ROOT}"
sleep 5

if [ -z "${REPO_ROOT}" ] || [ ! -d "${REPO_ROOT}" ] || ! cd ${REPO_ROOT}; then
    echo "ERROR: REPO_ROOT is not set or does not exist: ${REPO_ROOT}"
    exec bash
fi

# need some global git config, otherwise repo refuses to cooperate
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

if [ -n "${INIT_CACHE_PATH}" ]; then
    mkdir -p "${INIT_CACHE_PATH}/sstate" "${INIT_CACHE_PATH}/downloads"
    export SSTATE_PATH="${INIT_CACHE_PATH}/sstate"
    export DOWNLOADS_PATH="${INIT_CACHE_PATH}/downloads"
fi

echo "first_time_init: running . setup-environment"
if . setup-environment; then
    echo "first_time_init: setup-environment finished."
else
    echo "ERROR: setup-environment failed with exit code $?"
    echo "Leaving the tmux shell open for debugging."
    exec bash
fi

cd "${REPO_ROOT}" || exec bash

echo "first_time_init: running ./devtools/scripts/initial_bolt_setup.sh"
if ./devtools/scripts/initial_bolt_setup.sh; then
    echo "first_time_init: initial Bolt setup finished."
else
    echo "ERROR: initial_bolt_setup.sh failed with exit code $?"
    echo "Leaving the tmux shell open for debugging."
    exec bash
fi

echo "first_time_init: complete."
sleep 5