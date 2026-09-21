# Clubhouse rework — spec (2026-09-20)

Replaces the west block (office + 94-stud tunnel corridor + two dressing rooms,
three separately clad boxes) with **one small grassroots clubhouse right on the
west touchline**, with three ways in and out. Decided with Marcel 2026-09-20.

This spec covers **phase 1: shell + interior layout + everything that depends on
its position**. The exterior restyle is phase 2 and is only outlined here.

## Why

- Today the only way in or out of the office and dressing rooms is the tunnel
  mouth: no exterior door, no window. "GO TO MY CLUB" drops the player in a
  dead-end block ~100 studs from daylight.
- From outside it is three brick boxes at three heights (office roof 14.1,
  rooms 9.8, corridor 10.9) with two different grey roofs.
- A grassroots club has no walk-out tunnel. It has a cramped building beside
  the pitch. The 94-stud corridor only exists to pass under a 16-row West stand
  the starting club does not have.

## Decisions (all Marcel-approved)

1. Clubhouse stays on the **west touchline, centred on halfway (z = 0)**.
2. **No tunnel.** Players come out of a door in the clubhouse's east wall.
   `Pitch.TUNNEL` keeps its meaning (the point the teams emerge from).
3. The West stand becomes **two wings either side of the clubhouse at every
   level**. Tall wings (levels 3-4) flanking a 12-high building is accepted for
   now. "Main stand absorbs the clubhouse and a real tunnel appears" is phase 3,
   not scheduled.
4. A **kiosk / store room** is in the shell now (empty room + hatch), no mechanics.
5. **Both dressing rooms are enterable.**
6. Spawn stays in the office (CLAUDE.md s27).

## Geometry

Pitch-local studs, same frame as `WorldBuilder`: origin pitch centre, +X east,
-Z north, `DECK_Y = Pitch.SURFACE_Y`, `SIDE_EDGE = 121` (west wall line at
x = -121), west perimeter wall runs z -155..155.

### Shell

| | value |
|---|---|
| Footprint (outer) | x -157..-121, z -40..40 (36 deep x 80 long) |
| East wall | on the perimeter wall line; it **replaces** the perimeter wall for z -40..40 |
| Outer walls / partitions | 1 thick |
| Floor top | `DECK_Y + 0.1` (as `OFFICE_Y` today), one continuous floor |
| Clear height | 10 (ceiling underside at `DECK_Y + 10.1`) |
| Roof | one slab, 1 thick, over the whole footprint; top ~ `DECK_Y + 11.1`. Parapet comes in phase 2 (target overall height 12, as the slice) |
| Door clear height | 7.5, with a header above |

One shell = one set of outer walls and one roof. No per-room cladding skins.
Phase 1 finish: one brick colour outside (`STAND_BRICK`), one roof colour, the
current interior finishes inside.

### Rooms (inner faces, approximate; partitions centred on the lines given)

```
              WEST  (x = -157)   car park / footpath side
   z -40        -16                       +16                 +40
    +------------+---====[1] FRONT====-----+--[window]---------+
    |            |        LOBBY            D3                  |
    |  KIOSK /   D4   (x -156..-148)       |                   |
    |  STORE     +---------+     +---------+     OFFICE        |
    |            |  AWAY   D5   D6  HOME   |     (spawn)       [3] SIDE DOOR
    | [hatch N]  |  dress. | COR |  dress. |                   |   (south wall)
    |            |         | RID |         |                   |
    +------------+---------+=[2]=+---------+-------------------+
              EAST  (x = -121)   touchline   PLAYERS' DOOR
```

| Room | x | z | Notes |
|---|---|---|---|
| Kiosk / store | -156..-122 | -39..-16.5 | Empty. Serving hatch 8 wide x 4 high, sill at 3.5, in the **north** wall (z = -40) centred x -139. Shutter part closed, non-functional |
| Lobby | -156..-148 | -15.5..15.5 | Behind the front doors; links everything |
| Corridor | -148..-122 | -4..4 (8 clear) | Runs lobby -> players' door. Walls centred z = +-4.5 |
| Away dressing room | -147..-122 | -15.5..-5 | North of the corridor. Grey kit until matchday, as today |
| Home dressing room | -147..-122 | 5..15.5 | South of the corridor |
| Office | -156..-122 | 16.5..39 | Spawn, desk, laptop + `ClubPrompt`, trophies, honours |

Dressing rooms are ~25 x 10.5: deliberately cramped. Re-fit `dressDressingRooms`
(benches + pegs down the long walls); drop anything that no longer fits rather
than shrinking it.

### Openings

| # | Opening | Where | Size |
|---|---|---|---|
| 1 | **Front double doors** | west wall x = -157, z -4..4 | 8 wide |
| 2 | **Players' door** | east wall x = -121, z -4..4 | 8 wide. Keeps the club-coloured header (`Config.HomeKit`) from today's tunnel mouth |
| 3 | **Office side door** | south wall z = 40, x -143..-138 | 5 wide |
| D3 | Office <-> lobby | partition z = 16, x -155..-150 | 5 wide |
| D4 | Store <-> lobby | partition z = -16, x -155..-150 | 5 wide |
| D5 / D6 | Dressing rooms <-> corridor | corridor walls, x -139..-134 | 5 wide each |
| W | Office window | west wall, z 22..34, sill 3.5, 5 high | glass part, non-opening |
| H | Kiosk hatch | north wall, see above | |

Doors are open doorways in phase 1 (no door leaves, nothing to operate). Every
opening must be walkable by an R15 character: test it.

Routes from spawn: outside via [3] in ~12 studs; outside via D3 -> [1] in ~25;
pitch via D3 -> lobby -> corridor -> [2] in ~45.

### Spawn and fittings

- `OfficeSpawn` at about (-139, floor + 0.5, 28), facing -X. Still `Enabled = false`
  (PlotService teleports; X278).
- Desk + laptop (`ClubPrompt`, green-screen `Screen` SurfaceGui) against the east
  wall of the office (no openings there). Trophies shelf on the east wall,
  honours pennants + framed shirt on the north partition (clear of D3). Tier
  fittings from `dressOffice` re-anchored to the new office box.
- **Fix while here:** nothing in the office is named `Computer` since the laptop
  became a `KitPlacer` model (X373), so `dressOffice`'s
  `office:FindFirstChild("Computer")` and the HUD beacon target `"Computer"` are
  silent no-ops. Name the placed laptop model `Computer` (and delete the dead
  `box("Computer", ...)` fallback).
- **Matchday board** (carries the Play Match prompt): on the lobby's east wall,
  home side, at about (-147.4, floor + 5, 10), facing -X, so it is the first
  thing seen from the front doors and from the office door. Keep the name
  `MatchdayBoard` (HUD beacon).
- Way-out signs (`buildWayOut`) become: "PITCH ->" over the corridor entrance in
  the lobby, "CAR PARK" over the office side door inside, club name over the
  front doors outside (plain sign part; styled in phase 2). Drop the painted
  floor arrow.
- Lights: one `PointLight` bulb per room, two strip lights in the corridor.

## Code shape

New module **`src/server/Clubhouse.luau`**, taking the clubhouse out of the
2,900-line `WorldBuilder.luau`:

- Moves/replaces `buildTunnel`, `buildDressingRooms`, `buildOffice`,
  `buildWayOut`, `dressDressingRooms`. `dressOffice`, `buildHonours`,
  `buildTrophies`, `buildMatchdayBoard`, `setFixtureNotice` may stay in
  WorldBuilder but must take their anchors from Clubhouse, not from
  `OFFICE_CX`-style constants.
- Driven by a small layout table at the top of the module: shell rect, room
  rects, and a list of openings `{ wall/partition, from, to, height, sill? }`.
  A wall builder takes one wall line plus its openings and emits the segments
  and headers. The exterior pass must be able to re-skin the shell without
  touching room code.
- Exposes what others need, e.g. `Clubhouse.SHELL` (rect), `Clubhouse.GAP_Z`
  (= 41, half-gap the stand / wall / ad boards leave), `Clubhouse.officeRect`,
  `Clubhouse.spawnCFrame`. If client code needs any of it, put the constants in
  `src/shared/Pitch.luau` next to `TUNNEL` instead.
- Model names: parent model `Clubhouse`, with children still named **`Office`**
  and **`DressingRooms`** (HUD `indoors()` L327-347 and `AmbientAudio` L123-140
  look these up by name and use their bounding boxes). Put lobby, corridor and
  store under a third child `Lobby` and add it to both of those indoor checks.
  The shared roof and outer walls go in a `Shell` child so they do not inflate
  the Office / DressingRooms bounding boxes.
- Remove `TUNNEL_H`, `TUNNEL_OUT`, `PORTAL_D`, `CORRIDOR_END`, `OFFICE_*`,
  `ROOM_*` constants once nothing reads them. Update the header comments in
  `WorldBuilder.luau` L49-53 and `Pitch.luau` L36-40 (no longer "running back
  through the stand").

## Dependencies to update

Server:
- `WorldBuilder.buildPerimeter` (L370-375): west wall split at z +-40 (the
  clubhouse east wall fills the gap), not +-`TUNNEL_OUT`.
- `WorldBuilder.buildAdBoards` (L443-451): no boards across z -40..40 on the west side.
- West stand: `plotGeometry` (L2119-2141), `rowRuns` (L2155-2168), L2318-2324,
  L2348-2353, L2462-2463. Gap becomes +-`GAP_Z` (41) at **every** level. Delete
  the `crossRow` / `crossY` "terrace rests on the corridor roof" logic. Each
  wing gets a proper end cap and back-wall return facing the clubhouse. Wings
  are z -155..-41 and 41..155 (114 each). Check seat/crowd placement (L2663)
  follows `rowRuns`, and that capacity comes from Config, not geometry.
- `PlotService.officeSpawn` (L303) / `sendHome` (L310) / GoHome (L549-570): new spawn.
- `PlotGrounds.luau`: update the header table (L30-41). Add (a) footpath spur:
  continue the z -12 footpath east from x -261 to x -169, plus a paved apron
  x -169..-157, z -16..16 in front of the front doors; (b) a path from the
  office side door (x -143..-138, z 40) south to z 46 then west to the car park
  kerb at x -250. Same paving as the existing footpath. The forecourt /
  turnstiles (north-west corner) are untouched.
- `Scenery.luau` (L186-195): `KEEP_OUT_WEST` can relax to about
  `-(SIDE_EDGE + 50)`; trees must also stay off the two new paths and apron.
- `SeasonService` L100 -> `setFixtureNotice` still finds its `Lines`.

Client:
- `MatchPresenter.luau` L444-464 walkout queue: spacing 4 -> 3 studs and file
  offset +-2.5 -> +-2 so 11 a side fit inside corridor + lobby (-117 - 33 =
  x -150). Also check L913, L919, L965-982 (subs, full-time exit) path through
  the players' door without clipping the header.
- `Match.client.luau` L47-62 `cameraWalkout`: still aimed at (-100, 4, -2);
  re-check the framing now the mouth is a door in a 12-high building.
- `HUD.client.luau` indoors + beacons, `AmbientAudio.client.luau`: see model
  names above.
- `PlotPicker.client.luau` L296-298, `ClubVisit`, `ClubPanel`: no change
  expected; verify the `ClubPrompt` still opens the panel.

Tests:
- `tests/PlotGroundsTest.luau` L22-37: `WestBlock` keep-out becomes x -170..-121,
  z -41..47 (shell + apron + side path). The old rect under-covered the block
  (stopped at z 30, rooms reached 37.6).
- New `tests/ClubhouseTest.luau`: builds the clubhouse and asserts (1) models
  `Clubhouse/Office/DressingRooms/Lobby/Shell` exist, (2) every opening in the
  layout table is clear: no part intersects a 4 x 6.5 box through the doorway
  (`GetPartBoundsInBox`), (3) spawn position is inside the office rect and under
  the roof, (4) `MatchdayBoard`, `Computer`, `ClubPrompt` exist, (5) one roof
  part covers the whole footprint and no clubhouse part rises above it.
- Run the suite the usual way (loadstring RunAll through Studio MCP; MCP sandbox
  needs the `DebugRun` attribute).

## Acceptance (phase 1)

1. Play-test in Studio: spawn in office; walk out through the side door, the
   front doors and the players' door; walk back in through each.
2. "GO TO MY CLUB" from town lands in the office.
3. Play a full match: both XIs queue inside, walk out of the players' door,
   subs and full-time exit work, walkout camera frames the door.
4. HUD "take my seat" is not offered in the lobby/corridor; outdoor audio ducks
   in every room.
5. West stand at levels 0, 1, 2 and 4 on a test plot: wings stop cleanly at the
   clubhouse, no parts interpenetrate (world pass 2 no-interpenetration rule),
   no floating back wall.
6. Top-down screenshot: one rectangle, one roof. Compare against the screenshot
   that started this (three boxes).
7. All tests pass. Commit once stable.

## Phase 2 — exterior (next session after phase 1, outline only)

Follow the vertical slice and `docs/PLOT_KIT_PLAN.md` (kit density, not
primitives). Reference: `assets/references/RivermereTurnstileEntrance.png`
(single-storey brick, flat roof with a pale fascia, navy sign band with crest,
navy doors) and the slice clubhouse in `Workspace.VerticalSlice` (blue double
doors under a canopy, uPVC windows, club sign, kiosk hatch).

- one brick skin, parapet flat roof to 12 high, fascia in club colour
- canopy + double door leaves at the front, a plain door at the office side
- uPVC windows: office (west), lobby sidelights, high slot windows in the
  dressing rooms (east wall stays blank to the pitch apart from the players' door)
- club name sign band over the front doors (`setClubName`)
- apron: bin, bench, lamp column; bollards at the side path
- rundown at tier 1 (stained render patches, faded sign); tidier with `Tier`,
  alongside the existing `dressOffice` thresholds

## Phase 3 — later, not scheduled

At a high West stand level (or league tier) the main stand is built over the
clubhouse and a real tunnel appears. Needs its own design talk.

## As built (phase 1, 2026-09-20)

Phase 1 is in: `src/server/Clubhouse.luau`, wired through `WorldBuilder`,
`PlotService.PER_CLUB`, `PlotGrounds`, `Pitch`, `MatchPresenter`, `HUD`,
`AmbientAudio`; tests in `tests/ClubhouseTest.luau`. Where the build differs
from the plan above, the build wins:

- **Clear height is 12, not 10** (roof top at floor + 13). The office honours,
  trophy shelf and tier fittings are all placed for a 12-high room.
- **Office side door is at the west end of the south wall** (x -155..-150), and
  the **kiosk hatch is on the west face** (z -34..-26), not the north wall. An
  8-row West stand wing runs along the rest of both end walls and would have
  blocked them. The spawn faces the side door from (-152.5, 34).
- **A 12- or 16-row West wing (levels 3-4) still blocks the side door and its
  path.** Accepted: that is the phase 3 case (main stand absorbs the clubhouse).
- Office/lobby and store/lobby doors are at x -154..-149; the office window is
  z 24..34. Dressing rooms are 25.6 x 10.8 and hang 12 shirts each.
- `Office`, `DressingRooms` and `MatchdayBoard` stay **direct children of the
  club model** (server dressers and clients look them up there). `Clubhouse`
  holds `Shell` and `Lobby` (hall, corridor, store).
- Walls: `Shell` is 0.6 brick; every room lines its own walls 0.4 thick, so the
  exterior pass only has to replace `Shell`.
- The west stand is two wings at every level, each half the level's length,
  pushed out from the clubhouse (so level 1 bleachers still appear). Back wall,
  coping, roof, fascia and pillars are built per span.
- Pitch-side ad boards keep their old 16-stud gap in front of the players'
  door rather than clearing the whole clubhouse front.
- `Scenery` tree keep-out was left alone (it already keeps trees off this
  ground), and the new paths are not `PlotGrounds.footprints()` entries, like
  the rest of the footpath.
- `Clubhouse` had to join `PlotService.PER_CLUB`: per-club module clones resolve
  `script.Parent.X` against their own folder.

Verified in Studio: 785 tests pass; club claims and builds with no errors;
spawn lands in the office; all three outer doors open onto paving; a match
plays through; West stand levels 2 and 4 stop cleanly at the clubhouse.
Not yet eyeballed: the walkout itself (the debug match was 20 s) and the
"take my seat" / audio-ducking behaviour in the lobby.

## As built (phase 2 exterior, 2026-09-20)

All in `Clubhouse.luau`: `buildShell` is the styled shell, `dressExterior` the kit
clutter (model `Clubhouse.Exterior`). The slice clubhouse this follows is itself
brick primitives plus a handful of Poly Haven props, so this is too.

- Brick walls run up past the roof as a **parapet with a stone coping**; the felt
  roof sits inside it on top of the rooms. `Clubhouse.ROOF_TOP` is the coping top.
- A darker brick **plinth** course round the foot of the walls, broken at doors.
- **Windows** come from `OPENINGS` entries with `glazed = true`: white uPVC frame
  in the wall thickness, glass, stone sill. Office window, a sidelight either side
  of the front doors, and a high slot window in each dressing room on the pitch
  side. Add a window by adding an opening; walls, linings and frames follow.
- **Front doors**: leaves folded back (doorways stay open, non-colliding), steel
  canopy on two posts with a club-colour edge, bulkhead light under it, and a
  dark club-colour **fascia** over it with a crest either side of the club name
  (after RivermereTurnstileEntrance.png). The players' header keeps the club name.
- **Doors** (2026-09-21): every doorway, inside and out, is listed in `DOORS` and
  built by `hangDoor`: a white frame through the wall, leaves from the houses' kit
  doors (`MEH__Door_A` panelled, `Door_B` half glazed, `Door_C` fully glazed)
  stretched to the opening, and three hinge pins between jamb and leaf. Leaves
  stand open at 90 degrees, butted against the jamb, non-colliding. Outer doors
  are tinted club colour through the trim sheet's `SurfaceAppearance.Color`; inner
  ones stay white. The kit door has no back face, so leaves set `DoubleSided`.
  The lobby doors open into the office and store so they do not hide the
  matchday board.
- Kiosk hatch: shutter box, counter, and a TEMP "TEAS - PIES - HOT DRINKS" board.
- Rainwater pipes on the street-side corners.
- Kit props: utility box, power box, security camera, air-con unit, park bench,
  litter bin, dumpster with lids and two bin bags round the north end.
- **Rundown at tier 1**: damp patches on the street wall (`Damp` frames), hidden
  with the office's at `OFFICE_TIER_PAINT` by `WorldBuilder.dressOffice`.
