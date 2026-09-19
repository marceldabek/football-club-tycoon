import json
RAW = r"F:\dev\football-club-tycoon\assets\kit\_raw"
UK = RAW + r"\UKStreetProps\RoadTrafficProps"
J = {"studs_per_meter": 2.75, "out_dir": r"F:\dev\football-club-tycoon\assets\kit\_export\glb",
     "texcache": r"F:\dev\football-club-tycoon\assets\kit\_export\texcache",
     "uksp_tex_dir": UK,
     "material_overrides": {"ConcreteBareShader": "ConcreteWall", "MI_Concrete": "ConcreteWall", "PavingShader": "Sidewalk", "YellowLinesShader": "AsphaltYellow",
                            "DecalsShader1": "PhoneboxDecals", "GalvanizedMetalShader": "armcoBarrier", "phong1": "CardBoxes", "WoodShader": "WoodFence", "TrashCanMetalShader": "TrashCan",
                            "CrowdBarrierNewShader": "BarriersNew", "CrowdBarrierOldShader": "BarriersOld", "RedPhoneBoxTextSub": "RedPhoneBoxClean", "Cable": "SteelCable", "Metal": "Iron",
                            "BridgeRoadShader": "Road", "M_TrafficCones": "T_TrafficCones", "BrickWideShader": "Brick", "ElectircPoleShader": "ElectricityPoles", "ElectricPolesShader": "ElectricityPoles", "ElectricPoleGlassShader": "ElectricityPoles"},
     "jobs": []}
uk_files_1024 = ["Bridge", "Overpass", "Cables", "ExteriorWall", "SpeedCameras"]
uk_files_8000 = ["Pylons", "UtilityPoles"]
for f in uk_files_1024:
    J["jobs"].append({"name": "UKSP__" + f, "source": UK + "\\" + f + ".fbx", "mode": "uksp", "split": True, "max_tex": 1024, "flip_normal_green": True, "tri_limit": 12000})
for f in uk_files_8000:
    J["jobs"].append({"name": "UKSP__" + f, "source": UK + "\\" + f + ".fbx", "mode": "uksp", "split": True, "max_tex": 1024, "flip_normal_green": True, "tri_limit": 8000})
out_path = r"C:\Users\mdabe\AppData\Local\Temp\fct-research\inv\jobs_7packs.json"
json.dump(J, open(out_path, "w"), indent=1)
print(len(J["jobs"]), "jobs ->", out_path)
