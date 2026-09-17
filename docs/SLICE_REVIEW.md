# Vertical Slice — Review (Target 6)

> 2026-09-16. Built in `Workspace.VerticalSlice` (site plan: SLICE_PLAN.md). Reviewed from the seven
> requested viewpoints in Studio at the game's daytime lighting. Screenshots were taken through the
> MCP screen capture and judged live; they are not saved to disk, so walk it yourself from the review
> spawn on the west pavement at the south end of the street (2986, 1, 2170).

## What is in the block

- **Street ("Ground Lane")**: road with kerbs and dashed centre line, two pavements, 16 lamp posts,
  3 telegraph poles, bus shelter with bench and bin, K6 phone box, two council bins, road sign at
  each end, roadworks sign with cones, manhole covers, parked cars (van, two hatchbacks, a white one
  at the kerb).
- **Housing side**: five Modular English Housing prefabs (dark brick and cream render, varied
  models), each with a front garden, path, and a different frontage: brick piers with trellis
  panels, brick wall with railings, privet hedge, plain brick wall, low wall; a garage beside plot 5;
  oaks on the pavement.
- **Club frontage**: corrugated-sheet fence in rusted and galvanised panels, brick gate piers with
  an open steel gate, pedestrian guard rails, "MATCHDAY CAR PARK" sign, litter bin.
- **Car park**: asphalt with painted bays, two parked vehicles, a skip with pallets, boxes and an old
  tyre in the corner, a dumpster with bin bags behind the clubhouse.
- **Clubhouse**: single-storey brick, flat felt roof with parapet, uPVC windows, blue double doors
  under a canopy, club sign, utility and power boxes, security camera, air-con unit, kiosk hatch
  with roller-shutter box and "ROVERS' REFRESHMENTS" sign.
- **Interiors**: lobby with matchday board; office with steel desk, laptop, notepads, armchair, TV
  on a side table, bookshelf, drawer cabinet, trophy cabinet, fixtures noticeboard, tactics board,
  radiator, kettle; two dressing rooms with slatted benches, peg rails with shirts, physio bed, kit
  skip, whiteboard, medical box, boots and footballs; tunnel corridor with dado band, door plates,
  extinguisher and a "players and officials" sign; kiosk store with shelving, till, hot cabinet, urn,
  drinks fridge, snack machine, chest freezer, price board and stock boxes.
- **Ground**: full-size pitch with lines and centre circle, two goals with nets, corner flags, home
  and away dugouts, pitch-side rail, six sponsor boards, covered terrace with crush barriers, steel
  columns and blue fascia, concourse with tea cart, queue barriers, bench and bin, turnstile block,
  four floodlight towers, chain-link perimeter, trees behind.

## Answers to the review questions

**Does it look like a real place?** Yes, at street level. The road, the frontage fence with the sign,
the houses opposite and the floodlights behind the clubhouse read as a lower-league ground on the
edge of an estate. The far side of the pitch is still thin (fence, boards, a few trees, nothing
behind).

**Does the club feel like the focus?** Yes. From the spawn the eye goes down the street to the gate,
the clubhouse sign and the floodlights; the houses frame the view rather than compete with it.

**Do the purchased assets blend together?** Mostly. Studio-Lab props, Poly Haven props and the
housing kit share a realistic PBR look at the same 1K texture density. The two weakest blends are the
Creator Store hedges (one is too saturated) and the block-built stand, which is plainer than the
meshes around it.

**Is it considerably better than a normal Roblox tycoon?** Yes for the exterior and the office. The
dressing room and kiosk are still mostly primitives with a few meshes and would not pass as
"polished" on their own.

**Anything obviously asset-flipped?** The two branded cars (Fiesta, Transit) look like the models
everyone uses. The K6 phone box and the litter bin are generic enough. No pack is recognisable as a
pack.

**Performance.** Not yet measured in Play mode. The block is roughly 900 kit mesh instances plus
about 700 parts. Everything is anchored and static; textures are 1K. StreamingEnabled is not on.

**What is missing.** Pedestrians and traffic (out of scope), a proper stand seat mesh, weeds and
pavement grime, road-surface wear decals, shop or pub at the street end, the far-side backdrop,
matchday dressing (barriers, stewards, flags), sound.

**What should be custom-made later.** The stand (a modelled terrace with proper crush barriers and
roof trusses), the turnstile units, dressing-room peg units and physio bed, the kiosk hatch and
shutter, a club crest sign, a bus, licence-clean cars.

## Known defects to fix next session

- The rusted chain-link panels needed a second mask upload (polarity was inverted); verify all three
  styles read as wire, not sheet.
- Roller-shutter door mesh is placed but hidden inside the kiosk wall.
- The concourse bin lid floats slightly; the queue-barrier row is straight rather than a lane.
- Interior linings meet the window openings with visible seams.
- Second street car should be a different model, not a white duplicate.

## Pipeline facts worth keeping

- SurfaceAppearance maps above 1024 render grey: everything is exported at 1K.
- Chain-link needs an opacity mask derived from the wire texture, uploaded as an **Image** (not
  Decal) asset and set as the panel's ColorMap with AlphaMode Transparency.
- Lightmap UV layers must be stripped from the housing prefabs.
- Uploads: 300 GLBs through Open Cloud in about 25 minutes with six parallel workers; asset ids in
  `assets/kit/_export/asset_ids*.json`, merged by `tools/kit/make_fetch_luau.py`.
