# meta-bolt-flutter

Bitbake meta layer extending the **bolt** distro and meta-flutter allowing to build flutter applications and flutter runtime (flutter engine + embedder) natively (AOT release mode) as separate OCI-artifacts in ralf format aka bolts.

Multi-version support allows building against Flutter SDK series **3.32**, **3.35**, and **3.38** from a single codebase.

| Series | Flutter SDK Tag |
|--------|----------------|
| 3.32   | 3.32.2         |
| 3.35   | 3.35.7         |
| 3.38   | 3.38.3         |

# Setup and building

See [Setup and building](https://github.com/rdkcentral/meta-bolt-distro/blob/develop/README.md#setup-and-building)
section in the [meta-bolt-distro](https://github.com/rdkcentral/meta-bolt-distro) documentation.

## flutter runtime build instructions

* Download this repository and enter its root directory.
```
git clone https://github.com/rdkcentral/meta-bolt-flutter.git
cd meta-bolt-flutter
```

* Setup the build environment. Pass the desired Flutter SDK series as argument:
```
source setup-environment 3.38   # build against Flutter 3.38.3
source setup-environment 3.35   # build against Flutter 3.35.7
source setup-environment 3.32   # build against Flutter 3.32.2
```

* Start building the flutter-runtime  image.
```
bitbake flutter-auto-runtime-bolt-image
```
## Building flutter-runtime as bolt package! 

To create Bolt packages for Flutter, ensure that the base package is available in the package store. Refer to the [building the base bolt package](https://github.com/rdkcentral/meta-bolt-distro?tab=readme-ov-file#building-the-base-bolt-package) section to generate the base package and set up the package store.

```
bolt make flutter.runtime.flutter-auto --install

```
## App versioning

Flutter app recipes inherit the `flutter-bolt-app` bbclass which creates a `current` symlink inside the app rootfs pointing to the actual Flutter SDK version directory:

```
/usr/share/flutter/<app-name>/current  ->  <FLUTTER_SDK_TAG>
```

App bolt package configs use this stable `current` path as the entryPoint:
```
"entryPoint": "/usr/share/flutter/<app-name>/current/release/"
```

This means the same app bolt package config works across all supported Flutter SDK series without any version-specific changes.

## Building flutter-application as bolt package! 

Make sure you configured your the packageconfig of your application with right depedency on the exact flutter runtime and entryPoint
See example [package-configs](https://github.com/rdkcentral/meta-bolt-flutter/tree/develop/package-configs)

```
bolt make flutter.app.wonderous --install
bolt make flutter.app.helloworld --install
```


## Running flutter bolt packages on device ! 

To run bolt packages on device, use `bolt push` and `bolt run` as explained in [bolt tool usage](https://github.com/rdkcentral/bolt-tools/tree/main/bolt#usage)

```
bolt push <sshuser@remoteip> <boltpackagename>
bolt run <sshuser@remoteip> <boltpackagename>

bolt push <sshuser@remoteip> com.rdkcentral.base+0.2.0
bolt push <sshuser@remoteip> com.rdkcentral.flutter.runtime.flutter-auto+0.0.1
bolt push <sshuser@remoteip> com.rdkcentral.flutter.app.wonderous+0.1.0

bolt run <sshuser@remoteip> com.rdkcentral.flutter.app.wonderous+0.1.0
```
