#!/usr/bin/env bash
# Builds the LUMA sign-in plugin for Android (plugins/luma_auth/android) into
# addons/luma_auth/bin/luma-auth.aar, which addons/luma_auth/luma_auth_plugin.gd adds to
# Gradle exports. Needs JDK 17+ and ANDROID_HOME. Gradle is downloaded and checksum-verified.
#   tools/ci/build_auth_plugin_android.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
GRADLE_VERSION=8.11.1
GRADLE_SHA256=f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6
CACHE="${HOME}/.cache/luma-gradle"
mkdir -p "$CACHE"
ZIP="$CACHE/gradle-$GRADLE_VERSION-bin.zip"
if ! echo "$GRADLE_SHA256  $ZIP" | sha256sum -c - >/dev/null 2>&1; then
  curl -fsSL -o "$ZIP" "https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip"
  echo "$GRADLE_SHA256  $ZIP" | sha256sum -c -
fi
[ -d "$CACHE/gradle-$GRADLE_VERSION" ] || unzip -q "$ZIP" -d "$CACHE"
GRADLE="$CACHE/gradle-$GRADLE_VERSION/bin/gradle"

SDK="${ANDROID_HOME:?ANDROID_HOME must point at the Android SDK}"
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null || true
"$SDK/cmdline-tools/latest/bin/sdkmanager" "platforms;android-35" "build-tools;34.0.0" >/dev/null

cd plugins/luma_auth/android
echo "sdk.dir=$SDK" > local.properties
for attempt in 1 2 3; do
  if "$GRADLE" --no-daemon --quiet assembleRelease; then break; fi
  [ "$attempt" = 3 ] && exit 1
  echo "gradle failed (attempt $attempt); retrying in 30 s"; sleep 30
done
cd - >/dev/null
mkdir -p addons/luma_auth/bin
cp plugins/luma_auth/android/build/outputs/aar/luma-auth-release.aar addons/luma_auth/bin/luma-auth.aar
ls -la addons/luma_auth/bin/luma-auth.aar
