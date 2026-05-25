S = "${WORKDIR}/git"

# Ensure clang is available for native-asset compilation
DEPENDS += "clang-native"

# Force building for Linux target to avoid Android SDK checks
# Use a Flutter-allowed value for --target-platform
FLUTTER_BUILD_ARGS = "bundle --target-platform=linux-x64"

