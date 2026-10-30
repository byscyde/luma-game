#!/usr/bin/env python3
"""Builds LUMA's shipped brand images from the owner-supplied masters.

Inputs (not shipped; art/source has a .gdignore):
  art/source/luma_app_icon_master.jpg   1024x1024 app icon art (rounded corners on white)
  art/source/scyde_logo_reference.png   small SCYDE wordmark used as the reference

Outputs (assets/icons, assets/branding):
  icons/icon.png                1024 full-bleed square, no alpha (iOS/App Store, project icon)
  icons/icon_192.png            legacy Android launcher icon
  icons/adaptive_foreground.png 432 Android adaptive foreground (art scaled into the 66% safe zone)
  icons/adaptive_background.png 432 Android adaptive background (deep night blue)
  branding/scyde_splash.png     SCYDE wordmark on the logo background, for the boot splash
  branding/scyde_wordmark.png   transparent SCYDE wordmark for the in-game logo screen
  branding/luma_key_art.png     icon art with rounded corners on transparent, for the loading screen

The SCYDE wordmark is redrawn at high resolution (the reference is only 98x49) with
Inter Display ExtraBold (SIL OFL 1.1; installed system font, used only to rasterise) plus the
logo's yellow dot. Requires Pillow + numpy. Output is deterministic.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "source")
ICONS = os.path.join(ROOT, "assets", "icons")
BRAND = os.path.join(ROOT, "assets", "branding")

LOGO_BG = (12, 15, 20)        # sampled from the reference logo
LOGO_DOT = (255, 215, 106)
NIGHT = (20, 26, 60)          # icon background tone
INTER_BOLD = [
    "/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf",
    "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf",
    "/usr/share/fonts/opentype/inter/Inter-Bold.otf",
]


def full_bleed_icon():
    """Replace the white outside the rounded corners with the surrounding art colour."""
    im = Image.open(os.path.join(SRC, "luma_app_icon_master.jpg")).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32)
    bright = a.min(axis=2) > 150
    # flood the bright corner regions only (never bright art in the middle)
    mask = np.zeros(bright.shape, bool)
    h, w = bright.shape
    for sy, sx in [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]:
        stack = [(sy, sx)]
        while stack:
            y, x = stack.pop()
            if y < 0 or x < 0 or y >= h or x >= w or mask[y, x] or not bright[y, x]:
                continue
            if min(y, h - 1 - y) > 260 or min(x, w - 1 - x) > 260:
                continue
            mask[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    m_img = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
    m = np.asarray(m_img) > 0
    # normalised convolution: blur only the art pixels, divide by blurred weights
    keep = (~m).astype(np.float32)
    rad = 40
    def blur(ch):
        return np.asarray(Image.fromarray(np.clip(ch, 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(rad))).astype(np.float32)
    num = np.stack([blur(a[..., c] * keep) for c in range(3)], -1)
    den = blur(keep * 255.0)[..., None] / 255.0
    fill = num / np.maximum(den, 1e-3)
    fill[den[..., 0] < 0.02] = NIGHT
    out = np.where(m[..., None], fill, a)
    # soften the seam between the art edge and the fill
    soft = np.asarray(m_img.filter(ImageFilter.GaussianBlur(2))).astype(np.float32)[..., None] / 255.0
    out = a * (1 - soft) + out * soft
    out = np.where(m[..., None], fill, out)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def font(size):
    for p in INTER_BOLD:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    sys.exit("Inter Display Bold not found (install fonts-inter)")


def wordmark(height_px):
    """'scyde' in white with the square yellow dot, on transparent; height = x-height box."""
    f = font(height_px)
    text = "scyde"
    l, t, r, b = f.getbbox(text)
    dot = round(height_px * 0.2)
    gap = round(height_px * 0.06)
    W = r - l + gap + dot + 8
    H = b - t + 8
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((4 - l, 4 - t), text, font=f, fill=(255, 255, 255, 255))
    base = 4 - t + f.getbbox("s")[3]
    x0 = 4 + (r - l) + gap
    d.rectangle([x0, base - dot, x0 + dot - 1, base - 1], fill=LOGO_DOT + (255,))
    return img


def main():
    os.makedirs(ICONS, exist_ok=True)
    os.makedirs(BRAND, exist_ok=True)
    icon = full_bleed_icon()
    icon.save(os.path.join(ICONS, "icon.png"), optimize=True)
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(ICONS, "icon_192.png"), optimize=True)
    bg = Image.new("RGB", (432, 432), NIGHT)
    bg.save(os.path.join(ICONS, "adaptive_background.png"), optimize=True)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = rounded(icon.resize((300, 300), Image.LANCZOS), 60)
    fg.alpha_composite(inner, (66, 66))
    fg.save(os.path.join(ICONS, "adaptive_foreground.png"), optimize=True)
    rounded(icon.resize((768, 768), Image.LANCZOS), 150).save(os.path.join(BRAND, "luma_key_art.png"), optimize=True)
    wm = wordmark(220)
    wm.save(os.path.join(BRAND, "scyde_wordmark.png"), optimize=True)
    splash = Image.new("RGB", (1080, 1080), LOGO_BG)
    small = wm.resize((380, wm.height * 380 // wm.width), Image.LANCZOS)
    splash.paste(small, ((1080 - small.width) // 2, (1080 - small.height) // 2), small)
    splash.save(os.path.join(BRAND, "scyde_splash.png"), optimize=True)
    old = os.path.join(ICONS, "splash.png")
    if os.path.exists(old):
        os.remove(old)
    print("brand assets written")


if __name__ == "__main__":
    main()
