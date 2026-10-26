#!/usr/bin/env python3
"""Asset and reference validation.

* every res:// path referenced from scripts, scenes and project files exists
* every file under assets/ is listed in assets/ASSET_MANIFEST.json with a
  source and licence (provenance), and every manifest entry exists
* icon dimensions match platform requirements; audio is mono/stereo 16-bit PCM
* nothing in assets/ is unreasonably large for mobile

    python3 tools/validate_assets.py          # exit 1 on any error
"""
import json
import os
import re
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_REF = re.compile(r'res://([A-Za-z0-9_\-./@]+)')
SCAN_EXT = (".gd", ".tscn", ".tres", ".cfg", ".godot")
SKIP_DIRS = {".git", ".godot", "build", "android", "__pycache__"}
ICON_SIZES = {
    "assets/icons/icon.png": (1024, 1024),
    "assets/icons/icon_192.png": (192, 192),
    "assets/icons/adaptive_foreground.png": (432, 432),
    "assets/icons/adaptive_background.png": (432, 432),
    "assets/branding/scyde_splash.png": (1080, 1080),
}
MAX_ASSET_BYTES = 4 * 1024 * 1024


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def main():
    errors = []
    refs = 0
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(SCAN_EXT) or fn.endswith(".import"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT)
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            for m in RES_REF.finditer(text):
                target = m.group(1).rstrip(".")
                if target.endswith("/") or "%" in target or target.endswith(".translation") \
                        or target.split("/")[0] == "build":
                    continue  # directories, format strings, generated translations, output paths
                refs += 1
                if not os.path.exists(os.path.join(ROOT, target)):
                    errors.append("%s references missing res://%s" % (rel, target))
    manifest_path = os.path.join(ROOT, "assets", "ASSET_MANIFEST.json")
    with open(manifest_path) as f:
        manifest = json.load(f)
    listed = {}
    for entry in manifest["assets"]:
        for k in ("path", "source", "license"):
            if not entry.get(k):
                errors.append("manifest entry %r lacks '%s'" % (entry.get("path"), k))
        listed[entry["path"]] = entry
        if not os.path.exists(os.path.join(ROOT, entry["path"])):
            errors.append("manifest lists missing file %s" % entry["path"])
    for dirpath, _, filenames in os.walk(os.path.join(ROOT, "assets")):
        for fn in filenames:
            if fn.endswith((".import", ".uid")) or fn == "ASSET_MANIFEST.json":
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
            if rel not in listed:
                errors.append("asset without provenance entry: %s" % rel)
            size = os.path.getsize(os.path.join(ROOT, rel))
            if size > MAX_ASSET_BYTES:
                errors.append("asset too large for mobile budget: %s (%d bytes)" % (rel, size))
            if rel.endswith(".wav"):
                try:
                    with wave.open(os.path.join(ROOT, rel)) as w:
                        if w.getsampwidth() != 2 or w.getnchannels() not in (1, 2):
                            errors.append("%s: expected 16-bit mono/stereo PCM" % rel)
                except wave.Error as e:
                    errors.append("%s: unreadable wav (%s)" % (rel, e))
    for rel, want in ICON_SIZES.items():
        got = png_size(os.path.join(ROOT, rel))
        if got != want:
            errors.append("%s is %s, expected %s" % (rel, got, want))
    for e in errors:
        print("ERROR", e)
    print("%d res:// references checked, %d manifest entries, %d errors" % (refs, len(listed), len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
