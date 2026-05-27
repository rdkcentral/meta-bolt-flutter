#!/bin/bash
echo tmux_init: starting with root ${REPO_ROOT}
sleep 5
if [ -f "${REPO_ROOT}/devtools/setup_flutter_bolt_dev_container.sh" ]; then
    echo "Found setup script. Executing..."
    source "${REPO_ROOT}/devtools/setup_flutter_bolt_dev_container.sh"
    echo "Setup finished. Spawning bash shell to keep tmux alive..."
    exec bash
else
    echo "Error: ${REPO_ROOT}/devtools/setup_flutter_bolt_dev_container.sh not found!"
    sleep 5
    tmux kill-server
fi
