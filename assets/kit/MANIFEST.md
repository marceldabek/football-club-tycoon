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
| Roblox `generate_mesh` (2026-09-17, X45) | `ServerStorage.Kit.Vehicles`: HatchbackNavy (mesh 95055842771788, tex 109397609553801), HatchbackRed (mesh 137763373450908, tex 137092017577299), HatchbackSilver (mesh 102986906565540, tex 99180409914065); one MeshPart each, scaled x1.4 to street size, front = -LookVector like HatchbackOrange | AI generation under the account (Q27 allows it for props) | prompts asked for a generic unbranded hatchback; a fourth (white) failed on a rate limit; a first try with a rear spoiler was discarded |
| Roblox Creator Store (free) | `ServerStorage.Kit`: VanWhite (87089223661838), HatchbackWhite (15025303904), HatchbackOrange (447094510), HedgeLong (14355085874), HedgeBright (13364734150), OakPack6 (98950444096614), SnackVendingMachine (10904552162), DrinkFridge (8816864440), FloodlightTower (114304849826345) | Creator Store terms | all scripts, sounds and click detectors removed on import; provenance of the two branded cars and the oak pack is unverified (see notes) |
| Roblox Creator Store (free, 2026-09-17, X112) | `ServerStorage.Kit.Town.PhoneBoxK6`: "Red Telephone Box" asset 760731465 by CarmenDeAvila; 66 parts (39 meshes/unions), 11.4 tall, placed at scale 0.62 | free Creator Store model | no scripts in it; compared with asset 5224255351 (ColdPaIm3r, 84 parts, flat roof), which was discarded; place-file only, KitPlacer falls back to a red 3x7x3 block |
| Roblox Creator Store (free, 2026-09-17, X113) | `ReplicatedStorage.ClientKit.Swan`: "Swan" asset 15968285610 by yiypoo1024; one MeshPart "Mute Swan", scaled to 4 long, faces its local +Z | free Creator Store model | no scripts; in ReplicatedStorage because Swans.client.luau clones it; compared with 5636394423 (64 parts, standing, wings spread) and 4622120566 (19-part cartoon), both deleted; place-file only, the client falls back to 4 primitive parts |
| Roblox Creator Store (free, 2026-09-17, X114) | `ServerStorage.Kit.Vehicles.ForkliftYellow`: "Forklift (Prop)" asset 12635164828 by oreoPL2; one textured MeshPart, scaled to 7 long in the kit, forks at local -Z | free Creator Store model | no scripts; compared with 18934070882 (53 parts, 29 scripts) and 119225957516231 (same mesh re-uploaded with 3 scripts), both deleted; EstateBuilder falls back to the 8-part primitive forklift when it is missing |

Rejected on inspection: Bloxy Cola vending machine (untextured), Roblox classic oak (block foliage),
Small Hatchback Cars (toy look), Sport Stadium Seats (924 red blocks), Lada hatchback (walk-path rig).

## Import limits applied
- **SurfaceAppearance maps must be 1024×1024 or smaller.** Larger maps upload and pass moderation but render as flat grey on MeshParts (the same image still works as a Decal). Everything in the kit is therefore cached at 1K; the 2K cache is only for decals.
- Chain-link fence panels in UK Street Props ship without an opacity mask; the cut-out is derived from the wire luminance of `Fencing*_D.tif`, exported as a PNG colour map with CLIP blending, and the SurfaceAppearance uses AlphaMode Transparency.
- Modular English Housing prefabs carry a second lightmap UV layer; the exporter strips it.
- 20,000 triangles per mesh: TowerBlock (279k), Flats_01 (33k), Mansion_02 (21k) excluded or decimated; UKSP Wall (51k), Pylon (61k), TrashBags (30-132k), UtilityPoles (31k) decimated or skipped.
- Textures: 4K/8K sources cached at 1K (props) or 2K (walls, houses); Open Cloud upload limit is 20 MB per GLB.
- Normal maps: Studio-Lab textures were DirectX (Y-) and are flipped in the cache; Modular English Housing and Poly Haven are already OpenGL.
- Scale: all GLBs baked to studs at 2.75 studs per metre and grounded at y=0.

## Provenance notes
- The white "Ford Transit" and "Fiesta 2017" meshes look like conversions of third-party car models. Fine for the review slice; replace with licensed or generated cars before release.
- The Letaij oak pack's creator re-uploads Sketchfab models in other listings; treat the oaks the same way.

| Roblox Creator Store (free, 2026-09-20, X372) | `ServerStorage.Kit.Vehicles.BusDoubleDecker`: "Double Decker Transit Bus (prop)" asset 8211334552 by InuB30; one textured MeshPart, no scripts, sounds, seats or click detectors. Scaled 0.781 to 8.3 x 12.1 x 27.4 studs, matching a real double-decker (2.55 x 4.4 x 11 m at 2.75 studs/m). Windscreen faces +Z, so ClientKit publishes FrontYaw = pi. | free Creator Store model | replaces the primitive Traffic bus rig, which was 4.4 x 3.0 x 13.5 studs - three studs tall, shorter than a 5-stud townsperson |

## Town kit (overnight 2026-09-17) — `ServerStorage.Kit.Town`

Free Creator Store models, scripts/sounds/click detectors removed on insert. Checked against
`RiveremereWestdale.png` / `RivermereCenter.png`.

| Name in kit | Asset id | Creator | Parts | Size (studs) | Notes |
|---|---|---|---|---|---|
| TerraceRowVictorian | 2974339114 | RiverBL0X | 166 | 23 × 25 × 128 | Victorian two-up two-down red-brick row, slate roof, chimneys, navy doors; row runs along its Z, doors face its −X. Fits the 130-long terrace blocks in TownLayout. Older Roblox brick texture, no bay windows. |
| ChurchSpire | 7976643711 | esthergriffiths ("St. P#ter's Church - Hereford") | 238 | 163 × 202 × 77 | Brick church with a tall broach spire and pinnacles; 1 script removed. White porch/gate parts look unfinished. Landmark spire (TownLayout height 130: scale ~0.65 or keep). |
| LampVictorian | 8408243710 | visionpsyche7 | 36 | 4 × 20 × 2 | Black Victorian gas lamp post, no lights inside. |

Rejected: UK Block of 3 Houses 11953059993 (yellow-brick new-build, 1,443 parts), British/UK Mesh House
9768805544 / 9763582693 (a box with photo decals), Church model 12932669640 (2,661 parts, 39 lights),
Victorian Street Lamp Post Decor Pack 123430227900506 (2 scripts, tiny).
