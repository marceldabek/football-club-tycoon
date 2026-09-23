# Club buildings — levels, interiors and what they do

> Status: **decisions taken, spec not yet drafted.** The overnight agent drafts the spec below the
> decisions (backlog P9) as a **proposal for Marcel to review**. Nothing here gets built until Marcel
> approves it, the same way the ground plan was approved.

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

1. **Does a building's level price stack with the club-wide costs it touches?** e.g. Club Shop
   merchPerFan replaces `Config.AmenityLevels.merchPerFan` (decision 2) — should those fields be
   zeroed out in `AmenityLevels` now, or left until the shop track is actually implemented?
   **Recommendation:** leave `AmenityLevels` untouched until an implementing agent wires up
   `Config.ShopLevels`, then zero `merchPerFan` in the same change so the money is never counted
   twice. Note it here so nobody forgets.
2. **Club Shop's shell is only 26 × 30 studs (`SHOP_W`/`SHOP_D`, `PlotGrounds.luau`) — is that
   really enough for a "flagship store"?** The ground plan (§5) never reserves it more room.
   **Recommendation:** keep the existing footprint (it's a Roblox prototype, not a real
   megastore) and let "flagship" mean denser fixtures and better dressing, not square footage;
   revisit only if playtesting says the shop feels claustrophobic at L4.
3. **The academy's *reserved* plot (ground plan §5: x 342…376, z −60…60) is not where today's
   free youth hut actually stands** (`ACADEMY_CX/CZ = 348,90` in `PlotGrounds.luau`, next to
   training pitch 2 — outside the reserved slot entirely). Decision 3 says the academy "grows
   from pitch 2 into the reserved spot", which reads as a move, not a decision-5 fixed shell.
   **Recommendation:** make the reserved slot the fixed shell from L1 (so nothing has to move
   again later) and treat relocating the existing hut onto that slot as part of implementing L1
   of this track, not a design change. Flag if Marcel wants the hut to visibly stay by the
   pitches instead.
4. **Academy levels need real intake/potential/wonderkid numbers.** None exist in `Config` yet
   (`Squad.promoteYouth` takes no level). **Recommendation:** add `Config.AcademyLevels` shaped
   like `CoachLevels`/`ScoutLevels` — TEMP `{ name, cost, intakeBonus, potentialBonus,
   wonderkidChance }`, e.g. `0 / +1 / +2 / +3` intake and `0% / 0% / 3% / 8%` wonderkid chance —
   balanced once the loop is playable, same as everything else in that file.
5. **What does the office's "small sponsorship bonus" (decision 1) actually change?** No
   sponsorship revenue line exists yet outside the ad-board sponsors (X309, per-match, TEMP).
   **Recommendation:** a flat `%` bump to that same per-match sponsor income, e.g. `0/2/4/7%`
   in a new `Config.OfficeLevels`, so it reads as "a smarter office gets you better sponsorship
   deals" rather than inventing a second, unrelated income source.
6. **Should Office L3/L4's division gate block the *purchase*, or just hide the row until then?**
   Ground plan §6's progressive disclosure hides rows with no prerequisite yet, but a promoted-
   then-relegated club would keep a branded office it can no longer afford to have bought.
   **Recommendation:** gate the purchase (can't buy above the club's current division) but never
   repossess a level already bought, same as every other track — relegation just re-greys the
   next level, it doesn't undo the last one.
7. **The Athletic Centre's training bonus and the coach's own `developMultiplier`
   (`Config.CoachLevels`, 1×/1.5×/2×/3×) both claim "player development" (CLAUDE.md §9).**
   Stacking two multipliers on the same stat risks a Pro Coach + full Athletic Centre trivialising
   development entirely. **Recommendation:** make the building's bonus additive on top of the
   coach's multiplier (`finalRate = base * coachMultiplier + buildingFlatBonus`), not another
   multiplier, so the two tracks feel complementary rather than compounding.
8. **Does the scouting room need more than 2 levels?** Every other track in this doc has 4;
   `Config.ScoutLevels` itself has 5 staff tiers (Local Scout up to Continental Network), all
   hireable the moment the room exists. **Recommendation:** keep the room at 2 (it only needs
   to gate *whether* a scout can be hired, not how good one is — that's `ScoutLevels`' job) and
   only add a cosmetic L3 "Scouting Hub" later if a National/Continental Network scout feels odd
   working out of the same small room as a Local Scout.
9. **What gates the Scouting Room appearing on the Club Map** (§6's progressive disclosure)?
   It has no obvious physical prerequisite like the others (no training pitch, no division).
   **Recommendation:** show it from spawn, same as Club Shop and the Coach's Cabin — three
   "football ops" rows visible immediately reads better than an arbitrary shop-tier gate.

## Draft (P9): level tables and floor plans

Per-level SVGs (+ PNG) are in `docs/club_buildings/`, generated by `tools/club_buildings_plan.py`
(same `Canvas`/palette as `tools/ground_plan.py`; run `python tools/club_buildings_plan.py` after
any edit to regenerate all of them, or pass names to regenerate just one building).

### Club Shop

Shell (fixed at every level, `PlotGrounds.luau` `SHOP_CX/CZ = -300,-150`, `SHOP_W/SHOP_D = 26,30`):
plot-local x −313…−287, z −165…−135. Door + display window face east (+X), onto the footpath, as
built today. Walk-in interior (decision 4). Merchandise money (`merchPerFan`, X353) belongs to this
track from L1, not the concourse amenity chain (decision 2).

| Level | Name | TEMP price | Prerequisite | Outside | Inside | Mechanic |
|---|---|---|---|---|---|---|
| 1 | Kiosk | £0 (exists) | none — built at spawn | plain brick kiosk, footpath window + door (as built) | till counter, folded-shirt shelf, scarf rail — [`clubshop_L1.svg`](club_buildings/clubshop_L1.svg) | `merchPerFan` 0.6 |
| 2 | Shop Unit | TEMP £3,500 | Kiosk | bigger fascia sign, wider display window | till counter + 2 clothing rails + kit rail — [`clubshop_L2.svg`](club_buildings/clubshop_L2.svg) | `merchPerFan` 1.4 |
| 3 | Megastore | TEMP £10,000 | Shop Unit, ground tier 2 | awning, larger window display | kit wall (numbered shirts) + 3 aisles + till — [`clubshop_L3.svg`](club_buildings/clubshop_L3.svg) | `merchPerFan` 2.4 |
| 4 | Flagship Store | TEMP £24,000 | Megastore, ground tier 3 | flagship signage, window mannequins | kit wall + digital screen + 2 tills + trophy cabinet — [`clubshop_L4.svg`](club_buildings/clubshop_L4.svg) | `merchPerFan` 3.4 |

Part budget (mobile target): L1 ~8 (as built), L2 ~20, L3 ~45, L4 ~65 — all well inside a single
dresser's usual budget (memory `dresser-part-budgets`).

Club Map: "Club Shop" row is visible from spawn (L1 already exists) and shows the L2 price
immediately, so there is something to buy here in the first session (ground plan §6, "dense
early ladder").

### Academy

Shell (fixed at every level, per decision 5 — see Q3 above about where today's hut actually is):
the ground plan's reserved slot, plot-local x 342…376, z −60…60 (34 × 120). Seen through the
training fence, not walked into (decision 4). Levels change `Squad.promoteYouth`'s intake size,
its potential and a wonderkid chance (Q4).

| Level | Name | TEMP price | Prerequisite | Outside | Mechanic |
|---|---|---|---|---|---|
| 1 | Youth Hut | £0 (exists, relocated — Q3) | ground tier 1 | 14×10 cabin + intake board — [`academy_L1.svg`](club_buildings/academy_L1.svg) | intake +0, wonderkid 0% |
| 2 | Youth Centre | TEMP £4,000 | Youth Hut | hut grows into a classroom block, five-a-side marking — [`academy_L2.svg`](club_buildings/academy_L2.svg) | intake +1, wonderkid 0% |
| 3 | Academy Building | TEMP £12,000 | Youth Centre, ground tier 3 | classrooms + coach's office, marked mini pitch — [`academy_L3.svg`](club_buildings/academy_L3.svg) | intake +2, wonderkid 3% |
| 4 | Elite Academy | TEMP £28,000 | Academy Building | fills the reserved plot: classrooms, dorms, gym, full-size marked mini pitch — [`academy_L4.svg`](club_buildings/academy_L4.svg) | intake +3, wonderkid 8% |

Part budget: L1 ~10 (as built today), L2 ~18, L3 ~28, L4 ~40 (mostly ground marking, not full
meshes — this is a windows-only building, decision 4).

Club Map: "Academy" row appears once training pitch 2 exists (ground plan §5 tier 3), greyed
with "needs training pitch 2" until then — a long-term row, not part of the dense early ladder.

### Office

Shell (fixed at every level — it already is, `Clubhouse.ROOMS.Office`): plot-local x −156…−122,
z 16.4…39. Walk-in interior (decision 4), spawn point. `WorldBuilder.dressOffice(tier)` already
re-skins this room for free on promotion through `OFFICE_TIER_PAINT/SCREEN/BRAND` (2/3/4) —
decision 1 turns the same three re-skins into a bought track, and the top levels *also* keep
their division requirement (so a club can't buy its way to a branded office in the bottom tier).

| Level | Name | TEMP price | Prerequisite | Inside | Mechanic |
|---|---|---|---|---|---|
| 1 | Rundown Office | £0 (exists) | none | damp stains, dim light, green-screen terminal — [`office_L1.svg`](club_buildings/office_L1.svg) | sponsorship bonus +0% |
| 2 | Painted Office | TEMP £1,000 | Rundown Office | walls painted, notice board tidied — [`office_L2.svg`](club_buildings/office_L2.svg) | sponsorship bonus +2% |
| 3 | Modern Office | TEMP £5,000 | Painted Office, division 2+ | flat-screen computer, rug, brighter light — [`office_L3.svg`](club_buildings/office_L3.svg) | sponsorship bonus +4% |
| 4 | Branded Office | TEMP £15,000 | Modern Office, division 1 | trophy shelf, branded lighting + crest — [`office_L4.svg`](club_buildings/office_L4.svg) | sponsorship bonus +7% |

Part budget: unchanged from today at every level — `dressOffice` only swaps wall colour, the
computer model, light brightness/colour and a couple of props, never the desk/chair/notice/room
shell (~25 parts throughout, memory `dresser-part-budgets`).

Club Map: "Office" row is visible from spawn (L1 already exists) alongside Club Shop; a division
gate greys L3/L4 out with "needs Division 2" / "needs Division 1" in words, per ground plan §6.

Q5 below covers the new sponsorship-bonus number this track needs.

### Coach's cabin -> athletic centre

Shell (fixed at every level, ground plan §5's own table + `tools/ground_plan.py`
`proposed_common`): plot-local x 240…320, z −16…16 (80 × 32), inside the training-ground fence.
Walk-in interior from L3 (decision 4); L1/L2 are seen from outside only. Levels are already
specified in the ground plan (§5); this draft just prices them and gives the mechanic numbers.

| Level | Name | TEMP price | Prerequisite | Outside | Mechanic |
|---|---|---|---|---|---|
| 1 | (nothing) | — | none | for-sale outline only — [`coachcabin_L1.svg`](club_buildings/coachcabin_L1.svg) | no coach can be hired |
| 2 | Coach's Cabin | TEMP £2,500 | none — dense early ladder (ground plan §6) | 16×10 cabin at the shell's centre, rest still for sale — [`coachcabin_L2.svg`](club_buildings/coachcabin_L2.svg) | **unlocks hiring a coach** (`Config.CoachLevels`) |
| 3 | Athletic Centre | TEMP £9,000 | Coach's Cabin, training pitch 1 | fills the shell: coach's office + gym — [`athleticcentre_L3.svg`](club_buildings/athleticcentre_L3.svg) | training bonus, TEMP +15% `developMultiplier` |
| 4 | + Physio | TEMP £20,000 | Athletic Centre, training pitch 2 | same footprint, physio room added — [`athleticcentre_L4.svg`](club_buildings/athleticcentre_L4.svg) | injury recovery bonus, TEMP −1 match off `Config.InjuryMatches` |

Part budget: L2 ~10, L3 ~35 (coach's office + gym fixtures), L4 ~45 (+ physio table, ice bath).

Club Map: "Coach's Cabin" is one of the three rows visible from spawn (ground plan §6), alongside
one more stand and Club Shop. Athletic Centre/+ Physio only appear once their training-pitch
prerequisite exists.

### Scouting room (clubhouse store refit)

Shell (fixed — it already is, `Clubhouse.ROOMS.Store`, mirroring the office across the
corridor): plot-local x −156…−122, z −39…−16.4. Ground plan §5's table gives this row only two
states, so this track is deliberately short — two levels, not four (see Q8).

| Level | Name | TEMP price | Prerequisite | Inside | Mechanic |
|---|---|---|---|---|---|
| 1 | Store | £0 (exists) | none | empty concession store, as built — [`scoutroom_L1.svg`](club_buildings/scoutroom_L1.svg) | no scout can be hired |
| 2 | Scouting Room | TEMP £3,000 | Store | world map pinboard, desk + shortlist tray, filing cabinet — [`scoutroom_L2.svg`](club_buildings/scoutroom_L2.svg) | **unlocks hiring a scout** (`Config.ScoutLevels`) |

Part budget: L1 0 (unfurnished, as built), L2 ~10.

Club Map: visible from spawn alongside Club Shop and the Coach's Cabin (see Q9 — it has no
physical prerequisite to gate on).
