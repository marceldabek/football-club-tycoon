"""Merge the Modular English Housing pieces of every house recipe into whole-unit meshes.

Why: a house built from 8 separate kit modules showed every module as its own panel from a
distance. All modules map their brick to one quadrant of the trim-sheet atlas, so mipmaps bleed
the dark slate next to it into every module edge; and row-long back walls and roofs were one
quad stretched six times. Here each unit becomes three meshes:

    HOUSE__<unit>__masonry   every brick face, UVs remapped onto a standalone TILEABLE brick
                             texture (the atlas quadrant cropped out), so a wrap lands on brick
    HOUSE__<unit>__roof      the slates of the two roof slopes, same idea with the slate quadrant
    HOUSE__<unit>__trim      everything else (frames, glass, doors, fascia, chimney pots), still
                             on the kit trim sheet exactly as before

Scaled and stretched pieces (the double-scale back wall, the roof stretched over two modules)
get their masonry / slate UVs multiplied instead, so bricks and slates keep their size.

Source of truth is src/shared/HouseRecipes.luau: the recipe lines are parsed from it, nothing is
typed twice. tests/HouseUnitsTest.luau compares the signature written here with the live recipes
and fails when a recipe changed without re-running this script.

Pure Python + numpy + Pillow (the kit GLBs are tiny untextured meshes; Blender is not needed).

    python tools/kit/make_house_units.py            # GLBs, textures, upload lists, HouseUnits.luau
    python tools/upload_kit.py --user 74667306 --list assets/kit/_export/upload_house_units.txt --ids assets/kit/_export/asset_ids_house_units.json
    python tools/upload_kit.py --user 74667306 --images assets/kit/_export/upload_house_textures.txt --ids assets/kit/_export/asset_ids_house_textures.json
    python tools/kit/make_house_units.py            # again: writes the new asset ids into HouseUnits.luau
    then run tools/kit/install_house_units.luau in Studio (Edit mode)

Frames: recipe space is the Roblox one (+X along the street, -Z to the street, Y up). The glTF
importer turns a GLB half a turn about Y (Roblox x = -GLB x, z = -GLB z), checked against the
Wall_Door_B doorway in Studio 2026-09-21, so pieces are flipped on the way in and units on the
way out.
"""
import json, math, os, re, struct, sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXPORT = os.path.join(ROOT, "assets", "kit", "_export")
GLB_DIR = os.path.join(EXPORT, "glb")
TEX_DIR = os.path.join(EXPORT, "textures")
TEXCACHE = os.path.join(EXPORT, "texcache", "2k")
RECIPES = os.path.join(ROOT, "src", "shared", "HouseRecipes.luau")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "HouseUnits.luau")
UNIT_IDS = os.path.join(EXPORT, "asset_ids_house_units.json")
TEX_IDS = os.path.join(EXPORT, "asset_ids_house_textures.json")

M = 8.25
H = M / 2
TRIMS = (1, 3)  # HouseRecipes.TRIMS: ts1 dark brick, ts3 pale brick
LAYERS = ("masonry", "roof", "trim")


# ------------------------------------------------------------------ recipes, parsed from Luau

def parse_recipes():
    src = open(RECIPES, encoding="utf-8").read()

    def table(name):
        body = re.search(r"HouseRecipes\.%s = \{(.*?)\n\}" % name, src, re.S).group(1)
        return body

    brick_plane = {k: float(v) for k, v in re.findall(r"(\w+) = (-?[\d.]+),", table("BRICK_PLANE"))}
    door_opening = {k: float(v) for k, v in re.findall(r"(\w+) = \{ centre = (-?[\d.]+)", table("DOOR_OPENING"))}
    door_recess = float(re.search(r"HouseRecipes\.DOOR_RECESS = ([\d.]+)", src).group(1))

    def piece(name, x, y, z, yaw, role, scale=1.0, stretch=1.0, once=False):
        return {"piece": name, "x": x, "y": y, "z": z, "yaw": yaw, "role": role, "scale": scale, "stretchX": stretch, "once": once, "shiftX": 0.0}

    def front(name, x, storey):
        return piece(name, x, storey * M, -M + brick_plane.get(name, 0.0), 0, "front")

    def door(name, x):
        return piece(name, x, 0, -M + door_recess, 0, "door")

    def canopy(name, x):
        return piece(name, x, 5.0, -M - 0.705, 0, "canopy")

    def chimney(x, once=False):
        return piece("Chimney_A", x, 2 * M + 4.2, 0, 0, "chimney", scale=1.4, once=once)

    def shell():
        return [
            piece("Wall_A", 0, 0, M, 180, "back", scale=2),
            piece("Roof_A", 0, 2 * M, -H - 0.17, 0, "roof", stretch=2),
            piece("Roof_A", 0, 2 * M, H + 0.17, 180, "roof", stretch=2),
        ]

    def end_cap(side, windowed):
        yaw = 90 if side < 0 else -90
        out = [piece("Roof_Wall_Full_A", side * M, 2 * M, 0, yaw, "gable")]

        def side_wall(name, y, z):
            out.append(piece(name, side * (M - brick_plane.get(name, 0.0)), y, z, yaw, "side"))

        if windowed:
            side_wall("Wall_Window_B", 0, -H)
            side_wall("Wall_A", 0, H)
            side_wall("Wall_Window_C", M, -H)
            side_wall("Wall_A", M, H)
        else:
            out.append(piece("Wall_A", side * M, 0, 0, yaw, "side", scale=2))
        return out

    recipes = []

    def recipe(rid, kind, door_x, fronts, extras=None, ends=False):
        pieces = list(fronts) + shell() + list(extras or [])
        shift = 0.0
        for p in pieces:
            if p["role"] == "front" and p["piece"] in door_opening:
                shift = door_opening[p["piece"]]
        if shift:
            for p in pieces:
                if p["role"] in ("door", "canopy"):
                    p["x"] += shift
                    p["shiftX"] = shift
        if ends:
            pieces += end_cap(-1, True) + end_cap(1, False)
        recipes.append({"id": rid, "kind": kind, "pieces": pieces})

    env = {"front": front, "door": door, "canopy": canopy, "chimney": chimney, "recipe": recipe, "H": H, "true": True, "false": False}
    lines = re.findall(r"^\trecipe\(.*\),\s*$", src, re.M)
    assert len(lines) >= 18, "expected the recipe lines in HouseRecipes.luau, found %d" % len(lines)
    for line in lines:
        eval(line.strip().rstrip(",").replace("{", "[").replace("}", "]"), env)

    def mirrored(pieces):
        out = []
        for p in pieces:
            if p["once"]:
                continue
            q = dict(p)
            q["x"] = p["shiftX"] - (p["x"] - p["shiftX"])
            q["yaw"] = -p["yaw"]
            out.append(q)
        return out

    units = []
    for r in recipes:
        units.append((r["id"], r["pieces"]))
        if r["kind"] == "semi":
            units.append((r["id"] + "_m", mirrored(r["pieces"])))
    for side, sname in ((-1, "left"), (1, "right")):
        for windowed, wname in ((False, "plain"), (True, "win")):
            units.append(("cap_%s_%s" % (wname, sname), end_cap(side, windowed)))
    return units


def signature(pieces):
    """Mirrors HouseUnits signature in tests/HouseUnitsTest.luau: tenths of a stud, whole degrees."""
    def t(v):
        return int(math.floor(v * 10 + 0.5))
    parts = ["%s@%d,%d,%d,%d,%d,%d" % (p["piece"], t(p["x"]), t(p["y"]), t(p["z"]), int(round(p["yaw"])) % 360, t(p["scale"]), t(p["stretchX"])) for p in pieces]
    return "|".join(sorted(parts))


# ------------------------------------------------------------------ GLB in

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    js = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", d[off:off + 4])[0]
    blob = d[off + 8:off + 8 + bl]

    def acc(i):
        a = js["accessors"][i]
        bv = js["bufferViews"][a["bufferView"]]
        n = NC[a["type"]]
        dt = np.dtype(CT[a["componentType"]])
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", 0)
        if stride and stride != dt.itemsize * n:
            out = np.zeros((a["count"], n), dt)
            for k in range(a["count"]):
                out[k] = np.frombuffer(blob, dt, n, start + k * stride)
            return out
        return np.frombuffer(blob, dt, a["count"] * n, start).reshape(a["count"], n)

    pos, nrm, uv = [], [], []
    for node in js["nodes"]:
        assert not any(k in node for k in ("rotation", "scale", "translation", "matrix")), path + ": node transform"
        if "mesh" not in node:
            continue
        for prim in js["meshes"][node["mesh"]]["primitives"]:
            p = acc(prim["attributes"]["POSITION"]).astype(np.float64)
            n = acc(prim["attributes"]["NORMAL"]).astype(np.float64)
            t = acc(prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
            idx = acc(prim["indices"]).reshape(-1).astype(np.int64)
            pos.append(p[idx]); nrm.append(n[idx]); uv.append(t[idx])
    pos, nrm, uv = np.concatenate(pos), np.concatenate(nrm), np.concatenate(uv)
    return pos.reshape(-1, 3, 3), nrm.reshape(-1, 3, 3), uv.reshape(-1, 3, 2)


_piece_cache = {}


def load_piece(name):
    """Triangles of one kit piece in ROBLOX space, origin at its bounding-box bottom centre
    (which is how KitPlacer places it)."""
    if name not in _piece_cache:
        pos, nrm, uv = read_glb(os.path.join(GLB_DIR, "MEH__%s__ts1.glb" % name))
        flip = np.array([-1.0, 1.0, -1.0])
        pos, nrm = pos * flip, nrm * flip
        flat = pos.reshape(-1, 3)
        mn, mx = flat.min(0), flat.max(0)
        pos = pos - np.array([(mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2])
        _piece_cache[name] = (pos, nrm, uv)
    return _piece_cache[name]


# ------------------------------------------------------------------ merge

E = 1e-4


def classify(uv):
    lo, hi = uv.min(1), uv.max(1)
    brick = (lo[:, 0] >= -E) & (hi[:, 0] <= 0.5 + E) & (lo[:, 1] >= 0.5 - E) & (hi[:, 1] <= 1 + E)
    slate = (lo[:, 0] >= 0.5 - E) & (hi[:, 0] <= 1 + E) & (lo[:, 1] >= 0.5 - E) & (hi[:, 1] <= 1 + E)
    return brick, slate


def build_unit(pieces):
    layers = {k: ([], [], []) for k in LAYERS}
    for p in pieces:
        pos, nrm, uv = load_piece(p["piece"])
        k, m = p["scale"], p["stretchX"]
        pos = pos * np.array([k * m, k, k])
        nrm = nrm * np.array([1.0 / m, 1.0, 1.0])
        nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=2, keepdims=True), 1e-12)
        a = math.radians(p["yaw"])
        c, s = math.cos(a), math.sin(a)
        rot = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])  # CFrame.Angles(0, yaw, 0)
        pos = pos @ rot.T + np.array([p["x"], p["y"], p["z"]])
        nrm = nrm @ rot.T

        brick, slate = classify(uv)
        slate = slate & (p["role"] == "roof")  # bay roofs, canopies and gable verges stay on the trim sheet
        rest = ~(brick | slate)
        tile = np.array([k * m, k])
        b_uv = (uv - np.array([0.0, 0.5])) / 0.5 * tile
        s_uv = (uv - np.array([0.5, 0.5])) / 0.5 * tile
        for key, mask, tuv in (("masonry", brick, b_uv), ("roof", slate, s_uv), ("trim", rest, uv)):
            if mask.any():
                L = layers[key]
                L[0].append(pos[mask]); L[1].append(nrm[mask]); L[2].append(tuv[mask])
    out = {}
    for key, (P, N, T) in layers.items():
        if P:
            out[key] = (np.concatenate(P).reshape(-1, 3), np.concatenate(N).reshape(-1, 3), np.concatenate(T).reshape(-1, 2))
    return out


# ------------------------------------------------------------------ GLB out

def write_glb(path, pos, nrm, uv, material):
    flip = np.array([-1.0, 1.0, -1.0])
    verts = np.concatenate([pos * flip, nrm * flip, uv], axis=1).astype(np.float32)
    uniq, index = np.unique(np.round(verts, 5), axis=0, return_inverse=True)
    index = index.reshape(-1)
    P, N, T = uniq[:, 0:3].astype(np.float32), uniq[:, 3:6].astype(np.float32), uniq[:, 6:8].astype(np.float32)
    idt = np.uint16 if len(uniq) < 65535 else np.uint32
    chunks, views, offset = [], [], 0
    for arr, target in ((P, 34962), (N, 34962), (T, 34962), (index.astype(idt), 34963)):
        raw = arr.tobytes()
        pad = (-len(raw)) % 4
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(raw), "target": target})
        chunks.append(raw + b"\0" * pad)
        offset += len(raw) + pad
    js = {
        "asset": {"version": "2.0", "generator": "fct make_house_units"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": os.path.splitext(os.path.basename(path))[0]}],
        "materials": [{"name": material, "pbrMetallicRoughness": {"baseColorFactor": [0.8, 0.8, 0.8, 1], "metallicFactor": 0, "roughnessFactor": 0.8}}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "buffers": [{"byteLength": offset}],
        "bufferViews": views,
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(P), "type": "VEC3", "min": P.min(0).tolist(), "max": P.max(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(N), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(T), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123 if idt == np.uint16 else 5125, "count": len(index), "type": "SCALAR"},
        ],
    }
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * ((-len(jb)) % 4)
    blob = b"".join(chunks)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(blob)))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A)); f.write(jb)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(blob)
    return len(index) // 3


# ------------------------------------------------------------------ textures

def make_textures():
    from PIL import Image
    os.makedirs(TEX_DIR, exist_ok=True)
    names = []
    for ts in TRIMS:
        for m in "DNR":
            im = Image.open(os.path.join(TEXCACHE, "TrimSheet_0%d_%s.jpg" % (ts, m))).convert("RGB")
            w, h = im.size
            for region, box in (("brick", (0, h // 2, w // 2, h)), ("slate", (w // 2, h // 2, w, h))):
                name = "house_%s_ts%d_%s.png" % (region, ts, m)
                im.crop(box).resize((1024, 1024), Image.LANCZOS).save(os.path.join(TEX_DIR, name), optimize=True)
                names.append(name)
    return names


# ------------------------------------------------------------------ outputs

def luau_vec(v):
    return "Vector3.new(%.4f, %.4f, %.4f)" % (v[0], v[1], v[2])


def main():
    units = parse_recipes()
    glbs, entries, total_tris = [], [], 0
    for key, pieces in units:
        meshes = build_unit(pieces)
        rows = []
        for layer in LAYERS:
            if layer not in meshes:
                continue
            pos, nrm, uv = meshes[layer]
            name = "HOUSE__%s__%s" % (key, layer)
            tris = write_glb(os.path.join(GLB_DIR, name + ".glb"), pos, nrm, uv, "house_" + layer)
            total_tris += tris
            mn, mx = pos.min(0), pos.max(0)
            bottom = ((mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2)
            rows.append((layer, name, bottom, mx - mn, tris))
            glbs.append(name + ".glb")
        entries.append((key, signature(pieces), rows))
        print("%-20s %s" % (key, "  ".join("%s %d tris" % (r[0], r[4]) for r in rows)))

    with open(os.path.join(EXPORT, "upload_house_units.txt"), "w") as f:
        f.write("# GLBs in assets/kit/_export/glb/ from tools/kit/make_house_units.py\n" + "\n".join(glbs) + "\n")
    textures = make_textures()
    with open(os.path.join(EXPORT, "upload_house_textures.txt"), "w") as f:
        f.write("# PNGs in assets/kit/_export/textures/ from tools/kit/make_house_units.py\n" + "\n".join(textures) + "\n")

    unit_ids = json.load(open(UNIT_IDS)) if os.path.exists(UNIT_IDS) else {}
    tex_ids = json.load(open(TEX_IDS)) if os.path.exists(TEX_IDS) else {}
    lines = [
        "--!strict",
        "-- GENERATED by tools/kit/make_house_units.py -- do not edit by hand.",
        "-- Whole-unit house meshes merged from the MEH pieces of each Shared/HouseRecipes recipe.",
        "-- `offset` is the bounding-box bottom centre of the mesh in unscaled recipe space (where",
        "-- KitPlacer puts it), `signature` the recipe the mesh was built from: HouseUnitsTest fails",
        "-- when a recipe changes and this file was not regenerated. `assetId` (0 until uploaded) is",
        "-- what tools/kit/install_house_units.luau loads into ServerStorage.Kit.Meshes.",
        "local HouseUnits = {}",
        "",
        "export type UnitMesh = { layer: string, name: string, assetId: number, offset: Vector3, size: Vector3 }",
        "export type Unit = { signature: string, meshes: { UnitMesh } }",
        "",
        "HouseUnits.UNITS = {",
    ]
    for key, sig, rows in entries:
        lines.append("\t%s = {" % key)
        lines.append('\t\tsignature = "%s",' % sig)
        lines.append("\t\tmeshes = {")
        for layer, name, bottom, size, _ in rows:
            asset = int(unit_ids.get(name + ".glb", {}).get("assetId") or 0)
            lines.append('\t\t\t{ layer = "%s", name = "%s", assetId = %d, offset = %s, size = %s },' % (layer, name, asset, luau_vec(bottom), luau_vec(size)))
        lines.append("\t\t},")
        lines.append("\t},")
    lines += ["} :: { [string]: Unit }", "", "-- Kit.Appearances.<name>: colour, normal and roughness map ids of the tileable brick and slate.", "HouseUnits.LOOKS = {"]
    for ts in TRIMS:
        for region in ("brick", "slate"):
            ids = [int(tex_ids.get("house_%s_ts%d_%s.png" % (region, ts, m), {}).get("assetId") or 0) for m in "DNR"]
            lines.append("\tHouse%s_ts%d = { %d, %d, %d }," % (region.capitalize(), ts, ids[0], ids[1], ids[2]))
    lines += ["} :: { [string]: { number } }", "", "return HouseUnits", ""]
    with open(OUT_LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("%d units, %d GLBs, %d triangles, %d textures" % (len(entries), len(glbs), total_tris, len(textures)))


if __name__ == "__main__":
    main()
