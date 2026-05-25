# meta-bolt-flutter

Bitbake meta layer extending the **bolt** distro and meta-flutter allowing to build flutter applications and flutter runtime (flutter engine + embedder) natively (AOT release mode) as separate OCI-artifacts in ralf format aka bolts 

# Setup and building

See [Setup and building](https://github.com/rdkcentral/meta-bolt-distro/blob/develop/README.md#setup-and-building)
section in the [meta-bolt-distro](https://github.com/rdkcentral/meta-bolt-distro) documentation.

## flutter runtime build instructions

* Download this repository and enter its root directory.
```
git clone https://github.com/rdkcentral/meta-bolt-flutter.git
cd meta-bolt-flutter
```

* Setup the build environment.
```
source setup-environment
```

* Start building the flutter-runtime  image.
```
bitbake flutter-auto-3-41-8-runtime-bolt-image
```
## Building flutter-runtime as bolt package! 

To create Bolt packages for Flutter, ensure that the base package is available in the package store. Refer to the [building the base bolt package](https://github.com/rdkcentral/meta-bolt-distro?tab=readme-ov-file#building-the-base-bolt-package) section to generate the base package and set up the package store.


Follow the same steps mentioned in the [Cobalt OCI image building instructions](#cobalt-oci-image-building-instructions) chapter to setup and build the Cobalt runtime, but instead of calling `bitbake cobalt-bolt-image`, use the [bolt tool](https://github.com/rdkcentral/bolt-tools/tree/main/bolt) to create bolt packages for Cobalt.

```
bolt make flutter.runtime.flutter-auto.v3_41_8 --install

```
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
bolt push <sshuser@remoteip> com.rdkcentral.flutter.runtime.flutter-auto.v3_41_8+0.0.1
bolt push <sshuser@remoteip> com.rdkcentral.flutter.app.wonderous+0.1.0

bolt run <sshuser@remoteip> com.rdkcentral.flutter.app.wonderous+0.1.0
```
