**a note** the document ends with TL;DR section that briefly describes setup & everyday usage.

# Flutter Bolt Development Tools

This directory contains helper scripts, templates, and container tooling used to initialize a `meta-bolt-flutter` checkout, build Flutter Bolt packages, and deploy/debug them on a Bolt-based target device.

The main entry point is:

```bash
devtools/flutter_bolt_dev_container.sh <command> [options]
```

## Prerequisites

Before starting the container workflow, make sure that:

- Docker and bash are available on the host.
- The `meta-bolt-flutter` repository is checked out.
- The Flutter application source code is available in a local directory.
- A debug Bolt package configuration exists for the application, for example `flutter.app.wonderous-debug.bolt.json` in `package-configs/`.
- The target STB is reachable from the host.
- You know the BitBake recipe name for the Flutter application (it is later described how to find that out, given you know the bolt package configuration)

Example application source:

```bash
git clone https://github.com/gskinnerTeam/flutter-wonderous-app.git "${APP_DIR}"
git -C "${APP_DIR}" checkout f406f017dd0e6ac8aef8a98c2904cd56cdb105ab
```

## Build the Container Image

Build the local development container image once before using the other commands:

```bash
cd "${REPO_ROOT}"
devtools/flutter_bolt_dev_container.sh dockerbuild
```

This builds the `flutter-bolt-dev:latest` Docker image from `devtools/Dockerfile-flutter-bolt-dev`.

## First-Time Initialization

Run `first_time_init` once for a fresh checkout before starting application development. It runs the repository setup inside the container, updates `build/conf/local.conf` with cache paths, builds the base Bolt environment, and creates the initial runtime Bolt packages.

A cold build can take 1-2 hours. It is much faster when you reuse already populated Yocto downloads and sstate cache directories from a previous compatible build, as described in the next section.

It is possible to pass `--use-build-volume` to store the Yocto `build` directory in a Docker volume instead of the repository bind mount. This is necessary if the host filesystem is not Linux extfs, since yocto is expecting some extfs-specific filesystem features during build; this is necessary eg. on Apple arm M* devices.
The wrapper creates a repo-specific volume during first-time initialization (flutter-bolt-dev-build-*), mounts it at `${REPO_ROOT}/build`, and automatically reuses it on later `start` commands when the matching volume exists. Bolt packages are created under `${REPO_ROOT}/build/bolts`.

### Use Existing Downloads and Sstate

If you already have cache directories, pass both paths:

```bash
cd "${REPO_ROOT}"
devtools/flutter_bolt_dev_container.sh first_time_init \
    --flutter-version "${FLUTTER_SERIES}" \
    --use-build-volume \
    --downloads-path "${OE_DOWNLOADS}" \
    --sstate-path "${OE_SSTATE_PATH}"
```

Both directories must already exist on the host. The script mounts them into the container and writes the following values into `build/conf/local.conf`:

```bitbake
DL_DIR = "${OE_DOWNLOADS}"
SSTATE_DIR = "${OE_SSTATE_PATH}"
```

Only local cache directories are supported by this wrapper. Configure mirrors manually in Yocto if you need a different cache strategy.

### Initialize a New Cache

If you do not have prewarmed cache directories, let the script create them:

```bash
cd "${REPO_ROOT}"
devtools/flutter_bolt_dev_container.sh first_time_init \
    --flutter-version "${FLUTTER_SERIES}" \
    --use-build-volume \
    --init-cache-path "${REPO_ROOT}/build/init-cache"
```

This creates and uses:

```text
${REPO_ROOT}/build/init-cache/downloads
${REPO_ROOT}/build/init-cache/sstate
```

Do not combine `--init-cache-path` with `--downloads-path` or `--sstate-path`; choose one mode.

The command starts a container and runs the initialization in a `tmux` session. In an interactive terminal it attaches automatically. Detach without stopping the container with `Ctrl+B`, then `D`. If setup fails, the shell remains open for debugging.

## Determine Application Names

The development scripts need both a Bolt package name and the BitBake recipe that builds the Flutter app.

The Bolt name is the package config name without the `.bolt.json` suffix, for example:

```bash
export BOLT_NAME=flutter.app.wonderous-debug
```

The package config points to the image recipe:

```bash
jq -r '.bitbake.image' package-configs/flutter.app.wonderous-debug.bolt.json
```

Example output:

```text
gskinnerteam-flutter-wonderous-app-wonders-bolt-image
```

By convention, the Flutter application recipe is the same name without the `-bolt-image` or `-image` suffix, for example:

```bash
export FLUTTER_APP=gskinnerteam-flutter-wonderous-app-wonders
```

## Start the Development Container

Use `start` when the first-time initialization has completed and you are ready to work on a Flutter app:

```bash
cd "${REPO_ROOT}"
devtools/flutter_bolt_dev_container.sh start \
    --flutter-version "${FLUTTER_SERIES}" \
    --project-path "${APP_DIR}" \
    --bolt-name "${BOLT_NAME}" \
    --stb-ip "${STB_IP}" \
    --application-recipe "${FLUTTER_APP}" \
    --downloads-path "${OE_DOWNLOADS}" \
    --sstate-path "${OE_SSTATE_PATH}"
```

Required parameters:

- `--flutter-version <series>`: Flutter SDK series to build against, e.g. `3.38`. Must match one of the supported series (`3.32`, `3.35`, `3.38`). Passed into the container as `FLUTTER_SERIES` and forwarded to `setup-environment`.
- `--project-path <path>`: local path to the Flutter application source code. It is mounted into the container and configured as `EXTERNALSRC` for the app recipe.
- `--bolt-name <name>`: Bolt package config name without the `.bolt.json` suffix, such as `flutter.app.wonderous-debug`.
- `--stb-ip <ip>`: target STB IP address used by `push` and `debug`.
- `--application-recipe <recipe>`: BitBake recipe name for the Flutter app, such as `gskinnerteam-flutter-wonderous-app-wonders`.

Optional parameters:

- `--downloads-path <path>`: existing Yocto downloads directory. The directory must exist.
- `--sstate-path <path>`: existing Yocto sstate cache directory. The directory must exist.

Passing both `--downloads-path` and `--sstate-path` is strongly recommended for repeat builds. If omitted, the container uses whatever cache configuration already exists in the workspace.

The `start` command configures `build/conf/local.conf` with an `externalsrc` block for the selected app recipe and excludes the app and app image recipes from `rm_work`, so rebuilds and debugging are practical.

More concrete examples are available in the earlier sections of this README. You can also inspect package examples in `package-configs/`, such as `flutter.app.wonderous-debug.bolt.json`, and adapt the app template files described below.

## Build, Deploy, and Debug

After `start`, the container runs a background `tmux` session named `dev`. The wrapper commands send build and deployment operations to that session.

Build the configured Bolt package:

```bash
devtools/flutter_bolt_dev_container.sh make
```

Push the built package to the target device:

```bash
devtools/flutter_bolt_dev_container.sh push
```

Build and push in one step:

```bash
devtools/flutter_bolt_dev_container.sh makepush
```

Run the app on the target and print the Dart VM service endpoint:

```bash
devtools/flutter_bolt_dev_container.sh debug
```

The debug command expects the Flutter app to expose the Dart VM service on the target. The current device-side devtools port is hardcoded to `22342`, so successful output looks like:

```text
flutter: The Dart VM service is listening on http://${STB_IP}:22342/
```

To use Flutter's custom device flow from the host, copy `devtools/custom_devices.json` to your local Flutter config directory, for example `~/.config/flutter/custom_devices.json`, and make sure these environment variables are defined in the host shell:

```bash
export STB_IP=<target-ip>
export REPO_ROOT=<path-to-meta-bolt-flutter>
```

Then run:

```bash
flutter run --debug -d rdkdevice
```

This gives access to the Flutter console, hot reload, and Flutter DevTools features supported by the target/runtime.

## Application Templates

The `devtools/app_templates/` directory contains starter files for creating a new Flutter Bolt image and recipe set. These can be used when adding a new application to this layer. Note that it is generally enough to create just a single (release, debug or profile) config to start working on some app; the templates are provided for all the modes.

The templates include:

- `myapp.inc`: shared Flutter app recipe metadata, source URI, Flutter app name, install suffix, and `inherit flutter-app`.
- `myapp-debug.bb`, `myapp-profile.bb`, and `myapp-release.bb`: mode-specific application recipes using the debug, profile, and release Flutter modes.
- `myapp-bolt-image-debug.bb`, `myapp-bolt-image-profile.bb`, and `myapp-bolt-image-release.bb`: image recipes that include the app recipe.
- `flutter.app.myapp.bolt-debug.json`, `flutter.app.myapp.bolt-profile.json`, and `flutter.app.myapp.bolt.json`: Bolt package configs that point to the image recipes.
- `com.rdkcentral.flutter.app.myapp-debug.json`, `com.rdkcentral.flutter.app.myapp-profile.json`, and `com.rdkcentral.flutter.app.myapp.json`: application metadata consumed by Bolt.

Typical use is to copy the template set, replace `myapp` with your recipe/application name, update the metadata and source details, place recipe files under the appropriate recipe directory, and place package config JSON files under `package-configs/`. The resulting debug Bolt package name is the value you pass to `start --bolt-name`, and the app recipe is the value you pass to `start --application-recipe`.

## Command Overview

`devtools/flutter_bolt_dev_container.sh` supports these commands:

- `dockerbuild`: builds the local `flutter-bolt-dev` Docker image.
- `first_time_init`: starts a setup container and performs the initial repo, BitBake, base image, and runtime Bolt setup. Requires `--flutter-version`; requires either `--downloads-path` plus `--sstate-path`, or `--init-cache-path`; accepts `--use-build-volume` to put `${REPO_ROOT}/build` in a repo-specific Docker volume.
- `start`: starts the app development container. Requires `--flutter-version`, `--project-path`, `--bolt-name`, `--stb-ip`, and `--application-recipe`; accepts optional cache paths and Docker tag.
- `bash`: attaches to the container's `tmux` session. Exiting the shell stops the session and then the container; detach with `Ctrl+B`, then `D` to keep it running.
- `make`: runs `bolt make` for the configured Flutter Bolt package.
- `push`: runs `bolt push root@${STB_IP}` for the built output package.
- `makepush`: runs `make` and then `push`.
- `debug`: runs the built package on the target and prints the Dart VM service URL when startup succeeds.
- `ctrlc`: sends `Ctrl+C` to the active command in the container `tmux` session.
- `stop`: stops the running development container.

Each checkout path gets its own generated container name, so multiple checkouts can coexist without sharing the same container instance.

## Notes

- The first `repo sync` and cold BitBake build can take a long time and download a large amount of data.
- Reusing compatible local `downloads` and `sstate-cache` directories is the main way to keep first-time setup and rebuilds fast.
- The scripts currently support local cache folders directly; they do not expose command-line options for remote mirrors.

## TL;DR

### First Time Install

1. Set the paths used by the setup commands:

```bash
export REPO_ROOT=/path/to/meta-bolt-flutter
export OE_DOWNLOADS=/path/to/downloads
export OE_SSTATE_PATH=/path/to/sstate-cache
export FLUTTER_SERIES=3.38
```

2. Build the development container image:

```bash
cd "${REPO_ROOT}"
devtools/flutter_bolt_dev_container.sh dockerbuild
```

3. Run first time init. There are 2 cases:

3.1 If cache is already available, initialize the checkout with existing cache directories:

```bash
devtools/flutter_bolt_dev_container.sh first_time_init \
    --flutter-version "${FLUTTER_SERIES}" \
    --downloads-path "${OE_DOWNLOADS}" \
    --sstate-path "${OE_SSTATE_PATH}"
```

3.2 Alternatively, initialize a new local cache instead:

```bash
devtools/flutter_bolt_dev_container.sh first_time_init \
    --flutter-version "${FLUTTER_SERIES}" \
    --init-cache-path "${REPO_ROOT}/build/init-cache"
```

4. Configure Flutter custom devices on the host:

First, enable custom device support for flutter with:

```bash
flutter config --enable-custom-devices
```

For more details, see:
https://github.com/flutter/flutter/blob/master/docs/tool/Using-custom-embedders-with-the-Flutter-CLI.md

Then copy the custom_devices.json config:

```bash
cp "${REPO_ROOT}/devtools/custom_devices.json" "${HOME}/.config/flutter/custom_devices.json"
```

The setup can be verified by running 'flutter devices'. Assuming the device is available at ${STB_IP}, try;

```bash
export STB_IP=...
flutter devices -v
```

And check that 'rdkdevice' is listed.

### General Usage

1. Set the app and target values:

```bash
export REPO_ROOT=/path/to/meta-bolt-flutter
export APP_DIR=/path/to/flutter-app
export BOLT_NAME=flutter.app.wonderous-debug
export STB_IP=192.0.2.10
export FLUTTER_APP=gskinnerteam-flutter-wonderous-app-wonders
export OE_DOWNLOADS=/path/to/downloads
export OE_SSTATE_PATH=/path/to/sstate-cache
export FLUTTER_SERIES=3.38
```

2. Start the development container:

```bash
cd "${REPO_ROOT}"
devtools/flutter_bolt_dev_container.sh start \
    --flutter-version "${FLUTTER_SERIES}" \
    --project-path "${APP_DIR}" \
    --bolt-name "${BOLT_NAME}" \
    --stb-ip "${STB_IP}" \
    --application-recipe "${FLUTTER_APP}" \
    --downloads-path "${OE_DOWNLOADS}" \
    --sstate-path "${OE_SSTATE_PATH}"
```

3. Build and push the app:

```bash
devtools/flutter_bolt_dev_container.sh makepush
```

4. Start the app in debug mode and print the VM service URL:

```bash
devtools/flutter_bolt_dev_container.sh debug
```

4.1 Optional: start DDS & access the devtools.

**Note that this is simplified by using 'flutter run' command; see point 5.**

If the application was compiled in debug or profile mode (-debug or -profile bolt variant was used), it is possible to use the devtools like this:

First, start the dart devtools server / DDS:

```bash
dart devtools
```

This should automatically open DDS page in the default browser (url like 'http://127.0.0.1:9100/home'). Here, you need to provide the url to rdk device in a text box; the device url is logged by previous 'debug' command, and should be something like:

    http://10.42.0.36:23452

Enter this address, then press 'connect' button. Flutter devtools should open an another tab.

5. Or run the app through Flutter's custom device support, to enable hot reload etc.

In the ${APP_DIR} folder, run:

```bash
export REPO_ROOT=/path/to/meta-bolt-flutter
export STB_IP=192.0.2.10
flutter run --debug -d rdkdevice
```

The url to already created webtools instance will be visible in the log. You are also able to use flutter console commands, like hot-reload.

6. Stop the flutter application running on the device

The application is running synchronously in container tmux session bash, so it is necessary to send 'ctrl-c' interrupt command:

```bash
devtools/flutter_bolt_dev_container.sh ctrlc
```

7. Attach to, detach from, or stop the running container when needed:

```bash
devtools/flutter_bolt_dev_container.sh bash
# detach from tmux with Ctrl+B, then D
devtools/flutter_bolt_dev_container.sh stop
```
