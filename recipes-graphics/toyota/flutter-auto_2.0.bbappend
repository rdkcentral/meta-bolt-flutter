# --- Adding launcher script that allows to pass in right flutter launch app path coming from entryPoint in package-config of the separate app bolt package
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://flutter-auto-bolt.sh"

# ivi-homescreen patches
SRC_URI:append = " \
	file://0001-fix-xdg-client-ifdef.patch \
	file://0002-add-simple-shell-listener.patch"

# waypp patches
SRC_URI:append = " \
    file://0001-waypp-compile-w-o-xdg-output-enabled.patch;striplevel=1;patchdir=third_party/waypp \
    file://0002-waypp-add-simpleshell-protocol.patch;striplevel=1;patchdir=third_party/waypp \
    file://0003-waypp-compile-with-no-xdg-bd20d4db.patch;striplevel=1;patchdir=third_party/waypp"

# --- add PACKAGECONFIG option for simple-shell
PACKAGECONFIG[simple-shell] = "-DENABLE_SIMPLE_SHELL_CLIENT=ON,-DENABLE_SIMPLE_SHELL_CLIENT=OFF"

# Override PACKAGECONFIG for flutter-auto_2.0
# Keep only the minimal set needed: backend-wayland-egl and simple-shell for now to get up and running, we can expand afterwards.

PACKAGECONFIG = "\
    backend-wayland-egl \
    simple-shell \
    disable-plugins \
"
EXTRA_OECMAKE += "\
    -DBUILD_IVI_HOME_SCREEN_PLUGINS=OFF \
    -DBUILD_PLUGINS=OFF \
    -DENABLE_DBUS=OFF \
"
FILES:${PN}:append = " ${bindir}/flutter-auto-bolt.sh"

do_install:append() {
	install -m 0555 ${WORKDIR}/flutter-auto-bolt.sh ${D}${bindir}
}
