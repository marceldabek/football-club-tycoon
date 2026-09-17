# Town Plan — Rivermere greybox master plan

> Backlog C1.1. Data twin: `src/shared/TownLayout.luau` (C1.2), checked by `tests/TownLayoutTest.luau`.
> If this file and the module disagree, the module wins and this file gets fixed.
> Every number here is **TEMP** until the greybox walk test (C2.2) and Marcel confirm it.
> Source: `assets/references/RivermereAIMap.png`, arrangement kept, scaled down. The map's
> labels use an old town name; the town is **Rivermere** and the river is the **River Lune**.

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

| Plot | Site | Centre (x, z) | Yaw | Entrance faces | World bounds x / z | Access | Bus stop (x, z) | River clearance |
|---|---|---|---|---|---|---|---|---|
| 1 | SE | (1050, 1250) | 270° | north | 670..1430 / 870..1630 | Plot 1 Lane off Ring S (970, 761) | (992, 840) | 491 |
| 2 | NE | (1900, −1200) | 0° | west | 1520..2280 / −1580..−820 | Plot 2 Lane off Plot 2 Roundabout | (1490, −1142) | 380 |
| 3 | E | (1950, 420) | 0° | west | 1570..2330 / 40..800 | Plot 3 Lane off Plot 3 Roundabout | (1540, 522) | 123 |
| 4 | NW | (−1900, −1200) | 180° | east | −2280..−1520 / −1580..−820 | Plot 4 Lane off Plot 4 Roundabout | (−1490, −1302) | 1006 |

Every access lane (X6) ends at `plotCFrame(i) * TownLayout.PLOT_LANE_END` = plot-local (−390, 0, 80), 10 studs
outside the vehicle gate (`PlotGrounds`: gate at local x −380, z 60..100). Gate ends in world: Plot 1 (970, 860),
Plot 2 (1510, −1120), Plot 3 (1560, 500), Plot 4 (−1510, −1280). Each plot bus stop sits 22 beside its lane, 20 back
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

| Kind | Width | Road | Points (x, z) |
|---|---|---|---|
| ring | 32 | Ring Road (closed loop) | (−1300,−800) (−650,−1000) (0,−1050) (650,−1000) (1300,−800) (1400,−400) (1400,−60) (1400,150) (1400,400) (1250,720) (700,800) (0,800) (−600,800) (−1100,700) (−1150,430) (−1150,200) (−1250,−100) (−1350,−400) (−1300,−800) |
| main | 26 | Mapleford Road (exit W) | (−1350,−400) → (−2400,−380) |
| main | 26 | Greenbridge Road (exit SW) | (−1100,700) (−1100,1100) (−2400,1500) |
| main | 26 | Hollingford Road (exit E) | (1250,720) (1500,840) (2400,860) |
| main | 26 | High Street | (−1250,−100) (−460,−60) (−60,0) |
| main | 26 | Riverside Road | (60,0) (500,40) (900,60) (1400,−60) |
| main | 26 | North Road | (0,−60) → (0,−1050) |
| main | 26 | Bridge Street | (0,60) (100,300) (100,540) (0,800) |
| main | 26 | Station Road | (−460,−60) (−700,−300) (−800,−340) |
| main | 26 | Estate Road | (−1250,−100) → (−2300,−110) |
| residential | 20 | Mill Street | (0,−200) → (900,−200) |
| residential | 20 | Weaver Street | (−430,−330) → (900,−330) |
| residential | 20 | Elm Grove | (−500,−440) → (900,−440) |
| residential | 20 | Northfields Avenue | (−1320,−600) → (1345,−600) |
| residential | 20 | Hayfield Close | (400,−600) → (400,−920) |
| residential | 20 | Rowan Close | (−200,−600) → (−200,−920) |
| residential | 20 | Westdale Avenue | (−1100,950) → (−690,950) |
| residential | 20 | Westdale Crescent | (−1250,1250) → (−690,1250) |
| residential | 20 | Sports Centre Road | (0,800) (0,1200) (520,1200) |
| residential | 20 | Linden Way | (−700,−920) → (700,−920) |
| residential | 20 | Elder Close | (−1200,−600) → (−1200,−827) |
| residential | 20 | Ash Close | (−1000,−600) → (−1000,−888) |
| residential | 20 | Birch Close | (−800,−600) → (−800,−950) |
| residential | 20 | Cherry Close | (−600,−600) → (−600,−920) |
| residential | 20 | Hazel Close | (−400,−600) → (−400,−920) |
| residential | 20 | Holly Close | (225,−600) → (225,−920) |
| residential | 20 | Laurel Close | (650,−600) → (650,−920) |
| residential | 20 | Maple Close | (850,−600) → (850,−935) |
| residential | 20 | Oak Close | (1050,−600) → (1050,−873) |
| residential | 20 | Poplar Close | (1250,−600) → (1250,−812) |
| residential | 20 | Church Lane | (−360,−45) → (−360,−330) |
| residential | 20 | Cooper Street | (−1296,−240) → (−640,−240) |
| residential | 20 | Lock Street | (−1160,150) → (−540,150) |
| residential | 20 | Lune Street | (−440,260) → (480,260) |
| residential | 20 | Meadow Road | (92,560) → (1325,560) |
| residential | 20 | Viaduct Road | (−545,620) → (69,620) |
| residential | 20 | Weir Road | (−1126,560) → (−615,560) |
| residential | 20 | Westdale Road | (−915,737) → (−915,1400) |
| residential | 20 | Brook Street | (−1100,1100) → (−690,1100) |
| residential | 20 | Orchard Road | (−1700,1400) → (−690,1400) |
| residential | 20 | Alder Road | (−1250,1146) → (−1250,1400) |
| residential | 20 | Cedar Road | (−470,800) → (−470,1500) |
| residential | 20 | Moss Lane | (−1800,560) → (−1134,560) |
| residential | 20 | Fern Street | (−1800,800) → (−1113,800) |
| residential | 20 | Reed Road | (−1600,380) → (−1600,1110) |
| residential | 20 | Hollins Road | (520,800) → (520,1500) |
| residential | 20 | Foundry Way | (−1480,−397) → (−1480,120) |
| lane | 20 | Plot 1 Lane | (970,761) → (970,860) |
| lane | 20 | Plot 2 Lane | (1300,−800) (1300,−1120) (1510,−1120) |
| lane | 20 | Plot 3 Lane | (1400,400) (1460,500) (1560,500) |
| lane | 20 | Plot 4 Lane | (−1300,−800) (−1300,−1280) (−1510,−1280) |

Streets added or lengthened in the X5 densify pass: Mill, Weaver and Elm Grove run on to x 900; Northfields Avenue
spans the ring; twelve closes (Elder … Poplar) run north to Linden Way or the ring; Church Lane, Cooper Street and
Lock Street fill the centre and station side; Lune Street, Meadow Road, Viaduct Road and Weir Road line the river
banks; Westdale Road, Brook Street, Orchard Road, Alder Road, Cedar Road, Moss Lane, Fern Street and Reed Road make
Westdale; Hollins Road runs beside Plot 1; Foundry Way serves the industrial estate. Moss Lane and Weir Road meet the
ring as a plain crossroads (TEMP, no roundabout).

### Roundabouts (radius 40) and square

| Name | Centre (x, z) | Joins |
|---|---|---|
| Market Square (radius 60, pedestrian core) | (0, 0) | High Street, Riverside Road, North Road, Bridge Street |
| Northfields | (0, −1050) | Ring, North Road |
| Plot 4 | (−1300, −800) | Ring, Plot 4 Lane |
| Plot 2 | (1300, −800) | Ring, Plot 2 Lane |
| Plot 3 | (1400, 400) | Ring, Plot 3 Lane |
| Hollingford | (1250, 720) | Ring, Hollingford Road |
| Sports Centre | (0, 800) | Ring, Bridge Street, Sports Centre Road |
| Westdale | (−1100, 700) | Ring, Greenbridge Road |
| High Street | (−1250, −100) | Ring, High Street, Estate Road |
| Mapleford | (−1350, −400) | Ring, Mapleford Road |

### Districts (greybox volumes; heights in studs)

| District | Kind | Area x / z | Blocks | Contents |
|---|---|---|---|---|
| Town Centre | centre | −455..539 / −275..340 | 49 | shops, shops with flats and pubs wrapping the market square and lining High Street, Riverside Road, North Road and Bridge Street, flats behind; supermarket, town hall (−150,200), church (−220,−230), school (−250,310) |
| Mill Street Terraces | terraced | −444..950 / −414..−115 | 48 | terraced rows (100–140 × 22–26 × 24) both sides of Mill St, Weaver St and Church Lane, back-to-back. The original 8 rows (x 100 / 300) moved 8 studs off the street to clear the pavement (z −164, −236, −294, −366). **First district to dress (E3.1)** |
| Northfields | estate | −1300..1296 / −1004..−458 | 168 | terraced rows and semis on Elm Grove, Northfields Avenue, North Road, Linden Way and the twelve closes; corner shops; school (−1100,−750) |
| Riverside | riverside | −620..1302 / −88..1570 | 167 | flats on Riverside Road and Lune Street, marina basin (900,240); south bank terraces on Meadow Road, Viaduct Road, Bridge Street, the ring and Hollins Road |
| Riverside Park | park | 970..1330 / −560..−80 | 3 | lawn 360 × 480, bandstand, park café |
| Station | station | −1286..−489 / −380..234 | 55 | station car park (−1000,−350), shops on Station Road, terraced rows on Cooper Street, High Street west and Lock Street |
| Industrial Estate | industrial | −2390..−1300 / −560..123 | 43 | the six big sheds plus warehouses, workshops and trade counters on Estate Road, Mapleford Road and Foundry Way |
| Westdale | estate | −1800..−386 / 380..1550 | 143 | terraced rows on Weir Road, the ring, Westdale Avenue / Crescent / Road, Brook Street, Orchard, Alder and Cedar Roads, and Moss Lane / Fern Street / Reed Road west of the ring; corner shops; school (−1250,1000) |
| Community Sports Centre | sports | −300..340 / 920..1500 | 6 | three grass pitches, two 3G pitches and a sports hall (220,1300) |

Total **682** blocks (was 74). Rules checked by `tests/TownLayoutTest.luau`: all yaw 0; no two blocks overlap (1-stud
tolerance; a building may stand on a flat ground piece); every block clears carriageway + 8 pavement, river width/2 + 20
(marina excepted), rail width/2 + 10, roundabouts and the square (+8), bus stops (12), landmarks (30, the church nave
excepted) and plots (+20); at least 400 blocks. Rows were laid by a frontage script (set back 6 from the pavement,
back-to-back pairs with a 12 alley, terraces 100–140 long with 10 gaps, semis 40–50 with 10–16 gaps, industrial
sheds 120–180 with yards between) and checked numerically before commit.

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
| Town Centre | (90, −20) | 0 | Riverside Road by the square |
| Station | (−740, −355) | 0 | Station Road forecourt |
| Riverside | (700, 80) | 0 | Riverside Road |
| Riverside Park | (1180, −40) | 0 | Riverside Road |
| Industrial Estate | (−1600, −130) | 0 | Estate Road |
| Westdale | (−1075, 964) | 0 | Westdale Avenue |
| Sports Centre | (40, 1180) | 0 | Sports Centre Road |
| Plot 1 | (992, 840) | 90 | Plot 1 Lane |
| Plot 2 | (1490, −1142) | 180 | Plot 2 Lane |
| Plot 3 | (1540, 522) | 0 | Plot 3 Lane |
| Plot 4 | (−1490, −1302) | 180 | Plot 4 Lane |

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
