# Overnight Agent Brief — night of 2026-09-23

> Start it in a fresh Claude Code session in this folder with:
> `/goal Follow docs/OVERNIGHT.md and work through Phase P in docs/BACKLOG.md. Done when Phase P is finished, or it is after 09:00 on Wednesday 2026-09-23 (local time), or Studio is unreachable and no [disk] item is left.`
> Fallback if `/goal` isn't available: `/loop Follow docs/OVERNIGHT.md. Continue from docs/OVERNIGHT_LOG.md.`
> Edit this file to steer future nights. The 2026-09-17 brief and log are in `docs/archive/`.

You are the **lead agent** working unattended on Football Club Tycoon. Marcel is asleep and nobody will
answer before morning. Tonight is a **short, focused list**, not an open-ended polish run: finish
**Phase P** in `docs/BACKLOG.md` (P1–P11) in order, then stop.

## 0. Read first (once)

- `CLAUDE.md` (sections 21, 22 and 27) and your memory directory (Roblox Studio workflow notes first).
- `docs/BACKLOG.md` → **Phase P** only. Each item names its playtest number.
- `docs/PLAYTEST_NOTES_2026-09-21.md` for the full text of each playtest item.
- For P9: `docs/CLUB_BUILDINGS.md` (decisions already taken) and the ground plan spec
  `docs/superpowers/specs/2026-09-22-ground-plan-design.md` + `tools/ground_plan.py`.
- For P10/P11: the ground plan spec and `docs/ground_plan/proposed_L1..L4.png`.

## 1. Setup (first iteration only)

1. Stay on branch `overnight/2026-09-23` (already created). Never commit to master, never push, never force.
2. Check Studio (`list_roblox_studios`, `get_studio_state`), Edit mode, run `RunAll`. Baseline at
   01:50 was **879 passed, 0 failed**, with Rojo connected (port 34872) and syncing.
3. Start `docs/OVERNIGHT_LOG.md` with a "Morning handoff" section at the top (section 6).

## 2. Hard rules

- **Studio is one shared resource.** Only you, the lead, touch Studio. Subagents never call Studio tools.
- **Disk is the source of truth.** Build from code in `src/`. Studio-only edits count as lost work.
- **Test before commit.** `RunAll` in Edit mode after code changes. Commit small, one backlog item per
  commit where possible, message ending in the Co-Authored-By line. Tick the item with a time.
- **Don't break the loop.** Play Match → earn → upgrade must still work, and a club must still load.
  After any server change, claim a plot in Play mode (`DebugRun "claim|1"`) and check the console for
  `failed to start` (that's how X369 was caught).
- **Don't decide open questions.** If an item needs a design call, pick a clearly labelled TEMP value,
  add a numbered question with a recommendation to the handoff, and move on.
- **Not tonight:** online/1v1 work, monetization (#43/#44), away economy (#17), scooter (#42),
  stadium capacity past 8,000 (X234), tactics effects (X360), town items #27–#39, the crowd avatar
  swap (#6c/#9). Don't touch `git stash` entry `stash@{0}` (the old X368 wage-base attempt).
- Assets: free only (see `docs/FREE_ASSETS.md`); `generate_mesh` is fine for props. Nothing paid.

## 3. Token budget (Marcel asked for this: don't burn tokens overnight)

- **At most 2 subagents at a time**, and only for `[disk]` work that is clearly separable (P1's
  checker script, P7, one building of P9 each). Use `model: "sonnet"` and `isolation: "worktree"`.
  Give each a self-contained prompt. Review their diff yourself before merging.
- **Two strikes per item.** If the same item has failed twice (two approaches, or ~45 minutes),
  stop, write what you tried and why it failed in the log as a known bug, and move to the next item.
  Never loop on one problem.
- **When Phase P is done, stop.** Don't invent new polish items. Write the handoff and finish.
- Screenshots only to verify a visual item, at `scale` 0.5, at most ~3 per item.
- Keep `execute_luau` output short (counts, names, first error). Read only the part of a file you need.
- If Studio stops responding: retry once after a minute. If it's still dead, do `[disk]` items only
  (P1, P2, P7, P9) and note it in the handoff.

## 4. Item notes

- **P1** first. X369 shipped because a local was removed and one use of it was missed. The checker only
  has to be good enough to catch that class of bug: an identifier read in a file, never declared in any
  scope that reaches it, and not a Luau/Roblox global. Some false positives are fine; list them in the
  script's allowlist. Fix every real hit and name each one in the log.
- **P3:** reuse the existing "go to my club" server move, then run the normal Play Match flow.
- **P5:** check the room scale against the kit props before scaling anything up (#24f says the props
  are "at real scale"). Fixtures notice: `src/server/Clubhouse.luau:792`, `src/server/SeasonService.luau:94`.
- **P6:** Marcel's mockup is described in #19c. Use a pin, not a star.
- **P9:** a **proposal document only**, draft per building in the order `docs/CLUB_BUILDINGS.md` gives.
  Generate SVGs with a small Python script next to `tools/ground_plan.py` (same scale and coordinate
  frame). Put every new question in that doc's question list, numbered, with a recommendation.
- **P10/P11** are big. Split P10 into steps (wall + gates, then turnstile blocks, then huts + forecourt,
  then end stairs), commit each, and playtest fan routes after each. Only start once P1–P8 are done.

## 5. Each iteration

1. Take the next unticked Phase P item. Split it if it's L.
2. Hand separable `[disk]` work to a subagent (max 2 running), do the `[studio]` work yourself.
3. Test, commit, tick with a time, add 2–4 lines to `docs/OVERNIGHT_LOG.md`.
4. Next item.

## 6. Morning handoff (keep it current, top of `docs/OVERNIGHT_LOG.md`)

- **What to look at:** where to stand in Studio, what to press.
- **Done / half-done / reverted**, by Phase P number.
- **Known bugs**, numbered.
- **Questions for Marcel**, numbered, each with a recommendation.
- **Studio state:** remind Marcel to save the place if anything exists only in Studio, and to publish
  if a live-crash fix (like X369) landed.
