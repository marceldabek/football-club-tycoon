# League club crests in the UI — design

2026-09-21. Approved by Marcel: all recommended options.

## Goal

Replace the placeholder shield-and-initials crest with the real crest art for
the 40 league clubs in `Config.Clubs`, everywhere a crest appears in the UI.

## What was checked first

- All 40 crest images exist, in `C:\Users\mdabe\Downloads\`, named
  `<Club Name> — <region>.png` (2026-09-15). Every one was compared against its
  prompt in `docs/CRESTS.md` and matches its own club (motif, both colours,
  shape, division polish). No art is swapped between clubs.
- The club names in `Config.Clubs` already match `docs/CRESTS.md` and the image
  names. **No club is renamed.** The only renaming is of the files: to the
  `tier<N>_<kebab-name>.png` scheme CRESTS.md specifies, which also removes the
  stray `. ` (Bramblewick Rovers) and `'` (Meridian City) in two filenames.
- Every image sits on plain white, has no lettering, and is square (~1254 px)
  except Old Aldgate and Wentworth United (1024×1536 portrait).

## Scope

In:
- the 40 league clubs' crests in every UI crest: HUD scoreboard, club panel
  header/fixtures/league table, match summary, and (when it lands) the pack
  spec's `PlayerCard`;
- a report of clubs whose shirt colour disagrees with their crest art.

Out:
- **The player's own club crest.** The crest builder
  (`docs/CREST_BUILDER_PROMPTS.md`, separate work in progress) owns it, including
  its renderer and `CrestBadge`. This work does not touch the player's crest.
- **League crests in the 3D world** (away banners, scoreboard, murals). A
  planned follow-up.
- Changing any kit colour automatically.

## Design

### 1. Asset prep — `tools/prep_crests.py`

Pure Python (PIL + numpy + scipy, as `tools/key_cards.py`).

1. Read a source folder (default the Downloads path) and match each file to a
   club by the text before ` — `, after stripping leading `. ` and trailing `'`.
   The club list and tier come from parsing `Config.luau`'s `Config.Clubs`, so
   the script and the game cannot disagree. An unmatched file or a club with
   no file is an error that stops the script.
2. Copy to `assets/ui/crests/src/tier<N>_<kebab-name>.png`.
3. Key the background by **flood fill from the four corners** over
   near-white pixels (soft edge between two thresholds, as in `key_cards.py`).
   Not a global white key: 17 crests use white as one of their two colours and
   would get holes.
4. Trim to the alpha bounds, pad to a centred square with a small even margin,
   resize to 256×256, and write `assets/ui/crests/keyed/tier<N>_<kebab-name>.png`.
5. Write `assets/ui/crests/contact_sheet.png`: all 40 on a mid-grey checker in
   division rows, to review the key at a glance.
6. **Colour report:** take the two dominant non-white colours of each keyed
   crest and compare them with that club's `kit` and `accent`. Print the clubs
   whose nearest pair is further apart than a threshold. This is printed only;
   Marcel decides what to change.

Folder name `crests/` (plural) keeps it apart from the builder's
`assets/ui/crest/`.

### 2. Upload

Upload the 40 keyed PNGs via Studio MCP `upload_image` (the card-art route).
Record the ids in `assets/ui/crests/asset_ids.json` (file → id), and add a
`crest = "rbxassetid://…"` field to each entry in `Config.Clubs`
(`export type Club` gains `crest: string?`).

### 3. Lookup — `Config.clubCrestImage(name): string?`

Returns the image id for a league club, or nil (unknown name, the player's
club, or no art yet). Built into the same name map as `crestByName`. It is the
only new Config API.

### 4. Drawing — `src/client/Crest.luau`

- `Crest.draw(parent, name, size, options)`: if not `options.isPlayer` and
  `Config.clubCrestImage(name)` is set, the returned `Crest` frame is
  transparent and holds an `Art` ImageLabel (full size, `ScaleType.Fit`).
  Otherwise draw today's shield unchanged. Size, position, anchor and layout
  order options behave the same in both cases.
- `Crest.update(crest, name, isPlayer)`: the HUD's away crest and the panel's
  fixtures change club in place, possibly between art and no art. `update`
  keeps one outer `Frame` named `Crest` holding either an `Art` ImageLabel or
  the shield contents, and swaps the child. So `draw` returns that outer frame
  in both cases (transparent when it holds art), and existing callers that
  hold the returned frame keep working.
- No size cut-off: art draws at every size, including the ~20–24 px table rows.
- `MatchSummary.luau` (~line 622) builds its own crest from
  `Config.clubCrest`; route the league side through `Crest.draw` so the
  summary shows art too.

**Seam with the crest builder.** The builder will replace the player-club
branch of `Crest.luau`. This work adds only the league-art branch and the
`Config.clubCrestImage` lookup, and keeps them in one clearly marked function
(`drawLeagueArt`) so the builder's rewrite can keep it as it is. Whichever work
lands second rebases onto the first; before editing `Crest.luau`, check
`git log` for the builder's change.

### 5. Docs

`docs/CRESTS.md` "Notes for later": say the art is in, where the files and ids
live, and how to re-run the prep script for a replacement image.

## Error handling

- Missing or unmatched files stop the prep script with the names listed.
- If an image id fails to load in game, the `ImageLabel` is simply blank; no
  runtime fallback (the test below catches a missing id before it ships).

## Testing

- Luau test (RunAll via MCP): every club in `Config.Clubs` has a non-empty
  `crest`; `Config.clubCrestImage` returns it by name and nil for an unknown
  name and for the player's club; `Crest.draw` gives art for a league club and
  the shield for the player; `Crest.update` switches art ↔ shield without
  leaving stray children.
- Visual check in Studio at phone size: league table (~24 px), scoreboard
  (34 px), match summary (84 px). Watch the busy Division 3 crests
  (Harrowgate City, Greyfriars United, Dunmore Wanderers) at table size; if
  they are unreadable, regenerating them with simpler prompts is a separate
  decision for Marcel.
- Contact sheet reviewed for keying holes, especially in the white-accent crests.

## Build order

1. `prep_crests.py`, then check the contact sheet and read the colour report.
2. Upload, then ids into `Config.Clubs`, then `Config.clubCrestImage` plus tests.
3. `Crest.luau` league branch and `update` swap, then MatchSummary routing.
4. Studio phone-size check, then the CRESTS.md note, then commit.
