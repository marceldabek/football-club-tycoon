# Rivermere v3 — Performance Spike and Budgets (Lane P)

> Measured 2026-09-20 in Studio Edit mode. Budgets themselves live in `docs/TOWN_V3_BUILD.md`
> section 9; this file is the reasoning. Helpers: `src/server/V3Perf.luau`.
>
> **Frame time has NOT been measured.** It needs Play on the mid-range preset and only Lane I may
> start Play. Everything here is from instance / MeshPart / triangle counts plus working
> assumptions about phones. Lane I must validate (see "Deferred to Lane I").

## 1. Headline

**The whole town at slice density does not fit a mid-range phone.** Full density is about
**90,000 MeshParts, 275,000 instances and 75 million source triangles**. The published budget is a
two-tier town of about **49,000 MeshParts**, with a worst-case **~10,000 MeshParts loaded** at the
recommended streaming radius. Still no primitives in either tier. Tiering is Marcel's call
(handoffs, Questions P1-P4).

Three surprises that change other lanes' plans:

1. **Houses are not the triangle problem; garden walls and props are.** One
   `UKSP__GardenWall__Wall` (8 studs) is 3,620 triangles, more than a whole prefab house
   (`House_02` is 3,414). Gardens cost 12,000 triangles per house; the house itself 1,900-3,800.
2. **Modular terraces are the MeshPart problem.** A two-storey, two-bay terraced unit from MEH
   modules is 15.8 MeshParts (the TEMP budget assumed ~3). 2,212 terraced units x 15.8 = 35,000.
3. **`CollisionFidelity` / `RenderFidelity` cannot be set from a script.** Assignment is silently
   ignored. The only scripted route is `CreateMeshPartAsync` + `ApplyMesh` (`V3Perf.bake`), about
   0.14 s per MeshPart, so it is done once on the kit templates, not on the built town.

Also found: the **MEH modular pieces have no texture at all** (no SurfaceAppearance, no TextureID;
they render flat pale grey), and **two kit vehicles are 66 and 131 MeshParts each**
(`VanWhite`, `HatchbackWhite`); the one-mesh hatchbacks, forklift and bus are 1.

## 2. Step zero: is the kit loaded?

`ServerStorage.Kit.Meshes` holds **464** children, exactly the 464 ids in
`assets/kit/_export/fetch_kit.luau` (the script is idempotent: it skips names already present).
Plus 18 Creator Store models in the category folders. The kit is fully loaded; nobody needs to run
the fetch.

## 3. Reference: `Workspace.VerticalSlice`

360 studs of street, houses on one side only (5 houses at a 30-stud pitch), club on the other.

| Folder | MeshParts | unique MeshIds | triangles | notes |
|---|---|---|---|---|
| whole slice | 749 | 298 | n/a | 3,208 instances, 816 primitive Parts, all 749 cast shadows, 728 Default collision |
| Houses | 6 | 6 | 29,657 | prefabs, 1 MeshPart each |
| KitStreet | 62 | 40 | 118,417 | 17 MeshParts / 100 studs |
| KitGardens | 60 | 16 | ~27,000 | 12 MeshParts per house |
| KitFences | 168 | 5 | 103,338 | mostly the club fence line |
| KitProps | 90 | 82 | 260,274 | car park / club clutter, 2,900 tris per prop |
| Vehicles | 329 | 131 | not readable | 4 cars; Creator Store meshes refuse EditableMesh |

Street dressing in the slice is therefore about **17 furniture MeshParts per 100 studs** and
**12 boundary MeshParts per house**.

## 4. Spike: `Workspace.V3Sandbox.P.SpikeStreet`

359 studs (4 `ModularRoads__Straight` at scale 0.816 = 89.8 studs each), 17 units per side at the
v3 terraced pitch of 20.5 studs. West side: MEH modular terrace (rows of 6, gable ends). East side:
MEH prefab houses. Gardens both sides (front wall, gate posts, party wall, wheelie bin). Furniture
to the slice's density. All via `KitPlacer.place`; zero `KitMissing`, zero primitive Parts.

| Group | MeshParts | unique MeshIds | triangles | per unit / per 100 studs |
|---|---|---|---|---|
| Road | 12 | 3 | 224 | 3 MeshParts and 56 tris per tile |
| TerraceModular (17 units) | 268 | 12 | 31,796 | **15.8 MeshParts, 1,870 tris per unit** |
| HousesPrefab (17 units) | 17 | 3 | 64,347 | **1 MeshPart, 3,785 tris per unit** |
| Gardens (34 units) | 374 | 5 | 410,516 | **11 MeshParts, 12,074 tris per unit** |
| Furniture | 53 | 26 | 181,895 | **14.8 MeshParts, 50,700 tris per 100 studs** |
| **All** | **724** | **49** | **688,778** | 202 MeshParts, 192,000 tris per 100 studs; 2,267 instances |

Every placed kit piece is 3+ instances (Model wrapper, MeshPart, SurfaceAppearance): instances are
about 3.1x MeshParts. Many UKSP props are 2 MeshParts (one per material); the phone box is 6.

## 5. v3 totals (from `docs/town_v3_lots.json`)

- Roads: **94 roads, 65,952 studs** (ring 8,405; main 9,553; residential 46,834; lane 1,160).
- Lots: **851**, units **2,927**: terraced 2,212 (416 rows); semis 404; detached 107;
  shops-with-flats 103; shops 37; corner shops 29; workshops 17; flats 10; warehouses 5; trade 3.
- Densest spot is around (0..200, -200..-400). Road length / units inside a radius:

| radius | worst road studs | worst units | mean road studs |
|---|---|---|---|
| 256 | 2,370 | 128 | 964 |
| 384 | 4,540 | 259 | 1,772 |
| 512 | 8,020 | 407 | 2,906 |
| 768 | 16,023 | 698 | 5,763 |
| 1,024 | 24,137 | 1,078 | 9,855 |

### Full slice density, town-wide

| | MeshParts | source triangles |
|---|---|---|
| Roads (735 tile-equivalents x 3) | 2,300 | 0.2 M |
| Housing, all modular (2,723 x 15.8) | 43,000 | 5.1 M |
| Gardens (2,723 x 11) | 30,000 | 32.9 M |
| Furniture (660 x 14.8) | 9,800 | 33.4 M |
| Commercial / civic (estimate) | 4,000 | 3 M |
| **Total** | **~89,000** (275,000 instances) | **~75 M** |

Loaded at once in the densest spot, full density: 12,200 MeshParts / 9.7 M triangles at radius 512;
33,000 / 27 M at radius 1,024.

## 6. Working assumptions for a mid-range phone

Roblox publishes no hard numbers, so these are conservative working limits, to be replaced by
Lane I's measurements:

- Loaded (streamed-in) MeshParts: aim under **10,000** worst case, ~4,000 typical.
- Source triangles loaded: aim under **8 M**; roughly a third is in the view frustum and
  `RenderFidelity = Automatic` drops distant meshes to a fraction, so about 1 M rendered.
- Unique MeshIds per street kept low (the spike used 49): identical MeshId + material batches
  into one instanced draw, so *repetition is cheap and variety is expensive*.
- Shadow casters are roughly a second draw of the mesh: only structures and tall props cast.
- Server holds the whole town regardless of streaming: ~150,000 instances is acceptable,
  275,000 is not worth the join time and memory.

## 7. Decisions

### Streaming

- Workspace (set by hand in the Properties panel; these properties are not script-accessible):
  `StreamingEnabled = true` (already), `ModelStreamingBehavior = Improved`,
  `StreamingMinRadius = 192`, `StreamingTargetRadius = 640`, `StreamOutBehavior = Opportunistic`,
  `StreamingIntegrityMode = PauseOutsideLoadedArea`.
- **Do NOT make a district one Atomic model** (this overrides the contract's default in 4.3).
  Atomic streams the whole model as soon as any part is in range: Westdale is 556 units, about
  12,000 MeshParts arriving at once. Instead:
  - District = a plain `Model` with `ModelStreamingMode = Default` (non-atomic) used for grouping.
  - **One `Model` per lot (one terrace row, one pair of semis, one shop run), `Atomic`**, so a row
    never appears half-built. A row of 6 is 60-100 MeshParts, a sensible streaming unit.
  - Roads: one Model per road, `Default` (tiles stream individually, nearest first).
  - Furniture and garden boundaries: `Default`, never Atomic. One Model per lot for boundaries is
    fine for grouping but leave it non-atomic.
  - Special blocks (church, station, town hall): each one `Atomic`.
  - Landmarks that must be seen across town (church spire, viaduct): `Persistent` is allowed for
    at most 5 models / 300 MeshParts total, registered with Lane P.
- No impostors for now. With target radius 640 plus Atmosphere haze, distant districts simply are
  not there. Revisit only if Lane I finds the skyline looks empty from the plots.

### Fidelity, collision, shadows (`V3Perf.FIDELITY`, `V3Perf.applyDefaults`)

| kind | examples | CollisionFidelity | RenderFidelity | CastShadow | collide |
|---|---|---|---|---|---|
| structure | MEH wall/roof modules, shop walls | Box (exact for flat modules) | Automatic | on | yes |
| prefab | MEH `House_0x`, garage, office | Hull | Automatic | on | yes |
| road | ModularRoads tiles | Box | Automatic | **off** | yes |
| prop | lamps, bins, benches, garden walls, fences, signs | Box | Automatic | **off unless taller than 12 studs** | yes |
| decor | manhole covers, trash bags, cones, litter, weeds | Box | Performance | off | **CanCollide/CanQuery off** |

All kit parts: `Anchored`, `CanTouch = false`. Nothing uses Default/Precise decomposition.

**Bake the templates once.** Because fidelity is not script-writable, the Integrator (or Lane P on
request) runs `V3Perf.bake(template, kind)` over `ServerStorage.Kit.Meshes` in Edit mode, in
chunks inside `task.spawn` (about 2 minutes total; a single MCP call times out). Clones then
inherit the fidelity and runtime builds pay nothing. Until that is done, builders still call
`V3Perf.applyDefaults(model, kind)` after every `KitPlacer.place`: it handles shadows, CanTouch and
decor collision today.

### Per unit vs per row

- **Assemble per row, not per unit.** A unit built on its own has two side walls; in a row they
  are shared party walls nobody sees. Build front and back faces across the row, one roof run, and
  gable walls only at the two row ends. Skip interior floors/ceilings/foundations entirely.
- Prefer the 16-stud pieces (`Wall_WindowDoor_A/B`, `Wall_WindowCentre_A/B`, `Wall_WideDoor_A`,
  `Roof_Wall_Full_A/B`): one MeshPart covers what two 8-stud pieces do. With those, a unit is
  front 2 + back 2 + roof 4 + chimney 1 = 9, plus row ends = **10 MeshParts per unit** budget.
- Backs nobody can reach (rows backing onto the river/rail) may use plain `Wall_A` for the back.
- Semis and detached: use the prefab houses (1 MeshPart, Hull collision). Cheapest thing in the kit.
- A bought terraced-house kit with whole-house meshes would cut housing from ~24,000 to ~6,000
  MeshParts. See Question P2.

### Two tiers (proposal, Question P1)

- **Tier A, full slice density:** within **450 studs of each of the 4 plots, the Market Square
  (0,0) and the station (-900,-350)**. That is 10,861 studs of road (16%) and 505 units (17%).
- **Tier B, lighter dressing everywhere else:** same roads and houses (so silhouettes never
  change), front garden wall + gate only (no party walls, bins only every third house), lamps,
  telegraph poles and junction signs only. All kit assets, no primitives.
- Per-piece triangle caps in both tiers: **boundary pieces at most 1,000 triangles** (the current
  `GardenWall__Wall` at 3,620 fails; Lane F should pick a cheaper wall/fence or have it baked at
  `Performance`), Tier B props at most 1,500.
- Everything in "decor" gets the tag **`V3Decor`** so the existing Low quality level can hide it
  (Integrator: add the tag to `Quality` handling).

Worst-case loaded set at radius 640 (densest spot, (200,-300)): full density 13,100 MeshParts;
tiered 10,100; tiered with a whole-house terrace kit about 5,500.

## 8. Deferred to Lane I (needs Play)

1. Frame time on the mid-range preset at the densest spot (200, 0, -300), at a plot, and on the
   ring road; target 30 fps. Use the MicroProfiler / `Stats` render and heartbeat times.
2. Client memory (`Stats:GetTotalMemoryUsageMb()`, plus the GraphicsMeshParts and GraphicsTexture
   categories) after walking the ring road once.
3. Whether `StreamingTargetRadius = 640` leaves visible pop-in from a plot's stand; try 512 / 768.
4. If 30 fps fails: first cut boundary triangles, then Tier B furniture, then radius. Do not cut
   houses or roads.

## 9. How lanes use `V3Perf`

```lua
local V3Perf = require(script.Parent.V3Perf)
local m = KitPlacer.place(name, cf, lotModel, opts)
V3Perf.applyDefaults(m, "prop")               -- structure | road | prop | decor
...
local c = V3Perf.count(parent)
print("[FCT] Furniture: " .. V3Perf.format(c))   -- same fields for every lane
assert(V3Perf.withinBudget(c, M.PART_BUDGET))
```

`V3Perf.count(root, { triangles = true })` adds triangle totals via EditableMesh. Edit mode only,
slow on first sight of each mesh (run inside `task.spawn` and write the result to a StringValue),
and Creator Store meshes refuse it (counted as unknown, not zero).
