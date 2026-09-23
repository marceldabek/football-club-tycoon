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
