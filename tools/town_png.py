"""Rasterise a town data dict (the shape tools/town_map.py parses) to a PNG.

    python tools/town_png.py [out.png]            # the live layout
    from town_png import render                   # any plan with the same shape

The SVG is the deliverable; this exists because a PNG can be cropped, zoomed
and diffed by eye without a browser. `flag` marks blocks to paint loud red, which
is how the "housing behind housing" audit is made visible.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from town_map import ROAD_STYLE, is_housing, parse, use_fill  # noqa: E402

PLOT_SIZE = 760.0


def _font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(d, out, scale=0.5, crop=None, flag=None, labels=True):
    """crop = (minX, maxX, minZ, maxZ) in world studs; flag = predicate(block)."""
    minX, maxX, minZ, maxZ = crop or d["extent"]
    pad = 20
    W = int((maxX - minX) * scale) + pad * 2
    H = int((maxZ - minZ) * scale) + pad * 2
    img = Image.new("RGB", (W, H), "#eef0e9")
    g = ImageDraw.Draw(img, "RGBA")

    def P(x, z):
        return ((x - minX) * scale + pad, (z - minZ) * scale + pad)

    def line(pts, colour, width):
        w = max(1, int(round(width * scale)))
        xy = [P(x, z) for x, z in pts]
        g.line(xy, fill=colour, width=w, joint="curve")
        r = w / 2
        for x, y in xy:
            g.ellipse((x - r, y - r, x + r, y + r), fill=colour)

    line(d["river"]["points"], "#7fb5d5", d["river"]["width"])
    line(d["rail"]["points"], "#5c5750", d["rail"]["width"])

    for plot in d["plots"]:
        cx, cz = plot["centre"]
        h = PLOT_SIZE / 2
        x0, y0 = P(cx - h, cz - h)
        x1, y1 = P(cx + h, cz + h)
        g.rectangle((x0, y0, x1, y1), fill=(47, 125, 79, 46), outline="#2f7d4f", width=3)

    for r in sorted(d["roads"], key=lambda r: -r["width"]):
        # pavement first so the corridor width is honest
        line(r["points"], "#d5d3cb", r["width"] + 16)
    for r in sorted(d["roads"], key=lambda r: -r["width"]):
        colour, _ = ROAD_STYLE.get(r["kind"], ROAD_STYLE["residential"])
        line(r["points"], colour, r["width"])

    for hx, hz in d.get("heads", []):   # cul-de-sac turning heads
        x, y = P(hx, hz)
        for rad, colour in ((42, "#d5d3cb"), (34, ROAD_STYLE["residential"][0])):
            g.ellipse((x - rad * scale, y - rad * scale, x + rad * scale, y + rad * scale), fill=colour)

    for rb in d["roundabouts"]:
        cx, cz = rb["centre"]
        rr = rb["radius"] * scale
        x, y = P(cx, cz)
        g.ellipse((x - rr, y - rr, x + rr, y + rr), fill="#eef0e9", outline="#4a4f57", width=2)

    for b in d["bridges"]:
        g.line([P(*b["from"]), P(*b["to"])], fill="#2d3036", width=3)

    for dist in d["districts"]:
        for blk in dist["blocks"]:
            cx, cz = blk["centre"]
            sx, sz = blk["size"]
            a = math.radians(blk["yaw"])
            ca, sa = math.cos(a), math.sin(a)
            corners = []
            for ux, uz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                lx, lz = ux * sx / 2, uz * sz / 2
                corners.append(P(cx + lx * ca - lz * sa, cz + lx * sa + lz * ca))
            if flag and flag(blk):
                g.polygon(corners, fill="#ff1744", outline="#7a0019")
            else:
                outline = "#7a2f1b" if is_housing(blk["use"]) else None
                g.polygon(corners, fill=use_fill(blk["use"]), outline=outline)

    x, y = P(0, 0)
    g.ellipse((x - 60 * scale, y - 60 * scale, x + 60 * scale, y + 60 * scale), fill="#d8c98a", outline="#8a7b3f")
    if d.get("station"):
        x, y = P(*d["station"])
        g.rectangle((x - 60 * scale, y - 14 * scale, x + 60 * scale, y + 14 * scale), fill="#3a3630")

    if labels:
        big, small = _font(max(11, int(40 * scale))), _font(max(9, int(24 * scale)))
        for plot in d["plots"]:
            x, y = P(*plot["centre"])
            g.text((x, y), plot["name"], fill="#1d5133", font=big, anchor="mm")
        for dist in d["districts"]:
            xs = [b["centre"][0] for b in dist["blocks"]]
            zs = [b["centre"][1] for b in dist["blocks"]]
            if not xs:
                continue
            x, y = P(sum(xs) / len(xs), sum(zs) / len(zs))
            g.text((x, y), dist["name"], fill="#15171a", font=big, anchor="mm",
                   stroke_width=3, stroke_fill="#eef0e9")
        for r in d["roads"]:
            if r["kind"] in ("ring", "main"):
                pts = r["points"]
                i = len(pts) // 2
                mx, mz = (pts[i - 1][0] + pts[i][0]) / 2, (pts[i - 1][1] + pts[i][1]) / 2
                x, y = P(mx, mz)
                g.text((x, y), r["name"], fill="#111", font=small, anchor="mm",
                       stroke_width=2, stroke_fill="#eef0e9")
        for lm in d["landmarks"]:
            x, y = P(*lm["at"])
            g.ellipse((x - 5, y - 5, x + 5, y + 5), fill="#b2402f")

    img.save(out)
    return out


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "docs" / "town_map.png"
    print(render(parse(), out))
