# Rivermere v3 - Handoffs

Shared noticeboard for the lanes in `docs/TOWN_V3_BUILD.md`. Append under your lane; never edit another lane's entry.

## Status

- [x] Contract ready 2026-09-20: 20 stub files committed, `docs/town_v3_lots.json` written (851 lots, 94 roads). Regenerate with `python tools/town_plan_v3.py --json`. Do NOT read the JSON whole (300 KB): query it with python.
- [ ] Marcel: Rojo Disconnect/Connect done after stubs landed
- [x] Lane P: spike numbers published 2026-09-20 (TOWN_V3_BUILD.md s9, reasoning in TOWN_V3_PERF.md). TEMP budgets are replaced: re-read section 9.

## Questions for Marcel

**From Lane P (performance)**

- **P1. Two-tier town?** Full slice density town-wide is about 89,000 MeshParts / 275,000 instances / 75 M triangles and does not fit a mid-range phone. Proposal: Tier A (full slice density) within 450 studs of the 4 plots, the Market Square and the station (16% of roads, 17% of units); Tier B elsewhere keeps the same roads and houses but lighter garden boundaries and furniture. All kit assets, no primitives. Total about 49,000 MeshParts, worst case ~10,000 loaded. *Recommendation: yes; lanes are building to it meanwhile.*
- **P2. Buy the terraced-house kit ("UK Housing - Terraced Set 1", $39.99, already on Lane C's list)?** 2,212 of 2,723 homes are terraced and the kit has no terrace prefab, so each unit is ~10-16 modular MeshParts (24,000 town-wide). Whole-house terrace meshes would cut housing to ~6,000 and halve the worst-case loaded set. *Recommendation: buy it; it is the single biggest performance lever.*
- **P3. MEH modular pieces are untextured.** All 68 `MEH__*__ts1` modular pieces have no SurfaceAppearance and no TextureID (flat pale grey in Studio); the MEH prefab houses are textured. This is an export problem, not a Lane H bug. *Recommendation: re-export the modular pieces with the trim-sheet texture at max_tex 1024 before Lane H's review screenshots; needs you or whoever runs the Blender export.*
- **P4. OK to bake collision/render fidelity into `ServerStorage.Kit` templates?** Fidelity cannot be set by script per clone; `V3Perf.bake` rewrites the templates once (Box collision, ~2 minutes, Edit mode, reversible by re-running `fetch_kit.luau` on a cleared folder). It touches the shared kit, so I have not run it. *Recommendation: yes, Lane I runs it before integration.*

**From Lane C (commercial, industrial, civic)**

- **C1. Please approve buy-list items #1-#5 (about $25).** rik4000 UK Commercial Buildings Pack 1 and 2, UK Industrial Buildings Pack 1, UK Pub Pack 1 (Unity Asset Store, $5 each) and UK Service Buildings Pack 1 (GameDev Market, about $5, has 2 train stations). Full table with links and licences: `docs/TOWN_V3_BUILD.md` s8.2. The kit has no shopfront, pub, industrial unit or station, so today the High Street is MEH house walls with bay windows and reads as housing. These packs are one low-poly mesh per building, which is also lighter than my modular stand-ins. They are 2017-era and flatter than MEH up close. *Recommendation: yes, buy all five, judge them on the High Street, and only if they look too dated there buy #6 British Modular Buildings ($27.99), which would put 3D spend about $3 over the $120 cap.*
- **C2. The church is 238 primitive Parts.** The `ChurchSpire` Creator Store keeper is not a mesh. No mesh church was found in the searches. *Recommendation: keep it for now (register EC7), AI-mesh or buy a church later; it is one building.*

## Lane A

## Lane P

**Done 2026-09-20 (spike + budgets).**
- Kit check: `ServerStorage.Kit.Meshes` = 464 children = every id in `fetch_kit.luau`. Fully loaded, nobody needs to fetch.
- Spike street: `Workspace.V3Sandbox.P.SpikeStreet` (359 studs, 17 units a side, modular terrace west, prefabs east). 724 MeshParts / 49 unique MeshIds / 689k triangles / 2,267 instances; zero KitMissing, zero primitives.
- Headline per-unit costs: modular terraced unit 15.8 MeshParts / 1.9k tris; prefab house 1 / 3.8k; gardens 11 / 12k per unit; furniture 14.8 MeshParts / 51k tris per 100 studs; road tile 3 / 56.
- v3 exact: 65,952 studs of road, 851 lots, 2,927 units.
- Published: section 9 budgets, `docs/TOWN_V3_PERF.md`, `V3Perf.count / format / withinBudget / applyDefaults / bake / FIDELITY`, `tests/V3PerfTest.luau` (10 tests pass).
- **Frame time NOT measured** (needs Play). Lane I: see TOWN_V3_PERF.md section 8.

**For Lane A:** section 4.3 says one Atomic Model per district. Please change it to: district = non-atomic grouping Model; one Atomic Model per lot. Reason in PERF s7 (Westdale as one Atomic model = ~12,000 MeshParts arriving at once).

**For Lane R:** a road tile is 3 MeshParts (4 for YellowLines variants), so your budget went UP to 2,600. Tiles: `applyDefaults(m, "road")`.

**For Lane H:** budget 24,000, 10 MeshParts per terraced unit averaged per row. Assemble per row (shared party walls, 16-stud pieces, gables only at row ends, no floors/ceilings/foundations); prefabs for semis/detached. One Atomic Model per lot. The modular pieces are currently untextured (Question P3): not your bug.

**For Lane F:** furniture 4,500 (15 per 100 studs in Tier A, 5 in Tier B); plot boundaries 13,500 (11 / 4 per unit) with a 1,000-triangle cap per boundary piece. `UKSP__GardenWall__Wall` is 3,620 triangles: pick a cheaper wall or fence. Non-atomic. Tag decor `V3Decor`. Only 1-MeshPart vehicles.

**For Lane C:** budget 4,000 (12 per commercial unit, 40 per special). Each special block Atomic.

**For Lane I:** (1) set Workspace streaming properties by hand (section 9 rule 5); (2) run `V3Perf.bake` over the kit templates in chunks inside `task.spawn` if Marcel OKs P4; (3) make `Quality` Low hide the `V3Decor` tag; (4) frame-time and memory validation per PERF s8; (5) `V3PerfTest` needs adding to nothing: RunAll picks up `*Test` modules itself.

**Sorry, Lane C:** commit 181a90b swept in your then-uncommitted section 7/8 edits to `TOWN_V3_BUILD.md` (same file, whole-file staging). Nothing was changed or lost; your text is committed as you wrote it.

**Known gaps:** triangle counts need EditableMesh (Edit mode only; Creator Store meshes refuse). Tier membership is not computed by `V3Perf`; lanes test distance to the six Tier A points. Wave 1: I will review each lane's `[FCT]` line as it lands.

## Lane R

**Done 2026-09-20.** `Shared/RoadTiles` (pure: `plan(roads, roundabouts) -> { tiles, exempt, stats }`, piece table measured from the kit) and `Server/RoadTiler.build(parent, origin, filter)` per s4.3. Reads `TownLayout.ROADS` / `ROUNDABOUTS` directly. Whole town built in `Workspace.V3Sandbox.R` at (0,0,6000): one Atomic `Roads_<district>` Model per district (10; roads with no district go to "Town Centre" if wholly inside the centre box, else "Arterial"). Tests: `RoadTilesTest` 15 + `RoadTilerTest` 5, all passing; 0 `KitMissing`, 0 untagged primitives, 0 unresolved conflicts, max gap 0.57 stud.

`[FCT] Roads: 676 tiles (2107 MeshParts, budget 1200) ...` = 517 straight, 40 bends (28 x 45, 12 x 90), 70 T, 24 cross, 25 heads, 19 E3 parts. Build time 0.17 s.

**Budget (Lane P):** s9's 1,200 assumed one MeshPart per tile. Kit road pieces are 3 MeshParts each (4 with yellow lines), all sharing MeshIds. 676 tiles is inside the tile estimate; 2,107 MeshParts is not. Please rule: raise R to ~2,200, or count tiles.

**Decisions (detail in the RoadTiles header):**
- Scale: residential/lane 0.816 (36 corridor); main AND ring 0.93 (40.9 wide). Ring at its true 48 would need 1.09 bends, which do not fit the ring's 113-stud double 45 north of Northfields; 0.93 is the largest that does, and keeping ring = main means no width step at their junctions. The ring keeps a 3.5-stud bare strip each side inside its corridor.
- Straights are remainder-fitted by stretching along their length (0.67 to 1.35 typical; markings checked, dashes just lengthen). KitPlacer only scales uniformly, so RoadTiler resizes the MeshParts along local Z after placing.
- **Fork is NOT used.** Its branches are 90 apart (each 135 from the stem); the split at (-505,-105) is a through line plus a 45 spur. High Street keeps a proper 45 bend there and Station Road tucks under it. `CulDeSac_Left/Right90Degree` are a bend with a bulb and two mouths, not a terminal head: unused. All 25 heads use `CulDeSac` with the bulb centred on the head point (34.5 radius vs HEAD_RADIUS 34).
- **Tuck** = stand-in for junctions the kit cannot make (no 45 T) or that do not fit: the branch's last straight is pitched down <=1.5 studs so its end slides under the through road. Visible result: the through road's verge and pavement run unbroken across the branch mouth. 30 tucked tiles, 21 downgraded junctions.
- **Every kit road piece already carries kerb + pavement + a green verge** (carriageway 15.9, pavement ~4.3 each side, verge ~9.75 each side, unscaled). So **E4 is not used by Lane R**. But in terraced streets and the Town Centre the outer 8 studs each side are GRASS, not paving. Lane F / Integrator: decide whether the centre wants a paving overlay (that would be the real E4).
- E3: big roundabouts (9) = asphalt disc + grass island, arms trimmed 8 inside the radius, disc hides the overlap. Foundry Way mini (r 16) = normal Crossroads + a painted 5-stud disc. No new register rows.

**Known bugs / limits:**
1. Tucked mouths have verge across them (see above). Lane A could remove most: these junction pairs are closer than one T piece (~90 studs): High St (-330/-360/-400), Riverside Rd (750/760), Ring (590/600 south; -850/-915; -1150,0..25; -1350,-200..-240; -1350,-600..-670), Bridge St (100, 560/620/680/700 and 0,130..200), Hollingford Rd (1500/1510), Mill St, Weaver St, Northfields Ave (400/450, 850/900), the three 60-stud stubs at z 740-800 (Bleach/Fellmonger/Lunebank). Spacing junctions >= 100 apart (>= 150 from a bend) makes them real T pieces with no code change.
2. 45-degree junctions (Station Rd, Cooper St, Ferry Lane, Fern St, Riverside Rd at the ring, Lune St x Bridge St) will always tuck until a 45 T asset exists. Buy-list candidate.
3. Plot 2 / Plot 4 lanes end 40-50 studs after a 90 bend; the bend's leg runs ~35 studs past the lane's end point into the plot entrance. Harmless if the plot has a car-park apron there.
4. A few sliver straights (down to 3 studs) where a run leaves a tiny remainder.
5. Roads cross the river and railway at ground level: no bridge awareness. Tiles carry a `Road` attribute; Integrator should either skip tiles inside `TownLayout.BRIDGES` spans or let BridgeDresser decks cover them.
6. Screenshots: taken via MCP (`R_northfields_west`, `R_fork_highstreet`, `R_ring_roundabouts`) but the capture tool returns images inline only, so nothing could be saved to `docs/v3_review/R/`. To re-take, top-down from sandbox coords (-1000,420,5250), (-440,330,5940), (1320,340,6470).

**Integrator must wire:** call `RoadTiler.build(townFolder, CFrame.new(), nil)` and retire the primitive road / pavement / kerb / roundabout drawing in `TownBuilder` (and any road-marking decals). Ground under roads should be plain grass (tile bottoms sit ~0.1 to 0.5 below y=0, pavement top at y=0.35, carriageway ~0.1). Add `RoadTilesTest` and `RoadTilerTest` to the suite (they are picked up by name already).

## Lane H

## Lane C

**Done 2026-09-20.** `TradeRecipes` (pure, seeded from `Lot.id`) and `TradeAssembler.build(parent, origin, filter)` build all 134 frontage lots of the seven trade uses plus 21 building-type specials (pubs, pub and cafes, park cafe, supermarket, 2 shop blocks, town hall, 3 schools, church, waterfront flats, sports hall, builders yard). Reads live `TownFrontage.generate()` and `TownLayout.DISTRICTS`; falls back to a fixture inside `TradeRecipes` if either is missing. Specials have no `front`, so they face whichever long side is nearer a road.

- Whole town in `Workspace.V3Sandbox.C` at (-6000, 0, 0): `meshParts=2741` of 4,000, `uniqueMeshIds=43`, `kitMissing=0`, `parts=220` (all inside the church keeper, tagged `V3Exempt = "EC7"`). Builds in 1.5 s. One Atomic Model per lot named by `Lot.id`, district groups `Trade_<district>` Default, `V3Perf.applyDefaults` on every piece.
- Tests: `TradeRecipesTest` 8/8, `TradeAssemblerTest` 7/7 (fit the lot box, deterministic, zero KitMissing, every primitive exempt, textured, within budget, district filter).
- **No Part is created by Lane C code.** What is honest to say instead: almost everything is a *stand-in made of kit meshes*, registered as EC1-EC5 in s7. Parades are MEH bays and doors (read as housing, no fascia); industrial units are UKSP corrugated fence sheet stretched to wall panels with MEH garage doors scaled 1.5-2.5x; pubs are prefab houses; town hall and schools are `Office_01`. Buy list s8 fixes these.
- **MEH modular pieces are untextured (same as P3).** Found that the prefab trim sheet fits the modular UVs, so `TradeAssembler` clones the SurfaceAppearance from `MEH__House_01_VAR01__ts1/ts3` onto any untextured MEH MeshPart. Lane H can do the same today; it is skipped automatically once the pieces are re-exported.
- Cost savers worth knowing: blank back and side walls are covered by uniformly scaled `Wall_A` squares (6 x 4 modules = 3 pieces, brick looks 2-4x larger and shows a seam); rear roof slopes and flat roofs are one stretched piece.

**Known bugs / rough edges**
- Screenshots: the MCP capture returns the image to the agent only and cannot write to disk, so `docs/v3_review/C/` is empty. Four captures were taken (prefab facing probe, untextured modules, trim-sheet fix, High Street parade). To review: Studio camera at (-6150, 30, -5) looking at (-6230, 14, -34).
- `PH__security_camera_01` orientation on the parades was not checked visually.
- Scaled garage doors on warehouses are 20 studs tall: fine from a distance, cartoonish up close.
- Corner shops are `House_02` scaled 0.87 to fit the 18 x 24 lot; doors are slightly under character height.
- Specials that are ground or belong to a dresser are NOT built here: parks, pitches, marina, bandstand, station car park. There is no station building in the specials list at all (EC6).
- Lots at 45 degrees are placed through `Lot.front`; not visually checked.

**Integrator must wire**
- Call `TradeAssembler.build(townFolder, CFrame.new(), nil)` from the town build; retire `ShopBuilder` and the building half of `ShopDresser` (anything that draws SurfaceGui shopfronts or primitive shop/industrial/pub/flat blocks). `SquareDresser` builds a church for `use == "church"` blocks (lines 816, 844) and `SportsCentreDresser` a sports hall (line 324): pick one owner for each or they will double up with mine.
- When real shop/pub/industrial meshes arrive, only `TradeRecipes.recipeFor` changes: return one piece per lot and delete the EC rows.
- The fixture inside `TradeRecipes` (between `FIXTURE BEGIN/END`) can be deleted once `TownFrontage` and the v3 `TownLayout` are committed.

**District dresser coordinate check (Station, Marina, Park, School, SportsCentre, Square): nothing to fix.** None holds a literal world coordinate. All six find their blocks with `for _, district in TownLayout.DISTRICTS ... block.use == ...`, roads by name (`"Station Road"`) and landmarks from `TownLayout.LANDMARKS`, so the nudged pubs, supermarket and moved roads follow the data. Two assumptions to keep true: `StationDresser.yellowLineRuns` treats the LAST segment of Station Road as the straight past the station (v3: (-737,-337) to (-938,-337), still true), and `TownLayout.STATION_LAYBY` (z = -354, width 8) must stay on that segment's kerb (road centre -337, width 26, kerb -350: still true).


## Lane F

**Done 2026-09-20.** `src/shared/FurniturePlan.luau` (pure rules), `src/server/StreetFurniture.luau` (builder), `tests/FurniturePlanTest.luau` (19) + `tests/StreetFurnitureTest.luau` (7): 26 pass, all four files `loadstring` clean. Runs on Lane A's real `TownLayout.ROADS` + `TownFrontage.generate()` (no fixture file needed).

- `StreetFurniture.build(parent, origin, { district = ... })` per 4.3; `buildFrom(input, ...)` takes explicit data. One **non-atomic** grouping Model per district (`Furniture_<district>`; roads with no district go in `Furniture_Through Roads`). Each prop is a Model named by category with `Kit` and `Road` attributes, `V3Perf.applyDefaults` applied (`prop`; manholes and cones are `decor` and tagged `V3Decor`).
- Rules by road kind and by Lane P's tiers (looked up per spot, 450 studs from plots / square / station): lamps alternate sides with the arm over the road, telegraph poles down one side, give-way at every minor-road mouth and roundabout entry (driver's left, facing the driver), 40 signs on ring/main both directions, bins + benches on mains and outside every shop lot, phone boxes sparse, shelter + bench + bin at each `BUS_STOPS` entry (snapped to the nearest road's pavement, slid out of junction mouths), guard rails with a gate gap + warning signs at the 3 schools, manholes, utility cabinets, rare roadworks (sign, barrier, 4 cones), parked 1-MeshPart hatchbacks against the kerb on the UK side, only in front of housing lots.
- Nothing lands in a road corridor, lot, special block, junction mouth (other road's half width + 8 pavement + 6), roundabout, turning head (34), plot, market square or bridge ramp. `FurniturePlan.violations(input, placements)` re-checks any plan; whole town = 0 violations. Only exception: category `car` sits on its OWN residential carriageway (`onCarriageway = true`).
- **Fails loudly:** budget clipping and missing kit names `warn` and are counted; the `[FCT] Furniture:` line prints placed/planned per category, parts vs budget, clipped, missing, plus `V3Perf.format`. A missing asset is destroyed, never left as a grey block. Cheap decor is placed last so a clip hits manholes before lamps.

**Counts vs budget (whole town, planned, not built town-wide in Studio):** 2,859 props = **3,321 MeshParts of 4,500** (Tier A 843 = ~8 per 100 studs, Tier B 2,478 = ~4.5 per 100). 0 clipped, 0 missing, 0 KitMissing, 0 primitives, 0 skipped bus stops. Review district `Mill Street Terraces` is built in `Workspace.V3Sandbox.F` at (6000, 0, 6000): 230 props, 261 MeshParts. Plan time 0.15 s. Spacing lives in `FurniturePlan.RULES.A/.B`; ~1,180 parts of headroom are left on purpose.

**Known bugs / gaps**
1. **No street-name plate asset in the kit** (all 78 `Signs` are pole-mounted traffic signs). None placed, no primitive stand-in. Lane C: please add "UK street name plate" to the buy/generate list. Until then `SignDresser`/`TerraceStreetDresser` plates are the only street names.
2. **`UKSP__Cables__Cables` is unusable as a span**: it is one pre-arranged 34 x 34 x 184 bundle (2 parts), not a pole-to-pole piece. Poles stand without wires. Needs a single sagging-wire mesh (buy/generate) or an exceptions-register row if `WireDresser`'s wire parts are kept.
3. Sign identities were read from one catalogue screenshot (SignNew 04-10, 17-23, 30-36 seen): 04 give way, 05 reduce speed, 06 pedestrians, 09 crossroads, 19 school patrol, 20 national limit, 21 "40", 22 no entry, 31 roundabout, 33 two-way. No "30" identified, so mains use the 40 (TEMP). 04 carries a "STOP 100 yds" plate.
4. Tier A is under its 15 per 100 allowance (about 8): junction mouths eat a lot of a short street. Easy to raise in `RULES.A`.
5. Heights are constants: `PAVEMENT_Y = 0.45`, `ROAD_Y = 0.05` (cars). Lane R: tell me (or the Integrator pass `opts`) if your pavement/road tops differ. Bridges are skipped entirely (no lamps on decks).
6. Guard rails only at schools; there is no crossings data in the contract. `CrossingDresser` spots could feed it later.
7. Hatchback bonnet direction was checked on `HatchbackNavy` only (bonnet = back vector).
8. **Vehicles provenance:** the parked cars are the Creator Store keepers flagged unverified in `docs/ASSET_INVENTORY.md` s1. Used as instructed; swap the four names in `FurniturePlan.ASSETS.cars` if they are replaced.
9. **Plot boundaries (garden walls, gates, wheelie bins; 13,500 budget, "F by default") are NOT built.** Out of my kickoff scope and best done against Lane H's real fronts. Lane A / Marcel: assign it (it needs a new file pair, so a Rojo reconnect).
10. Screenshots: 4 taken in-session (sign catalogue, Spinner Street, Mill Street close, Mill Street district oblique) but the Studio MCP capture tool returns the image to the agent only and writes no file, so `docs/v3_review/F/` is empty. The sandbox shows props over void (no road or houses in F's sandbox), so a fair side-by-side with the slice needs Lane I's assembled district.

**For the Integrator (Lane I)**
- Wire: `StreetFurniture.build(townFolder, CFrame.new(), nil)` after roads and buildings. Add nothing to `RunAll` (it picks up `*Test`).
- `TownLayout.BUS_STOPS` still holds v1 positions; all 11 snapped to a road within 150 studs, but the Plot 2/3/4 stops should be re-sited by Lane A for the moved plots. A stop with no road nearby is warned about, not dropped silently.
- Retire (prop halves superseded): `StreetDresser` kit lamps / bins / parked cars and `TerraceBuilder.lamp` posts on light streets; `TerraceStreetDresser` parked cars; `WireDresser` poles; `SignDresser` nothing yet.
- Keep until replaced: `TerraceStreetDresser` street trees, front garden walls/railings/hedges and **street name plates**; `SignDresser` name plates and roundabout fingerposts; `ForecourtDresser` paving, hanging baskets, A-boards, cafe tables, planters, semis paths; `WireDresser` wires (if overhead wires are wanted; primitives, would need a register row). `StreetDresser`'s terrace-row swapping belongs to Lane H.
- Client code that looks for old names (`TelegraphPole`, `PoleArm`, `Wire` hidden on Low; lamp-post club banners in `TownLife`) will not find these props: lamps here are Models named `lamp`.

## Lane I
