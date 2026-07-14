# flutter-engine 3.35.x series overrides for meta-bolt-flutter
#
# meta-flutter revision: f7087e6ea32dcd6eeaeb9ffdb84e2173e63c6eec
# This is the meta-flutter commit that rolls Flutter to 3.35.7.
# See: https://github.com/meta-flutter/meta-flutter/commit/f7087e6ea32dcd6eeaeb9ffdb84e2173e63c6eec
#
# FLUTTER_SDK_TAG="3.35.7" is set by setup-environment and passed through to
# meta-flutter which resolves the engine SRCREV from releases_linux.json.
#
# Override TMP_OUT_DIR to use the correct function (mirrors 3.38 behaviour).
TMP_OUT_DIR = "${@get_gn_tmp_out_dir_relative(d)}"

# 0001-memcpy-void-cast.patch in f7087e6e is missing patchdir=engine/src.
# The file lives at engine/src/flutter/third_party/skia/... but without patchdir
# quilt searches under ${S}/flutter/... which does not exist.
SRC_URI:remove = "file://0001-memcpy-void-cast.patch"
SRC_URI:append = " file://0001-memcpy-void-cast.patch;patchdir=engine/src"
