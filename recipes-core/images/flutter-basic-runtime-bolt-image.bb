SUMMARY = "Basic Flutter runtime bolt image"
# this runtime includes the flutter-engine and a basic flutter launcher (no embedder like flutter-auto)
# flutter-engine from https://github.com/meta-flutter/meta-flutter/tree/master/recipes-graphics/flutter-engine
# Basic launcher uses flutter-launcher-wayland for general-purpose Flutter app support

inherit base-bolt-image

IMAGE_INSTALL += "flutter-engine-release"
IMAGE_INSTALL += "flutter-launcher-wayland"

# xkeyboard-config needed to solve flutter runtime error: xkbcommon: ERROR: failed to add default include path /usr/share/X11/xkb
IMAGE_INSTALL:append = " xkeyboard-config"
