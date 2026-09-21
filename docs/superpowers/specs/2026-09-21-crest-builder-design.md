# Crest Builder: Design

2026-09-21. Marcel approved every recommended option (questions 1–9 in the session).
The art prompts are in `docs/CREST_BUILDER_PROMPTS.md`.

## Goal

A new club picks its crest on the found-club card: shape, two colours, pattern and emblem.
Those two colours become the club's colours everywhere the player's club is shown today
as the fixed `Config.HomeKit` red: kit, crowd scarves, fascias, banners, clubhouse
doors, town banners and the UI crests.

## Player flow

1. The found-club card has two steps. **Step 1 is the name** (unchanged).
   **Step 2 is "Design your crest"**: a large live preview, plus a row for each of
   Shape, Main colour, Second colour, Pattern and Emblem. It also has **Randomise**
   and **Found the club**.
2. Step 2 opens on a ready-made default, so a player can skip it in two taps.
3. **Re-editing later**: the office computer panel has an "Edit crest" button. It opens the
   same step-2 card with a Save button, is free for now, and works only between matches
   (Manage phase). The name stays one-shot.
4. Saves from before this change get the default crest (red and white classic shield,
   castle) and are not prompted.

## Options

- **Shapes** (4): classic, round, square, pointed
- **Patterns** (4): plain, halves, stripes, sash
- **Emblems** (8): ball, lion, castle, waves, star, oak, bridge, crown
- **Palette** (12 fixed swatches):
  - red, claret, orange, gold, green, dark green, sky, royal, navy, purple, black, white
  - Main and second must differ. The server rejects a spec where they are the same.

## Data

```
Crest = { shape: string, pattern: string, emblem: string, main: string, second: string }
```

The fields are string keys, not indices, so reordering a list never changes a saved crest.

- **Saved** as `profile.crest`: an optional field that needs no `Profile.VERSION` bump,
  the same way `settings` was added. `Profile.normalize` validates every field and falls
  back to the default one field at a time.
- **Replicated** as a `Crest` JSON attribute on the club state folder
  (`ReplicatedStorage.Clubs.PlotN`). It is in `ClubState` PERSISTED, so a change marks
  the save dirty.
- **Kit colour** = main, **accent** = second. `ClubCrest.colours(spec)`.

## Units

| Unit | Role |
|---|---|
| `shared/CrestImages.luau` | GENERATED ids of the 36 uploaded layers (`tools/upload_crest_parts.py`) |
| `shared/ClubCrest.luau` | option lists, palette, default / normalize / random / encode / decode, `colours`, `forClub(name)`, `draw` / `update` (ImageLabel stack that works in both ScreenGui and SurfaceGui), `paint` / `repaint` for world parts |
| `Config.clubCrest(name, isPlayer, home?)` | the player's club reads its colours through `ClubCrest.forClub`. Opponents are hue-shifted against `home` (the club they play), not the fixed red |
| `client/Crest.luau` | the same API; a player club draws the builder crest instead of the initials square |
| `client/CrestBuilder.luau` | the step-2 card, used by Onboarding and the office |
| server `Session` | `ClubCrest` remote: owner only, Manage phase, normalize, set the attribute, save |
| server `WorldBuilder.applyCrest` | repaints tagged world parts and redraws the world crest badges when `Crest` changes |

### Layer stack (`ClubCrest.draw`)

The layers stack in this order:

1. shape (main)
2. pattern (second)
3. rim (second)
4. emblem halo (main)
5. emblem (second)

All layers share one square canvas, so alignment is free. Emblem placement per shape is
`EMBLEM_BOX`, mirrored in `tools/make_crest_parts.py`.

### World repaint

Server builders pass colours through `ClubCrest.paint(instance, role, darken)`.
- `paint` sets the colour and records `ClubPaint` / `ClubPaintDarken` attributes.
- `repaint(root, spec)` walks the club model and resets every tagged instance.
- World crest badges are frames tagged `ClubCrestBadge`, which `repaint` redraws.

This means colour changes need no rebuild of the club, and the found-club flow (which
runs after the world is built) repaints in place.

### Client-only colour uses

Crowd scarves, pedestrians, training shirts and headshots read the viewing player's club
through `ClubCrest.localColours()` (via `ClubRef`), which falls back to the default.

## Not in scope

- Charging for crest changes
- Free-text or uploaded crests (so no filtering is needed)
- Separate kit colours
- Away kits
- Crest art for the league clubs (already exists)

**Initials:** questions 1–9 approved auto initials on large crests. In the preview, the
emblem already fills the crest's centre, and the initials had nowhere to go without
clutter. **Builder crests show no initials. Flagged to Marcel.**

## Testing

- `ClubCrestTest`: normalize (junk, partial, same-colour, unknown keys), random is always
  valid, encode/decode round-trip, colours match the palette, and every option has an
  uploaded image id.
- `ProfileTest`: a crest survives normalize, and an old save gets the default.
- Play test: found a club with a non-default crest. The kit, crowd, fascia and table
  crest change; the re-edit from the office repaints live; a rejoin keeps the crest.
