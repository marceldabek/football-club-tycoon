# Overnight Agent Brief

> Start it in a fresh Claude Code session in this folder with (preferred):
> `/goal Follow docs/OVERNIGHT.md and keep working through docs/BACKLOG.md. Done only when it is after 08:00 on Friday 2026-09-18 (local time), or Studio is unreachable and no [disk] work is left.`
> Fallback if `/goal` isn't available: `/loop Follow docs/OVERNIGHT.md. Continue from docs/OVERNIGHT_LOG.md.`
> Edit this file to steer future nights. Re-read it at the start of each backlog item.

You are the **lead agent** working unattended on Football Club Tycoon. **This run is long:** Marcel is
away from the night of Wed 2026-09-16 until **Friday 2026-09-18 morning** (~32 hours). Nobody will read or
answer anything before then. Pace yourself: keep committing small, keep the handoff current, and if you
hit a usage limit or the session resumes after a break, re-read this file and the log and carry on.
Your job is to get as much real, tested progress as you can on the Rivermere shared-town direction,
so that in the morning he can walk around, list what's wrong, and fix it with you.

## 0. Read first (once per session, not every iteration)

- `CLAUDE.md`, especially **section 27** (decided town/multiplayer direction) and section 21 (agent rules).
- `docs/WORLD_ROADMAP.md` (sessions A–J; every question is DECIDED) and `docs/WORLD_VISION.md`.
- `docs/SLICE_PLAN.md`, `docs/ASSET_KIT.md`, `assets/kit/MANIFEST.md`.
- Every image in `assets/references/` (including `town/`). These are the look to aim for. Many say "Riverdale": the town is **Rivermere**. Never write Riverdale in signs, code or docs.
- Your memory directory, especially the Roblox Studio workflow notes.
- `docs/BACKLOG.md` and `docs/OVERNIGHT_LOG.md` if they exist.

## 1. Setup (first iteration only)

1. Work on a branch: `git switch -c overnight/<today's date>` (or switch to it if it already exists). Never commit to master, never push, never force anything.
2. Check Studio is connected (`list_roblox_studios`, `get_studio_state`), Edit mode, and run the test suite. Record the baseline in the log.
3. If `docs/BACKLOG.md` doesn't exist, build it (section 3).

## 2. Hard rules

- **Studio is one shared resource.** Only you, the lead, touch Roblox Studio through MCP. Subagents never call Studio tools.
- **Disk is the source of truth.** MCP cannot save the place, and Studio can crash overnight. Build town geometry from **layout data + builder code in `src/`** (Q26), so everything can be rebuilt from git. Hand-placed Studio-only edits count as lost work unless they are captured as code or an `.rbxm`.
- **Test before commit.** Run `RunAll` in Edit mode after code changes. Take a screenshot to check anything visual. Commit small and often, with clear messages ending in the Co-Authored-By line.
- **Use the reference images whenever possible.** Before building or restyling any district, street, building, landmark or prop, open the matching images in `assets/references/` (for example `RivermereCenter.png`, `RiveremereWestdale.png`, `RivermereNorthfields.png`, `RivermereRiverside.png`, `RivermereStation.png`, `RivermereTurnstileEntrance.png`, `rivermer.industrialestate.png`, `RivermereAIMap.png`). Match their layout, materials, colours, signage style and props. In each log entry, name the image you worked from. When you finish a visual item, compare your screenshot against the image and list the biggest differences as follow-up backlog items. If no image fits, say so in the log and add "reference image needed for X" to Questions for Marcel.
- **Don't break the loop.** Play Match → earn → upgrade must still work after every change. If a change breaks it and you can't fix it in about 20 minutes, revert it and log the problem.
- **Assets:**
  - Allowed: free Creator Store models (strip every script, log the id and creator in `assets/kit/MANIFEST.md`), free CC0 sources (Poly Haven, ambientCG, Kenney), `generate_mesh` for props, and uploading your own GLB exports with `tools/upload_kit.py`.
  - **Actively look for free models that match the reference images.** Before building something from primitives, search `search_asset` (Creator Store, free only), Poly Haven, ambientCG and Kenney for a close match (terraced houses, shopfronts, lamp posts, bus shelters, benches, bins, planters, railings, trees, cars, station and industrial pieces), then download or insert it. Only use sources that don't need a login, since you can't sign in or create accounts. Check the licence (CC0 / free Creator Store), log it in `assets/kit/MANIFEST.md`, and remove scripts. If the best match needs a login or payment, add it to the buy list with a link instead. Use primitives only when nothing free fits well.
  - Not allowed: buying anything (paid packs, Robux). Add them to a "Buy list for Marcel" section in the log with the price and why.
  - Not allowed: executables or files from unknown sites.
  - Prefer bought or downloaded buildings over generated ones (Q27).
  - Never print or commit `.roblox_api_key`.
- **Mobile budget.** The target is a mid-range phone (Q18). Keep StreamingEnabled-friendly structure, reuse meshes, and log part/triangle counts for each district.
- **No online / 1v1 work** until the J0 design talk (Q35). No monetization.
- **Don't decide open questions silently.** If something genuinely blocks, pick a clearly labelled TEMP value, log the question in the "Questions for Marcel" section with a recommendation, and move on to other work.
- **Don't stop to ask.** Nobody will answer until morning. Keep choosing the next unblocked item.

## 3. The backlog (`docs/BACKLOG.md`)

Turn CLAUDE.md s27, the roadmap phases A–J, the milestones, `docs/SLICE_PLAN.md` and the reference
images into one ordered, very long checklist. Give each item:

- a one-line outcome that can be checked ("Terraced street 1: 12 houses, pavements, lamp posts, bins")
- a tag: `[studio]` (needs Studio to build or verify) or `[disk]` (code, data, exports, docs, research)
- a size: S (<30 min) / M (<2 h) / L (split it)
- dependencies

Suggested first stretch, in order:

- **A1:** client-side hero-afternoon lighting and the post-match fast-forward.
- **B1–B3:** the club becomes a plot, with 4 plots, the plot picker on load, the for-sale lot, and despawn on leave.
- **C1–C2:** greybox Rivermere from the concept map: ring road, river + bridges, railway + viaduct + station, centre with a market square, the four ground sites on the edges.
- **C3:** performance baseline.
- **E:** the first district, terraced streets beside the centre, using the kit houses.
- Then bus-stop fast travel, landmarks (church spire, bridge, viaduct), and so on.

When the backlog runs low, extend it: polish passes, bugs found while testing, missing props from the
reference images. There is always more to do.

## 4. Each iteration

1. Pick the top unblocked item. Break it down if it's L.
2. **Parallelise the disk work.** Send independent `[disk]` items to subagents, several at once, each in an isolated git worktree (`isolation: "worktree"`), using the cheaper `sonnet` model for mechanical work: GLB export batches, layout data tables, pure-logic modules with tests, asset research lists. Give each one a self-contained prompt and tell it not to touch Studio. Review and merge their branches yourself, then verify in Studio.
3. Do the `[studio]` item yourself: sync (Rojo or `tools/studio-sync.luau`), build, run tests, take a screenshot, fix.
4. Commit, tick the item, and append 2–4 lines to `docs/OVERNIGHT_LOG.md`: what changed, how it was tested, known bugs.
5. Next item. Don't finish your turn while unblocked work remains.

## 5. Spend tokens carefully

- Screenshots only to verify visual work, and at reduced `scale`. Don't take one after every small tweak.
- Read only the part of a file you need. Don't re-read files you just edited.
- Keep `execute_luau` output short (counts, names, first error), not whole dumps.
- If the same approach has failed twice, stop, write down why, and move to a different item.
- If Studio stops responding, wait, retry once, and if it's still dead switch to `[disk]` items only and log it.

## 6. Morning handoff (keep it current all night)

At the top of `docs/OVERNIGHT_LOG.md`, keep an up-to-date summary with:

- **What to look at:** where to stand in Studio, and screenshots saved in `assets/screenshots/overnight/`.
- **Done / half-done / reverted.**
- **Known bugs** (numbered, so Marcel can answer by number).
- **Questions for Marcel** (numbered, each with a recommendation).
- **Buy list for Marcel.**
- **Studio state:** remind Marcel to save the place (Ctrl+S / File → Save to Roblox) before trusting anything that only exists in Studio.
