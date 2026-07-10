#
# Copyright (c) 20XX Whoever owns that. All rights reserved.
#

SUMMARY = "My app"
DESCRIPTION = "description"
AUTHOR = "me"
HOMEPAGE = "None"
BUGTRACKER = "None"
SECTION = "graphics"

LICENSE = "CLOSED"

SRC_URI = "git://github.com/some_org/my_app.git;lfs=0;branch=master;protocol=https;rev=3cd6acfc335c52cca90465749b9630f2a2ddf7d7"
SRC_URI[sha256sum] = "1cdfc21d7e8fad6e2888ecf3565c2d72c1bce2df3526859565af0b3e6ed4100a"

PUBSPEC_APPNAME = "my_app"
FLUTTER_APPLICATION_INSTALL_SUFFIX = "myapp"
FLUTTER_APPLICATION_PATH = ""

inherit flutter-app

do_compile[network] = "1"

S = "${WORKDIR}/git"
