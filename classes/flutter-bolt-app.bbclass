# flutter-bolt-app.bbclass
#
# Creates a 'current' symlink under FLUTTER_INSTALL_DIR pointing to the
# versioned Flutter SDK directory, e.g.:
#
#   /usr/share/flutter/<app>/current  ->  3.32.2
#
# This allows bolt app package configs to use a stable, version-free
# entryPoint like /usr/share/flutter/<app>/current/release/ regardless
# of the Flutter SDK version in use.

do_install:append() {
    ln -sfn ${FLUTTER_SDK_VERSION} ${D}${FLUTTER_INSTALL_DIR}/current
}

FILES:${PN}:append = " ${FLUTTER_INSTALL_DIR}/current"
