# Pack Opening — Design

Date: 2026-09-21. Decisions by Marcel in the "pack opening feature" session.

## Goal

The scout report on the office desk becomes a FIFA-style pack. The player walks
up to the manila folder, the screen is taken over, three player cards come out,
and he signs, pins or leaves them. A pack arrives after **every** match, from
match 1, so the 30-minute season loop always has something to open.

## Rules (decided)

| # | Rule |
|---|------|
| 1 | Every pack is exactly **3 cards**. Scout level changes quality and foreign reach, never the count. |
| 2 | **No scout hired:** a weak "walk-in trialists" pack still arrives after every match (mostly Bronze). |
| 3 | **Match 1 pack:** the trialist pack is special: keep **1 of 3 free**. Lightly rigged so one card clearly beats the weakest starter in its position. Never shown as rigged. |
| 4 | The starting XI is **not** unpacked. It is shown as cards at the first walkout / lineup board (reuses `PlayerCard`). |
| 5 | Six card stats (PAC SHO PAS DRI DEF PHY) are **display-only**, derived from overall + position + player seed. The match sim keeps using overall. |
| 6 | Portrait: head bust plus a simple torso. Neutral scout-grey shirt for prospects, club kit once signed. |
| 7 | Buttons per card: **Sign £X** and **Pin**. One **Done** for the pack. No per-card Pass: unsigned cards stay in the Scouting tab until the next report. Unaffordable: Sign shows "Need £X more", Pin is highlighted. |
| 8 | **Pin:** one slot. Pinning replaces the old pin. Fee locked at pin time. Survives new reports. Cleared on sign, unpin, or season end. |
| 9 | **Squad full** (`Config.SquadMax`): Sign opens a "release who?" picker, then completes the signing. |
| 10 | **Unopened packs do not stack.** A new report replaces the old one (the pin survives). |
| 11 | Reveal: tap flips each card, best card last, hold / double-tap reveals all. Rare and above get a build-up (flag → position → flip). Bronze / Silver flip straight away. Whole reveal under ~10 s, always skippable. |
| 12 | No quick-sell. Prospects are not owned until signed. |
| 13 | The overlay is client-only. Visitors see the owner standing at the desk. |
| 14 | Opening from the menu uses the same overlay without the camera push-in. |
| 15 | Out of scope: paid / Robux packs, special cards. Tier odds live in one `Config` table so they can be published later (Roblox odds-disclosure rule). |

## Architecture

Simulation / presentation split as everywhere else: the server rolls and owns
the pack; the client only animates what it was given.

### Shared

- **`Shared/CardStats`** (new, pure). `CardStats.of(player) -> { pac, sho, pas, dri, def, phy }`.
  Position weight table (a ST is high SHO / low DEF, a CB the reverse, GK gets
  its own spread) scaled around `overall`, plus a small per-stat offset seeded
  from `player.look` (stable for the player's life). Recomputed on read, so the
  numbers rise as overall develops. Nothing is stored, nothing to migrate.
- **`Squad.prospects`**: count comes from `Config.PackSize = 3`, not
  `level.prospects`. Accepts scout level 0 using a new `Config.WalkInPack`
  entry (negative `overallBonus`, no potential boost, zero reach). Remove
  `prospects` from `Config.ScoutLevels` and fix the HUD / panel copy that
  quotes it.
- **`Squad.trialistPack(seed, players)`**: the match-1 pack. Normal walk-in
  roll, then one card is re-rolled into the role of the weakest starter at
  `thatStarter.overall + 4..6` TEMP.
- **`Config.CardArt`**: tier name → asset id, plus `back`. **`Config.PackOdds`**:
  placeholder table documenting tier odds per scout level (derived by test, not
  hand-written, see Testing).

### Server (`ClubService`)

State added to the save: `packRevealed: boolean`, `packFree: boolean`
(match-1 pack, one free signing left), `pinned: Prospect?`.

- `refreshShortlist()` runs for scout level 0 too; after match 1 it calls
  `trialistPack` and sets `packFree`. Sets `packRevealed = false`.
- Action `openReport`: clears `ScoutReportNew` (as now).
- Action `packRevealed`: sets the flag so a reopen shows the cards face-up.
- Action `sign`: also looks in `pinned`; fee is 0 while `packFree`, which then
  clears; optional second arg `releaseId` releases that player first (rule 9),
  validated the same way the existing release action is.
- Actions `pin <id>` / `unpin`: move a shortlist prospect into `pinned` /
  drop it. Season rollover clears `pinned`.
- Published club JSON gains `pinned`, `packRevealed`, `packFree`.
- Old saves: missing fields default to `false` / `nil`; a saved shortlist of a
  different length is kept until the next report replaces it.

### Client

- **`PlayerCard`** (new module). `PlayerCard.new(player, opts) -> Frame`. Tier
  art by `Squad.rarity`, overall, position, frame-drawn flag (`Nations`), club
  crest (signed players only), `Headshot` bust + torso, `Format.cardName`, six
  stats. Layout in scale units off the 2:3 art so it works at any size. One line
  of name text fitted with `TextService:GetTextSize`, not `TextScaled`.
  `card:showBack()` / `card:flip()` do the 2D squash-spin.
- **`Headshot`**: bust gains an optional torso (`shirtColor`), cached per
  look + colour.
- **`PackOpening`** (new module). `PackOpening.open(club, { fromDesk: boolean })`:
  1. lock movement, hide HUD and ClubPanel; if `fromDesk`, tween the camera to
     the folder (~0.6 s) with DoF;
  2. dark overlay in, folder opens, three backs slide out, ordered worst → best;
  3. tap to flip, build-up for Rare+, tier-coloured rim glow, wonderkid shimmer,
     sound per beat; hold / double-tap reveals all; fire `packRevealed`;
  4. result state: three cards with Sign / Pin, the pinned card (if any) in a
     smaller fourth slot, Done. Squad-full opens the release picker;
  5. Done or Escape restores camera, HUD and movement. Any error in the
     sequence jumps straight to step 4 so the player is never stuck.
  If `club.packRevealed` is already true, it opens directly at step 4.
- **`ClubPanel`**: the desk prompt and a Scouting-tab "Open report" button call
  `PackOpening.open`; the Scouting tab lists the same three prospects plus the
  pin. Remove the TEMP open-the-tab behaviour.
- **First walkout** (rule 4): `LineupBoard` shows the XI as `PlayerCard`s the
  first time only.

### Assets

Upload the seven PNGs in `assets/ui/cards/keyed/` via Studio MCP, ids into
`Config.CardArt`. Sounds (slide, flip, three sting strengths) from the Roblox
licensed library into `Config`'s audio table.

## Build order

1. `CardStats` + tests.
2. Pack rules: `PackSize`, walk-in pack, trialist pack, pin, free sign,
   release-and-sign, save fields + tests.
3. Card art upload, `PlayerCard`, headshot torso. Check in Studio at phone size.
4. `PackOpening` sequence and result state; wire the desk prompt and menu.
5. Lineup cards at first walkout.
6. Audio and polish pass; full playtest: new save → match 1 → free trialist →
   match 2 pack → pin → squad-full sign.

Each step is tested and committed before the next.

## Testing

- `CardStatsTest`: deterministic per player; rises with overall; ST SHO > DEF,
  CB DEF > SHO; all stats within 1..99.
- `SquadTest`: every pack has 3 cards at every scout level including 0;
  walk-in packs are mostly Bronze over 1,000 seeds; trialist pack always holds
  one card better than the weakest starter in the same role. The same sweep
  prints tier odds per scout level for `Config.PackOdds`.
- `ClubService` / `ProfileTest`: pin replace, locked fee, pin survives a new
  report, cleared at season end; free sign only once; release-and-sign is
  atomic (no release if the sign would fail); old save loads.
- Studio playtest of the full flow at a phone resolution, including skip,
  reopen after reveal, and leaving mid-reveal.

## TEMP values to label in code

Trialist bonus (+4..6), walk-in `overallBonus`, stat weight table, reveal
timings, pin expiry at season end.

## Deviations at implementation (2026-09-21)

- Card name text uses `TextScaled` in a fixed box, not `GetTextSize` (TextWrapped stays false).
- The XI is shown as a card strip in `Match.client.luau` during the first walkout, not in `LineupBoard`.
- `PackOpening.open(getClub, actionEvent, { fromDesk, folder })`; the HUD is covered by an opaque shade rather than hidden.
- Movement is frozen via the humanoid (no PlayerModule controls in this project).
- UNPIN discards the pinned card and needs a second tap; so does PIN when a pin already exists.
- Hiring or upgrading a scout keeps the match-1 free pack until it is used.
- Server toasts are shown inside the overlay.
- Tier odds (`Config.PackOdds`) are measured at squad average 60 only.
