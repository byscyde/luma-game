#!/usr/bin/env python3
"""Generates the LUMA app icon set (original artwork, procedurally drawn).

Outputs assets/icons/:
  icon.png                 1024x1024 master (iOS App Store, project icon)
  icon_192.png             legacy Android launcher icon
  adaptive_foreground.png  432x432 Android adaptive foreground (safe zone 66%)
  adaptive_background.png  432x432 Android adaptive background
  splash.png               boot splash emblem
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons")

TEAL_TOP = (36, 98, 112)
TEAL_BOT = (16, 46, 56)
WATER = (60, 198, 208)
WATER_DEEP = (31, 147, 168)
WATER_LIGHT = (181, 244, 241)
LEAF = (109, 190, 91)
LEAF_DARK = (63, 143, 74)
GOLD = (242, 193, 78)


def gradient(size, top, bot):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return img


def drop_polygon(cx, cy, r, n=120):
    pts = []
    for i in range(n + 1):
        a = math.pi * i / n  # bottom half circle
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    pts.append((cx, cy - r * 1.75))  # tip
    return pts


def emblem(size, scale=1.0):
    """Water drop with a sprouting leaf pair and a soft glow."""
    S = size * 4  # supersample
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy, r = S / 2, S * 0.58, S * 0.25 * scale
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - r * 1.6, cy - r * 1.9, cx + r * 1.6, cy + r * 1.3], fill=GOLD + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.05))
    img.alpha_composite(glow)
    d.polygon(drop_polygon(cx, cy, r * 1.04), fill=WATER_DEEP + (255,))
    d.polygon(drop_polygon(cx - r * 0.04, cy - r * 0.04, r * 0.94), fill=WATER + (255,))
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx - r * 0.2, cy - r * 0.2], fill=WATER_LIGHT + (220,))
    # sprout
    stem_top = (cx, cy - r * 0.15)
    d.line([(cx, cy + r * 0.55), stem_top], fill=LEAF_DARK + (255,), width=int(r * 0.12))

    def leaf(base, angle, length, width, col):
        pts = []
        for i in range(41):
            t = i / 40
            x = t * length
            y = math.sin(t * math.pi) * width
            pts.append((x, y))
        for i in range(41):
            t = 1 - i / 40
            pts.append((t * length, -math.sin(t * math.pi) * width * 0.35))
        ca, sa = math.cos(angle), math.sin(angle)
        return [(base[0] + x * ca - y * sa, base[1] + x * sa + y * ca) for x, y in pts]

    d.polygon(leaf(stem_top, math.radians(-35), r * 0.95, r * 0.32, LEAF), fill=LEAF + (255,))
    d.polygon(leaf(stem_top, math.radians(-150), r * 0.75, -r * 0.26, LEAF_DARK), fill=LEAF_DARK + (255,))
    return img.resize((size, size), Image.LANCZOS)


def rounded_bg(size):
    bg = gradient(size, TEAL_TOP, TEAL_BOT)
    # gentle light from the top
    light = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    ld.ellipse([-size * 0.2, -size * 0.6, size * 1.2, size * 0.5], fill=(255, 240, 210, 40))
    light = light.filter(ImageFilter.GaussianBlur(size * 0.08))
    bg.alpha_composite(light)
    return bg


def main():
    os.makedirs(OUT, exist_ok=True)
    master = rounded_bg(1024)
    master.alpha_composite(emblem(1024, 1.0))
    master.convert("RGB").save(os.path.join(OUT, "icon.png"))  # iOS icons must be opaque
    master.convert("RGB").resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon_192.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(emblem(432, 0.66))
    fg.save(os.path.join(OUT, "adaptive_foreground.png"))
    rounded_bg(432).convert("RGB").save(os.path.join(OUT, "adaptive_background.png"))
    splash = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    splash.alpha_composite(emblem(512, 0.9))
    splash.save(os.path.join(OUT, "splash.png"))
    for f in sorted(os.listdir(OUT)):
        print("wrote assets/icons/" + f)


if __name__ == "__main__":
    main()
