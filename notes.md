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
