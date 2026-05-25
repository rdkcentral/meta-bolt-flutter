#our meta-bolt-distro sets GCC as default toolchain for compilation
#compilation of flutter-auto.bb with GCC is succeeding in our environment
#However flutter-auto.bb seems to prefer to use Clang toolchain for its own compilation as also required for flutter-engine
#however in our setup I see that despite settings in flutter-auto.bb like TOOLCHAIN = "clang" and other lang/llvm settings it compiles with GCC toolchain
#to fix and force Clang compilation for this recipe only use either 
#a)
#CC = "clang"
#CXX = "clang++"
#or 
#b)
#inherit clang


# In case we use GCC as toolchain iso clang/llvm
# below flag is clang-only warning flag
#CXXFLAGS:remove = "-Wno-deprecated-literal-operator"

# --- Remove the plugins repo from fetch sources ---
SRC_URI:remove = "gitsm://github.com/toyota-connected/ivi-homescreen-plugins.git;protocol=https;branch=v2.0;name=plugins;destsuffix=${S}/ivi-homescreen-plugins"

# --- Remove the plugins license file reference (it lives inside the removed repo) ---
LIC_FILES_CHKSUM:remove = "file://${S}/ivi-homescreen-plugins/LICENSE;md5=39ae29158ce710399736340c60147314"

# --- Replace upstream ivi-homescreen repo with temp fork that adds simple-shell support
SRC_URI:remove = "gitsm://github.com/toyota-connected/ivi-homescreen.git;protocol=https;branch=v2.0;name=homescreen"
SRC_URI:append = " gitsm://github.com/bcatrysse/ivi-homescreen.git;protocol=https;branch=v2.0_with_simple_shell;name=homescreen"
HOMESCREEN_COMMIT = "1cded8b60f1e095aeb7fafadc199272594c14d94" 

# --- Adding launcher script that allows to pass in right flutter launch app path coming from entryPoint in package-config of the separate app bolt package
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://flutter-auto-bolt.sh"

# --- Neutralize SRCREV metadata that refers to 'name=plugins' ---
# The base recipe appends '_plugins' to SRCREV_FORMAT and sets SRCREV_plugins.
# Clear the plugins SRCREV to avoid confusing bitbake's fetch logic.
SRCREV_plugins = ""
# Strip the '_plugins' suffix from SRCREV_FORMAT by removing the appended piece.
# NOTE: You must match EXACTLY what the .bb added ("_plugins")
SRCREV_FORMAT:remove = "_plugins"

# --- Optional: clean up any per-name checksum or other named URI attributes ---
SRC_URI[plugins.sha256sum] = ""
SRC_URI[plugins.md5sum] = ""

# --- add PACKAGECONFIG option for simple-shell
PACKAGECONFIG[simple-shell] = "-DENABLE_SIMPLE_SHELL_CLIENT=ON,-DENABLE_SIMPLE_SHELL_CLIENT=OFF"

# Override PACKAGECONFIG for flutter-auto_2.0
# Keep only the minimal set needed: backend-wayland-egl and simple-shell for now to get up and running, we can expand afterwards.

PACKAGECONFIG = "\
    backend-wayland-egl \
    simple-shell \
    disable-plugins \
"
PACKAGECONFIG:append = " \
    egl-3d \
    egl-transparency \
    egl-multisample \
    backend-wayland-drm \
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
