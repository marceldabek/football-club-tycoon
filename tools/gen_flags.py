"""Generate the 18 nation flag icons for player cards (#18a).

FlagView used to draw flags out of Frames at runtime (stripes + one emblem).
That reads as hand-made and the shapes (saltire angle, disc size, ...) drift
from real flags. This renders the same flag DATA (kept in sync with
src/shared/Nations.luau by hand -- there is no cheap way to parse the Luau
color constants back out) as a small, consistent icon set instead: one size,
one corner radius, one border, PNG with alpha.

    python tools/gen_flags.py

Writes assets/ui/flags/keyed/<code>.png (lowercase) and a contact_sheet.png.
Upload with the same localhost-http + upload_image path as the league crests
(see [[football-club-tycoon-league-crests]]); keep the id map in
src/shared/FlagImages.luau (tools/write_flag_images.py writes it from the
upload_image result).
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "flags", "keyed")

W, H = 300, 210  # 10:7, the box FlagView.draw fills
RADIUS = 16
BORDER = Image.new("RGBA", (1, 1), (18, 18, 22, 235)).getpixel((0, 0))
BORDER_W = 3

WHITE, BLACK = (255, 255, 255), (20, 20, 20)
RED, GREEN, YELLOW = (206, 17, 38), (0, 140, 69), (252, 209, 22)
SKY = (116, 172, 223)

# Transcribed from src/shared/Nations.luau (Nations.LIST) -- keep in sync by hand.
NATIONS = [
    dict(code="ENG", dir="h", colors=[WHITE], emblem="cross", emblemColor=RED),
    dict(code="SCO", dir="h", colors=[(0, 94, 184)], emblem="saltire", emblemColor=WHITE),
    dict(code="WAL", dir="h", colors=[WHITE, GREEN], emblem="disc", emblemColor=RED),
    dict(code="NIR", dir="h", colors=[WHITE], emblem="cross", emblemColor=(200, 16, 46)),
    dict(code="IRL", dir="v", colors=[(22, 155, 98), WHITE, (255, 136, 62)]),
    dict(code="FRA", dir="v", colors=[(0, 38, 153), WHITE, (237, 41, 57)]),
    dict(code="ESP", dir="h", colors=[(198, 11, 30), (255, 196, 0), (198, 11, 30)], sizes=[1, 2, 1]),
    dict(code="ITA", dir="v", colors=[(0, 146, 70), WHITE, (206, 43, 55)]),
    dict(code="GER", dir="h", colors=[BLACK, (221, 0, 0), (255, 206, 0)]),
    dict(code="NED", dir="h", colors=[(174, 28, 40), WHITE, (33, 70, 139)]),
    dict(code="POR", dir="v", colors=[(0, 102, 0), (255, 0, 0)], sizes=[2, 3], emblem="disc", emblemColor=YELLOW),
    dict(code="BRA", dir="h", colors=[(0, 155, 58)], emblem="diamond", emblemColor=(254, 223, 0)),
    dict(code="ARG", dir="h", colors=[SKY, WHITE, SKY], emblem="disc", emblemColor=(246, 180, 14)),
    dict(code="NGA", dir="v", colors=[(0, 135, 81), WHITE, (0, 135, 81)]),
    dict(code="GHA", dir="h", colors=[(206, 17, 38), YELLOW, (0, 107, 63)], emblem="disc", emblemColor=BLACK),
    dict(code="POL", dir="h", colors=[WHITE, (220, 20, 60)]),
    dict(code="JPN", dir="h", colors=[WHITE], emblem="disc", emblemColor=(188, 0, 45)),
    dict(code="USA", dir="h", colors=[(178, 34, 52), WHITE, (178, 34, 52), WHITE, (178, 34, 52)], emblem="canton", emblemColor=(60, 59, 110)),
]


def stripes(draw, dir, colors, sizes):
    sizes = sizes or [1] * len(colors)
    total = sum(sizes)
    at = 0.0
    for color, share in zip(colors, sizes):
        frac = share / total
        if dir == "v":
            x0, x1 = at * W, (at + frac) * W
            draw.rectangle([x0, 0, x1, H], fill=color)
        else:
            y0, y1 = at * H, (at + frac) * H
            draw.rectangle([0, y0, W, y1], fill=color)
        at += frac


def emblem(draw, kind, color):
    cx, cy = W / 2, H / 2
    if kind == "cross":
        draw.rectangle([0, cy - H * 0.1, W, cy + H * 0.1], fill=color)
        draw.rectangle([cx - W * 0.065, 0, cx + W * 0.065, H], fill=color)
    elif kind == "disc":
        r = W * 0.13
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    elif kind == "diamond":
        r = W * 0.24
        draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=color)
    elif kind == "canton":
        draw.rectangle([W * 0.06, H * 0.12, W * 0.42, H * 0.58], fill=color)


def saltire(img, color):
    """A real diagonal cross: two rotated bars alpha-composited onto `img`."""
    length = int(W * 1.4)
    thick = max(int(H * 0.17), 6)
    for sign in (1, -1):
        bar = Image.new("RGBA", (length, thick), (0, 0, 0, 0))
        ImageDraw.Draw(bar).rectangle([0, 0, length, thick], fill=(*color, 255))
        rot = bar.rotate(sign * -35, expand=True, resample=Image.BICUBIC)
        x = int(W / 2 - rot.width / 2)
        y = int(H / 2 - rot.height / 2)
        img.alpha_composite(rot, (x, y))


def draw_flag(spec):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    stripes(draw, spec["dir"], spec["colors"], spec.get("sizes"))
    kind = spec.get("emblem")
    if kind == "saltire":
        saltire(img, spec["emblemColor"])
    elif kind:
        emblem(draw, kind, spec["emblemColor"])

    # rounded corners + border, so every icon reads as one consistent set
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=RADIUS, fill=255)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    border = ImageDraw.Draw(out)
    border.rounded_rectangle([1, 1, W - 2, H - 2], radius=RADIUS, outline=BORDER, width=BORDER_W)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    cols = 6
    rows = (len(NATIONS) + cols - 1) // cols
    cell = 120
    sheet = Image.new("RGBA", (cell * cols, cell * rows), (60, 60, 66, 255))
    for i, spec in enumerate(NATIONS):
        icon = draw_flag(spec)
        icon.save(os.path.join(OUT, f"{spec['code'].lower()}.png"))
        thumb = icon.resize((int(cell * 0.9), int(cell * 0.9 * H / W)), Image.LANCZOS)
        sheet.alpha_composite(thumb, ((i % cols) * cell + 6, (i // cols) * cell + 6))
    sheet.convert("RGB").save(os.path.join(ROOT, "assets", "ui", "flags", "contact_sheet.png"))
    print(f"{len(NATIONS)} flags written to {OUT}")


if __name__ == "__main__":
    main()
