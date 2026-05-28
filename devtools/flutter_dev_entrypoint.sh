#!/bin/bash

# Map the flutter-dev user to the requesting host user's UID and GID if provided
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    # We use -o to allow non-unique (just in case) and update the group and user
    if [ "$HOST_GID" -ne "$(id -g flutter-dev)" ]; then
        groupmod -o -g "$HOST_GID" flutter-dev
    fi
    if [ "$HOST_UID" -ne "$(id -u flutter-dev)" ]; then
        usermod -o -u "$HOST_UID" flutter-dev
    fi
    # Ensure the home directory is owned by the new UID/GID
    chown -R flutter-dev:flutter-dev /home/flutter-dev
fi

# Drop privileges to flutter-dev and start the tmux session
exec sudo --preserve-env=REPO_ROOT,HOST_UID,HOST_GID -H -u flutter-dev bash <<'EOF'
tmux new-session -d -s dev "/usr/local/bin/tmux_init.sh"

# Keep the container alive by polling the tmux session
while tmux has-session -t dev 2>/dev/null; do
    sleep 2
done
EOF
