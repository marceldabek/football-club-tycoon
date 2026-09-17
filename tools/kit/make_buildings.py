"""Generate the low-part semis & industrial-estate textures (backlog E4.1).

Writes 512x512 (or 512x128 for the unit signs) PNGs into
assets/kit/_export/textures/ plus the upload list
assets/kit/_export/upload_buildings.txt for tools/upload_kit.py --images:

    semi_front_a.png   one 1930s semi-detached house front: brick ground floor
                        with a bay window + door, pebble-dash/render upper
                        floor with two sash windows. Cream render, red door.
    semi_front_b.png   as above, mirrored layout. White render, blue door.
    semi_side.png       plain seamless brick, for the pair's exposed gable ends.
    roof_tiles.png       red-brown clay roof tiles, seamless both ways.
    shed_cladding.png    grey-blue profiled metal cladding, vertical ribs,
                        seamless both ways.
    shed_door.png        a roller shutter, a personnel door and a blank sign
                        fascia above; one image per unit (not seamless).
    shed_sign_{a,b,c}.png  512x128 unit signs.

Each semi front is a single house (not a tiled pair): EstateBuilder tiles it
twice across a pair's frontage. Reference: assets/references/
RivermereNorthfields.png (1930s semis, pebble-dash over brick, hipped tiled
roofs, low front garden walls) and assets/references/
rivermer.industrialestate.png (metal-clad sheds, roller shutters, unit
signage). Shapes are drawn big and flat on purpose so they read at street
distance on a phone; this is not a photo texture.

Reuses the brick/window/door drawing helpers from make_facades.py so the two
kits share a visual language.

Usage:  python tools/kit/make_buildings.py   [--preview]
Deterministic (fixed seeds), so re-running gives identical files.
"""
import os, random, sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_facades as mf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXPORT = os.path.join(ROOT, "assets", "kit", "_export")
OUT = os.path.join(EXPORT, "textures")

N = mf.N  # 512
S = mf.S  # 2

FILES = [
    "semi_front_a.png",
    "semi_front_b.png",
    "semi_side.png",
    "roof_tiles.png",
    "shed_cladding.png",
    "shed_door.png",
    "shed_sign_a.png",
    "shed_sign_b.png",
    "shed_sign_c.png",
]

SIGNS = [
    ("shed_sign_a.png", "LUNE LOGISTICS", (26, 58, 110)),
    ("shed_sign_b.png", "RIVERMERE PLANT HIRE", (196, 128, 22)),
    ("shed_sign_c.png", "MILL LANE MOTORS", (120, 30, 34)),
]


def load_font(size):
    for path in (r"C:\Windows\Fonts\arialbd.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    try:
        return ImageFont.load_default(size=size)
    except Exception:
        return ImageFont.load_default()


# ---------------------------------------------------------------- pebbledash

def render_fill(w, h, base, seed, grain=11):
    """Blotchy render/pebbledash: low-res gaussian noise upsampled onto a flat
    base colour. Not seamless (each semi front is used once, never tiled)."""
    rng = np.random.default_rng(seed)
    sw, sh = max(1, w // 6), max(1, h // 6)
    noise = rng.normal(0, grain, (sh, sw)).astype(np.float32)
    noise_img = Image.fromarray(np.clip(noise + 128, 0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)
    noise_arr = np.asarray(noise_img).astype(np.int16) - 128
    arr = np.empty((h, w, 3), dtype=np.uint8)
    for c in range(3):
        arr[:, :, c] = np.clip(base[c] + noise_arr, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGB")


# ------------------------------------------------------------------- semis

def semi_front(seed, pal_name, door_colour, render_colour, mirror=False, curtain=(206, 196, 176)):
    rng = random.Random(seed)
    pal = mf.PALETTES[pal_name]
    img = Image.new("RGB", (mf.W, mf.W))
    mf.bricks(img, rng, pal)  # ground-floor brick base for the whole wall

    upper = render_fill(mf.W, 260 * S, render_colour, seed + 500)
    img.paste(upper, (0, 0))  # covers the wall above the string course with render

    mf.grime(img)
    mf.eaves(img, pal)
    mf.string_course(img, 250)
    mf.plinth(img)

    def X(a, b):
        return (mf.N - b, mf.N - a) if mirror else (a, b)

    mf.sash(img, *mf.interleave(X(44, 126), (52, 176)), curtain=None)
    mf.sash(img, *mf.interleave(X(252, 362), (52, 184)), curtain=curtain)
    mf.door(img, *mf.interleave(X(40, 126), (290, 490)), door_colour)
    mf.bay_window(img, X, pal, curtain)
    px = 16 if mirror else 496
    mf.downpipe(img, px)
    return mf.finish(img)


def semi_side():
    rng = random.Random(55)
    img = Image.new("RGB", (mf.W, mf.W))
    mf.bricks(img, rng, mf.PALETTES["red"])
    return mf.finish(img)


# -------------------------------------------------------------- roof tiles

def roof_tiles():
    rng = random.Random(88)
    img = Image.new("RGB", (mf.W, mf.W))
    d = ImageDraw.Draw(img)
    base = (150, 78, 52)
    d.rectangle([0, 0, mf.W, mf.W], fill=(90, 46, 32))
    courses, per_row = 14, 14
    ch, sw = mf.W / courses, mf.W / per_row
    tones = {}
    for r in range(courses):
        for i in range(per_row):
            b = mf.mix(base, (190, 110, 70), rng.random() * 0.4) if rng.random() < 0.2 else base
            tones[(r, i)] = mf.jitter(rng, b, 10)
    for r in range(courses):
        y0, y1 = round(r * ch), round((r + 1) * ch)
        off = sw / 2 if r % 2 else 0
        for i in range(-1, per_row + 1):
            x0 = round(i * sw + off)
            x1 = round((i + 1) * sw + off) - 2 * S
            if x1 <= 0 or x0 >= mf.W:
                continue
            c = tones[(r, i % per_row)]
            d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=c)
            d.rectangle([x0, y0, x1 - 1, y0 + 3 * S], fill=mf.mix(c, (0, 0, 0), 0.3))
            d.rectangle([x0, y1 - 3 * S, x1 - 1, y1 - 1], fill=mf.mix(c, (255, 255, 255), 0.08))
    return mf.finish(img)


# ------------------------------------------------------------- shed textures

def shed_cladding():
    rng = random.Random(21)
    img = Image.new("RGB", (mf.W, mf.W))
    d = ImageDraw.Draw(img)
    base = (150, 162, 172)
    d.rectangle([0, 0, mf.W, mf.W], fill=base)
    ribs = 20
    rw = (mf.N / ribs) * S
    for i in range(ribs):
        x0 = round(i * rw)
        x1 = round((i + 1) * rw)
        tone = mf.jitter(rng, base, 5)
        d.rectangle([x0, 0, x1 - 1, mf.W], fill=tone)
        hl = round(rw * 0.18)
        d.rectangle([x0, 0, x0 + hl, mf.W], fill=mf.mix(tone, (255, 255, 255), 0.35))
        d.rectangle([x1 - hl, 0, x1 - 1, mf.W], fill=mf.mix(tone, (0, 0, 0), 0.3))
    for i in range(ribs):
        cx = round((i + 0.5) * rw)
        for y in range(40, mf.W - 40, 256):
            d.ellipse([cx - 4 * S, y, cx + 4 * S, y + 8 * S], fill=(70, 76, 84))
    return mf.finish(img)


def shed_door():
    img = Image.new("RGB", (mf.W, mf.W), (170, 174, 180))
    d = ImageDraw.Draw(img)
    mf.rect(d, 0, 0, N, 80, (40, 46, 56))  # blank sign fascia
    mf.rect(d, 0, 76, N, 80, (20, 24, 30))
    x0, x1, y0, y1 = 30, 380, 96, 470
    mf.rect(d, x0 - 6, y0 - 6, x1 + 6, y1 + 6, (60, 64, 70))  # guide frame
    slats = 18
    sh = (y1 - y0) / slats
    for i in range(slats):
        sy0 = y0 + i * sh
        sy1 = sy0 + sh - 2
        tone = (198, 200, 204) if i % 2 == 0 else (172, 176, 182)
        mf.rect(d, x0, sy0, x1, sy1, tone)
    mf.shade(img, x0, y1 - 30, x1, y1, 0.25)
    dx0, dx1, dy0, dy1 = 400, 466, 180, 470  # personnel door
    d = ImageDraw.Draw(img)
    mf.rect(d, dx0 - 4, dy0 - 4, dx1 + 4, dy1 + 2, (40, 44, 50))
    mf.rect(d, dx0, dy0, dx1, dy1, (58, 92, 70))
    mf.rect(d, dx0 + 8, dy0 + 30, dx1 - 8, dy0 + 90, (150, 170, 178))
    mf.rect(d, dx0 - 10, dy1, dx1 + 10, dy1 + 10, (90, 90, 90))
    return mf.finish(img)


def shed_sign(text, bg, fg=(245, 245, 245)):
    w, h = N, 128
    img = Image.new("RGB", (w * S, h * S), bg)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w * S, 10 * S], fill=mf.mix(bg, (255, 255, 255), 0.25))
    d.rectangle([0, h * S - 10 * S, w * S, h * S], fill=mf.mix(bg, (0, 0, 0), 0.25))
    size = 44 * S
    font = load_font(size)
    while size > 10:
        bbox = d.textbbox((0, 0), text, font=font)
        if bbox[2] - bbox[0] <= w * S - 40 * S:
            break
        size -= 4 * S
        font = load_font(size)
    bbox = d.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((w * S - tw) / 2 - bbox[0], (h * S - th) / 2 - bbox[1]), text, font=font, fill=fg)
    return img.reduce(S)


def main():
    os.makedirs(OUT, exist_ok=True)
    out = {
        "semi_front_a.png": semi_front(401, "red", (150, 30, 30), (222, 214, 192)),
        "semi_front_b.png": semi_front(402, "red", (36, 64, 118), (234, 232, 226), mirror=True, curtain=(214, 206, 190)),
        "semi_side.png": semi_side(),
        "roof_tiles.png": roof_tiles(),
        "shed_cladding.png": shed_cladding(),
        "shed_door.png": shed_door(),
    }
    for name, text, bg in SIGNS:
        out[name] = shed_sign(text, bg)

    for name in FILES:
        out[name].save(os.path.join(OUT, name), optimize=True)
        print("wrote", os.path.join(OUT, name))

    with open(os.path.join(EXPORT, "upload_buildings.txt"), "w") as f:
        f.write("# PNGs in assets/kit/_export/textures/ for: python tools/upload_kit.py --images <this file>\n")
        f.write("\n".join(FILES) + "\n")

    if "--preview" in sys.argv:
        sheet = Image.new("RGB", (N * 3, N * 2 + 128), (255, 255, 255))
        sheet.paste(out["semi_front_a.png"], (0, 0))
        sheet.paste(out["semi_front_b.png"], (N, 0))
        sheet.paste(out["semi_side.png"], (2 * N, 0))
        sheet.paste(out["roof_tiles.png"], (0, N))
        sheet.paste(out["shed_cladding.png"], (N, N))
        sheet.paste(out["shed_door.png"], (2 * N, N))
        for i, (name, _, _) in enumerate(SIGNS):
            sheet.paste(out[name], (i * N, 2 * N))
        sheet.save(os.path.join(OUT, "_preview_buildings.png"))
        print("wrote preview")


if __name__ == "__main__":
    main()
