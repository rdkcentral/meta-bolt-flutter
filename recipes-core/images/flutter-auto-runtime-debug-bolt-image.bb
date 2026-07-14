SUMMARY = "Flutter runtime bolt image"
# this runtime includes the flutter-engine version 3.38.3/3.35.7/3.32.2 and flutter-auto embedder with wayland-egl/gles2 backend that can launch associated flutter RDK bolt apps
# flutter-engine from https://github.com/meta-flutter/meta-flutter/tree/master/recipes-graphics/flutter-engine
# flutter-auto embedder maintained by AGL/toyota, see https://github.com/toyota-connected/ivi-homescreen
# We adapted it to support RDK simple-shell, see code in https://github.com/bcatrysse/ivi-homescreen/tree/v2.0_with_simple_shell
# status 27 March 2026 by BartC : is compiling successfully, successful bolt runtime test done on RDK-8 brcm VA with wonderous flutter app

inherit base-bolt-image

IMAGE_INSTALL += "flutter-engine-debug"
IMAGE_INSTALL += "flutter-auto"

#need to add to solve flutter-auto runtime error: xkbcommon: ERROR: failed to add default include path /usr/share/X11/xkb
IMAGE_INSTALL:append = " xkeyboard-config"
