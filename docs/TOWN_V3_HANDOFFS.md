# Rivermere v3 - Handoffs

Shared noticeboard for the lanes in `docs/TOWN_V3_BUILD.md`. Append under your lane; never edit another lane's entry.

## Status

- [x] **Lane A 2026-09-20 16:30: `TownLayout` v3 and `TownFrontage.luau` are live (868 lots). `Lot.yaw` convention and lot ids changed: read "CONTRACT CHANGES" under Lane A.**
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

**From Lane A (layout and generator)**

- **A1. 903 blocks vs v1's 682: merge semis and detached into one lot per run?** Today a run of 8 semis is 4 lots and a run of detached houses is one lot each (209 + 107 = 316 lots, 36% of the town). Lane P wants one Atomic Model per lot, so lot count is streaming-unit count, not part count: merging saves no MeshParts. *Recommendation: do not merge. Small Atomic units stream in more smoothly, `units` already tells Lane H how many houses a lot holds, and merging would make a 300-stud run of detached houses arrive as one lump. Revisit only if Lane I measures per-Model overhead as a problem.*
- **A2. Give the eight streets that stop at the central railway a turning head?** Weaver Street, Elm Grove, Signal Street, Lock Street, Lune Street (west end), Viaduct Road, Weir Road and Fuller Street end blind at the tracks, as they did in v1. Westdale's five are fixed already. *Recommendation: yes, shorten each by about 40 and add `head = true`; it costs roughly one terrace each and the kit has the CulDeSac piece. Ten minutes of work, but it changes the approved picture, so I want your yes.*
- **A3. Re-space junctions for Lane R's T pieces?** About 15 junction pairs are closer than one kit T piece (90 studs), so Lane R tucks one road under the other and the verge runs across the mouth. Fixing it means sliding side streets 30 to 60 studs (for example Church Lane / Tanner Row on High Street, Hollins Road / Dye Works Lane on the ring). *Recommendation: wait until you have looked at the tiled roads in the assembled town, then give me the list of mouths that actually look wrong; most are minor streets where a tuck may be fine.*
- **A4. The industrial estate now has 3 warehouses, not 5.** Two were standing across Forge Lane and Furnace Lane in the approved drawing. *Recommendation: accept for now; if it reads empty, I widen the gaps between the three lanes (320 apart today, a warehouse cell is 160) rather than shrink the warehouse.*

## Lane A

**Done 2026-09-20 16:30 (commit d676591 + docs).** Steps 2 to 5 of the lane.

- `TownLayout.luau` is v3: 94 ROADS with `front / use / useAt / district / head`, `HEAD_RADIUS = 34`, plots 2/3/4 moved (3 is yaw 270 now), lanes, plot bus stops re-sited, "Lunebank Roundabout", DISTRICTS cut to the 35 hand-placed specials (districts with none keep an empty entry; Mapleford, Millbrook, Hollingford added). 1,462 lines down to about 1,050.
- `TownFrontage.luau` is the generator and the source of truth: **868 lots** (terraced row 416, semis 209, detached house 107, corner shop 46, shops with flats 36, shops 18, workshop 18, flats 11, trade counter 4, warehouse 3; `python tools/town_v3_parity.py` prints it per district too). Builds in about 1 s. Extras beyond the contract: `build()` (uncached), `lotCFrame(lot)`, `lotCorners(lot, grow)`, `RULES`, `HOMES`.
- Python is the drawing tool only. `tools/town_v3_emit.py` writes ROADS / PLOTS / ROUNDABOUTS into the Luau (`--check` to verify), `tools/town_v3_parity.py --write` pins the Python digest into `TownFrontageTest`, which asserts the Luau generator matches it (counts per use, per district, position sum, id sum). They matched first time and after every change since.
- Tests: `TownFrontageTest` 14/14 (new, strict), `TownLayoutTest` 32/32 (8 new, 6 v1 pins rewritten for v3 with the reason in a comment, none weakened; block checks now handle any yaw). Full suite at 16:20: **738 passed, 4 failed** (below).
- `docs/TOWN_PLAN.md` sections 2, 3, 6 regenerated from the data; `docs/PLOTS.md` has the v3 plot table. `docs/town_v3_lots.json` and the v3 map images are regenerated.

**CONTRACT CHANGES every builder lane must know**
1. **`Lot.yaw` is Roblox convention** (it was the maths angle in the first JSON, which mirrors every 45 degree lot). Use `TownFrontage.lotCFrame(lot)`. The JSON now matches. Axis-aligned lots are unaffected; Hollingford's 57 diagonal lots were mirrored before. `lot.front` is unchanged and still the right way to find the street side.
2. **Lot ids** are now `"<road>|<side>|<segment index>|<n>"` as the contract says (they carried a Python tuple before). Anything seeded from `Lot.id` will reshuffle once.
3. Lots moved: 851 to 868. Clearance is now tested every 10 studs round a cell, not at 9 points: three warehouses were standing across Foundry Way, Forge Lane and Furnace Lane in the approved drawing. Also nothing generates within 16 of a bus stop.
4. Section 4.3 now says one Atomic Model per LOT inside a non-atomic district Model, as Lane P asked.

**Deliberate layout changes from the approved picture** (all visible in `docs/town_map_v3.png`): Lune Street runs on east to a turning head so the waterfront flats front a street (the "1 of 120 with no frontage"); Westdale's five E-W streets end in turning heads at x = -730, short of the railway; Estate Road runs out to the town edge; Elder Close and Oak Close are 25 / 5 shorter so their heads clear the ring; the Northfields green (was straddling the ring chamfer) is at (1155, -675); the Hollingford river meadow is at (1600, 80), clear of the river; Northfields parade shops moved 5 off North Road's pavement; Westdale park 140 wide at (-820, 1175); Riverside and Riverside Park bus stops moved onto the pavement; seven connecting streets that can never hold a lot are `front = "none"`. The four auto-nudged centre blocks, the Westdale school and the moved pub now carry their coordinates as plain data with a comment; `push_clear` is gone.

**Other tests that now fail (expected, not edited; Integrator's to retire or re-point)**
- `StreetDresserTest.lightStreetsPickTheDistrictsResidentialStreets`: "Northfields streets missing". StreetDresser finds a district's streets from its housing blocks in DISTRICTS; there are none now.
- `EstateBuilderTest.layoutSemisPlotsStayInsideTheirBlocks`: "no semis blocks found". Same cause.
- `TerraceStreetDresserTest.millStreetMeetsNorthRoadOnly` (expects 1 junction, gets 6) and `.signsStandOnTheCornersPastTheMouth` (expects 2 signs, gets 11): Mill Street is crossed by the new centre grid streets.

**For the Integrator: v1 assumptions that pass tests but will build nothing or the wrong thing**
- 27 server files loop `TownLayout.DISTRICTS` looking for housing/shop/industrial blocks (`EstateDresser`, `ForecourtDresser`, `ImperfectionDresser`, `TerraceStreetDresser`, `StreetDresser`, `ShopDresser`, `GreeneryDresser`, `TownBuilder` 831/843, `AmbientAudio.client` 85/191...). With specials only they silently do nothing for housing. Point them at `TownFrontage.lotsByDistrict()` or retire them in favour of lanes H/C/F.
- Road names hardcoded outside TownLayout: `WireDresser` (3), `ImperfectionDresser` (2), `GatewayDresser`, `StationDresser`, `StreetDresser`, `TownBuilder` (1 each). All the names still exist, but Mill Street / Weaver Street now have cross streets, and Greenbridge Road runs due west instead of to the south-west corner (check `GatewayDresser`).
- No literal v1 plot or road coordinates found outside TownLayout (`TownLifeMath` river boat points, `StreetFurniture` tier points and `RiverDresser`'s Plot 1 fallback are all unmoved places). `PlotService.luau:125` has a plot-local camera; fine.
- Plot 3 faces north now (yaw 270, was 0). Anything keyed to plot index rather than `plotCFrame` needs a look.
- Special `yaw` may be non-multiples of 90 (the Hollingford meadow is 45); v1 dressers that build an axis-aligned rect from `block.size` should use a CFrame.
- Lane R bug 1 (junctions closer than one T piece): not done. It is a layout change to about 15 junctions; I would rather do it as one deliberate pass after Marcel has seen roads tiled than nudge streets blind. Ask and I will.
- Lane F item 9 (plot boundaries unassigned): needs an owner; I have not created files for it.

**Known bugs**
- 14 streets stop dead with no turning head (listed with reasons in `TownLayoutTest.KNOWN_DEAD_ENDS`; a new one fails the test). Eight of them end at the central railway exactly as v1 did.
- Industrial Estate is thin: only 3 warehouses fit now that they may not straddle the lanes (25 lots in the district).
- Lot yaw is not normalised (one head row is -270); harmless through `lotCFrame`.
- `tools/town_map.py` on its own now draws roads and specials only; `town_plan_v3.py` is the full map. Sections 5, 7, 8 of TOWN_PLAN.md are still v1 text.
- The v3 map PNG/SVG are regenerated on every `town_plan_v3.py` run, so they show as modified after any run.

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

**Done 2026-09-20 16:26.** `HouseRecipes` (pure data + selection) and `HouseAssembler` build every `terraced row`, `semis` and `detached house` lot from `TownFrontage.generate()`: 732 lots, 2,681 units. 22 tests pass (`HouseRecipesTest` 9, `HouseAssemblerTest` 13), all four files `loadstring` clean. No primitives, no exceptions-register entries.

**Whole-town count (real data, `HouseAssembler.build(holder, CFrame.new(), nil)`, 2.9 s in Edit):**

| | MeshParts | Section 9 budget |
|---|---|---|
| Houses | **20,739** | 24,000 |
| Boundaries (garden walls, back fences, bins) | **10,830** | 13,500 |
| Unique MeshIds | 38 town-wide | 60 per district |
| KitMissing / primitive Parts | 0 / 0 | 0 |

Per unit (houses + boundaries): terraced Tier A 9.0 + 8.8, Tier B 7.4 + 3.3; semis 10.4 + 8.9 / 9.5 + 3.3; detached 8.4 + 8.2 / 8.4 + 2.9. 91 of 732 lots are Tier A.

**Kit facts worked out (also in the `HouseRecipes` header):** module grid 8.25 studs (3 m), storey 8.25, walls 8.25 or 16.5 wide, pivots at bounding-box bottom centre, exterior faces -Z at yaw 0, walls are single-sided. Decision: every house is a 2 x 2 module body (16.5 square) under ONE uniform scale = unit frontage / 16.5 (about 1.25: storey 10.3, door 6.6 studs). Real frontage per unit is `size.X / units` (18 to 21), not `unitWidth`, because the row gap comes out of the lot. Three modules would need scale 0.84 (4.4-stud doors) and 50% more parts.

**Textures:** the 67 untextured modular pieces take the prefab trim sheet (`MEH__House_02_VAR1__ts1/ts3` SurfaceAppearance), same trick as Lane C. `ts1` leaves an existing SurfaceAppearance alone so a fixed export wins; `ts3` always swaps, which is what gives each row one of two trims (dark brick, pale render).

**How the count is kept low (each is one field in `HouseAssembler.PRESETS`):** no party walls, floors or ceilings; gables only at row ends; one double-scale `Wall_A` as the whole back of a ROW; each roof slope is one `Roof_A` stretched across the unit (Tier A) or the whole row (Tier B); one boundary piece per run either side of the gate, stretched to fit (`boundaryStretch`); `flatten` drops KitPlacer's wrapper Models. `PRESETS.lean` (6 parts a unit, no boundaries) is the brake if the budget is cut again. Detached lots draw the 1-part `House_02` prefab 3 times in 7.

**Section 9 rules followed:** district Model `Default`, one `Atomic` Model per lot (attribute `LotId`), boundaries in a separate non-atomic `Boundaries` model (attribute `BoundaryLotId`), `V3Perf.applyDefaults` after every place ("structure" / "prop"), tiers from distance to the 4 `TownLayout.PLOTS`, (0,0,0) and (-900,0,-350), `[FCT]` lines with `V3Perf.format`.

**Deviations from the brief, on purpose:** the UKSP `WoodFences` (about 8,000 triangles each), `TrashBags` (11,400) and `GardenWall__Wall` (3,620) fail the 1,000-triangle cap, so back fences are `MEH__Wood_Fence_A` (352) and clutter is the wheelie bin only (`TrashcanBase` 1,344 + lid 352, Tier A, one yard in three: slightly over the cap, Lane P to rule). `RailingWall__Wall` (1,144) and `WallBStraightWithRailing` (1,320) are Tier A only.

**Known bugs / rough edges**
1. `Lot.corner` does not say WHICH end meets the junction, so corner terraces get the windowed gable (5 parts) on both ends. A `cornerEnd: "start"|"end"|"both"` field from Lane A would save about 900 parts.
2. The blank side and back walls are `Wall_A` at double scale, so their bricks are twice the size of the front's, and on `ts1` the plain wall maps to red brick while the window walls are dark brick (it is how the trim sheet is laid out).
3. The Tier B row roof is one slope stretched up to 14x; it reads as banded slate from the street, but look at it from a stand roof before shipping.
4. Single-unit `semis` lots are 13 wide; the scale clamps at 0.85, so that house overhangs its lot by half a stud each side.
5. `Wall_Window_I` did not render in my first hand assembly (cause not found); no recipe uses it.
6. No side boundary between neighbouring gardens and no return walls at row ends.
7. `MeshPart.DoubleSided` is off on the kit walls, so interiors are see-through from behind; nothing is built to be entered.
8. Screenshots could not be written to `docs/v3_review/H/`: the MCP capture returns the image to the agent only. Viewpoints to re-shoot (sandbox origin (0,0,-6000), Station district is built there now): street level `(-1105, 9, -5846)` looking at `(-1000, 9, -5875)`; the slice pair is the review spawn `(2986, 1, 2170)` looking north.

**Integrator must wire:** `HouseAssembler.build(townFolder, CFrame.new(), nil)` once at town build. Both test modules are picked up by name. **Retire:** `TerraceBuilder`, `EstateBuilder`, the housing part of `TerraceStreetDresser` (and check `EstateDresser`, which dresses the estates `EstateBuilder` made). Lane F: front boundaries, back fences and bins are already built here, under `Housing_<district>.Boundaries`; do not add a second set.

**Bigger lever for Lane P / Marcel:** every recipe uses one trim sheet, so each of the 19 recipes could be baked offline into ONE mesh (19 meshes + 2 end caps). Housing would fall from 20,739 to about 4,200 MeshParts with the same look. The recipes are already the bake list.

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

### Lane I stage 1 (wiring) - done 2026-09-20 16:36

**Wired (Main.server.luau, after `Backdrop`, before the dressers), all with `origin = CFrame.identity`, each into its own holder Folder under `workspace.Town` so its V3Perf count is its own:** `RoadTiler` -> `Town.V3Roads`, `HouseAssembler` -> `Town.V3Housing`, `TradeAssembler` -> `Town.V3Trade`, `StreetFurniture` -> `Town.V3Furniture`.

**Playtest [FCT] lines (town ready in about 10 s):** Roads 677 tiles / 2,110 MeshParts of 2,600; Housing 732 lots, 20,739 house + 10,830 boundary MeshParts (24,000 / 13,500); Trade 156 lots, 2,763 MeshParts of 4,000; Furniture 2,865/2,865 placed, 3,327 parts of 4,500, 0 clipped, 0 missing. **KitMissing under Town: 0 (0 in the whole place).** Console errors after the fix below: none.

**Bug found by the playtest and fixed:** `V3Perf.count` read `SurfaceAppearance.ColorMap`, which throws "lacking capability Plugin" in a running server (fine in Edit). It killed Main after the Housing line, so no Trade, Furniture, dressers or PlotService. It is a pcall now; in Play `uniqueTextures` only counts `TextureID`. (So Play was started twice: once to find this, once to confirm.)

**Retired (deleted):**
- `TownBuilder`: carriageway slabs, bend joints, pavements, verges, roundabout discs, `freeRuns`, `VERGE_ROADS / VERGE_WIDTH` and their two tests. `Town.Roads` now holds only the Market Square disc. Greybox volumes are no longer built for the specials TradeAssembler builds.
- `StreetDresser.build` and everything only it used (kit / light rows, lamps, bins, cars, `lightStreets`, `streetCoverage`). The file is now 186 lines of pure street maths that six other files still read. Its `TerraceBuilder` / `KitPlacer` requires are gone.
- `ShopDresser.build` (the file keeps `facingYaw / placement / handles`, read by ForecourtDresser and ImperfectionDresser).
- Tests removed, reason left in place: `StreetDresserTest.lightStreets...`, `EstateBuilderTest.layoutSemisPlotsStayInsideTheirBlocks` (walked v1 semis blocks), `TownBuilderTest.freeRuns...` and `.vergeRoads...`. Tests re-pinned to v3, stricter not weaker: `TerraceStreetDresserTest.millStreetMeetsNorthRoadOnly` (6 junctions, 4 of them through) and `.signsStandOnTheCornersPastTheMouth` (11 plates, the 2 at North Road still position-checked).

**Disabled behind a named constant, NOT deleted (untangling is stage 2 work):**
- `TerraceStreetDresser.V3_HOUSING_RETIRED` (front gardens) and `.V3_PARKED_CARS_RETIRED`. Trees and name plates still build, but only on the DRESSED showpiece streets: light streets are chosen by "has terraced-row blocks in DISTRICTS", which is never true now (0 light streets).
- `EstateDresser.V3_BLOCKS_RETIRED` (semis, warehouses, workshops, trade counters, builders yard). Name stones, play area, banners and roundabout shrubs still build.
- `SportsCentreDresser.V3_HALL_RETIRED` (TradeAssembler owns the sports hall).
- `V3_OVERHEAD_WIRES = false` in Main: `WireDresser` is not called. Its poles are superseded and Lane F's poles stand elsewhere, so the wires would hang from nothing.
- `TradeAssembler.OWNED_ELSEWHERE = { church = "SquareDresser" }`: the live build skips the church, because SquareDresser places the same keeper plus the churchyard. `buildLot` still builds one for tests.
- Also: `RoadTiler.PART_BUDGET` 1,200 -> 2,600 (Lane P's published number).

**No module could be deleted whole.** `TerraceBuilder` (`lamp` used by ParkDresser and MarinaDresser; `row / TEXTURES` by ShopBuilder), `ShopBuilder` (`bays`, `GROUND_FLOOR`, `SHOP_FRONTS` read by ForecourtDresser) and `EstateBuilder` (EstateDresser, ForecourtDresser) are dead as builders but still required. No file was added or deleted on disk, so **no Rojo reconnect is needed for stage 1**.

**Suite (Edit mode, after all changes): 743 passed, 0 failed.**

**Seen in the playtest, not fixed (one screenshot, Mill Street from (120, 60, -120))**
1. Kit road verges are bright lime green against the darker terrain grass; every road reads as a green stripe.
2. Roads are one Atomic Model per district; v1 roads were `Persistent` (X62: traffic drove over grass when far roads streamed out). Only a short stretch of road was visible from the camera. Decide Persistent vs streamed.
3. `[FCT] crossings: 0 tactile slabs (264 spots off the pavement)`: CrossingDresser and StationDresser raycast for parts named "Pavement", which no longer exist.
4. `ImperfectionDresser` still lays 900 primitive parts (523 lane dashes, patches, grates, manholes, give-ways) at v1 road heights on top of kit roads that already carry markings; StreetFurniture also places manholes and give-ways, so those are doubled.
5. `ForecourtDresser` still builds 8 forecourts, 20 hanging baskets, 5 A-boards and 2 cafe sets positioned for ShopBuilder facades that no longer exist (0 awnings / signs / window boxes because it finds no ShopRow models). Probably floating against the TradeAssembler buildings.
6. Housing trims look right; blank gable walls show the double-scale brick Lane H described.
7. Three church pieces remain: TownBuilder's landmark tower (8 parts), the church greybox (removed by SquareDresser when the kit loads) and SquareDresser's keeper (238 primitive parts, EC7).
8. `TerraceStreets.ParkedStreets` still lists the showpiece streets although that dresser parks nothing now; Traffic.client does not know where StreetFurniture parks cars.
9. Not checked: bridges over kit roads (Lane R bug 5), plots vs lanes, bus stops (TownBuilder's primitive stops, 120 parts, AND StreetFurniture's 11 shelters both exist).

**To do in stage 2**
- A. Delete for real once re-pointed: `StreetDresser` (move `stations / polylineMidpoint` to a shared maths module; re-point the `lampPositions` users CentreTreeDresser, TerraceStreetDresser, WireDresser at `FurniturePlan`); `ShopDresser` + `ShopBuilder` + their tests (rewrite or delete ForecourtDresser's facade half; ImperfectionDresser lines 44 and 1128); `EstateBuilder` + the building half of `EstateDresser` + `EstateBuilderTest` (users: ForecourtDresser 867-880, SportsCentreDresser, StationDresser, YardWorkers.client, PlayAreaLife.client); `TerraceBuilder` (swap `lamp` in ParkDresser 1054 and MarinaDresser 342 for the kit lamp; TownLife.client 188 looks for its lamp model); the garden / car code in `TerraceStreetDresser`; `SportsCentreDresser.buildHall`; `WireDresser`.
- B. Files that loop `TownLayout.DISTRICTS` for housing / shop / industrial blocks and now silently do nothing: `TerraceStreetDresser` (frontsFor, light streets), `EstateDresser`, `ForecourtDresser`, `ImperfectionDresser`, `GreeneryDresser`, `StreetDresser.isKitRow`, `AmbientAudio.client` 85 / 191. Point them at `TownFrontage.lotsByDistrict()`.
- C. Client files keyed to retired instance names: `TownLife.client` (TerraceLamp banners, 188 / 326), `LitWindows.client` 156 (ShopBuilder Shopfront faces), `Traffic.client` 445-452 (ParkedStreets), `YardWorkers.client` (EstateBuilder sheds), `CafeSitters.client` (ForecourtDresser tables), `PlayAreaLife.client`, `TownLifeMath` 173-177 (Shopfront drinkers), and the Low-quality hiding of `TelegraphPole / PoleArm / Wire` (should hide the `V3Decor` tag).
- D. Hardcoded road names: `WireDresser` (3), `ImperfectionDresser` (2), `GatewayDresser` (Greenbridge Road now runs due west), `StationDresser`, `TownBuilder` (1). Plot 3 is yaw 270: check anything keyed to plot index.
- E. Primitive dressers still live, to audit against the no-primitives rule (parts in this playtest): Riverside 1,001, Imperfections 900, Square 533 + church 238, Park 477, Greenery 448, Bridges 384 + TownBuilder bridges 64, Station 336, Marina 324, Signs 222, Forecourts 208, TerraceStreets 158, SportsCentre 155, BusStops 120, Estates 110, Rail 66, Viaduct 56, Schools 38, plus CentreTrees, Gateways, Crossings, Backdrop, Landmarks 8, Districts greybox 17.
- F. Decide the duplicate owners: bus stops (TownBuilder vs StreetFurniture), manholes / give-ways (ImperfectionDresser vs StreetFurniture), church tower.
- G. Lane P items not done here: Workspace streaming properties by hand, `V3Perf.bake` (waits on Marcel's P4), Quality Low hiding `V3Decor`, frame time.

### Lane I stage 2 (old code agrees with v3) - done 2026-09-20 16:54

**Suite (Edit mode, after all changes): 750 passed, 0 failed** (743 + 7 new). Three playtests and three screenshots used. Last playtest: 0 errors, 0 warnings, 0 KitMissing, 11 of 11 bus stops on a kit shelter. Bus travel Town Centre -> Plot 3 was tried in playtest 1 and landed on the pavement at (-1826, 574). Primitive parts under `workspace.Town`: about 6,900 in stage 1 -> **4,762** (40,012 MeshParts). No file added or deleted: **no Rojo reconnect needed**.

**Bug found by the playtest and fixed:** the town build is one resume of 10+ s, and Studio's script timeout killed Main inside `EstateDresser:958`, so every dresser after it, PlotService and BusService never ran (playtest 1 passed by luck, playtest 2 did not). `Main.server.luau` now calls `task.wait()` after each v3 builder and each dresser; playtest 3 ran clean.

**1. Built twice / on top of the new town**
- `ImperfectionDresser` OFF: `V3_PRIMITIVE_IMPERFECTIONS = false` in Main (900 primitives at v1 road heights; kit roads carry markings, StreetFurniture places manholes, give-ways, bins, cones).
- Bus stops: `TownBuilder.V3_PRIMITIVE_BUS_SHELTERS = false`. TownBuilder now makes one invisible anchor per stop (E2). `BusService.start` finds StreetFurniture's `shelter` models, moves each stop's anchor and prompt onto the nearest one (`SHELTER_SEARCH = 300`) and uses that position for the travel range check, the menu's `stopPosition` and the arrival point (`shelterStand`: 3.5 studs toward the road, facing the shelter). Drift from `BUS_STOPS` to the real shelter: 0-7 studs for town stops, 19-56 for plot stops. Lost: the stop-name flag and timetable (primitive); the kit shelter has no name on it.
- `ForecourtDresser.V3_SHOPS_RETIRED = true`: shop forecourts, cafe sets, A-boards, baskets, awnings, pub signs, semis paths (all positioned off ShopBuilder / EstateBuilder facades). The Market Square pedestrian zone and 8 planters still build (124 parts).
- `V3_PRIMITIVE_TACTILE_SLABS = false` in Main: CrossingDresser placed 0 of 264 (it looked for "Pavement" parts).
- Church: checked, already single. SquareDresser destroys TownBuilder's tower and the greybox when the keeper loads.
- Lime verges: `RoadTiler.VERGE_TINT` on the verge MeshPart's SurfaceAppearance. `RoadTiler.vergeOf` finds the verge by shape (ColorMap is unreadable in Play); a test checks it against the grass texture for all 44 pieces. **The tint value is not settled**: (150,158,118) was a dark saturated green, (255,185,200) mustard; the committed (240,212,235) has NOT been looked at.
- Road district models are `Default` streaming now, not `Atomic` (section 9 rule 1); RoadTilerTest re-pinned deliberately. Persistent vs streamed for traffic is still open.
- Parked cars: StreetFurniture publishes `ParkedStreets` on `Town.V3Furniture` (53 streets); `Traffic.client` reads it; TerraceStreetDresser publishes an empty list.

**2. Hardcoded v1 coordinates.** `BUS_STOPS` was already re-sited by Lane A (every stop is 4-37 studs from a road edge; plot stops sit about 410 from their plot centre). `PlotService.FALLBACK_SITES` (v1 corners, Plot 3 at (2000, 0)) deleted; `plotCFrame` errors if TownLayout is missing. Grepped for 1950 / Plot 3 Roundabout / Moss Lane / Hollins Road / Greenbridge and for 3-4 digit Vector3 / CFrame literals outside TownLayout: nothing else stale. GatewayDresser is data-driven and right for the new Greenbridge Road. River boats in TownLifeMath still sit on the river. `GroundInfluence` / `MatchdayRoutes` literals are plot-local. No code is keyed to a plot index.

**3. DISTRICTS loops**
- `GreeneryDresser`: a district's area is now its TownFrontage lots; `clear()` rejects any point within `LOT_CLEAR = 3` of a lot (grid-hashed); MAX is shared evenly over the 7 housing districts and halved to 260 (520 spots came to 1,188 primitives). Two new tests.
- `AmbientAudio.client`: the industrial hum box comes from roads with `useAt = "industrial"` (+70). Pub / cafe emitters still work, they read specials. TownFrontage is NOT generated on the client (it costs 0.7 s).
- Left alone because they only read specials, which DISTRICTS still has: EstateDresser (stones, play area, totem), SchoolDresser, SquareDresser, SportsCentreDresser, StationDresser.
- Still dead and not untangled: `TerraceStreetDresser` light streets (0), `StreetDresser.isKitRow`, `ImperfectionDresser.terraceBlocks` (module is off).

**Switched off by named constant (on top of stage 1's list):** `V3_PRIMITIVE_IMPERFECTIONS`, `V3_PRIMITIVE_TACTILE_SLABS` (Main); `TownBuilder.V3_PRIMITIVE_BUS_SHELTERS`; `ForecourtDresser.V3_SHOPS_RETIRED`.

**4. Primitive dresser audit** (primitive Parts / MeshParts, playtest 3). Converted this stage: Imperfections (900 -> 0), bus shelters (120 -> 11 invisible anchors), park and marina lamps (9 kit `StreetLight01`, was 54 parts), forecourt shop dressing (84). New register row **EI1** (trees).

| Dresser (Town child) | Prims | Mesh | What the primitives are | Kit replacement, or register id |
|---|---|---|---|---|
| Riverside | 955 | 46 | promenade slabs, railings, moorings, planters, steps | railings: UKSP fence / guard-rail rows; slabs are ground (E1); the rest has no asset (EC6) |
| Greenery | 599 | 0 | trees, shrubs | EI1: no usable tree asset |
| Bridges (TownBuilder 64 + BridgeDresser 440, viaduct included) | 504 | 0 | decks, parapets, piers, arches, lamps | none in kit; needs a register row and a bridge on the buy list |
| Square | 419 | 114 | paving, stalls, clock tower, planters | paving E1; stalls / clock tower: none, needs a row |
| Park | 419 | 23 | paths, bandstand, picnic tables, fences, trees | picnic tables: `UKSP__PicnicBenches__BenchNew/Old` (cheap win, not done); fences: UKSP fence rows; bandstand EC6; trees EI1 |
| StationFront | 319 | 17 | station building, canopy, platforms, signs | EC6 (s8 #4) |
| Marina | 296 | 18 | quay, pontoons, boats, clubhouse | EC6 |
| Signs | 222 | 0 | street name plates, finger posts | text signs: keep, needs a row |
| Church keeper | 220 | 18 | the keeper itself | EC7 |
| TerraceStreets | 158 | 0 | street trees, name plates | EI1; plates as Signs |
| SportsCentre | 149 | 6 | pitches, goals, fences, car park | pitches E1; fences: UKSP fence rows |
| Forecourts | 124 | 0 | square zone slabs (36), 8 planters | E1; planters EI1 |
| Estates | 110 | 0 | name stones, play area, totem, shrubs | play equipment: none, needs a row |
| CentreTrees | 72 | 0 | trees in pits | EI1 |
| Rail | 66 | 0 | track bed, rails | none, needs a row |
| Schools | 38 | 0 | playground markings, fences | fences: UKSP; markings E1 |
| Churchyard | 31 | 1 | walls, gravestones | a cheap UKSP wall piece (not `GardenWall__Wall`, 3,620 tris) |
| V3Roads | 19 | 2,110 | roundabout stand-ins | E3 |
| Gateways | 18 | 0 | welcome and route signs | text signs: keep, needs a row |
| Districts | 12 | 0 | ground-use greybox (lawns, pitches, car park) | E1 |
| BusStops | 11 | 0 | invisible prompt anchors | E2 |

The "what the primitives are" column comes from file headers and greps, not a part-by-part read. None of the old dressers' parts carry a `V3Exempt` tag; only RoadTiler, the church keeper and the new bus anchors do.

**Left for stage 3**
- Walk each plot (Plot 3 yaw 270; plots vs lanes; bus arrival at the 4 plot stops, which drift 19-56 studs from the layout position); bridges over kit roads (Lane R bug 5).
- Look at the verge tint and settle it. Check the park / marina kit lamps face the path (the quarter turn is taken from FurniturePlan's facing note, not looked at).
- Performance: Workspace streaming properties by hand, Quality Low hiding `V3Decor` (and dropping the TelegraphPole / Wire names), frame time at (200, 0, -300), roads Persistent or not. `V3Perf.bake` still waits on P4.
- Stage 1 to-do A (deleting StreetDresser, ShopDresser + ShopBuilder, EstateBuilder, TerraceBuilder, WireDresser, and now ImperfectionDresser and CrossingDresser, with their tests) was NOT started: all are file deletes, so batch them behind one Rojo reconnect. TerraceBuilder is now only required by ShopBuilder.
- Stage 1 to-do C, client files keyed to retired names, NOT done except Traffic: `TownLife.client` (TerraceLamp banners; the park lamps are now named `ParkLamp`), `ClubStickers.client` 76, `LitWindows.client`, `YardWorkers.client`, `CafeSitters.client` (no cafe sets exist now), `PlayAreaLife.client`, `TownLifeMath` Shopfront drinkers. ClubStickers, GreeneryDresser, SquareDresser and others still measure from `BUS_STOPS` positions rather than the shelters (small drift, harmless so far).
- Bus stop name: nothing on the kit shelter says which stop it is. A SurfaceGui on the invisible anchor would do it without a primitive.
- Docs: TOWN_PLAN / PLOTS / ASSET_KIT still describe the v1 dressers; register rows wanted for bridges + viaduct, rail, square stalls + clock tower, name plates / text signs, play equipment.
