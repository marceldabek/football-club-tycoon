# Overnight Log

## Morning handoff (kept current)

**What to look at:** (filled in as work lands)

**Done:** —
**Half-done:** —
**Reverted:** —

**Known bugs**
1. —

**Questions for Marcel**
1. —

**Buy list for Marcel**
- —

**Studio state:** Save the place (Ctrl+S / File → Save to Roblox) before trusting anything that only exists in Studio.

---

## Entries

### 2026-09-17 00:24 — setup
- Branch `overnight/2026-09-17`. Studio connected (Edit). Baseline RunAll: **76 passed, 0 failed**.
- Rojo server was not running; started `rojo serve` in the background. The MCP sandbox now also blocks
  `HttpService` (Network capability), so `tools/studio-sync.luau` cannot run from MCP. Sync is done by
  writing `Source` directly through `execute_luau` (works). Studio sources matched disk at start (only CRLF differences).
- Wrote `docs/BACKLOG.md` (reference: `RivermereAImap.png` for the phase C frame).

### 2026-09-17 ~00:40 — A1/A2 client sky, B1.1 PlotRegistry, B3.1 SaveLock
- New `src/client/Sky.luau` + `src/shared/DayCycle.luau` (subagent): lighting is per player now. Hero afternoon at 15:00; evening fixtures (TEMP: match index % 4 == 3, never matches 1–2) tween to the floodlit look and the server turns floodlights on for everyone; afternoon matches no longer go dusky. Summary "Back to Club" plays the ~4 s fast-forward (evening → night → dawn → afternoon), any click/key skips; season card plays the ~10 s one (not playtested).
- Tested: Play mode, evening match 35: server floodlights 72/72 neon, client clock 19.2; after Continue the client clock went 19.0 → 20.4 → 0.5 → 4.4 → 7.8 → 14.7 → 15.0. RunAll 95/95 in Edit.
- `PlotRegistry` and `SaveLock` pure modules + tests merged (not wired yet). No reference image applies (lighting).
- Sync note: Studio gets condensed copies of new modules/tests (comments trimmed). Disk is the source of truth; Rojo will overwrite them when Marcel reconnects.

### 2026-09-17 ~00:50 — Clubs become plots (B1.2, B2.1b, B2.3, B4.1) + town plan (C1)
- Each claimed plot now runs its own copy of the club services (docs/PLOTS.md): `PlotService` clones the modules into `ServerScriptService.ClubRuntime.PlotN`, `PlotContext` gives each copy its state folder (`ReplicatedStorage.Clubs.PlotN`), world (`workspace.Plots.PlotN.Club`) and transform; `RemoteRouter` sends each remote to the sender's plot; clients use `ClubRef`. Free plots show a for-sale lot (grass, council FOR SALE board, trees, rocks, fence posts). Leaving saves, despawns and restores the lot. TEMP: first free plot is auto-assigned until the picker lands.
- Tested (Play): club loaded on a plot rotated 180°, owner placed in the office, full 25 s match with footballers/ball/crowd on the right pitch (screenshot checked), summary + payout arrived, North stand expansion rebuilt in place. RunAll 110/110 (incl. new TownLayout tests).
- Town plan + layout data (subagent, `docs/TOWN_PLAN.md`, `src/shared/TownLayout.luau`, reference `RivermereAImap.png`): plots at SE (1050,1250) yaw 270, NE (1900,-1200), E (1950,420), NW (-1900,-1200) yaw 180. Plots now use these.
- Also merged: `KitPlacer` (not yet in Studio), `docs/FREE_ASSETS.md` (Poly Haven/ambientCG shortlist; Poly Haven has no buildings/vehicles).
- Note: the place is published, so Studio playtests load and save **Marcel's real club** from DataStore (it went from 34 to 36 matches, cash up, North stand +1 during testing). Backlog X1 proposes a Studio-only save key.
