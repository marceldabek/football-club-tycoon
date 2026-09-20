# Town Plan — Rivermere master plan (v3)

> Backlog C1.1. Data twin: `src/shared/TownLayout.luau` (C1.2), checked by `tests/TownLayoutTest.luau`.
> If this file and the module disagree, the module wins and this file gets fixed.
> Every number here is **TEMP** until the greybox walk test (C2.2) and Marcel confirm it.
> Source: `assets/references/RivermereAIMap.png`, arrangement kept, scaled down. The map's
> labels use an old town name; the town is **Rivermere** and the river is the **River Lune**.

> **v3 (2026-09-20).** The layout is `docs/town_map_v3.png`. Three things changed from v1: the ring and
> through roads are snapped to axis / 45° so the bought road kit tiles; plots 2 and 4 moved toward the
> ring and plot 3 moved to Westdale in the south-west; and **everything built along a street is
> generated from street frontage** by `src/shared/TownFrontage.luau` instead of being authored.
> `TownLayout.DISTRICTS` now holds only the hand-placed special blocks.
> Source of truth: the two Luau modules. `tools/town_plan_v3.py` is the drawing tool and mirrors the
> generator; `python tools/town_v3_parity.py` checks the two agree and `tools/town_v3_emit.py` writes
> ROADS / PLOTS / ROUNDABOUTS into the Luau. Sections 2, 3 and 6 below are v3; sections 5, 7 and 8 were
> written for v1 and are still to be re-walked (walking times to plots 2 to 4 are stale).

## 1. Frame and scale

| Item | Value |
|---|---|
| Origin | market square centre = world (0, 0, 0) |
| Axes | +X east, +Z south (north = −Z), ground y = 0 |
| Scale | 2.75 studs per metre |
| Extent | x −2400..2400, z −1700..1700 (4800 × 3400 studs ≈ 1.75 × 1.24 km) |
| Walk / sprint | 16 / ~26 studs per second |
| Style reference | `Workspace.VerticalSlice` stays at (3000, 0, 2000), outside the extent |

The concept map is roughly 4.5 × 2.5 km. The town keeps its layout but shrinks to about 40% of that,
so the centre-to-plot walk is 2–2.5 minutes, not 6.

Sketch (not to scale; north up, the tables below are the truth):

```
 z-1700 +-------------------------------------------------------------------------------+
        |  [PLOT 4]                        Northfields                     [PLOT 2]     |
        |  NW  yaw180 >        (Ring N)   Rowan Cl  Hayfield Cl         < yaw0  NE      |
 z -800 |      (O)----- Ring ----------------(O)-----------------------(O)              |
        |  ====rail=====[Station]=\   Elm Grove / Weaver St / Mill St    |  Riverside    |
 z -400 | (O)Mapleford Rd          \   church+  terraces                 |   Park   ~~~~~|
        | Industrial Estate    (O)--High St--( SQUARE )--Riverside Rd----+ East Br ~~~   |
 z    0 |   sheds                    |rail     shops   Riverside  marina ~~~~   [PLOT 3]|
        |~~~~~~~~~~~ River Lune ~~West Br~~~Viaduct~~~Lune Br~~~~~~~~~~~   (O)< yaw0  E  |
 z  400 |                          |    \        |                          \             |
        |          Westdale       (O)    rail   Bridge St                   (O)Hollingford|
 z  800 |   Greenbridge Rd  /       \-----Ring----(O)--------------------/  ^            |
        |                  /   Westdale Ave  |  Sports Centre         [PLOT 1] yaw270   |
 z 1700 +-------------------------------------------------------------------------------+
      x-2400                                 x0                                     x2400
```

## 2. Club plots

Plot square: **760 × 760** (TEMP). Plot frame: origin = pitch centre, pitch long axis on local Z,
local −X = entrance side (office, turnstiles, car park) facing the access lane.
With Roblox yaw θ, local −X maps to world (−cos θ, 0, sin θ).

| Plot | Site | Centre (x, z) | Yaw | Entrance faces | World bounds x / z | Access | Bus stop (x, z) | River bank clearance |
|---|---|---|---|---|---|---|---|---|
| 1 | south-east | (1050, 1250) | 270° | north | 670..1430 / 870..1630 | Plot 1 Lane off Ring Road S (970, 800) | (992, 840) | 446 |
| 2 | north-east (Millbrook) | (1830, −1160) | 0° | west | 1450..2210 / −1540..−780 | Plot 2 Lane off Plot 2 Roundabout (1400, −600) | (1420, −1058) | 302 |
| 3 | south-west (Westdale) | (−1780, 1020) | 270° | north | −2160..−1400 / 640..1400 | Plot 3 Lane off Greenbridge Road (−1860, 560) | (−1838, 610) | 318 |
| 4 | north-west (Mapleford) | (−1790, −1130) | 180° | east | −2170..−1410 / −1510..−750 | Plot 4 Lane off Plot 4 Roundabout (−1350, −750) | (−1380, −1232) | 898 |

v1 had plot 2 at (1900, −1200), plot 3 in the east at (1950, 420) where it crowded plot 2, and plot 4 at (−1900, −1200).

Every access lane (X6) ends at `plotCFrame(i) * TownLayout.PLOT_LANE_END` = plot-local (−390, 0, 80), 10 studs
outside the vehicle gate (`PlotGrounds`: gate at local x −380, z 60..100). Gate ends in world: Plot 1 (970, 860), Plot 2 (1440, −1080), Plot 3 (−1860, 630), Plot 4 (−1400, −1210). Each plot bus stop sits 22 beside its lane, 20 back
from the lane end, outside the plot. Rail clearance: Plot 4 270, others > 1200.

### Inside a plot (local frame, TEMP zoning)

| Zone | Local x | Local z | Notes |
|---|---|---|---|
| Endgame stadium (~30k) | −240..240 | −280..280 | ~480 × 560 including stands |
| Entrance strip | −380..−240 | −380..380 | office, turnstiles, club shop, car park (`RivermereTurnstileEntrance.png`) |
| Training strip | 240..380 | −380..380 | two small training pitches ~120 × 180 end to end |
| End margins | any | ±280..±380 | trees, fence, service yard, floodlight bases |

The current office/entrance sits at local x ≈ −150..−300; it stays inside the entrance strip as the stands grow.

## 3. Elements and coordinates

### River, bridges, rail

| Element | Coordinates (x, z) | Size / notes |
|---|---|---|
| River Lune | (−2400,180) (−1800,220) (−1200,300) (−700,380) (−200,420) (300,420) (800,360) (1200,220) (1450,0) (1600,−250) (1900,−400) (2400,−450) | width 90; W→E, south of the centre, bends north-east between Plot 2 and Plot 3 |
| West Bridge (road) | (−1150,400) → (−1150,215) | ring road, deck 32 |
| Lune Bridge (road) | (100,330) → (100,510) | Bridge Street, deck 26; stone multi-arch (`RivermereRiverside.png`) |
| East Bridge (road) | (1400,−60) → (1400,150) | ring road, deck 32 |
| Lune Viaduct (rail) | (−530,260) → (−570,540) | 16 wide, arches, top ~45 (landmark) |
| Railway | (−2400,−560) (−1400,−470) (−1000,−440) (−600,−440) (−480,−340) (−460,−100) (−500,150) (−530,260) (−570,540) (−650,900) (−620,1700) | 16 wide (twin track); enters W, station, turns south over the viaduct, leaves S |
| Rivermere Station | centre (−800,−400) | building 240 × 24 × 40, platform side on the track at z −440 |
| Rail crossings (TEMP) | Ring (−1342,−466), High St / Station Rd (−466,−60), Ring (−627,795) | greybox as level crossings; later rail on embankment over the roads |

### Roads (carriageway widths; pavements +8 each side)

v3: every segment is axis-aligned or 45°. `front` is which sides `TownFrontage` builds along (left of the direction of travel); `use` is the building type, or *rule:name* when a `TownFrontage.RULES` rule picks it from the position. **head** = ends in a cul-de-sac turning head (radius 34). A residential street with front *none* is a connecting street whose corners are taken by the streets it joins.

| Road | Kind | Points (x, z) | Front | Use | District | Head |
|---|---|---|---|---|---|---|
| Ring Road | ring | (−1100, −1000) → (−500, −1000) → (−420, −1080) → (420, −1080) → (500, −1000) → (1000, −1000) → (1400, −600) → (1400, 400) → (1250, 550) → (1250, 650) → (1100, 800) → (−1000, 800) → (−1150, 650) → (−1150, 0) → (−1350, −200) → (−1350, −750) → (−1100, −1000) | none |  |  |  |
| North Road | main | (0, −60) → (0, −1080) | both | *rule:north road* |  |  |
| High Street | main | (−60, 0) → (−400, 0) → (−505, −105) → (−1255, −105) | both | *rule:high street* |  |  |
| Station Road | main | (−505, −105) → (−737, −337) → (−938, −337) | both | shops | Station |  |
| Riverside Road | main | (60, 0) → (1340, 0) → (1400, −60) | both | *rule:centre* |  |  |
| Bridge Street | main | (0, 60) → (0, 200) → (100, 300) → (100, 700) → (0, 800) | both | *rule:bridge street* |  |  |
| Mapleford Road | main | (−1350, −400) → (−2400, −400) | both | *rule:industrial* |  |  |
| Estate Road | main | (−1255, −105) → (−2400, −105) | both | *rule:industrial* |  |  |
| Greenbridge Road | main | (−1150, 560) → (−2400, 560) | right | terraced row | Westdale |  |
| Hollingford Road | main | (1250, 600) → (1300, 600) → (1500, 800) → (2400, 800) | both | terraced row | Hollingford |  |
| Guild Street | residential | (−330, 130) → (0, 130) | both | *rule:centre* |  |  |
| Quay Street | residential | (0, 130) → (480, 130) | both | *rule:centre* |  |  |
| Tanner Row | residential | (−330, 0) → (−330, 260) | both | *rule:centre* |  |  |
| Wharf Street | residential | (250, 0) → (250, 260) | none |  |  |  |
| Marina Way | residential | (760, 0) → (760, 190) | both | *rule:centre* |  | head |
| Chapel Street | residential | (−150, 0) → (−150, −330) | both | *rule:centre* |  |  |
| Fountain Street | residential | (250, 0) → (250, −200) | both | *rule:centre* |  |  |
| Dyers Lane | residential | (500, 0) → (500, −200) | both | *rule:centre* |  |  |
| Park Street | residential | (750, 0) → (750, −200) | both | *rule:centre* |  |  |
| Spinner Street | residential | (450, −200) → (450, −600) | none |  | Mill Street Terraces |  |
| Park Road | residential | (900, −200) → (900, −600) | both | terraced row | Mill Street Terraces |  |
| Loom Street | residential | (−200, −330) → (−200, −600) | both | terraced row | Mill Street Terraces |  |
| Mill Street | residential | (0, −200) → (900, −200) | both | terraced row | Mill Street Terraces |  |
| Weaver Street | residential | (−430, −330) → (900, −330) | both | terraced row | Mill Street Terraces |  |
| Elm Grove | residential | (−500, −440) → (900, −440) | both | terraced row | Mill Street Terraces |  |
| Northfields Avenue | residential | (−1350, −600) → (1400, −600) | both | terraced row | Northfields |  |
| Linden Way | residential | (−1000, −920) → (850, −920) | both | terraced row | Northfields |  |
| Elder Close | residential | (−1200, −600) → (−1200, −815) | both | semis | Northfields | head |
| Ash Close | residential | (−1000, −600) → (−1000, −920) | both | semis | Northfields |  |
| Birch Close | residential | (−800, −600) → (−800, −920) | both | semis | Northfields |  |
| Cherry Close | residential | (−600, −600) → (−600, −920) | both | terraced row | Northfields |  |
| Hazel Close | residential | (−400, −600) → (−400, −920) | both | terraced row | Northfields |  |
| Rowan Close | residential | (−200, −600) → (−200, −920) | both | terraced row | Northfields |  |
| Holly Close | residential | (225, −600) → (225, −920) | both | terraced row | Northfields |  |
| Hayfield Close | residential | (400, −600) → (400, −920) | both | terraced row | Northfields |  |
| Laurel Close | residential | (650, −600) → (650, −920) | both | terraced row | Northfields |  |
| Maple Close | residential | (850, −600) → (850, −920) | both | semis | Northfields |  |
| Oak Close | residential | (1050, −600) → (1050, −865) | both | semis | Northfields | head |
| Church Lane | residential | (−360, 0) → (−360, −330) | none |  | Town Centre |  |
| Cooper Street | residential | (−1350, −240) → (−640, −240) | both | terraced row | Station |  |
| Signal Street | residential | (−1150, 25) → (−560, 25) | both | terraced row | Station |  |
| Lock Street | residential | (−1150, 150) → (−540, 150) | both | terraced row | Station |  |
| Foundry Way | residential | (−1480, −400) → (−1480, 110) | both | *rule:industrial* |  |  |
| Lune Street | residential | (−440, 260) → (700, 260) | both | *rule:centre* |  | head |
| Platform Street | residential | (−850, −240) → (−850, 150) | none |  | Station |  |
| Goods Yard Lane | residential | (−1000, −105) → (−1000, −240) | none |  | Station |  |
| Forge Lane | residential | (−1800, −400) → (−1800, 110) | both | *rule:industrial* |  |  |
| Furnace Lane | residential | (−2120, −400) → (−2120, 110) | both | *rule:industrial* |  |  |
| Wharf Road | residential | (−1480, 110) → (−2250, 110) | none |  |  |  |
| Meadow Road | residential | (100, 560) → (1180, 560) | both | terraced row | Riverside | head |
| Tannery Row | residential | (100, 680) → (1100, 680) | both | terraced row | Riverside | head |
| Viaduct Road | residential | (−545, 620) → (100, 620) | both | terraced row | Riverside |  |
| Weir Road | residential | (−1150, 560) → (−615, 560) | both | terraced row | Riverside |  |
| Fuller Street | residential | (−1090, 690) → (−615, 690) | both | terraced row | Riverside |  |
| Sluice Lane | residential | (−850, 560) → (−850, 800) | none |  | Riverside |  |
| Dye Works Lane | residential | (600, 560) → (600, 800) | none |  | Riverside |  |
| Osier Lane | residential | (−250, 620) → (−250, 800) | both | terraced row | Riverside |  |
| Sports Centre Road | residential | (0, 800) → (0, 1200) → (590, 1200) | none |  | Riverside |  |
| Cedar Road | residential | (−470, 800) → (−470, 1500) | both | terraced row | Riverside | head |
| Paddock Road | residential | (400, 800) → (400, 1500) | both | semis | Riverside | head |
| Hollins Road | residential | (590, 800) → (590, 1500) | both | terraced row | Riverside | head |
| Plot 1 Lane | lane | (970, 800) → (970, 860) | none |  |  |  |
| Moss Lane | residential | (−2240, 430) → (−1250, 430) | both | semis | Westdale |  |
| Reed Road | residential | (−1600, 430) → (−1600, 560) | none |  | Westdale |  |
| Alder Road | residential | (−1310, 560) → (−1310, 1480) | both | terraced row | Westdale |  |
| Tanner's Lane | residential | (−2240, 560) → (−2240, 1480) | both | semis | Westdale |  |
| Orchard Road | residential | (−2240, 1480) → (−730, 1480) | both | terraced row | Westdale | head |
| Fern Street | residential | (−1310, 800) → (−1000, 800) | both | terraced row | Westdale |  |
| Westdale Avenue | residential | (−1310, 950) → (−730, 950) | both | terraced row | Westdale | head |
| Brook Street | residential | (−1310, 1100) → (−730, 1100) | both | terraced row | Westdale | head |
| Westdale Crescent | residential | (−1310, 1250) → (−730, 1250) | both | terraced row | Westdale | head |
| Coronation Street | residential | (−1310, 1365) → (−730, 1365) | both | terraced row | Westdale | head |
| Westdale Road | residential | (−915, 800) → (−915, 1480) | both | terraced row | Westdale |  |
| Plot 3 Lane | lane | (−1860, 560) → (−1860, 630) | none |  |  |  |
| Plot 4 Lane | lane | (−1350, −750) → (−1350, −1210) → (−1400, −1210) | none |  |  |  |
| Mapleford Lane | residential | (−2250, −670) → (−1350, −670) | both | terraced row | Mapleford |  |
| Drift Close | residential | (−2250, −670) → (−2250, −1060) | both | detached house | Mapleford | head |
| Tollgate Road | residential | (−1350, −1210) → (−1350, −1590) → (−2120, −1590) | both | terraced row | Mapleford | head |
| Drovers Road | residential | (−1350, −1210) → (−760, −1210) | both | terraced row | Mapleford | head |
| Pinfold Close | residential | (−950, −1210) → (−950, −1110) | both | detached house | Mapleford | head |
| Smithy Close | residential | (−1120, −1210) → (−1120, −1460) → (−880, −1460) | both | semis | Mapleford | head |
| Plot 2 Lane | lane | (1400, −600) → (1400, −1080) → (1440, −1080) | none |  |  |  |
| Millbrook Road | residential | (1400, −700) → (2300, −700) | both | terraced row | Millbrook |  |
| Lune View | residential | (1560, −570) → (2250, −570) | both | detached house | Millbrook | head |
| Fell Lane | residential | (2300, −700) → (2300, −1320) | both | semis | Millbrook | head |
| Quarry Road | residential | (1400, −1080) → (900, −1080) → (780, −1200) | both | terraced row | Millbrook | head |
| Kiln Close | residential | (1180, −1080) → (1180, −1400) | both | semis | Millbrook | head |
| Millbrook Rise | residential | (1400, −1080) → (1400, −1330) | both | terraced row | Millbrook | head |
| Lunebank Road | residential | (1400, 300) → (1500, 300) → (1940, 740) → (1940, 800) | both | terraced row | Hollingford |  |
| Ferry Lane | residential | (1500, 300) → (1593, 207) | none |  | Hollingford |  |
| Fellmonger Street | residential | (1500, 480) → (1760, 740) → (1760, 800) | both | terraced row | Hollingford |  |
| Bleach Street | residential | (1593, 207) → (2126, 740) → (2126, 800) | both | semis | Hollingford |  |
| Garth Road | residential | (1510, 800) → (1510, 1560) | both | detached house | Hollingford | head |
| Ropewalk | residential | (1660, 640) → (1843, 457) | none |  | Hollingford |  |

### Roundabouts and square

| Name | Centre (x, z) | Radius |
|---|---|---|
| Northfields Roundabout | (0, −1080) | 40 |
| Plot 4 Roundabout | (−1350, −750) | 40 |
| Plot 2 Roundabout | (1400, −600) | 40 |
| Lunebank Roundabout | (1400, 300) | 40 |
| Hollingford Roundabout | (1250, 600) | 40 |
| Sports Centre Roundabout | (0, 800) | 40 |
| Westdale Roundabout | (−1150, 560) | 40 |
| High Street Roundabout | (−1255, −105) | 40 |
| Mapleford Roundabout | (−1350, −400) | 40 |
| Foundry Way Roundabout | (−1480, −105) | 16 |
| Market Square | (0, 0) | 60 |

"Plot 3 Roundabout" is now **Lunebank Roundabout**: plot 3 no longer hangs off it.

### Districts

Two layers. **Specials** are hand-placed in `TownLayout.DISTRICTS` (35 blocks). **Lots** are generated by `TownFrontage.generate()` (868 lots: terraced row 416, semis 209, detached house 107, corner shop 46, shops with flats 36, shops 18, workshop 18, flats 11, trade counter 4, warehouse 3).

| District | Kind | Specials (use at x, z) | Generated lots |
|---|---|---|---|
| Town Centre | centre | pub (400, −41); supermarket (−260, 36); town hall (−150, 200); church (−220, −230); pub (−50, −87); pub (87, −50); pub (−385, 41); pub (−183, −59); pub (−117, −54); school (−250, 310); pub (−365, 95) | shops with flats 36, shops 7 |
| Mill Street Terraces | terraced | — | terraced row 54, corner shop 7 |
| Northfields | estate | school (−1100, −750); park (1155, −675); park (−100, −760); park (525, −760); shops (80, −645); shops (−80, −555) | terraced row 75, semis 34, corner shop 7 |
| Riverside | riverside | pub and cafes (560, 130); waterfront flats (600, 214); marina (900, 240) | terraced row 86, semis 25, flats 11, corner shop 10 |
| Riverside Park | park | park lawn (1150, −320); bandstand (1150, −300); park cafe (1050, −120) | — |
| Station | station | station car park (−1020, −350); pub (−668, −330) | terraced row 30, shops 11, corner shop 4 |
| Industrial Estate | industrial | builders yard (−1650, 20) | workshop 18, trade counter 4, warehouse 3 |
| Westdale | estate | school (−1110, 1025); park (−820, 1175) | terraced row 78, semis 73, corner shop 7 |
| Community Sports Centre | sports | grass pitch (220, 1000); grass pitch (−220, 1050); 3G pitch (−220, 1400); sports hall (220, 1300); 3G pitch (−60, 1000); grass pitch (220, 1450) | — |
| Mapleford | estate | — | terraced row 37, detached house 24, semis 15, corner shop 2 |
| Millbrook | estate | — | detached house 41, semis 35, terraced row 25, corner shop 4 |
| Hollingford | estate | park (1600, 80) | detached house 42, terraced row 31, semis 27, corner shop 5 |

How a lot is made (full rules at the top of `TownFrontage.luau`): one row of cells down each fronted side of a street at setback = carriageway/2 + pavement 8 + the type's garden + depth/2. A cell is dropped if it comes within 4 of another road's pavement, or too near the river (+20), the rail (+22), a roundabout, a turning head, the square, the station, a bus stop (16), a plot (+20), a special (6) or an earlier cell (10). Main roads fill first, then the longest streets. Cells join into lots by the type's `group` (terrace of 6, pair of semis); roughly one terrace in three gives its end cell to a corner shop; each cul-de-sac gets a short row across its end (`closesStreet`).

| Type | Cell | Depth | Group | Gap | Garden | Height (TEMP) |
|---|---|---|---|---|---|---|
| terraced row | 22 | 24 | 6 | 8 | 6 | 28 |
| semis | 25 | 24 | 2 | 12 | 8 | 28 |
| detached house | 34 | 26 | 1 | 14 | 10 | 28 |
| corner shop | 22 | 24 | 1 | 4 | 6 | 28 |
| shops with flats | 26 | 30 | 5 | 6 | 0 | 36 |
| shops | 30 | 30 | 3 | 6 | 0 | 20 |
| flats | 70 | 36 | 1 | 16 | 8 | 44 |
| workshop | 80 | 50 | 1 | 16 | 10 | 24 |
| trade counter | 80 | 50 | 1 | 16 | 10 | 24 |
| warehouse | 160 | 100 | 1 | 24 | 14 | 36 |

## 4. Road hierarchy

| Kind | Carriageway | Pavements | Role | Speed feel |
|---|---|---|---|---|
| ring | 32 | 8 + 8 | loop linking every plot, district and exit; bus route | two lanes, roundabouts |
| main | 26 | 8 + 8 | spokes from the square, exits, station, estate | two-way with parking bays |
| residential | 20 | 8 + 8 | terraced and estate streets | parked cars one side |
| lane | 20 | none (greybox) | plot access, ends 10 outside the plot's vehicle gate | club traffic, matchday queues |

## 5. Walking times

Route length TEMP = straight line × 1.3. Centre = market square; plots = their bus stops.

| From → To | Route (studs) | Walk 16/s | Sprint 26/s |
|---|---|---|---|
| Centre → Plot 1 | 1690 | 1 m 46 s | 65 s |
| Centre → Plot 2 | 2440 | 2 m 33 s | 94 s |
| Centre → Plot 3 | 2114 | 2 m 12 s | 81 s |
| Centre → Plot 4 | 2572 | 2 m 41 s | 99 s |
| Centre → Station | 1067 | 67 s | 41 s |
| Plot 1 → Plot 3 | 824 | 51 s | 32 s |
| Plot 1 → Plot 2 | 2657 | 2 m 46 s | 102 s |
| Plot 2 → Plot 3 | 2164 | 2 m 15 s | 83 s |
| Plot 2 → Plot 4 | 3880 | 4 m 02 s | 149 s |
| Plot 1 → Plot 4 | 4262 | 4 m 26 s | 164 s |
| Plot 3 → Plot 4 | 4598 | 4 m 47 s | 177 s |

Anything over ~2 minutes is what the bus stops and the "go to my club" button are for.

## 6. Bus stops (fast travel)

| Stop | Position (x, z) | Shelter yaw | Road |
|---|---|---|---|
| Town Centre | (90, −20) | 180 | Riverside Road |
| Station | (−915, −355) | 180 | Station Road |
| Riverside | (700, 22) | 0 | Riverside Road |
| Riverside Park | (1180, −22) | 180 | Riverside Road |
| Industrial Estate | (−1600, −130) | 180 | Estate Road |
| Westdale | (−1075, 964) | 0 | Westdale Avenue |
| Sports Centre | (40, 1180) | 180 | Sports Centre Road |
| Plot 1 | (992, 840) | 90 | Plot 1 Lane |
| Plot 2 | (1420, −1058) | 0 | Plot 2 Lane |
| Plot 3 | (−1838, 610) | 90 | Plot 3 Lane |
| Plot 4 | (−1380, −1232) | 180 | Plot 4 Lane |

v3 moved the three plot stops with their lanes, and put Riverside and Riverside Park on Riverside Road's pavement (they stood 50 and 27 behind the kerb). `yaw` is the way the shelter opens.

## 7. Landmarks and sightlines

| Landmark | Position (x, z) | Top height | Seen from |
|---|---|---|---|
| Church spire | (−220, −240) | 130 (~47 m) | every plot and most streets; roofs are ≤ 40 |
| Lune Viaduct | (−550, 400) | 45 | river paths, Westdale, Lune Bridge, station |
| Lune Bridge | (100, 420) | 14 | Riverside promenade, Bridge Street |

| From (bus stop) | Spire distance / bearing | Viaduct distance / bearing |
|---|---|---|
| Plot 1 | 1623 / 312° (NW) | 1604 / 286° (W) |
| Plot 2 | 1933 / 242° (WSW) | 2557 / 233° (SW) |
| Plot 3 | 1918 / 293° (WNW) | 2094 / 273° (W) |
| Plot 4 | 1656 / 130° (SE) | 1944 / 151° (SSE) |
| Station | 533 / 102° (E) | 779 / 166° (S) |
| Westdale | 1477 / 35° (NE) | 771 / 43° (NE) |

Rules: keep a gap in tree lines on each plot's entrance side along the spire bearing; nothing in town taller than
60 except the spire, floodlights and endgame stand roofs; the spire must clear roofs from 560+ studs away
(eye 5, roof 40, spire 130).

## 8. Reference image per district

| District / piece | Reference |
|---|---|
| Overall arrangement | `assets/references/RivermereAIMap.png` |
| Town Centre, market square, High Street | `assets/references/RivermereCenter.png` |
| Mill Street Terraces, Westdale | `assets/references/RiveremereWestdale.png` |
| Northfields | `assets/references/RivermereNorthfields.png` |
| Riverside, Riverside Park, Lune Bridge | `assets/references/RivermereRiverside.png` |
| Station, Station Road, bus stops | `assets/references/RivermereStation.png` |
| Industrial Estate | `assets/references/rivermer.industrialestate.png` |
| Plot entrance, club shop, turnstiles | `assets/references/RivermereTurnstileEntrance.png` |
| Community Sports Centre | `RivermereAIMap.png` (south, no close-up yet) |

## 9. TEMP choices for Marcel

| # | Choice | Why |
|---|---|---|
| T1 | Plot 760 × 760 | fits a ~480 × 560 stadium plus 140-wide entrance and training strips; training pitches are small |
| T2 | River Lune 90 wide (~33 m) | reads as a proper river, three bridges and a viaduct are short enough to build |
| T3 | Rail turns south after the station and crosses the river on the viaduct | the map's line stops at the station; the viaduct landmark needs a crossing |
| T4 | Three level crossings in greybox | cheap now; swap for rail bridges when E7.1 dresses the line |
| T5 | Plot 2 and Plot 4 sit outside the ring on short lanes | keeps the ring compact and the plots on the town edge |
| T6 | Exit names Mapleford (W), Greenbridge (SW), Hollingford (E) | taken from the map's road signs; no north exit |
| T7 | Walking route factor 1.3 | replaced by measured times in C2.2 |
