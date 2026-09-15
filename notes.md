# Fixes & Changes

## Global UI style
1. [x] All UI box outlines are different — unify them to a single consistent color/stroke across every panel.
2. [x] Corners look squared and jagged — round the corners properly on all UI boxes.

## Squad screen — drag & drop
3. [x] Clicking a player does nothing at first — the drag doesn't visibly start until release.
4. [x] On release, every card flashes / the whole page appears to reload. Remove the flash — update only what changed instead of rebuilding the whole screen.
5. [x] While dragging, I should see the player card follow my cursor.
6. [x] While holding a player over another player, that target should be highlighted so I can see who is about to be swapped out.

## Squad screen — layout
7. [x] The player detail panel (bottom right) pushes MID / Overall / Potential / Age and then Appearances / Goals to the very bottom, which creates a scrollbar. Remove scrolling on the whole UI — everything should fit on one screen.
8. [x] The stats block at the bottom right is annoying as-is — restructure it so it reads cleanly without scrolling.
9. [x] The Auto Squad button takes up too much room — move it to the bottom.
10. [x] Scrolling should only ever happen inside the bench list, never on the whole UI.
11. [x] When a bench player is selected, open a larger detail window for them instead of cramming it in.
12. [x] The Sell button is all the way at the bottom of the page — move it somewhere reachable without scrolling.

## Character models
13. [x] "Rounded shoulders" was misinterpreted — I don't want ball-shaped shoulders. I want the normal Roblox character torso style (the standard blocky torso with softly rounded edges), not spheres stuck on the sides.

## Top bar
14. [x] The Play Match button is smaller than the text inside it — fix the sizing/padding.
15. [x] The "5/10" indicator is unnecessary — remove it.

## League info (later, not now)
16. [ ] The top-left block showing our league / matches / league position is poorly presented. Replace it with a sidebar that slides in and out, summarizing those and showing the league table. Save this one for later.

---

## How each one was done

1–2. `Theme.stroke` no longer takes a colour or transparency: callers pass a
state (`rest` / `selected` / `target` / `danger`) and every resting outline in
the game is the same colour and weight. Radii are named too (`Theme.radius`,
`cardRadius`, `buttonRadius`, `chipRadius`) and were all bumped, so nothing
reads as a square box.

3–6. `LineupBoard` is now a component: `LineupBoard.new(...)` builds once and
`update(...)` moves the widgets that changed. A card belongs to a player id for
as long as that player is on screen, so a swap moves two widgets instead of
rebuilding the screen — that is what killed the flash (4). A press lights the
card up immediately (3), an opaque ghost follows the cursor from 4px of
movement (5), the card under the cursor gets a green drop-target outline (6),
and the dragged card leaves its slot behind so the bench does not reflow.

7–12. The Squad tab has its own page that never scrolls. The XI fills the left
column, the right column is a scrolling bench list (the only scroll region on
the screen, 10) above a full player window (7, 8, 11) with a stat grid and the
Sell button inside it (12). Auto Squad is a compact switch in the bar along the
bottom next to the squad-capacity meter (9).

13. The headshot bust uses the standard blocky Roblox torso: a wider shirt
block with square sleeve and upper-arm blocks, no spheres.

14–15. PLAY MATCH grows with its label (`AutomaticSize.X` + padding, with a
300x48 minimum), and the `(5/10)` counter is gone from the label.

---

# Stadium / World Fixes

## Pitch & stand layout
1. [x] Almost no spacing between the stands and the field.
2. [x] Only one stand, and only one place to put it — wanted N/S/E/W plots.
3. [x] No walkable perimeter: pavement, dugouts, touchline walkway.
4. [ ] Make the perimeter itself part of the upgrade path (it exists from the start for now).

## Stand model
5. [x] Triangular side panels mirrored — they fought the seating ramp.
6. [x] Billboards floating off the wall.
7. [ ] Replace the stand with a better asset later; primitives stay for now.

## Office
8. [x] Office in a bad place — it sat mid-touchline and blocked the whole west side.

---

## How each one was done

1, 3. `Pitch.luau` now owns the ground's outer geometry: `SIDE_MARGIN` 26 studs beside a
touchline and `END_MARGIN` 34 behind a goal (about 9.5 m and 12 m at 2.75 studs/m). That gap
is paved — `buildHardstanding` lays a ring of slabs flush with the grass — and everything
that used to sit on the touchline (ad boards, dugouts) now stands on it. A perimeter wall
runs along the outer edge on the `SIDE_EDGE` / `END_EDGE` line.

2. Each side is an independent plot (`Config.StandPlots`) on the same `StandLevels` chain,
level 0 being an empty plot. Capacity is the sum over plots, so the ground grows
asymmetrically like a real lower-league ground and there are now four things to spend on
instead of one. Every plot is built in a local frame where +X points away from the pitch and
+Z runs along the stand, so `buildPlot` serves all four sides; the west plot splits around
the tunnel mouth. Saves gained a `stands` table with a v1 -> v2 migration that moves the old
single `standLevel` onto the east plot.

5. A WedgePart is full height at its local +Z (verified in Studio), so the end wall needed
yaw +90, not -90, to slope away from the pitch. It was building the ramp backwards.

6. The signs were `BillboardGui`s floating 4 studs above their posts, and the ad boards sat
at ground level while the pitch surface is 1 stud up. Signs are painted onto the board face
with a `SurfaceGui` now, and everything pitch-side stands on the paving.

8. The player's way in and the team's way out were the same gap in the west fence, which
forced the office to sit mid-touchline. They are separate now: turnstiles in the open
north-west corner for the player (office, matchday board, concourse and car park on a paved
forecourt outside it), and a tunnel mouth in the middle of the west wall for the
footballers. That frees all four sides for stands.
