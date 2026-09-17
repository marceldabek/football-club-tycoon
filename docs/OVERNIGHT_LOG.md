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

### 01:50 — A1/A2 client sky, B1.1 PlotRegistry, B3.1 SaveLock
- New `src/client/Sky.luau` + `src/shared/DayCycle.luau` (subagent): lighting is per player now. Hero afternoon at 15:00; evening fixtures (TEMP: match index % 4 == 3, never matches 1–2) tween to the floodlit look and the server turns floodlights on for everyone; afternoon matches no longer go dusky. Summary "Back to Club" plays the ~4 s fast-forward (evening → night → dawn → afternoon), any click/key skips; season card plays the ~10 s one (not playtested).
- Tested: Play mode, evening match 35: server floodlights 72/72 neon, client clock 19.2; after Continue the client clock went 19.0 → 20.4 → 0.5 → 4.4 → 7.8 → 14.7 → 15.0. RunAll 95/95 in Edit.
- `PlotRegistry` and `SaveLock` pure modules + tests merged (not wired yet). No reference image applies (lighting).
- Sync note: Studio gets condensed copies of new modules/tests (comments trimmed). Disk is the source of truth; Rojo will overwrite them when Marcel reconnects.
