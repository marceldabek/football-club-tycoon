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
(serve assets/ui/flags/keyed on 127.0.0.1:8765, MCP upload_image the changed
files) and copy the returned ids into src/shared/FlagImages.luau.

The icons go further than Nations.luau's frame-drawable data where a flag
would otherwise be wrong or ambiguous: Wales gets its dragon, Northern Ireland
the Ulster banner's star, hand and crown (not a second England), Portugal its
armillary sphere on the stripe line, Brazil its globe, Ghana a star and the
USA a proper canton.
"""
import math
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
    dict(code="WAL", dir="h", colors=[WHITE, GREEN], emblem="dragon", emblemColor=RED),
    dict(code="NIR", dir="h", colors=[WHITE], emblem="ulster", emblemColor=(200, 16, 46)),
    dict(code="IRL", dir="v", colors=[(22, 155, 98), WHITE, (255, 136, 62)]),
    dict(code="FRA", dir="v", colors=[(0, 38, 153), WHITE, (237, 41, 57)]),
    dict(code="ESP", dir="h", colors=[(198, 11, 30), (255, 196, 0), (198, 11, 30)], sizes=[1, 2, 1]),
    dict(code="ITA", dir="v", colors=[(0, 146, 70), WHITE, (206, 43, 55)]),
    dict(code="GER", dir="h", colors=[BLACK, (221, 0, 0), (255, 206, 0)]),
    dict(code="NED", dir="h", colors=[(174, 28, 40), WHITE, (33, 70, 139)]),
    dict(code="POR", dir="v", colors=[(0, 102, 0), (255, 0, 0)], sizes=[2, 3], emblem="sphere", emblemColor=YELLOW),
    dict(code="BRA", dir="h", colors=[(0, 155, 58)], emblem="globe", emblemColor=(254, 223, 0)),
    dict(code="ARG", dir="h", colors=[SKY, WHITE, SKY], emblem="disc", emblemColor=(246, 180, 14)),
    dict(code="NGA", dir="v", colors=[(0, 135, 81), WHITE, (0, 135, 81)]),
    dict(code="GHA", dir="h", colors=[(206, 17, 38), YELLOW, (0, 107, 63)], emblem="star", emblemColor=BLACK),
    dict(code="POL", dir="h", colors=[WHITE, (220, 20, 60)]),
    dict(code="JPN", dir="h", colors=[WHITE], emblem="disc", emblemColor=(188, 0, 45)),
    dict(code="USA", dir="h", colors=[(178, 34, 52), WHITE] * 3 + [(178, 34, 52)], emblem="canton", emblemColor=(60, 59, 110)),
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


def star_points(cx, cy, r_out, r_in, points, turn=-90):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(turn + i * 180 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# A passant dragon, drawn in a 100 x 70 box (the flag's 10:7) facing left.
# Chunky on purpose: at card size (~40 px wide) it has to read as a beast with
# wings and a tail, not as detail.
DRAGON = [
    [(29, 36), (20, 24), (26, 18), (40, 32)],  # neck
    [(9, 22), (17, 14), (28, 14), (31, 20), (22, 22), (15, 27)],  # head, jaw open
    [(23, 15), (27, 7), (30, 16)],  # horn
    [(42, 34), (40, 20), (45, 4), (51, 15), (58, 2), (62, 15), (71, 6), (68, 24), (64, 34)],  # wings
    [(70, 36), (84, 38), (91, 30), (93, 19), (97, 18), (96, 27), (92, 38), (84, 46), (70, 46)],  # tail
    [(93, 21), (88, 13), (99, 12)],  # tail tip
    [(36, 40), (27, 44), (23, 51), (28, 52), (31, 47), (41, 45)],  # raised forepaw
    [(40, 44), (37, 59), (44, 59), (47, 46)],  # standing foreleg
    [(61, 44), (59, 59), (66, 59), (69, 44)],  # hind legs
    [(68, 43), (72, 57), (78, 57), (75, 41)],
]
DRAGON_BODY = (52, 40, 22, 9)  # centre x, y, radius x, y



def emblem(img, draw, kind, color):
    cx, cy = W / 2, H / 2
    sx, sy = W / 100, H / 70
    if kind == "cross":
        draw.rectangle([0, cy - H * 0.1, W, cy + H * 0.1], fill=color)
        draw.rectangle([cx - W * 0.065, 0, cx + W * 0.065, H], fill=color)
    elif kind == "ulster":
        # St George's cross with the white star, red hand and crown on top
        emblem(img, draw, "cross", color)
        draw.polygon(star_points(cx, cy + H * 0.05, H * 0.27, H * 0.15, 6), fill=WHITE)
        draw.ellipse([cx - H * 0.08, cy - H * 0.03, cx + H * 0.08, cy + H * 0.13], fill=color)
        cw, top = W * 0.1, cy - H * 0.36
        draw.polygon([(cx - cw, top + H * 0.14), (cx - cw, top), (cx - cw * 0.5, top + H * 0.07), (cx, top - H * 0.02),
                      (cx + cw * 0.5, top + H * 0.07), (cx + cw, top), (cx + cw, top + H * 0.14)], fill=YELLOW)
    elif kind == "dragon":
        dy = H * 0.02
        for poly in DRAGON:
            draw.polygon([(x * sx, y * sy + dy) for x, y in poly], fill=color)
        bx, by, rx, ry = DRAGON_BODY
        draw.ellipse([(bx - rx) * sx, (by - ry) * sy + dy, (bx + rx) * sx, (by + ry) * sy + dy], fill=color)
    elif kind == "disc":
        r = W * 0.13
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    elif kind == "sphere":
        # the armillary sphere sits on the green/red line, a shield in front
        x, r = W * 0.4, H * 0.27
        draw.ellipse([x - r, cy - r, x + r, cy + r], outline=color, width=max(int(H * 0.06), 3))
        draw.line([(x - r, cy), (x + r, cy)], fill=color, width=max(int(H * 0.04), 2))
        sw = H * 0.12
        draw.rounded_rectangle([x - sw, cy - sw * 1.1, x + sw, cy + sw * 1.2], radius=sw * 0.6, fill=WHITE, outline=(200, 0, 0), width=max(int(H * 0.035), 2))
    elif kind == "diamond":
        r = W * 0.24
        draw.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=color)
    elif kind == "globe":
        emblem(img, draw, "diamond", color)
        r = H * 0.22
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 39, 118))
        draw.line([(cx - r, cy - r * 0.15), (cx + r, cy + r * 0.2)], fill=WHITE, width=max(int(H * 0.04), 2))
    elif kind == "star":
        draw.polygon(star_points(cx, cy + H * 0.02, H * 0.2, H * 0.08, 5), fill=color)
    elif kind == "canton":
        # blue canton over the top four of seven stripes, rows of white stars
        cw, ch = W * 0.4, H * 4 / 7
        draw.rectangle([0, 0, cw, ch], fill=color)
        for row in range(4):
            for col in range(5):
                x = cw * (col + 0.5 + (0.25 if row % 2 else -0.05)) / 5.3
                y = ch * (row + 0.5) / 4
                d = H * 0.025
                draw.ellipse([x - d, y - d, x + d, y + d], fill=WHITE)


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
        emblem(img, draw, kind, spec["emblemColor"])

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
