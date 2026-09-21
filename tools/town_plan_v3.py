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
# Every generated building is one of these. cell = frontage one unit takes,
# group = how many units join into one block before a gap. This table is the
# "mix of assets": each row is a different kit family on the ground.
TYPES = {
    #                     cell  depth group gap garden
    "terraced row":      (22.0, 24.0, 6, 8.0, 6.0),
    "semis":             (25.0, 24.0, 2, 12.0, 8.0),
    "detached house":    (34.0, 26.0, 1, 14.0, 10.0),
    "corner shop":       (22.0, 24.0, 1, 4.0, 6.0),
    "shops with flats":  (26.0, 30.0, 5, 6.0, 0.0),
    "shops":             (30.0, 30.0, 3, 6.0, 0.0),
    "flats":             (70.0, 36.0, 1, 16.0, 8.0),
    "workshop":          (80.0, 50.0, 1, 16.0, 10.0),
    "trade counter":     (80.0, 50.0, 1, 16.0, 10.0),
    "warehouse":         (160.0, 100.0, 1, 24.0, 14.0),
}
HOMES = ("terraced row", "semis", "detached house")
# colour + legend label per use, first match wins
STYLE = [
    ("terraced row", "#c4624d", "terraced rows"),
    ("semis", "#e39a4f", "semi-detached pairs"),
    ("detached", "#efd268", "detached houses"),
    ("corner shop", "#e0479e", "corner shops"),
    ("shops with flats", "#6a4fc4", "high-street shops with flats over"),
    ("shops", "#a08be6", "shop parades"),
    ("supermarket", "#a08be6", None),
    ("flats", "#3fa39b", "blocks of flats"),
    ("pub", "#7d2f2f", "pubs and cafes"),
    ("church", "#2f5d8a", "civic: church, town hall, schools, station"),
    ("town hall", "#2f5d8a", None),
    ("school", "#2f5d8a", None),
    ("station", "#2f5d8a", None),
    ("warehouse", "#555c66", "warehouses"),
    ("builders yard", "#555c66", None),
    ("workshop", "#8d939c", "workshops and trade counters"),
    ("trade counter", "#8d939c", None),
    ("marina", "#5b8fb0", "marina"),
    ("pitch", "#9ccf7f", "sports pitches and hall"),
    ("sports hall", "#9ccf7f", None),
    ("park", "#7fae6a", "parks and greens"),
    ("bandstand", "#7fae6a", None),
]


def style_of(use):
    u = use.lower()
    for key, colour, _ in STYLE:
        if key in u:
            return key, colour
    return "other", "#a9adb4"


def fill_of(use):
    return style_of(use)[1]


def is_home(use):
    return any(h in use for h in ("terrace", "semis", "detached"))


SINGLE_SEMI_TRIM = 5.0  # a semis street's odd cell becomes a detached house this much narrower than the cell
STOP_CLEAR = 16.0  # nothing is generated this close to a bus stop (shelter + painted bay)
HEAD = 34.0       # cul-de-sac turning head radius (kit CulDeSac is 96 x 69 at town scale)
FAN_ANGLE = 65.0  # a close's side lots stand this far round the bulb from the end lot

# ------------------------------------------------------------------ roads

R, M, S, L, A = "ring", "main", "residential", "lane", "alley"
WIDTH = {R: 32.0, M: 26.0, S: 20.0, L: 20.0, A: 10.0}


def road(name, kind, pts, front=None, use="terraced row", district=None, use_at=None, head=False,
         closed=False):
    """front: "both" | "left" | "right" | "none" (left of the direction of
    travel). Residential streets default to both sides, everything else to none."""
    if front is None:
        front = "both" if kind == S else "none"
    return {"name": name, "kind": kind, "width": WIDTH[kind],
            "points": [(float(x), float(z)) for x, z in pts],
            "front": front, "use": use, "district": district, "use_at": use_at,
            "head": head,      # head: the last point is a cul-de-sac turning head (kit: CulDeSac*)
            "closed": closed}  # closed: the last point is a blunt end with a terrace across it
    # (Marcel, 2026-09-20: a turning circle belongs to a semis / detached close; a terraced
    # street joins another street or stops at a terrace, as Victorian streets do)


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


def centre_use(x, z):
    """What fronts a town-centre street: shops at the square, flats toward the
    river, terraces beyond. One building deep, always."""
    r = hyp(x, z * 1.4)
    if r < 430:
        return ("shops with flats", "Town Centre")
    if z > 60 and r < 1000:
        return ("flats", "Riverside")
    if r < 640:
        return ("shops", "Town Centre")
    return ("terraced row", "Mill Street Terraces" if z < 0 else "Riverside")


def industrial_use(x, z):
    return ("warehouse" if z < -250 or z > 40 else ("trade counter" if int(x // 96) % 3 == 0 else "workshop"),
            "Industrial Estate")


# A road's use_at names one of these; TownFrontage.RULES in Luau has the same names.
RULES = {
    "centre": centre_use,
    "industrial": industrial_use,
    "north road": lambda x, z: ("shops with flats", "Town Centre") if z > -150 else None,
    "high street": lambda x, z: ("shops with flats", "Town Centre") if x > -520 else
    (("shops", "Station") if x > -700 else ("terraced row", "Station")),
    "bridge street": lambda x, z: ("shops with flats", "Town Centre") if z < 300 else None,
    # Marcel, 2026-09-20: a terrace across the ring road from Plot 1, facing the ground
    "ring road": lambda x, z: ("terraced row", "Riverside") if 640 < x < 1110 and z > 700 else None,
}


def roads():
    # front="none" on a residential street means a CONNECTING street: the streets it joins have
    # already taken its corners and nothing is left to front it (or the river is too close).
    # TownFrontageTest.everyFrontedStreetGotSomething fails if a fronted street ends up empty.
    # the ring is a bare arterial except opposite Plot 1's entrance, where a row faces the ground
    # ("right" of its clockwise travel is the inside of the loop)
    out = [road("Ring Road", R, RING, front="right", use_at="ring road")]

    # ---- through roads, each as near its v1 line as axis/45 allows
    out += [
        road("North Road", M, [(0, -60), (0, -1080)], front="both", use_at="north road"),
        road("High Street", M, [(-60, 0), (-400, 0), (-505, -105), (-1255, -105)], front="both",
             use_at="high street"),
        road("Station Road", M, [(-610, -105), (-610, -337), (-938, -337)], front="both",
             use="shops", district="Station"),   # junction moves: leaves High Street square, not at its 45 bend
        # junction moves: it met the ring at 45 degrees on East Bridge's abutment, where no kit junction
        # fits. A square route north to the ring would cut through Riverside Park, so it ends in a
        # turning head at the park instead (TEMP: Marcel to choose between this and a smaller park).
        road("Riverside Road", M, [(60, 0), (1290, 0)], front="both", use_at="centre", head=True),
        road("Bridge Street", M, [(0, 60), (0, 800)], front="both",
             use_at="bridge street"),
        road("Mapleford Road", M, [(-1350, -400), (-2400, -400)], front="both", use_at="industrial"),
        road("Estate Road", M, [(-1255, -105), (-2400, -105)], front="both", use_at="industrial"),
        # Greenbridge Road takes Moss Lane's line due west; the old diagonal to
        # the south-west corner is where Plot 3 now stands
        road("Greenbridge Road", M, [(-1150, 560), (-2400, 560)],
             front="right", district="Westdale"),
        road("Hollingford Road", M, [(1250, 600), (1300, 600), (1500, 800), (2400, 800)],
             front="both", district="Hollingford"),
    ]

    # ---- Town Centre: a proper little grid. Every shop fronts a street; nothing
    # stands behind anything else.
    tc = "Town Centre"
    out += [
        road("Guild Street", S, [(-295, 105), (0, 105)], use_at="centre"),              # NEW
        road("Quay Street", S, [(0, 105), (480, 105)], use_at="centre"),                # NEW
        road("Tanner Row", S, [(-295, 0), (-295, 260)], use_at="centre"),               # NEW
        road("Wharf Street", S, [(250, 0), (250, 260)], front="none"),  # its corners are taken by the streets it joins               # NEW
        road("Marina Way", S, [(760, 0), (760, 190)], use_at="centre", head=True),      # NEW
        road("Chapel Street", S, [(-150, 0), (-150, -330)], use_at="centre"),           # NEW
        road("Fountain Street", S, [(250, 0), (250, -200)], use_at="centre"),           # NEW
        road("Dyers Lane", S, [(450, 0), (450, -200)], use_at="centre"),                # NEW
        road("Park Street", S, [(760, 0), (760, -200)], use_at="centre"),               # NEW
        # side streets tying the terraces together
        road("Spinner Street", S, [(450, -200), (450, -600)], district="Mill Street Terraces", front="none"),   # NEW
        road("Park Road", S, [(900, -200), (900, -600)], district="Mill Street Terraces"),        # NEW
        road("Loom Street", S, [(-150, -330), (-150, -600)], district="Mill Street Terraces", front="none"),  # a connecting street: gable ends face it    # NEW
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
        road("Linden Way", S, [(-1000, -920), (900, -920)], district=nf),
    ]
    for name, x, end in [("Elder Close", -1200, -815), ("Ash Close", -1000, -920),
                         ("Birch Close", -800, -920), ("Cherry Close", -600, -920),
                         ("Hazel Close", -400, -920), ("Rowan Close", -150, -920),
                         ("Holly Close", 225, -920), ("Hayfield Close", 450, -920),
                         ("Laurel Close", 650, -920), ("Maple Close", 900, -920),
                         ("Oak Close", 1050, -765)]:
        semis = abs(x) >= 800
        out.append(road(name, S, [(x, -600), (x, end)], district=nf,
                        use="semis" if semis else "terraced row", head=end != -920))

    # ---- Station quarter: one new street where rows stood five deep
    st = "Station"
    out += [
        road("Church Lane", S, [(-295, 0), (-295, -330)], district="Town Centre", front="none"),
        road("Cooper Street", S, [(-1290, -240), (-720, -240)], district=st, closed=True),  # stops short of the ring; a terrace across its end short of Station Road
        road("Signal Street", S, [(-1090, 25), (-560, 25)], district=st),          # NEW
        road("Lock Street", S, [(-1150, 150), (-540, 150)], district=st),
        road("Foundry Way", S, [(-1480, -400), (-1480, 110)], use_at="industrial"),
        # runs on east to the waterfront flats, which v1 left 130 studs from any street
        road("Lune Street", S, [(-440, 260), (700, 260)], use_at="centre", head=True),
        road("Platform Street", S, [(-850, -240), (-850, 150)], district=st, front="none"),     # NEW
        road("Goods Yard Lane", S, [(-1000, -105), (-1000, -240)], district=st, front="none"),  # NEW
        # the industrial estate gets the same treatment: units front a road
        road("Forge Lane", S, [(-1800, -400), (-1800, 110)], use_at="industrial"),    # NEW
        road("Furnace Lane", S, [(-2120, -400), (-2120, 110)], use_at="industrial"),  # NEW
        road("Wharf Road", S, [(-1480, 110), (-2250, 110)], front="none"),  # NEW
    ]

    # ---- Riverside (south bank, inside the ring): one new street
    rv = "Riverside"
    out += [
        road("Meadow Road", S, [(0, 560), (1135, 560)], district=rv, closed=True),
        road("Tannery Row", S, [(0, 680), (1060, 680)], district=rv, closed=True),            # NEW
        road("Tenter Lane", S, [(950, 560), (950, 680)], district=rv, front="none"),  # ties the two ends together
        road("Viaduct Road", S, [(-545, 560), (0, 560)], district=rv),
        road("Weir Road", S, [(-1150, 560), (-615, 560)], district=rv),
        road("Fuller Street", S, [(-1090, 690), (-615, 690)], district=rv),         # NEW
        road("Sluice Lane", S, [(-850, 560), (-850, 800)], district=rv, front="none"),            # NEW
        road("Dye Works Lane", S, [(600, 560), (600, 800)], district=rv, front="none"),           # NEW
        road("Osier Lane", S, [(-250, 560), (-250, 800)], district=rv),             # NEW
    ]

    # ---- south of the ring
    out += [
        road("Sports Centre Road", S, [(0, 800), (0, 1200), (600, 1200)], district=rv,
             front="none"),
        road("Cedar Road", S, [(-470, 800), (-470, 1500)], district=rv, closed=True),
        road("Paddock Road", S, [(400, 800), (400, 1500)], district=rv, head=True, use="semis"),           # NEW
        road("Hollins Road", S, [(600, 800), (600, 1500)], district=rv, closed=True),           # was x=520
    ]

    # ---- Westdale, rebuilt round Plot 3
    wd = "Westdale"
    out += [
        road("Moss Lane", S, [(-2240, 430), (-1250, 430)], district=wd, use="semis"),
        road("Reed Road", S, [(-1600, 430), (-1600, 560)], district=wd, front="none"),
        road("Alder Road", S, [(-1310, 560), (-1310, 1480)], district=wd),
        road("Tanner's Lane", S, [(-2240, 560), (-2240, 1480)], district=wd, use="semis"),      # NEW
        # the E-W streets stop short of the railway, each at a terrace across its end
        road("Orchard Road", S, [(-2240, 1480), (-730, 1480)], district=wd, closed=True),
        road("Fern Street", S, [(-1310, 800), (-1128, 800)], district=wd, closed=True),
        road("Westdale Avenue", S, [(-1310, 950), (-730, 950)], district=wd, closed=True),
        road("Brook Street", S, [(-1310, 1100), (-730, 1100)], district=wd, closed=True),
        road("Westdale Crescent", S, [(-1310, 1250), (-730, 1250)], district=wd, closed=True),
        road("Coronation Street", S, [(-1310, 1365), (-730, 1365)], district=wd, closed=True),   # NEW
        road("Westdale Road", S, [(-850, 800), (-850, 1480)], district=wd),
    ]

    # ---- Mapleford: Plot 4's estate (north-west). Not a box round the plot:
    # a street south, a street north, and closes filling the ground between the
    # plot and the ring, so the club sits at the end of somebody's road.
    p4 = "Mapleford"
    out += [
        road("Plot 4 Lane", L, [(-1350, -750), (-1350, -1210)]),   # the ground stands on its west pavement
        road("Mapleford Lane", S, [(-2250, -600), (-1350, -600)], district=p4),
        road("Drift Close", S, [(-2250, -600), (-2250, -1060)], district=p4, head=True, use="detached house"),
        road("Tollgate Road", S, [(-1350, -1210), (-1350, -1590), (-2120, -1590)], district=p4, closed=True),
        road("Drovers Road", S, [(-1350, -1210), (-760, -1210), (-760, -1000)], district=p4),  # round to the ring
        road("Pinfold Close", S, [(-950, -1210), (-950, -1100)], district=p4, head=True, use="detached house"),
        road("Smithy Close", S, [(-1120, -1210), (-1120, -1460), (-880, -1460)], district=p4,
             use="semis", head=True),
    ]

    # ---- Millbrook: Plot 2's estate (north-east), deliberately not Mapleford's mirror
    p2 = "Millbrook"
    out += [
        road("Plot 2 Lane", L, [(1400, -600), (1400, -1080)]),   # the ground stands on its east pavement
        road("Millbrook Road", S, [(1400, -700), (2300, -700)], district=p2),
        road("Lune View", S, [(1560, -570), (2250, -570)], district=p2, head=True, use="detached house"),
        road("Fell Lane", S, [(2300, -700), (2300, -1320)], district=p2, head=True, use="semis"),
        road("Quarry Road", S, [(1400, -1080), (900, -1080), (780, -1200)], district=p2, closed=True),
        road("Kiln Close", S, [(1180, -1080), (1180, -1400)], district=p2, use="semis", head=True),
        # runs down Plot 2's entrance wall, then turns away west: a terrace across an end on the
        # plot's own line would stand in its wall
        road("Millbrook Rise", S, [(1400, -1080), (1400, -1330), (1300, -1330)], district=p2, closed=True),
    ]

    # ---- Hollingford: the 45-degree estate, in the ground Plot 3 left. Every
    # street is parallel to Hollingford Road's own 45 leg off the roundabout.
    hf = "Hollingford"
    out += [
        road("Lunebank Road", S, [(1400, 300), (1500, 300), (1905, 705), (1905, 800)], district=hf),
        road("Ferry Lane", S, [(1578, 378), (1671, 285)], district=hf, front="none"),
        road("Fellmonger Street", S, [(1500, 480), (1725, 705), (1725, 800)], district=hf),
        road("Bleach Street", S, [(1671, 285), (2091, 705), (2091, 800)], district=hf, use="semis"),
        # beside Plot 1
        road("Garth Road", S, [(1610, 800), (1610, 1560)], district=hf, head=True, use="detached house"),
        road("Ropewalk", S, [(1650, 630), (1833, 447)], district=hf, front="none"),               # NEW, ties the three diagonals
    ]

    # ---- back alleys (Marcel, 2026-09-20): the small, fully paved road size
    # (RoadTiles.ALLEY_SCALE, 22 studs across). Each runs down the middle of the gap between
    # two terraced rows that stand back to back, where that gap is 29 to 36 studs, and opens
    # onto the streets it meets. width is the paved carriageway. Nothing fronts an alley and
    # it takes no pavement setback (like a plot lane).
    out += [
        road("Back Cooper Street", A, [(-1190, -174), (-740, -174)], district="Station"),
        road("Back Signal Street", A, [(-1100, -38), (-745, -38)], district="Station"),
        road("Back Lock Street", A, [(-1100, 88), (-595, 88)], district="Station"),
        road("Back Mill Street", A, [(0, -265), (900, -265)], district="Mill Street Terraces"),
        road("Back Fuller Street", A, [(-1060, 625), (-655, 625)], district="Riverside"),
    ]
    return out


# Marcel, 2026-09-20: every ground stands hard against its street, the entrance wall along the
# back of the pavement (PLOT_STREET_GAP from the street's centreline, TownLayout has the same
# number) with no driveway: the vehicle gate opens off the street over a dropped kerb. Plots 1
# and 3 front the ring / Greenbridge Road; 2 and 4 front their own lane, opposite the street
# that meets it (Quarry Road, Drovers Road).
# yaw: plot-local -X faces the street (TownLayout.plotCFrame). bus: the plot's bus stop, across
# the street from the gate and 22 off the centreline, with the way the shelter opens.
PLOT_STREET_GAP = 15.5
_EDGE = 760 / 2 + PLOT_STREET_GAP
PLOTS = [
    {"name": "Plot 1", "centre": (1050.0, 800 + _EDGE), "was": (1050, 1250), "faces": "north", "yaw": 270,
     "note": "south-east, on the ring road, entrance faces north", "bus": (1010, 778), "bus_yaw": 180},
    {"name": "Plot 2", "centre": (1400 + _EDGE, -1160.0), "was": (1900, -1200), "faces": "west", "yaw": 0,
     "note": "north-east (Millbrook), entrance faces west", "bus": (1378, -1030), "bus_yaw": 270},
    {"name": "Plot 3", "centre": (-1780.0, 560 + _EDGE), "was": (1950, 420), "faces": "north", "yaw": 270,
     "note": "south-west (Westdale), on Greenbridge Road, entrance faces north", "bus": (-1820, 538), "bus_yaw": 180},
    {"name": "Plot 4", "centre": (-1350 - _EDGE, -1130.0), "was": (-1900, -1200), "faces": "east", "yaw": 180,
     "note": "north-west (Mapleford), entrance faces east", "bus": (-1328, -1160), "bus_yaw": 90},
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

# ------------------------------------------------------------------ geometry


def hyp(x, z):
    """sqrt(x*x + z*z), NOT math.hypot: TownFrontage.luau does exactly this, and the two must
    agree to the last bit or a lot sitting exactly on a clearance could flip between them."""
    return math.sqrt(x * x + z * z)


def dist(a, b):
    return hyp(b[0] - a[0], b[1] - a[1])


def rect_point_dist(b, p):
    """Distance from point p to the (rotated) rectangle b; 0 inside."""
    a = math.radians(b["yaw"])
    ca, sa = math.cos(a), math.sin(a)
    dx, dz = p[0] - b["centre"][0], p[1] - b["centre"][1]
    lx, lz = dx * ca + dz * sa, -dx * sa + dz * ca
    return hyp(max(abs(lx) - b["size"][0] / 2, 0.0), max(abs(lz) - b["size"][1] / 2, 0.0))


def seg_dist(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return hyp(px - ax - t * dx, pz - az - t * dz)


def corners(b, grow=0.0):
    cx, cz = b["centre"]
    sx, sz = b["size"][0] / 2 + grow, b["size"][1] / 2 + grow
    a = math.radians(b["yaw"])
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + lx * ca - lz * sa, cz + lx * sa + lz * ca)
            for lx, lz in ((-sx, -sz), (sx, -sz), (sx, sz), (-sx, sz))]


SAMPLE_STEP = 10.0


def samples(b):
    """The outline every SAMPLE_STEP studs or less, then the centre. Dense enough that a road
    cannot cross a 160-wide warehouse between two samples (corners + midpoints let three do it)."""
    c = corners(b)
    out = []
    for i in range(4):
        (x0, z0), (x1, z1) = c[i], c[(i + 1) % 4]
        n = max(1, math.ceil(hyp(x1 - x0, z1 - z0) / SAMPLE_STEP))
        for k in range(n):
            out.append((x0 + (x1 - x0) * (k / n), z0 + (z1 - z0) * (k / n)))
    return out + [b["centre"]]


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

    # --- clearances ---------------------------------------------------
    def road_clear(self, blk, skip=None, extra=GARDEN - 2):
        pts = samples(blk)
        for r in self.roads:
            need = r["width"] / 2 + (0 if r["kind"] in (L, A) else PAVE) + extra
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
            if any(hyp(px - x, pz - z) < rad + PAVE + 6 for px, pz in pts):
                return False
        if heads:
            for r in self.roads:
                if r["head"]:
                    hx, hz = r["points"][-1]
                    if any(hyp(px - hx, pz - hz) < HEAD + 5 for px, pz in pts):
                        return False
        if any(hyp(px, pz) < 60 + 14 for px, pz in pts):
            return False
        if any(rect_point_dist(blk, stop["at"]) < STOP_CLEAR for stop in self.live["bus_stops"]):
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

    # --- the hand-placed specials -------------------------------------
    def carry_over(self):
        """TownLayout.DISTRICTS holds only the special blocks now (church, pubs, schools,
        parks...). They are authored in the Luau file; this just reads them."""
        for dist in self.live["districts"]:
            for blk in dist["blocks"]:
                b = dict(blk)
                b["yaw"] = -b["yaw"]   # Luau yaw is Roblox's (CFrame.Angles); in here it is atan2(dz, dx)
                self.kept.append((dist["name"], b))

    # --- everything from frontage ------------------------------------------
    def fits(self, cell, skip=None, heads=True, run=()):
        cx, cz = cell["centre"]
        reach = max(cell["size"]) + 110
        return (self.ground_clear(cell, heads=heads)
                and self.road_clear(cell, skip=skip)
                and not any(overlap(cell, k, 6) for _, k in self.kept)
                and not any(overlap(cell, c, 10) for c in self.cells
                            if abs(c["centre"][0] - cx) < reach and abs(c["centre"][1] - cz) < reach
                            and not any(c is mine for mine in run)))

    def frontage(self):
        order = sorted((r for r in self.roads if r["front"] != "none"),
                       key=lambda r: (r["kind"] != M, -sum(dist(a, b) for a, b in segments(r))))
        for r in order:
            for index, (a, b) in enumerate(segments(r), 1):
                seg = dist(a, b)
                ux, uz = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
                yaw = math.degrees(math.atan2(uz, ux))
                for side, label in ((1, "left"), (-1, "right")):
                    if r["front"] not in ("both", label):
                        continue
                    nx, nz = uz * side, -ux * side
                    key = f"{r['name']}|{label}|{index}"
                    run, t = [], 4.0
                    while t < seg - 4.0:
                        px, pz = a[0] + ux * t, a[1] + uz * t
                        got = RULES[r["use_at"]](px, pz) if r["use_at"] else (r["use"], r["district"])
                        if got is None:
                            self.flush(run, r, yaw, key)
                            run, t = [], t + 11.0
                            continue
                        use, district = got
                        w, depth, _, _, garden = TYPES[use]
                        if t + w > seg - 4.0:
                            break
                        setback = r["width"] / 2 + PAVE + garden + depth / 2
                        m = t + w / 2
                        cell = {"centre": (a[0] + ux * m + nx * setback, a[1] + uz * m + nz * setback),
                                "size": (w, depth), "yaw": yaw, "use": use, "district": district,
                                "front": (-nx, -nz)}
                        if run and run[-1]["use"] != use:
                            self.flush(run, r, yaw, key)
                            run = []
                        if self.fits(cell, skip=(r, (a, b)), run=run):
                            run.append(cell)
                            self.cells.append(cell)
                            t += w
                        else:
                            self.flush(run, r, yaw, key)
                            run, t = [], t + 11.0
                    self.flush(run, r, yaw, key)

    def head_rows(self):
        """What stands at a street's last point.
        head   (a close's turning circle): a fan of three short lots round the bulb, at 0 and
               +-FAN_ANGLE from the street's line, each facing the centre of the circle.
        closed (a terraced street's blunt end): one row square across the end, looking back
               down the street; if an end house does not fit, the two that do still stand."""
        for r in self.roads:
            if not (r["head"] or r["closed"]) or r["front"] == "none":
                continue
            (ax, az), (bx, bz) = r["points"][-2], r["points"][-1]
            seg = dist((ax, az), (bx, bz))
            ux, uz = (bx - ax) / seg, (bz - az) / seg
            got = RULES[r["use_at"]](bx, bz) if r["use_at"] else (r["use"], r["district"])
            if got is None or got[0] not in HOMES:
                continue
            w, depth, _, _, garden = TYPES[got[0]]
            key = f"{r['name']}|head|{len(r['points']) - 1}"
            n = len(self.rows)

            def cell_at(dx, dz, reach, k):
                # dx, dz: the way the lot looks out from the street's last point; k: cells sideways
                return {"centre": (bx + dx * reach - dz * k * w, bz + dz * reach + dx * k * w),
                        "size": (w, depth), "yaw": math.degrees(math.atan2(dz, dx)) + 90,
                        "use": got[0], "district": got[1], "front": (-dx, -dz)}

            if r["head"]:
                reach = HEAD + garden + depth / 2
                ks = (0,) if got[0] == "detached house" else (-0.5, 0.5)
                placed = []
                for deg in (0, FAN_ANGLE, -FAN_ANGLE):
                    t = math.radians(deg)
                    dx, dz = ux * math.cos(t) - uz * math.sin(t), uz * math.cos(t) + ux * math.sin(t)
                    run = [cell_at(dx, dz, reach, k) for k in ks]
                    # the fan's own lots stand closer than the 10-stud cell margin on purpose
                    if all(self.fits(c, heads=False, run=placed) for c in run):
                        placed += run
                        self.cells.extend(run)
                        self.flush(run, r, run[0]["yaw"], key)
            else:
                # the same building line off the street's end as the side rows keep off its centreline
                reach = r["width"] / 2 + PAVE + garden + depth / 2
                run, best = [], []
                for k in ((-0.5, 0.5) if got[0] == "semis" else (-1, 0, 1)):
                    cell = cell_at(ux, uz, reach, k)
                    if self.fits(cell, heads=False, run=run):
                        run.append(cell)
                        if len(run) > len(best):
                            best = list(run)
                    else:
                        run = []
                if len(best) >= 2:
                    self.cells.extend(best)
                    self.flush(best, r, best[0]["yaw"], key)
            for _, row in self.rows[n:]:
                row["closes_street"] = True   # faces the street end, so square to it on purpose

    def flush(self, run, r, yaw, key=""):
        if not run:
            return
        use = run[0]["use"]
        w, depth, group, gap, _ = TYPES[use]
        if use == "terraced row" and len(run) == 1:
            self.cells.remove(run[0])           # never strand a single terraced house
            return
        # a corner shop on the end of roughly one terrace in three
        if use == "terraced row" and len(run) >= 5 and sum(map(ord, key)) % 3 == 0:
            shop, run = run[0], run[1:]
            self.rows.append((shop["district"] or "Rivermere", {
                "centre": shop["centre"], "size": (w - 4.0, depth), "yaw": yaw,
                "use": "corner shop", "street": r["name"], "front": shop["front"],
                "units": 1, "unit_width": w, "corner": True, "key": key}))
        first = True
        while run:
            take = run[:group]
            if use == "terraced row" and len(run) - len(take) == 1:
                take = run[:group + 1] if group + 1 <= len(run) else take
            run = run[len(take):]
            (x0, z0), (x1, z1) = take[0]["centre"], take[-1]["centre"]
            lot_use, lot_w, lot_d, lot_unit = use, len(take) * w - gap, depth, w
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if use == "semis" and len(take) == 1:
                # never strand half a pair: on 25 - 12 = 13 studs it was built at two-thirds size.
                # The odd cell takes a detached house instead, as wide as the cell allows, on a
                # detached house's own building line (deeper garden, deeper lot: further back).
                det_cell, det_depth, _, _, det_garden = TYPES["detached house"]
                back = (det_garden - TYPES[use][4]) + (det_depth - depth) / 2
                fx, fz = take[0]["front"]
                # (25 - 5 is exactly a detached lot's 34 - 14 frontage)
                lot_use, lot_w, lot_d, lot_unit = "detached house", w - SINGLE_SEMI_TRIM, det_depth, det_cell
                cx, cz = cx - fx * back, cz - fz * back
            self.rows.append((take[0]["district"] or "Rivermere", {
                "centre": (cx, cz),
                "size": (lot_w, lot_d), "yaw": yaw, "use": lot_use, "street": r["name"],
                "front": take[0]["front"], "units": len(take), "unit_width": lot_unit,
                "corner": first or not run, "key": key}))
            first = False

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


def audit(d, title, home=is_housing):
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
    housing = [b for dist in d["districts"] for b in dist["blocks"] if home(b["use"])]
    blocks = sum(len(dist["blocks"]) for dist in d["districts"])
    stacked = off = 0
    for b in housing:
        best, bseg = 1e9, None
        for r, p, q in allsegs:
            dd = seg_dist(b["centre"], p, q)
            if dd < best:
                best, bseg = dd, (p, q)
        if best > 55 and not b.get("closes_street"):
            stacked += 1
        street = math.degrees(math.atan2(bseg[1][1] - bseg[0][1], bseg[1][0] - bseg[0][0]))
        long_axis = b["yaw"] + (0 if "street" in b or b["size"][0] >= b["size"][1] else 90)
        diff = abs((long_axis - street + 90) % 180 - 90)
        if diff > 5 and best <= 55 and not b.get("closes_street"):
            off += 1
    print(f"  blocks {blocks}, housing {len(housing)}; behind another row {stacked} "
          f"({100 * stacked / max(1, len(housing)):.0f}%); off-parallel {off}")
    frontage = sum(max(b["size"]) for b in housing)
    print(f"  housing frontage {frontage:,.0f} studs")
    trade = [b for dist in d["districts"] for b in dist["blocks"]
             if any(k in b["use"] for k in ("shop", "flats", "workshop", "trade", "warehouse"))]
    deep = 0
    for b in trade:
        reach = min(b["size"]) / 2 + 40
        if min(seg_dist(b["centre"], p, q) - r["width"] / 2 for r, p, q in allsegs) > reach:
            deep += 1
    print(f"  commercial + industrial blocks {len(trade)}; with no street frontage {deep}")
    mix = {}
    for dist in d["districts"]:
        for b in dist["blocks"]:
            k = style_of(b["use"])[0]
            mix[k] = mix.get(k, 0) + 1
    print("  mix: " + ", ".join(f"{k} {v}" for k, v in sorted(mix.items(), key=lambda kv: -kv[1])))


HEIGHT = {"terraced row": 28, "semis": 28, "detached house": 28, "corner shop": 28,
          "shops with flats": 36, "shops": 20, "flats": 44, "workshop": 24, "trade counter": 24,
          "warehouse": 36}   # TEMP nominal heights in studs


def write_json(d, town, path):
    """The Wave 1 contract (docs/TOWN_V3_BUILD.md s4) as data, so builder lanes can start
    before the Luau port exists. Query it with python; it is too big to read whole."""
    import json
    lots, seen = [], {}
    for district, b in town.rows:
        n = seen[b["key"]] = seen.get(b["key"], 0) + 1
        lots.append({
            "id": f'{b["key"]}|{n}', "use": b["use"], "district": district, "street": b["street"],
            "centre": [round(b["centre"][0], 2), 0, round(b["centre"][1], 2)],
            "size": [round(b["size"][0], 2), HEIGHT[b["use"]], round(b["size"][1], 2)],
            "yaw": round(-b["yaw"], 2) + 0.0,   # Roblox convention, as TownFrontage.Lot.yaw
            "front": [round(b["front"][0], 4), 0, round(b["front"][1], 4)],
            "units": b["units"], "unitWidth": b["unit_width"],
            "closesStreet": bool(b.get("closes_street")), "corner": bool(b["corner"])})
    out = {
        "extent": d["extent"], "headRadius": HEAD,
        "types": {k: dict(zip(("cell", "depth", "group", "gap", "garden"), v), height=HEIGHT[k])
                  for k, v in TYPES.items()},
        "roads": [{"name": r["name"], "kind": r["kind"], "width": r["width"],
                   "points": [[x, 0, z] for x, z in r["points"]], "front": r["front"],
                   "head": bool(r["head"]), "district": r["district"]} for r in d["roads"]],
        "plots": [{"name": q["name"], "centre": [q["centre"][0], 0, q["centre"][1]],
                   "faces": q["faces"]} for q in PLOTS],
        "roundabouts": [{"name": n, "centre": [x, 0, z], "radius": rad} for n, x, z, rad in ROUNDABOUTS],
        "specials": [{"district": n, "use": b["use"], "centre": [b["centre"][0], 0, b["centre"][1]],
                      "size": [b["size"][0], 0, b["size"][1]], "yaw": -b["yaw"] + 0.0} for n, b in town.kept],
        "lots": lots,
    }
    path.write_text(json.dumps(out, indent=0), encoding="utf-8")
    print(f"  wrote {path} ({len(lots)} lots, {len(out['roads'])} roads)")


def main():
    live = parse()
    town = Town(live)
    town.carry_over()
    town.head_rows()
    town.frontage()
    d = town.data()

    audit(d, "v3 (this plan)", home=is_home)
    print(f"  {len(town.kept)} special blocks read from TownLayout.luau, {len(town.rows)} lots generated")

    docs = ROOT / "docs"
    if "--json" in sys.argv:
        write_json(d, town, docs / "town_v3_lots.json")
    counts = {}
    for dist in d["districts"]:
        for b in dist["blocks"]:
            k = style_of(b["use"])[0]
            counts[k] = counts.get(k, 0) + 1
    legend, seen = [], set()
    for key, colour, label in STYLE:
        if label and label not in seen:
            seen.add(label)
            n = sum(counts.get(k2, 0) for k2, c2, _ in STYLE if c2 == colour)
            legend.append((colour, f"{label} ({n})"))
    d["legend"] = legend

    import town_map
    town_map.use_fill = fill_of
    town_map.is_housing = lambda use: False     # no special outline: colour carries the type
    svg = town_map.build_svg(d)
    minX, _, minZ, _ = EXTENT
    heads = "".join(
        f'<circle cx="{(x - minX) * 0.34 + 40:.1f}" cy="{(z - minZ) * 0.34 + 40:.1f}" '
        f'r="{HEAD * 0.34:.1f}" fill="#6b7078"/>' for x, z in d["heads"])
    svg = svg.replace("<circle", heads + "<circle", 1)
    # swap the stock five-line legend for the full building mix
    k = svg.rindex('<rect x="40"')
    k2 = svg.index("<line", k)
    lx, h = 640, 100 + 17 * len(legend)
    box = [f'<rect x="{lx}" y="{h - 60 - 17 * len(legend)}" width="300" height="{30 + 17 * len(legend)}" '
           f'fill="#ffffff" fill-opacity="0.92" stroke="#b9bcb4"/>',
           f'<text x="{lx + 10}" y="{h - 40 - 17 * len(legend)}" font-size="14" font-weight="700" '
           f'fill="#2d3036">Rivermere v3: what stands where</text>']
    for n, (colour, label) in enumerate(legend):
        y = h - 22 - 17 * (len(legend) - n)
        box.append(f'<rect x="{lx + 10}" y="{y - 10}" width="16" height="12" fill="{colour}"/>')
        box.append(f'<text x="{lx + 34}" y="{y}" font-size="12" fill="#3a3e45">{label.replace("&", "&amp;")}</text>')
    svg = svg[:k] + "".join(box) + svg[k2:]
    (docs / "town_map_v3.svg").write_text(svg, encoding="utf-8")
    body = svg.replace("<svg ", '<svg style="width:100%;height:auto;display:block" ', 1)
    (docs / "town_map_v3_view.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>Rivermere v3</title>'
        "<style>html,body{margin:0;background:#22262b}</style>" + body, encoding="utf-8")
    from town_png import render
    render(d, docs / "town_map_v3.png", scale=0.5, fill=fill_of)
    return d


if __name__ == "__main__":
    main()
