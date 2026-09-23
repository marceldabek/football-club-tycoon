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
