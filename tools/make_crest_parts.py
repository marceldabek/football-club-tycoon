"""Build the crest-builder layers from the generated art (docs/CREST_BUILDER_PROMPTS.md).

Reads the white-on-magenta source PNGs, keys the backdrop and writes tint-ready
layers (pure white RGB, the shape carried by alpha) to assets/ui/crest/parts/:

  shape_<s>.png            the fill, every shape on the same square canvas
  rim_<s>.png              a band just inside the shape's edge
  pattern_<p>_<s>.png      halves / stripes / sash, clipped to the shape
  emblem_<e>.png           cropped to its bounds, centred on a square canvas
  halo_<e>.png             the emblem grown a little, drawn under it in the main colour

Roblox cannot clip one image by another, so the game stacks these as tinted
ImageLabels. Cutting the rim and patterns from the shape here is what keeps
the layers aligned to the pixel.

It also writes assets/ui/crest/preview.png: sample crests composited the way
the game stacks them, to check proportions before uploading.

    python tools/make_crest_parts.py [source_folder]
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "crest")
SRC_COPY = os.path.join(OUT, "src")
PARTS = os.path.join(OUT, "parts")
DEFAULT_SRC = os.path.join(os.path.expanduser("~"), "Downloads")

# Downloaded name -> game name.
SHAPES = {"classicshield": "classic", "circle": "round", "square": "square", "sharpshield": "pointed"}
EMBLEMS = {
    "soccerball": "ball", "lion": "lion", "castle": "castle", "waves": "waves",
    "star": "star", "oak": "oak", "bridge": "bridge", "crown": "crown",
}
PATTERNS = ["halves", "stripes", "sash"]

WORK = 1024   # everything is cut at this size, then downsampled (free anti-aliasing)
SIZE = 512    # shipped size
SHAPE_FILL = 0.94   # the shape's longest side, as a share of the canvas
RIM = 0.05          # rim width, as a share of the canvas
STRIPES = 5         # vertical bands across the shape; the even ones take the second colour
SASH = 0.26         # sash width, as a share of the canvas
EMBLEM_FILL = 0.90  # emblem's longest side on its canvas; the margin leaves room for the halo
HALO = 0.035        # halo growth around the emblem, as a share of its canvas


# Colour distance from the backdrop: below T0 fully clear, above T1 fully solid.
T0, T1 = 60.0, 160.0


def key(path):
    """Alpha from the distance to the corner backdrop colour, everywhere. Unlike
    tools/key_cards.py this also clears enclosed backdrop, which is what the
    star's inner star, the acorns and the castle windows are."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    corners = np.concatenate([rgb[:8, :8], rgb[:8, -8:], rgb[-8:, :8], rgb[-8:, -8:]]).reshape(-1, 3)
    backdrop = np.median(corners, axis=0)
    alpha = np.clip((np.linalg.norm(rgb - backdrop, axis=2) - T0) / (T1 - T0), 0.0, 1.0)
    return alpha, backdrop


def source_path(folder, stem):
    for name in (stem + ".png", stem + ".PNG"):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            return p
    return None


def fit(alpha, fill):
    """Crop `alpha` to its bounds and centre it on a WORK square, longest side = fill * WORK."""
    ys, xs = np.where(alpha > 0.5)
    crop = alpha[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = crop.shape
    scale = fill * WORK / max(h, w)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    img = Image.fromarray((crop * 255).astype(np.uint8), "L").resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("L", (WORK, WORK), 0)
    canvas.paste(img, ((WORK - nw) // 2, (WORK - nh) // 2))
    return np.asarray(canvas).astype(np.float32) / 255.0


def save_layer(alpha, name):
    small = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8), "L").resize((SIZE, SIZE), Image.LANCZOS)
    rgba = Image.merge("RGBA", [Image.new("L", small.size, 255)] * 3 + [small])
    rgba.save(os.path.join(PARTS, name + ".png"), optimize=True)
    return np.asarray(small).astype(np.float32) / 255.0


def rim_of(shape):
    inside = ndimage.distance_transform_edt(shape > 0.5)
    band = np.clip(RIM * WORK + 0.5 - inside, 0.0, 1.0)
    return band * shape


def pattern_of(shape, kind):
    ys, xs = np.where(shape > 0.5)
    x0, x1 = xs.min(), xs.max()
    yy, xx = np.mgrid[0:WORK, 0:WORK].astype(np.float32)
    if kind == "halves":
        region = xx >= (x0 + x1) / 2
    elif kind == "stripes":
        band = np.floor((xx - x0) / ((x1 - x0 + 1) / STRIPES))
        region = (band % 2) == 1
    else:  # sash: top-left to bottom-right through the centre
        c = WORK / 2
        dist = np.abs((xx - c) - (yy - c)) / np.sqrt(2)
        region = dist <= SASH * WORK / 2
    return region.astype(np.float32) * shape


def halo_of(emblem):
    """The emblem grown by HALO: drawn under it in the main colour, so the
    emblem still reads where a pattern puts the second colour behind it."""
    outside = ndimage.distance_transform_edt(emblem < 0.5)
    return np.maximum(emblem, np.clip(HALO * WORK + 0.5 - outside, 0.0, 1.0))


def check_emblem(alpha, name):
    solid = alpha > 0.5
    # Thinnest stroke that has to survive at 48px: open at 1% of the canvas.
    k = max(1, int(0.01 * alpha.shape[0]))
    lost = (solid ^ ndimage.binary_opening(solid, iterations=k)).sum() / max(1, solid.sum())
    flags = []
    if lost > 0.04:
        flags.append(f"{lost:.1%} of the white is thinner than 2% of the width")
    print(f"  emblem {name}: " + ("; ".join(flags) if flags else "ok"))


def composite(shape, pattern, rim, emblem, halo, main, second, emblem_scale, emblem_y):
    """One crest the way the game stacks it, as an RGBA image at SIZE."""
    out = np.zeros((SIZE, SIZE, 4), np.float32)

    def over(alpha, colour):
        a = alpha[..., None]
        rgb = np.array(colour, np.float32) / 255.0
        out[..., :3] = out[..., :3] * (1 - a) + rgb * a
        out[..., 3:] = out[..., 3:] * (1 - a) + a

    over(shape, main)
    if pattern is not None:
        over(pattern, second)
    over(rim, second)
    es = int(SIZE * emblem_scale)
    for img, colour in ((halo, main), (emblem, second)):
        em = Image.fromarray((img * 255).astype(np.uint8), "L").resize((es, es), Image.LANCZOS)
        layer = Image.new("L", (SIZE, SIZE), 0)
        layer.paste(em, ((SIZE - es) // 2, int(SIZE * emblem_y - es / 2)))
        over(np.asarray(layer).astype(np.float32) / 255.0, colour)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


# Emblem placement per shape: (scale of the canvas, vertical centre). Mirrored in
# src/shared/ClubCrest.luau (EMBLEM_BOX); keep the two in step.
EMBLEM_BOX = {"classic": (0.50, 0.46), "round": (0.52, 0.50), "square": (0.54, 0.50), "pointed": (0.46, 0.47)}


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    for d in (OUT, SRC_COPY, PARTS):
        os.makedirs(d, exist_ok=True)

    shapes, emblems, halos = {}, {}, {}
    print("shapes")
    for stem, name in SHAPES.items():
        path = source_path(src, stem) or source_path(SRC_COPY, "shape_" + name)
        if not path:
            sys.exit(f"missing shape source {stem}.png")
        if os.path.dirname(os.path.abspath(path)) != os.path.abspath(SRC_COPY):
            shutil.copyfile(path, os.path.join(SRC_COPY, "shape_" + name + ".png"))
        alpha, backdrop = key(path)
        shape = fit(alpha, SHAPE_FILL)
        shapes[name] = {
            "shape": save_layer(shape, "shape_" + name),
            "rim": save_layer(rim_of(shape), "rim_" + name),
        }
        for p in PATTERNS:
            shapes[name][p] = save_layer(pattern_of(shape, p), f"pattern_{p}_{name}")
        print(f"  {name}: backdrop {tuple(int(c) for c in backdrop)}")

    print("emblems")
    for stem, name in EMBLEMS.items():
        path = source_path(src, stem) or source_path(SRC_COPY, "emblem_" + name)
        if not path:
            sys.exit(f"missing emblem source {stem}.png")
        if os.path.dirname(os.path.abspath(path)) != os.path.abspath(SRC_COPY):
            shutil.copyfile(path, os.path.join(SRC_COPY, "emblem_" + name + ".png"))
        alpha, _ = key(path)
        emblem = fit(alpha, EMBLEM_FILL)
        check_emblem(emblem, name)
        emblems[name] = save_layer(emblem, "emblem_" + name)
        halos[name] = save_layer(halo_of(emblem), "halo_" + name)

    # Preview: every shape x pattern with a rotating emblem, then every emblem at 48px.
    samples = [((200, 40, 50), (245, 245, 245)), ((24, 60, 140), (250, 200, 40)),
               ((20, 110, 60), (245, 245, 245)), ((30, 30, 34), (230, 190, 60))]
    names = list(emblems)
    tile = 200
    sheet = Image.new("RGBA", (tile * 4, tile * 5), (40, 44, 52, 255))
    for r, s in enumerate(SHAPES.values()):
        for c, p in enumerate([None] + PATTERNS):
            main_c, second_c = samples[(r + c) % len(samples)]
            e = names[(r * 4 + c) % len(names)]
            scale, y = EMBLEM_BOX[s]
            img = composite(shapes[s]["shape"], shapes[s][p] if p else None, shapes[s]["rim"],
                            emblems[e], halos[e], main_c, second_c, scale, y)
            sheet.alpha_composite(img.resize((tile - 16, tile - 16), Image.LANCZOS), (c * tile + 8, r * tile + 8))
    for i, e in enumerate(names):
        img = composite(shapes["classic"]["shape"], None, shapes["classic"]["rim"], emblems[e], halos[e],
                        (24, 60, 140), (245, 245, 245), *EMBLEM_BOX["classic"])
        sheet.alpha_composite(img.resize((48, 48), Image.LANCZOS), (8 + i * 96, 4 * tile + 40))
        sheet.alpha_composite(img.resize((24, 24), Image.LANCZOS), (64 + i * 96, 4 * tile + 52))
    sheet.save(os.path.join(OUT, "preview.png"))
    print(f"wrote {len(os.listdir(PARTS))} layers to {PARTS}")


if __name__ == "__main__":
    main()
