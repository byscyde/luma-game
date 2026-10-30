#!/usr/bin/env bash
# Installs the pinned Godot editor (and optionally export templates) for CI.
# Downloads are verified against SHA-512 sums pinned in this file, so a
# tampered or truncated download fails the build instead of being used.
#   tools/ci/install_godot.sh linux|macos [--templates]
# Exposes GODOT (path to the binary) via $GITHUB_ENV when running in Actions.
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_TAG="${GODOT_VERSION}-stable"
BASE="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"
SHA_LINUX="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
SHA_MACOS="38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca"
SHA_TEMPLATES="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"

PLATFORM="${1:?usage: install_godot.sh linux|macos [--templates]}"
WANT_TEMPLATES="${2:-}"
CACHE="${GODOT_CACHE:-$HOME/.cache/luma-godot}"
mkdir -p "$CACHE"

fetch() { # url dest sha512
  local url="$1" dest="$2" sum="$3"
  if [ -f "$dest" ] && echo "$sum  $dest" | shasum -a 512 -c - >/dev/null 2>&1; then
    echo "cached: $(basename "$dest")"; return
  fi
  echo "downloading $(basename "$dest")"
  curl -fsSL --retry 4 --retry-delay 3 -o "$dest.part" "$url"
  echo "$sum  $dest.part" | shasum -a 512 -c - >/dev/null || { echo "checksum mismatch for $url"; rm -f "$dest.part"; exit 1; }
  mv "$dest.part" "$dest"
}

case "$PLATFORM" in
  linux)
    ZIP="Godot_v${GODOT_TAG}_linux.x86_64.zip"
    fetch "$BASE/$ZIP" "$CACHE/$ZIP" "$SHA_LINUX"
    mkdir -p "$CACHE/bin"
    unzip -o -q "$CACHE/$ZIP" -d "$CACHE/bin"
    GODOT_BIN="$CACHE/bin/Godot_v${GODOT_TAG}_linux.x86_64"
    TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
    ;;
  macos)
    ZIP="Godot_v${GODOT_TAG}_macos.universal.zip"
    fetch "$BASE/$ZIP" "$CACHE/$ZIP" "$SHA_MACOS"
    mkdir -p "$CACHE/bin"
    unzip -o -q "$CACHE/$ZIP" -d "$CACHE/bin"
    GODOT_BIN="$CACHE/bin/Godot.app/Contents/MacOS/Godot"
    TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable"
    ;;
  *) echo "unknown platform $PLATFORM"; exit 1 ;;
esac
chmod +x "$GODOT_BIN"
"$GODOT_BIN" --headless --version

if [ "$WANT_TEMPLATES" = "--templates" ]; then
  TPZ="Godot_v${GODOT_TAG}_export_templates.tpz"
  fetch "$BASE/$TPZ" "$CACHE/$TPZ" "$SHA_TEMPLATES"
  mkdir -p "$TEMPLATE_DIR" "$CACHE/tpl"
  unzip -o -q "$CACHE/$TPZ" -d "$CACHE/tpl"
  cp -R "$CACHE/tpl/templates/." "$TEMPLATE_DIR/"
  rm -rf "$CACHE/tpl"
  test "$(cat "$TEMPLATE_DIR/version.txt")" = "${GODOT_VERSION}.stable" || { echo "template version mismatch"; exit 1; }
  echo "templates installed to $TEMPLATE_DIR"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "GODOT=$GODOT_BIN" >> "$GITHUB_ENV"
fi
echo "GODOT=$GODOT_BIN"
