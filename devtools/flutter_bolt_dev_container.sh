#!/bin/bash
debug="echo [DEBUG]"
# Resolve the canonical, absolute path of the script itself
SCRIPT_PATH=$(readlink -f "$0")

# FLUTTER_PROJECT_SOURCE_CODE_PATH="/home/tomasz.karczewski/copilot/flutter-wonderous-app"

# Compute the instance ID using sha256 of the path
INSTANCE_ID=$(echo -n "$SCRIPT_PATH" | sha256sum | cut -d' ' -f1)
CONTAINER_NAME="flutter-bolt-dev-container-instance-${INSTANCE_ID}"

# this script should be within the meta-bolt-flutter tree. 
REPO_ROOT=$(realpath "$(dirname $SCRIPT_PATH)/..")
#$(cd "$(dirname "$SCRIPT_PATH")" && git rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_PATH")

# Utility to send commands to the container's background tmux bash session synchronously
run_in_tmux() {
    local cmd="$1"
    # If true, we won't wrap the command in exit code capture logic and will assume it handles its own output/exit code
    if [ "$2" = "DIRECT" ]; then
        is_direct=1
    else
        is_direct=0
    fi

    # if passed, we don't find for the command to return (and always report success)
    if [ "$2" = "ASYNC" ]; then
        is_async=1
    else
        is_async=0
    fi


    # 1. Clean up state from any previous commands
    docker exec --user flutter-dev "$CONTAINER_NAME" bash -c 'rm -f /tmp/cmd.out /tmp/cmd.exit'
    
    # 2. Send the command.
    if [ "$is_direct" == "1" ]; then
        # If it's a direct command, we don't wrap it in the exit code capture logic
        full_command="${cmd} > /tmp/cmd.out 2>&1 ; echo "0" > /tmp/cmd.exit"
    elif [ "$is_async" == "1" ]; then
        full_command="${cmd}"
    else
        full_command="( ${cmd} > /tmp/cmd.out 2>&1 ) ; echo \$? > /tmp/cmd.exit"
    fi
    
    ${debug} -e "******** Running command in container: \n" ${full_command} "\n********"
    docker exec --user flutter-dev "$CONTAINER_NAME" tmux send-keys -t dev " ${full_command}" ENTER

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
            # Small extra sleep to allow bash to actually launch inside tmux
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

cmd_start() {
    local tag="latest"
    local project_path=""
    local bolt_name=""
    local stb_ip=""
        local application_recipe=""

    if is_running; then
        echo "Warning: Container instance '$CONTAINER_NAME' is already running."
        echo "Attached repository path: $REPO_ROOT"
        return 0
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --tag)
                if [ -z "$2" ]; then
                    echo "Usage: $0 start [--tag <tag>] <project-source-code-path> <bolt-name> <stb-ip> <application-bitbake-recipe>"
                    exit 1
                fi
                tag="$2"
                shift 2
                ;;
            *)
                if [ -z "$project_path" ]; then
                    project_path="$1"
                elif [ -z "$bolt_name" ]; then
                    bolt_name="$1"
                elif [ -z "$stb_ip" ]; then
                    stb_ip="$1"
                elif [ -z "$application_recipe" ]; then
                    application_recipe="$1"
                else
                    echo "Usage: $0 start [--tag <tag>] <project-source-code-path> <bolt-name> <stb-ip> <application-bitbake-recipe>"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$project_path" ] || [ -z "$bolt_name" ] || [ -z "$stb_ip" ] || [ -z "$application_recipe" ]; then
        echo "Usage: $0 start [--tag <tag>] <project-source-code-path> <bolt-name> <stb-ip> <application-bitbake-recipe>"
        exit 1
    fi

    # Clean up dead container if it exists
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1

    echo "Starting container $CONTAINER_NAME..."
    echo "Mounting ${REPO_ROOT} and ${project_path}"
    SCRIPT_DIR=`dirname "$0"`
    docker run -d --name "$CONTAINER_NAME" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        --security-opt apparmor=unconfined \
        -v "$REPO_ROOT:$REPO_ROOT" \
	    -v "${project_path}:${project_path}" \
	    -v "/tmp:/tmp" \
        -v "${SCRIPT_DIR}/tmux_init.sh:/usr/local/bin/tmux_init.sh" \
        -v "${SCRIPT_DIR}/flutter_dev_entrypoint.sh:/usr/local/bin/entrypoint.sh" \
	    --network host \
        -e REPO_ROOT="${REPO_ROOT}" \
        -e FLUTTER_PROJECT_SOURCE_CODE_PATH="${project_path}" \
        -e FLUTTER_BOLT_NAME="${bolt_name}" \
        -e STB_IP="${stb_ip}" \
        -e FLUTTER_APPLICATION_RECIPE="${application_recipe}" \
        "flutter-bolt-dev:$tag"
    wait_for_tmux || return 1
}

cmd_push() {
    if ! is_running; then
        echo "Error: Container instance is not running."
        exit 1
    fi

    ${debug} "Checking required environment variables in container..."
    run_in_tmux 'if [ -z "$FLUTTER_PROJECT_SOURCE_CODE_PATH" ] || [ -z "$FLUTTER_BOLT_NAME" ] || [ -z "$STB_IP" ]; then echo "ERROR: FLUTTER_PROJECT_SOURCE_CODE_PATH ($FLUTTER_PROJECT_SOURCE_CODE_PATH) and/or FLUTTER_BOLT_NAME ($FLUTTER_BOLT_NAME) and/or STB_IP ($STB_IP) are not defined. Start the container with <project-source-code-path> <bolt-name> <stb-ip> first." >&2; exit 1; fi'
    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Execute the push echo output directly from inside the container mapped bash
    run_in_tmux 'cd ' ${META_BOLT_ROOT} '/bolts; bolt push root@${STB_IP} com.rdkcentral.flutter.app.wonderous+0.1.0'
}

cmd_debug() {
    local stb_ip=""

    if ! is_running; then
        echo "Error: Container instance is not running."
        exit 1
    fi

    stb_ip=$(get_container_env STB_IP)
    
    ${debug} "Debug on: STB_IP: ${stb_ip}."

    ${debug} "Checking required environment variables in container..."
    run_in_tmux 'if [ -z "$FLUTTER_PROJECT_SOURCE_CODE_PATH" ] || [ -z "$FLUTTER_BOLT_NAME" ] || [ -z "$STB_IP" ]; then echo "ERROR: FLUTTER_PROJECT_SOURCE_CODE_PATH ($FLUTTER_PROJECT_SOURCE_CODE_PATH) and/or FLUTTER_BOLT_NAME ($FLUTTER_BOLT_NAME) and/or STB_IP ($STB_IP) are not defined. Start the container with <project-source-code-path> <bolt-name> <stb-ip> first." >&2; exit 1; fi'
    if [ $? -ne 0 ]; then
        exit 1
    fi

    run_in_tmux 'bolt run root@${STB_IP} com.rdkcentral.flutter.app.wonderous+0.1.0 >/tmp/cmd.log 2>&1 >/tmp/bolt_run_output.log' ASYNC

    CTR=15
    # a hack for 'flutter run' with custom device: to discover the VM
    # it is parsing the log to get 'listening on ...' line
    # wait for 'The Dart VM service is listening on http://0.0.0.0:12345/'
    while ! grep "Dart VM service is listening on" /tmp/bolt_run_output.log >/dev/null && [ $CTR != 0 ]
    do
        ${debug} "Waiting for flutter app to start ... ($CTR)"
        sleep 1
        CTR=$(($CTR-1))
    done
    
    if grep "Dart VM service is listening on" /tmp/bolt_run_output.log >/dev/null
    then
        echo flutter: The Dart VM service is listening on http://${stb_ip}:12345/
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
    *)
        echo "Usage: $0 {start|push|debug|stop|bash|dockerbuild} [args...]"
        echo "  start [--tag <tag>] <project-source-code-path> <bolt-name> <stb-ip> <application-bitbake-recipe>"
        exit 1
        ;;
esac
