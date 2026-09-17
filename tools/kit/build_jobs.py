import json, glob, os
RAW = r"F:\dev\football-club-tycoon\assets\kit\_raw"
UK = RAW + r"\UKStreetProps\RoadTrafficProps"
MEHB = RAW + r"\ModularEnglishHousing\Modular_English_Housing.blend"
J = {"studs_per_meter": 2.75, "out_dir": r"F:\dev\football-club-tycoon\assets\kit\_export\glb",
     "uksp_tex_dir": UK, "meh_tex_dir": RAW + r"\ModularEnglishHousing\Modular_English_Housing._Textures",
     "material_overrides": {"ConcreteBareShader": "ConcreteWall", "MI_Concrete": "ConcreteWall", "PavingShader": "Sidewalk", "YellowLinesShader": "AsphaltYellow",
                            "DecalsShader1": "PhoneboxDecals", "GalvanizedMetalShader": "armcoBarrier", "phong1": "CardBoxes", "WoodShader": "WoodFence", "TrashCanMetalShader": "TrashCan",
                            "CrowdBarrierNewShader": "BarriersNew", "CrowdBarrierOldShader": "BarriersOld", "RedPhoneBoxTextSub": "RedPhoneBoxClean", "Cable": "SteelCable", "Metal": "Iron",
                            "BridgeRoadShader": "Road", "M_TrafficCones": "T_TrafficCones", "BrickWideShader": "Brick", "ElectircPoleShader": "ElectricityPoles", "ElectricPolesShader": "ElectricityPoles", "ElectricPoleGlassShader": "ElectricityPoles"},
     "jobs": []}
uk_files = {"Skips": 2048, "dumpster": 2048, "LitterBin": 1024, "TrachCan": 1024, "boxes": 1024, "WoodPallets": 1024, "BusShelter": 2048, "RedPhoneBoxes": 2048, "ModernPhoneBox": 1024,
            "StreetLights": 1024, "Signs": 1024, "TrafficCones": 1024, "CrowdBarrier": 1024, "GuardRails": 1024, "armcoBarrier": 1024, "ConcreteBarriers": 1024, "ConcreteWall": 1024,
            "GardenWall": 2048, "GardenWallA": 2048, "GardenWallB": 2048, "BondaryWall": 2048, "RailingWall": 2048, "Fences": 1024, "WoodFences": 1024, "WoodenFence": 1024, "CorrugatedFence": 1024,
            "TelegraphPoles": 1024, "ElectricityPoles": 1024, "TrafficProps": 1024, "ParkBenches": 1024, "PicnicBenches": 1024, "TrashBags": 1024, "ModularRoads": 2048, "VarioGuard": 1024,
            "RoadWorksSign": 1024, "RoadClosedSign": 1024}
for f, mt in uk_files.items():
    J["jobs"].append({"name": "UKSP__" + f, "source": UK + "\\" + f + ".fbx", "mode": "uksp", "split": True, "max_tex": mt, "flip_normal_green": True, "tri_limit": 12000})
for name in ["House_01_VAR01", "House_02_VAR1", "House_03_VAR01", "House_04_VAR01", "House_05_VAR01", "House_06_VAR01"]:
    for ts in (1, 3):
        J["jobs"].append({"name": "MEH__%s__ts%d" % (name, ts), "source": MEHB + "\\Building_Prefabs\\" + name + ".blend", "mode": "meh", "trimsheet": ts, "max_tex": 2048, "tri_limit": 19000})
for name in ["Garage_01_VAR01", "Office_01_VAR01", "Mansion_01_VAR01"]:
    J["jobs"].append({"name": "MEH__%s__ts1" % name, "source": MEHB + "\\Building_Prefabs\\" + name + ".blend", "mode": "meh", "trimsheet": 1, "max_tex": 2048, "tri_limit": 19000})
for piece in ["Wood_Fence_A", "Wood_Fence_Beam_A", "Wood_Gate_A", "Railing_A", "Railing_Post_A", "Door_Canopy_A", "Chimney_A", "Letterbox_A", "Stairs_Front_A", "Wall_Window_A", "Wall_Door_A", "Wall_A", "Roof_A"]:
    J["jobs"].append({"name": "MEH__%s__ts1" % piece, "source": MEHB + "\\Modular_Pieces\\" + piece + ".blend", "mode": "meh", "trimsheet": 1, "max_tex": 2048})
lim = {"drawer_cabinet": 12000, "dirty_football": 6000, "rubber_boots": 8000, "CoffeeCart_01": 15000, "power_box_01": 8000, "classic_laptop": 8000, "cardboard_box_01": 6000, "plastic_crate_01": 6000, "exterior_aircon_unit": 10000, "security_camera_01": 6000}
for d in sorted(glob.glob(RAW + r"\PolyHaven\*")):
    if not os.path.isdir(d): continue
    fb = glob.glob(d + r"\*.fbx")
    if not fb: continue
    n = os.path.basename(d)
    J["jobs"].append({"name": "PH__" + n, "source": fb[0], "mode": "ph", "max_tex": 2048, "tri_limit": lim.get(n, 12000)})
json.dump(J, open(r"C:\Users\mdabe\AppData\Local\Temp\fct-research\inv\jobs_full.json", "w"), indent=1)
print(len(J["jobs"]), "jobs")
