"""A PROPOSED Rivermere, drawn to argue about before any of it is built.

    python tools/town_plan_v2.py [out.svg]

Nothing here touches the game. It emits the same shape of data as
tools/town_map.py so it can reuse that renderer, which means the proposal and
the real town can be compared like for like.

What it changes, and why:

* Bigger footprint (4800 x 3400 -> 6600 x 4600 studs). The plots were stranded
  in the corners outside the ring; a wider town lets each one sit INSIDE a
  neighbourhood with housing around it, instead of at the edge of nowhere.

* The ring road becomes an OCTAGON. It keeps the loop, but every segment is
  either axis-aligned or 45 degrees, which is exactly the vocabulary the road
  kit ships (straight, 45 bend, 90 bend, T, crossroads, fork). The old ring was
  an 18-point curve: 71% of its length was at arbitrary angles and could never
  be tiled.

* Four plots evenly spaced N/E/S/W at a consistent radius, rather than two
  clustered east and nothing in the south-west.

* Housing is GENERATED from the streets, one row down each side at a fixed
  setback. That is the whole point: a row cannot end up three deep, cannot end
  up off-parallel, and cannot end up with nothing in front of it, because every
  row is derived from a street frontage.

* The centre is deliberately thinned out. Today Northfields alone is a solid
  mass of terraces; here the middle is square, shops and civic space, and the
  housing sits in the neighbourhoods around each plot.

The river, the railway and the station are taken from the CURRENT layout
unchanged, because those are the bits worth keeping.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from town_map import build_svg, parse  # noqa: E402

# ------------------------------------------------------------------ the plan

EXTENT = (-3300.0, 3300.0, -2300.0, 2300.0)

# Octagon ring: half-width, half-height, and how much of each corner is cut
# off at 45 degrees. Every resulting segment is axis-aligned or exactly 45.
RING_X, RING_Z, CUT = 2500.0, 1800.0, 700.0

PLOT_RADIUS_X, PLOT_RADIUS_Z = 1750.0, 1200.0
STREET_SPACING = 200.0  # between parallel residential streets
ROW_SETBACK = 42.0      # street centreline -> centre of a housing row
ROW_DEPTH = 26.0
ROW_MAX = 130.0         # longest single terrace row before a gap


def ring_points():
    x, z, c = RING_X, RING_Z, CUT
    return [
        (-x + c, -z), (x - c, -z),     # north side
        (x, -z + c), (x, z - c),       # east side
        (x - c, z), (-x + c, z),       # south side
        (-x, z - c), (-x, -z + c),     # west side
        (-x + c, -z),                  # close the loop
    ]


def neighbourhood(cx, cz, half_x, half_z, name, skip=None):
    """A grid of residential streets around a plot. `skip` is a keep-out box
    (the plot itself) that streets stop short of."""
    roads = []
    n = 0
    z = cz - half_z
    while z <= cz + half_z + 1:
        roads.append({
            "name": f"{name} Street {n + 1}",
            "kind": "residential",
            "width": 20.0,
            "points": [(cx - half_x, z), (cx + half_x, z)],
        })
        n += 1
        z += STREET_SPACING
    x = cx - half_x
    m = 0
    while x <= cx + half_x + 1:
        roads.append({
            "name": f"{name} Avenue {m + 1}",
            "kind": "residential",
            "width": 20.0,
            "points": [(x, cz - half_z), (x, cz + half_z)],
        })
        m += 1
        x += STREET_SPACING * 1.5
    if skip:
        roads = [r for r in roads if not _crosses(r, skip)]
    return roads


def _crosses(road, box):
    (bx0, bz0, bx1, bz1) = box
    for i in range(1, len(road["points"])):
        (x0, z0), (x1, z1) = road["points"][i - 1], road["points"][i]
        if max(x0, x1) > bx0 and min(x0, x1) < bx1 and max(z0, z1) > bz0 and min(z0, z1) < bz1:
            return True
    return False


def rows_from_streets(roads, keepouts):
    """Housing generated from street frontage: one row down each side, parallel
    by construction. This is the proposed generator, in miniature."""
    blocks = []
    for r in roads:
        if r["kind"] != "residential":
            continue
        for i in range(1, len(r["points"])):
            (x0, z0), (x1, z1) = r["points"][i - 1], r["points"][i]
            seg = math.hypot(x1 - x0, z1 - z0)
            if seg < 60:
                continue
            ux, uz = (x1 - x0) / seg, (z1 - z0) / seg
            nx, nz = -uz, ux  # left normal
            count = max(1, int(seg // ROW_MAX))
            step = seg / count
            for side in (-1, 1):
                for k in range(count):
                    t = (k + 0.5) * step
                    mx, mz = x0 + ux * t, z0 + uz * t
                    px = mx + nx * ROW_SETBACK * side
                    pz = mz + nz * ROW_SETBACK * side
                    if any(bx0 < px < bx1 and bz0 < pz < bz1 for bx0, bz0, bx1, bz1 in keepouts):
                        continue
                    yaw = math.degrees(math.atan2(uz, ux))
                    blocks.append({
                        "centre": (px, pz),
                        "size": (step - 14, ROW_DEPTH),
                        "yaw": yaw,
                        "use": "terraced row",
                    })
    return blocks


def diagonal_hood(cx, cz, reach, name):
    """A small quarter on 45 degrees, using the kit's 45-degree bends. Keeps the
    town from reading as a pure chessboard."""
    roads = []
    for k in range(-2, 3):
        off = k * STREET_SPACING * 0.9
        ax, az = cx - reach + off, cz - reach - off
        bx, bz = cx + reach + off, cz + reach - off
        roads.append({"name": f"{name} Row {k + 3}", "kind": "residential", "width": 20.0,
                      "points": [(ax, az), (bx, bz)]})
    return roads


def plan():
    live = parse()  # river, rail and station are kept as they are
    roads = [{"name": "Ring Road", "kind": "ring", "width": 32.0, "points": ring_points()}]

    # radials into the square; two sit on 45 degrees so the kit's bend pieces
    # get used and the town is not a pure chessboard
    roads += [
        {"name": "North Road", "kind": "main", "width": 26.0, "points": [(0, -RING_Z), (0, -160)]},
        {"name": "South Road", "kind": "main", "width": 26.0, "points": [(0, RING_Z), (0, 160)]},
        {"name": "West Road", "kind": "main", "width": 26.0, "points": [(-RING_X, 0), (-160, 0)]},
        {"name": "East Road", "kind": "main", "width": 26.0, "points": [(RING_X, 0), (160, 0)]},
        {"name": "Mapleford Way", "kind": "main", "width": 26.0,
         "points": [(-RING_X + CUT, -RING_Z), (-620, -620), (-170, -170)]},
        {"name": "Hollingford Way", "kind": "main", "width": 26.0,
         "points": [(RING_X - CUT, RING_Z), (620, 620), (170, 170)]},
        {"name": "Station Approach", "kind": "main", "width": 26.0,
         "points": [(-RING_X + CUT, RING_Z), (-900, 900), (-900, -300)]},
    ]

    # Plots are evenly spaced but NOT on a perfect cross: each is nudged so the
    # town does not read as a diagram, and each sits inside its own estate.
    spots = [
        ("Plot 1", "Northfields", 260.0, -PLOT_RADIUS_Z, 820, 560),
        ("Plot 2", "Riverside", PLOT_RADIUS_X, -260.0, 700, 640),
        ("Plot 3", "Westdale", -260.0, PLOT_RADIUS_Z, 880, 560),
        ("Plot 4", "Ashcroft", -PLOT_RADIUS_X, 200.0, 700, 620),
    ]
    plots, keepouts, districts = [], [], []
    for label, hood_name, px, pz, hx, hz in spots:
        plots.append({"name": f"{label} - {hood_name}", "centre": (px, pz)})
        keepouts.append((px - 420, pz - 420, px + 420, pz + 420))

    for label, hood_name, px, pz, hx, hz in spots:
        hood = neighbourhood(px, pz, hx, hz, hood_name,
                             skip=(px - 400, pz - 400, px + 400, pz + 400))
        roads += hood
        districts.append({"name": hood_name, "blocks": rows_from_streets(hood, keepouts)})

    # a 45-degree quarter between the centre and the north-east, so at least one
    # settlement sits off the grid the way you asked
    diag = diagonal_hood(1050, -950, 320, "Millbrook")
    roads += diag
    districts.append({"name": "Millbrook", "blocks": rows_from_streets(diag, keepouts)})

    # the middle stays civic: square and shops, no terracing at all
    centre_blocks = []
    for dx, dz in ((-170, -120), (170, -120), (-170, 120), (170, 120)):
        centre_blocks.append({"centre": (dx, dz), "size": (200, 64), "yaw": 0.0, "use": "shops with flats"})
    for dx, dz in ((-380, 0), (380, 0)):
        centre_blocks.append({"centre": (dx, dz), "size": (120, 150), "yaw": 0.0, "use": "shops"})
    districts.append({"name": "Town Centre", "blocks": centre_blocks})

    # the character districts the first draft dropped: industry by the railway,
    # park on the river, sport in a spare corner
    industrial = [{"centre": (-1850 + i % 4 * 190, -1150 + (i // 4) * 210),
                   "size": (150, 150), "yaw": 0.0, "use": "industrial"} for i in range(12)]
    districts.append({"name": "Industrial Estate", "blocks": industrial})

    park = [{"centre": (700, 620), "size": (620, 360), "yaw": 0.0, "use": "park"}]
    districts.append({"name": "Riverside Park", "blocks": park})

    sports = [{"centre": (-1500, 1250), "size": (520, 320), "yaw": 0.0, "use": "sports"},
              {"centre": (-1500, 1010), "size": (200, 90), "yaw": 0.0, "use": "sports hall"}]
    districts.append({"name": "Community Sports Centre", "blocks": sports})

    return {
        "roads": roads,
        "river": live["river"],
        "rail": live["rail"],
        "station": live["station"],
        "bridges": live["bridges"],
        "plots": plots,
        "roundabouts": [
            {"name": "N", "centre": (0.0, -RING_Z), "radius": 40.0},
            {"name": "S", "centre": (0.0, RING_Z), "radius": 40.0},
            {"name": "W", "centre": (-RING_X, 0.0), "radius": 40.0},
            {"name": "E", "centre": (RING_X, 0.0), "radius": 40.0},
            {"name": "NE", "centre": (RING_X - CUT, -RING_Z), "radius": 40.0},
            {"name": "SW", "centre": (-RING_X + CUT, RING_Z), "radius": 40.0},
        ],
        "districts": districts,
        "landmarks": live["landmarks"],
        "extent": list(EXTENT),
    }


def main():
    d = plan()
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "docs" / "town_plan_v2.svg"
    out.write_text(build_svg(d), encoding="utf-8")
    houses = sum(len(x["blocks"]) for x in d["districts"])
    res = [r for r in d["roads"] if r["kind"] == "residential"]
    length = sum(
        math.hypot(r["points"][i][0] - r["points"][i - 1][0], r["points"][i][1] - r["points"][i - 1][1])
        for r in d["roads"] for i in range(1, len(r["points"]))
    )
    print(out)
    print(f"  roads {len(d['roads'])} ({len(res)} residential)  total {length:,.0f} studs")
    print(f"  housing rows generated from frontage: {houses}")


if __name__ == "__main__":
    main()
