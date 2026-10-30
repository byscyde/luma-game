#!/usr/bin/env bash
# Sets up the realistic character renderer (tools/art/render_people.py):
# Blender 5.1 as a Python module (bpy, needs Python 3.13), MPFB 2 (MakeHuman for
# Blender) and the CC0 MakeHuman system assets + faceunits (smiles).
#   tools/art/setup_people_renderer.sh [dir]     # default dir: ~/.cache/luma-people
#   then: ~/.cache/luma-people/venv/bin/python tools/art/render_people.py
set -euo pipefail
DIR="${1:-$HOME/.cache/luma-people}"
mkdir -p "$DIR"
cd "$DIR"
[ -x venv/bin/python ] || python3.13 -m venv venv
venv/bin/pip install -q "bpy==5.1.2"
fetch() { [ -f "$2" ] || curl -fsSL --retry 4 -o "$2" "$1"; }
fetch https://files.makehumancommunity.org/plugins/mpfb2-20261027.zip mpfb2.zip
fetch https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip system_assets_cc0.zip
fetch https://files.makehumancommunity.org/functional/faceunits01.zip faceunits01.zip
venv/bin/python - "$DIR" <<'PY'
import os, shutil, sys, zipfile
import bpy, addon_utils
d = sys.argv[1]
ext = os.path.join(bpy.utils.user_resource("EXTENSIONS"), "user_default")
os.makedirs(ext, exist_ok=True)
if not os.path.exists(os.path.join(ext, "mpfb")):
    zipfile.ZipFile(os.path.join(d, "mpfb2.zip")).extractall(os.path.join(d, "mpfb_src"))
    shutil.copytree(os.path.join(d, "mpfb_src", "mpfb"), os.path.join(ext, "mpfb"))
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
from bl_ext.user_default.mpfb.services.locationservice import LocationService
data = LocationService.get_user_data()
for z in ("system_assets_cc0.zip", "faceunits01.zip"):
    zipfile.ZipFile(os.path.join(d, z)).extractall(data)
print("MPFB data:", data)
PY
echo "ready: $DIR/venv/bin/python tools/art/render_people.py"
