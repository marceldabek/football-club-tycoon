# Overnight Log — 2026-09-23

Previous nights: `docs/archive/OVERNIGHT_LOG_2026-09-17.md`.

## Morning handoff (kept current)

*Not started yet.*

## Prep (01:35–02:00, with Marcel)

- Baseline: 879 passed, 0 failed; Rojo connected on 34872 and syncing.
- X370: the iris is gone; every transition is a fade to black (`src/client/Fade.luau`). Checked in Play
  mode: the match walkout leaves the fade fully open and hidden, and a close/open round trip goes black and back.
- X369 **live crash fixed:** any club with a record appearance holder failed to load (`accent` was
  removed by the crest builder but still used in `WorldBuilder.buildHonours`). Build 0.1.1 has this bug,
  so **it needs publishing**. `PlotService` now logs a traceback when a club fails to start.
- X365 and X366 were already done by SOFT_LAUNCH SL6/SL7; ticked.
- Club buildings decisions recorded in `docs/CLUB_BUILDINGS.md`; Phase P added to the backlog.

## P6 (15:20–16:14, day session)

- #19 pack screen: SCOUT REPORT + "3 PLAYERS DISCOVERED", green SIGN £X + square pin button (drawn from
  frames, Gotham has no pin glyph), "PIN UNTIL SEASON END" caption, CONTINUE >. `Pack.slots` keeps every
  report card in its slot (worst first, like the reveal); `pack.report`/`pack.signed` are published as
  `packReport`/`packSigned`, session only (not saved). 885 passed; checked sign, pin, pin-over and the
  older-pin extra slot in Play.
- MCP trap: `user_mouse_input` takes GUI coordinates (below the 58 px top bar), not screenshot pixels.
  Clicking at screenshot y hit CONTINUE and looked like the screen closing itself.

## P8 (16:15–16:20, day session)

- #3: the tags were already on all match; `MaxDistance = 60` hid them past 60 studs, i.e. most of a
  290-stud pitch from any stand. Now 400, and the size is `UDim2.new(2.7, 77, 0.42, 12)` (shared as
  `BlockFootballer.TAG_SIZE`) so far tags stay readable without a banner over nearby heads.
- #4: `Presenter.offsideLine(half)`: deepest outfield player of the side defending that end, or the ball
  if deeper. `Footballer:giveFlag()` welds a stick + 2x2 red/yellow cloth to the right hand (rig or call,
  whichever lands second; block fallback carries none). Evening matches are still dark (#2).

