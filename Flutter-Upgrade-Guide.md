# Flutter Version Upgrade Guide — meta-bolt-flutter

> This document covers the generic Flutter upgrade process for the `meta-bolt-flutter` Yocto layer,  
> the specific changes made during the **3.38.3 → 3.41.8** upgrade, errors encountered and their fixes,  
> build & validation steps, and future recommendations.

---

## Table of Contents

1. [Upgrade Overview](#1-upgrade-overview)
2. [Generic Flutter Upgrade Process](#2-generic-flutter-upgrade-process)
3. [Changes Made — 3.38.3 → 3.41.8](#3-changes-made--3383--3418)
4. [Errors / Warnings and Fixes](#4-errors--warnings-and-fixes)
5. [Build & Validation Steps](#5-build--validation-steps)
6. [Future Recommendations](#6-future-recommendations)

---

## 1. Upgrade Overview

| Property | Value |
|---|---|
| Previous Flutter version | 3.38.3 (Dart 3.10.1) |
| New Flutter version | **3.41.8** (Dart 3.11.5) |
| Flutter engine revision | `59aa584fdf100e6c78c785d8a5b565d1de4b48ab` |
| Flutter release date | 2026-04-27 |
| Flutter archive | `stable/linux/flutter_linux_3.41.8-stable.tar.xz` |
| Archive SHA256 | `0c7e47fc39ef86290b41707d687bdca7f82b277267a6ef74717f8e88ac423de1` |
| Build status |  Successful |

> **Note:** Dart SDK is **not** independently versioned. It is derived from:  
> `Flutter → Engine → DEPS → Dart`  
> Correct Dart alignment is achieved solely by pinning the Flutter engine revision.

---

## 2. Generic Flutter Upgrade Process

Follow these steps for any future Flutter version upgrade in `meta-bolt-flutter`.

### Step 1 — Identify release metadata

Visit the official Flutter release feed:
```
https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
```
Collect for the target version:
- Release hash
- Dart SDK version
- Archive path and SHA256
- Release date

### Step 2 — Retrieve the engine revision

```bash
git clone https://github.com/flutter/flutter.git
cd flutter
git checkout <new_version_tag>
cat bin/internal/engine.version
```

### Step 3 — Update meta-flutter version metadata

Edit or patch the following files inside `deps/meta-flutter`:

| File | Change |
|---|---|
| `conf/include/flutter-version.inc` | Update `FLUTTER_SDK_TAG` to the new version |
| `conf/include/dart-revision.json` | Add `"<version>": "<dart_version>"` entry |
| `conf/include/engine-revision.json` | Add `"<version>": "<engine_commit>"` entry |
| `conf/include/releases_linux.json` | Add release entry block and update `current_release.stable` hash |

> In this layer, these changes are delivered via a patch file applied by `do_meta_flutter_patch`  
> in `flutter-engine_git.bbappend` to avoid modifying the upstream `meta-flutter` dependency directly.

### Step 4 — Update layer version references

Replace all occurrences of the old version string (e.g. `3_38_3` / `3.38.3`) with the new version in:

- `conf/conf-notes.txt` — bitbake example targets
- `README.md` — build and bolt commands
- `package-configs/*.json` — entryPoints and runtime dependencies
- `recipes-core/images/` — create new image `.bb` file
- `package-configs/*.bolt.json` — bolt build descriptors

### Step 5 — Review and update recipe patches

- Remove patches that are no longer needed or incompatible with the new engine version
- Add new patches for any build issues introduced by the new version
- Verify existing patches apply cleanly; fix context lines if needed

### Step 6 — Review embedder and distro configuration

- Check if new `DISTRO_FEATURES` are required (e.g. new graphics/X11 backends)
- Check if new `PACKAGECONFIG` options are needed for the embedder (`flutter-auto`)
- Check if new native build tool dependencies are required (e.g. `clang-native`)

### Step 7 — Build and validate

```bash
source setup-environment
bitbake flutter-auto-<new_version>-runtime-bolt-image
```

---

## 3. Changes Made — 3.38.3 → 3.41.8

### 3.1 meta-flutter Version Metadata (via patch)

**File:** `recipes-graphics/flutter-engine/files/flutter_version_upgrade_to_3_41_8.patch`  
Applied to `deps/meta-flutter` by the `do_meta_flutter_patch` Yocto task.

| File patched | Change |
|---|---|
| `conf/include/flutter-version.inc` | `FLUTTER_SDK_TAG` → `3.41.8` |
| `conf/include/dart-revision.json` | Added `"3.41.8": "3.11.5"` |
| `conf/include/engine-revision.json` | Added `"3.41.8": "59aa584fdf100e6c78c785d8a5b565d1de4b48ab"` |
| `conf/include/releases_linux.json` | Added 3.41.8 stable release entry; updated `current_release.stable` |

---

### 3.2 Modified Recipe Files

#### `recipes-graphics/flutter-engine/flutter-engine_git.bbappend`

1. Added `GN_ARGS:append = " --no-default-linux-sysroot"` to disable the default Debian sysroot check; Yocto provides its own sysroot via `STAGING_DIR_TARGET`
2. Removed obsolete patches no longer compatible with 3.41.8:
   - `0003-impeller-unnecessary-virtual-specifier.patch`
   - `0001-abseil-cpp-clang-compiler-warnin.patch`
3. Added `do_meta_flutter_patch` task with check to apply `flutter_version_upgrade_to_3_41_8.patch`
4. Added `DEPENDS += "libxcb libx11"` for new X11 requirements

#### `recipes-graphics/toyota/flutter-auto_2.0.bbappend`

Extended `PACKAGECONFIG` with:
```
egl-3d
egl-transparency
egl-multisample
backend-wayland-drm
```
Enables: Wayland EGL backend, DRM backend, EGL 3D support, transparency, and multisampling.

#### `recipes-graphics/flutter-apps/gskinnerteam-flutter-wonderous-app-wonders_2.2.4.bbappend`

```bitbake
DEPENDS += "clang-native"
FLUTTER_BUILD_ARGS = "bundle --target-platform=linux-x64"
```

#### `conf/layer.conf`

```bitbake
DISTRO_FEATURES:append = " opengl x11"
```

#### `conf/conf-notes.txt` and `README.md`

All bitbake targets and bolt commands updated from `v3_38_3` / `3.38.3` → `v3_41_8` / `3.41.8`.

---

### 3.3 Updated Package Configs

| File | Change |
|---|---|
| `com.rdkcentral.flutter.app.wonderous.json` | entryPoint and runtime dependency → `3.41.8` / `v3_41_8` |
| `com.rdkcentral.flutter.app.helloworld.json` | entryPoint and runtime dependency → `3.41.8` / `v3_41_8` |
| `com.rdkcentral.flutter.app.games.sample.multiplayer.json` | entryPoint and runtime dependency → `3.41.8` / `v3_41_8` |

---

### 3.4 New Files Added

| File | Description |
|---|---|
| `recipes-core/images/flutter-auto-3-41-8-runtime-bolt-image.bb` | New Yocto image recipe; installs `flutter-engine` + `flutter-auto` + `xkeyboard-config` |
| `package-configs/com.rdkcentral.flutter.runtime.flutter-auto.v3_41_8.json` | Bolt runtime descriptor; entryPoint `/usr/bin/flutter-auto-bolt.sh` |
| `package-configs/flutter.runtime.flutter-auto.v3_41_8.bolt.json` | Bolt build descriptor; maps to `flutter-auto-3-41-8-runtime-bolt-image` |
| `package-configs/com.rdkcentral.flutter.runtime.basic.v3_41_8.json` | Bolt basic runtime descriptor; entryPoint `/usr/bin/flutter-launcher-wayland` |
| `package-configs/flutter.runtime.basic.v3_41_8.bolt.json` | Bolt build descriptor for basic runtime see note below |
| `recipes-graphics/flutter-engine/files/flutter_version_upgrade_to_3_41_8.patch` | Patch to register 3.41.8 metadata in `meta-flutter` |


---

## 4. Errors / Warnings and Fixes

### Error 1 — GN Sysroot Assertion Failure

**Symptom:**
```
ERROR at //build/config/sysroot.gni:35:5: Assertion failed.
Missing sysroot (debian_bullseye_amd64-sysroot)
```

**Root Cause:**  
`tools/gn` defaults `use_default_linux_sysroot = true` and writes it into the generated `args.gn`,  
causing GN to assert that the Debian sysroot exists — which it never does in a Yocto cross-compile  
environment. The Yocto staging sysroot is already provided via `--target-sysroot ${STAGING_DIR_TARGET}`.

**Fix:**  
`tools/gn` (Flutter 3.41.8) exposes a built-in `--no-default-linux-sysroot` flag. Adding it to  
`GN_ARGS` in `flutter-engine_git.bbappend` ensures `use_default_linux_sysroot = false` is written  
into `args.gn` before GN runs — no patches required:

```bitbake
# recipes-graphics/flutter-engine/flutter-engine_git.bbappend
GN_ARGS:append = " --no-default-linux-sysroot"
```

**Alternative manual fix:**
```bash
build/linux/sysroot_scripts/install-sysroot.py --arch=x64
```

---

### Error 2 — XCB Header Not Found

**Symptom:**
```
fatal error: 'xcb/xcb.h' file not found
```

**Root Cause:**  
Flutter 3.41.8 engine requires X11/XCB libraries which were not in the Yocto build dependencies.

**Fix:**
```bitbake
# recipes-graphics/flutter-engine/flutter-engine_git.bbappend
DEPENDS += "libxcb libx11"

# conf/layer.conf
DISTRO_FEATURES:append = " opengl x11"
```

---

### Error 3 — Android SDK Check Triggered

**Symptom:**
```
Error: Android SDK could not be found
```

**Root Cause:**  
Flutter 3.41.8 tooling introduced platform detection logic that triggers Android SDK validation  
when no explicit target platform is set.

**Fix:**
```bitbake
# recipes-graphics/flutter-apps/gskinnerteam-flutter-wonderous-app-wonders_2.2.4.bbappend
FLUTTER_BUILD_ARGS = "bundle --target-platform=linux-x64"
```

---

### Error 4 — Native Asset Compilation Failure

**Symptom:**  
Build failure during native asset compilation for Flutter apps with native plugins.

**Root Cause:**  
Clang toolchain was not available in the Yocto sysroot for native asset compilation.

**Fix:**
```bitbake
DEPENDS += "clang-native"
```

---

## 5. Build & Validation Steps

### 5.1 Environment Setup

```bash
cd meta-bolt-flutter
source setup-environment
```

### 5.2 Build Runtime Image

```bash
# Single config (amd64 default)
bitbake flutter-auto-3-41-8-runtime-bolt-image

# Multi-config builds
bitbake mc:arm:flutter-auto-3-41-8-runtime-bolt-image
bitbake mc:arm64:flutter-auto-3-41-8-runtime-bolt-image
bitbake mc:amd64:flutter-auto-3-41-8-runtime-bolt-image
```

### 5.3 Build Bolt Packages

```bash
# Build and install runtime
bolt make flutter.runtime.flutter-auto.v3_41_8 --install

# Build application packages
bolt make flutter.app.wonderous --install
bolt make flutter.app.helloworld --install
```

### 5.4 Deploy and Run on Target Device

```bash
bolt push <sshuser@remoteip> com.rdkcentral.base+0.2.0
bolt push <sshuser@remoteip> com.rdkcentral.flutter.runtime.flutter-auto.v3_41_8+0.0.1
bolt push <sshuser@remoteip> com.rdkcentral.flutter.app.wonderous+0.1.0

bolt run <sshuser@remoteip> com.rdkcentral.flutter.app.wonderous+0.1.0
```

### 5.5 Validation Checklist

| Check | Status |
|---|---|
| `bitbake` build completes without errors |  Verified |
| Flutter engine (`libflutter_engine.so`) installed | Verified |
| Flutter Auto embedder starts with Wayland/EGL | Verified |
| Dart version aligned to 3.11.5 via engine |  Verified |
| Wonderous app launches on RDK-8 brcm VA |  Verified |
| Runtime validation on target device | Verified |

---

## 6. Future Recommendations

### 6.1 Upstream the meta-flutter patch

Rather than applying `flutter_version_upgrade_to_3_41_8.patch` at build time via `do_meta_flutter_patch`,  
contribute the Flutter 3.41.8 version metadata directly to the upstream  
[meta-flutter](https://github.com/meta-flutter/meta-flutter) repository.  
This eliminates the patch mechanism entirely for future consumers.

### 6.2 Create missing basic runtime image recipe

`flutter.runtime.basic.v3_41_8.bolt.json` references `flutter-3-41-8-basic-runtime-bolt-image`  
which has no `.bb` recipe. Either:
- Create `recipes-core/images/flutter-3-41-8-basic-runtime-bolt-image.bb`, or
- Remove the basic bolt config files if the basic runtime is not required

### 6.3 Automate version string replacement

Version strings appear in many files (`package-configs`, `recipes-core/images`, `README.md`, etc.).  
Consider a helper script to automate the find-and-replace across all relevant files:
```bash
./scripts/bump-flutter-version.sh 3.41.8 3.XX.X
```

### 6.4 Monitor patch compatibility on each upgrade

The following patches must be reviewed on every Flutter version bump:

| Patch | Risk |
|---|---|
| `flutter_version_upgrade_to_3_41_8.patch` | Will need a new version-specific patch each upgrade |

### 6.5 Pin `meta-flutter` dependency hash

Currently `deps/meta-flutter` tracks a branch. Pinning it to a specific commit hash  
prevents unexpected upstream changes from breaking the build between upgrades.
