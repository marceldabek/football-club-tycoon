"""Key the solid backdrop out of the generated card art and check the outlines match.

Reads assets/ui/cards/card_*.png (magenta or green backdrop, sampled from the
corners), writes transparent PNGs to assets/ui/cards/keyed/, then compares every
card's alpha outline against card_gold.png.

    python tools/key_cards.py
"""
import glob
import os

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "cards")
OUT = os.path.join(SRC, "keyed")
SKIP = {"card_filled_reference.png"}
REFERENCE = "card_gold.png"

# Colour distance from the backdrop: below T0 is fully clear, above T1 fully solid.
T0, T1 = 60.0, 160.0


def key(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = rgb.shape
    corners = np.concatenate([rgb[:8, :8], rgb[:8, -8:], rgb[-8:, :8], rgb[-8:, -8:]]).reshape(-1, 3)
    backdrop = np.median(corners, axis=0)

    dist = np.linalg.norm(rgb - backdrop, axis=2)
    alpha = np.clip((dist - T0) / (T1 - T0), 0.0, 1.0)

    # Only the backdrop joined to the image border is keyed, so a purple or
    # green highlight inside the card keeps its alpha.
    labels, _ = ndimage.label(alpha < 1.0)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    outside = np.isin(labels, border[border != 0])
    alpha = np.where(outside, alpha, 1.0)

    # Despill and bleed: every pixel that is not fully solid takes the colour of
    # the nearest solid card pixel. The soft edge loses its backdrop tint, and
    # the clear pixels carry rim colour, so scaling in Roblox leaves no halo.
    _, (iy, ix) = ndimage.distance_transform_edt(alpha < 1.0, return_indices=True)
    clean = rgb[iy, ix]

    rgba = np.dstack([clean, alpha * 255.0]).astype(np.uint8)
    return rgba, backdrop


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max(), ys.max()


def main():
    os.makedirs(OUT, exist_ok=True)
    masks = {}
    for path in sorted(glob.glob(os.path.join(SRC, "card_*.png"))):
        name = os.path.basename(path)
        if name in SKIP:
            continue
        rgba, backdrop = key(path)
        Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name), optimize=True)
        masks[name] = rgba[..., 3] >= 128
        print(f"{name}: backdrop {tuple(int(c) for c in backdrop)}")

    ref = masks[REFERENCE]
    # Distance of every pixel to the reference outline, to measure the worst stray.
    ref_edge = ref ^ ndimage.binary_erosion(ref)
    to_ref_edge = ndimage.distance_transform_edt(~ref_edge)
    print(f"\noutline vs {REFERENCE}  (bbox = left, top, right, bottom)")
    print(f"  {REFERENCE}: bbox {bbox(ref)}")
    for name, mask in masks.items():
        if name == REFERENCE:
            continue
        iou = (mask & ref).sum() / (mask | ref).sum()
        edge = mask ^ ndimage.binary_erosion(mask)
        print(
            f"  {name}: bbox {bbox(mask)}  IoU {iou:.4f}  "
            f"edge drift mean {to_ref_edge[edge].mean():.1f}px max {to_ref_edge[edge].max():.1f}px"
        )


if __name__ == "__main__":
    main()
