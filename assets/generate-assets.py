#!/usr/bin/env python3
"""
SlozOS Asset Generator
Run once before the Docker build:
    python3 assets/generate-assets.py

Uses your images directly:
  assets/logo/slozos-logo.png        → your hand-drawn sloth sketch
  assets/wallpapers/slozos-default.png → your pixel art wallpaper

Produces:
  config/plymouth/slozos/logo.png    white-on-transparent sloth for boot screen
  config/plymouth/slozos/bar-fill.png
  config/plymouth/slozos/bar-track.png

Requires:  pip install Pillow
"""

from PIL import Image, ImageOps
import os

ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLY_D  = os.path.join(ROOT, "config", "plymouth", "slozos")
LOGO_SRC  = os.path.join(ROOT, "assets", "logo", "slozos-logo.png")
WALL_SRC  = os.path.join(ROOT, "assets", "wallpapers", "slozos-default.png")

os.makedirs(PLY_D, exist_ok=True)


def make_plymouth_logo():
    """
    Convert the hand-drawn sloth (black on white) into a white-on-transparent
    PNG for the Plymouth boot screen.
    """
    if not os.path.exists(LOGO_SRC):
        print(f"  WARNING: {LOGO_SRC} not found — skipping Plymouth logo.")
        return

    src = Image.open(LOGO_SRC).convert("RGBA")

    # Detect dark (sketch) pixels via grayscale luminance
    gray = src.convert("L")

    # Output: white where lines are dark, transparent elsewhere
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    pixels_src  = gray.load()
    pixels_out  = out.load()
    w, h = src.size

    for y in range(h):
        for x in range(w):
            lum = pixels_src[x, y]
            if lum < 160:          # dark = sketch line
                # map darkness to alpha (darker line → more opaque white)
                alpha = int((1 - lum / 160) * 255)
                pixels_out[x, y] = (255, 255, 255, alpha)

    # Crop to the bounding box of the drawn content
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)

    # Resize so it fits comfortably on a 1080p boot screen
    target_h = 320
    scale     = target_h / out.height
    new_size  = (int(out.width * scale), target_h)
    out = out.resize(new_size, Image.LANCZOS)

    dest = os.path.join(PLY_D, "logo.png")
    out.save(dest, "PNG")
    print(f"  ply logo    → {dest}  ({new_size[0]}×{new_size[1]})")


def make_bars():
    Image.new("RGBA", (1, 3), (0, 119, 255, 255)).save(
        os.path.join(PLY_D, "bar-fill.png"),  "PNG")
    Image.new("RGBA", (1, 3), (40, 40, 70, 140)).save(
        os.path.join(PLY_D, "bar-track.png"), "PNG")
    print(f"  bars        → {PLY_D}/bar-*.png")


def verify_sources():
    ok = True
    for path, label in [(LOGO_SRC, "logo"), (WALL_SRC, "wallpaper")]:
        if os.path.exists(path):
            size = os.path.getsize(path)
            img  = Image.open(path)
            print(f"  {label:10s} ✓  {img.size[0]}×{img.size[1]}  ({size//1024} KB)  {path}")
        else:
            print(f"  {label:10s} ✗  NOT FOUND: {path}")
            ok = False
    return ok


if __name__ == "__main__":
    print("SlozOS asset check...\n")
    if not verify_sources():
        print("\nFix the missing files above, then re-run.")
        raise SystemExit(1)

    print()
    make_plymouth_logo()
    make_bars()
    print("\nDone — ready to build.")
