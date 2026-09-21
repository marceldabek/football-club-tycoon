"""Prepare the 40 league club crests for the UI (docs/CRESTS.md).

Reads the generated crest PNGs (named "<Club Name> — <region>.png"), matches each
to a club in Config.Clubs (src/shared/Config.luau), and writes:

  assets/ui/crests/src/tier<N>_<kebab-name>.png    the original, renamed
  assets/ui/crests/keyed/tier<N>_<kebab-name>.png  white backdrop keyed out, 256x256
  assets/ui/crests/contact_sheet.png               all 40, one division per row

It also prints the clubs whose shirt colour (`kit`) in Config is far from every colour in their crest art.
The report is only printed; nothing in Config is changed.

    python tools/prep_crests.py [source_folder]
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "src", "shared", "Config.luau")
OUT = os.path.join(ROOT, "assets", "ui", "crests")
DEFAULT_SRC = os.path.join(os.path.expanduser("~"), "Downloads")

SIZE = 256
MARGIN = 0.04
# Colour distance from the backdrop: below T0 fully clear, above T1 fully solid.
T0, T1 = 40.0, 120.0
DRIFT = 60.0


def kebab(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def load_clubs():
    """[(tier, name, kit, accent)] in Config order."""
    text = open(CONFIG, encoding="utf-8").read()
    start = text.index("Config.Clubs = {")
    end = text.index("\n}\n", start)
    clubs, tier = [], 0
    for line in text[start:end].splitlines():
        if re.match(r"\s*\{ --", line):
            tier += 1
        m = re.search(r'name = "([^"]+)", kit = \{ (\d+), (\d+), (\d+) \}, accent = \{ (\d+), (\d+), (\d+) \}', line)
        if m:
            nums = [int(v) for v in m.groups()[1:]]
            clubs.append((tier, m.group(1), nums[:3], nums[3:]))
    return clubs


def find_sources(folder, clubs):
    names = {c[1]: c for c in clubs}
    found = {}
    # os.listdir, not glob: glob skips dotfiles, and one crest was saved as
    # ". Bramblewick Rovers — ...png".
    for base in os.listdir(folder):
        path = os.path.join(folder, base)
        if not base.lower().endswith(".png") or " — " not in base:
            continue
        club = base.split(" — ")[0].strip(" .'\"")
        if club in names:
            found[club] = path
    missing = [n for n in names if n not in found]
    if missing:
        sys.exit("No crest file for: " + ", ".join(missing))
    return found


def key(rgb):
    h, w, _ = rgb.shape
    corners = np.concatenate([rgb[:8, :8], rgb[:8, -8:], rgb[-8:, :8], rgb[-8:, -8:]]).reshape(-1, 3)
    backdrop = np.median(corners, axis=0)
    dist = np.linalg.norm(rgb - backdrop, axis=2)
    alpha = np.clip((dist - T0) / (T1 - T0), 0.0, 1.0)
    # Only backdrop joined to the border is keyed, so white inside the crest
    # (17 crests use white as a colour) keeps its alpha.
    labels, _ = ndimage.label(alpha < 1.0)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    outside = np.isin(labels, border[border != 0])
    alpha = np.where(outside, alpha, 1.0)
    # Despill: soft and clear pixels take the nearest solid colour, so the edge
    # has no white halo when Roblox scales it.
    _, (iy, ix) = ndimage.distance_transform_edt(alpha < 1.0, return_indices=True)
    clean = rgb[iy, ix]
    return np.dstack([clean, alpha * 255.0]).astype(np.uint8)


def square(rgba):
    ys, xs = np.where(rgba[..., 3] > 8)
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    h, w = crop.shape[:2]
    side = int(round(max(h, w) * (1 + 2 * MARGIN)))
    canvas = np.zeros((side, side, 4), np.uint8)
    y0, x0 = (side - h) // 2, (side - w) // 2
    canvas[y0 : y0 + h, x0 : x0 + w] = crop
    return Image.fromarray(canvas, "RGBA").resize((SIZE, SIZE), Image.LANCZOS)


def palette(img, k=4):
    """Cluster centres of the crest's opaque pixels, white included."""
    px = np.asarray(img).reshape(-1, 4).astype(np.float32)
    px = px[px[:, 3] > 200][:, :3]
    rng = np.random.default_rng(0)
    centres = px[rng.choice(len(px), k, replace=False)]
    for _ in range(20):
        lab = np.linalg.norm(px[:, None] - centres[None], axis=2).argmin(1)
        centres = np.array([px[lab == i].mean(0) if (lab == i).any() else centres[i] for i in range(k)])
    return centres


def drift(centres, kit):
    """How far the shirt colour is from the nearest colour actually in the crest."""
    d = np.linalg.norm(centres - np.array(kit, float), axis=1)
    return d.min(), centres[d.argmin()]


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    clubs = load_clubs()
    if len(clubs) != 40:
        sys.exit(f"Expected 40 clubs in Config.Clubs, found {len(clubs)}")
    sources = find_sources(folder, clubs)
    for sub in ("src", "keyed"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)

    cell = 128
    sheet = Image.new("RGBA", (cell * 8, cell * 5), (128, 128, 128, 255))
    checker = np.indices((cell * 5, cell * 8)).sum(0) // 16 % 2
    sheet = Image.fromarray(np.where(checker[..., None], [150, 150, 150, 255], [110, 110, 110, 255]).astype(np.uint8), "RGBA")

    report, col = [], {}
    for tier, name, kit, _accent in clubs:
        fname = f"tier{tier}_{kebab(name)}.png"
        src = Image.open(sources[name])
        src.save(os.path.join(OUT, "src", fname))
        rgb = np.asarray(src.convert("RGB")).astype(np.float32)
        out = square(key(rgb))
        out.save(os.path.join(OUT, "keyed", fname), optimize=True)
        i = col.get(tier, 0)
        col[tier] = i + 1
        sheet.alpha_composite(out.resize((cell, cell), Image.LANCZOS), (i * cell, (tier - 1) * cell))
        d, nearest = drift(palette(out), kit)
        if d > DRIFT:
            report.append(f"  {name}: shirt {tuple(kit)}, nearest crest colour {tuple(int(v) for v in nearest)}  drift {d:.0f}")

    sheet.convert("RGB").save(os.path.join(OUT, "contact_sheet.png"))
    print(f"{len(clubs)} crests written to {OUT}")
    print(f"Shirt colours that drift from the crest art (> {DRIFT:.0f}):" if report else "No shirt colour drifts from its crest.")
    print("\n".join(report))


if __name__ == "__main__":
    main()
