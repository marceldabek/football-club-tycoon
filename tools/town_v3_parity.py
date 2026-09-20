"""Parity between the two copies of the Rivermere v3 frontage generator.

    python tools/town_v3_parity.py            # print the Python digest, check the pinned one
    python tools/town_v3_parity.py --write    # pin the Python digest into the Luau test

src/shared/TownFrontage.luau is the source of truth; tools/town_plan_v3.py mirrors it so
the town can be drawn without Studio. There is no local Luau runtime, so the check is in
two halves that meet in tests/TownFrontageTest.luau:

  1. this script runs the PYTHON generator and pins its digest (lots per use, lots per
     district, a position sum and an id sum) between the PARITY markers in the test;
  2. T.matchesThePythonDrawing runs the LUAU generator in Studio and asserts the same digest.

So after changing either generator: mirror the change in the other, run --write, run
TownFrontageTest in Studio. Without --write this exits 1 if the pinned digest is stale.
It also runs tools/town_v3_emit.py --check, so stale ROADS/PLOTS are caught here too.
"""

import math
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import town_map  # noqa: E402
import town_plan_v3 as v3  # noqa: E402

TEST = v3.ROOT / "tests" / "TownFrontageTest.luau"


def lots():
    town = v3.Town(town_map.parse())
    town.carry_over()
    town.head_rows()
    town.frontage()
    seen, out = {}, []
    for district, b in town.rows:
        n = seen[b["key"]] = seen.get(b["key"], 0) + 1
        out.append({"id": f'{b["key"]}|{n}', "use": b["use"], "district": district, "centre": b["centre"]})
    return out


def digest(rows):
    by_use, by_district = {}, {}
    pos = ids = 0
    for lot in rows:
        by_use[lot["use"]] = by_use.get(lot["use"], 0) + 1
        by_district[lot["district"]] = by_district.get(lot["district"], 0) + 1
        pos += math.floor(lot["centre"][0] + 0.5) + 3 * math.floor(lot["centre"][1] + 0.5)
        ids += sum(lot["id"].encode("ascii"))
    return {"total": len(rows), "byUse": by_use, "byDistrict": by_district, "positionSum": pos, "idSum": ids}


def luau(d):
    def table(m):
        return "{ " + ", ".join(f'["{k}"] = {v}' for k, v in sorted(m.items())) + " }"
    return ("local PARITY = {\n"
            f"\ttotal = {d['total']},\n"
            f"\tbyUse = {table(d['byUse'])},\n"
            f"\tbyDistrict = {table(d['byDistrict'])},\n"
            f"\tpositionSum = {d['positionSum']},\n"
            f"\tidSum = {d['idSum']},\n"
            "}\n")


def main():
    d = digest(lots())
    print(f"Python generator: {d['total']} lots")
    for title, m in (("use", d["byUse"]), ("district", d["byDistrict"])):
        print(f"  by {title}: " + ", ".join(f"{k} {v}" for k, v in sorted(m.items(), key=lambda kv: -kv[1])))
    print(f"  positionSum {d['positionSum']}, idSum {d['idSum']}")

    src = TEST.read_text(encoding="utf-8")
    m = re.search(r"(-- PARITY-BEGIN[^\n]*\n)(.*?)(-- PARITY-END)", src, re.S)
    assert m, "no PARITY markers in " + str(TEST)
    want = luau(d)
    stale = m.group(2) != want
    if "--write" in sys.argv:
        if stale:
            TEST.write_text(src[:m.start(2)] + want + src[m.end(2):], encoding="utf-8", newline="\n")
        print("pinned digest " + ("UPDATED: now run TownFrontageTest in Studio" if stale else "already current"))
        stale = False
    elif stale:
        print("pinned digest in tests/TownFrontageTest.luau is STALE: run with --write, then the Studio test")
    else:
        print("pinned digest is current")
    emit = subprocess.run([sys.executable, str(Path(__file__).with_name("town_v3_emit.py")), "--check"])
    sys.exit(1 if stale or emit.returncode else 0)


if __name__ == "__main__":
    main()
