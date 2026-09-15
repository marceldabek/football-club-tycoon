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

---

# Stadium / World Fixes — round 2

Marcel's walkthrough of the built ground, 2026-09-15. All done the same day.

## Tunnel & the west side
1. [x] A strip of grass survives between the pavement and the tunnel mouth, and you
   step into it walking in — it reads as a hole in the floor. Pave right up to the
   tunnel (`buildHardstanding` / `buildTunnel` in `src/server/WorldBuilder.luau`).
2. [x] The tunnel is a dead end — a throat that stops. Open it all the way through so
   it comes out the back of the west wall.
3. [x] Move the office to the far end of the tunnel, up against the back wall, so
   walking out of the office and down the tunnel onto the pitch is one continuous
   route. (Office is currently on the north-west forecourt.)
4. [x] Build locker rooms off the back of the tunnel while we're there. Visual only
   to begin with — mechanics later.

## Dugouts / benches
5. [x] The red seat is clipping through the black base and z-fighting — it flickers
   between the two colours as you move. Same at the corners, where a couple of pieces
   overlap. Give every piece its own space (`buildDugouts`, `Seat` / `SeatBase` /
   `SeatBack` around `WorldBuilder.luau:407-411`).
6. [x] Real pitches mark out a technical area the coach has to stay inside. Work out
   what ours should look like and paint/mark one around each dugout.
7. [x] Nobody sits on the bench. The substitutes should actually be sitting in the
   dugout, so that a substitution is them standing up and walking on.
8. [x] The ad boards are right on top of the dugouts — the benches need room in front
   of them. Pull the boards forward / the dugouts back.

## Grass & ground surface
9. [x] Grass stops exactly at the pitch markings and becomes pavement immediately.
   Real grounds keep grass for a margin beyond the lines — extend the turf a few
   studs past the pitch on every side before the paving starts. The strip in front of
   the dugouts should be grass too, not paving.
10. [x] Kill the see-through slabs on the deck: the two worn goalmouth patches and the
   centre-circle wear patch (`Goalmouth`, `CentreWear`, `WorldBuilder.luau:119-127`).
   They float above the grass and read as weird translucent blocks. Make them
   invisible or delete them.

## Stands
11. [x] Add railings to every stand — right now there are none anywhere.
12. [x] There's a big empty gap in the west stand directly above the tunnel. Seating
    should carry on over the tunnel mouth. Probably needs two stand variants, one that
    sits above the tunnel and one below it. Future, not urgent.

## Crowd
13. [x] The fans are placeholder blobs (a body block and a sphere head). Make them
    proper Roblox-character NPCs so they read as people in the seats — worth a lot of
    immersion. Watch the part budget; see `WorldBuilder.buildCrowd`.

## Scoreboard
14. [x] No way to see the score from inside the ground. Add a scoreboard: a small,
    cheap one for a lower-tier club — on top of or in front of a stand, or in a corner
    of the pitch — and a proper video screen later as the club grows.

---

## How each one was done

**1, 2, 3, 4.** The tunnel was a 14-stud stub with nothing behind it, and the
paving stopped at the wall line, which is where that strip of grass came from.
It is now a corridor with one continuous floor running from the wall line all
the way to the office door, walled, ceilinged and lit. A dressing room opens
off each side of it (`buildDressingRooms`: benches, peg rails, hung shirts, a
tactics board), and the office sits at the far end with its door facing back
down the tunnel. The player spawns at the desk, walks out past the matchday
board — which moved onto the corridor wall — and comes out of the mouth onto
the pitch, the same way the team does. The forecourt keeps the turnstiles, the
concourse, the car park and the bus; they got their own constants so they no
longer follow the office around.

**5.** Every dugout piece overlapped its neighbour: the red cushion ran from
1.30 to 1.80 while the black pedestal ran 0.60 to 1.60, so over a quarter of
the cushion was *inside* the pedestal. Two coplanar faces have no depth order,
so the renderer picks one per frame — that is the flicker. The corners were the
same story between the posts and the glass. `buildDugouts` now takes extents
(`slab(name, x0, x1, y0, y1, z0, z1, ...)`) instead of centre + size, and
nothing overlaps anything: pieces touch, they never interpenetrate.

**6.** There is a technical area now, marked the way the laws describe it: from
a metre off the touchline back to the front of the bench, and a metre past the
seats at each end. It is painted flush at the same height as the pitch lines,
so it crosses the turf and the paving without z-fighting either.

**7.** Substitutes are built at kickoff and sat in the dugout instead of being
conjured out of the tunnel when needed. `Footballer` gained a `sit` pose (the
Roblox R15 sit track, with the root dropped to bench height) and `stand`. A
substitution is now the bench player getting up, walking out to the touchline
and then to their slot, while the player coming off walks over and takes the
empty seat. Three numbers had to agree for that to look right — the plinth the
feet rest on, the cushion the hips sit on, and the sit pose's own hip height —
so they live together in `Pitch.DUGOUT_STEP` / `BENCH_SEAT_Y` / `BENCH_HIP_Y`.
Before that the feet were 0.35 inside the plinth and the seat back came up to
exactly head height, which is why they looked buried.

**8.** The boards now skip the stretch in front of each dugout as well as the
tunnel mouth, and they stand on the front edge of the paving rather than three
studs off the touchline. The bench has about four studs of clear ground in
front of it and an unobstructed view out.

**9.** `Pitch.GRASS_MARGIN` (8 studs, ~3 m) is turf that carries on past the
markings before the paving starts. It is a ring of four slabs that never
overlap the striped pitch, so nothing z-fights. The nets (6 deep) and the
technical areas now stand on grass, which is where they belong.

**10.** Gone. The worn goalmouth and centre-circle patches were 0.08-thick
translucent slabs floating 0.02 above the grass — coplanar and see-through,
which is exactly what made them read as weird glass blocks.

**11.** Railings everywhere: a rail along the front of row 1, a crush barrier
across the back row, and a handrail up both sides of every aisle. The aisle
rails are one raked bar with a post every third row rather than a rail per row
per aisle, which would have been about 2,000 parts per stand on its own.

**12.** Done rather than deferred, and it fell out of fixing the gap properly.
The terrace used to stop 11 studs short of the centre line on both sides, which
left a slot through the whole stand. It now stops against the tunnel's own side
walls, and from the first row that clears the corridor roof (`crossRow`, which
falls out of the rake — row 7 at the current step height) it carries straight
over the top. So the only hole is the mouth, and the two-stage look happens by
itself: a level-2 stand crosses with two rows, a level-4 one with ten.

**13.** Fans are blocky Roblox characters now — torso, arms, square head with a
face decal and hair, thighs on the front rows where you can see them — instead
of a block with a sphere on top. They are budgeted by part count
(`FAN_PART_BUDGET`), and when the ground outgrows the budget they *thin out*
rather than spread out. Stretching the spacing was the obvious thing to do and
it looked terrible: every row got fans at the same z, so the crowd read as
vertical columns of people. Density now falls off toward the back rows, so the
seats nearest the pitch — the ones the player actually walks past — stay full.

**14.** A scoreboard on two posts by the open north-east corner, angled at the
centre circle: club abbreviations, the score and the minute, lit so it reads at
dusk under the floodlights. It follows `ClubState` directly, so it is correct
without `MatchService` knowing it exists. Deliberately a cheap painted board for
a non-league club, with the room and the mounting to become a video screen later.

**Also, while in there.** A tree was growing through the new office: `Scenery`
kept trees out of a box guessed from the pitch size, which no longer covered a
club that reaches 120 studs west of the wall. The keep-out is measured from the
real extents now, and the north hedge moved back far enough to clear a
full-depth stand.
