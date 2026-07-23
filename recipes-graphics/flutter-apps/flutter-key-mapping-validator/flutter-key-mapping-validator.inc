# Key Mapping Validator Flutter App (shared)
#
SUMMARY = "key_mapping_validator"
DESCRIPTION = "Flutter key mapping validation app for RDK devices"
AUTHOR = "krishnan-nair-infosys"
HOMEPAGE = "https://github.com/krishnan-nair-infosys/key_mapping_validator"
BUGTRACKER = "https://github.com/krishnan-nair-infosys/key_mapping_validator/issues"
SECTION = "graphics"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=421eabdde8ad31134feff02518f91a30"

SRCREV = "433dd293b4848727b6551d3e11e2cd827d53ca27"
SRC_URI = "git://github.com/krishnan-nair-infosys/key_mapping_validator.git;branch=main;protocol=https \
           file://config.toml \
"

S = "${WORKDIR}/git"

PUBSPEC_APPNAME = "key_mapping_validator"
FLUTTER_APPLICATION_INSTALL_SUFFIX = "flutter-key-mapping-validator"
PUBSPEC_IGNORE_LOCKFILE = "1"
FLUTTER_APPLICATION_PATH = "."

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit flutter-app

do_compile[network] = "1"
export HOME = "${WORKDIR}"

do_install:append() {
    runtime_root="${STAGING_DIR_TARGET}${datadir}/flutter/${FLUTTER_SDK_VERSION}"
    if [ ! -d "$runtime_root" ]; then
        bbfatal "Flutter runtime directory not found: $runtime_root"
    fi
    for runtime_dir in "$runtime_root"/*; do
        [ -d "$runtime_dir" ] || continue
        FLUTTER_RUNTIME_MODE="$(basename "$runtime_dir")"
        install -d ${D}${FLUTTER_INSTALL_DIR}/${FLUTTER_SDK_VERSION}/${FLUTTER_RUNTIME_MODE}
        install -m 0644 ${WORKDIR}/config.toml \
            ${D}${FLUTTER_INSTALL_DIR}/${FLUTTER_SDK_VERSION}/${FLUTTER_RUNTIME_MODE}/config.toml
    done
}
