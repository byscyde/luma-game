#!/usr/bin/env bash
# Builds the LUMA sign-in GDExtension for iOS (plugins/luma_auth/ios) on macOS: godot-cpp at a
# pinned tag, a device library (arm64) and a simulator library (x86_64, like the rest of the
# simulator build), merged into addons/luma_auth/bin/libluma_auth.ios.xcframework, plus the
# .gdextension file that makes the iOS export link it.
#   tools/ci/build_auth_plugin_ios.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
GODOT_CPP_TAG=godot-4.5-stable
GODOT_CPP_COMMIT=e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77
SCONS_VERSION=4.8.1
SRC=plugins/luma_auth/ios

if [ ! -d "$SRC/godot-cpp/.git" ]; then
  git clone --quiet --depth 1 --branch "$GODOT_CPP_TAG" https://github.com/godotengine/godot-cpp "$SRC/godot-cpp"
fi
test "$(git -C "$SRC/godot-cpp" rev-parse HEAD)" = "$GODOT_CPP_COMMIT" || { echo "godot-cpp is not at the pinned commit"; exit 1; }

VENV="$HOME/.cache/luma-scons"
[ -x "$VENV/bin/scons" ] || { python3 -m venv "$VENV"; "$VENV/bin/pip" install --quiet "scons==$SCONS_VERSION"; }
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

cd "$SRC"
"$VENV/bin/scons" -j"$JOBS" platform=ios arch=arm64 ios_simulator=no ios_min_version=15.0 target=template_release
"$VENV/bin/scons" -j"$JOBS" platform=ios arch=x86_64 ios_simulator=yes ios_min_version=15.0 target=template_release

rm -rf bin/device bin/simulator && mkdir -p bin/device bin/simulator
libtool -static -o bin/device/libluma_auth.a \
  bin/libluma_auth.ios.template_release.arm64.a godot-cpp/bin/libgodot-cpp.ios.template_release.arm64.a
SIM_OURS=$(ls bin/libluma_auth.ios.template_release*x86_64*.a | head -n 1)
SIM_CPP=$(ls godot-cpp/bin/libgodot-cpp.ios.template_release*x86_64*.a | head -n 1)
libtool -static -o bin/simulator/libluma_auth.a "$SIM_OURS" "$SIM_CPP"

OUT="$ROOT/addons/luma_auth/bin"
mkdir -p "$OUT"
rm -rf "$OUT/libluma_auth.ios.xcframework"
xcodebuild -create-xcframework -library bin/device/libluma_auth.a -library bin/simulator/libluma_auth.a \
  -output "$OUT/libluma_auth.ios.xcframework"
cp luma_auth.gdextension "$ROOT/addons/luma_auth/luma_auth.gdextension"
ls -la "$OUT/libluma_auth.ios.xcframework"
