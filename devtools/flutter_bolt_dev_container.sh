#!/bin/bash

# Enabling `set -v` changes the debug command output and can interfere with log parsing.
# set -v
debug="echo [DEBUG]"
# Resolve the canonical, absolute path of the script itself
SCRIPT_PATH=$(readlink -f "$0")

# Compute the instance ID using sha256 of the path
INSTANCE_ID=$(echo -n "$SCRIPT_PATH" | sha256sum | cut -d' ' -f1)
CONTAINER_NAME="flutter-bolt-dev-container-instance-${INSTANCE_ID}"

# This script is expected to live inside the meta-bolt-flutter tree.
REPO_ROOT=$(realpath "$(dirname $SCRIPT_PATH)/..")

# Utility to send commands to the container's background tmux bash session synchronously
run_in_tmux() {
    local cmd="$1"
    # If true, we won't wrap the command in exit code capture logic and will assume it handles its own output/exit code
    if [ "$2" = "DIRECT" ]; then
        is_direct=1
    else
        is_direct=0
    fi

    # If set, do not wait for the command to complete.
    if [ "$2" = "ASYNC" ]; then
        is_async=1
    else
        is_async=0
    fi

    # 1. Clean up state from any previous commands
    docker exec --user flutter-dev "$CONTAINER_NAME" bash -c 'rm -f /tmp/cmd.out /tmp/cmd.exit'

    # 2. Send the command.
    if [ "$is_direct" == "1" ]; then
        # Direct mode skips the explicit exit-code wrapper.
        full_command="${cmd} > /tmp/cmd.out 2>&1 ; echo "0" > /tmp/cmd.exit"
    elif [ "$is_async" == "1" ]; then
        full_command="${cmd}"
    else
        full_command="( ${cmd} > /tmp/cmd.out 2>&1 ) ; echo \$? > /tmp/cmd.exit"
    fi

    ${debug} -e "******** Running command in container: \n" ${full_command} "\n********"
    docker exec --user flutter-dev "$CONTAINER_NAME" tmux send-keys -t dev "${full_command}" ENTER

    if [ "$is_async" == "1" ]; then
        echo "Command sent to container in async mode. Not waiting for output or exit code."
        return 0
    fi

    ${debug} "waiting for exit code..."
    
    # 3. Wait (poll) until the exit code file is created
    while ! docker exec --user flutter-dev "$CONTAINER_NAME" stat /tmp/cmd.exit >/dev/null 2>&1; do
        sleep 0.5
    done

    # 4. Fetch the output and print it to the host terminal
    docker exec --user flutter-dev "$CONTAINER_NAME" cat /tmp/cmd.out

    # 5. Fetch the exit code and return it
    local exit_code=$(docker exec --user flutter-dev "$CONTAINER_NAME" cat /tmp/cmd.exit)
    return $exit_code
}

is_running() {
    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" == "true" ]; then
        return 0
    else
        return 1
    fi
}

wait_for_tmux() {
    echo "Waiting for tmux session to initialize..."
    for i in {1..20}; do
        if docker exec --user flutter-dev "$CONTAINER_NAME" tmux has-session -t dev 2>/dev/null; then
            # Give the shell a moment to finish starting inside tmux.
            sleep 1
            return 0
        fi
        sleep 1
    done
    echo "Timed out waiting for tmux to start."
    return 1
}

get_container_env() {
    local env_name="$1"

    docker exec --user flutter-dev "$CONTAINER_NAME" printenv "$env_name" 2>/dev/null
}

start_usage() {
    echo "Usage: $0 start [--tag <tag>] --project-path <project-source-code-path> --bolt-name <bolt-name> --stb-ip <stb-ip> --application-recipe <application-bitbake-recipe> [--downloads-path <downloads-path>] [--sstate-path <sstate-path>]"
}

first_time_init_usage() {
    echo "Usage: $0 first_time_init [--tag <tag>] --downloads-path <downloads-path> --sstate-path <sstate-path>"
    echo "   or: $0 first_time_init [--tag <tag>] --init-cache-path <init-cache-path>"
}

cmd_start() {
    local tag="latest"
    local project_path=""
    local bolt_name=""
    local stb_ip=""
    local application_recipe=""
    local downloads_path=""
    local sstate_path=""
    local docker_args=()

    if is_running; then
        echo "Warning: Container instance '$CONTAINER_NAME' is already running."
        echo "Attached repository path: $REPO_ROOT"
        return 0
    fi

    while [ $# -gt 0 ]; do
        if [ $# -lt 2 ]; then
            start_usage
            exit 1
        fi

        case "$1" in
            --tag)
                tag="$2"
                ;;
            --project-path)
                project_path="$2"
                ;;
            --bolt-name)
                bolt_name="$2"
                ;;
            --stb-ip)
                stb_ip="$2"
                ;;
            --application-recipe)
                application_recipe="$2"
                ;;
            --downloads-path)
                downloads_path="$2"
                ;;
            --sstate-path)
                sstate_path="$2"
                ;;
            *)
                start_usage
                exit 1
                ;;
        esac

        shift 2
    done

    if [ -z "$project_path" ] || [ -z "$bolt_name" ] || [ -z "$stb_ip" ] || [ -z "$application_recipe" ]; then
        start_usage
        exit 1
    fi

    if [ -n "$downloads_path" ] && [ ! -d "$downloads_path" ]; then
        echo "Error: Downloads path does not exist: $downloads_path"
        exit 1
    fi

    if [ -n "$sstate_path" ] && [ ! -d "$sstate_path" ]; then
        echo "Error: Sstate path does not exist: $sstate_path"
        exit 1
    fi

    if [ -n "$downloads_path" ]; then
        docker_args+=( -v "${downloads_path}:${downloads_path}" )
        docker_args+=( -e "DOWNLOADS_PATH=${downloads_path}" )
    fi

    if [ -n "$sstate_path" ]; then
        docker_args+=( -v "${sstate_path}:${sstate_path}" )
        docker_args+=( -e "SSTATE_PATH=${sstate_path}" )
    fi

    # Remove a stopped container with the same generated name, if present.
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1

    export REPO_ROOT

    echo "Starting container $CONTAINER_NAME..."
    echo "Mounting ${REPO_ROOT} and ${project_path}"
    docker run -d --name "$CONTAINER_NAME" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        --security-opt apparmor=unconfined \
        -v "$REPO_ROOT:$REPO_ROOT" \
	    -v "${project_path}:${project_path}" \
	    -v "/tmp:/tmp" \
        -v "${REPO_ROOT}/devtools/scripts/tmux_init.sh:/usr/local/bin/tmux_init.sh" \
        -v "${REPO_ROOT}/devtools/scripts/flutter_dev_entrypoint.sh:/usr/local/bin/entrypoint.sh" \
	    "${docker_args[@]}" \
	    --network host \
        -e REPO_ROOT="${REPO_ROOT}" \
        -e FLUTTER_PROJECT_SOURCE_CODE_PATH="${project_path}" \
        -e FLUTTER_BOLT_NAME="${bolt_name}" \
        -e STB_IP="${stb_ip}" \
        -e FLUTTER_APPLICATION_RECIPE="${application_recipe}" \
        "flutter-bolt-dev:$tag"
    wait_for_tmux || return 1
}

cmd_first_time_init() {
    local tag="latest"
    local downloads_path=""
    local sstate_path=""
    local init_cache_path=""
    local docker_args=()

    if is_running; then
        echo "Warning: Container instance '$CONTAINER_NAME' is already running."
        echo "Attached repository path: $REPO_ROOT"
        echo "Attach with: $0 bash"
        return 0
    fi

    while [ $# -gt 0 ]; do
        if [ $# -lt 2 ]; then
            first_time_init_usage
            exit 1
        fi

        case "$1" in
            --tag)
                tag="$2"
                ;;
            --downloads-path)
                downloads_path="$2"
                ;;
            --sstate-path)
                sstate_path="$2"
                ;;
            --init-cache-path)
                init_cache_path="$2"
                ;;
            *)
                first_time_init_usage
                exit 1
                ;;
        esac

        shift 2
    done

    if [ -n "$init_cache_path" ] && { [ -n "$downloads_path" ] || [ -n "$sstate_path" ]; }; then
        echo "Error: Use either --downloads-path/--sstate-path or --init-cache-path, not both."
        first_time_init_usage
        exit 1
    fi

    if [ -z "$init_cache_path" ] && { [ -z "$downloads_path" ] || [ -z "$sstate_path" ]; }; then
        echo "Error: Missing cache arguments."
        if [ -z "$downloads_path" ]; then
            echo "  Missing: --downloads-path <downloads-path>"
        fi
        if [ -z "$sstate_path" ]; then
            echo "  Missing: --sstate-path <sstate-path>"
        fi
        echo "Pass both --downloads-path and --sstate-path to use existing cache directories,"
        echo "or pass --init-cache-path <init-cache-path> to create and use:"
        echo "  <init-cache-path>/downloads"
        echo "  <init-cache-path>/sstate"
        first_time_init_usage
        exit 1
    fi

    if [ -n "$init_cache_path" ]; then
        mkdir -p "${init_cache_path}"
        init_cache_path=$(realpath "$init_cache_path")
        docker_args+=( -v "${init_cache_path}:${init_cache_path}" )
        docker_args+=( -e "INIT_CACHE_PATH=${init_cache_path}" )
    else
        if [ ! -d "$downloads_path" ]; then
            echo "Error: Downloads path does not exist: $downloads_path"
            exit 1
        fi

        if [ ! -d "$sstate_path" ]; then
            echo "Error: Sstate path does not exist: $sstate_path"
            exit 1
        fi

        docker_args+=( -v "${downloads_path}:${downloads_path}" )
        docker_args+=( -v "${sstate_path}:${sstate_path}" )
    fi

    if [ -n "$downloads_path" ]; then
        docker_args+=( -e "DOWNLOADS_PATH=${downloads_path}" )
    fi

    if [ -n "$sstate_path" ]; then
        docker_args+=( -e "SSTATE_PATH=${sstate_path}" )
    fi

    # Remove a stopped container with the same generated name, if present.
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1

    echo "Starting first-time init container $CONTAINER_NAME..."
    echo "Mounting ${REPO_ROOT}"
    docker run -d --name "$CONTAINER_NAME" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        --security-opt apparmor=unconfined \
        -v "$REPO_ROOT:$REPO_ROOT" \
        -v "/tmp:/tmp" \
        -v "${REPO_ROOT}/devtools/scripts/first_time_init_tmux.sh:/usr/local/bin/first_time_init_tmux.sh" \
        -v "${REPO_ROOT}/devtools/scripts/flutter_dev_entrypoint.sh:/usr/local/bin/entrypoint.sh" \
        "${docker_args[@]}" \
        --network host \
        -e REPO_ROOT="${REPO_ROOT}" \
        -e TMUX_INIT_SCRIPT="/usr/local/bin/first_time_init_tmux.sh" \
        "flutter-bolt-dev:$tag"
    wait_for_tmux || return 1

    # only attach to tmux session if in interactive session (fds 0 & 1 available) ...
    if [ -t 0 ] && [ -t 1 ]; then
        echo "Attaching to first-time init tmux session. Detach with Ctrl+B, then D."
        cmd_bash
    else
        echo "First-time init is running in tmux. Attach with: $0 bash"
    fi
}

cmd_push() {
    if ! is_running; then
        echo "Error: Container instance is not running."
        exit 1
    fi

    # Run the push command from the container tmux session.
    run_in_tmux 'cd ${REPO_ROOT}/bolts; bolt push root@${STB_IP} ${FLUTTER_OUTPUT_BOLT_NAME}'
}

cmd_make() {
    if ! is_running; then
        echo "Error: Container instance is not running."
        exit 1
    fi

    # Run the build command from the container tmux session.
    run_in_tmux 'cd ${REPO_ROOT}/bolts; bolt make ${FLUTTER_BOLT_NAME}'
}

cmd_debug() {
    local stb_ip=""

    if ! is_running; then
        echo "Error: Container instance is not running."
        exit 1
    fi

    stb_ip=$(get_container_env STB_IP)

    ${debug} "Debug on: STB_IP: ${stb_ip}."

    run_in_tmux 'bolt run root@${STB_IP} ${FLUTTER_OUTPUT_BOLT_NAME} >/tmp/cmd.log 2>&1 >/tmp/bolt_run_output.log' ASYNC

    CTR=15
    # Poll the target log until the Dart VM service endpoint becomes available.
    while ! grep "Dart VM service is listening on" /tmp/bolt_run_output.log >/dev/null && [ $CTR != 0 ]
    do
        ${debug} "Waiting for flutter app to start ... ($CTR)"
        sleep 1
        CTR=$(($CTR-1))
    done

    if grep "Dart VM service is listening on" /tmp/bolt_run_output.log >/dev/null
    then
        echo flutter: The Dart VM service is listening on http://${stb_ip}:22342/
    else
        echo "The app didn't start!"
        exit 1
    fi
    exit 0
}

cmd_stop() {
    if is_running; then
        echo "Stopping container $CONTAINER_NAME..."
        docker stop "$CONTAINER_NAME"
    else
        echo "Warning: Container instance $CONTAINER_NAME is not running."
    fi
}

cmd_bash() {
    if ! is_running; then
        echo "Error: Container instance is not running."
        exit 1
    fi
    docker exec --user flutter-dev -it "$CONTAINER_NAME" tmux attach-session -t dev
}

# -----------------
# Entrypoint Router
# -----------------
COMMAND="$1"
shift

case "$COMMAND" in
    first_time_init)
        cmd_first_time_init "$@"
        ;;
    start)
        cmd_start "$@"
        ;;
    push)
        cmd_push "$@"
        ;;
    debug)
        cmd_debug "$@"
        ;;
    stop)
        cmd_stop "$@"
        ;;
    bash)
        cmd_bash "$@"
        ;;
    dockerbuild)
        docker build . -f Dockerfile-flutter-bolt-dev -t flutter-bolt-dev
        ;;
    make)
        cmd_make "$@"
        ;;
    makepush)
        cmd_make "$@"
        cmd_push "$@"
        ;;
    ctrlc)
        if ! is_running; then
            echo "Error: Container instance is not running."
            exit 1
        fi
        docker exec --user flutter-dev "$CONTAINER_NAME" tmux send-keys -t dev C-c
        # Allow the interrupted process to settle before returning control.
        sleep 3
        ;;
    *)
        echo "Usage: $0 {first_time_init|start|push|debug|stop|bash|dockerbuild|make|makepush|ctrlc} [args...]"
        echo "  first_time_init [--tag <tag>] --downloads-path <downloads-path> --sstate-path <sstate-path>"
        echo "  first_time_init [--tag <tag>] --init-cache-path <init-cache-path>"
        echo "  start [--tag <tag>] --project-path <project-source-code-path> --bolt-name <bolt-name> --stb-ip <stb-ip> --application-recipe <application-bitbake-recipe> [--downloads-path <downloads-path>] [--sstate-path <sstate-path>]"
        exit 1
        ;;
esac
