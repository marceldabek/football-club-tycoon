"""Merged unit meshes for the town's blocks of flats and the backs of its shop parades.

Why (playtest 2026-09-21, #30 / #32): a block of flats was ~25 separate MEH modules, and every
module showed as its own panel from a distance (the atlas-mip seam the houses had, see
make_house_units.py); its back and ends were blank brick. A parade's back and ends were blank too.
Here each block becomes three meshes and each parade back one or two, laid out with windows on
every side and the brick on the tileable HouseBrick / HouseSlate looks the houses already use:

    HOUSE__flats_<v>__masonry / __roof / __trim     a whole 6 x 3 module, four-storey block
    HOUSE__parade_n<N>_s<S>__masonry / __trim       back wall and both ends of an N-module,
                                                   S-storey parade (its front and roof stay
                                                   module by module: they vary per lot)

The layouts live HERE (this file is their source of truth); src/shared/TradeUnits.luau is
generated from them. In a place whose kit does not hold the merged meshes TradeRecipes builds its
older module-by-module block (blank back and ends) instead.

Same frame as TradeRecipes / HouseRecipes: +X along the street, -Z to the street, Y up, a piece's
position is its bounding-box bottom centre, yaw 0 = exterior faces -Z. Unit origin = the centre
of the body's footprint at ground level. Every wall piece is placed by its brick face (measured
from the GLB), so the faces meet on the grid lines with no step.

    python tools/kit/make_trade_units.py            # GLBs, upload list, TradeUnits.luau
    python tools/upload_kit.py --user 74667306 --list assets/kit/_export/upload_trade_units.txt --ids assets/kit/_export/asset_ids_trade_units.json
    python tools/kit/make_trade_units.py            # again: writes the asset ids
    then run tools/kit/install_house_units.luau in Studio (Edit mode); it installs both tables.

Inputs are the MEH piece GLBs in assets/kit/_export/glb (see make_house_units.py).
"""
import json, os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_house_units as mh  # noqa: E402

M = mh.M
OUT_LUAU = os.path.join(mh.ROOT, "src", "shared", "TradeUnits.luau")
UNIT_IDS = os.path.join(mh.EXPORT, "asset_ids_trade_units.json")

# Parade sizes the town builds (TradeRecipes.parade: n = lot width / module, storeys 2 or 3),
# measured from TownFrontage 2026-09-23. A size missing here falls back to blank modules.
PARADES = [(2, 2), (2, 3), (5, 2), (5, 3), (8, 2), (8, 3), (11, 2), (11, 3), (15, 2), (15, 3)]

_plane = {}


def brick_z(name):
    """Local z of the piece's exterior brick face (exterior looks down -Z)."""
    if name not in _plane:
        pos, nrm, uv = mh.load_piece(name)
        brick, _ = mh.classify(uv)
        m = brick & (nrm.mean(1)[:, 2] < -0.5)
        _plane[name] = float(np.median(pos[m][:, :, 2])) if m.any() else 0.0
    return _plane[name]


def piece(name, x, y, z, yaw, role):
    return {"piece": name, "x": x, "y": y, "z": z, "yaw": yaw, "role": role, "scale": 1.0, "stretchX": 1.0, "once": False, "shiftX": 0.0}


def face(side, W, D):
    """(yaw, length, at(along) -> (x, z) of the face line, outward normal) of a W x D body.
    `along` runs from the face's left end as seen from outside, like TradeRecipes.faceOf."""
    if side == "front":
        return 0, W, (lambda a: (W / 2 - a, -D / 2)), (0.0, -1.0)
    if side == "back":
        return 180, W, (lambda a: (-W / 2 + a, D / 2)), (0.0, 1.0)
    if side == "left":
        return 90, D, (lambda a: (-W / 2, -D / 2 + a)), (-1.0, 0.0)
    return -90, D, (lambda a: (W / 2, D / 2 - a)), (1.0, 0.0)


WIDTH = {"Wall_WindowCentre_B": 2, "Wall_WideDoor_A": 2}


def run(out, side, W, D, storey, names, role):
    """Lays wall pieces left to right along one face at one storey, brick face on the line."""
    yaw, _, at, n = face(side, W, D)
    a = 0.0
    for name in names:
        w = WIDTH.get(name, 1) * M
        x, z = at(a + w / 2)
        zb = brick_z(name)
        out.append(piece(name, x + n[0] * zb, storey * M, z + n[1] * zb, yaw, role))
        a += w


FLATS = {
    # front ground, front upper, back ground, back upper, end walls (every storey)
    "a": (["Wall_WindowCentre_B", "Wall_WideDoor_A", "Wall_WindowCentre_B"],
          ["Wall_WindowCentre_B", "Wall_Window_C", "Wall_WindowCentre_B", "Wall_Window_C"],
          ["Wall_Window_D"] * 6,
          ["Wall_Window_C"] * 6,
          ["Wall_Window_C", "Wall_A", "Wall_Window_C"]),
    "b": (["Wall_WindowCentre_B", "Wall_WideDoor_A", "Wall_WindowCentre_B"],
          ["Wall_Window_B", "Wall_WindowCentre_B", "Wall_WindowCentre_B", "Wall_Window_B"],
          ["Wall_Window_D", "Wall_Window_A", "Wall_Window_D", "Wall_Window_D", "Wall_Window_A", "Wall_Window_D"],
          ["Wall_Window_B"] * 6,
          ["Wall_A", "Wall_Window_B", "Wall_A"]),
}
FLATS_STOREYS = 4


def flats(variant):
    fg, fu, bg, bu, ends = FLATS[variant]
    W, D = 6 * M, 3 * M
    out = []
    for s in range(FLATS_STOREYS):
        run(out, "front", W, D, s, fg if s == 0 else fu, "front")
        run(out, "back", W, D, s, bg if s == 0 else bu, "back")
        run(out, "left", W, D, s, ends, "side")
        run(out, "right", W, D, s, ends, "side")
    top = FLATS_STOREYS * M
    for i in range(6):
        for j in range(3):
            out.append(piece("Roof_Flat_A", -W / 2 + (i + 0.5) * M, top, -D / 2 + (j + 0.5) * M, 0, "roof"))
    out.append(piece("Door_Canopy_A", 0.0, 4.6, -D / 2 - 1.1, 0, "canopy"))
    return out, (W, top, D)


def parade(n, storeys):
    """Back wall and both ends of a parade; TradeRecipes builds its front and roof."""
    W, D = n * M, 2 * M
    out = []
    for s in range(storeys):
        if s == 0:
            back = ["Wall_Window_D" if i % 3 == 1 else "Wall_A" for i in range(n)]
            ends = ["Wall_A", "Wall_A"]
        else:
            back = ["Wall_Window_B" if i % 3 == 1 else "Wall_Window_C" for i in range(n)]
            ends = ["Wall_Window_C", "Wall_Window_C"]
        run(out, "back", W, D, s, back, "back")
        run(out, "left", W, D, s, ends, "side")
        run(out, "right", W, D, s, ends, "side")
    return out, (W, storeys * M, D)


def main():
    units = [("flats_" + v, *flats(v)) for v in sorted(FLATS)]
    units += [("parade_n%d_s%d" % (n, s), *parade(n, s)) for n, s in PARADES]
    ids = json.load(open(UNIT_IDS)) if os.path.exists(UNIT_IDS) else {}
    glbs, tris_total = [], 0
    lines = [
        "--!strict",
        "-- GENERATED by tools/kit/make_trade_units.py -- do not edit by hand (the layouts live there).",
        "-- Merged meshes for blocks of flats and the backs and ends of shop parades (#30, #32).",
        "-- Frame as TradeRecipes: origin = the body's footprint centre at ground level, +X along",
        "-- the street, -Z to the street. `offset` is a mesh's bounding-box bottom centre (where",
        "-- KitPlacer puts it), `body` the walls' W x H x D.",
        "local TradeUnits = {}",
        "",
        "export type UnitMesh = { layer: string, name: string, assetId: number, offset: Vector3, size: Vector3 }",
        "export type Unit = { body: Vector3, meshes: { UnitMesh } }",
        "",
        "TradeUnits.UNITS = {",
    ]
    for key, pieces, body in units:
        meshes = mh.build_unit(pieces)
        lines.append("\t%s = {" % key)
        lines.append("\t\tbody = %s," % mh.luau_vec(body))
        lines.append("\t\tmeshes = {")
        summary = []
        for layer in mh.LAYERS:
            if layer not in meshes:
                continue
            pos, nrm, uv = meshes[layer]
            name = "HOUSE__%s__%s" % (key, layer)
            tris = mh.write_glb(os.path.join(mh.GLB_DIR, name + ".glb"), pos, nrm, uv, "house_" + layer)
            tris_total += tris
            glbs.append(name + ".glb")
            mn, mx = pos.min(0), pos.max(0)
            bottom = ((mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2)
            asset = int(ids.get(name + ".glb", {}).get("assetId") or 0)
            lines.append('\t\t\t{ layer = "%s", name = "%s", assetId = %d, offset = %s, size = %s },' % (layer, name, asset, mh.luau_vec(bottom), mh.luau_vec(mx - mn)))
            summary.append("%s %d tris" % (layer, tris))
        lines.append("\t\t},")
        lines.append("\t},")
        print("%-18s %3d modules  %s" % (key, len(pieces), "  ".join(summary)))
    lines += ["} :: { [string]: Unit }", "", "return TradeUnits", ""]
    with open(OUT_LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    with open(os.path.join(mh.EXPORT, "upload_trade_units.txt"), "w") as f:
        f.write("# GLBs in assets/kit/_export/glb/ from tools/kit/make_trade_units.py\n" + "\n".join(glbs) + "\n")
    print("%d units, %d GLBs, %d triangles" % (len(units), len(glbs), tris_total))


if __name__ == "__main__":
    main()
