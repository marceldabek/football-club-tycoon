import json
J = json.load(open(r"C:\Users\mdabe\AppData\Local\Temp\fct-research\inv\jobs_full.json"))
keep = []
for j in J["jobs"]:
    n = j["name"]
    if n.startswith("PH__"):
        keep.append(j)
    elif n in ("UKSP__GardenWall", "UKSP__GardenWallA", "UKSP__GardenWallB", "UKSP__BondaryWall", "UKSP__RailingWall", "UKSP__BusShelter", "UKSP__RedPhoneBoxes", "UKSP__Skips", "UKSP__dumpster"):
        j["max_tex"] = 1024
        keep.append(j)
J["jobs"] = keep
json.dump(J, open(r"C:\Users\mdabe\AppData\Local\Temp\fct-research\inv\jobs_fix.json", "w"), indent=1)
print(len(keep), "fix jobs")
