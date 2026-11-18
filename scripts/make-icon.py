#!/usr/bin/env python3
"""Draws the app icon (original artwork) and writes every macOS AppIcon size.

    python3 scripts/make-icon.py
"""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4096                      # supersampled canvas; final master is 1024
k = S / 1024
OUT = Path(__file__).resolve().parent.parent / "ScreenViewer/Assets.xcassets/AppIcon.appiconset"


def px(v):
    return int(round(v * k))


def vgradient(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        g.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return g.resize((w, h))


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))


def blob(img, box, color, blur):
    """Soft colour blob for a pastel mesh-style gradient."""
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([px(v) for v in box], fill=255)
    img.paste(Image.new("RGBA", (S, S), color), (0, 0), m.filter(ImageFilter.GaussianBlur(px(blur))))


# Tile with soft drop shadow
tile = (px(100), px(92), px(924), px(916))
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle(
    (tile[0], tile[1] + px(14), tile[2], tile[3] + px(14)), radius=px(186), fill=(0, 0, 0, 90))
canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(px(18))))
tile_mask = rounded_mask((S, S), tile, px(186))

# Tile background: light frosted lilac
canvas.paste(vgradient((S, S), (246, 243, 252), (222, 220, 240)).convert("RGBA"), (0, 0), tile_mask)

layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)

# Cable leaving the bottom of the tile
d.rounded_rectangle((px(496), px(760), px(528), px(960)), radius=px(16), fill=(255, 255, 255, 255))
d.rounded_rectangle((px(496), px(760), px(528), px(960)), radius=px(16), outline=(190, 192, 210, 255), width=px(3))
d.rounded_rectangle((px(476), px(740), px(548), px(804)), radius=px(14), fill=(214, 216, 228, 255))

# Phone body (white, thin grey rim)
body = (px(342), px(178), px(682), px(770))
body_shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(body_shadow).rounded_rectangle(
    (body[0], body[1] + px(12), body[2], body[3] + px(12)), radius=px(70), fill=(60, 50, 110, 70))
layer.alpha_composite(body_shadow.filter(ImageFilter.GaussianBlur(px(22))))
d.rounded_rectangle(body, radius=px(70), fill=(255, 255, 255, 255))
d.rounded_rectangle(body, radius=px(70), outline=(196, 198, 214, 255), width=px(4))

# Screen: pastel mesh gradient (peach, rose, lavender, sky)
screen = (px(360), px(196), px(664), px(752))
mesh = Image.new("RGBA", (S, S), (250, 214, 196, 255))
blob(mesh, (300, 150, 640, 420), (255, 190, 140, 255), 80)    # peach, top
blob(mesh, (330, 380, 620, 650), (250, 140, 165, 255), 90)   # rose, middle
blob(mesh, (480, 300, 760, 640), (170, 165, 245, 255), 90)   # lavender, right
blob(mesh, (380, 560, 720, 860), (110, 190, 245, 255), 90)   # sky, bottom
layer.paste(mesh, (0, 0), rounded_mask((S, S), screen, px(52)))

# Glossy highlight across the top of the screen
gm = Image.new("L", (S, S), 0)
ImageDraw.Draw(gm).ellipse((px(250), px(80), px(780), px(420)), fill=80)
gm = ImageChops.multiply(gm.filter(ImageFilter.GaussianBlur(px(40))), rounded_mask((S, S), screen, px(52)))
layer.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), gm)

# Two small "mirror" arrows on the screen (screen -> Mac)
w = px(22)
d.rounded_rectangle((px(452), px(430), px(572), px(530)), radius=px(16), outline=(255, 255, 255, 255), width=w)
d.rounded_rectangle((px(490), px(468), px(610), px(568)), radius=px(16), fill=(255, 255, 255, 235))

r, g, b, a = layer.split()
canvas.alpha_composite(Image.merge("RGBA", (r, g, b, ImageChops.multiply(a, tile_mask))))

edge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(edge).rounded_rectangle(tile, radius=px(186), outline=(255, 255, 255, 120), width=px(4))
canvas.alpha_composite(edge)

master = canvas.resize((1024, 1024), Image.LANCZOS)

# Write all macOS slots
images = []
for pt in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        size = pt * scale
        name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
        master.resize((size, size), Image.LANCZOS).save(OUT / name)
        images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2))
master.save(OUT.parent.parent.parent / "icon-preview.png")
print("wrote", len(images), "icon sizes")
