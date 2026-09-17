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
| 1 | SE | (1050, 1250) | 270° | north | 670..1430 / 870..1630 | Plot 1 Lane off Ring S (1050, 750) | (1090, 835) | 491 |
| 2 | NE | (1900, −1200) | 0° | west | 1520..2280 / −1580..−820 | Plot 2 Lane off Plot 2 Roundabout | (1470, −1160) | 380 |
| 3 | E | (1950, 420) | 0° | west | 1570..2330 / 40..800 | Plot 3 Lane off Plot 3 Roundabout | (1520, 460) | 123 |
| 4 | NW | (−1900, −1200) | 180° | east | −2280..−1520 / −1580..−820 | Plot 4 Lane off Plot 4 Roundabout | (−1470, −1160) | 1006 |

Nearest road edge to any plot is 20 studs (the access lane ends). Rail clearance: Plot 4 270, others > 1200.

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
| residential | 20 | Mill Street | (0,−200) → (450,−200) |
| residential | 20 | Weaver Street | (0,−330) → (450,−330) |
| residential | 20 | Elm Grove | (−350,−440) → (450,−440) |
| residential | 20 | Northfields Avenue | (−350,−600) → (900,−600) |
| residential | 20 | Hayfield Close | (400,−600) → (400,−900) |
| residential | 20 | Rowan Close | (−200,−600) → (−200,−900) |
| residential | 20 | Westdale Avenue | (−1100,950) → (−720,950) |
| residential | 20 | Westdale Crescent | (−1100,1250) → (−720,1250) |
| residential | 20 | Sports Centre Road | (0,800) (0,1200) (450,1200) |
| lane | 20 | Plot 1 Lane | (1050,750) → (1050,850) |
| lane | 20 | Plot 2 Lane | (1300,−800) (1320,−1200) (1500,−1200) |
| lane | 20 | Plot 3 Lane | (1400,400) → (1550,420) |
| lane | 20 | Plot 4 Lane | (−1300,−800) (−1320,−1200) (−1500,−1200) |

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
| Town Centre | centre | −310..450 / −275..230 | 12 | 4 shop blocks around the square (h 36–40), 6 high-street shops/pub/supermarket (h 30–34), town hall (−150,200), church (−220,−230) |
| Mill Street Terraces | terraced | 35..365 / −370..−160 | 8 | terraced rows 130 × 24 × 24 both sides of Mill St and Weaver St, back-to-back gardens between. **First district to dress (E3.1)** |
| Northfields | estate | −340..800 / −890..−458 | 23 | semis on Elm Grove, rows both sides of Northfields Avenue, Hayfield Close and Rowan Close |
| Riverside | riverside | 500..970 / 110..280 | 4 | pub/cafés, flats, waterfront flats on the north bank, marina basin (900,240) |
| Riverside Park | park | 970..1330 / −560..−80 | 3 | lawn 360 × 480, bandstand, park café |
| Station | station | −1060..−680 / −420..−320 | 1 + station | station building, car park (−1000,−350) |
| Industrial Estate | industrial | −2230..−1570 / −300..65 | 6 | two rows of sheds (160 × 100, h 26–30) either side of Estate Road |
| Westdale | estate | −1610..−770 / 508..1292 | 13 | rows by the West Bridge, Westdale Avenue and Crescent, semis on Greenbridge Road |
| Community Sports Centre | sports | −300..340 / 920..1500 | 4 | three pitches and a sports hall (220,1300) |

## 4. Road hierarchy

| Kind | Carriageway | Pavements | Role | Speed feel |
|---|---|---|---|---|
| ring | 32 | 8 + 8 | loop linking every plot, district and exit; bus route | two lanes, roundabouts |
| main | 26 | 8 + 8 | spokes from the square, exits, station, estate | two-way with parking bays |
| residential | 20 | 8 + 8 | terraced and estate streets | parked cars one side |
| lane | 20 | 8 one side | plot access, ends at the plot edge | club traffic, matchday queues |

## 5. Walking times

Route length TEMP = straight line × 1.3. Centre = market square; plots = their bus stops.

| From → To | Route (studs) | Walk 16/s | Sprint 26/s |
|---|---|---|---|
| Centre → Plot 1 | 1785 | 1 m 52 s | 69 s |
| Centre → Plot 2 | 2434 | 2 m 32 s | 94 s |
| Centre → Plot 3 | 2065 | 2 m 09 s | 79 s |
| Centre → Plot 4 | 2434 | 2 m 32 s | 94 s |
| Centre → Station | 1067 | 67 s | 41 s |
| Plot 1 → Plot 3 | 742 | 46 s | 29 s |
| Plot 1 → Plot 2 | 2640 | 2 m 45 s | 102 s |
| Plot 2 → Plot 3 | 2107 | 2 m 12 s | 81 s |
| Plot 2 → Plot 4 | 3822 | 3 m 59 s | 147 s |
| Plot 1 → Plot 4 | 4219 | 4 m 24 s | 162 s |
| Plot 3 → Plot 4 | 4421 | 4 m 36 s | 170 s |

Anything over ~2 minutes is what the bus stops and the "go to my club" button are for.

## 6. Bus stops (fast travel)

| Stop | Position (x, z) | Shelter yaw | Road |
|---|---|---|---|
| Town Centre | (90, −20) | 0 | Riverside Road by the square |
| Station | (−740, −355) | 0 | Station Road forecourt |
| Riverside | (700, 80) | 0 | Riverside Road |
| Riverside Park | (1180, −40) | 0 | Riverside Road |
| Industrial Estate | (−1600, −130) | 0 | Estate Road |
| Westdale | (−1060, 930) | 0 | Westdale Avenue |
| Sports Centre | (40, 1180) | 0 | Sports Centre Road |
| Plot 1 | (1090, 835) | 0 | Plot 1 Lane |
| Plot 2 | (1470, −1160) | 90 | Plot 2 Lane |
| Plot 3 | (1520, 460) | 90 | Plot 3 Lane |
| Plot 4 | (−1470, −1160) | 270 | Plot 4 Lane |

## 7. Landmarks and sightlines

| Landmark | Position (x, z) | Top height | Seen from |
|---|---|---|---|
| Church spire | (−220, −240) | 130 (~47 m) | every plot and most streets; roofs are ≤ 40 |
| Lune Viaduct | (−550, 400) | 45 | river paths, Westdale, Lune Bridge, station |
| Lune Bridge | (100, 420) | 14 | Riverside promenade, Bridge Street |

| From (bus stop) | Spire distance / bearing | Viaduct distance / bearing |
|---|---|---|
| Plot 1 | 1695 / 309° (NW) | 1697 / 285° (W) |
| Plot 2 | 1924 / 241° (WSW) | 2552 / 232° (SW) |
| Plot 3 | 1876 / 292° (WNW) | 2071 / 272° (W) |
| Plot 4 | 1552 / 126° (SE) | 1811 / 149° (SSE) |
| Station | 533 / 102° (E) | 779 / 166° (S) |
| Westdale | 1440 / 36° (NE) | 736 / 44° (NE) |

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
