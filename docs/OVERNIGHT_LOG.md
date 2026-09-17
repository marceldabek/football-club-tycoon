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
