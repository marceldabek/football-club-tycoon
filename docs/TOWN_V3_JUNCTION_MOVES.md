# Rivermere v3: layout moves that give every junction a real kit piece

Status: APPLIED 2026-09-20 (Marcel approved groups A, B and C), in `tools/town_plan_v3.py` and
emitted to `TownLayout`. The raised-entry (ramp) code is removed; `RoadTilesTest.everyTownJunctionGetsARealKitPiece`
holds the town at 0 makeshift junctions.

Differences from the proposal:
- **Riverside Road does NOT go north to the ring**: that route runs through Riverside Park. It
  ends in a turning head at (1290, 0) by the park instead. OPEN for Marcel: keep this, or take
  about a fifth off the park's east side so the road can reach the ring at z -170.
- Cooper Street ends at x -720 with a turning head (not a bare dead end at -700).
- Loom Street is `front = "none"`: the rows on the streets it crosses take its corners.
- Osier Lane follows Viaduct Road to z 560.
- Specials moved clear of the new lines: supermarket x -260 -> -220, town-centre pub x 400 -> 360,
  Station pub z -330 -> -296, Northfields park 100 -> 90 wide at x -80, Northfields shops 110 -> 100
  wide, Westdale park to the west side of Westdale Road (x -940).
- Built town after the moves: 0 tucked junctions, crossroads 25 -> 37, lots 868 -> 861,
  housing units 2,681 -> 2,638 (-1.6%), trade lots 156 -> 148, all part budgets still met.

Why: 26 junctions have no proper piece (`RoadTiles.plan().makeshift`). 21 are raised
entries (ramps), which Marcel does not want; 5 still tuck under. The kit's T piece and
Crossroads are 90 studs long, so they only fit where junctions are spaced for them. The
moves below were dry-run through `RoadTiles.plan` on a copy of `TownLayout.ROADS`:
result 0 makeshift junctions, 0 ramps, 0 tucks, crossroads 25 -> 37, tiles 738 -> 735.

Houses, shops and gardens follow their street automatically (`TownFrontage`), so a move
re-generates the lots on that street. Bus stops, signs, alleys and specials near a moved
street need checking when the moves are applied.

## A. Staggered pairs become crossroads (small shifts)
| Move | From | To | Result |
|---|---|---|---|
| Hollins Road (and the end of Sports Centre Road) | x 590 | x 600 | crossroads with Dye Works Lane on the ring |
| Park Street | x 750 | x 760 | crossroads with Marina Way on Riverside Road |
| Hayfield Close | x 400 | x 450 | crossroads with Spinner Street on Northfields Avenue |
| Dyers Lane | x 500 | x 450 | crossroads with Spinner Street on Mill Street |
| Maple Close (and the end of Linden Way) | x 850 | x 900 | crossroads with Park Road |
| Loom Street and Rowan Close | x -200 | x -150 | crossroads with Chapel Street, and with each other on Northfields Avenue |
| Westdale Road | x -915 | x -850 | crossroads with Sluice Lane on the ring |
| Mapleford Lane (and the start of Drift Close) | z -670 | z -600 | crossroads with Northfields Avenue on the ring |
| Tanner Row and Church Lane | x -330 / -360 | x -295 | one crossroads on High Street, clear of its bend |
| Guild Street and Quay Street | z 130 | z 105 | their crossroads fits between the end of Bridge Street and its bend |

## B. Junctions too close to a bend
| Move | Detail |
|---|---|
| Garth Road | x 1510 -> 1610 (it was 10 studs from Hollingford Road's bend) |
| Fellmonger Street, Lunebank Road, Bleach Street | the last straight leg into Hollingford Road grows from 60 to 95: junctions move 35 west (x 1725, 1905, 2091), knees to z 705 |
| Ropewalk | slides 10 along Fellmonger Street: (1650,630) -> (1833,447) |
| Pinfold Close | 10 longer (head at z -1100) so a T and its turning head both fit |
| Signal Street, Cooper Street | stop short of the ring road (start x -1090 / -1290); Cooper Street also stops at x -700, short of Station Road |
| Fern Street | becomes a cul-de-sac ending at x -1090, short of the ring's bend |
| Ferry Lane (and the start of Bleach Street) | joins Lunebank Road 110 further along its diagonal: (1578,378) -> (1671,285) |

## C. Bigger changes (landmarks)
| Move | Detail |
|---|---|
| Bridge Street runs straight | (0,60) -> (0,800) instead of jogging to x 100. Lune Bridge moves to x 0 (z 330..510). Lune Street crosses it square; Meadow Road and Tannery Row start at x 0; Viaduct Road moves to z 560 and makes a crossroads with Meadow Road. Removes 4 makeshift junctions and two 45 bends. |
| Station Road leaves High Street square | (-610,-105) -> (-610,-337) -> (-938,-337), replacing the 45-degree split at High Street's bend |
| Riverside Road reaches the ring north of East Bridge | (60,0) -> (1260,0) -> (1260,-170) -> (1400,-170). Going straight on to (1400,0) is not possible: that point is on East Bridge. |

## D. Street ends (Marcel, 2026-09-20)
A turning circle belongs to a semis / detached close, not to a Victorian terrace. Applied in
`tools/town_plan_v3.py`, emitted, digest re-pinned; 0 makeshift junctions, 0 shrunk pieces.

- **Closes keep `head = true` and get a fan**: three short lots round the bulb at 0 and +-65 degrees
  (`TownFrontage.FAN_ANGLE`), each facing the centre. Each lot is tested on its own, so a lot that
  hits a plot, the ring or a special is dropped and the others stand (Elder Close 1 of 3 beside the
  school and the ring; Drift Close, Lune View, Fell Lane 2 of 3). Oak Close's head moved
  z -865 -> -765 to clear the ring (all 3 lots).
- **Terraced streets are `closed = true`**: no circle, a terrace of 3 square across the end on the
  street's own building line, and a paved apron from the road end to its gardens (`PavingStrips`).
  Cooper Street, Meadow Road (end x 1180 -> 1135), Tannery Row (1100 -> 1060), Cedar Road, Hollins
  Road, Orchard Road, Fern Street (-1090 -> -1128), Westdale Avenue, Brook Street, Westdale
  Crescent, Coronation Street, Tollgate Road, Quarry Road, Millbrook Rise (2 houses: Plot 2's margin).
- **Joined up**: Drovers Road turns north at x -760 to a T on the ring; new Tenter Lane (x 950) ties
  Meadow Road to Tannery Row.
- **Left alone**: Riverside Road (the park question above), and the flats streets Marina Way and
  Lune Street, whose circles are 92 apart on the waterfront.
- Tests: `TownFrontageTest.everyStreetEndIsBuiltRound`, `PavingStripsTest.aBluntEndGetsAPavedApron`.
