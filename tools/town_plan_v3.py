"""Rivermere v3: the CURRENT town, evolved. Drawn to be approved before any game
code changes.

    python tools/town_plan_v3.py

writes docs/town_map_v3.svg, docs/town_map_v3.png and docs/town_map_v3_view.html
and prints the audit (stacked rows, off-parallel rows, how much road is tileable).

What v3 is, in one breath: same river, same railway, same station, same extent,
same districts, same residential grid. Three things change.

1. HOUSING IS GENERATED FROM THE STREETS. Nobody authors a housing block any
   more. Each residential street gets one row down each side at a fixed setback,
   so a row cannot be behind another row and cannot be off-parallel. Where v1
   had rows stacked 2-4 deep there is now either a new street or back gardens.

2. THE RING AND THE THROUGH ROADS ARE SNAPPED to axis / 45 degrees, staying as
   close to their v1 lines as that allows, so the bought road kit can tile them.

3. THE PLOTS COME IN. 2 and 4 slide toward the ring and get streets wrapped
   round them, 1 stays, and 3 leaves the east (where it crowded 2) for Westdale
   in the south-west, which had no ground at all.

Everything that is not housing (shops, pubs, church, school, sheds, park,
sports centre) is carried over from the live layout; a block is only nudged if
a straightened road now runs through it.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from town_map import build_svg, is_housing, parse  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

EXTENT = (-2400.0, 2400.0, -1700.0, 1700.0)  # unchanged from v1
PLOT = 760.0
PAVE = 8.0
GARDEN = 6.0      # pavement -> house front, as v1's frontage script used
DEPTH = 24.0      # house depth, as v1
CELL = 22.0       # one house of frontage
ROW_CELLS = 6     # longest terrace before a ginnel
ROW_GAP = 8.0
HEAD = 34.0       # cul-de-sac turning head radius (kit CulDeSac is 96 x 69 at town scale)

# ------------------------------------------------------------------ roads

R, M, S, L = "ring", "main", "residential", "lane"
WIDTH = {R: 32.0, M: 26.0, S: 20.0, L: 20.0}


def road(name, kind, pts, front=None, use="terraced row", district=None, use_at=None, head=False):
    """front: "both" | "left" | "right" | "none" (left of the direction of
    travel). Residential streets default to both sides, everything else to none."""
    if front is None:
        front = "both" if kind == S else "none"
    return {"name": name, "kind": kind, "width": WIDTH[kind],
            "points": [(float(x), float(z)) for x, z in pts],
            "front": front, "use": use, "district": district, "use_at": use_at,
            "head": head}  # head: the last point is a cul-de-sac turning head (kit: CulDeSac*)


RING = [
    (-1100, -1000), (-500, -1000),      # north-west shoulder
    (-420, -1080), (420, -1080),        # the bow v1 had at North Road, as two 45 ramps
    (500, -1000), (1000, -1000),        # north-east shoulder
    (1400, -600), (1400, 400),          # big NE chamfer, east side on v1's x (East Bridge stays)
    (1250, 550), (1250, 650),           # SE corner in two steps; the roundabout sits on the straight
    (1100, 800), (-1000, 800),          # south side on v1's z
    (-1150, 650), (-1150, 0),           # SW chamfer, west side on v1's x (West Bridge stays)
    (-1350, -200), (-1350, -750),       # the jog out round the station quarter
    (-1100, -1000),
]


def roads():
    out = [road("Ring Road", R, RING)]

    # ---- through roads, each as near its v1 line as axis/45 allows
    out += [
        road("North Road", M, [(0, -60), (0, -1080)]),
        road("High Street", M, [(-60, 0), (-400, 0), (-505, -105), (-1255, -105)], front="both",
             use_at=lambda x, z: ("shops with flats", "Town Centre") if x > -520 else ("terraced row", "Station")),
        road("Station Road", M, [(-505, -105), (-737, -337), (-938, -337)]),
        road("Riverside Road", M, [(60, 0), (1340, 0), (1400, -60)], front="both",
             use_at=lambda x, z: ("shops with flats", "Town Centre") if x < 620 else ("terraced row", "Riverside")),
        road("Bridge Street", M, [(0, 60), (0, 200), (100, 300), (100, 700), (0, 800)]),
        road("Mapleford Road", M, [(-1350, -400), (-2400, -400)]),
        road("Estate Road", M, [(-1255, -105), (-2300, -105)]),
        # Greenbridge Road takes Moss Lane's line due west; the old diagonal to
        # the south-west corner is where Plot 3 now stands
        road("Greenbridge Road", M, [(-1150, 560), (-2400, 560)],
             front="right", district="Westdale"),
        road("Hollingford Road", M, [(1250, 600), (1300, 600), (1500, 800), (2400, 800)],
             front="both", district="Hollingford"),
    ]

    # ---- Mill Street Terraces: untouched
    out += [
        road("Mill Street", S, [(0, -200), (900, -200)], district="Mill Street Terraces"),
        road("Weaver Street", S, [(-430, -330), (900, -330)], district="Mill Street Terraces"),
        road("Elm Grove", S, [(-500, -440), (900, -440)], district="Mill Street Terraces"),
    ]

    # ---- Northfields: same avenue, same closes; the closes now stop at the
    # flat ring, Linden Way runs further west, Poplar Close gives way to a green
    nf = "Northfields"
    out += [
        road("Northfields Avenue", S, [(-1350, -600), (1400, -600)], district=nf),
        road("Linden Way", S, [(-1000, -920), (850, -920)], district=nf),
    ]
    for name, x, end in [("Elder Close", -1200, -840), ("Ash Close", -1000, -920),
                         ("Birch Close", -800, -920), ("Cherry Close", -600, -920),
                         ("Hazel Close", -400, -920), ("Rowan Close", -200, -920),
                         ("Holly Close", 225, -920), ("Hayfield Close", 400, -920),
                         ("Laurel Close", 650, -920), ("Maple Close", 850, -920),
                         ("Oak Close", 1050, -870)]:
        semis = abs(x) >= 1000
        out.append(road(name, S, [(x, -600), (x, end)], district=nf,
                        use="semis" if semis else "terraced row", head=end != -920))

    # ---- Station quarter: one new street where rows stood five deep
    st = "Station"
    out += [
        road("Church Lane", S, [(-360, 0), (-360, -330)], district="Town Centre", front="none"),
        road("Cooper Street", S, [(-1350, -240), (-640, -240)], district=st),
        road("Signal Street", S, [(-1150, 25), (-560, 25)], district=st),          # NEW
        road("Lock Street", S, [(-1150, 150), (-540, 150)], district=st),
        road("Foundry Way", S, [(-1480, -400), (-1480, 120)], front="none"),
        road("Lune Street", S, [(-440, 260), (480, 260)], district="Town Centre",
             use="flats"),
    ]

    # ---- Riverside (south bank, inside the ring): one new street
    rv = "Riverside"
    out += [
        road("Meadow Road", S, [(100, 560), (1180, 560)], district=rv, head=True),
        road("Tannery Row", S, [(100, 680), (1100, 680)], district=rv, head=True),            # NEW
        road("Viaduct Road", S, [(-545, 620), (100, 620)], district=rv),
        road("Weir Road", S, [(-1150, 560), (-615, 560)], district=rv),
        road("Fuller Street", S, [(-1090, 690), (-615, 690)], district=rv),         # NEW
    ]

    # ---- south of the ring
    out += [
        road("Sports Centre Road", S, [(0, 800), (0, 1200), (590, 1200)], district=rv,
             front="none"),
        road("Cedar Road", S, [(-470, 800), (-470, 1500)], district=rv, head=True),
        road("Paddock Road", S, [(400, 800), (400, 1500)], district=rv, head=True),           # NEW
        road("Hollins Road", S, [(590, 800), (590, 1500)], district=rv, head=True),           # was x=520
        road("Plot 1 Lane", L, [(970, 800), (970, 860)]),
    ]

    # ---- Westdale, rebuilt round Plot 3
    wd = "Westdale"
    out += [
        road("Moss Lane", S, [(-2240, 430), (-1250, 430)], district=wd),
        road("Reed Road", S, [(-1600, 430), (-1600, 560)], district=wd, front="none"),
        road("Alder Road", S, [(-1310, 560), (-1310, 1480)], district=wd),
        road("Tanner's Lane", S, [(-2240, 560), (-2240, 1480)], district=wd),       # NEW
        road("Orchard Road", S, [(-2240, 1480), (-690, 1480)], district=wd),
        road("Fern Street", S, [(-1310, 800), (-1000, 800)], district=wd),
        road("Westdale Avenue", S, [(-1310, 950), (-690, 950)], district=wd),
        road("Brook Street", S, [(-1310, 1100), (-690, 1100)], district=wd),
        road("Westdale Crescent", S, [(-1310, 1250), (-690, 1250)], district=wd),
        road("Coronation Street", S, [(-1310, 1365), (-690, 1365)], district=wd),   # NEW
        road("Westdale Road", S, [(-915, 800), (-915, 1480)], district=wd),
        road("Plot 3 Lane", L, [(-1860, 560), (-1860, 630)]),
    ]

    # ---- Mapleford: Plot 4's estate (north-west). Not a box round the plot:
    # a street south, a street north, and closes filling the ground between the
    # plot and the ring, so the club sits at the end of somebody's road.
    p4 = "Mapleford"
    out += [
        road("Plot 4 Lane", L, [(-1350, -750), (-1350, -1210), (-1400, -1210)]),
        road("Mapleford Lane", S, [(-2250, -670), (-1350, -670)], district=p4),
        road("Drift Close", S, [(-2250, -670), (-2250, -1060)], district=p4, head=True),
        road("Tollgate Road", S, [(-1350, -1210), (-1350, -1590), (-2120, -1590)], district=p4, head=True),
        road("Drovers Road", S, [(-1350, -1210), (-760, -1210)], district=p4, head=True),
        road("Pinfold Close", S, [(-950, -1210), (-950, -1110)], district=p4, head=True),
        road("Smithy Close", S, [(-1120, -1210), (-1120, -1460), (-880, -1460)], district=p4,
             use="semis", head=True),
    ]

    # ---- Millbrook: Plot 2's estate (north-east), deliberately not Mapleford's mirror
    p2 = "Millbrook"
    out += [
        road("Plot 2 Lane", L, [(1400, -600), (1400, -1080), (1440, -1080)]),
        road("Millbrook Road", S, [(1400, -700), (2300, -700)], district=p2),
        road("Lune View", S, [(1560, -570), (2250, -570)], district=p2, head=True),
        road("Fell Lane", S, [(2300, -700), (2300, -1320)], district=p2, head=True),
        road("Quarry Road", S, [(1400, -1080), (900, -1080), (780, -1200)], district=p2, head=True),
        road("Kiln Close", S, [(1180, -1080), (1180, -1400)], district=p2, use="semis", head=True),
        road("Millbrook Rise", S, [(1400, -1080), (1400, -1330)], district=p2, head=True),
    ]

    # ---- Hollingford: the 45-degree estate, in the ground Plot 3 left. Every
    # street is parallel to Hollingford Road's own 45 leg off the roundabout.
    hf = "Hollingford"
    out += [
        road("Lunebank Road", S, [(1400, 300), (1500, 300), (1940, 740), (1940, 800)], district=hf),
        road("Ferry Lane", S, [(1500, 300), (1593, 207)], district=hf, front="none"),
        road("Fellmonger Street", S, [(1500, 480), (1760, 740), (1760, 800)], district=hf),
        road("Bleach Street", S, [(1593, 207), (2126, 740), (2126, 800)], district=hf),
        # beside Plot 1
        road("Garth Road", S, [(1510, 800), (1510, 1560)], district=hf, head=True),
    ]
    return out


PLOTS = [
    {"name": "Plot 1", "centre": (1050.0, 1250.0), "was": (1050, 1250), "faces": "north"},
    {"name": "Plot 2", "centre": (1830.0, -1160.0), "was": (1900, -1200), "faces": "west"},
    {"name": "Plot 3", "centre": (-1780.0, 1020.0), "was": (1950, 420), "faces": "north"},
    {"name": "Plot 4", "centre": (-1790.0, -1130.0), "was": (-1900, -1200), "faces": "east"},
]

ROUNDABOUTS = [
    ("Northfields Roundabout", 0, -1080, 40),
    ("Plot 4 Roundabout", -1350, -750, 40),
    ("Plot 2 Roundabout", 1400, -600, 40),
    ("Lunebank Roundabout", 1400, 300, 40),       # was Plot 3 Roundabout
    ("Hollingford Roundabout", 1250, 600, 40),
    ("Sports Centre Roundabout", 0, 800, 40),
    ("Westdale Roundabout", -1150, 560, 40),
    ("High Street Roundabout", -1255, -105, 40),
    ("Mapleford Roundabout", -1350, -400, 40),
    ("Foundry Way Roundabout", -1480, -105, 16),
]

# New non-housing blocks: the green and the shops Northfields never had.
EXTRA_BLOCKS = {
    "Northfields": [
        {"centre": (1230.0, -700.0), "size": (150.0, 110.0), "yaw": 0.0, "use": "park"},      # where Poplar Close was
        {"centre": (-100.0, -760.0), "size": (100.0, 180.0), "yaw": 0.0, "use": "park"},      # Northfields Green
        {"centre": (525.0, -760.0), "size": (110.0, 180.0), "yaw": 0.0, "use": "park"},       # allotments
        {"centre": (75.0, -645.0), "size": (110.0, 30.0), "yaw": 0.0, "use": "shops"},        # parade on the avenue
        {"centre": (-75.0, -555.0), "size": (110.0, 30.0), "yaw": 0.0, "use": "shops"},
    ],
    "Westdale": [
        {"centre": (-1110.0, 1025.0), "size": (140.0, 90.0), "yaw": 0.0, "use": "school"},   # v1's school, moved 140 east off Alder Road
        {"centre": (-800.0, 1175.0), "size": (150.0, 80.0), "yaw": 0.0, "use": "park"},
    ],
    "Hollingford": [
        {"centre": (1560.0, 40.0), "size": (120.0, 120.0), "yaw": 45.0, "use": "park"},       # river meadow
    ],
}

# v1 blocks that must go because something else now stands there
DROP_NEAR_PLOT = 30.0

# ------------------------------------------------------------------ geometry


def seg_dist(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - ax - t * dx, pz - az - t * dz)


def corners(b, grow=0.0):
    cx, cz = b["centre"]
    sx, sz = b["size"][0] / 2 + grow, b["size"][1] / 2 + grow
    a = math.radians(b["yaw"])
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + lx * ca - lz * sa, cz + lx * sa + lz * ca)
            for lx, lz in ((-sx, -sz), (sx, -sz), (sx, sz), (-sx, sz))]


def samples(b):
    c = corners(b)
    mids = [((c[i][0] + c[(i + 1) % 4][0]) / 2, (c[i][1] + c[(i + 1) % 4][1]) / 2) for i in range(4)]
    return c + mids + [b["centre"]]


def overlap(a, b, margin=0.0):
    """Separating-axis test for two rotated rectangles."""
    ca, cb = corners(a, margin / 2), corners(b, margin / 2)
    for poly in (ca, cb):
        for i in range(2):
            ex, ez = poly[i + 1][0] - poly[i][0], poly[i + 1][1] - poly[i][1]
            nx, nz = -ez, ex
            pa = [x * nx + z * nz for x, z in ca]
            pb = [x * nx + z * nz for x, z in cb]
            if max(pa) <= min(pb) or max(pb) <= min(pa):
                return False
    return True


def segments(r):
    return list(zip(r["points"], r["points"][1:]))


def angle_class(a, b):
    ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])) % 90
    if min(ang, 90 - ang) < 0.5:
        return "axis"
    if abs(ang - 45) < 0.5:
        return "45"
    return "other"


# ------------------------------------------------------------------ the generator


class Town:
    def __init__(self, live):
        self.live = live
        self.roads = roads()
        self.plots = PLOTS
        self.kept = []       # (district, block) carried over from v1
        self.rows = []       # (district, block) generated
        self.cells = []      # every accepted house cell, for the collision test
        self.nudged = []
        self.dropped = []

    # --- clearances ---------------------------------------------------
    def road_clear(self, blk, skip=None, extra=GARDEN - 2):
        pts = samples(blk)
        for r in self.roads:
            need = r["width"] / 2 + (0 if r["kind"] == L else PAVE) + extra
            for a, b in segments(r):
                if skip is not None and (r is skip[0] and (a, b) == skip[1]):
                    continue
                if any(seg_dist(p, a, b) < need for p in pts):
                    return False
        return True

    def ground_clear(self, blk, heads=True):
        pts = samples(blk)
        minX, maxX, minZ, maxZ = EXTENT
        if any(not (minX + 20 < x < maxX - 20 and minZ + 20 < z < maxZ - 20) for x, z in pts):
            return False
        riv = self.live["river"]
        for a, b in zip(riv["points"], riv["points"][1:]):
            if any(seg_dist(p, a, b) < riv["width"] / 2 + 20 for p in pts):
                return False
        rail = self.live["rail"]["points"]
        for a, b in zip(rail, rail[1:]):
            if any(seg_dist(p, a, b) < 8 + 22 for p in pts):
                return False
        for _, x, z, rad in ROUNDABOUTS:
            if any(math.hypot(px - x, pz - z) < rad + PAVE + 6 for px, pz in pts):
                return False
        if heads:
            for r in self.roads:
                if r["head"]:
                    hx, hz = r["points"][-1]
                    if any(math.hypot(px - hx, pz - hz) < HEAD + 5 for px, pz in pts):
                        return False
        if any(math.hypot(px, pz) < 60 + 14 for px, pz in pts):
            return False
        sx, sz = self.live["station"]
        if any(abs(px - sx) < 120 + 30 and abs(pz - sz) < 20 + 40 for px, pz in pts):
            return False
        for plot in self.plots:
            cx, cz = plot["centre"]
            h = PLOT / 2 + 20
            if any(abs(px - cx) < h and abs(pz - cz) < h for px, pz in pts):
                return False
        return True

    # --- v1's non-housing, carried over ---------------------------------
    def carry_over(self):
        for dist in self.live["districts"]:
            for blk in dist["blocks"]:
                if is_housing(blk["use"]) or blk["use"] == "corner shop":
                    continue
                b = dict(blk)
                if any(abs(b["centre"][0] - p["centre"][0]) < PLOT / 2 + DROP_NEAR_PLOT
                       and abs(b["centre"][1] - p["centre"][1]) < PLOT / 2 + DROP_NEAR_PLOT
                       for p in self.plots):
                    self.dropped.append((dist["name"], blk))
                    continue
                if not self.road_clear(b, extra=0):
                    if not self.push_clear(b):
                        self.dropped.append((dist["name"], blk))
                        continue
                    self.nudged.append((dist["name"], blk, b))
                self.kept.append((dist["name"], b))
        for name, blocks in EXTRA_BLOCKS.items():
            for b in blocks:
                self.kept.append((name, dict(b)))

    def push_clear(self, b):
        """Slide a block straight back from whichever road now clips it."""
        x0, z0 = b["centre"]
        for step in range(1, 13):
            for dx, dz in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                b["centre"] = (x0 + dx * step * 6, z0 + dz * step * 6)
                if self.road_clear(b, extra=0) and not any(
                        overlap(b, k, 4) for _, k in self.kept if "lawn" not in k["use"]):
                    return True
        b["centre"] = (x0, z0)
        return False

    # --- housing from frontage -------------------------------------------
    def frontage(self):
        order = sorted((r for r in self.roads if r["front"] != "none"),
                       key=lambda r: (r["kind"] != M, -sum(math.dist(a, b) for a, b in segments(r))))
        for r in order:
            setback = r["width"] / 2 + PAVE + GARDEN + DEPTH / 2
            for a, b in segments(r):
                seg = math.dist(a, b)
                if seg < 2 * CELL:
                    continue
                ux, uz = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
                yaw = math.degrees(math.atan2(uz, ux))
                for side, label in ((1, "left"), (-1, "right")):
                    if r["front"] not in ("both", label):
                        continue
                    nx, nz = uz * side, -ux * side
                    n = int(seg // CELL)
                    start = (seg - n * CELL) / 2
                    run = []
                    for k in range(n):
                        t = start + (k + 0.5) * CELL
                        cx, cz = a[0] + ux * t + nx * setback, a[1] + uz * t + nz * setback
                        use, district = (r["use_at"](cx, cz) if r["use_at"] else (r["use"], r["district"]))
                        cell = {"centre": (cx, cz), "size": (CELL, DEPTH), "yaw": yaw,
                                "use": use, "district": district}
                        if run and run[-1]["use"] != use:
                            self.flush(run, r, yaw)
                            run = []
                        ok = (self.ground_clear(cell)
                              and self.road_clear(cell, skip=(r, (a, b)))
                              and not any(overlap(cell, k, 6) for _, k in self.kept)
                              and not any(overlap(cell, c, 10) for c in self.cells
                                          if abs(c["centre"][0] - cell["centre"][0]) < 60
                                          and abs(c["centre"][1] - cell["centre"][1]) < 60))
                        if ok:
                            run.append(cell)
                        else:
                            self.flush(run, r, yaw)
                            run = []
                    self.flush(run, r, yaw)

    def head_rows(self):
        """A short row across the end of each cul-de-sac, looking back down it."""
        for r in self.roads:
            if not r["head"] or r["front"] == "none":
                continue
            (ax, az), (bx, bz) = r["points"][-2], r["points"][-1]
            seg = math.dist((ax, az), (bx, bz))
            ux, uz = (bx - ax) / seg, (bz - az) / seg
            yaw = math.degrees(math.atan2(uz, ux)) + 90
            d = HEAD + GARDEN + DEPTH / 2
            run = []
            for k in (-1, 0, 1):
                cell = {"centre": (bx + ux * d - uz * k * CELL, bz + uz * d + ux * k * CELL),
                        "size": (CELL, DEPTH), "yaw": yaw, "use": r["use"], "district": r["district"]}
                if (self.ground_clear(cell, heads=False) and self.road_clear(cell)
                        and not any(overlap(cell, k2, 6) for _, k2 in self.kept)
                        and not any(overlap(cell, c, 10) for c in self.cells)):
                    run.append(cell)
                else:
                    run = []
                    break
            n = len(self.rows)
            self.flush(run, r, yaw)
            for _, row in self.rows[n:]:
                row["closes_street"] = True   # faces down the street, so square to it on purpose

    def flush(self, run, r, yaw):
        while len(run) >= 2:
            take = run[:ROW_CELLS]
            if len(run) - len(take) == 1:       # never strand a single house
                take = run[:ROW_CELLS - 1]
            run = run[len(take):]
            (x0, z0), (x1, z1) = take[0]["centre"], take[-1]["centre"]
            length = len(take) * CELL - ROW_GAP
            use = take[0]["use"]
            self.rows.append((take[0]["district"] or "Rivermere", {
                "centre": ((x0 + x1) / 2, (z0 + z1) / 2),
                "size": (length, DEPTH), "yaw": yaw, "use": use, "street": r["name"]}))
            self.cells.extend(take)

    # --- output ----------------------------------------------------------
    def data(self):
        names, by = [], {}
        for name, b in self.kept + self.rows:
            if name not in by:
                by[name] = []
                names.append(name)
            by[name].append(b)
        return {
            "roads": self.roads,
            "river": self.live["river"], "rail": self.live["rail"],
            "station": self.live["station"], "bridges": self.live["bridges"],
            "plots": [{"name": p["name"], "centre": p["centre"]} for p in self.plots],
            "roundabouts": [{"name": n, "centre": (float(x), float(z)), "radius": float(r)}
                            for n, x, z, r in ROUNDABOUTS],
            "districts": [{"name": n, "blocks": by[n]} for n in names],
            "landmarks": self.live["landmarks"],
            "extent": list(EXTENT),
            "heads": [r["points"][-1] for r in self.roads if r["head"]],
        }


# ------------------------------------------------------------------ audit


def audit(d, title):
    print(f"\n== {title}")
    allsegs = [(r, a, b) for r in d["roads"] for a, b in segments(r)]
    total = {}
    for r, a, b in allsegs:
        k = r["kind"]
        t = total.setdefault(k, {"axis": 0.0, "45": 0.0, "other": 0.0})
        t[angle_class(a, b)] += math.dist(a, b)
    grand = sum(sum(t.values()) for t in total.values())
    tile = sum(t["axis"] + t["45"] for t in total.values())
    print(f"  roads {len(d['roads'])}, {len(allsegs)} segments, {grand:,.0f} studs; "
          f"tileable (axis or 45) {100 * tile / grand:.0f}%")
    for k, t in total.items():
        s = sum(t.values())
        print(f"    {k:12s} {s:8,.0f}  axis {100 * t['axis'] / s:3.0f}%  45 {100 * t['45'] / s:3.0f}%  "
              f"other {100 * t['other'] / s:3.0f}%")
    housing = [b for dist in d["districts"] for b in dist["blocks"] if is_housing(b["use"])]
    blocks = sum(len(dist["blocks"]) for dist in d["districts"])
    stacked = off = 0
    for b in housing:
        best, bseg = 1e9, None
        for r, p, q in allsegs:
            dd = seg_dist(b["centre"], p, q)
            if dd < best:
                best, bseg = dd, (p, q)
        if best > 55:
            stacked += 1
        street = math.degrees(math.atan2(bseg[1][1] - bseg[0][1], bseg[1][0] - bseg[0][0]))
        long_axis = b["yaw"] + (0 if b["size"][0] >= b["size"][1] else 90)
        diff = abs((long_axis - street + 90) % 180 - 90)
        if diff > 5 and best <= 55 and not b.get("closes_street"):
            off += 1
    print(f"  blocks {blocks}, housing {len(housing)}; behind another row {stacked} "
          f"({100 * stacked / max(1, len(housing)):.0f}%); off-parallel {off}")
    frontage = sum(max(b["size"]) for b in housing)
    print(f"  housing frontage {frontage:,.0f} studs")


def main():
    live = parse()
    town = Town(live)
    town.carry_over()
    town.head_rows()
    town.frontage()
    d = town.data()

    audit(live, "v1 (live TownLayout.luau)")
    audit(d, "v3 (this plan)")
    print(f"  carried over {len(town.kept)} non-housing blocks; nudged {len(town.nudged)}, "
          f"dropped {len(town.dropped)}")
    for name, old, new in town.nudged:
        print(f"    nudged  {name}: {old['use']} {old['centre']} -> {new['centre']}")
    for name, old in town.dropped:
        print(f"    dropped {name}: {old['use']} {old['centre']}")
    for p in PLOTS:
        print(f"  {p['name']}: {p['was']} -> {p['centre']}  moved {math.dist(p['was'], p['centre']):.0f}")

    docs = ROOT / "docs"
    svg = build_svg(d)
    minX, _, minZ, _ = EXTENT
    heads = "".join(
        f'<circle cx="{(x - minX) * 0.34 + 40:.1f}" cy="{(z - minZ) * 0.34 + 40:.1f}" '
        f'r="{HEAD * 0.34:.1f}" fill="#6b7078"/>' for x, z in d["heads"])
    svg = svg.replace("<circle", heads + "<circle", 1)
    (docs / "town_map_v3.svg").write_text(svg, encoding="utf-8")
    body = svg.replace("<svg ", '<svg style="width:100%;height:auto;display:block" ', 1)
    (docs / "town_map_v3_view.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>Rivermere v3</title>'
        "<style>html,body{margin:0;background:#22262b}</style>" + body, encoding="utf-8")
    try:
        from town_png import render
        render(d, docs / "town_map_v3.png", scale=0.5)
    except ImportError:
        pass
    return d


if __name__ == "__main__":
    main()
