# Asset Inventory — have / missing / using

> Compiled 2026-09-19 from `assets/kit/_raw/`, `assets/kit/_export/glb/`, `asset_ids*.json`, the
> Creator Store list in `ASSET_KIT.md`, and a grep of `src/`.
> Companion to `docs/ASSET_KIT.md` (purchases, licences, pipeline) and `docs/PLOT_KIT_PLAN.md` (the build plan).

## Headline

| | |
|---|---|
| Bought/downloaded source files | **69 FBX** across 3 packs |
| Prepped as Roblox GLBs | **378** |
| Uploaded to Roblox | **299** |
| Loaded into the place (`Kit.Meshes`) | **96** |
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

# 2. HAVE BUT NOT UPLOADED — 79 GLBs sitting ready on disk

**These are already prepped, Roblox-ready, and one `tools/upload_kit.py` run from being usable.**
This is the biggest and cheapest win in the project.

| Pack | N | What it is | Why it matters |
|---|---|---|---|
| **ModularRoads** | **44** | Straight, StraightYellowLines ×2, Crossroads, TJunction (L/R), Fork, CulDeSac (5 variants), 45° and 90° turns, left/right turns — most with yellow-line variants | **Every road in Rivermere is a primitive asphalt slab.** This is a complete modular road system. |
| **BondaryWall** | **6** | WallStraight, WallCorner, Post, GatePosts, LeftGate, RightGate | **Literally the club plot boundary wall + vehicle gates** that `PlotGrounds` builds from blocks |
| MEH | 6 | 6 more housing variants | More terrace variety |
| RoadClosedSign | 6 | New/old closed signs, trims | Matchday road closure |
| ElectricityPoles | 5 | 5 pole types | Estate/industrial backdrop |
| ConcreteWall | 4 | A, B, C, cap | Industrial estate |
| ModernPhoneBox | 4 | Clean, dirty, doors | Street variety |
| PicnicBenches | 2 | New, old | Riverside Park |
| VarioGuard | 2 | Middle, cap | Roads |

**Action: upload all 79.** One run of `tools/upload_kit.py`, no Blender work, no money.

---

# 3. HAVE BUT NOT EXPORTED — 7 FBX packs needing Blender

Bought, sitting in `_raw/`, never run through `tools/kit/export_glb_v3.py`:

| FBX | Likely use | Note |
|---|---|---|
| **Bridge** | River Lune road bridges (currently 384 primitive parts) | |
| **Overpass** | Ring road / railway | |
| **Pylons** | Backdrop beyond the town | manifest says 61k tris — needs decimating |
| **UtilityPoles** | Estates | 31k tris — needs decimating |
| **ExteriorWall** | Building shells | |
| **Cables** | Overhead wires (currently 184 primitive parts) | |
| **SpeedCameras** | Road detail | |

**Action: one Blender export batch.** No money, but needs the export pipeline re-run.

---

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
