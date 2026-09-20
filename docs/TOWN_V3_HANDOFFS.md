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

**Known gaps:** triangle counts need EditableMesh (Edit mode only; Creator Store meshes refuse). Tier membership is not computed by `V3Perf`; lanes test distance to the six Tier A points. Wave 1: I will review each lane's `[FCT]` line as it lands.

## Lane R

## Lane H

## Lane C

## Lane F

## Lane I
