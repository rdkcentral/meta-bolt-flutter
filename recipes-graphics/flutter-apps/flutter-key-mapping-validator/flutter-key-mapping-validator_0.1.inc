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

SRCREV = "a677be573be33846fb341f12f41bac28d954463b"
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
inherit flutter-bolt-app

do_compile[network] = "1"
export HOME = "${WORKDIR}"

do_install:append() {
    install -d "${D}${datadir}/flutter/${FLUTTER_APPLICATION_INSTALL_SUFFIX}/${FLUTTER_SDK_VERSION}/${FLUTTER_APP_RUNTIME_MODES}"
    install -m 0644 "${WORKDIR}/config.toml" \
        "${D}${datadir}/flutter/${FLUTTER_APPLICATION_INSTALL_SUFFIX}/${FLUTTER_SDK_VERSION}/${FLUTTER_APP_RUNTIME_MODES}/config.toml"
}
