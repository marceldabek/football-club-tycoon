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
