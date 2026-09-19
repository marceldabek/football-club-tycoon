# Asset Inventory — have / missing / using

> Compiled 2026-09-19 from `assets/kit/_raw/`, `assets/kit/_export/glb/`, `asset_ids*.json`, the
> Creator Store list in `ASSET_KIT.md`, and a grep of `src/`.
> Companion to `docs/ASSET_KIT.md` (purchases, licences, pipeline) and `docs/PLOT_KIT_PLAN.md` (the build plan).

## Headline

| | |
|---|---|
| Bought/downloaded source files | **69 FBX + 68 housing `.blend`** across 3 packs |
| Prepped as Roblox GLBs | **464** |
| Uploaded to Roblox | **497** (was 299 before 2026-09-19) |
| Loaded into the place (`Kit.Meshes`) | **96** — run `fetch_kit.luau` to get the rest |
| **Actually referenced in `src/`** | **2** |

Two of 299. The two are `UKSP__LitterBin__LitterBin` and `UKSP__ParkBenches__ParkBench01`. Everything
else in Rivermere is primitives.

| Pack | Exported | Uploaded | Used in `src/` |
|---|---|---|---|
| UK Street Props (UKSP) | 333 | 260 | **2** |
| Modular English Housing (MEH) | 19 | 13 | **0** |
| Poly Haven (PH, CC0) | 26 | 26 | **0** |

---

# 1. HAVE — uploaded and usable today

## UK Street Props — 260 items live

| Category | N | Category | N |
|---|---|---|---|
| **Signs** | 78 | dumpster | 6 |
| TrafficProps | 21 | CorrugatedFence | 6 |
| Fences | 21 | RoadWorksSign | 6 |
| WoodFences | 15 | GardenWallB | 5 |
| TelegraphPoles | 15 | CrowdBarrier | 4 |
| TrafficCones | 10 | ParkBenches | 4 |
| GuardRails | 10 | RailingWall | 4 |
| boxes | 9 | RedPhoneBoxes | 4 |
| WoodPallets | 9 | armcoBarrier | 3 |
| ConcreteBarriers | 8 | StreetLights | 3 |
| TrashBags | 6 | GardenWallA / GardenWall | 3 / 3 |
| | | Skips / TrachCan | 2 / 2 |
| | | BusShelter / LitterBin / WoodenFence | 1 each |

## Modular English Housing — 13 uploaded
6 house models × 2 trim-sheet variants, plus a garage. Flat-fronted Victorian; **no bay windows**.

## Poly Haven (CC0) — 26 props
Office and interior kit: desk, armchair, laptop, notepads, stationery, TV, drawer cabinet,
bookshelf, bench, footballs, boots, medical box, till, coffee cart, utility/power box, security
camera, air-con, manhole cover, tyre, box, extinguisher, ladder, wet-floor sign, roller shutter.

## Roblox Creator Store (free, in the place)
VanWhite, HatchbackWhite, HatchbackOrange, HedgeLong, HedgeBright, OakPack6, SnackVendingMachine,
DrinkFridge, FloodlightTower, PhoneBoxK6, Swan, ForkliftYellow, TerraceRowVictorian, ChurchSpire,
LampVictorian. Plus 3 AI-generated hatchbacks (navy/red/silver).

⚠️ The white "Transit" and "Fiesta" and the oak pack have **unverified provenance** — replace before release.

---

# 2. RESOLVED 2026-09-19 — everything bought is now uploaded

All three gaps below are closed. 198 new assets went up in one pass.

| Was blocked | N | Why it had failed |
|---|---|---|
| **ModularRoads** | **44** | Every GLB was 23-29 MB against Open Cloud's **20 MB per-file limit**. Cause was `max_tex: 2048` selecting the 2k texture cache. Re-exported at 1024: largest is now 6.2 MB, the set went 1,110 MB -> 233 MB. |
| **MEH modular pieces** | **68** | `build_jobs.py` named only 13 of 68, and **32 of the `.blend` files were saved in Edit Mode**, which makes `bpy.ops.object.select_all` fail its poll and kill the job. `export_glb_v3.py` now forces Object Mode and deselects via `select_set`. |
| **7 never-exported packs** | **22** | Bridge, Overpass, Cables, Pylons, UtilityPoles, ExteriorWall, SpeedCameras were simply absent from the `uk_files` dict. Pylons/UtilityPoles decimated to 7,600 tris. |
| Prepped but unsent | 35 | BondaryWall, ConcreteWall, ElectricityPoles, ModernPhoneBox, PicnicBenches, RoadClosedSign, VarioGuard, 6 MEH |

Two pieces are directly useful for the club plot:
- **`UKSP__BondaryWall__*`** — WallStraight, WallCorner, Post, GatePosts, LeftGate, RightGate
- **`UKSP__ExteriorWall__*`** — Wall, Post, GateLeft, GateRight, GatePosts (a second gate set)

**Both fixes are pinned in the tracked scripts**, so a rebuild cannot regress: `build_jobs.py` globs
the pieces directory rather than naming a few, and pins ModularRoads to 1024.

## Still suspect: the remaining `max_tex: 2048` entries

`build_jobs.py` still asks for 2048 on GardenWall, GardenWallA/B, BondaryWall, RailingWall,
RedPhoneBoxes, Skips, dumpster and BusShelter. Roblox renders SurfaceAppearance maps above
1024x1024 as **flat grey on MeshParts**, so these may already look broken in the place. They are
small enough to have uploaded, so nobody noticed. **Check them in Studio; if grey, drop to 1024 and
re-export.**

# 4. MISSING — not owned, should be found

Ordered by how much it would change what the player sees. Nothing here is bought yet.

## High — the player stands in these
| Need | Current | Note |
|---|---|---|
| **Stand / terrace seating units** | primitive blocks | The slice review called the block-built stand "plainer than the meshes around it". The single biggest visual gap at the ground. |
| **Turnstile units** | primitives | CLAUDE.md s20 lists these as deserving custom work |
| **Shopfront units** | SurfaceGui-drawn fronts | High street is drawn, not modelled |
| **Kerbs / pavement pieces** | primitive strips | ModularRoads has **no kerb or pavement** — a gap even after uploading it |
| **Dugouts, goals + nets, sponsor boards** | primitives | |

## Medium — seen constantly
| Need | Current | Note |
|---|---|---|
| **A bus** | none | Bus-stop fast travel is a decided feature (s27). There is no bus. |
| **Crowd / pedestrian characters** | R15 block rigs | |
| **Pub, station building, industrial units** | primitives | MEH is houses only |
| Licence-clean cars | 2 unverified + 3 AI | Replace the Transit/Fiesta |
| Train + carriages, track, platform edge | primitives | |

## Low — nice to have
Trees beyond the oak pack; bay-window terraces (`RiveremereWestdale.png` shows bays, MEH is flat-fronted —
"UK Housing – Terraced Set 1", Macwelshman, Fab, $39.99 is the closest paid match); market stalls;
trophy, club bus, training equipment (s20 flags these as custom-worthy).

---

# 5. WILL USE — the plan

## Now, before Studio
1. **Upload the 79 ready GLBs** — roads and the boundary wall above all.
2. **Export the 7 unexported FBX packs** in one Blender batch.
3. **Run `fetch_kit.luau`** — only 96 of 299 are in the place; after step 1 it should be ~378.

## Then, the club plot (`docs/PLOT_KIT_PLAN.md`)
`BondaryWall` for the wall and gates → footpath furniture → car park signage → training fence →
yard clutter and crowd barriers. Stop after the wall and look at it.

## Then, roads
Replace primitive road slabs with `ModularRoads`. **Straight pieces are fine for most streets** —
the kit has `Straight`, `StraightYellowLines` ×2, plus junctions, T-junctions, forks and cul-de-sacs
for where they're genuinely needed. Roads do not have to run at arbitrary angles; snapping the layout
to the module grid is an acceptable and probably better-looking constraint.

## Not doing yet
- MEH houses into the terraces — 13–19 prefabs across 66 semi pairs plus terrace rows will repeat
  hard. Compare against the textured primitives side by side first.
- Anything in section 4 that costs money, until Marcel approves a buy list.

---

# 6. Known issues to check in Studio

- **Three rows of houses stacked in some spots** (Marcel, 2026-09-19). Not yet verified or located —
  likely two builders dressing the same street (`TerraceBuilder`, `TerraceStreetDresser`,
  `EstateBuilder` all place housing). Check before the road work, since it may be a layout bug
  rather than an asset one.
- Only 96 of 299 uploads are loaded into the place.
- `ServerStorage.Kit.Meshes` names must match `KitPlacer` lookups exactly; misses fall back to grey blocks.
