# Club buildings — levels, interiors and what they do

> Status: **draft spec ready for Marcel's review** (backlog P9, 2026-09-23). It is a **proposal**:
> nothing here gets built until Marcel approves it, the same way the ground plan was approved.
> Answer the questions by number.

The ground plan (`docs/superpowers/specs/2026-09-22-ground-plan-design.md`) fixed *where* every
building goes. This doc covers *what is inside each one* and *how each one levels up*.

## Decisions (Marcel, 2026-09-23)

Marcel approved all seven recommendations:

1. **Office becomes a bought track.** 4 levels, each with a small sponsorship bonus. The top levels
   still need a higher division. (Today `WorldBuilder.dressOffice(tier)` upgrades it for free on promotion.)
2. **Club shop gets its own track**, separate from concourse food: kiosk → shop unit → megastore with
   a kit wall → flagship store. Merchandise money (`merchPerFan`, X353) moves from the amenity chain to the shop.
3. **Academy is bought, with levels.** Level 1 is today's free youth hut at training pitch 2. Levels 2–4
   give a bigger intake, better potential and a chance of a wonderkid. It grows from pitch 2 into the
   reserved spot (x 342…376, z −60…60).
4. **Walk-in interiors:** office, dressing rooms, club shop and athletic centre. The academy and the
   concourse under the stands are seen through windows at first, to keep phones fast.
5. **Buildings are sized for their top level now** (a fixed shell, like the ground envelope). Levels
   refit the inside and dress the outside, so nothing is rebuilt or moved later.
6. **Dressing rooms get an upgrade track** with a small home-advantage or morale bonus, **built after the others**.
7. **Prices are TEMP values in `Config`**, balanced once the loop is playable.

## What the spec must contain (per building)

- A level table: level, name, TEMP price, prerequisite (in words, as the Club Map will show it),
  outside look, inside look, mechanic (the number it changes and by how much, TEMP).
- One top-down floor-plan SVG per level in `docs/club_buildings/`, drawn at the ground plan's scale and
  plot-local coordinates, with the fixed shell outline on every level.
- Part budget per level (mobile target: a mid-range phone).
- How it appears on the Club Map (ground plan §6): which row, when it becomes visible.

Buildings, in this order: club shop, academy, office, coach's cabin → athletic centre, scouting room
(clubhouse store refit), concourse undercroft, dressing rooms.

## Open questions the draft should raise (numbered, each with a recommendation)

Add them here as the draft finds them. Don't decide them silently.

1. **Merchandise money must not be counted twice.** Decision 2 moves `merchPerFan` from
   `Config.AmenityLevels` to the shop. If `Config.ShopLevels` is added while `AmenityLevels` still
   carries `merchPerFan`, a club earns merch from both tracks. **Recommendation:** remove
   `merchPerFan` from `AmenityLevels` in the same change that adds `Config.ShopLevels`, and read
   `Economy.merchRevenue`'s rate from the shop level only.
2. **Is the shop's 26 × 30 shell enough for a "flagship store"?** The ground plan (§5) never gives
   it more room. **Recommendation:** keep the footprint. At L4 "flagship" means denser fittings,
   a screen, mannequins and an awning, not more floor. Revisit only if it feels cramped in a playtest.
3. **The academy shell.** The ground plan reserves x 342…376, z −60…60, but today's hut
   (`PlotGrounds.buildAcademy`, X289) stands at x 341…355, z 85…95, 25 studs south of that. Moving
   the hut breaks decision 5 ("nothing is rebuilt or moved later") and decision 3 ("level 1 is today's
   hut at training pitch 2"). **Recommendation:** make the fixed shell the reserved slot run south to
   take in the hut: **x 340…376, z −60…96**. The hut never moves and the academy grows north into the
   reserved spot, as decision 3 says. `tools/ground_plan.py`'s reserved rectangle is updated to match
   when the track is built (station 1 owns that file).
4. **Academy numbers.** Nothing in `Config` yet, and `Squad.promoteYouth` takes no level.
   **Recommendation:** a new `Config.AcademyLevels` shaped like `CoachLevels`, TEMP:
   `{ name, cost, intakeBonus, potentialBonus, wonderkidHeadroom }` =
   L1 `0 / 0 / 0`, L2 `+1 / +1 / 0`, L3 `+1 / +2 / +1`, L4 `+2 / +3 / +2`.
   `intakeBonus` is extra graduates on top of the ones the squad needs (still capped by
   `Config.SquadMax`), `potentialBonus` adds to `promoteYouth`'s potential boost (8 today), and
   `wonderkidHeadroom` adds to the headroom roll before `Squad.rollsWonderkid` looks at it.
   The intake itself must never depend on the building: it is the safety net that keeps a squad
   playable after retirements (X277), so a club with no academy building still gets today's intake.
5. **Today's academy already makes a lot of wonderkids.** Every graduate is 17–19 and rolls headroom
   6–18, and `Squad.rollsWonderkid` flags anyone 20 or under with headroom 16+, so about **3 in 13
   graduates (23%)** already come up as wonderkids. L3/L4's `wonderkidHeadroom` would push that to
   roughly 31% and 38%. **Recommendation:** measure it first (a seeded test like
   `SquadTest.packOddsAreDocumented`). If Marcel wants wonderkids rare, lower the academy's base roll
   and let the levels give it back, so L1 stays the floor and nobody loses anything. The level numbers
   in Q4 stay TEMP until then.
6. **What the office's "small sponsorship bonus" changes.** **Recommendation:** a percentage on
   `Economy.sponsorFee` (the X309 per-match sponsor, paid home and away), TEMP `0 / 2 / 4 / 7 %` in a
   new `Config.OfficeLevels.sponsorBonus`. Better offices land better sponsors, and no new income
   line is needed.
7. **Division gates: block the purchase, or just hide the row?** Office, club shop, academy and
   dressing-room top levels need a higher division. **Recommendation:** grey the row with the reason
   in words ("needs Regional Premier") and block the purchase. Never take back a level already bought:
   a relegated club keeps its office, and the next level just greys out again. The gates use the
   division *names* (`Config.Divisions`, bottom to top: Sunday Parks League, County League, Regional
   Premier, National League, Premier Division). The office keeps today's `dressOffice` thresholds:
   screen at Regional Premier (tier 3), crest at National League (tier 4).
8. **Old saves (the public beta's saves carry over).** Today the office is dressed for free by
   division, a coach and a scout can be hired with no building, and `AmenityLevel` is 0–3.
   **Recommendation:** a one-time migration when a save has no building fields yet:
   office level = the division tier, up to 4 (so nobody's office gets worse); cabin level 2 if a coach
   is hired; scouting room level 2 if a scout is hired; concourse level = `AmenityLevel + 1` (the four
   rows map 1 : 1, see Q12); shop, academy and dressing rooms at L1.
9. **Athletic centre vs the coach: both claim "player development".** `Config.CoachLevels`
   multiplies the develop chance by 1 / 1.5 / 2 / 3. A second multiplier would let a Pro Coach and a
   full athletic centre trivialise development. **Recommendation:** the building's bonus is *added
   after* the coach's multiplier: `chance = base × coach + bonus`. TEMP bonus from L3 = +15% of the
   base chance: +0.03 for under-24s (`DevelopChance` 0.2), +0.01 for 24–27 (`DevelopChancePeak` 0.06).
10. **Does the scouting room need more than 2 levels?** The ground plan gives it two states;
    `Config.ScoutLevels` already has five staff tiers. **Recommendation:** keep 2. The room decides
    *whether* a scout can be hired and `ScoutLevels` decides how good he is. Add a cosmetic L3 only if a
    Continental Network scout working out of a small room feels wrong in a playtest.
11. **When each row appears on the Club Map.** Ground plan §6: at spawn the map shows only the East
    stand, one more stand and the coach's cabin, and a row appears when its prerequisite exists (never
    more than about 5 affordable-soon rows). **Recommendation:**
    - **Coach's cabin:** at spawn.
    - **Club shop:** after match 1, when the first summary shows its takings.
    - **Office:** after the first purchase of anything.
    - **Scouting room:** once the cabin is built (football ops follows the coach).
    - **Concourse:** once any stand reaches Main Stand (kiosks need one).
    - **Athletic centre levels:** with training pitch 1.
    - **Academy:** with training pitch 2 (its hut stands there).
    - **Dressing rooms:** last, once the athletic centre is built (decision 6).
12. **Concourse levels vs the ground plan's catering tiers.** The ground plan (§4) has 3 catering
    tiers. `Config.AmenityLevels` has 4 rows (Nothing, Snack Bar £1,200, Merch Stand £6,000, Fan Zone
    £15,000), all on sale today. **Recommendation:** keep all four rows and their costs and split the
    ground plan's tier 3 in two: L3 **Undercroft Bars** (was Merch Stand, renamed because its merch
    moves to the shop) and L4 **Fan Zone**. No new tier is invented: premium hospitality stays a later
    idea (CLAUDE.md §11). This replaces the first draft's unpriced "Full Hospitality" L4.
13. **Dressing rooms: upgrade both rooms, or only the home one?** **Recommendation:** only the
    home room. The away room stays at L1, the way real lower-league clubs keep visitors spartan.
    That is the home advantage, and it halves the part cost.
14. **The dressing-room bonus.** Fixtures have been home *and* away since X361 (`Economy.settle`'s
    `atHome`), so a real home advantage is possible now. **Recommendation:** a flat home-strength
    bonus in `CoachLevels.strengthBonus` units, TEMP `0 / 1 / 2 / 3`, applied **only at home matches**,
    in a new `Config.DressingRoomLevels`. It is added like Q9, never multiplied. The first draft's
    premise ("home-only fixtures") is out of date.
15. **The #23a athletic-centre path crosses training pitch 2.** Ground plan §2 runs it along
    x 276…284 from the fence gate at z 178 to the building door at z 16, but pitch 2 covers x 230…330,
    z 20…170. **Recommendation (for station 1 and the ground plan):** move the building door to the
    east end wall (x 320) and run the path down the 8-stud strip between pitch 2 and the east fence
    (x 330…338). The floor plans below keep the ground plan's door until that is decided.
16. **The first coach and the first scout now cost more.** Today the first coach costs £800 and the
    first scout £600, with no building. With the cabin and the scouting room at TEMP £1,000 and £1,500,
    that becomes £1,800 and £2,100. **Recommendation:** accept it. The cabin is part of the ground
    plan's dense early ladder (§6), and packs still arrive every match without a scout (walk-in
    trialists, CLAUDE.md §8). Both building prices are kept low for that reason. The first draft had
    £2,500 and £3,000.

## Draft (P9): level tables and floor plans

Per-level SVGs (+ PNG) are in `docs/club_buildings/`, generated by `tools/club_buildings_plan.py`.
Run it after any edit (or pass plan names, e.g. `clubshop_L2`). Every sheet uses the ground plan's
frame: plot-local studs, north up, the street on the left. Each sheet has:
- the fixed shell: solid when built, dashed while it is still for sale;
- what that level adds, outlined in red;
- a locator showing where the building sits on the plot;
- a 10-stud bar and its zoom. Rooms are drawn at 11–14 px/stud, outdoor sites at 5–6, and the
  concourse at the ground plan's own 1.25.

Geometry that exists in code is read from it (the sources are named in the script). If they
disagree, the code wins.

**Mechanic hooks, for whoever builds it.** All of these are proposals:

| Building | Config table | Code hook |
|---|---|---|
| Club shop | `Config.ShopLevels.merchPerFan` | `Economy.merchRevenue` (home matches only, X361) |
| Office | `Config.OfficeLevels.sponsorBonus` | `Economy.sponsorFee` |
| Academy | `Config.AcademyLevels` | `Squad.promoteYouth` |
| Athletic centre | `Config.AthleticLevels.developBonus` / `injuryRelief` | `Squad` develop roll / injury length |
| Scouting room | none | gates hiring (`ScoutLevels`) |
| Concourse | `Config.AmenityLevels`, minus `merchPerFan` | as today |
| Dressing rooms | `Config.DressingRoomLevels.homeStrength` | the home XI's strength at home |

### Club Shop

Shell: fixed at every level and already built (`PlotGrounds.buildShop`, `SHOP_CX/CZ` −300, −150,
26 × 30). Plot-local x −313…−287, z −165…−135. The front faces east onto the footpath:
- window, z −162…−148;
- door, z −144…−138.

It is walk-in (decision 4). Merchandise money (`merchPerFan`, X353) is this track's from L1
(decision 2). It is only earned at home matches.

| Level | Name | TEMP price | Prerequisite (as the Club Map says it) | Outside | Inside | Mechanic |
|---|---|---|---|---|---|---|
| 1 | Kiosk | £0 (exists) | none | brick shop, club fascia, three shirts in the window (as built) | counter + till, shelf of folded shirts, scarf rail — [`clubshop_L1`](club_buildings/clubshop_L1.svg) | `merchPerFan` 0.6 |
| 2 | Shop Unit | £3,500 | none | lit fascia + projecting sign | full-length shirt wall, 2 clothing rails — [`clubshop_L2`](club_buildings/clubshop_L2.svg) | `merchPerFan` 1.4 |
| 3 | Megastore | £10,000 | "needs County League" | awning over window and door | kit wall of numbered shirts, name + number printing, 2 gondolas, 2 tills — [`clubshop_L3`](club_buildings/clubshop_L3.svg) | `merchPerFan` 2.4 |
| 4 | Flagship Store | £24,000 | "needs Regional Premier" | 2 mannequins in the window | LED screen in the kit wall, 3 gondolas, trophy replica cabinet — [`clubshop_L4`](club_buildings/clubshop_L4.svg) | `merchPerFan` 3.4 |

The L1 rate is today's Snack Bar merch rate. A new club gets it free because the shop already
exists: about £90 a match at 150 fans. The rest of the ladder runs past today's top rate (2.2),
because the shop is now its own track.

Part budget (the as-built shop is 26 shell parts + 8 stock = 34):
- L2: about 44;
- L3: about 58;
- L4: about 68.

Shirt numbers, names and screen content are SurfaceGuis, not parts.

Club Map: the row appears after match 1 (Q11). L2 is the first buy.

### Academy

Shell (Q3): proposed x 340…376, z −60…96. This is the ground plan's reserved slot run south to take
in today's hut. It is seen from outside only, not walked into (decision 4). The hut
(`PlotGrounds.buildAcademy`) stays where it is at every level: 14 × 10 at (348, 90), with its door
and intake board facing training pitch 2.

| Level | Name | TEMP price | Prerequisite | Outside | Mechanic (Q4, TEMP) |
|---|---|---|---|---|---|
| 1 | Youth Hut | £0 (exists today; free) | comes with training pitch 2 | the hut + intake board — [`academy_L1`](club_buildings/academy_L1.svg) | today's intake: fill to a matchday squad, 17–19, potential boost 8 |
| 2 | Youth Centre | £4,000 | none | classroom cabin beside the hut, a 28 × 52 small-sided cage — [`academy_L2`](club_buildings/academy_L2.svg) | +1 graduate, potential +1 |
| 3 | Academy Building | £12,000 | "needs Regional Premier" | two-storey block (classrooms, coach's office), cage floodlit — [`academy_L3`](club_buildings/academy_L3.svg) | +1 graduate, potential +2, wonderkid headroom +1 |
| 4 | Elite Academy | £28,000 | "needs National League" | dorms + gym/canteen wing at the north end — [`academy_L4`](club_buildings/academy_L4.svg) | +2 graduates, potential +3, wonderkid headroom +2 |

Seen from outside only, so there is no inside column. The academy intake runs whether or not the
building exists (Q4).

Part budget:
- L1: 10 (as built);
- L2: about 22;
- L3: about 38;
- L4: about 50.

The cage is a floor and four textured fence panels, not posts and netting. The site is far from
spawn, so it streams out on phones.

Club Map: the row appears with training pitch 2 (Q11). It is a long-term row.

### Office

Shell: fixed and built, `Clubhouse.ROOMS.Office`. Plot-local x −156…−122, z 16.4…39. It is the
spawn room and walk-in. The furniture is as placed in P5 (`Clubhouse.buildOffice`):
- desk and chair at the east end;
- shelf and cabinet with a telly on the west wall;
- the window.

Each level is exactly one of `WorldBuilder.dressOffice`'s existing fittings tiers (2 / 3 / 4). Those
are free on promotion today; decision 1 makes them bought. Trophies and pennants (`buildTrophies`,
`buildHonours`) stay earned, not bought.

| Level | Name | TEMP price | Prerequisite | Inside | Mechanic (Q6) |
|---|---|---|---|---|---|
| 1 | Rundown | £0 (exists) | none | damp stains, green-screen laptop, bare bulb 1.2 — [`office_L1`](club_buildings/office_L1.svg) | sponsor +0% |
| 2 | Painted | £1,000 | none | damp painted over, filing cabinet, bulb 1.8 — [`office_L2`](club_buildings/office_L2.svg) | sponsor +2% |
| 3 | Modern | £5,000 | "needs Regional Premier" | flat screen (SQUAD / TRANSFERS / FINANCE), tactics board — [`office_L3`](club_buildings/office_L3.svg) | sponsor +4% |
| 4 | Branded | £15,000 | "needs National League" | crest + club name panel, plant, bright cool light 2.4 — [`office_L4`](club_buildings/office_L4.svg) | sponsor +7% |

The outside does not change: the office is one room in the clubhouse.

Part budget: the room and its kit props are unchanged. The level fittings add:
- L2: +2;
- L3: +3;
- L4: +6.

Club Map: the row appears after the first purchase (Q11). Division gates are covered in Q7.

### Coach's cabin → athletic centre

Shell: ground plan §5, x 240…320, z −16…16 (80 × 32). It sits between training pitches 1 and 2,
inside the training fence. The door is on the south face at the #23a path (but see Q15). The L2
cabin (16 × 10 at (280, 0)) becomes the athletic centre's reception at L3, so nothing is knocked down.
The athletic centre is walk-in (decision 4); the cabin is seen from outside.

| Level | Name | TEMP price | Prerequisite | Outside | Inside | Mechanic |
|---|---|---|---|---|---|---|
| 1 | (nothing) | — | none | for-sale outline and board — [`coachcabin_L1`](club_buildings/coachcabin_L1.svg) | — | no coach can be hired |
| 2 | Coach's Cabin | £1,000 | none (dense early ladder) | 16 × 10 cabin — [`coachcabin_L2`](club_buildings/coachcabin_L2.svg) | desk, kit bags (through the window) | **unlocks hiring a coach** (`CoachLevels`) |
| 3 | Athletic Centre | £9,000 | "needs training pitch 1" | fills the shell, the cabin becomes reception | coach's office, gym (bikes, weights, treadmills); west end fitted at L4 — [`athleticcentre_L3`](club_buildings/athleticcentre_L3.svg) | develop chance +0.03 / +0.01, added after the coach (Q9) |
| 4 | + Physio | £20,000 | "needs training pitch 2" | same | physio room: 2 treatment tables, ice bath — [`athleticcentre_L4`](club_buildings/athleticcentre_L4.svg) | injuries last one match less, never under 1 (`InjuryMatches` 1–3 → 1–2) |

Part budget:
- L2: about 10;
- L3: about 32 (the cabin's parts are reused as reception);
- L4: about 40.

Club Map: the row is visible at spawn (ground plan §6). The athletic centre levels appear with their
training pitch.

### Scouting room (clubhouse store refit)

Shell: fixed and built, `Clubhouse.ROOMS.Store`. Plot-local x −156…−122, z −39…−16.4, mirroring the
office across the lobby. Walk-in. The ground plan gives it two states, so the track has two levels
(Q10). The west-wall kiosk hatch goes in ground plan step #12 (station 1), not here.

| Level | Name | TEMP price | Prerequisite | Inside | Mechanic |
|---|---|---|---|---|---|
| 1 | Store | £0 (exists) | none | boxes, a ladder, one bulb — [`scoutroom_L1`](club_buildings/scoutroom_L1.svg) | no scout can be hired; the walk-in trialist pack still comes every match |
| 2 | Scouting Room | £1,500 | "needs the Coach's Cabin" | map wall with pins, desk with the scout's laptop, shortlist board showing this week's 3 cards, filing cabinet — [`scoutroom_L2`](club_buildings/scoutroom_L2.svg) | **unlocks hiring a scout** (`ScoutLevels`) |

The pack itself still opens from the folder on the office desk (CLAUDE.md §8). The shortlist board
is a mirror of it, not a second way in.

Part budget: L1 4 kit props, L2 about 8 (the boxes go).

Club Map: the row appears once the cabin is built (Q11).

### Concourse undercroft

This is not one building. Catering is "one club-wide track" (ground plan §4), so each sheet is the
whole ground at the ground plan's 1.25 px/stud, with the stands at the tier that level needs. The four
levels are `Config.AmenityLevels`' four existing rows, prices and numbers unchanged, minus
`merchPerFan` (decision 2, Q1). The ground plan's catering tier 3 is split into L3 and L4 (Q12).
Buying a level upgrades every qualifying stand at once, as `AmenityLevels` does today.

| Level | Name (Config row) | TEMP price | Prerequisite | Look | Mechanic |
|---|---|---|---|---|---|
| 1 | Burger Van (Nothing) | £0 (exists) | none | grass, gravel strip behind the stand, one van (−153, −105), portaloos (−154, 106) — [`concourse_L1`](club_buildings/concourse_L1.svg) | `perFan` 0 |
| 2 | Kiosks (Snack Bar) | £1,200 | "needs a Main Stand" | paved; a kiosk behind every map tier 2+ stand, at the ground plan's 6 points — [`concourse_L2`](club_buildings/concourse_L2.svg) | `perFan` 2, demand +10% |
| 3 | Undercroft Bars (was Merch Stand) | £6,000 | "needs a Double-tier Stand" | bars under every map tier 3+ stand; kiosks stay behind the others — [`concourse_L3`](club_buildings/concourse_L3.svg) | `perFan` 4, demand +20% |
| 4 | Fan Zone (Fan Zone) | £15,000 | "needs Undercroft Bars" | picnic benches at x −198…−176, z −150…−70 — [`concourse_L4`](club_buildings/concourse_L4.svg) | `perFan` 6, demand +35% |

The undercroft bars are seen through the concourse openings (decision 4), not walked into.

Part budget:
- L1: about 10 (van + portaloos);
- L2: about 30 (6 kiosks × 5);
- L3: about 36 (6 stand sections × 6 parts, inside the stand, so they stream with it);
- L4: about 16.

Club Map: one "Concourse" row, not one per stand. It appears once any stand reaches Main Stand (Q11).

### Dressing rooms

Built after the other six (decision 6). Two fixed, built shells either side of the players'
corridor (`Clubhouse.ROOMS`):
- **Home:** x −147.6…−122, z 4.8…15.6, south of the corridor;
- **Away:** the mirror at z −15.6…−4.8, north of it.

Each door is at x −139…−134 on the corridor wall. The corridor runs from the lobby (x −148) to the
players' door and tunnel (x −121). Walk-in.

**Only the home room upgrades** (Q13); every sheet shows the away room at L1 for comparison. Any
refit must keep at least 11 parts named `Shirt` in the home room: `WorldBuilder.dressDressingRooms`
hangs the XI's names on them. L2 has 11, down from 12 today.

| Level | Name | TEMP price | Prerequisite | Inside (home room) | Mechanic (Q14) |
|---|---|---|---|---|---|
| 1 | Benches | £0 (exists) | none | benches + peg rails with the XI's shirts, tactics board on the west wall — [`dressing_L1`](club_buildings/dressing_L1.svg) | +0 |
| 2 | Lockers + Showers | £2,000 | none | lockers along the outer wall, shower bay in the east corner — [`dressing_L2`](club_buildings/dressing_L2.svg) | home strength +1 at home |
| 3 | Cubicles | £6,000 | "needs Regional Premier" | a cubicle per player on both walls, tiled floor, ice bath beside the showers — [`dressing_L3`](club_buildings/dressing_L3.svg) | +2 at home |
| 4 | Pro Dressing Room | £14,000 | "needs National League" | cubicles in club colours, crest in the floor, screen replaces the tactics board — [`dressing_L4`](club_buildings/dressing_L4.svg) | +3 at home |

Part budget: today about 28 parts per room. For the home room only:
- L2: about 32;
- L3: about 43 (cubicles replace the bench runs);
- L4: about 45.

Club Map: the row appears last, once the athletic centre is built (Q11).
