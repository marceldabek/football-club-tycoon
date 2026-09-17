# Asset Kit Manifest

`assets/kit/` is gitignored (large binaries). This file and README.md are the only tracked items.
Layout:

```
assets/kit/
  _raw/                 untouched downloads
    ModularEnglishHousing/   Fab purchase, Blender files + 5 trim sheets (4K)      Standard License (Fab)
    UKStreetProps/           Fab purchase "roadtrafficpropsv2": 43 FBX + 359 PNG    Standard License (Fab)
    PolyHaven/<id>/          26 CC0 props, FBX + textures (1k/2k)                   CC0
  _export/
    texcache/{1k,2k}/     downscaled JPEG/PNG maps (UKSP normals green-flipped to OpenGL)
    glb/                  Roblox-ready GLBs, 1 unit = 1 stud (2.75 studs/m), grounded, <= 19k tris
  Architecture .. Materials/   empty category folders reserved for sorted copies once uploads exist
```

## Sources and licences

| Source | Items | Licence | Notes |
|---|---|---|---|
| Modular English Housing (Howard Coates, Fab) | 12 prefab buildings, 68 modular pieces, 5 trim-sheet material variants | Fab Standard License, Personal tier | .blend texture paths were broken; exporter re-links by basename |
| UK Street Props (Studio-Lab, Fab) | 43 FBX files, 355 mesh objects | Fab Standard License, Personal tier | materials carry no texture links; exporter maps material name -> `<prefix>_{D,N,R,M,E}` maps |
| Poly Haven | metal_office_desk, modern_arm_chair_01, classic_laptop, office_notepads, stationery_supplies, Television_01, drawer_cabinet, wooden_bookshelf_worn, painted_wooden_bench, football, dirty_football, rubber_boots, medical_box, CashRegister_01, CoffeeCart_01, utility_box_01, power_box_01, security_camera_01, exterior_aircon_unit, water_manhole_cover, old_tyre, cardboard_box_01, korean_fire_extinguisher_01, wooden_ladder, WetFloorSign_01, rollershutter_door | CC0 | several are 20k-37k tris; exporter decimates to per-prop limits |
| Roblox Creator Store (free) | `ServerStorage.Kit`: VanWhite (87089223661838), HatchbackWhite (15025303904), HatchbackOrange (447094510), HedgeLong (14355085874), HedgeBright (13364734150), OakPack6 (98950444096614), SnackVendingMachine (10904552162), DrinkFridge (8816864440), FloodlightTower (114304849826345) | Creator Store terms | all scripts, sounds and click detectors removed on import; provenance of the two branded cars and the oak pack is unverified (see notes) |

Rejected on inspection: Bloxy Cola vending machine (untextured), Roblox classic oak (block foliage),
Small Hatchback Cars (toy look), Sport Stadium Seats (924 red blocks), Lada hatchback (walk-path rig).

## Import limits applied
- 20,000 triangles per mesh: TowerBlock (279k), Flats_01 (33k), Mansion_02 (21k) excluded or decimated; UKSP Wall (51k), Pylon (61k), TrashBags (30-132k), UtilityPoles (31k) decimated or skipped.
- Textures: 4K/8K sources cached at 1K (props) or 2K (walls, houses); Open Cloud upload limit is 20 MB per GLB.
- Normal maps: Studio-Lab textures were DirectX (Y-) and are flipped in the cache; Modular English Housing and Poly Haven are already OpenGL.
- Scale: all GLBs baked to studs at 2.75 studs per metre and grounded at y=0.

## Provenance notes
- The white "Ford Transit" and "Fiesta 2017" meshes look like conversions of third-party car models. Fine for the review slice; replace with licensed or generated cars before release.
- The Letaij oak pack's creator re-uploads Sketchfab models in other listings; treat the oaks the same way.
