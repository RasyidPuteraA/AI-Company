#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SINGLES = ROOT / "apps/dashboard/public/assets/limezu/modern-office/4_Modern_Office_singles/32x32"
OUT_DIR = ROOT / "apps/dashboard/public/assets/limezu/maps"
OUT = OUT_DIR / "office-map-v2.png"
OUT_DIR.mkdir(parents=True, exist_ok=True)

TILE = 32
W, H = 768, 544

def load_single(tile_id):
    p = SINGLES / f"Modern_Office_Singles_32x32_{tile_id}.png"
    if p.exists():
        return Image.open(p).convert("RGBA")
    return None

ASSETS = {
    "computer": load_single(92),
    "server": load_single(284),
    "chair": load_single(109),
    "table": load_single(156),
    "board": load_single(240),
    "plant": load_single(38),
    "decor": load_single(174),
}

img = Image.new("RGBA", (W, H), (68, 66, 92, 255))
draw = ImageDraw.Draw(img)

outside = (68, 66, 92, 255)
wall = (246, 247, 250, 255)
wall_dark = (31, 35, 56, 255)
floor = (138, 144, 142, 255)
floor_alt = (128, 135, 133, 255)
floor_lower = (150, 146, 138, 255)
grid = (106, 112, 120, 255)
desk = (116, 102, 82, 255)
desk_dark = (52, 45, 50, 255)
label_bg = (23, 27, 44, 215)
label_fg = (235, 241, 255, 255)

draw.rectangle((0, 0, W, H), fill=outside)

# L-shape office like reference.
top_outer = (48, 24, 736, 348)
bottom_outer = (196, 332, 736, 520)

for box in [top_outer, bottom_outer]:
    x1, y1, x2, y2 = box
    draw.rectangle((x1 - 5, y1 - 5, x2 + 5, y2 + 5), fill=wall_dark)
    draw.rectangle(box, fill=wall)

top_floor = (64, 40, 720, 332)
bottom_floor = (212, 348, 720, 504)

draw.rectangle(top_floor, fill=floor)
draw.rectangle(bottom_floor, fill=floor_lower)

def draw_grid(box, a, b):
    x1, y1, x2, y2 = box
    for y in range(y1, y2, TILE):
        for x in range(x1, x2, TILE):
            color = a if ((x // TILE) + (y // TILE)) % 2 == 0 else b
            draw.rectangle((x, y, min(x + TILE - 1, x2), min(y + TILE - 1, y2)), fill=color)
            draw.rectangle((x, y, min(x + TILE - 1, x2), min(y + TILE - 1, y2)), outline=grid)

draw_grid(top_floor, floor, floor_alt)
draw_grid(bottom_floor, floor_lower, (140, 137, 130, 255))

# Open connection between top and bottom.
draw.rectangle((212, 320, 310, 362), fill=floor_lower)
draw.rectangle((520, 320, 640, 362), fill=floor_lower)

# Re-outline walls after openings.
for box in [top_outer, bottom_outer]:
    draw.rectangle(box, outline=wall_dark, width=3)

# Window panels
for x in [88, 180, 302, 440, 570]:
    draw.rectangle((x, 28, x + 64, 42), fill=(218, 225, 238, 255))
    draw.rectangle((x, 28, x + 64, 42), outline=(88, 96, 112, 255))
for x in [250, 392, 560]:
    draw.rectangle((x, 336, x + 64, 350), fill=(218, 225, 238, 255))
    draw.rectangle((x, 336, x + 64, 350), outline=(88, 96, 112, 255))

def label(txt, x, y):
    w = max(42, len(txt) * 8 + 16)
    draw.rectangle((x, y, x + w, y + 20), fill=label_bg)
    draw.text((x + 7, y + 5), txt, fill=label_fg)

def prop(name, x, y, scale=1):
    asset = ASSETS.get(name)
    if not asset:
        return
    if scale != 1:
        asset = asset.resize((asset.width * scale, asset.height * scale), Image.Resampling.NEAREST)
    img.alpha_composite(asset, (x, y))

def workstation(x, y, wide=False):
    w = 118 if wide else 92
    draw.rectangle((x, y, x + w, y + 48), fill=desk, outline=desk_dark, width=3)
    prop("computer", x + 14, y + 10)
    prop("decor", x + w - 38, y + 10)
    prop("chair", x + 26, y + 54)

# Top office cluster.
label("PM", 84, 70)
workstation(92, 108, wide=True)

label("ENGINEER", 332, 70)
workstation(292, 108, wide=True)
workstation(420, 108, wide=True)

label("QA", 612, 70)
workstation(590, 108, wide=True)

# Second open-office row, to make it feel populated like reference.
workstation(96, 226)
workstation(252, 226)
workstation(408, 226)
workstation(564, 226)

# Top wall furniture/decor.
prop("server", 72, 76)
prop("board", 306, 50)
prop("plant", 672, 68)
prop("plant", 688, 240)
prop("decor", 176, 252)

# Bottom left DevOps.
label("DEVOPS", 236, 358)
draw.rectangle((232, 404, 354, 462), fill=desk, outline=desk_dark, width=3)
prop("server", 224, 390)
prop("server", 256, 390)
prop("computer", 300, 414)
prop("chair", 326, 466)
prop("plant", 214, 466)

# Bottom middle Meeting.
label("MEETING", 414, 358)
draw.rectangle((402, 394, 558, 464), fill=(113, 96, 74, 255), outline=desk_dark, width=3)
prop("table", 458, 412)
prop("chair", 370, 400)
prop("chair", 560, 400)
prop("chair", 452, 472)
prop("board", 568, 370)

# Bottom right Owner.
label("OWNER", 622, 358)
draw.rectangle((612, 404, 704, 462), fill=desk, outline=desk_dark, width=3)
prop("computer", 628, 414)
prop("chair", 650, 466)
prop("plant", 700, 454)
prop("decor", 690, 386)

# Small corridor / office details.
draw.rectangle((64, 330, 202, 342), fill=wall_dark)
draw.rectangle((310, 330, 520, 342), fill=wall_dark)
draw.rectangle((640, 330, 720, 342), fill=wall_dark)

draw.rectangle((354, 42, 510, 56), fill=(55, 63, 82, 255))
draw.text((374, 44), "AI COMPANY OS HQ", fill=(190, 198, 210, 255))

# Final border
draw.rectangle((0, 0, W - 1, H - 1), outline=(31, 35, 56, 255), width=4)

img.save(OUT)
print(f"Rendered denser reference-inspired office map: {OUT}")
print(f"Size: {W}x{H}")
