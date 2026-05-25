do_install:append() {
    # Canonical provider for Yocto shlib resolver
    install -d ${D}${libdir}
    ln -sf ${datadir}/flutter/${FLUTTER_SDK_VERSION}/release/lib/libflutter_engine.so \
           ${D}${libdir}/libflutter_engine.so
}

SRC_URI:remove = " \
    file://0003-impeller-unnecessary-virtual-specifier.patch \
    file://0001-abseil-cpp-clang-compiler-warnin.patch;patchdir=engine/src/flutter/third_party/abseil-cpp \
"

# Disable the default debian sysroot check; Yocto provides its own via STAGING_DIR_TARGET
GN_ARGS:append = " --no-default-linux-sysroot"

do_meta_flutter_patch() {
    cd ${TOPDIR}/../deps/meta-flutter
    if grep -q "3.41.8" conf/include/flutter-version.inc; then
        bbnote "flutter_version_upgrade_to_3_41_8.patch already applied, skipping"
    else
        patch -N -p1 < ${THISDIR}/files/flutter_version_upgrade_to_3_41_8.patch || true
    fi
    find ${TOPDIR}/../deps/meta-flutter -name "*.rej" -delete
}

addtask meta_flutter_patch before do_fetch

# Tell Yocto that this file belongs to the main runtime package
FILES:${PN} += "${libdir}/libflutter_engine.so"

# Avoid QA warnings (because libflutter_engine.so is unversioned)
# Need symlink from /usr/lib/libflutter_engine.so,  allow unversioned .so symlink in main package iso -dev package
INSANE_SKIP:${PN} += "dev-so"

DEPENDS += "libxcb libx11"
