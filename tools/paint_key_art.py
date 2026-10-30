#!/usr/bin/env python3
"""Grades the island renders from tools/render_key_art.gd into loading-screen art.

For each shot: a gentle painterly smoothing (edges stay crisp), soft bloom on the
highlights, a warm/cool split grade, a vignette, then a JPEG:
assets/branding/loading_<n>.jpg (1080x1920). Deterministic; needs Pillow + numpy.

Usage: python3 tools/paint_key_art.py [render dir, default build/key_art]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "branding")

# Order on the loading screen (loading_1 ... loading_6): Verdant Isle, then the five islands.
SHOTS = ["dawn", "ember", "lantern", "steps", "rope", "grove"]
LOOK = {
    #          warm   bloom  sat   vignette  lift (shadow tint)
    "dawn":  (0.16, 0.38, 1.06, 0.38, (0.10, 0.05, 0.08)),
    "glade": (0.06, 0.28, 1.08, 0.32, (0.02, 0.05, 0.08)),
    "falls": (0.08, 0.30, 1.06, 0.34, (0.03, 0.05, 0.08)),
    "ponds": (0.10, 0.32, 1.07, 0.34, (0.04, 0.05, 0.08)),
    "ember": (0.18, 0.40, 1.08, 0.40, (0.10, 0.03, 0.05)),
    "lantern": (0.04, 0.46, 1.04, 0.42, (0.02, 0.03, 0.10)),
    "steps": (0.08, 0.26, 1.05, 0.32, (0.04, 0.06, 0.04)),
    "rope": (0.06, 0.30, 1.08, 0.32, (0.02, 0.05, 0.08)),
    "grove": (0.02, 0.44, 1.06, 0.42, (0.06, 0.03, 0.10)),
}


def grade(img, look):
    warm, bloom, sat, vig, lift = look
    im = img.convert("RGB").filter(ImageFilter.ModeFilter(3)).filter(ImageFilter.SMOOTH_MORE)
    a = np.asarray(im).astype(np.float32) / 255.0
    # bloom: blurred highlights added back
    lum = a @ np.array([0.299, 0.587, 0.114], np.float32)
    hi = np.clip((lum - 0.62) / 0.38, 0, 1)[..., None] * a
    hi_img = Image.fromarray((hi * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(28))
    a = a + bloom * np.asarray(hi_img).astype(np.float32) / 255.0
    # saturation
    lum = (a @ np.array([0.299, 0.587, 0.114], np.float32))[..., None]
    a = lum + (a - lum) * sat
    # split grade: warm highlights, tinted shadows
    lum = np.clip(a @ np.array([0.299, 0.587, 0.114], np.float32), 0, 1)[..., None]
    a = a + warm * lum * np.array([0.10, 0.04, -0.06], np.float32)
    a = a + (1 - lum) ** 2 * np.array(lift, np.float32) * 0.6
    # vignette
    h, w = lum.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / np.sqrt(2)
    a = a * (1 - vig * np.clip(d - 0.25, 0, 1) ** 1.6)[..., None]
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "key_art")
    os.makedirs(OUT, exist_ok=True)
    for i, name in enumerate(SHOTS, 1):
        img = Image.open(os.path.join(src, name + ".png")).resize((1080, 1920), Image.LANCZOS)
        out = os.path.join(OUT, "loading_%d.jpg" % i)
        grade(img, LOOK[name]).save(out, quality=84, optimize=True, progressive=True)
        print("wrote", os.path.relpath(out, ROOT), os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
