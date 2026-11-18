#!/usr/bin/env python3
"""Builds the app icon from scripts/icon-source.png with a USB-C cable plugged into
the bottom, and writes every macOS AppIcon size.

    python3 scripts/make-icon-from-image.py [path/to/source.png]
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "scripts/icon-source.png"
OUT = ROOT / "ScreenViewer/Assets.xcassets/AppIcon.appiconset"
K = 4                      # supersample factor
S = 1024 * K

base = Image.open(SRC).convert("RGBA").resize((S, S), Image.LANCZOS)

# Find the bottom edge of the tile along the centre line.
alpha = base.split()[3]
cx = S // 2
bottom = max(y for y in range(S) if alpha.getpixel((cx, y)) > 200)


def px(v):
    return int(round(v * K))


icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
cable = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(cable)

plug_w, plug_h = px(78), px(46)
plug_top = bottom - px(6)                 # tucks just under the tile edge
cable_w = px(30)

# Soft shadow under plug + cable
sh = Image.new("L", (S, S), 0)
ImageDraw.Draw(sh).rounded_rectangle((cx - plug_w // 2, plug_top + px(6), cx + plug_w // 2, plug_top + plug_h + px(6)),
                                     radius=px(12), fill=110)
ImageDraw.Draw(sh).rounded_rectangle((cx - cable_w // 2 + px(3), plug_top + plug_h, cx + cable_w // 2 + px(3), S),
                                     radius=cable_w // 2, fill=90)
icon.paste(Image.new("RGBA", (S, S), (40, 40, 60, 255)), (0, 0), sh.filter(ImageFilter.GaussianBlur(px(6))))

# Cable
d.rounded_rectangle((cx - cable_w // 2, plug_top + plug_h - px(10), cx + cable_w // 2, S + px(20)),
                    radius=cable_w // 2, fill=(250, 250, 252, 255), outline=(200, 202, 212, 255), width=px(2))
# Strain relief
d.rounded_rectangle((cx - px(22), plug_top + plug_h - px(8), cx + px(22), plug_top + plug_h + px(26)),
                    radius=px(10), fill=(244, 244, 248, 255), outline=(200, 202, 212, 255), width=px(2))
# Plug housing
d.rounded_rectangle((cx - plug_w // 2, plug_top, cx + plug_w // 2, plug_top + plug_h),
                    radius=px(14), fill=(255, 255, 255, 255), outline=(196, 198, 210, 255), width=px(2))
# Highlight line on the plug
d.line((cx - plug_w // 2 + px(12), plug_top + px(10), cx + plug_w // 2 - px(12), plug_top + px(10)),
       fill=(255, 255, 255, 255), width=px(3))

# Cable behind the tile, plug in front: draw cable layer, then tile, then plug only.
icon.alpha_composite(cable)
icon.alpha_composite(base)
plug_only = cable.crop((0, plug_top - px(4), S, plug_top + plug_h + px(30)))
icon.alpha_composite(plug_only, (0, plug_top - px(4)))

master = icon.resize((1024, 1024), Image.LANCZOS)

images = []
for pt in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        size = pt * scale
        name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
        master.resize((size, size), Image.LANCZOS).save(OUT / name)
        images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2))
master.save(ROOT / "icon-preview.png")
print("tile bottom at", bottom // K, "- wrote", len(images), "icon sizes")
