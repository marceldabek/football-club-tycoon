"""Draw Rivermere top-down as an SVG, straight from src/shared/TownLayout.luau.

    python tools/town_map.py [out.svg]

The point is to argue about the layout without opening Studio, so this reads the
real data rather than a copy: rerun it after any TownLayout change and the map
follows. World +X is drawn right, world +Z is drawn DOWN, so the picture matches
a Studio top-down view (north, -Z, is up).
"""

import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "TownLayout.luau"

VEC = r"Vector3\.new\(\s*(-?[\d.]+)\s*,\s*-?[\d.]+\s*,\s*(-?[\d.]+)\s*\)"

# world -> image
SCALE = 0.34
PAD = 40


def section(src: str, name: str, stop: str) -> str:
    i = src.index(f"TownLayout.{name}")
    j = src.index(f"TownLayout.{stop}", i + 1)
    return src[i:j]


def points(text: str):
    return [(float(a), float(b)) for a, b in re.findall(VEC, text)]


def parse():
    src = SRC.read_text(encoding="utf-8")
    out = {}

    roads = []
    for chunk in re.split(r"\n\t\{\n", section(src, "ROADS", "RIVER")):
        nm = re.search(r'name\s*=\s*"([^"]+)"', chunk)
        kd = re.search(r'kind\s*=\s*"([^"]+)"', chunk)
        wd = re.search(r"width\s*=\s*([\d.]+)", chunk)
        pm = re.search(r"points\s*=\s*\{(.*?)\n\t\t\}", chunk, re.S) or re.search(
            r"points\s*=\s*\{(.*?)\}", chunk, re.S
        )
        if nm and pm:
            pts = points(pm.group(1))
            if len(pts) >= 2:
                roads.append(
                    {
                        "name": nm.group(1),
                        "kind": kd.group(1) if kd else "residential",
                        "width": float(wd.group(1)) if wd else 20.0,
                        "points": pts,
                    }
                )
    out["roads"] = roads

    riv = section(src, "RIVER", "BRIDGES")
    out["river"] = {
        "points": points(riv),
        "width": float(re.search(r"width\s*=\s*([\d.]+)", riv).group(1)),
    }

    rail = section(src, "RAIL", "DISTRICTS")
    st = re.search(r"station\s*=\s*\{(.*?)\}", rail, re.S)
    out["rail"] = {"points": points(rail[: rail.index("station")]), "width": 16.0}
    out["station"] = points(st.group(1))[0] if st else None

    out["bridges"] = []
    for line in section(src, "BRIDGES", "BRIDGE_RISE").splitlines():
        nm = re.search(r'name\s*=\s*"([^"]+)"', line)
        pts = points(line)
        if nm and len(pts) == 2:
            out["bridges"].append({"name": nm.group(1), "from": pts[0], "to": pts[1]})

    out["plots"] = []
    for chunk in re.split(r"\n\t\{", section(src, "PLOTS", "ROADS")):
        nm = re.search(r'name\s*=\s*"([^"]+)"', chunk)
        cm = re.search(r"centre\s*=\s*" + VEC, chunk)
        if nm and cm:
            out["plots"].append(
                {"name": nm.group(1), "centre": (float(cm.group(1)), float(cm.group(2)))}
            )

    out["roundabouts"] = []
    for line in section(src, "ROUNDABOUTS", "PLOTS").splitlines():
        nm = re.search(r'name\s*=\s*"([^"]+)"', line)
        cm = re.search(r"centre\s*=\s*" + VEC, line)
        rr = re.search(r"radius\s*=\s*([\d.]+)", line)
        if nm and cm and rr:
            out["roundabouts"].append(
                {
                    "name": nm.group(1),
                    "centre": (float(cm.group(1)), float(cm.group(2))),
                    "radius": float(rr.group(1)),
                }
            )

    districts = []
    for chunk in re.split(r"\n\t\{\n", section(src, "DISTRICTS", "LANDMARKS")):
        nm = re.search(r'name\s*=\s*"([^"]+)"', chunk)
        if not nm:
            continue
        blocks = []
        for line in chunk.splitlines():
            cm = re.search(r"centre\s*=\s*" + VEC, line)
            sm = re.search(r"size\s*=\s*" + VEC, line)
            ym = re.search(r"yaw\s*=\s*(-?[\d.]+)", line)
            um = re.search(r'use\s*=\s*"([^"]+)"', line)
            if cm and sm:
                blocks.append(
                    {
                        "centre": (float(cm.group(1)), float(cm.group(2))),
                        "size": (float(sm.group(1)), float(sm.group(2))),
                        "yaw": float(ym.group(1)) if ym else 0.0,
                        "use": um.group(1) if um else "",
                    }
                )
        if blocks:
            districts.append({"name": nm.group(1), "blocks": blocks})
    out["districts"] = districts

    out["landmarks"] = []
    for line in section(src, "LANDMARKS", "BUS_STOPS").splitlines():
        nm = re.search(r'name\s*=\s*"([^"]+)"', line)
        pm = re.search(r"position\s*=\s*" + VEC, line)
        if nm and pm:
            out["landmarks"].append(
                {"name": nm.group(1), "at": (float(pm.group(1)), float(pm.group(2)))}
            )

    ext = re.search(
        r"EXTENT\s*=\s*\{\s*minX\s*=\s*(-?\d+),\s*maxX\s*=\s*(-?\d+),\s*minZ\s*=\s*(-?\d+),\s*maxZ\s*=\s*(-?\d+)",
        src,
    )
    out["extent"] = [float(g) for g in ext.groups()]
    return out


# housing uses get their own colour: this is what we are arguing about
HOUSING = ("terrace", "semis", "house")
USE_FILL = {
    "terrace": "#c96f5a",
    "semis": "#d98f6a",
    "house": "#c96f5a",
    "shops": "#8e7cc3",
    "flats": "#8e7cc3",
    "industrial": "#8a8f98",
    "school": "#7fae6a",
    "park": "#7fae6a",
    "sports": "#7fae6a",
}
ROAD_STYLE = {
    "ring": ("#3b3f46", 1.0),
    "main": ("#4a4f57", 1.0),
    "residential": ("#6b7078", 1.0),
    "lane": ("#878c94", 1.0),
}


def use_fill(use: str) -> str:
    u = use.lower()
    for key, colour in USE_FILL.items():
        if key in u:
            return colour
    return "#a9adb4"


def is_housing(use: str) -> bool:
    u = use.lower()
    return any(k in u for k in HOUSING)


def build_svg(d) -> str:
    minX, maxX, minZ, maxZ = d["extent"]
    w = (maxX - minX) * SCALE + PAD * 2
    h = (maxZ - minZ) * SCALE + PAD * 2

    def X(x):
        return (x - minX) * SCALE + PAD

    def Y(z):
        return (z - minZ) * SCALE + PAD

    p = []
    a = p.append
    a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" '
      f'viewBox="0 0 {w:.0f} {h:.0f}" font-family="Inter,Segoe UI,sans-serif">')
    a(f'<rect width="{w:.0f}" height="{h:.0f}" fill="#eef0e9"/>')

    # river then rail, under the roads
    riv = d["river"]
    pl = " ".join(f"{X(x):.1f},{Y(z):.1f}" for x, z in riv["points"])
    a(f'<polyline points="{pl}" fill="none" stroke="#7fb5d5" '
      f'stroke-width="{riv["width"] * SCALE:.1f}" stroke-linejoin="round" stroke-linecap="round"/>')

    rl = d["rail"]
    pl = " ".join(f"{X(x):.1f},{Y(z):.1f}" for x, z in rl["points"])
    a(f'<polyline points="{pl}" fill="none" stroke="#5c5750" stroke-width="{rl["width"] * SCALE:.1f}"/>')
    a(f'<polyline points="{pl}" fill="none" stroke="#e8e4dc" stroke-width="1.4" stroke-dasharray="6 6"/>')

    # roads, widest first so junctions read
    for r in sorted(d["roads"], key=lambda r: -r["width"]):
        colour, _ = ROAD_STYLE.get(r["kind"], ROAD_STYLE["residential"])
        pl = " ".join(f"{X(x):.1f},{Y(z):.1f}" for x, z in r["points"])
        a(f'<polyline points="{pl}" fill="none" stroke="{colour}" '
          f'stroke-width="{r["width"] * SCALE:.1f}" stroke-linejoin="round" stroke-linecap="round"/>')

    for rb in d["roundabouts"]:
        cx, cz = rb["centre"]
        a(f'<circle cx="{X(cx):.1f}" cy="{Y(cz):.1f}" r="{rb["radius"] * SCALE:.1f}" '
          f'fill="#eef0e9" stroke="#4a4f57" stroke-width="2"/>')

    for b in d["bridges"]:
        (x0, z0), (x1, z1) = b["from"], b["to"]
        a(f'<line x1="{X(x0):.1f}" y1="{Y(z0):.1f}" x2="{X(x1):.1f}" y2="{Y(z1):.1f}" '
          f'stroke="#2d3036" stroke-width="3" stroke-dasharray="3 3"/>')

    # blocks: housing outlined so the rows are countable
    for dist in d["districts"]:
        for blk in dist["blocks"]:
            cx, cz = blk["centre"]
            sx, sz = blk["size"]
            fill = use_fill(blk["use"])
            stroke = "#7a2f1b" if is_housing(blk["use"]) else "none"
            a(f'<g transform="translate({X(cx):.1f},{Y(cz):.1f}) rotate({blk["yaw"]:.1f})">'
              f'<rect x="{-sx * SCALE / 2:.1f}" y="{-sz * SCALE / 2:.1f}" '
              f'width="{sx * SCALE:.1f}" height="{sz * SCALE:.1f}" fill="{fill}" '
              f'fill-opacity="0.85" stroke="{stroke}" stroke-width="0.5"/></g>')

    # the four club plots, 760 studs square
    for plot in d["plots"]:
        cx, cz = plot["centre"]
        s = 760 * SCALE
        a(f'<rect x="{X(cx) - s / 2:.1f}" y="{Y(cz) - s / 2:.1f}" width="{s:.1f}" height="{s:.1f}" '
          f'fill="#2f7d4f" fill-opacity="0.18" stroke="#2f7d4f" stroke-width="2.5" stroke-dasharray="8 5"/>')
        a(f'<text x="{X(cx):.1f}" y="{Y(cz):.1f}" font-size="18" font-weight="700" '
          f'fill="#1d5133" text-anchor="middle">{plot["name"]}</text>')

    sq = re.search(r"", "")  # market square drawn from its own constant below
    a(f'<circle cx="{X(0):.1f}" cy="{Y(0):.1f}" r="{60 * SCALE:.1f}" fill="#d8c98a" stroke="#8a7b3f" stroke-width="2"/>')
    a(f'<text x="{X(0):.1f}" y="{Y(0) - 26:.1f}" font-size="15" font-weight="700" fill="#4a4222" '
      f'text-anchor="middle">Market Square</text>')

    if d["station"]:
        sx, sz = d["station"]
        a(f'<rect x="{X(sx) - 40:.1f}" y="{Y(sz) - 8:.1f}" width="80" height="16" fill="#5c5750"/>')
        a(f'<text x="{X(sx):.1f}" y="{Y(sz) - 14:.1f}" font-size="14" font-weight="600" fill="#3a3630" '
          f'text-anchor="middle">Rivermere Station</text>')

    for lm in d["landmarks"]:
        x, z = lm["at"]
        a(f'<circle cx="{X(x):.1f}" cy="{Y(z):.1f}" r="5" fill="#b2402f"/>')
        a(f'<text x="{X(x) + 9:.1f}" y="{Y(z) + 4:.1f}" font-size="13" fill="#7a2f1b">{lm["name"]}</text>')

    # district labels at the centroid of their blocks
    for dist in d["districts"]:
        xs = [b["centre"][0] for b in dist["blocks"]]
        zs = [b["centre"][1] for b in dist["blocks"]]
        cx, cz = sum(xs) / len(xs), sum(zs) / len(zs)
        a(f'<text x="{X(cx):.1f}" y="{Y(cz):.1f}" font-size="21" font-weight="800" fill="#2d3036" '
          f'text-anchor="middle" opacity="0.72">{dist["name"]}</text>')

    # road names, once per road, at its midpoint
    for r in d["roads"]:
        pts = r["points"]
        mid = pts[len(pts) // 2]
        if r["kind"] in ("ring", "main"):
            a(f'<text x="{X(mid[0]):.1f}" y="{Y(mid[1]):.1f}" font-size="12" fill="#f2f2ee" '
              f'text-anchor="middle" opacity="0.9">{r["name"]}</text>')

    # legend + scale bar
    lx, ly = PAD, h - PAD - 96
    a(f'<rect x="{lx}" y="{ly}" width="250" height="104" fill="#ffffff" fill-opacity="0.88" stroke="#b9bcb4"/>')
    a(f'<text x="{lx + 10}" y="{ly + 20}" font-size="14" font-weight="700" fill="#2d3036">Rivermere</text>')
    rows = [
        ("#c96f5a", "terraces / semis"),
        ("#8e7cc3", "shops &amp; flats"),
        ("#8a8f98", "industrial"),
        ("#7fae6a", "green / school / sport"),
        ("#2f7d4f", "club plot (760 studs)"),
    ]
    for i, (colour, label) in enumerate(rows):
        y = ly + 34 + i * 14
        a(f'<rect x="{lx + 10}" y="{y - 8}" width="12" height="10" fill="{colour}"/>')
        a(f'<text x="{lx + 28}" y="{y}" font-size="11" fill="#3a3e45">{label}</text>')
    bar = 500 * SCALE
    bx, by = w - PAD - bar - 10, h - PAD - 18
    a(f'<line x1="{bx:.1f}" y1="{by:.1f}" x2="{bx + bar:.1f}" y2="{by:.1f}" stroke="#2d3036" stroke-width="3"/>')
    a(f'<text x="{bx + bar / 2:.1f}" y="{by - 6:.1f}" font-size="12" fill="#2d3036" text-anchor="middle">'
      f'500 studs (182 m)</text>')
    a(f'<text x="{PAD}" y="{PAD - 14}" font-size="13" fill="#6a6e75">north is up (world -Z)</text>')
    a("</svg>")
    return "\n".join(p)


def main():
    d = parse()
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "town_map.svg"
    out.write_text(build_svg(d), encoding="utf-8")
    housing = sum(1 for dist in d["districts"] for b in dist["blocks"] if is_housing(b["use"]))
    blocks = sum(len(dist["blocks"]) for dist in d["districts"])
    print(f"{out}")
    print(f"  roads {len(d['roads'])}  districts {len(d['districts'])}  "
          f"blocks {blocks} (housing {housing})  plots {len(d['plots'])}  "
          f"roundabouts {len(d['roundabouts'])}")


if __name__ == "__main__":
    main()
