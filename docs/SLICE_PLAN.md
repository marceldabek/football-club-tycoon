# Vertical Slice — Site Plan

> One club block, built as static geometry in `Workspace.VerticalSlice`, far from the origin so it
> never collides with the runtime-built ground from `WorldBuilder`. Scale: 2.75 studs per metre
> (same as the game). Ground level is y = 0.

## Site frame

Site origin **(3000, 0, 2000)**. +X is east (towards the pitch), +Z is south.

| Element | X range | Z range | Notes |
|---|---|---|---|
| Base pad (grass) | 2880–3400 | 1820–2180 | Part, Grass material, top at y=0 |
| Ground Lane (road) | 2990–3010 | 1820–2180 | 20 studs = 7.3 m two-way, Asphalt, dashed centre line |
| West pavement | 2982–2990 | 1820–2180 | 0.5 high kerb, Concrete |
| East pavement | 3010–3018 | 1820–2180 | same, dropped kerb at the club entrance |
| House plots (5) | 2945–2982 | centres 1900, 1930, 1960, 1990, 2020 | Modular English Housing prefabs facing east, 12-deep front gardens, garden walls/hedges/gates on the pavement line |
| Club fence line | 3020 | 1880–2120 | corrugated / wire fence, entrance gap at Z 1990–2010 |
| Car park | 3022–3090 | 1940–2060 | Asphalt, painted bays, bollards, bins, skip, parked cars |
| Club building | 3096–3132 | 1964–2044 | single storey brick, flat roof with parapet, 12 high |
| Tunnel mouth | 3132–3140 | 1996–2012 | building east wall onto the west touchline |
| Concourse | 3100–3120 | 1880–1960 | concrete, kiosk hatch in the building's north wall, turnstile block at 3090–3100 / 1900–1912 |
| Stand | 3120–3140 | 1880–1960 | 5 terrace steps rising west, crush barriers, roof on steel columns |
| Pitch | 3140–3330 | 1855–2145 | 190 × 290, same size as the game pitch, centre (3235, 0, 2000) |
| Far perimeter | around the pitch | | fence + hedge + trees + ad boards (low detail) |

Inside the building (west to east: 36 studs deep; north to south: 80 long):
- north end (Z 1964–1988): kiosk / store room, hatch facing the concourse
- middle (Z 1988–2020): tunnel corridor with dressing room either side
- south end (Z 2020–2044): club office (spawn), window onto the car park

## Build order (Target 5)
1. Large forms: pad, road, pavements, car park, pitch, building shell, stand, fence line
2. Medium: houses, garden walls, hedges, trees, lamp posts, telegraph poles, parked cars, bus shelter
3. Interiors: office, dressing room, tunnel, kiosk
4. Small detail: signs, bins, skip, pallets, utility boxes, drains, posters, weeds
5. Lighting: ClockTime ~14:30, warm sun, Atmosphere haze, ColorCorrection, restrained Bloom

## Review spawn
A review SpawnLocation sits on the west pavement at the south end (2986, 1, 2170) facing north, so the
first thing seen is the street with the club on the right.
