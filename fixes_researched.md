# Traffic and pedestrians: researched fixes

## Status (2026-09-20, late evening): fixed and verified in Studio

All of the below is now fixed, except the items under "Left for a decision". Suite:
762 passed, 0 failed. Verified in a play session: 16 vehicles all 3.23 studs off
the rounded path, closest pair 21.7 studs (was 10 to 14, overlapping); cars
5.9 x 5.0 x 11.6 and bus 6.2 x 9.0 x 20.3; 30 walkers all 7.7 to 9.3 studs out, on the
3-stud paved strip; debug dots along the car lanes and walker lines stay on the
asphalt and the paving through both a 90 and a 45 bend.

| # | Fix | Where |
|---|---|---|
| 1a | Lane offset from the kit carriageway | already in `c4de7ff`; confirmed live |
| 1b / 2b | Corners rounded to the kit bends: new `Shared/RoadPaths` (fillet, `townRoads()`), used by Traffic and Pedestrians | `RoadPaths.luau`, `RoadTiles.KIT_BEND90_RADIUS = 29`, `KIT_BEND45_RADIUS = 40` |
| 1c | Spawn round the streaming focus (ReplicationFocus, else character, else camera); spawn only on a streamed road tile; despawn when the ground streams out | `Traffic.client`, `Pedestrians.client` |
| 1d / 4 | One car size `RoadTiles.CAR_SCALE = 0.6` for traffic, parked cars, car park cars, taxis, sports centre and station car parks; bus at `BUS_SCALE = 0.74` | `RoadTiles`, `FurniturePlan`, `MatchdayLife`, `StationDresser`, `SportsCentreDresser` |
| 1e | One island share (0.45) for the builder and for traffic, with a test | `RoadTiles.ISLAND_SHARE`, `TrafficMath` |
| 1f | Cars sit on `RoadTiles.roadTop`; junction turns and dead-end U-turns ease over 0.9 s instead of snapping | `Traffic.client` |
| 2a | Walkers hold the strip centre (no random jitter) | `Pedestrians.client` |
| 2c | Walkers turn round at junction mouths and where their road runs into another | `PedestrianMath.junctionZones` |
| 3a | Parked streets stay closed (parked cars measured 3.6 off centre, in the lane, both sides); budget cut 24 to 16, Low 8 to 6 | `Traffic.client`, `Quality` |
| 3b | Spawn road picked by length; nothing spawns within 40 studs of another vehicle; a car holds at a junction while its landing spot is taken | `TrafficMath.weightedIndex / crowded`, `Traffic.client` |
| 3c | Follow gap = both half lengths + 8 studs, eased from twice that; bikes count as leaders; ring seam handled; speed jitter 15% to 5% | `TrafficMath.followGap / followSpeed` |
| 3d | Walkers: 12-stud spawn spacing, segments picked by length, budget capped at one per 45 studs of nearby pavement, sidestep for oncoming walkers, hold back behind one ahead | `Pedestrians.client` |

Corrections to the research below: the bends are tighter than first estimated.
Measured from close top-down captures, the 90 bend's centreline radius is about
23.7 studs (corner was 9.8 studs off the asphalt centre) and the 45 bend's about
32.6 (2.7 studs off). The "25 to 32 studs" figure for the 90 bend was wrong.

### Left for a decision

- **D1 road scale.** Kept at 0.816 (decided earlier the same day). Cars at 0.6 are
  as large as a 6.47 lane allows. Going bigger means wider roads.
- **Pavement width.** Still 3 studs; a figure is 4 across the arms. The verge is
  one mesh, so it cannot be part-repainted as paving. Needs a wider road scale or
  extra paving parts from RoadTiler.
- **Walkers do not cross roads.** They pace between junctions. A crossing
  behaviour would need cars to give way to them.
- Car park bays were laid out for 0.85 cars; at 0.6 the cars sit small in a 9-wide bay.

---

# Original research

Researched 2026-09-20 (evening) against the live Studio play session and the code at
commit `c4de7ff`. Nothing has been changed yet. Every cause below has the evidence
that backs it; where something is an estimate it says so.

Kit road facts used throughout (measured on a `Straight` tile at scale 0.816,
lateral distance from the TownLayout centreline):

| Band | From | To |
|---|---|---|
| Asphalt carriageway | 0 | 6.47 (12.9 wide in total, so a lane is 6.47) |
| Kerb | 6.47 | about 7.0 |
| Paved strip (the pavement) | 7.0 | 10.0 (3 studs wide) |
| Grass verge | 10.0 | 17.95 |

The straight tile is centred on the TownLayout polyline (measured lateral centre 0.00).

---

## 1. Why cars are not in the road

### 1a. The screenshot shows the old lane offset (already fixed in `c4de7ff`, needs a fresh play session)

- Old code: `laneOffset(direction, road.width, -1)` = nominal width / 4 = 5.0 on a
  residential street, 6.5 on a main road, 8.0 on the ring. The real lane centre is 3.2.
- Measured from the screenshot: carriageway is 312 px = 12.9 studs, so 24 px per stud.
  The orange car's centre is 131 px = about 5.4 studs from the road centre, and its
  left side is over the kerb line. That is the old 5.0 offset, not the new 3.23.
- The file was saved at 18:33:19 and the screenshot arrived at 18:34:13, so the
  session in the picture was started before the fix.
- In the session running now, all 21 cars and buses measure 3.23 studs off the
  centreline, so on straights they are inside the lane (car spans 0.8 to 5.7 of 6.47).

**Fix:** none in code. Stop and restart Play, then re-check a straight street.

### 1b. Bends: cars follow a sharp corner, the kit road is a long curve (NOT fixed)

- `TrafficMath.pointAt` walks the TownLayout polyline, which turns 45 or 90 degrees at
  a single point. The kit bend pieces are smooth arcs (top-down capture of the 45
  bend at (18, 202) confirms it: the curve runs for about 69 studs).
- Estimated from that capture: radius about 88 studs, so the polyline corner sits
  about 7 studs inside the curve on a 45 bend. Lane offset 3.2 + 7 = about 10 studs
  from the real road centre, which is past the kerb and onto the paving and grass.
- A 90 bend (legs 96 and 93 unscaled, about 77 scaled) is far worse: corner to arc
  is roughly 0.41 x radius, so about 25 to 32 studs off the asphalt. (Estimate; I could
  not capture a 90 bend because none was streamed in near the character.)
- The plan has bend45, bend90 and cul-de-sac head pieces all over town, so every car
  leaves the road at every bend.

**Fix:** give Traffic (and Pedestrians) a drivable centreline that matches the tiles
instead of the raw polyline. Add a pure function in `RoadTiles` (or a new
`RoadPaths` module) that, for each road, returns the polyline with every bend node
replaced by an arc sampled every ~8 studs: tangent points at `legA * scale` and
`legB * scale` from the node (the numbers are already in `RoadTiles.PIECES`, and
shrunk nodes already carry `node.scale`). Traffic and Pedestrians then call
`pointAt` on that path. Unit test: every sampled point of the path lies within
1 stud of the tile's measured centreline at a 45 and a 90 bend. The arc radius
needs one Studio measurement per bend piece (45 and 90) before coding.

### 1c. Roads are not streamed in where the cars are

- `StreamingEnabled = true`. Traffic spawns 150 to 700 studs from the **camera** and
  keeps cars to 800. Streaming follows the **character**, not the camera.
- Capture at (1600, 215) during the plot picker (camera Scriptable at (1270, 120, 650),
  character at (46, -174)): a convoy of cars and buses driving over bare terrain
  grass. The server has the road tiles there; the client does not.
- In normal walking play this shows up as distant cars driving on grass beyond the
  streamed radius.

**Fix:** spawn and despawn around the character's position when there is one (fall
back to the camera only when there is no character), and pull `SPAWN_MAX_DIST` /
`DESPAWN_DIST` inside the streaming radius (check `StreamingTargetRadius` in the
place file; it is not scriptable). During the plot picker either pause traffic or
set `Player.ReplicationFocus` to the picker's focus point. Same change for
Pedestrians (it also uses the camera).

### 1d. Buses are wider than a lane

- Bus mesh measures 8.3 x 12.1 x 27.4 studs. A lane is 6.47. At offset 3.23 the bus
  spans -0.9 to 7.4: about 1 stud over the centre line and 1 stud over the kerb.
  Two buses passing overlap each other by about 1.8 studs (seen side by side in the
  capture).

**Fix:** depends on decision D1 below (road scale). If roads stay at 0.816, scale
the bus to about 6 wide (x0.72) in `ClientKit`; a Roblox double-decker 6 x 8.7 x 19.7
still reads as a bus.

### 1e. Roundabout islands: two different island sizes

- `RoadTiles` draws the island at `radius * 0.45` (18 studs on a 40 roundabout,
  1.2 studs high). `TrafficMath.ISLAND_SHARE` is still 0.35, so cars circle at
  0.35 * 40 + 4.5 = 18.5. Car inner edge = 18.5 - 2.45 = 16.05, which is 2 studs
  inside the island. Buses go 2.7 studs inside.

**Fix:** one constant. Export `ISLAND_SHARE = 0.45` from `RoadTiles` (or TownLayout)
and have `TrafficMath.aroundIslands` and `RoadTiles.emitNode` both read it. Add a
test that car clearance ring minus half a car width is greater than the island radius.

### 1f. Small ones

- Car root Y uses the v2 `ROAD_TOP` table (0.20 to 0.23). Kit asphalt top is 0.12,
  so every vehicle floats about 0.15 studs. Fix: one `RoadTiles.ASPHALT_Y = 0.12`.
- Dead ends: the U-turn flips `direction` in place, so the car jumps 6.5 studs
  sideways into the other lane and spins 180 degrees in one frame. Same kind of
  snap when `switchRoad` moves a car onto the next road. Fix: a short scripted
  turn (lerp position and yaw over about 1 s), or despawn at dead ends when more
  than 150 studs from the player.

---

## 2. Why people are not on the pavement

### 2a. On straights they are on it, but the strip is narrower than a person

- Measured now: all 30 walkers are 8.05 to 8.97 studs from the centreline. The paved
  strip is 7.0 to 10.0, so their feet are on it.
- The Townsfolk R6 figure is 4 studs wide arm to arm (torso 2 + two arms of 1).
  `WALKER_HALF_WIDTH = 1` only counts the torso. At the strip centre (8.5) the arms
  span 6.5 to 10.5, so they overhang the kerb and the grass by half a stud each
  side, and more with the 0.5 jitter. From above (as in the screenshot) this reads
  as "not on the pavement".
- Root cause is the 0.816 road scale: it makes the pavement 3 studs (about 1.1 m)
  wide.

**Fix:** tied to decision D1. If roads stay 0.816: set jitter to 0 so walkers hold the
strip centre, and make the paved band wider in `RoadTiler` by recolouring part of
the verge (the inner 2 studs of grass) as paving, so the pavement is 5 studs. If
roads go back to 1.0: paving is 3.7 wide natively and the same trick gives 6.

### 2b. Bends (same cause as 1b)

- `PedestrianMath.offsetPolyline` mitres the sharp corner. The kit paving curves.
  Walkers cut across grass on the inside of every bend and across asphalt on the
  outside. Fix is shared with 1b: offset the arc path, not the raw polyline.

### 2c. Junctions and crossings

- Walkers keep walking straight across every side-road mouth (the file header
  already lists this as a known limit). With kit T and crossroads pieces 73 studs
  long this is a long walk across open asphalt, and tucked side streets (visible in
  the capture, the side street simply runs under the through road) have no kerb
  break at all.
- Fix (smallest): at a junction node, have the walker turn the corner onto the
  side street's pavement or turn round, instead of crossing. `RoadTiles.plan`
  already knows every node and its arms; publish node positions and use them as
  path ends.

### 2d. Height

- Fine. Torso Y 3.35 to 3.47 means feet at about 0.35 to 0.47 = `SURFACE_Y` plus the bob.

---

## 3. Why everything is bunched together and colliding

### 3a. 53 of 94 roads are closed to traffic, so 24 cars share what is left

- `V3Furniture.ParkedStreets` lists 53 streets. Traffic will not spawn on them and
  strips them from the junction options. Cars are funnelled onto the few open
  streets near the camera and bounce off dead ends.
- Measured: of 24 vehicles, 9 were on Ferry Lane and 6 on Ropewalk.

**Fix:** the exclusion was written for the v2 20-wide street with cars parked on
both kerbs. Check where StreetFurniture parks cars on the 12.9 kit carriageway. If
parked cars sit on the asphalt there is no room for a moving lane and the streets
must stay closed, in which case lower the car budget (3b). If they can be parked
half on the verge, open the streets again. Needs one Studio look at a parked street.

### 3b. Spawn picks a road by index, not by length, and never checks for room

- `randomSpawnCandidate` does `math.random(1, #roads)`. Residential roads are 85% of
  picks but 71% of length; the ring is 1% of picks and 13% of length. Short streets
  get the same share as long ones, so they fill up.
- There is no "is another vehicle within N studs of this point" check at spawn.
- `switchRoad` drops a car onto the new road wherever the junction is, with no
  check for a car already there.

**Fix:** weight the road pick by length (cumulative-length table, built once), reject
a spawn point with any vehicle within 40 studs, and in `switchRoad` hold the car
(reuse the give-way dwell) while the landing spot is occupied.

### 3c. The follow gap is centre to centre and smaller than the vehicles

- `MIN_GAP = 14`, measured between centres. A car is 9.7 long, so bumper gap is 4.3.
  A bus is 27.4 long: a car 14 behind a bus centre has 4.6 studs of bonnet inside
  the bus. The capture shows exactly this.
- Follower speed is `leader.speed * gap / MIN_GAP`, which settles at gap = 14
  exactly. Measured convoy on Ferry Lane: five vehicles at 14.0-stud spacing.
- No overtaking plus 15% speed jitter means every road turns into one platoon
  behind its slowest vehicle, and platoons never break up.
- Gaps are only checked within the same road and direction: not across a junction,
  not across the ring road's wrap seam, and bikes are ignored entirely (cars drive
  through cyclists; a bike at kerb inset 1.6 is 4.87 out, inside the car's 0.8 to 5.7).

**Fix:** gap = half length of leader + half length of follower + 8 studs clear
(store `halfLength` on the Car). Start slowing at twice that distance. Drop the
speed jitter to 5% or give each road one speed. Include bikes as leaders. Check the
wrap seam on closed roads.

### 3d. Pedestrians: 30 walkers in a 250-stud radius, no spacing, no avoidance

- Only `main` and `residential` roads are walkable and the spawn radius is 250, so
  near the edge of town one road takes nearly everyone: 25 of 30 walkers were on
  Hollingford Road.
- Spawn picks a **segment** uniformly (not by length) and has no minimum distance to
  other walkers. The first fill places all 30 in one frame.
- Both directions share one line 1 stud wide (jitter 0.5), speeds differ (5 to 7), and
  there is no avoidance, so walkers pass through each other head on and from behind.
- Other ambient scripts (Strollers, TownLife, BenchSitters, CafeSitters) add more
  figures on the same pavements with no shared budget.

**Fix:** keep-left rule (lateral offset by walking direction, so opposing walkers use
opposite halves of the strip; needs the wider strip from 2a), minimum 12 studs
between walkers at spawn, weight segments by length, cap walkers per 100 studs of
road (for example 3), and when a faster walker closes to 3 studs on a slower one in
the same direction, match speed.

---

## 4. Car size next to the player

- Measured: traffic hatchbacks are 4.9 x 4.2 x 9.7 studs (`KIT_CAR_SCALE = 0.5`).
  Parked cars use the same 0.5 (`FurniturePlan.CAR_SCALE`). MatchdayLife car park
  cars use 0.85 and station taxis 0.7, so the town has three car sizes already.
- The player character measures 5.9 studs tall (with helmet) and is 4 studs wide.
- At the project's 2.75 studs per metre the 0.5 car is a true-to-life small
  hatchback (1.78 x 1.53 x 3.5 m), and its height ratio to a person is right (84%).
  It still looks like a toy because a Roblox avatar is about twice as wide as a real
  person: the car is barely wider than the player's arm span and the roof is below
  the player's head. The bus at true scale (12.1 tall) makes the cars look smaller
  still.
- It cannot simply be scaled up today: a lane is 6.47 wide. A car at 0.65
  (6.4 x 5.5 x 12.6) fills the lane edge to edge.

**Fix:** follows decision D1.

---

## Decisions for Marcel

**D1. Road scale.** Most of the above traces back to scaling every street to 0.816:
the carriageway becomes 12.9 (4.7 m), a lane 6.47, the pavement 3. Roblox avatars
and vehicles need more room than real-world scale gives.
- Option A (recommended): streets back to kit scale 1.0: carriageway 15.85, lane 7.9,
  paving 3.7 (plus the verge trick in 2a for 6). Cars at 0.62 (6.1 x 5.2 x 12.0), bus
  at 0.8. Costs a re-plan of tile fits (the 0.93 experiment failed on bend fits, so
  1.0 needs `RoadTiles.plan` stats checked for `unresolved`) and house frontages
  sit 4 studs closer to the kerb.
- Option B: keep 0.816. Cars stay 0.5 or go to 0.55 at most, bus shrinks to 0.72,
  pavement widened by repainting verge. Cheapest, cars still look small.

**D2. One car size for the whole town?** Traffic 0.5, parked 0.5, car park 0.85,
taxi 0.7 today. Recommend one constant in `Shared` that all four read.

**D3. Parked streets (3a).** Keep 53 streets traffic-free and cut the car budget to
about 12, or re-open them after checking parked car positions? Recommend checking
first; if parked cars leave one 6.5 lane free, open them one-way.

## Suggested order

1. Restart Play and confirm 1a on a straight (no code).
2. 1e island constant, 1f asphalt Y, 3c gap by vehicle length, 3b spawn spacing and
   length weighting. Small, pure, unit-testable in `TrafficMath`.
3. 1c spawn around the character inside the streaming radius (both scripts).
4. 1b / 2b arc paths from `RoadTiles`, with tests. Biggest single visual win.
5. D1, then 2a pavement width, 3d walker rules, car and bus sizes.
6. 2c junction behaviour for walkers, 1f turn animation.
