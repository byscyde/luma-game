#!/usr/bin/env python3
"""After tools/bake_merge_art.tscn: masks the face_*.png close-ups to a soft circle
(round portraits in dialogue and tasks) and lists every file of assets/merge/art in
assets/ASSET_MANIFEST.json (and drops entries whose file is gone).

    python3 tools/finish_merge_art.py
"""
import glob
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "merge", "art")
SOURCE = "Rendered by tools/bake_merge_art.tscn (SDF models in tools/art/, original work, SCYDE)"
LICENSE = "Proprietary - SCYDE (original work)"


def mask_faces():
    for path in glob.glob(os.path.join(ART, "face_*.png")):
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        ss = 4
        m = Image.new("L", (w * ss, h * ss), 0)
        ImageDraw.Draw(m).ellipse((ss, ss, w * ss - ss, h * ss - ss), fill=255)
        m = m.resize((w, h), Image.LANCZOS)
        a = Image.composite(im.getchannel("A"), Image.new("L", (w, h), 0), m)
        im.putalpha(a)
        im.save(path, optimize=True)


def sync_manifest():
    mpath = os.path.join(ROOT, "assets", "ASSET_MANIFEST.json")
    with open(mpath) as f:
        man = json.load(f)
    files = sorted(os.path.relpath(p, ROOT).replace(os.sep, "/") for p in glob.glob(os.path.join(ART, "*.png")))
    keep = [e for e in man["assets"] if not e["path"].startswith("assets/merge/art/") or e["path"] in files]
    listed = {e["path"] for e in keep}
    for p in files:
        if p not in listed:
            keep.append({"path": p, "source": SOURCE, "license": LICENSE})
    man["assets"] = keep
    with open(mpath, "w") as f:
        json.dump(man, f, indent=2)
        f.write("\n")
    print("%d merge art files listed" % len(files))


if __name__ == "__main__":
    mask_faces()
    sync_manifest()
