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
PEOPLE_SOURCE = ("Rendered by tools/art/render_people.py in Blender from MakeHuman models: MPFB 2, "
                 "makehuman_system_assets (CC0) and faceunits01 (CC0)")
PEOPLE_LICENSE = "Proprietary - SCYDE (render); MakeHuman assets CC0"
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
    import re
    people = set()
    rp = os.path.join(ROOT, "tools", "art", "render_people.py")
    if os.path.exists(rp):
        people = set(re.findall(r'^    "([a-z]+)": dict\(', open(rp).read(), re.M))
    keep = [e for e in man["assets"] if not e["path"].startswith("assets/merge/art/")]
    for p in files:
        who = os.path.basename(p)[:-4].split("_", 1)[-1]
        realistic = os.path.basename(p).startswith(("bust_", "face_")) and who in people
        keep.append({"path": p, "source": PEOPLE_SOURCE if realistic else SOURCE,
                     "license": PEOPLE_LICENSE if realistic else LICENSE})
    man["assets"] = keep
    with open(mpath, "w") as f:
        json.dump(man, f, indent=2)
        f.write("\n")
    print("%d merge art files listed" % len(files))


if __name__ == "__main__":
    mask_faces()
    sync_manifest()
