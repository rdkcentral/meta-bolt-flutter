SUMMARY = "Flutter demo wonderous app"
#see https://github.com/meta-flutter/meta-flutter/blob/kirkstone/meta-flutter-apps/recipes-graphics/flutter-apps/third-party/gskinnerteam-flutter-wonderous-app-wonders_2.2.4.bb
#see https://github.com/gskinnerTeam/flutter-wonderous-app requires mouse for full functionality
inherit base-bolt-image

IMAGE_INSTALL:append = " gskinnerteam-flutter-wonderous-app-wonders-debug"

