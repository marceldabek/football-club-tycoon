"""Top-down floor plans for the club buildings spec (docs/CLUB_BUILDINGS.md, backlog P9).

    python tools/club_buildings_plan.py            # writes docs/club_buildings/*.svg and *.png
    python tools/club_buildings_plan.py NAME ...    # only the named plans (e.g. clubshop_L2)

Same coordinate frame and drawing conventions as tools/ground_plan.py (plot-local
studs, origin pitch centre, +X east, -Z north, north drawn up): this module
imports that one's `Canvas` and palette rather than duplicating them.

Every building keeps ONE fixed shell (its top-level footprint, `CLAUDE.md`/
`docs/CLUB_BUILDINGS.md` decision 5) across all its levels; a level only
refits what is drawn *inside* the dashed/solid outline, so nothing here ever
implies moving a wall that a later level would have to move back.

Coordinates for shells that already exist in code are read from the source
named in each comment (SHOP_CX/SHOP_W etc. in PlotGrounds.luau, Clubhouse.ROOMS
in Clubhouse.luau); shells that do not exist yet use the reserved footprint
from docs/superpowers/specs/2026-09-22-ground-plan-design.md.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ground_plan import Canvas, C, draw_tree, draw_hedge, legend  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "docs" / "club_buildings"

# a few extra colours the ground plan palette doesn't need
CB = dict(C)
CB.update(
    wood="#6e4e32", till="#2c2c30", tile="#cfd6da", counter="#8a6a48",
    kitwall="#3b5fa8", rack="#9a9a9a", bench="#78553a", locker="#5a6472",
    screen="#151515", turfgreen="#5fae4f", gravel="#b9ab8c", grass="#cfe3b6",
    future="#eef0e9",
)


# ---------------------------------------------------------------- shared frame
def frame_building(shell, margin, title, subtitle, built=True, scale=6):
    """A Canvas sized to `shell` (dict x0/x1/z0/z1) plus `margin` studs, with
    the fixed shell outline (dashed = not built yet at this level, solid brick
    = built) and a title/scale bar in the ground_plan.py house style."""
    x0, x1, z0, z1 = shell["x0"] - margin, shell["x1"] + margin, shell["z0"] - margin, shell["z1"] + margin
    top_margin = 16
    c = Canvas(x0, x1, z0 - top_margin, z1 + 6, scale=scale)
    c.rect(x0, z0 - top_margin, x1, z1 + 6, fill="#f4f2ea")
    if built:
        c.rect(shell["x0"], shell["z0"], shell["x1"], shell["z1"], fill=CB["future"], stroke=CB["wall"], sw=2)
    else:
        c.rect(shell["x0"], shell["z0"], shell["x1"], shell["z1"], fill=CB["grass"], stroke=CB["fence"], sw=1.5, dash="3,2")
    c.text((x0 + x1) / 2, z0 - top_margin + 6, title, 8, bold=True)
    c.text((x0 + x1) / 2, z0 - top_margin + 14, subtitle, 6)
    # scale bar: 10 studs (~3.6 m)
    bx0 = x1 - 34
    c.line([(bx0, z1 + 2), (bx0 + 10, z1 + 2)], CB["text"], 1.5)
    c.text(bx0 + 5, z1 - 1.5, "10 studs (~3.6 m)", 5)
    return c


def door(c, x0, x1, z0, z1):
    c.rect(x0, z0, x1, z1, fill=CB["door"])


def label_shell(c, shell, text):
    c.text((shell["x0"] + shell["x1"]) / 2, shell["z1"] + 4, text, 6)


PLANS = {}


def plan(name, shell, margin, title, subtitle, draw_fn, built=True, scale=6):
    """Registers `name` -> a zero-arg function building one Canvas: the shared
    frame plus `draw_fn(c)` for that level's interior."""

    def build():
        c = frame_building(shell, margin, title, subtitle, built=built, scale=scale)
        draw_fn(c)
        return c

    PLANS[name] = build


# =================================================================== CLUB SHOP
# PlotGrounds.luau: SHOP_CX,SHOP_CZ = -300,-150; SHOP_W,SHOP_D = 26,30. Door +
# window face +X (the footpath). This is the fixed shell at every level
# (docs/CLUB_BUILDINGS.md decision 5) -- the shop never gets bigger outside.
SHOP_SHELL = dict(x0=-313, x1=-287, z0=-165, z1=-135)


def _shop_shell(c):
    s = SHOP_SHELL
    c.rect(s["x0"], s["z0"], s["x1"], s["z1"], fill="#efece2", stroke=CB["wall"], sw=1.5)
    # window (north) + door (south) on the east (+X) wall, as built today
    door(c, s["x1"] - 0.6, s["x1"], s["z0"] + 22, s["z0"] + 28)
    c.rect(s["x1"] - 0.6, s["x1"], s["z0"] + 3, s["z0"] + 17, fill=CB["glass"])
    c.text(s["x1"] + 3, s["z0"] + 10, "window", 5, anchor="l")
    c.text(s["x1"] + 3, s["z0"] + 25, "door", 5, anchor="l")


def shop_L1(c):
    _shop_shell(c)
    s = SHOP_SHELL
    # X179 (PlotGrounds.buildShop, as built): counter+till facing the door,
    # a shelf of folded shirts on the back (west) wall, a scarf rail north end
    c.rect(s["x0"] + 8.6, s["z0"] + 6.6, s["x0"] + 10.6, s["z0"] + 16.6, fill=CB["wood"])
    c.text(s["x0"] + 9.6, s["z0"] + 11.6, "till", 5, rot=90)
    c.rect(s["x0"] + 0.6, s["z0"] + 6.6, s["x0"] + 2, s["z1"] - 6.6, fill=CB["wood"])
    c.text(s["x0"] + 1.3, s["z0"] + 3, "shelf: folded shirts", 5, rot=90, anchor="l")
    c.rect(s["x0"] + 12.6, s["z0"] + 0.6, s["x0"] + 20.6, s["z0"] + 1.6, fill=CB["rack"])
    c.text(s["x0"] + 16.6, s["z0"] - 2, "scarf rail", 5)
    c.text((s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2 + 9, "KIOSK\n~8 parts", 6, bold=True)


def shop_L2(c):
    _shop_shell(c)
    s = SHOP_SHELL
    c.rect(s["x0"] + 8, s["z0"] + 5, s["x0"] + 11, s["z0"] + 20, fill=CB["wood"])
    c.text(s["x0"] + 9.5, s["z0"] + 12.5, "till\ncounter", 5, rot=90)
    c.rect(s["x0"] + 0.6, s["z0"] + 4, s["x0"] + 2, s["z1"] - 4, fill=CB["rack"])
    c.text(s["x0"] + 1.3, s["z0"] + 1, "kit rail", 5, rot=90, anchor="l")
    for zc in (s["z0"] + 12, s["z0"] + 20):
        c.rect(s["x0"] + 4, zc - 1, s["x0"] + 12, zc + 1, fill=CB["rack"])
    c.text(s["x0"] + 8, s["z0"] + 24, "clothing rails", 5)
    c.rect(s["x1"] - 8, s["z0"] + 2, s["x1"] - 0.6, s["z0"] + 2.2, fill=CB["counter"])
    c.text((s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2 + 12, "SHOP UNIT\nbigger sign + window\n~20 parts", 6, bold=True)


def shop_L3(c):
    _shop_shell(c)
    s = SHOP_SHELL
    c.rect(s["x0"] + 0.6, s["z0"] + 3, s["x0"] + 2.6, s["z1"] - 3, fill=CB["kitwall"])
    c.text(s["x0"] + 1.6, s["z0"] + 0, "KIT WALL (numbered shirts)", 5, rot=90, anchor="l")
    c.rect(s["x0"] + 8, s["z0"] + 5, s["x0"] + 11, s["z0"] + 22, fill=CB["wood"])
    c.text(s["x0"] + 9.5, s["z0"] + 13.5, "till", 5, rot=90)
    for i, zc in enumerate((s["z0"] + 8, s["z0"] + 16, s["z0"] + 24)):
        c.rect(s["x0"] + 12, zc - 1, s["x0"] + 20, zc + 1, fill=CB["rack"])
    c.text(s["x0"] + 16, s["z0"] + 28, "3 aisles: leisurewear, scarves, kids'", 5)
    c.text((s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2 - 12, "MEGASTORE\n~45 parts", 6, bold=True)


def shop_L4(c):
    _shop_shell(c)
    s = SHOP_SHELL
    c.rect(s["x0"] + 0.6, s["z0"] + 3, s["x0"] + 2.6, s["z1"] - 3, fill=CB["kitwall"])
    c.rect(s["x0"] + 0.6, s["z0"] + 3, s["x0"] + 2.6, s["z0"] + 6, fill=CB["screen"])
    c.text(s["x0"] + 1.6, s["z0"] + 0, "KIT WALL + digital screen", 5, rot=90, anchor="l")
    c.rect(s["x0"] + 8, s["z0"] + 4, s["x0"] + 11, s["z0"] + 12, fill=CB["wood"])
    c.rect(s["x0"] + 8, s["z0"] + 18, s["x0"] + 11, s["z0"] + 26, fill=CB["wood"])
    c.text(s["x0"] + 9.5, s["z0"] + 8, "till 1", 5, rot=90)
    c.text(s["x0"] + 9.5, s["z0"] + 22, "till 2", 5, rot=90)
    for i, zc in enumerate((s["z0"] + 6, s["z0"] + 14, s["z0"] + 22, s["z0"] + 28)):
        c.rect(s["x0"] + 12, zc - 1, s["x0"] + 20, zc + 1, fill=CB["rack"])
    c.rect(s["x1"] - 5, s["z0"] + 24, s["x1"] - 1, s["z1"] - 1, fill="#d8c98a", stroke=CB["wall"], sw=0.6)
    c.text(s["x1"] - 3, s["z1"] - 3, "trophy\ncabinet", 4)
    c.text((s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2 - 12, "FLAGSHIP STORE\nmannequins in window\n~65 parts", 6, bold=True)


plan("clubshop_L1", SHOP_SHELL, 10, "CLUB SHOP -- L1 Kiosk", "exists today (PlotGrounds.buildShop)", shop_L1)
plan("clubshop_L2", SHOP_SHELL, 10, "CLUB SHOP -- L2 Shop Unit", "TEMP GBP3,500", shop_L2)
plan("clubshop_L3", SHOP_SHELL, 10, "CLUB SHOP -- L3 Megastore", "TEMP GBP10,000, kit wall", shop_L3)
plan("clubshop_L4", SHOP_SHELL, 10, "CLUB SHOP -- L4 Flagship Store", "TEMP GBP24,000", shop_L4)


# ===================================================================== ACADEMY
# Reserved footprint from the ground plan spec (S5): x 342..376, z -60..60 --
# not the current code's youth hut, which sits outside this reserved slot at
# ACADEMY_CX/CZ = 348,90 (PlotGrounds.luau, next to training pitch 2). Treating
# the reserved slot as the fixed top-level shell from L1 (decision 5) means the
# hut needs to move here when the track is implemented -- flagged as Q3 below.
# Seen through the training fence, not walked into (decision 4).
ACADEMY_SHELL = dict(x0=342, x1=376, z0=-60, z1=60)


def _academy_shell(c):
    s = ACADEMY_SHELL
    c.rect(s["x0"], s["z0"], s["x1"], s["z1"], stroke=CB["fence"], sw=1, dash="3,2")
    c.text(s["x0"] - 3, s["z0"] - 2, "reserved academy plot (34 x 120)", 5, anchor="l")


def academy_L1(c):
    _academy_shell(c)
    s = ACADEMY_SHELL
    hx0, hx1, hz0, hz1 = s["x0"] + 2, s["x0"] + 16, s["z1"] - 20, s["z1"] - 2
    c.rect(hx0, hz0, hx1, hz1, fill=CB["building"], stroke=CB["wall"], sw=1)
    c.text((hx0 + hx1) / 2, hz0 - 3, "youth hut 14x10\n(today's, moved here)", 5)
    c.rect(hx0 - 1.5, hz0 + 1, hx0 - 0.3, hz1 - 1, fill="#28503c")
    c.text(hx0 - 3, (hz0 + hz1) / 2, "intake\nboard", 4, anchor="r")
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 20, "rest of plot: grass, for sale", 6, fill="#2d5a1e")


def academy_L2(c):
    _academy_shell(c)
    s = ACADEMY_SHELL
    hx0, hx1, hz0, hz1 = s["x0"] + 2, s["x1"] - 2, s["z1"] - 34, s["z1"] - 2
    c.rect(hx0, hz0, hx1, hz1, fill=CB["building"], stroke=CB["wall"], sw=1)
    c.text((hx0 + hx1) / 2, hz0 - 3, "youth centre: hut + classroom", 5)
    c.rect(s["x0"] + 6, s["z0"] + 4, s["x1"] - 6, hz0 - 6, fill=CB["turfgreen"], stroke=CB["turfline"], sw=0.8)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 20, "five-a-side marking", 5, fill="#e8f5e2")


def academy_L3(c):
    _academy_shell(c)
    s = ACADEMY_SHELL
    hx0, hx1, hz0, hz1 = s["x0"] + 2, s["x1"] - 2, s["z1"] - 46, s["z1"] - 2
    c.rect(hx0, hz0, hx1, hz1, fill=CB["building"], stroke=CB["wall"], sw=1)
    c.text((hx0 + hx1) / 2, hz0 - 3, "academy building: classrooms + coach's office", 5)
    c.rect(s["x0"] + 4, s["z0"] + 4, s["x1"] - 4, hz0 - 4, fill=CB["turfgreen"], stroke=CB["turfline"], sw=0.8)
    c.rect(s["x0"] + 20, s["z0"] + 16, s["x1"] - 20, hz0 - 16, stroke=CB["turfline"], sw=0.8)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 24, "mini pitch (marked)", 5, fill="#e8f5e2")


def academy_L4(c):
    s = ACADEMY_SHELL
    c.rect(s["x0"], s["z0"], s["x1"], s["z1"], fill=CB["building"], stroke=CB["wall"], sw=1.5)
    c.rect(s["x0"] + 4, s["z0"] + 40, s["x1"] - 4, s["z1"] - 4, fill=CB["turfgreen"], stroke=CB["turfline"], sw=0.8)
    c.rect(s["x0"] + 12, s["z0"] + 48, s["x1"] - 12, s["z1"] - 12, stroke=CB["turfline"], sw=0.8)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 24, "classrooms - dorms - gym", 5, fill="#fff")
    c.text((s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2 + 10, "full-size mini pitch (marked)", 5, fill="#e8f5e2")


plan("academy_L1", ACADEMY_SHELL, 10, "ACADEMY -- L1 Youth Hut", "exists today, relocated onto this plot (see Q3)", academy_L1, built=False)
plan("academy_L2", ACADEMY_SHELL, 10, "ACADEMY -- L2 Youth Centre", "TEMP GBP4,000", academy_L2, built=False)
plan("academy_L3", ACADEMY_SHELL, 10, "ACADEMY -- L3 Academy Building", "TEMP GBP12,000, ground tier 3", academy_L3, built=False)
plan("academy_L4", ACADEMY_SHELL, 10, "ACADEMY -- L4 Elite Academy", "TEMP GBP28,000", academy_L4, built=True)


# ====================================================================== OFFICE
# Clubhouse.luau: Clubhouse.ROOMS.Office, x -156..-122, z 16.4..39 -- one fixed
# room at every level (it already is: WorldBuilder.dressOffice re-skins it for
# free on promotion today; decision 1 turns that into a bought track and keeps
# the top levels also needing a higher division). Layout below matches
# buildOffice as built: lobby door (north wall, west end), side/spawn door
# (south wall, west end), window (west wall), desk+chair at the east end,
# fixtures notice on the east wall, trophy shelf on the north wall.
OFFICE_SHELL = dict(x0=-156, x1=-122, z0=16.4, z1=39)


def _office_base(c, painted):
    s = OFFICE_SHELL
    wall = "#e2ded2" if painted else "#aaa087"
    c.rect(s["x0"], s["z0"], s["x1"], s["z1"], fill=wall, stroke=CB["wall"], sw=1.5)
    door(c, s["x0"] + 2, s["x0"] + 7, s["z0"] - 0.6, s["z0"] + 0.6)          # OfficeLobbyDoor (north)
    c.text(s["x0"] + 4.5, s["z0"] - 3, "to lobby", 5)
    door(c, s["x0"] + 1, s["x0"] + 6, s["z1"] - 0.6, s["z1"] + 0.6)          # OfficeSideDoor (south, spawn)
    c.text(s["x0"] + 3.5, s["z1"] + 3, "side door (spawn)", 5)
    c.rect(s["x0"] - 0.6, s["z0"] + 7.6, s["x0"] + 0.6, s["z0"] + 17.6, fill=CB["glass"])  # window (west)
    c.text(s["x0"] - 3, s["z0"] + 12.6, "window", 5, anchor="r")
    # desk + chair, east end (P5 #24b/#24e): desk at east-6, chair between it and the wall
    deskZ = (s["z0"] + s["z1"]) / 2
    c.rect(s["x1"] - 7.5, deskZ - 2.75, s["x1"] - 4.5, deskZ + 2.75, fill=CB["wood"])
    c.text(s["x1"] - 6, deskZ - 4, "desk + laptop", 5)
    c.circle(s["x1"] - 2.8, deskZ, 1.2, fill=CB["bench"])
    c.text(s["x1"] - 2.8, deskZ + 3, "chair", 4)
    c.rect(s["x1"] - 0.4, s["z0"] + 9, s["x1"], s["z0"] + 15, fill="#ece4c8")  # fixtures notice, east wall
    c.text(s["x1"] - 3, s["z0"] + 7, "fixtures\nnotice", 4, anchor="r")


def office_L1(c):
    _office_base(c, painted=False)
    s = OFFICE_SHELL
    c.text((s["x0"] + s["x1"]) / 2, s["z1"] - 3, "damp stains - dim light - green-screen terminal", 5)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 3, "RUNDOWN OFFICE", 6, bold=True)


def office_L2(c):
    _office_base(c, painted=True)
    s = OFFICE_SHELL
    c.text((s["x0"] + s["x1"]) / 2, s["z1"] - 3, "walls painted - notice board tidied", 5)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 3, "PAINTED OFFICE", 6, bold=True)


def office_L3(c):
    _office_base(c, painted=True)
    s = OFFICE_SHELL
    c.rect(s["x0"] + 3, s["z0"] + 2, s["x0"] + 9, s["z0"] + 6, fill="#8a6a48", stroke=CB["wall"], sw=0.6)
    c.text(s["x0"] + 6, s["z0"] - 1, "rug", 4)
    c.text((s["x0"] + s["x1"]) / 2, s["z1"] - 3, "flat-screen computer - brighter light", 5)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 3, "MODERN OFFICE", 6, bold=True)


def office_L4(c):
    _office_base(c, painted=True)
    s = OFFICE_SHELL
    c.rect(s["x0"] + 3, s["z0"] + 2, s["x0"] + 9, s["z0"] + 6, fill="#8a6a48", stroke=CB["wall"], sw=0.6)
    c.rect(s["x0"] + 11, s["z0"] + 0.6, s["x0"] + 22, s["z0"] + 2.2, fill="#c9a94a")  # trophy shelf, north wall
    c.text(s["x0"] + 16, s["z0"] - 2, "trophy shelf", 4)
    c.text((s["x0"] + s["x1"]) / 2, s["z1"] - 3, "flat-screen computer - branded lighting + crest", 5)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 3, "BRANDED OFFICE", 6, bold=True)


plan("office_L1", OFFICE_SHELL, 8, "OFFICE -- L1 Rundown", "exists today (tier 1 look)", office_L1)
plan("office_L2", OFFICE_SHELL, 8, "OFFICE -- L2 Painted", "TEMP GBP1,000", office_L2)
plan("office_L3", OFFICE_SHELL, 8, "OFFICE -- L3 Modern", "TEMP GBP5,000, division 2+", office_L3)
plan("office_L4", OFFICE_SHELL, 8, "OFFICE -- L4 Branded", "TEMP GBP15,000, division 1", office_L4)


# ===================================================== COACH'S CABIN / ATHLETIC CENTRE
# Ground plan spec S5's own table already gives the per-level content; the
# fixed shell (decision 5) is the athletic centre's full footprint, x 240..320,
# z -16..16 (80 x 32), matching tools/ground_plan.py's `proposed_common`. The
# cabin (L2) is a small building inside that shell, not a separate site.
GYM_SHELL = dict(x0=240, x1=320, z0=-16, z1=16)


def gym_L1(c):
    s = GYM_SHELL
    c.text((s["x0"] + s["x1"]) / 2, (s["z0"] + s["z1"]) / 2, "nothing yet -- for sale", 6, fill="#2d5a1e")


def gym_L2(c):
    s = GYM_SHELL
    cx, cz = 280, 0
    c.rect(cx - 8, cz - 5, cx + 8, cz + 5, fill=CB["building"], stroke=CB["wall"], sw=1)
    door(c, cx - 1, cx + 1, cz + 4.4, cz + 5)
    c.text(cx, cz - 7, "COACH'S CABIN 16x10", 5, bold=True)
    c.text(cx, cz + 8, "unlocks hiring a coach", 5)
    c.text((s["x0"] + s["x1"]) / 2, s["z0"] + 4, "rest of plot: for sale", 6, fill="#2d5a1e")


def _gym_shell(c, extra_label):
    s = GYM_SHELL
    c.rect(s["x0"], s["z0"], s["x1"], s["z1"], fill=CB["building"], stroke=CB["wall"], sw=1.5)
    door(c, 279, 281, s["z1"] - 0.5, s["z1"] + 0.5)
    c.text(280, s["z1"] + 3, "training-ground door", 5)
    mid = (s["x0"] + s["x1"]) / 2
    c.line([(mid, s["z0"]), (mid, s["z1"])], CB["wall"], 1)
    c.text(mid - 20, 0, "COACH'S OFFICE", 6, bold=True, fill="#fff")
    c.text(mid + 20, 0, "GYM" + extra_label, 6, bold=True, fill="#fff")


def gym_L3(c):
    _gym_shell(c, "")
    c.text(280, -12, "ATHLETIC CENTRE 80x32 -- training bonus", 5, fill="#fff")


def gym_L4(c):
    _gym_shell(c, " + PHYSIO")
    c.rect(GYM_SHELL["x1"] - 18, -6, GYM_SHELL["x1"] - 2, 6, fill="#ef9a9a", stroke=CB["wall"], sw=0.6)
    c.text(GYM_SHELL["x1"] - 10, 0, "physio", 4)
    c.text(280, -12, "+ physio -- injury recovery bonus", 5, fill="#fff")


plan("coachcabin_L1", GYM_SHELL, 10, "COACH'S CABIN -- L1 (nothing)", "for-sale outline only", gym_L1, built=False)
plan("coachcabin_L2", GYM_SHELL, 10, "COACH'S CABIN -- L2 Cabin", "TEMP GBP2,500", gym_L2, built=False)
plan("athleticcentre_L3", GYM_SHELL, 10, "ATHLETIC CENTRE -- L3", "TEMP GBP9,000, training pitch 1", gym_L3)
plan("athleticcentre_L4", GYM_SHELL, 10, "ATHLETIC CENTRE -- L4 + Physio", "TEMP GBP20,000, training pitch 2", gym_L4)


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
