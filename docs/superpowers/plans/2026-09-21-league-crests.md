# League Crests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the real crest art for the 40 league clubs in every UI crest.

**Architecture:** A Python script keys, squares and renames the 40 PNGs; they are
uploaded through Studio MCP and their ids stored on each `Config.Clubs` entry.
`Config.clubCrestImage(name)` looks an id up by name. `Crest.luau` gains one
function, `Crest.applyArt(shield, name, isPlayer)`, which adds or updates an `Art`
ImageLabel inside an existing shield and hides the shield's own decoration
(fill, stroke, initials). `draw`, `update` and MatchSummary's own shields all call it.

**Tech Stack:** Python 3 (PIL, numpy, scipy), Luau, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-09-21-league-crests-design.md`

## Global Constraints

- No club is renamed; the `Config.Clubs` names are the source of truth.
- The player's own club is never given league art (`isPlayer` → no art). The crest builder owns it.
- Files: `assets/ui/crests/` (plural). The builder uses `assets/ui/crest/`, so do not touch that.
- Background key = flood fill from the corners only, never a global white key.
- Keyed output is 256×256 RGBA.
- No automatic kit-colour changes; the colour report is print-only.
- Tests run only in Studio Edit mode: `print(loadstring(game.ServerStorage.Tests.RunAll.Source)()())`.
- Other agents share the tree and Studio: stage only this plan's files, and never `git add -A`.

---

### Task 1: Prep script — rename, key, square, contact sheet, colour report

**Files:**
- Create: `tools/prep_crests.py`
- Output: `assets/ui/crests/src/*.png`, `assets/ui/crests/keyed/*.png`, `assets/ui/crests/contact_sheet.png`

**Interfaces:**
- Produces: `assets/ui/crests/keyed/tier<N>_<kebab>.png` for all 40 clubs; kebab = lowercase name, non-alphanumerics → `-`, trimmed (`Kestrel Green FC` → `kestrel-green-fc`).

- [ ] Step 1: Write the script. It parses `Config.Clubs` from `src/shared/Config.luau` (a regex on `name = "..."` inside the block that starts at `Config.Clubs = {`, with the tier counted from `{ --` division openers). It matches each source file by the text before ` — `, with `.`, `'`, spaces and quotes stripped from both ends. It stops with a listing if any club has no file or any file has no club.
- [ ] Step 2: Key: backdrop = median of the corner 8×8 patches; alpha ramps from 0 to 1 over colour distance 40→120; alpha is cleared only for components connected to the border; despill via the nearest solid pixel (same method as the card keyer).
- [ ] Step 3: Trim to alpha > 8, pad to a square with a 4% margin, LANCZOS resize to 256, save.
- [ ] Step 4: Contact sheet: 8 columns × 5 rows of 128px cells on a grey checker, one division per row.
- [ ] Step 5: Colour report: k-means (k=3, on opaque pixels that aren't near-white) → the two biggest clusters vs `kit`/`accent` (whichever pairing is better). Print a club if the best-pair mean RGB distance is > 60.
- [ ] Step 6: Run `python tools/prep_crests.py`. Expected: "40 crests written", the report lines, no errors. Open the contact sheet and check for holes in the white-accent crests.
- [ ] Step 7: Commit the script and assets.

### Task 2: Upload and Config ids

**Files:**
- Create: `assets/ui/crests/asset_ids.json`
- Modify: `src/shared/Config.luau` (`export type Club`, the 40 entries, and a new `Config.clubCrestImage` after `Config.clubCrest`)
- Test: `tests/CrestArtTest.luau`

**Interfaces:**
- Produces: `Config.clubCrestImage(name: string?, isPlayer: boolean?): string?`, which returns `"rbxassetid://<id>"` for a known league club, or nil for the player, nil, "" or an unknown name.

- [ ] Step 1: Write `tests/CrestArtTest.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

function T.everyLeagueClubHasArt()
	local n = 0
	for _, tier in Config.Clubs do
		for _, club in tier do
			n += 1
			assert(type(club.crest) == "string" and club.crest:match("^rbxassetid://%d+$"), club.name .. " has no crest id")
			assert(Config.clubCrestImage(club.name) == club.crest, club.name .. " lookup")
		end
	end
	assert(n == 40, "40 clubs, got " .. n)
end

function T.noArtForPlayerOrUnknown()
	local first = Config.Clubs[1][1].name
	assert(Config.clubCrestImage(first, true) == nil, "player never gets league art")
	assert(Config.clubCrestImage(nil) == nil, "nil name")
	assert(Config.clubCrestImage("") == nil, "empty name")
	assert(Config.clubCrestImage("Nowhere Athletic") == nil, "unknown club")
end

return T
```

- [ ] Step 2: Sync to Studio and run. Expected: FAIL (`clubCrestImage` is nil).
- [ ] Step 3: Upload the 40 keyed PNGs with MCP `upload_image`, and write `{ "tier1_bramblewick-rovers.png": "<id>", ... }` to `asset_ids.json`.
- [ ] Step 4: Add `crest: string?` to `export type Club`, add `crest = "rbxassetid://<id>"` to each entry, and add:

```lua
-- League crest art (docs/CRESTS.md, tools/prep_crests.py). The player's club
-- never has league art; its crest is drawn by the crest builder.
local crestImageByName: { [string]: string } = {}
for _, tierClubs in Config.Clubs do
	for _, club in tierClubs do
		if club.crest then
			crestImageByName[club.name] = club.crest
		end
	end
end

function Config.clubCrestImage(name: string?, isPlayer: boolean?): string?
	if isPlayer or name == nil then
		return nil
	end
	return crestImageByName[name]
end
```

- [ ] Step 5: Sync and run. Expected: CrestArtTest passes, with no new failures elsewhere.
- [ ] Step 6: Commit.

### Task 3: Crest.luau draws the art; MatchSummary uses it

**Files:**
- Modify: `src/client/Crest.luau` (add `applyArt`, and call it from `draw` and `update`)
- Modify: `src/client/MatchSummary.luau:622-633`
- Test: `tests/CrestArtTest.luau` (add cases)

**Interfaces:**
- Consumes: `Config.clubCrestImage`.
- Produces: `Crest.applyArt(shield: Frame, name: string?, isPlayer: boolean?): boolean`. It returns true when art is shown. With art, the shield background is transparent, the `UIStroke` is disabled and every other GuiObject child is hidden. Without art, those are restored and the `Art` child is hidden.

- [ ] Step 1: Add the tests:

```lua
local function crestModule()
	return require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Crest)
end

function T.drawShowsArtForLeagueClub()
	local Crest = crestModule()
	local holder = Instance.new("Frame")
	local name = Config.Clubs[3][1].name
	local shield = Crest.draw(holder, name, 34)
	local art = shield:FindFirstChild("Art") :: ImageLabel
	assert(art and art.Visible and art.Image == Config.clubCrestImage(name), "art shown")
	assert(shield.BackgroundTransparency == 1, "fill hidden")
	local letters = shield:FindFirstChild("Initials") :: TextLabel
	assert(letters and not letters.Visible, "initials hidden")
	holder:Destroy()
end

function T.updateSwapsArtAndShield()
	local Crest = crestModule()
	local holder = Instance.new("Frame")
	local name = Config.Clubs[5][2].name
	local shield = Crest.draw(holder, name, 34)
	Crest.update(shield, "Rivermere Nobodies", true)
	local art = shield:FindFirstChild("Art") :: ImageLabel
	assert(art == nil or not art.Visible, "art hidden for the player")
	assert(shield.BackgroundTransparency == 0, "fill back")
	assert((shield:FindFirstChild("Initials") :: TextLabel).Visible, "initials back")
	Crest.update(shield, name, false)
	assert((shield:FindFirstChild("Art") :: ImageLabel).Visible, "art again")
	local arts = 0
	for _, c in shield:GetChildren() do
		if c.Name == "Art" then
			arts += 1
		end
	end
	assert(arts == 1, "one Art child")
	holder:Destroy()
end
```

- [ ] Step 2: Sync and run. Expected: FAIL (no `Art`).
- [ ] Step 3: Implement `applyArt` in `Crest.luau`. `draw` builds the shield exactly as today (initials only at 24px and up), then calls `applyArt`. `update` recolours as today, then calls `applyArt`.
- [ ] Step 4: In MatchSummary, after each side is recoloured, call `Crest.applyArt(homeShield, leftName, leftIsUs)` and `Crest.applyArt(awayShield, rightName, not leftIsUs)`. `Inner` holds the initials there, and it is hidden by the "other children" rule.
- [ ] Step 5: Sync and run. Expected: all CrestArtTest cases pass, with no regressions.
- [ ] Step 6: Visual check in Studio play at phone size: league table, scoreboard, summary. Pay attention to the Division 3 crests at table size.
- [ ] Step 7: Update the CRESTS.md "Notes for later". Commit, then push.
