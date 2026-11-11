#!/usr/bin/env python3
"""Export Roku channel tile assets using the unmodified, frozen Rocha+ icon.

Usage: python3 tools/export_roku_icon.py
Requires: pip install Pillow
Source never modified. Do not run with an unofficial replacement asset.
"""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "branding/rocha_plus_icon.webp"
OUT = ROOT / "build" / "roku-icon"
# Roku's SD/HD channel tiles use 4:3 aspect ratio.
SIZES = {"mm_icon_focus_hd.png": (540, 405), "mm_icon_focus_sd.png": (290, 218)}
BACKGROUND = (10, 7, 24, 255)

def main():
    if not SOURCE.is_file():
        raise SystemExit(f"Official icon not found: {SOURCE}")
    OUT.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE) as original:
        artwork = original.convert("RGBA")
        for filename, (width, height) in SIZES.items():
            canvas = Image.new("RGBA", (width, height), BACKGROUND)
            # Preserve the entire official icon (no cropping, recoloring or logo edits).
            margin = round(min(width, height) * .075)
            resized = artwork.copy()
            resized.thumbnail((width - 2 * margin, height - 2 * margin), Image.Resampling.LANCZOS)
            canvas.alpha_composite(resized, ((width - resized.width)//2, (height - resized.height)//2))
            output = OUT / filename
            canvas.convert("RGB").save(output, "PNG", optimize=True)
            print(f"{output}: {width}x{height}")
    print("These are channel tile assets. Roku package integration remains a separate step.")

if __name__ == "__main__":
    main()
