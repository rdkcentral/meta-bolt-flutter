# Hello world app to start with
#

SUMMARY = "hello_world_app"
DESCRIPTION = "Flutter hello world example"
AUTHOR = "Google"
HOMEPAGE = "https://github.com/flutter/flutter/blob/master/examples/hello_world/README.md"
BUGTRACKER = "None"
SECTION = "graphics"

LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=ee7acc875d764bd7af8cde74d2de71cd"
#LIC_FILES_CHKSUM = "file://../license-destdir/common-licenses/BSD-3-Clause;md5=550794465ba0ec5312d6919e203a55f9"
SRCREV = "dd37b21edfedcb993cb91358a74e9bc7e8f5e551"
SRC_URI = "git://github.com/bcatrysse/flutter_hello_world.git;branch=develop;protocol=https"

S = "${WORKDIR}/git"

PUBSPEC_APPNAME = "hello_world"
FLUTTER_APPLICATION_INSTALL_SUFFIX = "flutter-samples-hello-world-app"
PUBSPEC_IGNORE_LOCKFILE = "1"
FLUTTER_APPLICATION_PATH = "hello_world"

inherit flutter-app

do_compile[network] = "1"
