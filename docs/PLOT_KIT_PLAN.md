# Club Plot — Kit Dressing Plan

> Decided 2026-09-19. The wider town stays as it is. **The club plot and the ground around it get
> built from the bought kit at vertical-slice density**, not from primitives.
>
> Why: the slice (`Workspace.VerticalSlice`, spawn `(2986, 1, 2170)`) proved the kit looks good at
> block scale. The town does not, because town-scale part budgets force primitives. So spend the
> mesh budget where the player actually stands.

## Rules for this pass

1. **`KitPlacer.place(name, cf, parent, opts)` for everything placeable.** It already falls back to a
   grey block when a name is missing, so a half-installed kit never breaks the build.
2. **Follow the slice, not the town.** `tools/kit/place_slice_A_fences.luau`, `_C_street.luau` and
   `_D_props.luau` are the working reference for pivots, grounding and run-laying. `docs/SLICE_PLAN.md`
   is the density to aim for.
3. **Layout data stays in code.** Everything must rebuild from git (CLAUDE.md s27, Q26). No
   hand-placed Studio-only geometry on the plot.
4. **Verify in Studio before committing.** There is no local Luau parser on this machine, so a closed
   Studio means the work cannot be checked. Run `RunAll` (Edit mode) after each file.
5. **Hard stop when the plot reads like the slice.** No backlog extension, no loop.

## Step 0 — before any code

- Open Studio, **click Connect in the Rojo panel** (it owns only `ReplicatedStorage.Shared`,
  `ServerScriptService.Server`, `ServerStorage.Tests`, `StarterPlayerScripts.Client` — it will not
  touch `ServerStorage.Kit`, `ReplicatedStorage.ClientKit`, `ParityProbe` or `VerticalSlice`).
- Run `RunAll`. Expect **582 passed**. The X368 economy rework is parked in `stash@{0}` and is still
  in the place file until Rojo overwrites it; if two `EconomyTest` cases fail, Rojo has not synced.
- Run `assets/kit/_export/fetch_kit.luau`. **Only 96 of 299 uploads are currently in
  `ServerStorage.Kit.Meshes`** — two thirds of the kit is not loaded.

## Target file

`src/server/PlotGrounds.luau` (1,096 lines) — currently **zero** `KitPlacer` calls, all primitives.
Its header holds the full pitch-local layout spec; keep those coordinates, change what fills them.

## Swap table

Counts are items uploaded and available.

| Plot element (PlotGrounds header) | Today | Kit to use | Avail |
|---|---|---|---|
| Boundary wall, edge ±380 | 1×3 parts | `UKSP__Fences__*`, `UKSP__CorrugatedFence__*`, `UKSP__GardenWallA/B__*`, `UKSP__RailingWall__*` | 21 / 6 / 8 / 4 |
| Vehicle gate, x −380, z 60..100 | gap in wall | `UKSP__Fences__*` gate + posts, `UKSP__ConcreteBarriers__*` | 21 / 8 |
| Pedestrian gate, x −380, z −20..−4 | gap in wall | `UKSP__GuardRails__*`, `UKSP__RailingWall__*` | 10 / 4 |
| Access road, x −379..−349 | asphalt part | keep surface; add `UKSP__GuardRails__*`, `UKSP__TrafficCones__*`, `UKSP__RoadWorksSign__*` | 10 / 10 / 6 |
| Car park, x −350..−250 | asphalt + bays | keep surface; **`UKSP__Signs__*` (78)**, `UKSP__armcoBarrier__*`, `UKSP__TrafficProps__*` | 78 / 3 / 21 |
| Footpath, z −12 | concrete strip | `UKSP__StreetLights__*`, `UKSP__ParkBenches__*`, `UKSP__LitterBin__*`, `UKSP__RedPhoneBoxes__*` | 3 / 4 / 1 / 4 |
| Training fence, x 222..338 | primitive fence | `UKSP__WoodFences__*`, `UKSP__Fences__*` | 15 / 21 |
| Yard clutter (new) | none | `UKSP__Skips__*`, `UKSP__dumpster__*`, `UKSP__TrashBags__*`, `UKSP__WoodPallets__*`, `UKSP__boxes__*`, `UKSP__TrachCan__*` | 2 / 6 / 6 / 9 / 9 / 2 |
| Matchday dressing (new) | none | `UKSP__CrowdBarrier__*` — the slice review flagged these as missing | 4 |
| Approach / bus stop | primitive sign | `UKSP__BusShelter__BusShelter`, `UKSP__TelegraphPoles__*` | 1 / 15 |
| Club shop, x −313..−287 | brick primitives | **leave primitive for now** — no shop-unit mesh in the kit; it uses an uploaded shopfront texture | — |

## Order of work

1. **Boundary wall + both gates.** Longest run, seen from every approach, and it is the first thing
   that reads as "a real ground" from the street. Judge this one edge before going further.
2. Footpath furniture and the pedestrian approach (lamps, bench, bin, rails).
3. Car park: signage, armco, bollards.
4. Training fence.
5. Yard clutter and crowd barriers.

Stop after 1 and look at it.

## Open, not decided here

- **Houses near the plot.** 13 MEH prefabs against the primitive terraces — they will repeat heavily.
  Compare side by side before swapping anything (see the earlier note in `docs/ASSET_KIT.md`).
- **Part budget for the plot.** The town budgets (1,240 / 900 / 260-part reserves) were set for
  town-scale dressing. The plot needs its own, higher, number. TEMP: measure after step 1 and record
  it here rather than guessing now.
