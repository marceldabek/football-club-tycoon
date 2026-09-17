"""Generate the low-part terrace textures (backlog X12).

Writes 512x512 PNGs into assets/kit/_export/textures/ plus the upload list
assets/kit/_export/upload_textures.txt for tools/upload_kit.py --images:

    terrace_front_a.png  one house bay, red brick, navy door, flat sash window
    terrace_front_b.png  orange-red brick, bottle-green door (door on the right)
    terrace_front_c.png  dark brown brick, burgundy door, bay window drawn flat
    terrace_back.png     plainer rear wall, small windows, no door
    slate_roof.png       grey-blue slate courses, seamless both ways
    brick_plain.png      seamless brick for gable ends (orange-red; TerraceBuilder tints it per row)

Each front covers pavement (bottom) to eaves (top) of one house and tiles
seamlessly left-right. Reference: assets/references/RiveremereWestdale.png and
RivermereNorthfields.png. Shapes are drawn big and flat on purpose so they read
at street distance on a phone; this is not a photo texture.

Usage:  python tools/kit/make_facades.py   [--preview]
Deterministic (fixed seeds), so re-running gives identical files.
"""
import os, random, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXPORT = os.path.join(ROOT, "assets", "kit", "_export")
OUT = os.path.join(EXPORT, "textures")

N = 512  # output size
S = 2  # supersample factor; drawn at 1024 then box-reduced (keeps tiling exact)
W = N * S

FILES = [
    "terrace_front_a.png",
    "terrace_front_b.png",
    "terrace_front_c.png",
    "terrace_back.png",
    "slate_roof.png",
    "brick_plain.png",
]

# ----------------------------------------------------------------- palettes

PALETTES = {
    "red": {"brick": (150, 60, 44), "mortar": (186, 172, 152), "dark": (104, 42, 34), "light": (172, 84, 60)},
    "orange": {"brick": (178, 92, 54), "mortar": (196, 182, 160), "dark": (132, 64, 40), "light": (196, 116, 72)},
    "brown": {"brick": (112, 64, 46), "mortar": (164, 150, 132), "dark": (78, 44, 34), "light": (136, 86, 62)},
}
STONE = (214, 204, 182)
STONE_SHADE = (170, 160, 140)
WHITE = (240, 238, 230)
FRAME_SHADE = (196, 194, 188)
PIPE = (34, 34, 38)
PLINTH = (70, 58, 60)
DOORS = {"navy": (30, 44, 82), "green": (24, 72, 48), "burgundy": (104, 26, 38)}
BRASS = (196, 160, 80)


def clamp(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


def jitter(rng, c, amt):
    k = rng.uniform(-amt, amt)
    return tuple(clamp(c[i] + k + rng.uniform(-amt * 0.3, amt * 0.3)) for i in range(3))


# All drawing coordinates below are in 512-space; R() scales to the canvas.
def R(x0, y0, x1, y1):
    return [int(round(x0 * S)), int(round(y0 * S)), int(round(x1 * S)) - 1, int(round(y1 * S)) - 1]


def rect(d, x0, y0, x1, y1, fill):
    if x1 > x0 and y1 > y0:
        d.rectangle(R(x0, y0, x1, y1), fill=fill)


def shade(img, x0, y0, x1, y1, amount, colour=(0, 0, 0)):
    """Blend a box towards `colour` (shadows, grime, angled bay lights)."""
    box = tuple(int(round(v * S)) for v in (max(0, x0), max(0, y0), min(N, x1), min(N, y1)))
    if box[2] <= box[0] or box[3] <= box[1]:
        return
    region = img.crop(box)
    img.paste(Image.blend(region, Image.new("RGB", region.size, colour), amount), box)


# ------------------------------------------------------------------- bricks

def bricks(img, rng, pal, courses=40, per_row=12, burnt=0.1, pale=0.05):
    """Stretcher-bond brick wall, seamless both ways (even course count)."""
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, W], fill=pal["mortar"])
    ch = W / courses
    bw = W / per_row
    joint = 2 * S
    tones = {}
    for r in range(courses):
        for i in range(per_row):
            roll = rng.random()
            base = pal["dark"] if roll < burnt else pal["light"] if roll < burnt + pale else pal["brick"]
            tones[(r, i)] = jitter(rng, base, 9)
    for r in range(courses):
        y0 = round(r * ch)
        y1 = round((r + 1) * ch) - joint
        off = bw / 2 if r % 2 else 0
        for i in range(-1, per_row + 1):
            x0 = round(i * bw + off)
            x1 = round((i + 1) * bw + off) - joint
            if x1 <= 0 or x0 >= W:
                continue
            c = tones[(r, i % per_row)]
            d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=c)
            d.rectangle([x0, y1 - S, x1 - 1, y1 - 1], fill=mix(c, (0, 0, 0), 0.18))  # lower arris
            d.rectangle([x0, y0, x1 - 1, y0 + S - 1], fill=mix(c, (255, 255, 255), 0.08))


# ---------------------------------------------------------------- features

def glass(img, x0, y0, x1, y1, curtain=None, frosted=False):
    """Dark blue-grey pane: vertical gradient, one diagonal sky reflection."""
    w, h = int(round((x1 - x0) * S)), int(round((y1 - y0) * S))
    if w <= 0 or h <= 0:
        return
    top, bottom = ((150, 160, 168), (178, 186, 190)) if frosted else ((34, 44, 58), (96, 112, 130))
    pane = Image.new("RGB", (w, h))
    pd = ImageDraw.Draw(pane)
    for yy in range(h):
        pd.line([(0, yy), (w, yy)], fill=mix(top, bottom, yy / max(1, h - 1)))
    if not frosted:
        streak = Image.new("RGB", (w, h), (150, 170, 188))
        mask = Image.new("L", (w, h), 0)
        md = ImageDraw.Draw(mask)
        md.polygon([(w * 0.25, 0), (w * 0.55, 0), (w * 0.1, h), (-w * 0.2, h)], fill=70)
        md.polygon([(w * 0.7, 0), (w * 0.8, 0), (w * 0.45, h), (w * 0.35, h)], fill=40)
        pane.paste(streak, (0, 0), mask)
    if curtain:
        cw = max(1, int(w * 0.22))
        pd.rectangle([0, 0, cw, h], fill=curtain)
        pd.rectangle([w - cw, 0, w, h], fill=mix(curtain, (0, 0, 0), 0.12))
    img.paste(pane, (int(round(x0 * S)), int(round(y0 * S))))


def sash(img, x0, y0, x1, y1, lintel=True, bars=True, curtain=None, frosted=False, sill=True):
    """White-framed sliding sash in a brick reveal, stone lintel and sill."""
    d = ImageDraw.Draw(img)
    if lintel:
        rect(d, x0 - 8, y0 - 18, x1 + 8, y0, STONE)
        rect(d, x0 - 8, y0 - 3, x1 + 8, y0, STONE_SHADE)
    rect(d, x0, y0, x1, y1, (46, 34, 32))  # reveal
    rect(d, x0 + 4, y0 + 6, x1, y1, WHITE)  # frame (reveal shadow shows top-left)
    gx0, gy0, gx1, gy1 = x0 + 11, y0 + 13, x1 - 7, y1 - 7
    mid = (gy0 + gy1) / 2
    glass(img, gx0, gy0, gx1, mid - 3, curtain=None, frosted=frosted)
    glass(img, gx0, mid + 3, gx1, gy1, curtain=curtain, frosted=frosted)
    d = ImageDraw.Draw(img)
    rect(d, gx0 - 2, mid - 3, gx1 + 2, mid + 3, WHITE)  # meeting rail
    rect(d, gx0, mid + 3, gx1, mid + 5, FRAME_SHADE)
    if bars:
        cx = (gx0 + gx1) / 2
        rect(d, cx - 2, gy0, cx + 2, gy1, WHITE)
    shade(img, x0 + 4, y0 + 6, x1, y0 + 12, 0.25)  # frame head in shadow
    if sill:
        d = ImageDraw.Draw(img)
        rect(d, x0 - 7, y1, x1 + 7, y1 + 10, STONE)
        rect(d, x0 - 7, y1, x1 + 7, y1 + 2, (232, 224, 204))
        shade(img, x0 - 5, y1 + 10, x1 + 5, y1 + 16, 0.35)


def door(img, x0, y0, x1, y1, colour):
    """Recessed four-panel door, fanlight, stone lintel with keystone, step."""
    d = ImageDraw.Draw(img)
    cx = (x0 + x1) / 2
    rect(d, x0 - 10, y0 - 22, x1 + 10, y0, STONE)
    rect(d, x0 - 10, y0 - 3, x1 + 10, y0, STONE_SHADE)
    rect(d, cx - 8, y0 - 28, cx + 8, y0 + 2, (228, 220, 198))
    rect(d, x0, y0, x1, y1, (40, 30, 28))  # reveal
    # fanlight
    rect(d, x0 + 5, y0 + 5, x1, y0 + 40, WHITE)
    glass(img, x0 + 11, y0 + 11, x1 - 6, y0 + 34)
    d = ImageDraw.Draw(img)
    for k in (1, 2):
        bx = x0 + 11 + (x1 - x0 - 17) * k / 3
        rect(d, bx - 1.5, y0 + 11, bx + 1.5, y0 + 34, WHITE)
    # leaf
    lx0, ly0, lx1, ly1 = x0 + 7, y0 + 42, x1 - 1, y1 - 8
    rect(d, lx0, ly0, lx1, ly1, colour)
    pw = (lx1 - lx0 - 18) / 2
    for col in range(2):
        px0 = lx0 + 6 + col * (pw + 6)
        px1 = px0 + pw
        for (py0, py1) in ((ly0 + 8, ly0 + 8 + (ly1 - ly0) * 0.42), (ly0 + 16 + (ly1 - ly0) * 0.5, ly1 - 8)):
            rect(d, px0, py0, px1, py1, mix(colour, (0, 0, 0), 0.25))
            rect(d, px0 + 2, py0 + 2, px1, py1, mix(colour, (255, 255, 255), 0.1))
            rect(d, px0 + 5, py0 + 5, px1 - 3, py1 - 3, colour)
    rect(d, cx - 12, ly0 + (ly1 - ly0) * 0.46, cx + 12, ly0 + (ly1 - ly0) * 0.46 + 5, BRASS)  # letterbox
    kx = lx1 - 10
    ky = ly0 + (ly1 - ly0) * 0.55
    d.ellipse(R(kx - 3, ky - 3, kx + 3, ky + 3), fill=BRASS)
    shade(img, lx0, ly0, lx1, ly0 + 10, 0.3)
    shade(img, lx0, ly0, lx0 + 6, ly1, 0.25)
    # step
    d = ImageDraw.Draw(img)
    rect(d, x0 - 6, y1 - 8, x1 + 6, y1, STONE)
    rect(d, x0 - 6, y1 - 8, x1 + 6, y1 - 6, (232, 224, 204))


def downpipe(img, x):
    d = ImageDraw.Draw(img)
    rect(d, x - 7, 10, x + 7, 28, PIPE)  # hopper head
    rect(d, x - 4, 28, x + 4, 504, PIPE)
    rect(d, x - 2, 28, x - 0.5, 504, (70, 70, 76))  # highlight
    for y in range(80, 500, 96):
        rect(d, x - 6, y, x + 6, y + 5, PIPE)  # brackets
    rect(d, x - 4, 498, x + 10, 506, PIPE)  # shoe
    shade(img, x + 4, 28, x + 7, 498, 0.25)


def eaves(img, pal):
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, N, 9, (26, 26, 30))  # gutter
    rect(d, 0, 7, N, 9, (60, 60, 66))
    shade(img, 0, 9, N, 16, 0.35)
    d = ImageDraw.Draw(img)
    for x in range(0, N, 16):  # dentil course, period divides 512
        rect(d, x + 2, 16, x + 10, 26, mix(pal["dark"], (0, 0, 0), 0.05))
    shade(img, 0, 26, N, 30, 0.2)


def string_course(img, y):
    d = ImageDraw.Draw(img)
    rect(d, 0, y, N, y + 9, STONE)
    rect(d, 0, y, N, y + 2, (232, 224, 204))
    shade(img, 0, y + 9, N, y + 13, 0.3)


def plinth(img):
    d = ImageDraw.Draw(img)
    rect(d, 0, 488, N, N, PLINTH)
    for x in range(0, N, 32):
        rect(d, x, 488, x + 1, N, (50, 42, 44))
    rect(d, 0, 486, N, 489, STONE_SHADE)


def grime(img):
    for i in range(12):
        shade(img, 0, 400 + i * 7, N, 400 + (i + 1) * 7, 0.01 * i)


def finish(img):
    return img.reduce(S)


# ---------------------------------------------------------------- textures

def front(seed, pal_name, door_colour, mirror=False, bay=False, curtain=(206, 196, 176)):
    rng = random.Random(seed)
    pal = PALETTES[pal_name]
    img = Image.new("RGB", (W, W))
    bricks(img, rng, pal)
    grime(img)
    eaves(img, pal)
    string_course(img, 244)
    plinth(img)

    def X(a, b):  # mirror a horizontal span
        return (N - b, N - a) if mirror else (a, b)

    # upper floor: narrow window over the hall, wider one over the front room
    sash(img, *interleave(X(44, 126), (52, 176)), curtain=None)
    sash(img, *interleave(X(252, 362), (52, 184)), curtain=curtain)
    # ground floor
    door(img, *interleave(X(40, 126), (290, 490)), DOORS[door_colour])
    if bay:
        bay_window(img, X, pal, curtain)
    else:
        sash(img, *interleave(X(246, 368), (318, 458)), curtain=curtain)
    px = 16 if mirror else 496
    downpipe(img, px)
    return finish(img)


def interleave(xs, ys):
    return xs[0], ys[0], xs[1], ys[1]


def bay_window(img, X, pal, curtain):
    """Canted bay drawn flat: lead roof, three lights, side lights shaded, brick base."""
    d = ImageDraw.Draw(img)
    x0, x1 = X(214, 452)
    y0, y1 = 300, 486
    # lead/slate hood over the bay
    d.polygon([tuple(v * S for v in p) for p in ((x0 - 6, y0), (x1 + 6, y0), (x1 - 10, y0 - 22), (x0 + 10, y0 - 22))], fill=(78, 84, 94))
    rect(d, x0 - 8, y0, x1 + 8, y0 + 8, STONE)
    shade(img, x0 - 6, y0 + 8, x1 + 6, y0 + 13, 0.3)
    # base panel under the lights
    d = ImageDraw.Draw(img)
    base_top = 424
    rect(d, x0, base_top, x1, y1, mix(pal["brick"], (0, 0, 0), 0.05))
    for yy in range(base_top + 12, y1, 13):
        rect(d, x0, yy, x1, yy + 2, pal["mortar"])
    rect(d, x0 - 6, base_top - 10, x1 + 6, base_top, STONE)  # sill band
    # three lights between stone mullions
    side = (x1 - x0) * 0.24
    spans = [(x0, x0 + side), (x0 + side, x1 - side), (x1 - side, x1)]
    for i, (a, b) in enumerate(spans):
        sash(img, a + 3, y0 + 13, b - 3, base_top - 10, lintel=False, bars=(i == 1), curtain=curtain, sill=False)
    d = ImageDraw.Draw(img)
    for m in (x0, x0 + side, x1 - side, x1):
        rect(d, m - 4, y0 + 8, m + 4, base_top - 10, STONE)
    # canted sides turn away from the light
    shade(img, x0 - 4, y0 + 8, x0 + side, y1, 0.28)
    shade(img, x1 - side, y0 + 8, x1 + 4, y1, 0.14)
    shade(img, x0 - 6, base_top, x1 + 6, base_top + 5, 0.25)


def back():
    rng = random.Random(404)
    pal = PALETTES["orange"]
    img = Image.new("RGB", (W, W))
    bricks(img, rng, pal, burnt=0.16, pale=0.02)
    grime(img)
    eaves(img, pal)
    d = ImageDraw.Draw(img)
    rect(d, 0, 494, N, N, PLINTH)
    sash(img, 88, 90, 140, 150, bars=False, frosted=True)  # bathroom
    sash(img, 292, 64, 380, 178, bars=False, curtain=(180, 172, 160))
    sash(img, 70, 330, 146, 420, bars=False)
    sash(img, 280, 318, 390, 430, bars=False, curtain=(190, 186, 170))
    downpipe(img, 208)
    return finish(img)


def slate():
    rng = random.Random(77)
    img = Image.new("RGB", (W, W))
    d = ImageDraw.Draw(img)
    base = (74, 82, 96)
    d.rectangle([0, 0, W, W], fill=(34, 38, 46))
    courses, per_row = 16, 16
    ch, sw = W / courses, W / per_row
    tones = {(r, i): jitter(rng, mix(base, (96, 106, 124), rng.random() * 0.5) if rng.random() < 0.15 else base, 7)
             for r in range(courses) for i in range(per_row)}
    for r in range(courses):
        y0, y1 = round(r * ch), round((r + 1) * ch)
        off = sw / 2 if r % 2 else 0
        for i in range(-1, per_row + 1):
            x0 = round(i * sw + off)
            x1 = round((i + 1) * sw + off) - 2 * S
            if x1 <= 0 or x0 >= W:
                continue
            c = tones[(r, i % per_row)]
            d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=c)
            d.rectangle([x0, y0, x1 - 1, y0 + 3 * S], fill=mix(c, (0, 0, 0), 0.35))  # lip of the course above
            d.rectangle([x0, y1 - 3 * S, x1 - 1, y1 - 1], fill=mix(c, (255, 255, 255), 0.1))
    return finish(img)


def brick_plain():
    rng = random.Random(9)
    img = Image.new("RGB", (W, W))
    bricks(img, rng, PALETTES["orange"])
    return finish(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    out = {
        "terrace_front_a.png": front(101, "red", "navy"),
        "terrace_front_b.png": front(202, "orange", "green", mirror=True, curtain=(214, 206, 190)),
        "terrace_front_c.png": front(303, "brown", "burgundy", bay=True, curtain=(196, 180, 150)),
        "terrace_back.png": back(),
        "slate_roof.png": slate(),
        "brick_plain.png": brick_plain(),
    }
    for name in FILES:
        out[name].save(os.path.join(OUT, name), optimize=True)
        print("wrote", os.path.join(OUT, name))
    with open(os.path.join(EXPORT, "upload_textures.txt"), "w") as f:
        f.write("# PNGs in assets/kit/_export/textures/ for: python tools/upload_kit.py --images <this file>\n")
        f.write("\n".join(FILES) + "\n")
    if "--preview" in sys.argv:
        # three houses of each front side by side above a 2x2 tile of the roof and brick
        sheet = Image.new("RGB", (N * 3, N * 5), (255, 255, 255))
        for row, name in enumerate(["terrace_front_a.png", "terrace_front_b.png", "terrace_front_c.png", "terrace_back.png"]):
            for k in range(3):
                sheet.paste(out[name], (k * N, row * N))
        for k in range(3):
            sheet.paste(out["slate_roof.png"] if k < 2 else out["brick_plain.png"], (k * N, 4 * N))
        sheet.save(os.path.join(OUT, "_preview.png"))
        print("wrote preview")


if __name__ == "__main__":
    main()
