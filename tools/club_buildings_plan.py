"""Top-down floor plans for the club buildings spec (docs/CLUB_BUILDINGS.md, backlog P9).

    python tools/club_buildings_plan.py            # writes docs/club_buildings/*.svg and *.png
    python tools/club_buildings_plan.py NAME ...    # only the named plans (e.g. clubshop_L2)

Same coordinate frame as tools/ground_plan.py (plot-local studs, origin = pitch
centre, +X east, -Z north, drawn north up with the street on the left) and the
same `Canvas`, palette and helpers, imported rather than copied.

Scale: the ground plan is drawn at 1.25 px/stud, which makes a 26 x 30 shop 32 px
across. Rooms are therefore zoomed (the px/stud is printed on every sheet next
to a 10-stud bar), and every sheet carries a locator: the whole plot drawn at a
fixed small scale with the building marked in red, so it can be found on
docs/ground_plan/proposed_L*.png. The concourse is a club-wide track, so its
sheets ARE the ground at the ground plan's own 1.25 px/stud.

Every building keeps ONE fixed shell across its levels (decision 5 in the doc).
It is drawn on every level: solid when built, dashed while it is still a
"for sale" outline. Geometry that exists in code is read from the source named
beside it (PlotGrounds.luau, Clubhouse.luau, WorldBuilder.luau); if code and
this file disagree, the code wins and this file is fixed. New geometry is TEMP
and belongs to the proposal.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ground_plan import (  # noqa: E402
    C, Canvas, SIDE_EDGE, END_EDGE, TIERS, stand_rects, draw_pitch, draw_ad_boards,
    draw_floodlight, MAST, ENV_W, ENV_E, ENV_N, ENV_S, CH_W, CH_E, CH_N, CH_S,
)

OUT = Path(__file__).resolve().parent.parent / "docs" / "club_buildings"

CB = dict(C)
CB.update(
    wood="#7a5534", till="#2c2c30", tile="#cfd6da", rack="#8d8d8d", bench="#78553a",
    locker="#5a6472", screen="#151515", gravel="#b9ab8c", grass="#cfe3b6", floor="#efece2",
    kit="#c8323c", kitwall="#3b5fa8", gold="#c9a94a", sale="#2d5a1e", new="#d9342b",
    damp="#aaa087", paint="#e2ded2", bg="#f6f4ee", physio="#e7a0a0", concrete="#c4c0b6",
)

# plot-wide outline for the locator inset, plot-local studs
PLOT_X0, PLOT_X1, PLOT_Z0, PLOT_Z1 = -440, 400, -380, 380
LOCATOR_PX = 120  # locator width in pixels
HEAD_PX, FOOT_PX = 134, 34


# ---------------------------------------------------------------- the sheet
def px(c, n):
    """n screen pixels in this sheet's stud units."""
    return n / c.s


def locator(c, where):
    """The whole plot, small, top right; `where` (x0, z0, x1, z1) in red."""
    k = px(c, LOCATOR_PX) / (PLOT_X1 - PLOT_X0)
    ox = c.x1 - px(c, LOCATOR_PX + 8)
    oz = c.z0 + px(c, 8)

    def P(x, z):
        return ox + (x - PLOT_X0) * k, oz + (z - PLOT_Z0) * k

    def box(x0, z0, x1, z1, **kw):
        a, b = P(x0, z0), P(x1, z1)
        c.rect(a[0], a[1], b[0], b[1], **kw)

    box(PLOT_X0, PLOT_Z0, PLOT_X1, PLOT_Z1, fill="#ffffff", stroke="#999", sw=0.6)
    box(-430, PLOT_Z0, -388, PLOT_Z1, fill=C["street"])
    box(-380, PLOT_Z0, 380, PLOT_Z1, fill=C["lawn"])
    box(ENV_W, ENV_N, ENV_E, ENV_S, fill=C["hard"], stroke=C["wall"], sw=0.6)
    box(-103, -153, 103, 153, fill=C["turf"])
    box(CH_W, CH_N, CH_E, CH_S, fill=C["brick"])
    box(222, -178, 338, 178, stroke=C["fence"], sw=0.6)
    box(-350, 40, -250, 300, stroke="#777", sw=0.6)
    x0, z0, x1, z1 = where
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    half = max((x1 - x0) / 2, 9), max((z1 - z0) / 2, 9)   # never smaller than a few px
    box(cx - half[0], cz - half[1], cx + half[0], cz + half[1], stroke=CB["new"], sw=1.6)
    a = P(PLOT_X0, PLOT_Z1)
    c.text(a[0] + px(c, LOCATOR_PX / 2), a[1] + px(c, 8), "where on the plot", 8, fill="#555")


def sheet(bounds, scale, title, subtitle, where, ground=None):
    """A Canvas over `bounds` (x0, x1, z0, z1) with a header (title, subtitle,
    locator) above and a footer (scale bar, north) below."""
    x0, x1, z0, z1 = bounds
    head, foot = HEAD_PX / scale, FOOT_PX / scale
    c = Canvas(x0, x1, z0 - head, z1 + foot, scale=scale)
    c.rect(c.x0, c.z0, c.x1, c.z1, fill=CB["bg"])
    c.rect(x0, z0, x1, z1, fill=ground or CB["grass"])
    c.text(x0 + px(c, 10), c.z0 + px(c, 18), title, 15, bold=True, anchor="l")
    for i, line in enumerate(subtitle.split("\n")):
        c.text(x0 + px(c, 10), c.z0 + px(c, 42 + 15 * i), line, 10, anchor="l")
    locator(c, where)
    # footer: a 10-stud bar, the zoom, north
    fz = z1 + px(c, 17)
    bx = x0 + px(c, 10)
    c.line([(bx, fz), (bx + 10, fz)], CB["text"], 2)
    c.text(bx + 10 + px(c, 6), fz, f"10 studs (~3.6 m)   ·   {scale:g} px/stud (ground plan: 1.25)", 9, anchor="l")
    nx = x1 - px(c, 16)
    c.line([(nx, fz + px(c, 9)), (nx, fz - px(c, 9))], CB["text"], 1.5, arrow=True)
    c.text(nx - px(c, 10), fz, "N", 10, bold=True)
    return c


def shell_outline(c, s, built):
    """The fixed shell: solid brick when built, dashed for-sale outline if not."""
    if built:
        c.rect(s[0], s[1], s[2], s[3], stroke=C["wall"], sw=2.5)
    else:
        c.rect(s[0], s[1], s[2], s[3], stroke=C["fence"], sw=1.5, dash="5,3")


def new(c, x0, z0, x1, z1):
    """Red outline around what this level adds."""
    c.rect(x0, z0, x1, z1, stroke=CB["new"], sw=1.4, dash="3,2")


PLANS = {}


def plan(name):
    def reg(fn):
        PLANS[name] = fn
        return fn
    return reg


# =================================================================== CLUB SHOP
# PlotGrounds.buildShop: SHOP_CX/CZ = -300, -150, SHOP_W/D = 26 x 30, walls 1
# thick. Shell x -313..-287, z -165..-135. Front (east, +X) wall from north to
# south: pier 3 | window 14 (z -162..-148) | pier 4 | door 6 (z -144..-138) | pier 3.
# Club-coloured fascia 0.5 proud of the front; apron out to the footpath leg
# x -269..-261 (PATH_X = -265, PATH_W = 8).
SHOP = (-313, -165, -287, -135)
SHOP_IN = (-312, -164, -288, -136)


def shop_base(c):
    x0, z0, x1, z1 = SHOP
    c.rect(-269, c.z0 + px(c, HEAD_PX), -261, c.z1 - px(c, FOOT_PX), fill=C["path"])
    c.text(-265, -118, "footpath (north leg)", 9, rot=-90)
    c.rect(-287, -146, -269, -136, fill=CB["concrete"])        # apron, doorZ0-2..doorZ1+2
    c.rect(x0, z0, x1, z1, fill=C["brick"])
    c.rect(*SHOP_IN, fill=CB["floor"])
    c.rect(-288, -162, -287, -148, fill=C["glass"])             # window
    c.rect(-288, -144, -287, -138, fill=C["door"])              # door
    c.rect(-287, z0, -286.5, z1, fill=CB["kit"])                # fascia, proud
    c.text(-283, -155, "window", 9, anchor="l")
    c.text(-283, -141, "door", 9, anchor="l")
    c.text(-300, -133, "fixed shell 26 x 30 (as built)", 9)
    shell_outline(c, SHOP, True)


def shop_counter(c, z0=-158, z1=-148, tills=(-150.4,)):
    c.rect(-304, z0, -302, z1, fill=CB["wood"])                # counter, x0+t+8..10
    for tz in tills:
        c.rect(-303.5, tz - 0.6, -302.5, tz + 0.6, fill=CB["till"])
    c.text(-300.6, (z0 + z1) / 2, "till counter", 9, rot=-90)


def shop_sheet(level, name, sub):
    return sheet((-322, -256, -172, -128), 11, f"CLUB SHOP — L{level} {name}", sub, SHOP)


@plan("clubshop_L1")
def shop_L1():
    c = shop_sheet(1, "Kiosk", "exists today (PlotGrounds.buildShop, X179 stock)\nmerchPerFan 0.6 · walk-in")
    shop_base(c)
    shop_counter(c)
    c.rect(-312, -158, -310.6, -142, fill=CB["wood"])          # shelf on the back wall
    for zc in (-154, -150, -146):
        c.rect(-311.9, zc - 1.2, -310.7, zc + 1.2, fill=CB["kit"])
    c.text(-309.2, -150, "shelf: folded shirts", 9, rot=-90)
    c.rect(-300, -163.7, -292, -163.3, fill=CB["rack"])          # scarf rail, north wall
    c.text(-296, -161.8, "scarf rail", 9)
    c.rect(-289.6, -161, -289.4, -149, fill=CB["rack"])          # window display rail
    for zc in (-158.5, -155, -151.5):
        c.rect(-290.2, zc - 1.1, -288.8, zc + 1.1, fill=CB["kit"])
    c.text(-292, -155, "3 shirts\nin window", 8, anchor="r")
    return c


@plan("clubshop_L2")
def shop_L2():
    c = shop_sheet(2, "Shop Unit", "TEMP £3,500 · merchPerFan 1.4\nshirt wall, two rails, lit fascia + projecting sign")
    shop_base(c)
    shop_counter(c)
    c.rect(-312, -163, -310.8, -137, fill=CB["kit"])            # full-length shirt wall
    c.text(-309.2, -150, "shirt wall", 9, rot=-90)
    new(c, -312.3, -163.3, -310.5, -136.7)
    for x in (-298, -294):                                       # two N-S clothing rails
        c.rect(x - 0.3, -161, x + 0.3, -151, fill=CB["rack"])
    new(c, -299, -162, -293, -150)
    c.text(-296, -163, "2 clothing rails", 9)
    c.rect(-286.5, -167, -285, -163, fill=CB["kit"])             # projecting sign
    new(c, -287, -167.5, -284.5, -162.5)
    c.text(-284, -168.5, "projecting sign", 8, anchor="l")
    c.text(-296, -141, "lane kept clear: door → till", 8, fill="#555")
    return c


@plan("clubshop_L3")
def shop_L3():
    c = shop_sheet(3, "Megastore", "TEMP £10,000 · needs County League · merchPerFan 2.4\nkit wall + printing, 2 gondolas, awning outside")
    shop_base(c)
    shop_counter(c, tills=(-155, -150.4))
    c.rect(-312, -163, -310.8, -137, fill=CB["kitwall"])
    c.text(-309.2, -155, "KIT WALL: numbered shirts", 9, rot=-90, fill=CB["kitwall"])
    c.rect(-311, -145, -306, -138, fill=CB["locker"])            # printing station
    c.text(-308.5, -141.5, "name +\nnumber\nprinting", 7, fill="#fff")
    new(c, -312.3, -163.3, -310.5, -136.7)
    new(c, -311.3, -145.3, -305.7, -137.7)
    for x in (-298, -294):                                       # gondola units, double-sided
        c.rect(x - 0.8, -162, x + 0.8, -150, fill=CB["rack"])
    new(c, -299.2, -162.5, -292.8, -149.5)
    c.text(-296, -163.6, "2 gondolas", 9)
    c.rect(-287, -163, -284, -137, fill=C["roof"], alpha=0.5)    # awning over window + door
    new(c, -287, -163, -284, -137)
    c.text(-283, -151.5, "awning", 8, anchor="l")
    c.text(-296, -141, "lane kept clear: door → till", 8, fill="#555")
    return c


@plan("clubshop_L4")
def shop_L4():
    c = shop_sheet(4, "Flagship Store", "TEMP £24,000 · needs Regional Premier · merchPerFan 3.4\nscreen on the kit wall, 2 tills, 3 gondolas, trophy replica, mannequins")
    shop_base(c)
    shop_counter(c, z0=-160, z1=-146, tills=(-157, -149))
    c.rect(-312, -163, -310.8, -137, fill=CB["kitwall"])
    c.rect(-312, -155, -310.8, -145, fill=CB["screen"])          # digital screen in the kit wall
    c.text(-309.2, -155, "kit wall + LED screen", 9, rot=-90, fill=CB["kitwall"])
    new(c, -312.3, -155.3, -310.5, -144.7)
    c.rect(-311, -145, -306, -138, fill=CB["locker"])
    c.text(-308.5, -141.5, "printing", 7, fill="#fff")
    for x in (-298, -294.5):
        c.rect(x - 0.8, -162, x + 0.8, -150, fill=CB["rack"])
    c.rect(-291.8, -162, -291, -156, fill=CB["rack"])            # third, short gondola by the window
    new(c, -292.2, -162.4, -290.6, -155.6)
    c.rect(-300, -137.2, -294, -136, fill=CB["gold"])            # trophy replica cabinet, south wall
    new(c, -300.3, -137.6, -293.7, -135.8)
    c.text(-297, -138.6, "trophy replica cabinet", 8)
    for zc in (-159, -151):                                      # mannequins in the window
        c.circle(-289.3, zc, 0.8, fill=CB["kit"], stroke="#333", sw=0.6)
    new(c, -290.3, -160, -288.3, -150)
    c.text(-283, -159.5, "mannequins", 8, anchor="l")
    c.rect(-287, -163, -284, -137, fill=C["roof"], alpha=0.5)
    return c


# ===================================================================== ACADEMY
# PlotGrounds.buildAcademy (X289): a 14 x 10 x 8 cabin at ACADEMY_CX/CZ =
# TRAIN_CX + TRAIN_W/2 + 18, TRAIN_CZ[2] = (348, 90): walls x 341..355,
# z 85..95, slab 1 wider; doorway in the west face (z 88.5..91.5), intake board
# on the west face. Training fence x 222..338 (ground plan §5), pitch 2 grass
# x 230..330, z 20..170 (it exists at spawn in code today; at training level 3
# in the plan).
# The ground plan reserves x 342..376, z -60..60 for the academy; the hut is
# 25 studs south of that. Proposed fixed shell (Q3): the reserved slot run
# south to take in the hut, x 340..376, z -60..96, so decision 3 ("level 1 is
# today's hut at pitch 2; it grows into the reserved spot") and decision 5
# (nothing moves) both hold.
ACADEMY = (340, -60, 376, 96)
RESERVED = (342, -60, 376, 60)


def academy_base(c, built):
    c.rect(300, -72, 338, 108, fill=CB["grass"])
    c.rect(300, 20, 330, 108, fill=C["turf"])
    c.rect(300, -72, 330, -20, fill=C["turf"])
    c.text(315, 64, "training\npitch 2", 9, fill="#fff", bold=True)
    c.text(315, -46, "training\npitch 1", 9, fill="#fff", bold=True)
    c.line([(338, -72), (338, 108)], C["fence"], 1.5, dash="4,2")
    c.text(336, 0, "training fence", 8, rot=-90)
    c.rect(*RESERVED, stroke="#8a6000", sw=1, dash="2,3")
    c.text(359, -64, "ground plan reserved slot", 8, fill="#8a6000")
    shell_outline(c, ACADEMY, built)
    c.text(358, 100, "proposed fixed shell 36 x 156 (Q3)", 8)
    # the hut, as built, at every level
    c.rect(340, 84, 356, 96, fill=CB["concrete"])
    c.rect(341, 85, 355, 95, fill=CB["floor"], stroke=C["wall"], sw=1.2)
    c.rect(340.6, 88.5, 341.4, 91.5, fill=C["door"])
    c.rect(340.1, 86, 340.5, 94, fill="#1c3c28")
    c.text(348, 90, "youth hut\n14 x 10", 8)


def academy_sheet(level, name, sub):
    return sheet((300, 386, -72, 108), 5, f"ACADEMY — L{level} {name}", sub, ACADEMY)


def classroom(c):
    c.rect(341, 69, 355, 83, fill=CB["floor"], stroke=C["wall"], sw=1.2)
    c.text(348, 76, "classroom\ncabin", 8)


def cage(c, lit=False):
    c.rect(346, 4, 374, 56, fill="#4f9a44", stroke="#333", sw=1)
    c.rect(348, 6, 372, 54, stroke="#eef7e6", sw=0.8)
    c.text(360, 30, "small-sided\ncage 28 x 52", 8, fill="#fff")
    if lit:
        for x, z in ((346, 4), (374, 4), (346, 56), (374, 56)):
            c.circle(x, z, 1.2, fill=C["mast"])


def academy_block(c):
    c.rect(358, 62, 376, 96, fill=CB["floor"], stroke=C["wall"], sw=1.2)
    c.text(367, 79, "academy\nbuilding\n(2 storeys)\nclassrooms\ncoach's office", 8)


@plan("academy_L1")
def academy_L1():
    c = academy_sheet(1, "Youth Hut", "exists today (X289), free\nseen from outside, not walk-in\ntoday's intake, unchanged")
    academy_base(c, built=False)
    c.text(358, 20, "rest of the shell:\ngrass, for sale", 9, fill=CB["sale"])
    return c


@plan("academy_L2")
def academy_L2():
    c = academy_sheet(2, "Youth Centre", "TEMP £4,000\n+1 graduate a season\npotential +1")
    academy_base(c, built=False)
    classroom(c)
    new(c, 340.5, 68.5, 355.5, 83.5)
    cage(c)
    new(c, 345.5, 3.5, 374.5, 56.5)
    return c


@plan("academy_L3")
def academy_L3():
    c = academy_sheet(3, "Academy Building", "TEMP £12,000 · needs Regional Premier\n+1 graduate, potential +2,\nwonderkid headroom +1")
    academy_base(c, built=False)
    classroom(c)
    cage(c, lit=True)
    academy_block(c)
    new(c, 357.5, 61.5, 376.5, 96.5)
    c.text(360, 60, "cage floodlit", 8)
    return c


@plan("academy_L4")
def academy_L4():
    c = academy_sheet(4, "Elite Academy", "TEMP £28,000 · needs National League\n+2 graduates, potential +3,\nwonderkid headroom +2")
    academy_base(c, built=True)
    classroom(c)
    cage(c, lit=True)
    academy_block(c)
    c.rect(344, -58, 376, -8, fill=CB["floor"], stroke=C["wall"], sw=1.2)
    c.line([(344, -33), (376, -33)], C["wall"], 1)
    c.text(360, -45.5, "dorms", 9)
    c.text(360, -20.5, "gym + canteen", 9)
    new(c, 343.5, -58.5, 376.5, -7.5)
    return c


# ====================================================================== OFFICE
# Clubhouse.ROOMS.Office: x -156..-122, z 16.4..39 (clear floor). Openings:
# lobby door on the north partition x -154..-149, side door on the south wall
# x -155..-150 (spawn at -152.5, 34, looking out of it), window in the west
# wall z 24..34. Furniture from Clubhouse.buildOffice (P5, 2026-09-23): desk at
# the east end (-128, 27.7) along Z with the chair east of it, bookshelf and
# drawer cabinet + telly on the west wall, bench on the south wall, ladder NE,
# boxes + tyre on the north wall, bin SE, fixtures notice on the east wall.
# Trophy shelf (buildTrophies) on the north wall x -143.5..-123.5. The level
# fittings are exactly WorldBuilder.dressOffice's tiers 2/3/4, made bought.
OFFICE = (-156, 16.4, -122, 39)


def office_base(c, painted):
    x0, z0, x1, z1 = OFFICE
    c.rect(-157, 15.6, -121, 40, fill=C["brick"])
    c.rect(x0, z0, x1, z1, fill=CB["paint"] if painted else CB["damp"])
    c.rect(-156.8, 24, -155.2, 34, fill=C["glass"])              # window, west wall
    c.text(-157.8, 29, "window", 9, anchor="r")
    c.rect(-154, 15.6, -149, 17, fill=C["door"])                 # lobby door
    c.text(-151.5, 13.8, "to lobby", 9)
    c.rect(-155, 38.4, -150, 40, fill=C["door"])                 # side door
    c.text(-152.5, 41.8, "side door (spawn)", 9)
    c.circle(-152.5, 34, 0.8, fill="#2c4c9c")
    # desk + laptop + chair (desk 2.9 x 6.3 at DESK_SCALE 1.15)
    c.rect(-129.45, 24.55, -126.55, 30.85, fill=CB["wood"])
    c.rect(-128.6, 27.1, -127.4, 28.4, fill=CB["screen"])
    c.circle(-124.2, 27.7, 1.2, fill=CB["bench"])
    c.text(-131, 27.7, "desk + laptop", 8, rot=-90)
    c.text(-124.2, 31, "chair", 8)
    c.rect(-156, 16.7, -154.4, 20.5, fill=CB["wood"])            # bookshelf
    c.rect(-156, 20.75, -154.7, 23.85, fill=CB["locker"])        # drawer cabinet + telly
    c.text(-153.8, 20.3, "shelf · cabinet + telly", 8, anchor="l")
    c.rect(-134.1, 37.6, -130.9, 39, fill=CB["bench"])           # bench, south wall
    c.text(-132.5, 36.4, "bench", 8)
    c.rect(-132.8, 16.8, -126.2, 18.6, fill="#a08a6a")           # boxes + tyre
    c.text(-129.5, 19.8, "boxes · tyre", 8)
    c.rect(-123.9, 16.9, -122.5, 18.3, fill="#9a7a50")           # ladder
    c.rect(-124.2, 36.9, -122.2, 38.8, fill="#555")              # bin
    c.rect(-122.2, 25.5, -122, 30, fill="#ece4c8")               # fixtures notice, east wall
    c.text(-120.8, 27.7, "fixtures notice", 8, rot=-90)
    c.rect(-143.5, 16.4, -123.5, 17.2, fill=CB["wood"], alpha=0.6)  # trophy shelf (with trophies)
    c.text(-138, 18.2, "trophy shelf + pennants (honours)", 8)
    shell_outline(c, (-157, 15.6, -121, 40), True)


def office_sheet(level, name, sub):
    return sheet((-162, -116, 10, 45), 14, f"OFFICE — L{level} {name}", sub, OFFICE, ground="#d8d4ca")


@plan("office_L1")
def office_L1():
    c = office_sheet(1, "Rundown", "exists today · spawn room · walk-in\ndamp stains, green-screen laptop, bare bulb 1.2")
    office_base(c, painted=False)
    for x, z in ((-147, 17.2), (-140, 17.2), (-122.8, 34)):
        c.circle(x, z, 0.9, fill="#6f6650")
    c.text(-142, 22, "damp stains", 9, fill="#5a5040")
    return c


def office_cabinet(c):
    c.rect(-125, 19.4, -122, 23.4, fill=CB["rack"])


def office_board(c):
    c.rect(-149, 38.4, -139, 39, fill="#1c4628")
    c.text(-144, 36.8, "tactics board", 8)


@plan("office_L2")
def office_L2():
    c = office_sheet(2, "Painted", "TEMP £1,000 · sponsor +2%\npainted over the damp, filing cabinet, bulb 1.8")
    office_base(c, painted=True)
    office_cabinet(c)
    new(c, -125.3, 19.1, -121.8, 23.7)
    c.text(-125.6, 21.4, "filing cabinet", 8, anchor="r")
    return c


@plan("office_L3")
def office_L3():
    c = office_sheet(3, "Modern", "TEMP £5,000 · needs Regional Premier · sponsor +4%\nflat screen (SQUAD / TRANSFERS / FINANCE), tactics board")
    office_base(c, painted=True)
    office_cabinet(c)
    office_board(c)
    new(c, -149.3, 38.1, -138.7, 39.3)
    new(c, -128.9, 26.8, -127.1, 28.7)
    return c


@plan("office_L4")
def office_L4():
    c = office_sheet(4, "Branded", "TEMP £15,000 · needs National League · sponsor +7%\ncrest + club name panel, plant, bright cool light 2.4")
    office_base(c, painted=True)
    office_cabinet(c)
    office_board(c)
    c.rect(-138.5, 38.4, -124.5, 39, fill=CB["kit"])
    c.text(-127, 36.9, "crest + name panel", 8)
    new(c, -138.8, 38.1, -124.2, 39.3)
    c.circle(-128, 22.2, 1.2, fill="#3c783c")
    new(c, -129.4, 20.8, -126.6, 23.6)
    c.text(-130, 22.2, "plant", 8, anchor="r")
    return c


# ===================================================== COACH'S CABIN / ATHLETIC CENTRE
# Ground plan §5 + tools/ground_plan.py: shell x 240..320, z -16..16 (80 x 32)
# inside the training fence, between training pitch 1 (z -170..-20) and pitch 2
# (z 20..170). The #23a path (x 276..284) comes up from the south to the
# building door at z 16. The L2 cabin is 16 x 10 at (280, 0) and becomes the
# L3 reception, so nothing is knocked down.
GYM = (240, -16, 320, 16)


def gym_base(c, built, pitch1, pitch2):
    c.rect(222, -30, 338, 42, fill=CB["grass"])
    if pitch1:
        c.rect(230, -30, 330, -20, fill=C["turf"])
        c.text(280, -25, "training pitch 1", 9, fill="#fff")
    else:
        c.rect(230, -30, 330, -20, stroke=C["fence"], sw=1, dash="3,2")
        c.text(280, -25, "pitch 1 (for sale)", 9, fill=CB["sale"])
    if pitch2:
        c.rect(230, 20, 330, 30, fill=C["turf"])
        c.text(252, 25, "training pitch 2", 9, fill="#fff")
    else:
        c.rect(230, 20, 330, 30, stroke=C["fence"], sw=1, dash="3,2")
        c.text(252, 25, "pitch 2 (for sale)", 9, fill=CB["sale"])
    c.rect(276, 16, 284, 42, fill=C["path"])
    c.text(287, 37, "#23a path from the south gate", 8, anchor="l")
    shell_outline(c, GYM, built)


def gym_sheet(level, name, sub):
    return sheet((222, 338, -30, 42), 6, f"COACH'S CABIN → ATHLETIC CENTRE — L{level} {name}", sub, GYM)


def cabin(c):
    c.rect(272, -5, 288, 5, fill=CB["floor"], stroke=C["wall"], sw=1.2)
    c.rect(278, 4.5, 282, 5.5, fill=C["door"])
    c.rect(276, 5, 284, 16, fill=C["path"])


@plan("coachcabin_L1")
def gym_L1():
    c = gym_sheet(1, "nothing", "for-sale outline and board · no coach can be hired\nvisible at spawn (ground plan §6)")
    gym_base(c, built=False, pitch1=False, pitch2=False)
    c.text(280, 0, "for sale", 11, fill=CB["sale"], bold=True)
    c.rect(283, 12, 286, 13, fill=CB["wood"])
    c.text(290, 11, "board", 8, anchor="l")
    return c


@plan("coachcabin_L2")
def gym_L2():
    c = gym_sheet(2, "Coach's Cabin", "TEMP £1,000 · unlocks hiring a coach (Config.CoachLevels)\nseen from outside")
    gym_base(c, built=False, pitch1=False, pitch2=False)
    cabin(c)
    new(c, 271.5, -5.5, 288.5, 16)
    c.text(280, 0, "cabin 16 x 10", 9)
    c.text(258, 0, "rest: for sale", 9, fill=CB["sale"])
    return c


def centre(c, physio):
    x0, z0, x1, z1 = GYM
    c.rect(x0, z0, x1, z1, fill=CB["floor"])
    for x in (256, 272, 288):
        c.line([(x, z0), (x, z1)], C["wall"], 1.2)
    c.rect(272, -5, 288, 5, stroke="#999", sw=0.8, dash="2,2")   # the old cabin
    c.rect(276, 15.5, 284, 16.5, fill=C["door"])
    c.text(280, -9, "reception\n(was the cabin)", 8)
    c.text(264, -10, "coach's office", 8)
    c.rect(258, -2, 262, 6, fill=CB["wood"])
    c.rect(271.4, -8, 271.8, 4, fill="#1c4628")
    c.text(304, -10, "gym", 9, bold=True)
    for i in range(4):
        c.rect(292 + i * 6, 2, 296 + i * 6, 8, fill=CB["locker"])
    c.text(304, 11, "bikes · weights · treadmills", 8)
    if physio:
        c.rect(242, -12, 254, -8, fill=CB["physio"])
        c.rect(242, -3, 254, 1, fill=CB["physio"])
        c.circle(248, 9, 2.5, fill=C["water"], stroke="#555", sw=0.6)
        c.text(248, -14.5, "physio", 8, bold=True)
        c.text(248, 4.5, "2 treatment tables", 7)
        c.text(248, 13, "ice bath", 7)
    else:
        c.text(248, 0, "shell only,\nfitted at L4", 8, fill="#777")
    shell_outline(c, GYM, True)


@plan("athleticcentre_L3")
def gym_L3():
    c = gym_sheet(3, "Athletic Centre", "TEMP £9,000 · needs training pitch 1 · walk-in\ndevelopment +15% of base chance, added after the coach")
    gym_base(c, built=True, pitch1=True, pitch2=False)
    centre(c, physio=False)
    new(c, 240, -16, 272, 16)
    new(c, 288, -16, 320, 16)
    return c


@plan("athleticcentre_L4")
def gym_L4():
    c = gym_sheet(4, "+ Physio", "TEMP £20,000 · needs training pitch 2 · walk-in\ninjuries last one match less (never under 1)")
    gym_base(c, built=True, pitch1=True, pitch2=True)
    centre(c, physio=True)
    new(c, 240.5, -15.5, 255.5, 15.5)
    return c


# ============================================================ SCOUTING ROOM
# Clubhouse.ROOMS.Store: x -156..-122, z -39..-16.4, the office's mirror across
# the lobby. Lobby door in its south partition x -154..-149. Kiosk hatch in the
# west wall z -34..-26 (ground plan §2 removes it, #12, station 1's job). As
# built: three boxes by (-127, -36.5), a ladder at (-123.2, -20), a bulb.
STORE = (-156, -39, -122, -16.4)


def store_base(c, hatch_note):
    x0, z0, x1, z1 = STORE
    c.rect(-157, -40, -121, -15.6, fill=C["brick"])
    c.rect(x0, z0, x1, z1, fill=CB["floor"])
    c.rect(-154, -17, -149, -15.6, fill=C["door"])
    c.text(-151.5, -13.8, "to lobby", 9)
    c.rect(-156.8, -34, -155.2, -26, fill="#999", stroke="#666", sw=0.6, dash="2,2")
    c.text(-157.8, -30, hatch_note, 8, anchor="r")
    shell_outline(c, (-157, -40, -121, -15.6), True)


def store_sheet(level, name, sub):
    return sheet((-176, -116, -45, -10), 14, f"SCOUTING ROOM — L{level} {name}", sub, STORE, ground="#d8d4ca")


@plan("scoutroom_L1")
def scout_L1():
    c = store_sheet(1, "Store", "exists today (Clubhouse.buildLobby) · no scout can be hired\npacks still come after every match (walk-in trialists)")
    store_base(c, "kiosk hatch\n(#12 removes it)")
    c.rect(-128.4, -37.8, -125.6, -35.2, fill="#a08a6a")
    c.text(-127, -33.6, "boxes", 8)
    c.rect(-123.9, -21, -122.5, -19, fill="#9a7a50")
    c.text(-125, -20, "ladder", 8, anchor="r")
    c.text(-139, -27.7, "empty store", 11, fill="#777")
    return c


@plan("scoutroom_L2")
def scout_L2():
    c = store_sheet(2, "Scouting Room", "TEMP £1,500 · unlocks hiring a scout (Config.ScoutLevels) · walk-in\nmap wall, desk with the scout's laptop, shortlist board, cabinet")
    store_base(c, "hatch gone\n(#12)")
    c.rect(-150, -39, -130, -38.4, fill="#2c4c3a")               # world map, north wall
    c.text(-140, -37, "map wall: pins where the scout has been", 8)
    new(c, -150.3, -39.3, -129.7, -38.1)
    c.rect(-129, -30, -126, -24, fill=CB["wood"])                # desk at the east end
    c.circle(-124.2, -27, 1.2, fill=CB["bench"])
    c.text(-131, -27, "desk + laptop", 8, rot=-90)
    new(c, -129.3, -30.3, -122.8, -23.7)
    c.rect(-122.6, -37, -122, -32, fill="#ece4c8")               # shortlist board, east wall
    c.text(-123.6, -34.5, "shortlist board\n(this week's 3 cards)", 7, anchor="r")
    new(c, -122.9, -37.3, -121.8, -31.7)
    c.rect(-156, -24, -154.6, -20, fill=CB["locker"])            # filing cabinet
    c.text(-153.8, -22, "filing cabinet", 8, anchor="l")
    new(c, -156.2, -24.3, -154.3, -19.7)
    return c


# ==================================================== CONCOURSE UNDERCROFT
# One club-wide track (ground plan §4), so each level is the whole ground at the
# ground plan's own 1.25 px/stud. The four levels are Config.AmenityLevels'
# four rows (Nothing / Snack Bar / Merch Stand / Fan Zone) mapped onto the plan:
# its catering tier 3 (undercroft + fan zone) is split in two (Q10).
KIOSKS = ((0, -232), (0, 232), (188, -60), (188, 60), (-185, -110), (-185, 110))


def ground(c, tier, surface):
    c.rect(ENV_W, ENV_N, ENV_E, ENV_S, fill=surface, stroke=C["wall"], sw=2)
    draw_pitch(c)
    draw_ad_boards(c)
    t = TIERS[tier]
    fill = C["standL4"] if t["roof"] else C["stand"]
    for side, poly in stand_rects(tier):
        if tier == 1 and side != "E":
            c.poly(poly, stroke=C["wall"], sw=0.8, dash="3,2")
            continue
        c.poly(poly, fill=fill, stroke=C["wall"], sw=0.8)
    c.rect(CH_W, CH_N, CH_E, CH_S, fill=C["brick"], stroke=C["wall"], sw=0.8)
    for x, z in MAST:
        draw_floodlight(c, x, z, label=False)


def conc_sheet(level, name, sub):
    return sheet((-215, 215, -275, 275), 1.25, f"CONCOURSE — L{level} {name}", sub, (ENV_W, ENV_N, ENV_E, ENV_S))


def undercroft(c):
    for side, poly in stand_rects(3):
        xs, zs = [p[0] for p in poly], [p[1] for p in poly]
        c.rect(min(xs) + 2, min(zs) + 2, max(xs) - 2, max(zs) - 2, stroke="#fff", sw=1.4, dash="3,2")
    c.text(146, 0, "bars under every stand", 9, fill="#fff", bold=True, rot=90)


@plan("concourse_L1")
def conc_L1():
    c = conc_sheet(1, "Burger Van", "exists today (AmenityLevels 'Nothing') · perFan 0\ngrass, gravel strip, one van, portaloos · stands shown at map tier 1")
    ground(c, 1, CB["grass"])
    c.rect(121 + 9.6, -40, 121 + 15, 40, fill=CB["gravel"])
    c.rect(-160, -110, -146, -100, fill=C["van"], stroke="#888", sw=0.8)
    c.text(-153, -118, "burger van", 9)
    c.rect(-160, 100, -148, 112, fill="#7fb3c9", stroke="#555", sw=0.8)
    c.text(-154, 120, "portaloos", 9)
    c.text(146, 0, "gravel strip behind the stand", 9, rot=90)
    return c


@plan("concourse_L2")
def conc_L2():
    c = conc_sheet(2, "Kiosks", "TEMP £1,200 (was Snack Bar) · needs a stand at Main Stand or bigger\nperFan 2, demand +10% · paved; a kiosk behind every stand at map tier 2+")
    ground(c, 2, C["hard"])
    for x, z in KIOSKS:
        c.rect(x - 7, z - 5, x + 7, z + 5, fill=C["building"], stroke=C["wall"], sw=0.8)
        new(c, x - 9, z - 7, x + 9, z + 7)
    c.text(0, -218, "kiosk", 9)
    return c


@plan("concourse_L3")
def conc_L3():
    c = conc_sheet(3, "Undercroft Bars", "TEMP £6,000 (was Merch Stand) · needs a stand at Double-tier or bigger\nperFan 4, demand +20% · bars under every map tier 3+ stand")
    ground(c, 3, C["hard"])
    undercroft(c)
    c.text(0, 240, "kiosks stay behind any stand still below tier 3", 9)
    return c


@plan("concourse_L4")
def conc_L4():
    c = conc_sheet(4, "Fan Zone", "TEMP £15,000 (was Fan Zone) · needs Undercroft Bars\nperFan 6, demand +35% · picnic benches north of the west wing")
    ground(c, 3, C["hard"])
    undercroft(c)
    c.rect(-198, -150, -176, -70, fill="#f6e7b2", stroke="#bbb", sw=0.8)
    for z in range(-144, -74, 12):
        c.rect(-194, z, -180, z + 4, fill=CB["bench"])
    new(c, -199, -151, -175, -69)
    c.text(-187, -160, "fan zone", 10, bold=True)
    return c


# ============================================================ DRESSING ROOMS
# Clubhouse.ROOMS.Home: x -147.6..-122, z 4.8..15.6 (south of the corridor);
# Away mirrors it at z -15.6..-4.8 (north). Corridor z -4..4 from the lobby
# mouth (x -148) to the players' door (x -121, the tunnel). Doors in the
# corridor walls at x -139..-134. Clubhouse.buildDressingRooms, per room:
# benches 3.2 deep down both long walls (inner run broken at the door), peg rail
# + hung shirts above (WorldBuilder.dressDressingRooms names the home XI on the
# "Shirt" parts, so an upgrade must keep >= 11 of them), tactics board on the
# west end wall, a high slot window in the east wall, one bulb. Only the HOME
# room upgrades (Q13); the away room stays at level 1.
DRESS = (-148, -16, -121, 16)


def dress_room(c, zs, level):
    """zs = +1 home (south), -1 away (north). `level` = what this room shows."""
    inner, outer = 4.8, 15.6

    def box(xa, a, xb, b, **kw):          # a, b: distances from the corridor axis
        za, zb = zs * a, zs * b
        c.rect(xa, min(za, zb), xb, max(za, zb), **kw)

    box(-147.6, inner, -122, outer, fill=CB["tile"] if level >= 3 else CB["floor"])
    if level >= 3:                                              # cubicles on both long walls
        runs = ((-145.6, -128.5, outer - 3.2, outer), (-145.6, -140, inner, inner + 3.2), (-133, -124, inner, inner + 3.2))
        for xa, xb, a, b in runs:
            n = max(1, int((xb - xa) // 2.8))
            w = (xb - xa) / n
            for i in range(n):
                box(xa + i * w + 0.1, a, xa + (i + 1) * w - 0.1, b, fill=CB["kit"] if level >= 4 else CB["locker"])
    else:
        box(-145.6, outer - 3.2, -128.5 if level >= 2 else -124, outer, fill=CB["bench"])
        box(-145.6, inner, -140, inner + 3.2, fill=CB["bench"])
        box(-133, inner, -124, inner + 3.2, fill=CB["bench"])
        if level >= 2:                                          # lockers along the outer wall
            box(-145.6, outer - 0.9, -128.5, outer, fill=CB["locker"])
    if level >= 2:                                              # shower bay, outer-east corner
        box(-128, outer - 5, -122, outer, fill=C["water"], stroke="#777", sw=0.6)
        c.text(-125, zs * (outer - 2.5), "showers\n+ ice bath" if level >= 3 else "showers", 7)
    box(-147.6, 8.2, -147.2, 12.2, fill="#151515" if level >= 4 else "#1c4628")   # board -> screen at L4
    box(-121.6, 8.5, -121, 12.5, fill=C["glass"])                                  # high slot window
    if level >= 4:
        c.circle(-131, zs * 10.2, 2, fill=CB["gold"])
        c.text(-131, zs * 10.2, "crest", 7)
    box(-139, 4, -134, 4.8, fill=C["door"])
    c.text(-140, zs * 10.2, ("HOME" if zs > 0 else "AWAY") + f" (L{level})", 9, bold=True)


def dress_base(c, home_level):
    c.rect(-148.4, -16.4, -121, 16.4, fill=C["brick"])
    c.rect(-147.6, -4, -122, 4, fill=C["path"])
    c.rect(-148.4, -4, -147.6, 4, fill=C["door"])
    c.rect(-121.6, -4, -121, 4, fill=C["door"])
    c.text(-150, 0, "lobby", 9, anchor="r")
    c.text(-119.5, 0, "players' door → tunnel", 9, anchor="l")
    c.text(-134.8, 0, "corridor", 9)
    dress_room(c, 1, home_level)
    dress_room(c, -1, 1)
    shell_outline(c, (-148.4, -16.4, -121, 16.4), True)


def dress_sheet(level, name, sub):
    return sheet((-162, -96, -22, 22), 14, f"DRESSING ROOMS — L{level} {name}", sub, DRESS, ground="#d8d4ca")


@plan("dressing_L1")
def dress_L1():
    c = dress_sheet(1, "Benches", "exists today · walk-in · both rooms\nbenches + peg rail, shirts named for the XI, tactics board")
    dress_base(c, 1)
    return c


@plan("dressing_L2")
def dress_L2():
    c = dress_sheet(2, "Lockers + Showers", "TEMP £2,000 · home room only\nhome strength +1 at home matches")
    dress_base(c, 2)
    new(c, -145.9, 10.3, -121.7, 15.9)
    return c


@plan("dressing_L3")
def dress_L3():
    c = dress_sheet(3, "Cubicles", "TEMP £6,000 · needs Regional Premier · home room only\nhome strength +2 · tiled floor, ice bath")
    dress_base(c, 3)
    new(c, -145.9, 4.6, -121.7, 15.9)
    return c


@plan("dressing_L4")
def dress_L4():
    c = dress_sheet(4, "Pro Dressing Room", "TEMP £14,000 · needs National League · home room only\nhome strength +3 · club-colour cubicles, crest, screen")
    dress_base(c, 4)
    new(c, -147.9, 4.6, -121.7, 15.9)
    return c


# ---------------------------------------------------------------------- main
def main(names=None):
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names or PLANS:
        c = PLANS[name]()
        c.to_svg(OUT / f"{name}.svg")
        c.to_png(OUT / f"{name}.png")
        print(OUT / f"{name}.svg")


if __name__ == "__main__":
    main(sys.argv[1:] or None)
