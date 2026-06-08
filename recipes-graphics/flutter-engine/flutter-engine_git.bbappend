# split the ouput into packages per flutter build mode
PACKAGE_BEFORE_PN += "${PN}-debug ${PN}-profile ${PN}-release ${PN}-jit_release"

FILES:${PN}-debug = "${FLUTTER_ENGINE_INSTALL_PREFIX}/debug/*"
FILES:${PN}-profile = "${FLUTTER_ENGINE_INSTALL_PREFIX}/profile/*"
FILES:${PN}-release = "${FLUTTER_ENGINE_INSTALL_PREFIX}/release/*"
FILES:${PN}-jit_release = "${FLUTTER_ENGINE_INSTALL_PREFIX}/release/*"

RDEPENDS:${PN}-debug += "${PN}"
RDEPENDS:${PN}-profile += "${PN}"
RDEPENDS:${PN}-release += "${PN}"
RDEPENDS:${PN}-jit_release += "${PN}"

# each target can only depend on single flutter build mode
RCONFLICTS:${PN}-debug += "${PN}-profile ${PN}-release"
RCONFLICTS:${PN}-profile += "${PN}-debug ${PN}-release"
RCONFLICTS:${PN}-release += "${PN}-debug ${PN}-profile"
RCONFLICTS:${PN}-jit_release += "${PN}-debug ${PN}-profile ${PN}-release"

ALLOW_EMPTY:${PN} = "1"
