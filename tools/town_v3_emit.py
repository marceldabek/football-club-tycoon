"""Emit the v3 tables of src/shared/TownLayout.luau from tools/town_plan_v3.py.

    python tools/town_v3_emit.py            # ROUNDABOUTS, PLOTS, ROADS and the plot BUS_STOPS
    python tools/town_v3_emit.py --check    # exit 1 if the Luau file would change

The Luau file is the source of truth for the game; this only saves hand-typing
94 roads. It rewrites whole tables between `TownLayout.NAME = {` and the closing
`} :: { Type }`, so comments inside those tables are not kept: put them in
town_plan_v3.py instead. DISTRICTS (the hand-placed specials) is NOT emitted:
it is edited by hand in the Luau file and the Python drawing reads it from there.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import town_plan_v3 as v3  # noqa: E402

LUAU = v3.ROOT / "src" / "shared" / "TownLayout.luau"


def num(v):
    v = float(v)
    return str(int(v)) if v == int(v) else repr(round(v, 3))


def vec(x, z, y=0):
    return f"Vector3.new({num(x)}, {num(y)}, {num(z)})"


def roundabouts():
    out = ["TownLayout.ROUNDABOUTS = {"]
    for name, x, z, rad in v3.ROUNDABOUTS:
        out.append(f'\t{{ name = "{name}", centre = {vec(x, z)}, radius = {num(rad)} }},')
    out.append("} :: { Roundabout }")
    return "\n".join(out)


def plots():
    out = ["TownLayout.PLOTS = {"]
    for i, p in enumerate(v3.PLOTS, 1):
        out += [f"\t{{ -- {p['note']}", f"\t\tindex = {i},", f'\t\tname = "{p["name"]}",',
                f"\t\tcentre = {vec(*p['centre'])},", f"\t\tyaw = {p['yaw']},",
                f"\t\tbusStop = {vec(*p['bus'])},", "\t},"]
    out.append("} :: { Plot }")
    return "\n".join(out)


def roads():
    out = ["TownLayout.ROADS = {"]
    for r in v3.roads():
        fields = [f'name = "{r["name"]}"', f'kind = "{r["kind"]}"', f"width = {num(r['width'])}",
                  f'front = "{r["front"]}"']
        if r["front"] != "none":
            if r["use_at"]:
                fields.append(f'useAt = "{r["use_at"]}"')
            else:
                fields.append(f'use = "{r["use"]}"')
        if r["district"]:
            fields.append(f'district = "{r["district"]}"')
        if r["head"]:
            fields.append("head = true")
        out.append("\t{")
        line = "\t\t"
        for f in fields:
            if len(line) + len(f) > 110:
                out.append(line.rstrip())
                line = "\t\t"
            line += f + ", "
        out.append(line.rstrip())
        pts = [vec(x, z) for x, z in r["points"]]
        out.append("\t\tpoints = {")
        for k in range(0, len(pts), 3):
            out.append("\t\t\t" + ", ".join(pts[k:k + 3]) + ",")
        out.append("\t\t},")
        out.append("\t},")
    out.append("} :: { Road }")
    return "\n".join(out)


def splice(src, name, typ, text):
    i = src.index(f"TownLayout.{name} = {{")
    end = f"}} :: {{ {typ} }}"
    j = src.index(end, i) + len(end)
    return src[:i] + text + src[j:]


def plot_stops(src):
    for p in v3.PLOTS:
        src, n = re.subn(r'\{ name = "%s", position = Vector3\.new\([^)]*\), yaw = -?\d+ \}' % p["name"],
                         f'{{ name = "{p["name"]}", position = {vec(*p["bus"])}, yaw = {p["bus_yaw"]} }}', src)
        assert n == 1, p["name"]
    return src


def main():
    old = LUAU.read_text(encoding="utf-8")
    new = splice(old, "ROUNDABOUTS", "Roundabout", roundabouts())
    new = splice(new, "PLOTS", "Plot", plots())
    new = splice(new, "ROADS", "Road", roads())
    new = plot_stops(new)
    if "--check" in sys.argv:
        print("TownLayout.luau matches town_plan_v3.py" if new == old else "TownLayout.luau is STALE")
        sys.exit(0 if new == old else 1)
    LUAU.write_text(new, encoding="utf-8", newline="\n")
    print(f"wrote {LUAU}: {len(v3.roads())} roads, {len(v3.PLOTS)} plots, {len(v3.ROUNDABOUTS)} roundabouts")


if __name__ == "__main__":
    main()
