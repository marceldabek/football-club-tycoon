"""Generate the low-part shop, flats and civic textures (backlog E2.1).

Writes PNGs into assets/kit/_export/textures/ plus the upload list
assets/kit/_export/upload_shops.txt for tools/upload_kit.py --images:

    shop_front_<name>.png      one shop bay, pavement to top of fascia (512x512,
                               drawn at 5:3 so it maps onto a ~20 x 12 stud bay)
    shop_front_pub.png         The Riverside Arms
    shop_front_corner.png      Westdale Stores     (corner shop, dark green)
    shop_front_corner2.png     Northfields Stores
    shop_front_supermarket.png Lune Fresh, 1024x512, drawn at 5:1 for a ~60 x 12 stud front
    upper_floors_a.png         one storey of red brick, 3 sashes, repeated twice (seamless both ways)
    upper_floors_b.png         the same in buff brick
    flats_facade.png           3-storey flats, seamless left-right (drawn for a ~24 x 38 stud tile)
    civic_facade.png           pale stone, tall windows, seamless left-right (~16 x 30 stud tile)
    brick_buff.png             seamless buff brick for the sides of buff-fronted rows

Reference: assets/references/RivermereCenter.png (painted timber shopfronts
with fascia signs under 2-3 storeys of brick with sash windows) and
RiveremereWestdale.png (Westdale Stores in dark green). The town is Rivermere.
Shapes are big and flat so they read at street distance on a phone.

Usage:  python tools/kit/make_shopfronts.py   [--preview]
Deterministic (fixed seeds), so re-running gives identical files.
"""
import os, random, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXPORT = os.path.join(ROOT, "assets", "kit", "_export")
OUT = os.path.join(EXPORT, "textures")

FONT_DIR = "C:/Windows/Fonts"
SERIF_BOLD = "georgiab.ttf"
SERIF = "georgia.ttf"
SANS_BOLD = "arialbd.ttf"
SANS = "arial.ttf"

STONE = (214, 204, 182)
STONE_LIGHT = (232, 224, 204)
STONE_SHADE = (170, 160, 140)
WHITE = (240, 238, 230)
GOLD = (214, 178, 96)
CREAM = (236, 226, 198)
DARK = (28, 26, 28)

BRICKS = {
    "red": {"brick": (150, 60, 44), "mortar": (186, 172, 152), "dark": (104, 42, 34), "light": (172, 84, 60)},
    "buff": {"brick": (196, 164, 112), "mortar": (214, 204, 184), "dark": (164, 132, 86), "light": (214, 186, 136)},
    "brown": {"brick": (132, 78, 56), "mortar": (176, 164, 148), "dark": (96, 56, 42), "light": (156, 100, 74)},
}


def clamp(v):
    return max(0, min(255, int(round(v))))


def mix(a, b, t):
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(3))


def jitter(rng, c, amt):
    k = rng.uniform(-amt, amt)
    return tuple(clamp(c[i] + k + rng.uniform(-amt * 0.3, amt * 0.3)) for i in range(3))


def font(name, size):
    try:
        return ImageFont.truetype(os.path.join(FONT_DIR, name), int(size))
    except OSError:
        try:
            return ImageFont.load_default(int(size))
        except TypeError:
            return ImageFont.load_default()


class Canvas:
    """Logical coordinates (w x h units) drawn at `ss` pixels per unit."""

    def __init__(self, w, h, ss, bg=(0, 0, 0)):
        self.w, self.h, self.ss = w, h, ss
        self.img = Image.new("RGB", (int(w * ss), int(h * ss)), bg)
        self.d = ImageDraw.Draw(self.img)

    def box(self, x0, y0, x1, y1):
        s = self.ss
        return [int(round(x0 * s)), int(round(y0 * s)), int(round(x1 * s)) - 1, int(round(y1 * s)) - 1]

    def rect(self, x0, y0, x1, y1, fill):
        if x1 > x0 and y1 > y0:
            self.d.rectangle(self.box(x0, y0, x1, y1), fill=fill)

    def ellipse(self, x0, y0, x1, y1, fill):
        self.d.ellipse(self.box(x0, y0, x1, y1), fill=fill)

    def poly(self, pts, fill):
        self.d.polygon([(x * self.ss, y * self.ss) for x, y in pts], fill=fill)

    def line(self, x0, y0, x1, y1, fill, width):
        self.d.line([(x0 * self.ss, y0 * self.ss), (x1 * self.ss, y1 * self.ss)], fill=fill, width=max(1, int(width * self.ss)))

    def shade(self, x0, y0, x1, y1, amount, colour=(0, 0, 0)):
        s = self.ss
        box = (int(max(0, x0) * s), int(max(0, y0) * s), int(min(self.w, x1) * s), int(min(self.h, y1) * s))
        if box[2] <= box[0] or box[3] <= box[1]:
            return
        region = self.img.crop(box)
        self.img.paste(Image.blend(region, Image.new("RGB", region.size, colour), amount), box)

    def gradient(self, x0, y0, x1, y1, top, bottom):
        s = self.ss
        for yy in range(int(y0 * s), int(y1 * s)):
            t = (yy - y0 * s) / max(1, (y1 - y0) * s - 1)
            self.d.line([(int(x0 * s), yy), (int(x1 * s) - 1, yy)], fill=mix(top, bottom, t))

    def text(self, cx, cy, text, fontname, max_w, max_h, fill, spacing=0.0):
        """Centre `text` on (cx, cy), shrinking the font until it fits max_w x max_h."""
        s = self.ss
        size = max_h * s
        while size > 6:
            f = font(fontname, size)
            if spacing:
                width = sum(self.d.textlength(ch, font=f) for ch in text) + spacing * s * (len(text) - 1)
            else:
                width = self.d.textlength(text, font=f)
            l, t, r, b = self.d.textbbox((0, 0), text, font=f)
            if width <= max_w * s and (b - t) <= max_h * s:
                break
            size *= 0.94
        f = font(fontname, size)
        l, t, r, b = self.d.textbbox((0, 0), text, font=f)
        y = cy * s - (t + b) / 2
        if spacing:
            x = cx * s - width / 2
            for ch in text:
                self.d.text((x, y), ch, font=f, fill=fill)
                x += self.d.textlength(ch, font=f) + spacing * s
        else:
            self.d.text((cx * s - width / 2, y), text, font=f, fill=fill)
        self.d = ImageDraw.Draw(self.img)

    def out(self, size):
        return self.img.resize(size, Image.LANCZOS)

    def out_seamless(self, size):
        """Resize without seams at the left/right edges: wrap, resize, crop the middle."""
        w, h = self.img.size
        wide = Image.new("RGB", (w * 3, h))
        for k in range(3):
            wide.paste(self.img, (k * w, 0))
        big = wide.resize((size[0] * 3, size[1]), Image.LANCZOS)
        return big.crop((size[0], 0, size[0] * 2, size[1]))


# ------------------------------------------------------------------ pieces

def bricks(c, rng, pal, x0, y0, x1, y1, course_h, brick_w, burnt=0.1, pale=0.05):
    """Stretcher bond over a box. Tiles in X when (x1-x0) is a multiple of brick_w,
    and in Y when (y1-y0) is an even multiple of course_h."""
    c.rect(x0, y0, x1, y1, pal["mortar"])
    joint = max(1.0 / c.ss, course_h * 0.14)
    rows = int(round((y1 - y0) / course_h))
    per = int(round((x1 - x0) / brick_w))
    tones = {}
    for r in range(rows):
        for i in range(per):
            roll = rng.random()
            base = pal["dark"] if roll < burnt else pal["light"] if roll < burnt + pale else pal["brick"]
            tones[(r, i)] = jitter(rng, base, 9)
    for r in range(rows):
        by0 = y0 + r * course_h
        by1 = by0 + course_h - joint
        off = brick_w / 2 if r % 2 else 0
        for i in range(-1, per + 1):
            bx0 = x0 + i * brick_w + off
            bx1 = bx0 + brick_w - joint
            if bx1 <= x0 or bx0 >= x1:
                continue
            col = tones[(r, i % per)]
            c.rect(max(x0, bx0), by0, min(x1, bx1), by1, col)
            c.rect(max(x0, bx0), by1 - joint * 0.6, min(x1, bx1), by1, mix(col, (0, 0, 0), 0.18))


def glass(c, x0, y0, x1, y1, top=(34, 44, 58), bottom=(96, 112, 130), streaks=True):
    c.gradient(x0, y0, x1, y1, top, bottom)
    if streaks:
        w, h = x1 - x0, y1 - y0
        s = c.ss
        layer = Image.new("RGB", c.img.size, (170, 186, 200))
        mask = Image.new("L", c.img.size, 0)
        md = ImageDraw.Draw(mask)
        md.polygon([((x0 + w * 0.2) * s, y0 * s), ((x0 + w * 0.45) * s, y0 * s), ((x0 + w * 0.1) * s, y1 * s), ((x0 - w * 0.15) * s, y1 * s)], fill=46)
        md.polygon([((x0 + w * 0.65) * s, y0 * s), ((x0 + w * 0.74) * s, y0 * s), ((x0 + w * 0.42) * s, y1 * s), ((x0 + w * 0.33) * s, y1 * s)], fill=30)
        clip = Image.new("L", c.img.size, 0)
        ImageDraw.Draw(clip).rectangle(c.box(x0, y0, x1, y1), fill=255)
        from PIL import ImageChops
        c.img.paste(layer, (0, 0), ImageChops.multiply(mask, clip))
        c.d = ImageDraw.Draw(c.img)


def warm_interior(c, x0, y0, x1, y1):
    c.gradient(x0, y0, x1, y1, (92, 66, 44), (46, 34, 28))


def sash(c, x0, y0, x1, y1, curtain=None, stone=True):
    """White sliding sash in a brick reveal with a stone lintel and sill (logical units)."""
    w = x1 - x0
    if stone:
        c.rect(x0 - w * 0.08, y0 - w * 0.2, x1 + w * 0.08, y0, STONE)
        c.rect(x0 - w * 0.08, y0 - w * 0.035, x1 + w * 0.08, y0, STONE_SHADE)
    c.rect(x0, y0, x1, y1, (46, 34, 32))
    f = w * 0.07
    c.rect(x0 + f * 0.5, y0 + f * 0.7, x1, y1, WHITE)
    gx0, gy0, gx1, gy1 = x0 + f * 1.5, y0 + f * 1.7, x1 - f, y1 - f
    mid = (gy0 + gy1) / 2
    glass(c, gx0, gy0, gx1, mid - f * 0.4)
    glass(c, gx0, mid + f * 0.4, gx1, gy1)
    if curtain:
        cw = (gx1 - gx0) * 0.2
        c.rect(gx0, mid + f * 0.4, gx0 + cw, gy1, curtain)
        c.rect(gx1 - cw, mid + f * 0.4, gx1, gy1, mix(curtain, (0, 0, 0), 0.12))
    c.rect(gx0 - f * 0.2, mid - f * 0.4, gx1 + f * 0.2, mid + f * 0.4, WHITE)
    cx = (gx0 + gx1) / 2
    c.rect(cx - f * 0.25, gy0, cx + f * 0.25, gy1, WHITE)
    c.shade(x0 + f * 0.5, y0 + f * 0.7, x1, y0 + f * 1.6, 0.25)
    if stone:
        c.rect(x0 - w * 0.1, y1, x1 + w * 0.1, y1 + w * 0.1, STONE)
        c.rect(x0 - w * 0.1, y1, x1 + w * 0.1, y1 + w * 0.025, STONE_LIGHT)
        c.shade(x0 - w * 0.08, y1 + w * 0.1, x1 + w * 0.08, y1 + w * 0.16, 0.3)


def flowers(c, rng, cx, cy, r):
    """A hanging basket: dark basket, leaves and a spill of flowers."""
    c.ellipse(cx - r, cy - r * 0.2, cx + r, cy + r * 0.9, (44, 40, 36))
    for _ in range(40):
        a, b = rng.uniform(-1, 1), rng.uniform(-0.9, 0.7)
        col = rng.choice([(58, 110, 50), (74, 130, 60), (214, 60, 90), (240, 170, 50), (160, 80, 200), (245, 245, 245), (58, 110, 50)])
        rr = r * rng.uniform(0.15, 0.28)
        x, y = cx + a * r * 1.1, cy + b * r
        c.ellipse(x - rr, y - rr, x + rr, y + rr, col)


# ------------------------------------------------------------- shopfronts
# Logical canvas 1000 x 600: y 0 top of cornice, 600 the pavement.

SHOPS = {
    "cafe": {"name": "The Daily Bean", "sub": "COFFEE  \u00b7  BRUNCH  \u00b7  CAKES", "fascia": (30, 44, 74), "ink": CREAM, "font": SERIF_BOLD, "caps": True, "seed": 11},
    "deli": {"name": "The Little Deli", "sub": "CHEESE  \u00b7  WINE  \u00b7  FINE FOOD", "fascia": (236, 230, 212), "ink": (40, 40, 44), "font": SERIF, "caps": False, "seed": 12, "mirror": True},
    "estate": {"name": "HOLLIS & CO.", "sub": "ESTATE AGENTS", "fascia": (24, 72, 52), "ink": GOLD, "font": SERIF_BOLD, "caps": True, "seed": 13},
    "pharmacy": {"name": "Lune Pharmacy", "sub": "PRESCRIPTIONS  \u00b7  HEALTH", "fascia": (22, 110, 116), "ink": (250, 250, 250), "font": SANS_BOLD, "caps": False, "seed": 14, "mirror": True},
    "bakery": {"name": "RIVERMERE BAKERY", "sub": "BAKED FRESH EVERY MORNING", "fascia": (110, 30, 42), "ink": CREAM, "font": SERIF_BOLD, "caps": True, "seed": 15},
    "butcher": {"name": "FLETCHER'S BUTCHERS", "sub": "FAMILY BUTCHERS SINCE 1921", "fascia": (22, 22, 24), "ink": (246, 244, 236), "font": SERIF_BOLD, "caps": True, "seed": 16, "mirror": True},
    "barber": {"name": "SHARP CUTS", "sub": "BARBERS  \u00b7  WALK-INS WELCOME", "fascia": (58, 60, 66), "ink": (250, 250, 250), "font": SANS_BOLD, "caps": True, "seed": 17},
    "charity": {"name": "Rivermere Hospice Shop", "sub": "EVERY PURCHASE HELPS", "fascia": (88, 44, 108), "ink": (250, 250, 250), "font": SANS_BOLD, "caps": False, "seed": 18, "mirror": True},
    "newsagent": {"name": "CORNER NEWS", "sub": "NEWS  \u00b7  SWEETS  \u00b7  CARDS", "fascia": (170, 32, 32), "ink": (252, 248, 236), "font": SANS_BOLD, "caps": True, "seed": 19},
}


def paint_frame(fascia):
    """Timber frame colour: the fascia colour, or a dark trim for pale fascias."""
    if sum(fascia) > 500:
        return (46, 52, 58)
    return fascia


def shop_shell(c, rng, fascia, ink, name, fontname, sub, frame=None, sign_top=18, sign_bottom=140):
    frame = frame or paint_frame(fascia)
    c.rect(0, 0, c.w, c.h, frame)
    # cornice over the fascia
    c.rect(0, 0, c.w, sign_top, mix(frame, (0, 0, 0), 0.25))
    c.rect(0, sign_top - 4, c.w, sign_top, mix(frame, (255, 255, 255), 0.15))
    # fascia board with a raised moulding
    c.rect(44, sign_top + 4, c.w - 44, sign_bottom, mix(fascia, (0, 0, 0), 0.2))
    c.rect(52, sign_top + 10, c.w - 52, sign_bottom - 8, fascia)
    c.rect(52, sign_bottom - 12, c.w - 52, sign_bottom - 8, mix(fascia, (0, 0, 0), 0.25))
    if sub:
        c.text(c.w / 2, sign_top + (sign_bottom - sign_top) * 0.4, name, fontname, c.w - 170, (sign_bottom - sign_top) * 0.5, ink)
        c.text(c.w / 2, sign_top + (sign_bottom - sign_top) * 0.8, sub, SANS_BOLD, c.w - 260, (sign_bottom - sign_top) * 0.17, mix(ink, fascia, 0.15), spacing=3)
    else:
        c.text(c.w / 2, (sign_top + sign_bottom) / 2, name, fontname, c.w - 170, (sign_bottom - sign_top) * 0.62, ink)
    # console brackets and pilasters
    for x in (0, c.w - 44):
        c.rect(x, 0, x + 44, c.h, mix(frame, (0, 0, 0), 0.1))
        c.rect(x + 6, sign_top, x + 38, sign_bottom + 10, mix(frame, (255, 255, 255), 0.12))
        c.rect(x + 12, sign_bottom + 10, x + 32, c.h - 40, mix(frame, (255, 255, 255), 0.06))
        c.shade(x + 38 if x == 0 else x, sign_bottom + 10, x + 44 if x == 0 else x + 6, c.h, 0.25)
    # plinth / pavement line
    c.rect(0, c.h - 24, c.w, c.h, (64, 60, 62))
    c.shade(0, sign_bottom, c.w, sign_bottom + 10, 0.35)


def window_frame(c, x0, y0, x1, y1, frame, transom=True, mullions=1):
    c.rect(x0 - 14, y0 - 14, x1 + 14, y1 + 14, mix(frame, (255, 255, 255), 0.08))
    stall = y1 + 14
    c.rect(x0 - 14, stall, x1 + 14, c.h - 24, mix(frame, (0, 0, 0), 0.1))
    # stall riser panels
    step = (x1 - x0) / 2
    for k in range(2):
        px0 = x0 + k * step + 12
        c.rect(px0, stall + 16, px0 + step - 24, c.h - 40, mix(frame, (0, 0, 0), 0.22))
        c.rect(px0 + 4, stall + 20, px0 + step - 28, c.h - 44, mix(frame, (255, 255, 255), 0.04))
    c.rect(x0 - 20, y1 + 8, x1 + 20, y1 + 18, mix(frame, (255, 255, 255), 0.2))  # sill


def window_bars(c, x0, y0, x1, y1, frame, transom_y=None, mullions=1):
    bar = mix(frame, (255, 255, 255), 0.08)
    if transom_y:
        c.rect(x0, transom_y - 5, x1, transom_y + 5, bar)
    for k in range(1, mullions + 1):
        mx = x0 + (x1 - x0) * k / (mullions + 1)
        c.rect(mx - 5, y0, mx + 5, y1, bar)


def shop_door(c, x0, x1, y0, frame, glazed=True):
    y1 = c.h - 24
    c.rect(x0 - 12, y0 - 12, x1 + 12, y1, mix(frame, (255, 255, 255), 0.08))
    c.rect(x0, y0, x1, y1, (30, 26, 26))  # recess
    c.shade(x0, y0, x1, y1, 0.2)
    lx0, lx1, ly0 = x0 + 18, x1 - 18, y0 + 60
    c.rect(lx0, y0 + 10, lx1, y0 + 50, (40, 36, 34))
    glass(c, lx0 + 6, y0 + 16, lx1 - 6, y0 + 44, streaks=False)
    c.rect(lx0, ly0, lx1, y1 - 6, frame if sum(frame) < 500 else (46, 52, 58))
    if glazed:
        glass(c, lx0 + 14, ly0 + 14, lx1 - 14, ly0 + (y1 - ly0) * 0.55)
    c.rect(lx0 + 14, ly0 + (y1 - ly0) * 0.62, lx1 - 14, y1 - 26, mix(frame, (0, 0, 0), 0.2))
    c.rect(lx1 - 26, ly0 + (y1 - ly0) * 0.5, lx1 - 18, ly0 + (y1 - ly0) * 0.5 + 30, GOLD)  # handle
    c.shade(x0, y0, x0 + 14, y1, 0.35)
    c.rect(x0 - 12, y1 - 8, x1 + 12, y1, STONE_SHADE)  # step


def interior(c, rng, kind, x0, y0, x1, y1, fascia):
    """A hint of the goods inside the display window. Returns text drawn on the
    glass, to be painted after the glazing bars."""
    w, h = x1 - x0, y1 - y0
    later = []
    if kind in ("cafe", "bakery", "deli", "pub", "butcher", "barber"):
        warm_interior(c, x0, y0, x1, y1)
    else:
        c.gradient(x0, y0, x1, y1, (150, 150, 146), (92, 90, 88))
    floor = y0 + h * 0.78
    if kind == "cafe":
        for k in range(3):
            lx = x0 + w * (0.2 + 0.3 * k)
            c.line(lx, y0, lx, y0 + h * 0.2, (30, 30, 30), 2)
            c.ellipse(lx - 18, y0 + h * 0.2, lx + 18, y0 + h * 0.2 + 22, (250, 210, 130))
        for k in range(2):
            tx = x0 + w * (0.3 + 0.4 * k)
            c.rect(tx - 50, floor - 30, tx + 50, floor - 20, (120, 80, 50))
            c.rect(tx - 5, floor - 20, tx + 5, y1, (70, 50, 36))
            for s in (-1, 1):
                c.rect(tx + s * 70 - 16, floor - 60, tx + s * 70 + 16, y1, (60, 44, 34))
            c.ellipse(tx - 14, floor - 44, tx + 4, floor - 30, WHITE)
        later.append((x0 + w / 2, y0 + h * 0.45, "Great coffee, good company", SERIF, w * 0.8, h * 0.09, CREAM))
    elif kind == "deli":
        for row in range(3):
            sy = y0 + h * (0.22 + 0.22 * row)
            c.rect(x0, sy, x1, sy + 6, (170, 150, 120))
            for k in range(9):
                jx = x0 + 20 + k * (w - 40) / 9
                col = rng.choice([(190, 60, 40), (220, 180, 60), (90, 120, 50), (140, 40, 70), (230, 220, 200)])
                c.rect(jx, sy - 34, jx + 26, sy, col)
                c.rect(jx + 4, sy - 40, jx + 22, sy - 34, (60, 50, 40))
        for k in range(4):
            cx = x0 + w * (0.15 + 0.23 * k)
            c.ellipse(cx - 34, floor - 20, cx + 34, floor + 20, (238, 196, 80))
            c.poly([(cx, floor), (cx + 34, floor - 8), (cx + 34, floor + 8)], (210, 170, 60))
    elif kind == "estate":
        c.gradient(x0, y0, x1, y1, (226, 226, 220), (186, 186, 180))
        cols, rows = 4, 3
        for r in range(rows):
            for k in range(cols):
                px = x0 + 24 + k * (w - 48) / cols
                py = y0 + 24 + r * (h - 48) / rows
                pw, ph = (w - 48) / cols - 18, (h - 48) / rows - 18
                c.rect(px, py, px + pw, py + ph, (252, 252, 250))
                c.rect(px + 8, py + 8, px + pw - 8, py + ph * 0.6, rng.choice([(120, 160, 200), (110, 150, 90), (170, 110, 80)]))
                c.rect(px + 8, py + ph * 0.7, px + pw * 0.7, py + ph * 0.78, fascia)
                c.rect(px + 8, py + ph * 0.84, px + pw * 0.45, py + ph * 0.9, (150, 150, 150))
    elif kind == "pharmacy":
        for row in range(3):
            sy = y0 + h * (0.25 + 0.24 * row)
            c.rect(x0, sy, x1, sy + 6, (240, 240, 240))
            for k in range(12):
                bx = x0 + 12 + k * (w - 24) / 12
                col = rng.choice([(240, 240, 240), (90, 170, 200), (230, 120, 140), (120, 190, 120), (250, 210, 90)])
                c.rect(bx, sy - rng.uniform(26, 44), bx + (w - 24) / 12 - 8, sy, col)
        cx, cy, r = x0 + w * 0.5, y0 + h * 0.14, 40
        c.rect(cx - r, cy - r / 3, cx + r, cy + r / 3, (40, 170, 80))
        c.rect(cx - r / 3, cy - r, cx + r / 3, cy + r, (40, 170, 80))
    elif kind == "bakery":
        for row in range(2):
            sy = y0 + h * (0.35 + 0.3 * row)
            c.rect(x0, sy, x1, sy + 8, (150, 110, 70))
            for k in range(7):
                bx = x0 + 30 + k * (w - 60) / 7
                c.ellipse(bx, sy - 38, bx + 62, sy + 2, rng.choice([(196, 140, 72), (214, 164, 92), (170, 110, 56)]))
                c.line(bx + 18, sy - 30, bx + 28, sy - 12, (240, 210, 160), 3)
                c.line(bx + 34, sy - 30, bx + 44, sy - 12, (240, 210, 160), 3)
        for k in range(3):
            cx = x0 + w * (0.2 + 0.3 * k)
            c.rect(cx - 6, floor - 8, cx + 6, y1, (200, 200, 200))
            c.rect(cx - 44, floor - 12, cx + 44, floor - 6, (220, 220, 220))
            c.rect(cx - 34, floor - 56, cx + 34, floor - 12, rng.choice([(246, 220, 230), (250, 240, 220), (120, 70, 50)]))
            c.rect(cx - 34, floor - 60, cx + 34, floor - 52, (240, 240, 240))
    elif kind == "butcher":
        c.gradient(x0, y0, x1, y1, (236, 236, 232), (196, 196, 192))
        for r in range(0, int(h), 30):
            c.rect(x0, y0 + r, x1, y0 + r + 2, (210, 210, 206))
        c.rect(x0, y0 + h * 0.12, x1, y0 + h * 0.12 + 6, (120, 120, 120))
        for k in range(6):
            hx = x0 + 40 + k * (w - 80) / 6
            c.line(hx + 20, y0 + h * 0.12, hx + 20, y0 + h * 0.22, (100, 100, 100), 3)
            c.ellipse(hx, y0 + h * 0.2, hx + 40, y0 + h * 0.46, rng.choice([(170, 50, 50), (190, 80, 70), (150, 40, 44)]))
        c.rect(x0, floor - 40, x1, y1, (240, 240, 240))
        for k in range(8):
            mx = x0 + 20 + k * (w - 40) / 8
            c.rect(mx, floor - 34, mx + (w - 40) / 8 - 10, floor - 8, rng.choice([(200, 70, 70), (220, 120, 110), (180, 50, 60), (230, 170, 140)]))
    elif kind == "barber":
        for k in range(2):
            mx = x0 + w * (0.12 + 0.46 * k)
            c.rect(mx, y0 + h * 0.15, mx + w * 0.3, y0 + h * 0.5, (190, 206, 214))
            c.rect(mx + w * 0.15 - 40, y0 + h * 0.52, mx + w * 0.15 + 40, floor, (30, 30, 34))
            c.rect(mx + w * 0.15 - 50, floor - 10, mx + w * 0.15 + 50, floor, (150, 30, 36))
            c.rect(mx + w * 0.15 - 8, floor, mx + w * 0.15 + 8, y1, (170, 170, 176))
        px = x0 + w - 40
        c.rect(px - 14, y0 + 10, px + 14, y0 + h * 0.62, (250, 250, 250))
        for k in range(8):
            yy = y0 + 10 + k * (h * 0.62 - 10) / 8
            c.poly([(px - 14, yy + 20), (px + 14, yy), (px + 14, yy + 14), (px - 14, yy + 34)], (200, 30, 40) if k % 2 == 0 else (30, 60, 150))
    elif kind == "charity":
        c.rect(x0 + 20, y0 + h * 0.22, x1 - 20, y0 + h * 0.25, (140, 140, 140))
        for k in range(14):
            hx = x0 + 30 + k * (w - 60) / 14
            c.rect(hx, y0 + h * 0.25, hx + 22, y0 + h * rng.uniform(0.55, 0.72), rng.choice([(200, 60, 80), (60, 100, 170), (230, 200, 90), (90, 150, 110), (240, 240, 240), (60, 60, 70)]))
        mx = x0 + w * 0.78
        c.ellipse(mx - 16, y0 + h * 0.3, mx + 16, y0 + h * 0.38, (230, 220, 210))
        c.poly([(mx - 30, y0 + h * 0.4), (mx + 30, y0 + h * 0.4), (mx + 46, floor), (mx - 46, floor)], (60, 120, 160))
        later.append((x0 + w * 0.3, floor + (y1 - floor) * 0.5, "DONATIONS WELCOME", SANS_BOLD, w * 0.5, (y1 - floor) * 0.5, (250, 250, 250)))
    elif kind == "newsagent":
        for row in range(4):
            sy = y0 + h * (0.18 + 0.2 * row)
            for k in range(10):
                bx = x0 + 10 + k * (w - 20) / 10
                c.rect(bx, sy, bx + (w - 20) / 10 - 8, sy + h * 0.16, rng.choice([(220, 60, 60), (60, 120, 200), (240, 200, 60), (250, 250, 250), (90, 180, 110), (230, 110, 170)]))
        c.rect(x0 + w * 0.08, y0 + h * 0.62, x0 + w * 0.46, y1 - 8, (252, 250, 240))
        c.text(x0 + w * 0.27, y0 + h * 0.72, "LOCAL", SANS_BOLD, w * 0.34, h * 0.09, (20, 20, 20))
        c.text(x0 + w * 0.27, y0 + h * 0.84, "NEWS", SANS_BOLD, w * 0.34, h * 0.09, (190, 30, 30))
    return later


def shop_front(key):
    spec = SHOPS[key]
    rng = random.Random(spec["seed"])
    c = Canvas(1000, 600, 2)
    fascia, ink = spec["fascia"], spec["ink"]
    frame = paint_frame(fascia)
    shop_shell(c, rng, fascia, ink, spec["name"], spec["font"], spec["sub"])
    mirror = spec.get("mirror", False)
    wx0, wx1 = (340, 940) if mirror else (70, 660)
    dx0, dx1 = (70, 270) if mirror else (730, 930)
    wy0, wy1 = 176, 470
    window_frame(c, wx0, wy0, wx1, wy1, frame)
    later = interior(c, rng, key, wx0, wy0, wx1, wy1, fascia)
    # reflections over the goods
    tint = Image.new("RGB", c.img.size, (120, 140, 160))
    region = c.box(wx0, wy0, wx1, wy1)
    crop = c.img.crop((region[0], region[1], region[2] + 1, region[3] + 1))
    c.img.paste(Image.blend(crop, tint.crop((0, 0) + crop.size), 0.12), (region[0], region[1]))
    c.d = ImageDraw.Draw(c.img)
    glass_streak(c, wx0, wy0, wx1, wy1)
    window_bars(c, wx0, wy0, wx1, wy1, frame, transom_y=wy0 + 56, mullions=1)
    for cx, cy, text, fontname, mw, mh, ink_ in later:
        c.rect(cx - mw * 0.55, cy - mh * 0.9, cx + mw * 0.55, cy + mh * 0.9, mix(frame, (0, 0, 0), 0.35))
        c.text(cx, cy, text, fontname, mw, mh, ink_)
    shop_door(c, dx0, dx1, 176, frame)
    # hanging basket on the outer pilaster
    flowers(c, rng, 22 if not mirror else c.w - 22, 200, 30)
    return c.out((512, 512))


def glass_streak(c, x0, y0, x1, y1):
    s = c.ss
    w = x1 - x0
    layer = Image.new("RGB", c.img.size, (230, 236, 240))
    mask = Image.new("L", c.img.size, 0)
    md = ImageDraw.Draw(mask)
    md.polygon([((x0 + w * 0.55) * s, y0 * s), ((x0 + w * 0.68) * s, y0 * s), ((x0 + w * 0.38) * s, y1 * s), ((x0 + w * 0.25) * s, y1 * s)], fill=34)
    md.polygon([((x0 + w * 0.74) * s, y0 * s), ((x0 + w * 0.78) * s, y0 * s), ((x0 + w * 0.48) * s, y1 * s), ((x0 + w * 0.44) * s, y1 * s)], fill=22)
    clip = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(clip).rectangle(c.box(x0, y0, x1, y1), fill=255)
    from PIL import ImageChops
    c.img.paste(layer, (0, 0), ImageChops.multiply(mask, clip))
    c.d = ImageDraw.Draw(c.img)


def etched(c, x0, y0, x1, y1):
    """Frosted, etched lower pub glass with a scroll border."""
    c.gradient(x0, y0, x1, y1, (190, 186, 172), (160, 156, 144))
    c.rect(x0 + 14, y0 + 14, x1 - 14, y0 + 18, (226, 222, 210))
    c.rect(x0 + 14, y1 - 18, x1 - 14, y1 - 14, (226, 222, 210))
    c.rect(x0 + 14, y0 + 14, x0 + 18, y1 - 14, (226, 222, 210))
    c.rect(x1 - 18, y0 + 14, x1 - 14, y1 - 14, (226, 222, 210))
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for k in range(6):
        r = 16 + k * 10
        c.d.arc(c.box(cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), 200, 340, fill=(226, 222, 210), width=4)
        c.d.arc(c.box(cx - r, cy - r * 0.6, cx + r, cy + r * 0.6), 20, 160, fill=(226, 222, 210), width=4)


def pub_front():
    rng = random.Random(21)
    c = Canvas(1000, 600, 2)
    green = (18, 46, 34)
    shop_shell(c, rng, green, GOLD, "THE RIVERSIDE ARMS", SERIF_BOLD, None, frame=(20, 40, 30), sign_top=18, sign_bottom=130)
    # gold pinstripe round the fascia
    c.rect(60, 34, 940, 37, GOLD)
    c.rect(60, 112, 940, 115, GOLD)
    for (wx0, wx1) in ((66, 366), (634, 934)):
        wy0, wy1 = 170, 488
        c.rect(wx0 - 14, wy0 - 14, wx1 + 14, c.h - 24, (26, 52, 38))
        split = wy0 + (wy1 - wy0) * 0.42
        warm_interior(c, wx0, wy0, wx1, split)
        for k in range(4):  # warm lamps and optics behind the bar
            lx = wx0 + 40 + k * (wx1 - wx0 - 80) / 3
            c.ellipse(lx - 12, wy0 + 30, lx + 12, wy0 + 54, (255, 206, 120))
        glass_streak(c, wx0, wy0, wx1, split)
        etched(c, wx0, split, wx1, wy1)
        window_bars(c, wx0, wy0, wx1, wy1, (26, 52, 38), transom_y=split, mullions=1)
        c.rect(wx0 - 18, wy1, wx1 + 18, wy1 + 12, (40, 70, 52))
        c.rect(wx0 + 10, wy1 + 26, wx1 - 10, c.h - 36, (14, 34, 24))
    # double doors in the middle
    x0, x1, y0 = 420, 580, 170
    c.rect(x0 - 12, y0 - 12, x1 + 12, c.h - 24, (26, 52, 38))
    c.rect(x0, y0, x1, c.h - 24, (16, 30, 22))
    for k in range(2):
        lx0 = x0 + 8 + k * (x1 - x0 - 16) / 2
        lx1 = lx0 + (x1 - x0 - 16) / 2 - 4
        c.rect(lx0, y0 + 8, lx1, c.h - 30, (22, 54, 38))
        etched(c, lx0 + 10, y0 + 20, lx1 - 10, y0 + 200)
        c.rect(lx0 + 10, y0 + 220, lx1 - 10, c.h - 50, (16, 40, 28))
    c.rect(498, y0 + 150, 502, y0 + 230, GOLD)
    # brass lamps and baskets
    for x in (22, 978):
        c.rect(x - 4, 130, x + 4, 150, GOLD)
        c.ellipse(x - 12, 146, x + 12, 170, (255, 214, 140))
    flowers(c, rng, 22, 230, 30)
    flowers(c, rng, 978, 230, 30)
    c.text(500, 150, "FREE HOUSE", SANS_BOLD, 200, 18, GOLD, spacing=4)
    return c.out((512, 512))


def corner_front(name):
    rng = random.Random(31 if name.startswith("W") else 32)
    c = Canvas(1000, 600, 2)
    green = (24, 64, 50)
    c.rect(0, 0, c.w, c.h, green)
    shop_shell(c, rng, green, CREAM, name, SERIF_BOLD, None, frame=green, sign_top=18, sign_bottom=140)
    # redraw the name to the left and a price list block to the right, like the reference
    c.rect(52, 28, 948, 132, green)
    c.text(360, 82, name, SERIF_BOLD, 560, 64, CREAM)
    c.rect(700, 36, 704, 124, mix(CREAM, green, 0.4))
    for k, line in enumerate(("NEWS", "OFF LICENCE", "GROCERIES")):
        c.text(826, 50 + k * 30, line, SANS_BOLD, 210, 22, CREAM)
    # window full of goods and posters
    wx0, wx1, wy0, wy1 = 70, 640, 176, 470
    window_frame(c, wx0, wy0, wx1, wy1, green)
    c.gradient(wx0, wy0, wx1, wy1, (160, 156, 146), (100, 96, 90))
    for row in range(4):
        sy = wy0 + 20 + row * 66
        for k in range(12):
            bx = wx0 + 10 + k * (wx1 - wx0 - 20) / 12
            c.rect(bx, sy, bx + (wx1 - wx0 - 20) / 12 - 6, sy + 50, rng.choice([(220, 60, 60), (60, 120, 200), (240, 200, 60), (250, 250, 250), (90, 180, 110), (230, 110, 170), (250, 150, 40)]))
    c.rect(wx0 + 30, wy0 + 150, wx0 + 250, wy1 - 20, (252, 236, 70))
    c.text(wx0 + 140, wy0 + 205, "FRESH", SANS_BOLD, 190, 40, (200, 30, 30))
    c.text(wx0 + 140, wy0 + 255, "BREAD", SANS_BOLD, 190, 40, (200, 30, 30))
    c.rect(wx1 - 220, wy0 + 150, wx1 - 30, wy1 - 20, (250, 250, 250))
    c.text(wx1 - 125, wy0 + 200, "LOCAL", SANS_BOLD, 160, 34, green)
    c.text(wx1 - 125, wy0 + 245, "PRODUCE", SANS_BOLD, 160, 34, green)
    glass_streak(c, wx0, wy0, wx1, wy1)
    window_bars(c, wx0, wy0, wx1, wy1, green, transom_y=wy0 + 50, mullions=0)
    shop_door(c, 730, 930, 176, green)
    flowers(c, rng, 700, 200, 34)
    return c.out((512, 512))


def supermarket_front():
    rng = random.Random(41)
    c = Canvas(2000, 400, 2)
    clad = (206, 208, 206)
    green = (46, 150, 70)
    c.rect(0, 0, c.w, c.h, clad)
    for x in range(0, c.w, 100):  # cladding panel joints
        c.rect(x, 0, x + 3, 110, (180, 182, 180))
    # sign panel
    c.rect(560, 14, 1440, 102, green)
    c.rect(560, 94, 1440, 102, mix(green, (0, 0, 0), 0.3))
    c.ellipse(600, 26, 670, 90, (250, 250, 250))
    c.poly([(622, 76), (650, 34), (658, 44), (632, 80)], green)
    c.text(1030, 58, "Lune Fresh", SANS_BOLD, 700, 70, (255, 255, 255))
    c.text(280, 58, "OPEN 7AM - 10PM", SANS_BOLD, 420, 34, (60, 64, 70), spacing=4)
    c.text(1720, 58, "EVERYDAY ESSENTIALS", SANS_BOLD, 480, 30, (60, 64, 70), spacing=3)
    c.rect(0, 108, c.w, 118, (70, 74, 80))  # canopy edge
    c.shade(0, 118, c.w, 132, 0.35)
    # glass curtain wall with the aisles behind
    gy0, gy1 = 118, 376
    c.gradient(0, gy0, c.w, gy1, (236, 238, 232), (190, 192, 186))
    for k in range(14):
        ax = 20 + k * 142
        c.rect(ax, gy0 + 60, ax + 90, gy1 - 30, (210, 212, 206))
        for r in range(4):
            sy = gy0 + 70 + r * 44
            c.rect(ax + 4, sy, ax + 86, sy + 30, rng.choice([(220, 70, 60), (240, 190, 60), (90, 170, 90), (70, 130, 200), (240, 240, 240), (230, 130, 60)]))
    for k in range(3):  # ceiling lights
        c.rect(0, gy0 + 20 + k * 2, c.w, gy0 + 24 + k * 2, (250, 250, 244))
    c.shade(0, gy0, c.w, gy1, 0.12, (90, 120, 150))
    glass_streak(c, 0, gy0, 1000, gy1)
    glass_streak(c, 1000, gy0, c.w, gy1)
    # mullions
    for x in range(0, c.w + 1, 125):
        c.rect(x - 4, gy0, x + 4, gy1, (80, 84, 90))
    # posters
    for (px, title, sub) in ((180, "FRESH", "EVERY DAY"), (1560, "MEAL DEAL", "\u00a33")):
        c.rect(px, gy0 + 40, px + 240, gy0 + 200, green)
        c.text(px + 120, gy0 + 95, title, SANS_BOLD, 210, 48, (255, 255, 255))
        c.text(px + 120, gy0 + 155, sub, SANS_BOLD, 200, 40, (252, 236, 70))
    # sliding doors in the middle
    c.rect(875, gy0 + 6, 1125, gy1, (80, 84, 90))
    c.gradient(885, gy0 + 16, 1115, gy1, (70, 90, 100), (130, 150, 160))
    c.rect(996, gy0 + 16, 1004, gy1, (80, 84, 90))
    glass_streak(c, 885, gy0 + 16, 1115, gy1)
    c.rect(900, gy0 + 42, 1100, gy0 + 78, green)
    c.text(1000, gy0 + 60, "WELCOME", SANS_BOLD, 180, 24, (255, 255, 255), spacing=3)
    # base and trolleys
    c.rect(0, gy1, c.w, c.h, (90, 92, 96))
    c.rect(0, gy1, c.w, gy1 + 4, (140, 142, 146))
    for k in range(3):
        tx = 1240 + k * 34
        c.rect(tx, gy1 - 70, tx + 80, gy1 - 66, (170, 174, 180))
        c.rect(tx, gy1 - 66, tx + 4, gy1 - 10, (170, 174, 180))
        for r in range(4):
            c.rect(tx, gy1 - 60 + r * 14, tx + 80, gy1 - 58 + r * 14, (170, 174, 180))
    return c.out((1024, 512))


# -------------------------------------------------------------- facades

def upper_floors(pal_name, seed):
    """One storey (1000 x 500) of brick with three sashes, stacked twice.
    Seamless both ways; each storey is identical so a one-storey face shows exactly half."""
    rng = random.Random(seed)
    pal = BRICKS[pal_name]
    storey = Canvas(1000, 500, 1)
    bricks(storey, rng, pal, 0, 0, 1000, 500, course_h=500 / 36, brick_w=1000 / 16)
    for k in range(3):
        cx = 1000 * (k + 0.5) / 3
        sash(storey, cx - 82, 130, cx + 82, 420, curtain=(206, 196, 176) if (k + seed) % 2 else None)
    # soot at the top of the storey under the next sill
    for i in range(6):
        storey.shade(0, i * 6, 1000, (i + 1) * 6, 0.05 - i * 0.008)
    c = Canvas(1000, 1000, 1)
    c.img.paste(storey.img, (0, 0))
    c.img.paste(storey.img, (0, 500))
    return c.out_seamless((512, 512))


def flats_facade():
    """3 storeys, 2 windows a tile, concrete floor bands. Drawn for a ~24 wide x 38 tall stud tile."""
    rng = random.Random(51)
    pal = BRICKS["brown"]
    c = Canvas(600, 950, 2)
    bricks(c, rng, pal, 0, 0, 600, 950, course_h=950 / 80, brick_w=600 / 12)
    c.rect(0, 0, 600, 34, (198, 194, 184))  # coping band
    c.shade(0, 34, 600, 44, 0.3)
    storey = (950 - 34) / 3
    for s in range(3):
        top = 34 + s * storey
        if s > 0:
            c.rect(0, top - 10, 600, top + 6, (198, 194, 184))  # floor band
            c.shade(0, top + 6, 600, top + 14, 0.25)
        for k in range(2):
            cx = 150 + k * 300
            x0, x1 = cx - 100, cx + 100
            y0, y1 = top + 70, top + storey - 70
            c.rect(x0 - 6, y0 - 6, x1 + 6, y1 + 6, (60, 50, 46))
            c.rect(x0, y0, x1, y1, (238, 238, 234))
            glass(c, x0 + 12, y0 + 12, cx - 4, y1 - 12)
            glass(c, cx + 4, y0 + 12, x1 - 12, y1 - 12)
            c.rect(x0 + 12, y0 + (y1 - y0) * 0.3, x1 - 12, y0 + (y1 - y0) * 0.3 + 8, (238, 238, 234))
            if rng.random() < 0.6:
                c.rect(x0 + 12, y0 + (y1 - y0) * 0.3 + 8, x0 + 44, y1 - 12, rng.choice([(206, 196, 176), (170, 190, 200), (200, 170, 160)]))
            c.rect(x0 - 14, y1 + 6, x1 + 14, y1 + 20, (198, 194, 184))
            c.shade(x0 - 10, y1 + 20, x1 + 10, y1 + 28, 0.3)
    c.rect(0, 930, 600, 950, (70, 64, 62))
    return c.out_seamless((512, 512))


def civic_facade():
    """Pale ashlar stone, rusticated ground floor, tall windows. ~16 wide x 30 tall stud tile."""
    rng = random.Random(61)
    c = Canvas(480, 900, 2)
    stone = (214, 206, 188)
    c.rect(0, 0, 480, 900, stone)
    course = 900 / 30
    for r in range(30):
        y = r * course
        c.rect(0, y, 480, y + 2, (188, 180, 162))
        off = 60 if r % 2 else 0
        for x in range(0, 480, 120):
            c.rect((x + off) % 480, y, (x + off) % 480 + 2, y + course, (192, 184, 166))
        for x in range(0, 480, 120):
            c.shade((x + off) % 480 + 4, y + 3, (x + off) % 480 + 116, y + course - 2, rng.uniform(0, 0.05), (120, 110, 90))
    # rusticated ground floor: deep horizontal joints
    ground = 900 * 0.45
    for r in range(8):
        y = ground + r * (900 - ground) / 8
        c.rect(0, y, 480, y + 7, (160, 150, 132))
    c.rect(0, ground - 24, 480, ground, (228, 222, 206))  # string course
    c.shade(0, ground, 480, ground + 10, 0.3)
    c.rect(0, 0, 480, 60, (228, 222, 206))  # cornice band
    c.rect(0, 50, 480, 60, (180, 172, 154))
    c.shade(0, 60, 480, 76, 0.35)
    # upper: tall sash with a pediment hood
    cx = 240
    x0, x1, y0, y1 = cx - 78, cx + 78, 150, ground - 70
    c.poly([(x0 - 24, y0 - 20), (x1 + 24, y0 - 20), (cx, y0 - 70)], (228, 222, 206))
    c.rect(x0 - 24, y0 - 22, x1 + 24, y0 - 10, (196, 188, 170))
    sash(c, x0, y0, x1, y1, stone=False)
    c.rect(x0 - 22, y1, x1 + 22, y1 + 18, (228, 222, 206))
    c.shade(x0 - 18, y1 + 18, x1 + 18, y1 + 30, 0.3)
    # ground: tall arched window with a keystone
    gx0, gx1, gy0, gy1 = cx - 78, cx + 78, ground + 110, 820
    c.ellipse(gx0, gy0 - 78, gx1, gy0 + 78, (60, 52, 48))
    c.rect(gx0, gy0, gx1, gy1, (60, 52, 48))
    c.ellipse(gx0 + 12, gy0 - 66, gx1 - 12, gy0 + 66, WHITE)
    c.rect(gx0 + 12, gy0, gx1 - 12, gy1, WHITE)
    c.ellipse(gx0 + 24, gy0 - 54, gx1 - 24, gy0 + 54, (60, 76, 94))
    glass(c, gx0 + 24, gy0, gx1 - 24, gy1 - 12)
    c.rect(cx - 5, gy0 - 54, cx + 5, gy1 - 12, WHITE)
    c.rect(gx0 + 24, gy0 + 120, gx1 - 24, gy0 + 130, WHITE)
    c.poly([(cx - 20, gy0 - 92), (cx + 20, gy0 - 92), (cx + 14, gy0 - 58), (cx - 14, gy0 - 58)], (232, 226, 210))
    c.rect(gx0 - 20, gy1, gx1 + 20, gy1 + 18, (228, 222, 206))
    c.rect(0, 870, 480, 900, (150, 142, 126))  # plinth
    return c.out_seamless((512, 512))


def brick_buff():
    rng = random.Random(71)
    c = Canvas(512, 512, 2)
    bricks(c, rng, BRICKS["buff"], 0, 0, 512, 512, course_h=512 / 40, brick_w=512 / 12)
    return c.out_seamless((512, 512))


# ------------------------------------------------------------------ main

def build():
    out = {}
    for key in SHOPS:
        out["shop_front_%s.png" % key] = shop_front(key)
    out["shop_front_pub.png"] = pub_front()
    out["shop_front_corner.png"] = corner_front("Westdale Stores")
    out["shop_front_corner2.png"] = corner_front("Northfields Stores")
    out["shop_front_supermarket.png"] = supermarket_front()
    out["upper_floors_a.png"] = upper_floors("red", 81)
    out["upper_floors_b.png"] = upper_floors("buff", 82)
    out["flats_facade.png"] = flats_facade()
    out["civic_facade.png"] = civic_facade()
    out["brick_buff.png"] = brick_buff()
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    out = build()
    for name, img in out.items():
        img.save(os.path.join(OUT, name), optimize=True)
        print("wrote", os.path.join(OUT, name))
    with open(os.path.join(EXPORT, "upload_shops.txt"), "w") as f:
        f.write("# PNGs in assets/kit/_export/textures/ for: python tools/upload_kit.py --images <this file>\n")
        f.write("\n".join(out.keys()) + "\n")
    if "--preview" in sys.argv:
        # each image squashed back to the stud aspect it maps onto in game
        aspect = {"shop_front_supermarket.png": (1000, 200), "flats_facade.png": (240, 380), "civic_facade.png": (160, 300)}
        tiles = []
        for name, img in out.items():
            if name.startswith("shop_front"):
                size = aspect.get(name, (400, 240))
            elif name.startswith("upper"):
                size = (400, 480)
            else:
                size = aspect.get(name, (320, 320))
            tiles.append((name, img.resize(size, Image.LANCZOS)))
        sheet = Image.new("RGB", (2100, 1900), (255, 255, 255))
        x = y = row_h = 0
        for name, img in tiles:
            if x + img.width > sheet.width:
                x, y = 0, y + row_h + 10
                row_h = 0
            sheet.paste(img, (x, y))
            x += img.width + 10
            row_h = max(row_h, img.height)
        sheet.save(os.path.join(OUT, "_preview_shops.png"))
        print("wrote preview")


if __name__ == "__main__":
    main()
