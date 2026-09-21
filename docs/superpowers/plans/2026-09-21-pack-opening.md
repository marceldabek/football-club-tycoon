# Pack Opening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The scout report on the office desk becomes a 3-card pack: walk up to the folder, fullscreen reveal, then Sign / Pin / Done.

**Architecture:** The server (`ClubService`) rolls and owns every pack; pure rules live in `Shared/Squad`, `Shared/CardStats` and a new `Shared/Pack` so they are unit-testable. The client gets three new modules (`FlagView`, `PlayerCard`, `PackOpening`) that only draw and animate what the published club JSON says.

**Tech Stack:** Luau, Rojo 7.4.4, Roblox Studio MCP. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-21-pack-opening-design.md` (read it first; rule numbers below refer to its table).

## Global Constraints

- Every pack is exactly 3 cards (`Config.PackSize = 3`).
- The match sim never reads card stats. Stats are display-only.
- No real player names. No paid assets.
- The reveal is always skippable and the whole sequence is under ~10 s.
- The overlay is client-only. Nothing about the reveal replicates.
- Balancing numbers are labelled `TEMP` in a comment, like the rest of `Config.luau`.
- Roles are `"GK" | "DEF" | "MID" | "FWD"` (`Pitch.Role`). The card shows the role, not "ST".
- Match the surrounding comment style: short, lower-case, explain *why*.
- Fit single-line text with `TextService:GetTextSize`. Never set `TextScaled` and `TextWrapped` together.
- **Running tests:** there is no local Luau runner. Studio must be open in **Edit** mode with Rojo connected. Run through MCP `execute_luau`:
  `print(loadstring(game.ServerStorage.Tests.RunAll.Source)()())`
  First check the change actually reached Studio (`script_grep` for a new symbol). If the Rojo plugin is stale, paste the new Source in with `execute_luau` (`.Source = [==[ ... ]==]`), or `multi_edit` with a className to create a new module.
- New test modules in `tests/` are picked up by `RunAll` automatically (any sibling named `*Test`).
- Commit after every task. End commit messages with
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- **Before Task 1:** the working tree has unrelated uncommitted work (X271 coach tactics, light shadows, manila folder, PlotGrounds). Run the suite and commit that first, with Marcel's OK, so pack commits stay clean.

## File Map

| File | Status | Responsibility |
|---|---|---|
| `src/shared/CardStats.luau` | new | six display stats from overall + role + look |
| `src/shared/Pack.luau` | new | pure pin / find / fee rules for a pack |
| `src/shared/Squad.luau` | modify | 3-card packs, walk-in level 0, trialist pack |
| `src/shared/Config.luau` | modify | `PackSize`, `WalkInPack`, `TrialistBonus`, `CardArt`, `PackAudio`, `ProspectKit`; drop `prospects` from `ScoutLevels` |
| `src/server/ClubService.luau` | modify | pack state, actions `packRevealed` / `pin` / `unpin`, free sign, release-and-sign, save fields |
| `src/server/Session.luau` | modify | folder prompt no longer needs a scout |
| `src/client/FlagView.luau` | new | draws a `Nations.Flag` out of Frames |
| `src/client/PlayerCard.luau` | new | one card: art, overall, role, flag, crest, bust, name, stats, flip |
| `src/client/PackOpening.luau` | new | fullscreen sequence + result state |
| `src/client/ClubPanel.client.luau` | modify | prompt and Scouting tab open the pack; copy fixes; pin row |
| `src/client/Match.client.luau` | modify | "meet your XI" card strip on the first walkout |
| `tests/CardStatsTest.luau`, `tests/PackTest.luau` | new | |
| `tests/SquadTest.luau`, `tests/ProfileTest.luau` | modify | |

---

### Task 1: CardStats

**Files:**
- Create: `src/shared/CardStats.luau`
- Test: `tests/CardStatsTest.luau`

**Interfaces:**
- Consumes: a table with `overall: number`, `role: Pitch.Role`, `look: number?`, `id: number`.
- Produces: `CardStats.of(p) -> { { label: string, value: number } }` — always six entries, in card order (left column top to bottom, then right column).

- [ ] **Step 1: Write the failing test** — `tests/CardStatsTest.luau`

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CardStats = require(ReplicatedStorage.Shared.CardStats)

local T = {}

local function player(role: string, overall: number, look: number)
	return { id = 1, role = role, overall = overall, look = look }
end

local function value(stats, label: string): number
	for _, s in stats do
		if s.label == label then
			return s.value
		end
	end
	error("no stat " .. label)
end

function T.sixStatsInRange()
	for _, role in { "GK", "DEF", "MID", "FWD" } do
		for _, overall in { 30, 45, 70, 99 } do
			local stats = CardStats.of(player(role, overall, 1234))
			assert(#stats == 6, "expected six stats")
			for _, s in stats do
				assert(s.value >= 1 and s.value <= 99, s.label .. " out of range")
				assert(#s.label == 3, "labels are three letters")
			end
		end
	end
end

function T.deterministic()
	local a = CardStats.of(player("MID", 60, 777))
	local b = CardStats.of(player("MID", 60, 777))
	for i = 1, 6 do
		assert(a[i].value == b[i].value and a[i].label == b[i].label, "not deterministic")
	end
end

function T.shapedByRole()
	for look = 1, 50 do
		local fwd = CardStats.of(player("FWD", 60, look))
		assert(value(fwd, "SHO") > value(fwd, "DEF"), "a forward shoots better than he defends")
		local def = CardStats.of(player("DEF", 60, look))
		assert(value(def, "DEF") > value(def, "SHO"), "a defender defends better than he shoots")
	end
end

function T.keeperHasKeeperLabels()
	local gk = CardStats.of(player("GK", 60, 5))
	assert(gk[1].label == "DIV" and gk[2].label == "HAN", "keeper labels")
end

function T.risesWithOverall()
	for look = 1, 50 do
		local low = CardStats.of(player("MID", 50, look))
		local high = CardStats.of(player("MID", 56, look))
		for i = 1, 6 do
			assert(high[i].value >= low[i].value, "a stat fell as the player improved")
		end
	end
end

return T
```

- [ ] **Step 2: Run the suite, verify it fails**

Expected: `CardStatsTest` errors with "CardStats is not a valid member of Folder".

- [ ] **Step 3: Implement** — `src/shared/CardStats.luau`

```lua
--!strict
-- The six numbers on a player card. Display only: the match sim reads
-- `overall` and nothing here (CLAUDE.md s22). Nothing is stored either - the
-- stats are worked out from the overall, the role and the look seed each time,
-- so they rise as the player develops and an old save needs no migration.

local CardStats = {}

export type Stat = { label: string, value: number }

-- Offsets from the overall, in card order. TEMP weights.
local OUTFIELD = { "PAC", "SHO", "PAS", "DRI", "DEF", "PHY" }
local KEEPER = { "DIV", "HAN", "KIC", "REF", "SPD", "POS" }
local SHAPE: { [string]: { number } } = {
	FWD = { 3, 5, -4, 3, -30, -2 },
	MID = { -1, -4, 5, 3, -8, -3 },
	DEF = { -3, -25, -6, -10, 5, 4 },
	GK = { 2, 0, -6, 3, -20, 1 },
}
local JITTER = 4 -- each stat moves this far either way, fixed for the player's life

function CardStats.of(p: { overall: number, role: string, look: number?, id: number }): { Stat }
	local shape = SHAPE[p.role] or SHAPE.MID
	local labels = if p.role == "GK" then KEEPER else OUTFIELD
	local seed = p.look or p.id
	local out: { Stat } = {}
	for i = 1, 6 do
		local wobble = Random.new(seed + i * 7919):NextInteger(-JITTER, JITTER)
		out[i] = { label = labels[i], value = math.clamp(p.overall + shape[i] + wobble, 1, 99) }
	end
	return out
end

return CardStats
```

- [ ] **Step 4: Run the suite, verify `CardStatsTest` passes and nothing else broke.**

- [ ] **Step 5: Commit**

```bash
git add src/shared/CardStats.luau tests/CardStatsTest.luau
git commit -m "CardStats: six display-only card stats from overall, role and look"
```

---

### Task 2: Three-card packs, walk-in pack, trialist pack

**Files:**
- Modify: `src/shared/Config.luau:259-274`
- Modify: `src/shared/Squad.luau:928-952`
- Modify: `src/client/ClubPanel.client.luau:620-622,642`
- Test: `tests/SquadTest.luau` (replace `T.prospectsRespectScoutLevel`, add three tests)

**Interfaces:**
- Produces:
  - `Config.PackSize = 3`, `Config.WalkInPack`, `Config.TrialistBonus = { 4, 6 }`
  - `Squad.prospects(seed, avgOverall, scoutLevel, avoidNames?) -> { Prospect }` — now 3 cards at **every** level including 0
  - `Squad.trialistPack(seed: number, players: { Player }, xi: { number }, avoidNames: { [string]: boolean }?) -> { Prospect }`

- [ ] **Step 1: Write the failing tests.** In `tests/SquadTest.luau` replace `T.prospectsRespectScoutLevel` (line 175) with:

```lua
function T.everyPackIsThreeCards()
	for level = 0, #Config.ScoutLevels do
		local list = Squad.prospects(level * 10 + 1, 45, level)
		assert(#list == Config.PackSize, ("level %d gave %d cards"):format(level, #list))
		for _, p in list do
			assert(p.fee >= 100, "fee too small")
			assert(p.id < 0, "prospect ids must be negative")
		end
	end
end

function T.walkInPackIsMostlyBronze()
	local bronze, total = 0, 0
	for seed = 1, 300 do
		for _, p in Squad.prospects(seed, 45, 0) do
			total += 1
			if Squad.rarity(p.overall) == "Bronze" then
				bronze += 1
			end
		end
	end
	assert(bronze / total >= 0.9, ("only %d%% bronze"):format(bronze / total * 100))
end

function T.walkInsAreWorseThanAScouts()
	local walk, local_ = 0, 0
	for seed = 1, 200 do
		for _, p in Squad.prospects(seed, 50, 0) do
			walk += p.overall
		end
		for _, p in Squad.prospects(seed, 50, 1) do
			local_ += p.overall
		end
	end
	assert(walk < local_, "hiring a scout should improve the pack")
end

function T.trialistPackBeatsTheWeakestStarter()
	for seed = 1, 100 do
		local players = Squad.generate(seed, 45)
		local lineup = Squad.autoLineup(players)
		local byId = Squad.byId(players)
		local weakest = byId[lineup.xi[1]]
		for _, id in lineup.xi do
			if byId[id].overall < weakest.overall then
				weakest = byId[id]
			end
		end
		local pack = Squad.trialistPack(seed, players, lineup.xi)
		assert(#pack == Config.PackSize, "trialist pack is three cards")
		local found = false
		for _, p in pack do
			if p.role == weakest.role and p.overall >= weakest.overall + Config.TrialistBonus[1] then
				found = true
			end
			assert(p.potential >= p.overall, "potential below overall")
		end
		assert(found, "nobody in the pack improves the weakest position")
	end
end
```

Check `Squad.byId` is exported (it is `local function byId` at line 82 but line 172 of the tests already calls `Squad.byId`, so an export exists; if not, use a local loop in the test).

- [ ] **Step 2: Run the suite, verify the four tests fail** (`Config.PackSize` nil, `trialistPack` nil).

- [ ] **Step 3: Config.** Replace `Config.luau:259-274` so `prospects` is gone and the new values exist:

```lua
-- Level 0 = no scout. Index = level (no zero entry). A new pack after every match.
-- Every pack is Config.PackSize cards (Marcel, 2026-09-21): a better scout buys
-- quality, reach abroad and a tighter ceiling, never a longer list.
-- X337: `potentialDoubt` is how wide a band the scout will commit a player's
-- ceiling to, in potential points. TEMP: ten points of doubt down to none.
Config.PackSize = 3
Config.ScoutLevels = {
	{ name = "Local Scout", cost = 600, overallBonus = 2, potentialBoost = 3, potentialDoubt = 10 },
	{ name = "Regional Scout", cost = 3000, overallBonus = 4, potentialBoost = 6, potentialDoubt = 7 },
	{ name = "Scouting Network", cost = 8000, overallBonus = 6, potentialBoost = 10, potentialDoubt = 5 },
	-- The top two exist so a club with five figures spare has something worth
	-- buying: prospects are generated around the squad's own average, so a bigger
	-- overallBonus is the only way cash turns into a genuinely better XI.
	{ name = "National Network", cost = 22000, overallBonus = 9, potentialBoost = 14, potentialDoubt = 3 },
	{ name = "Continental Network", cost = 60000, overallBonus = 12, potentialBoost = 18, potentialDoubt = 0 },
}
-- With no scout the pack still comes: lads who turned up asking for a trial.
-- Worse than the squad on average, so the first scout is still worth hiring. TEMP.
Config.WalkInPack = { name = "Walk-in trialists", overallBonus = -4, potentialBoost = 0, potentialDoubt = 12 }
-- The match-1 pack holds one card this much better than the weakest starter in
-- his position (CLAUDE.md s3: early rigging, never shown). TEMP.
Config.TrialistBonus = { 4, 6 }
```

Then `Grep` for `%.prospects` across `src/` and `tests/` and fix any remaining reader (expected: only `ClubPanel.client.luau:621`).

- [ ] **Step 4: Squad.** Replace `Squad.prospects` (lines 928-952) with:

```lua
-- A scout pack: Config.PackSize prospects. Level 0 is the walk-in pack. Better
-- scouts find higher-ceiling players further afield.
-- Ids are negative and unique per seed so they never clash with squad ids.
function Squad.prospects(seed: number, avgOverall: number, scoutLevel: number, avoidNames: { [string]: boolean }?): { Prospect }
	local level = if scoutLevel == 0 then Config.WalkInPack else Config.ScoutLevels[scoutLevel]
	if not level then
		return {}
	end
	local rng = Random.new(seed)
	local people = TeamGen.generatePeople(rng, Config.PackSize, avoidNames, Squad.scoutReach(scoutLevel))
	local list: { Prospect } = {}
	for i = 1, Config.PackSize do
		local role: Pitch.Role = GENERATE_ROLES[rng:NextInteger(3, #GENERATE_ROLES)]
		if rng:NextNumber() < 0.12 then
			role = "GK"
		end
		-- scouts look for players with a future: nobody over 27 in a pack
		local p = makePlayer(rng, -(seed * 100 + i), people[i], 0, role, avgOverall + level.overallBonus, level.potentialBoost, 27)
		local prospect = p :: any
		prospect.fee = Squad.fee(p)
		-- X337: what the scout will actually say about his ceiling
		prospect.potentialLow, prospect.potentialHigh = Squad.potentialBand(p.potential, level.potentialDoubt or 0, p.id, p.overall)
		table.insert(list, prospect)
	end
	return list
end

-- The pack after match 1: a walk-in pack with the last card re-cut to be a
-- clear upgrade on the weakest man in the XI, in his position. The player keeps
-- one of the three for nothing (ClubService), so his first pack always helps.
function Squad.trialistPack(seed: number, players: { Player }, xi: { number }, avoidNames: { [string]: boolean }?): { Prospect }
	local pack = Squad.prospects(seed, Squad.average(players), 0, avoidNames)
	local lookup = byId(players)
	local weakest: Player? = nil
	for _, id in xi do
		local p = lookup[id]
		if p and (weakest == nil or p.overall < (weakest :: Player).overall) then
			weakest = p
		end
	end
	local star = pack[#pack]
	if weakest and star then
		local rng = Random.new(seed + 1)
		star.role = weakest.role
		star.overall = clampOverall(weakest.overall + rng:NextInteger(Config.TrialistBonus[1], Config.TrialistBonus[2]))
		star.potential = math.max(star.potential, star.overall)
		star.fee = Squad.fee(star)
		star.potentialLow, star.potentialHigh = Squad.potentialBand(star.potential, Config.WalkInPack.potentialDoubt, star.id, star.overall)
	end
	return pack
end
```

`trialistPack` must sit **after** `Squad.average` is defined or `average` must be reachable: `Squad.average` is a field lookup at call time, so order in the file does not matter.

- [ ] **Step 5: Scouting copy.** `ClubPanel.client.luau:620-622` becomes:

```lua
	local desc = if level
		then ("A pack of %d after every match. %s"):format(Config.PackSize, precision)
		else ("%d walk-in trialists after every match. Hire a scout for better players, from further afield."):format(Config.PackSize)
```

and line 642's footer becomes `"Better scouts find better players with higher ceilings, look further abroad, and can tell you more precisely how high."`

- [ ] **Step 6: Run the suite.** Expected: the four new tests pass. `ProfileTest` and the other `Squad.prospects` callers (lines 46, 255, 911, 1047, 1074, 1122) still pass; if one asserted a count above 3, change it to `Config.PackSize`.

- [ ] **Step 7: Commit**

```bash
git add src/shared/Config.luau src/shared/Squad.luau src/client/ClubPanel.client.luau tests/SquadTest.luau
git commit -m "Packs are three cards at every scout level; walk-in and trialist packs"
```

---

### Task 3: Pack rules (pin, find, fee)

**Files:**
- Create: `src/shared/Pack.luau`
- Test: `tests/PackTest.luau`

**Interfaces:**
- Produces:
  - `export type State = { shortlist: { Squad.Prospect }, pinned: Squad.Prospect?, free: boolean, revealed: boolean }`
  - `Pack.find(state, id: number) -> (Squad.Prospect?, "shortlist" | "pinned" | nil)`
  - `Pack.pin(state, id: number) -> boolean` — moves the prospect from the shortlist into `pinned`, dropping any old pin
  - `Pack.unpin(state) -> boolean`
  - `Pack.fee(state, prospect) -> number` — 0 for a shortlist card while `free`, else `prospect.fee`
  - `Pack.take(state, id: number) -> Squad.Prospect?` — removes and returns; spends `free` if it was a shortlist card
  - `Pack.replace(state, shortlist, free: boolean)` — new report: swaps the shortlist, keeps the pin, `revealed = false`
  - `Pack.newSeason(state)` — clears the pin

- [ ] **Step 1: Write the failing test** — `tests/PackTest.luau`

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pack = require(ReplicatedStorage.Shared.Pack)
local Squad = require(ReplicatedStorage.Shared.Squad)

local T = {}

local function fresh(free: boolean?): Pack.State
	return { shortlist = Squad.prospects(9, 45, 1), pinned = nil, free = free == true, revealed = false }
end

function T.pinMovesTheCardAndLocksTheFee()
	local s = fresh()
	local target = s.shortlist[2]
	local fee = target.fee
	assert(Pack.pin(s, target.id), "pin failed")
	assert(#s.shortlist == 2 and s.pinned == target, "card did not move")
	Pack.replace(s, Squad.prospects(10, 80, 5), false)
	assert(s.pinned == target and (s.pinned :: any).fee == fee, "pin lost or re-priced by a new report")
	assert(s.revealed == false, "a new report is unrevealed")
end

function T.secondPinReplacesTheFirst()
	local s = fresh()
	local a, b = s.shortlist[1], s.shortlist[2]
	Pack.pin(s, a.id)
	Pack.pin(s, b.id)
	assert(s.pinned == b, "second pin should win")
	assert(Pack.find(s, a.id) == nil, "the old pin is gone, not back in the pack")
end

function T.pinUnknownIdFails()
	local s = fresh()
	assert(Pack.pin(s, 12345) == false)
end

function T.freeSignIsOnceAndNeverThePin()
	local s = fresh(true)
	Pack.pin(s, s.shortlist[3].id)
	local pinned = s.pinned :: Squad.Prospect
	assert(Pack.fee(s, pinned) == pinned.fee, "the pin is never free")
	local card = s.shortlist[1]
	assert(Pack.fee(s, card) == 0, "first trialist is free")
	assert(Pack.take(s, card.id) == card)
	assert(s.free == false, "free signing spent")
	local other = s.shortlist[1]
	assert(Pack.fee(s, other) == other.fee, "second one costs")
end

function T.takeThePin()
	local s = fresh()
	local target = s.shortlist[1]
	Pack.pin(s, target.id)
	assert(Pack.take(s, target.id) == target and s.pinned == nil)
end

function T.newSeasonClearsThePin()
	local s = fresh()
	Pack.pin(s, s.shortlist[1].id)
	Pack.newSeason(s)
	assert(s.pinned == nil)
end

return T
```

- [ ] **Step 2: Run the suite, verify `PackTest` fails** ("Pack is not a valid member").

- [ ] **Step 3: Implement** — `src/shared/Pack.luau`

```lua
--!strict
-- The rules of a scout pack, with no server state in them: the three cards of
-- the latest report, the one card the player has pinned to come back to, and
-- the free signing from the match-1 trialist pack. ClubService owns a State
-- and saves it; everything here is pure so it can be tested.

local Squad = require(script.Parent.Squad)

local Pack = {}

export type State = {
	shortlist: { Squad.Prospect },
	pinned: Squad.Prospect?,
	free: boolean, -- one card of this report can be kept for nothing
	revealed: boolean, -- the cards have been turned over once already
}

function Pack.find(state: State, id: number): (Squad.Prospect?, string?)
	for _, p in state.shortlist do
		if p.id == id then
			return p, "shortlist"
		end
	end
	local pinned = state.pinned
	if pinned and pinned.id == id then
		return pinned, "pinned"
	end
	return nil, nil
end

-- One slot: a new pin throws the old one away. The fee travels with the card,
-- so it is the fee he was quoted on the day.
function Pack.pin(state: State, id: number): boolean
	for i, p in state.shortlist do
		if p.id == id then
			table.remove(state.shortlist, i)
			state.pinned = p
			return true
		end
	end
	return false
end

function Pack.unpin(state: State): boolean
	if not state.pinned then
		return false
	end
	state.pinned = nil
	return true
end

function Pack.fee(state: State, prospect: Squad.Prospect): number
	if state.free and state.pinned ~= prospect then
		return 0
	end
	return prospect.fee
end

function Pack.take(state: State, id: number): Squad.Prospect?
	local pinned = state.pinned
	if pinned and pinned.id == id then
		state.pinned = nil
		return pinned
	end
	for i, p in state.shortlist do
		if p.id == id then
			table.remove(state.shortlist, i)
			state.free = false
			return p
		end
	end
	return nil
end

-- A new report replaces the old one; unopened packs do not stack.
function Pack.replace(state: State, shortlist: { Squad.Prospect }, free: boolean)
	state.shortlist = shortlist
	state.free = free
	state.revealed = false
end

function Pack.newSeason(state: State)
	state.pinned = nil -- TEMP: a pin lasts the season
end

return Pack
```

- [ ] **Step 4: Run the suite, verify `PackTest` passes.**

- [ ] **Step 5: Commit**

```bash
git add src/shared/Pack.luau tests/PackTest.luau
git commit -m "Pack: pure pin / free-signing / replace rules"
```

---

### Task 4: ClubService and Session wiring

**Files:**
- Modify: `src/server/ClubService.luau` (state at 28-44, `publishedShortlist` 70-83, `publish` 85-101, `refreshShortlist`/`ageShortlist` 134-160, `restore` 300-337, `serialize` 347-360, `act` 398-400 and 487-526 and 565-603, `newSeason` 674+)
- Modify: `src/server/Session.luau:197-207`
- Test: `tests/ProfileTest.luau` (round-trip of the new save fields)

**Interfaces:**
- Consumes: `Pack.*` (Task 3), `Squad.trialistPack`, `Squad.prospects` level 0 (Task 2).
- Produces, in the published `Club` JSON: `shortlist` (as before), `pinned: Prospect?` (potential hidden the same way), `packRevealed: boolean`, `packFree: boolean`.
- Produces actions on the `ClubAction` remote: `"packRevealed"`, `"pin", id`, `"unpin"`, `"sign", id, releaseId?`.
- Save fields added: `pinned`, `packFree`, `packRevealed`, `trialDone`.

- [ ] **Step 1: Write the failing test.** Add to `tests/ProfileTest.luau`, following the existing round-trip test near line 122 (read it first and reuse its helper for building a profile and calling the encode/decode pair it already uses):

```lua
function T.packFieldsSurviveARoundTrip()
	local pack = Squad.prospects(4, 45, 1)
	local club = {
		shortlist = { pack[1], pack[2] },
		pinned = pack[3],
		packFree = true,
		packRevealed = true,
		trialDone = true,
	}
	local back = roundTrip(club) -- the helper the neighbouring test uses
	assert(back.pinned and back.pinned.id == pack[3].id and back.pinned.fee == pack[3].fee, "pin lost")
	assert(back.packFree == true and back.packRevealed == true and back.trialDone == true, "flags lost")
end
```

If `Profile` whitelists club fields, this fails until Step 2 adds the four fields there; if `Profile` passes the club table through untouched, the test passes immediately and documents the contract — that is fine.

- [ ] **Step 2: State.** In `ClubService.luau` add `local Pack = require(ReplicatedStorage.Shared.Pack)` beside the other requires, and replace `local shortlist: { Squad.Prospect } = {}` (line 28) with:

```lua
-- the latest scout pack, the pinned card and the match-1 free signing (Shared/Pack)
local pack: Pack.State = { shortlist = {}, pinned = nil, free = false, revealed = false }
-- the match-1 trialist pack has been dealt (true for any save older than packs)
local trialDone = false
```

Then rename every remaining `shortlist` read in the file to `pack.shortlist` (publish, restore, serialize, newSeason's `spoken` loop). `Grep` `\bshortlist\b` in the file afterwards: only `pack.shortlist`, `data.shortlist`, the JSON key and `shortlistAge` / `shortlistMatchesLeft` may remain.

- [ ] **Step 3: Publishing.** Replace `publishedShortlist` with a per-card helper and publish the new fields:

```lua
-- X337: a prospect as the player is allowed to see him. The exact ceiling stays
-- here until he signs; the client gets the band his scout will commit to.
local function publishedProspect(p: Squad.Prospect): any
	local copy = table.clone(p) :: any
	local low, high = p.potentialLow, p.potentialHigh
	if type(low) ~= "number" or type(high) ~= "number" then
		low, high = Squad.potentialBand(p.potential, Squad.scoutDoubt(scoutLevel), p.id, p.overall)
	end
	copy.potentialLow, copy.potentialHigh = low, high
	copy.potential = nil
	-- what Sign will actually cost today (0 for the free trialist)
	copy.fee = Pack.fee(pack, p)
	return copy
end

local function publishedShortlist(): { any }
	local out = {}
	for _, p in pack.shortlist do
		table.insert(out, publishedProspect(p))
	end
	return out
end
```

and inside `publish()`'s table add:

```lua
		pinned = if pack.pinned then publishedProspect(pack.pinned) else nil,
		packRevealed = pack.revealed,
		packFree = pack.free,
```

- [ ] **Step 4: Dealing packs.** Replace `refreshShortlist` and `ageShortlist` (134-160):

```lua
local function refreshShortlist()
	-- X214: no prospect shares a name with a current player (or the pin)
	local taken: { [string]: boolean } = {}
	for _, p in players do
		taken[p.name] = true
	end
	if pack.pinned then
		taken[pack.pinned.name] = true
	end
	local seed = rng:NextInteger(1, 1000000)
	if not trialDone then
		-- the pack after match 1: keep one of the three for nothing
		trialDone = true
		Pack.replace(pack, Squad.trialistPack(seed, players, lineup.xi, taken), true)
	else
		Pack.replace(pack, Squad.prospects(seed, Squad.average(players), scoutLevel, taken), false)
	end
	shortlistAge = 0
	-- the folder on the office desk glows until it has been opened
	ClubState.set("ScoutReportNew", #pack.shortlist > 0)
end

-- After every match a new report lands, scout or no scout (Marcel, 2026-09-21).
local function ageShortlist()
	shortlistAge += 1
	if #pack.shortlist == 0 or shortlistAge >= SHORTLIST_MATCHES then
		refreshShortlist()
	end
end
```

The `hireScout` branch (line ~467) already calls `refreshShortlist()`. Guard it so hiring before match 1 cannot burn the trialist pack: change that call to

```lua
		if trialDone then
			refreshShortlist()
		end
```

and make its toast `("%s hired."):format(nextLevel.name)` when no pack was dealt.

- [ ] **Step 5: Save and restore.** In `restore`, after `shortlistAge = ...` (line 301):

```lua
	pack = { shortlist = {}, pinned = nil, free = data.packFree == true, revealed = data.packRevealed == true }
	-- a save from before packs has played its first match already
	trialDone = data.trialDone == true or ((ClubState.get("MatchesPlayed") :: number?) or 0) > 0
```

Pull the body of the `data.shortlist` loop (323-337) into a local `restoredProspect(p): Squad.Prospect?` that returns the repaired copy or nil, use it for the list, and add:

```lua
	if type(data.pinned) == "table" then
		pack.pinned = restoredProspect(data.pinned)
	end
```

In `serialize` replace `shortlist = shortlist,` with:

```lua
		shortlist = pack.shortlist,
		pinned = pack.pinned,
		packFree = pack.free,
		packRevealed = pack.revealed,
		trialDone = trialDone,
```

Also find where a brand-new club is created (the function around line 239 that sets `shortlist = {}`) and reset there: `pack = { shortlist = {}, pinned = nil, free = false, revealed = false }` and `trialDone = false`.

- [ ] **Step 6: Release as a reusable check.** Above `ClubService.act`, lift the validation out of the `release` branch (565-591) unchanged:

```lua
-- Why this player cannot leave right now, or nil. Shared by Release and by
-- signing into a full squad, so the two can never disagree.
local function releaseBlocker(p: Squad.Player): string?
	-- X363: the matchday squad, not Config.SquadMin - see Squad.matchdaySquadSize
	local floor = Squad.matchdaySquadSize()
	if #players <= floor then
		return ("You need %d players for an XI and a full bench"):format(floor)
	end
	if xiSlotOf(p.id) then
		-- X203: with Auto Squad on, swaps are refused, so say how to get there
		return if autoSquad then "Turn Auto Squad off, then take them out of the XI to sell" else "Take them out of the XI first"
	end
	-- X199: never sell the last goalkeeper (trades already require one)
	if p.role == "GK" then
		local keepers = 0
		for _, q in players do
			if q.role == "GK" then
				keepers += 1
			end
		end
		if keepers <= 1 then
			return "Keep at least one goalkeeper"
		end
	end
	return nil
end

local function removePlayer(p: Squad.Player): number
	for i, q in players do
		if q.id == p.id then
			table.remove(players, i)
			break
		end
	end
	local value = Squad.value(p)
	ClubState.addCash(value, "sales") -- X299
	return value
end
```

The `release` branch becomes:

```lua
	elseif name == "release" then
		local pid = tonumber(a)
		local p = if pid then findPlayer(pid) else nil
		if not p then
			return false, "Unknown player"
		end
		local blocked = releaseBlocker(p)
		if blocked then
			return false, blocked
		end
		local value = removePlayer(p)
		recomputeLineup()
		publish()
		return true, ("%s sold for %s"):format(p.name, money(value))
```

Note: with a full squad of 20 the `#players <= floor` check never blocks; the XI check does. With Auto Squad on, the picker (Task 7) only offers players outside the XI, so it still works.

- [ ] **Step 7: Actions.** Replace the `openReport` branch and the whole `sign` branch (487-526):

```lua
	if name == "openReport" then
		ClubState.set("ScoutReportNew", false)
		return true, nil
	elseif name == "packRevealed" then
		if not pack.revealed then
			pack.revealed = true
			publish()
		end
		return true, nil
	elseif name == "pin" then
		local pid = tonumber(a)
		if not pid or not Pack.pin(pack, pid) then
			return false, "That player is no longer available"
		end
		publish()
		return true, ("%s pinned. His fee is held until the season ends."):format((pack.pinned :: Squad.Prospect).name)
	elseif name == "unpin" then
		if Pack.unpin(pack) then
			publish()
		end
		return true, nil
```

```lua
	elseif name == "sign" then
		local pid = tonumber(a)
		local prospect = if pid then Pack.find(pack, pid) else nil
		if not prospect then
			return false, "That player is no longer available"
		end
		-- everything is checked before anything changes, so a failed signing
		-- can never cost the player the man he released to make room
		local leaving: Squad.Player? = nil
		if #players >= Config.SquadMax then
			local rid = tonumber(b)
			leaving = if rid then findPlayer(rid) else nil
			if not leaving then
				return false, ("Squad is full (%d). Release someone first."):format(Config.SquadMax)
			end
			local blocked = releaseBlocker(leaving)
			if blocked then
				return false, blocked
			end
		end
		local fee = Pack.fee(pack, prospect)
		local funds = cash + (if leaving then Squad.value(leaving) else 0)
		if funds < fee then
			return false, ("Need %s more"):format(money(fee - funds))
		end
		if leaving then
			removePlayer(leaving)
		end
		if fee > 0 then
			ClubState.addCash(-fee, "transfers") -- X299
		end
		Pack.take(pack, prospect.id)
		local signed: Squad.Player = {
			id = nextId,
			name = prospect.name,
			number = smallestFreeNumber(),
			role = prospect.role,
			age = prospect.age,
			overall = prospect.overall,
			potential = prospect.potential,
			injured = 0,
			apps = 0,
			goals = 0,
			look = prospect.look, -- X227: keep the face the pack showed
			nation = prospect.nation,
			wonderkid = prospect.wonderkid,
		}
		nextId += 1
		table.insert(players, signed)
		recomputeLineup()
		publish()
		return true, ("%s signed! Shirt number %d."):format(signed.name, signed.number)
```

- [ ] **Step 8: Season end.** In `ClubService.newSeason`, before the `spoken` loop, add `Pack.newSeason(pack)`.

- [ ] **Step 9: Session.** `Session.luau:197-207` becomes:

```lua
	-- the scout's report on the desk: a pack lands after every match, scout or
	-- not, and the folder is lit while the latest one is unopened
	local scoutPrompt = w.model:FindFirstChild("ScoutPrompt", true)
	if scoutPrompt and scoutPrompt:IsA("ProximityPrompt") then
		local played = ((ClubState.get("MatchesPlayed") :: number?) or 0) > 0
		scoutPrompt.Enabled = managing and named and played
		local glow = scoutPrompt.Parent and scoutPrompt.Parent:FindFirstChild("NewGlow")
		if glow and glow:IsA("Highlight") then
			glow.Enabled = scoutPrompt.Enabled and ClubState.get("ScoutReportNew") == true
		end
	end
```

Check that `Session.refreshPromptLock` is also connected to `MatchesPlayed` changes (see line 489 for how `ScoutReportNew` is wired); add the same one-line connection for `"MatchesPlayed"` if it is missing. Also check the folder prop itself is visible before a scout is hired: `Grep` `ScoutReport` in `Session.luau` and `Clubhouse.luau` for a `Transparency` toggle keyed on `ScoutLevel`, and key it on `MatchesPlayed > 0` instead.

- [ ] **Step 10: Run the suite** — all green.

- [ ] **Step 11: Playtest the server flow in Studio.** Start Play, name the club, then from the server via `DebugCommand` (`task.spawn` it — it yields to full time): `("playMatch", 5)`. Afterwards print `game.ReplicatedStorage`'s ClubState `Club` attribute and confirm: `shortlist` has 3 entries, all `fee == 0`, `packFree == true`. Open the Scouting tab, sign one: toast "signed", cash unchanged, the other two now show real fees. Stop Play.

- [ ] **Step 12: Commit**

```bash
git add src/server/ClubService.luau src/server/Session.luau tests/ProfileTest.luau
git commit -m "ClubService: a pack after every match, free trialist, pin, release-and-sign"
```

---

### Task 5: Upload the card art

**Files:**
- Modify: `src/shared/Config.luau` (next to the audio table, ~line 425)

**Interfaces:**
- Produces: `Config.CardArt: { [string]: string }` keyed by the `Config.Rarity` names plus `Back`; `Config.CardAspect = 683 / 1024`; `Config.ProspectKit: Color3`; `Config.PackAudio`.

- [ ] **Step 1:** Load the MCP tools with `ToolSearch` `select:mcp__Roblox_Studio__upload_image,mcp__Roblox_Studio__search_asset`. Upload the seven files in `assets/ui/cards/keyed/` one at a time with `upload_image`. Record each returned asset id.

- [ ] **Step 2:** Find three library sounds with `search_asset` (audio): a paper/card slide, a short card flip/whoosh, and a rising "reveal" sting. Prefer Roblox-uploaded audio (creator "Roblox"), like the entries already in `Config`.

- [ ] **Step 3:** Add to `Config.luau`, with the real ids in place of the zeros:

```lua
-- Player card art, keyed by Config.Rarity name. Sources are in
-- assets/ui/cards/keyed/ (tools/key_cards.py); 683x1024, one shared outline.
Config.CardArt = {
	Bronze = "rbxassetid://0",
	Silver = "rbxassetid://0",
	Gold = "rbxassetid://0",
	Rare = "rbxassetid://0",
	Epic = "rbxassetid://0",
	Legend = "rbxassetid://0",
	Back = "rbxassetid://0",
}
Config.CardAspect = 683 / 1024
-- the glow behind a card as it turns, and the ink that reads on its art
Config.CardTint = {
	Bronze = { glow = Color3.fromRGB(176, 110, 60), ink = Color3.fromRGB(34, 22, 14) },
	Silver = { glow = Color3.fromRGB(200, 208, 220), ink = Color3.fromRGB(24, 28, 36) },
	Gold = { glow = Color3.fromRGB(255, 204, 72), ink = Color3.fromRGB(36, 26, 8) },
	Rare = { glow = Color3.fromRGB(70, 150, 255), ink = Color3.fromRGB(240, 246, 255) },
	Epic = { glow = Color3.fromRGB(176, 90, 255), ink = Color3.fromRGB(248, 240, 255) },
	Legend = { glow = Color3.fromRGB(255, 240, 200), ink = Color3.fromRGB(30, 24, 12) },
}
-- a prospect is nobody's player yet: a plain grey training top on his card
Config.ProspectKit = Color3.fromRGB(120, 126, 136)
Config.PackAudio = {
	slide = "rbxassetid://0",
	flip = "rbxassetid://0",
	sting = "rbxassetid://0", -- pitched up for the better tiers
}
```

- [ ] **Step 4:** Verify in Studio (Edit): `execute_luau` that creates a temporary `ScreenGui` in `StarterGui` with one `ImageLabel` per id, `screen_capture`, confirm all seven render with transparent corners, then destroy the gui.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Config.luau
git commit -m "Config: uploaded card art, tier tints and pack sounds"
```

---

### Task 6: FlagView and PlayerCard

**Files:**
- Create: `src/client/FlagView.luau`
- Create: `src/client/PlayerCard.luau`

**Interfaces:**
- Consumes: `Config.CardArt`, `Config.CardTint`, `Config.CardAspect`, `Config.ProspectKit`, `Config.HomeKit`, `CardStats.of`, `Squad.rarity`, `Format.cardName`, `Nations.get(code).flag`, `Headshot.attach(parent, look, kit, number, { shoulders = true })`, `Crest.draw(parent, name, size)`.
- Produces:
  - `FlagView.draw(parent: GuiObject, flag: Nations.Flag): Frame` — fills `parent`.
  - `PlayerCard.new(parent: Instance, p: any, opts: { signed: boolean?, clubName: string?, faceDown: boolean? }?): Card`
  - `type Card = { frame: Frame, tier: string, faceUp: boolean, flip: (self) -> (), setFace: (self, up: boolean) -> (), destroy: (self) -> () }`
  - `card.frame` has `Size = UDim2.fromScale(1, 1)` and a `UIAspectRatioConstraint`; the caller sizes the **parent**.

- [ ] **Step 1: FlagView** — `src/client/FlagView.luau`

```lua
--!strict
-- Draws a Nations.Flag out of Frames: stripes, then at most one emblem. No
-- images, so eighteen flags cost nothing to load.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nations = require(ReplicatedStorage.Shared.Nations)

local FlagView = {}

local function bar(parent: Instance, color: Color3, pos: UDim2, size: UDim2, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end

function FlagView.draw(parent: GuiObject, flag: Nations.Flag): Frame
	local root = Instance.new("Frame")
	root.Name = "Flag"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = flag.colors[1]
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = parent

	local total = 0
	for i = 1, #flag.colors do
		total += if flag.sizes then flag.sizes[i] else 1
	end
	local at = 0
	for i, color in flag.colors do
		local share = (if flag.sizes then flag.sizes[i] else 1) / total
		local mid = at + share / 2
		if flag.dir == "v" then
			bar(root, color, UDim2.fromScale(mid, 0.5), UDim2.fromScale(share, 1))
		else
			bar(root, color, UDim2.fromScale(0.5, mid), UDim2.fromScale(1, share))
		end
		at += share
	end

	local ink = flag.emblemColor or Color3.new(1, 1, 1)
	local centre = UDim2.fromScale(0.5, 0.5)
	if flag.emblem == "cross" then
		bar(root, ink, centre, UDim2.fromScale(1, 0.2))
		bar(root, ink, centre, UDim2.fromScale(0.13, 1))
	elseif flag.emblem == "saltire" then
		bar(root, ink, centre, UDim2.fromScale(1.4, 0.16), 33)
		bar(root, ink, centre, UDim2.fromScale(1.4, 0.16), -33)
	elseif flag.emblem == "disc" or flag.emblem == "diamond" then
		local d = bar(root, ink, centre, UDim2.fromScale(0.34, 0.34), if flag.emblem == "diamond" then 45 else 0)
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = d
		if flag.emblem == "disc" then
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = d
		end
	elseif flag.emblem == "canton" then
		bar(root, ink, UDim2.fromScale(0.2, 0.25), UDim2.fromScale(0.4, 0.5))
	end
	return root
end

return FlagView
```

- [ ] **Step 2: PlayerCard** — `src/client/PlayerCard.luau`. All positions are in scale units of the 2:3 art, read off `assets/ui/cards/card_filled_reference.png` (overall top-left, role under it, flag, crest, bust right of centre, divider at 57%, name, then two stat columns).

```lua
--!strict
-- One football card: tier art, overall, role, flag, crest, bust, name and the
-- six stats, laid out in scale units so it is the same card at any size. The
-- caller sizes the parent; the card keeps its own 2:3 shape inside it.
--   card:flip()          squash to a line, swap back/face, open again
--   card:setFace(up)     no animation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local CardStats = require(ReplicatedStorage.Shared.CardStats)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Nations = require(ReplicatedStorage.Shared.Nations)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Crest = require(script.Parent.Crest)
local FlagView = require(script.Parent.FlagView)
local Headshot = require(script.Parent.Headshot)
local Theme = require(script.Parent.Theme)

local PlayerCard = {}

export type Options = { signed: boolean?, clubName: string?, faceDown: boolean? }
export type Card = {
	frame: Frame,
	tier: string,
	faceUp: boolean,
	flip: (self: Card) -> (),
	setFace: (self: Card, up: boolean) -> (),
	destroy: (self: Card) -> (),
}

local HALF_FLIP = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local OPEN_FLIP = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- text that scales with the card: TextScaled inside a scale-sized box, one line
local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, ink: Color3, align: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.Font = Theme.fonts.display
	t.TextColor3 = ink
	t.TextScaled = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.Position = pos
	t.Size = size
	t.ZIndex = 4
	t.Parent = parent
	return t
end

function PlayerCard.new(parent: Instance, p: any, opts: Options?): Card
	local signed = opts ~= nil and opts.signed == true
	local tier = Squad.rarity(p.overall)
	local tint = Config.CardTint[tier]
	local ink = tint.ink

	local frame = Instance.new("Frame")
	frame.Name = "PlayerCard"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = Config.CardAspect
	aspect.Parent = frame
	frame.Parent = parent

	local back = Instance.new("ImageLabel")
	back.Name = "Back"
	back.BackgroundTransparency = 1
	back.Image = Config.CardArt.Back
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 2
	back.Parent = frame

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.Image = Config.CardArt[tier]
	face.Size = UDim2.fromScale(1, 1)
	face.ZIndex = 2
	face.Parent = frame

	-- the bust sits behind the text and is clipped to the portrait window
	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.BackgroundTransparency = 1
	portrait.ClipsDescendants = true
	portrait.Position = UDim2.fromScale(0.3, 0.13)
	portrait.Size = UDim2.fromScale(0.62, 0.44)
	portrait.ZIndex = 3
	portrait.Parent = face
	local kit = if signed then Config.HomeKit else Config.ProspectKit
	local shot = Headshot.attach(portrait, p.look or p.id, kit, p.number or 0, { shoulders = true })
	shot.ZIndex = 3
	shot.BackgroundTransparency = 1
	local backdrop = portrait:FindFirstChild("Backdrop")
	if backdrop then
		backdrop:Destroy() -- the card art is the backdrop
	end

	label(face, tostring(p.overall), UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.24, 0.12), ink)
	label(face, p.role, UDim2.fromScale(0.1, 0.24), UDim2.fromScale(0.24, 0.055), ink)
	local flagBox = Instance.new("Frame")
	flagBox.BackgroundTransparency = 1
	flagBox.Position = UDim2.fromScale(0.13, 0.315)
	flagBox.Size = UDim2.fromScale(0.18, 0.07)
	flagBox.ZIndex = 4
	flagBox.Parent = face
	FlagView.draw(flagBox, Nations.get(p.nation).flag).ZIndex = 4
	if signed then
		local crestBox = Instance.new("Frame")
		crestBox.BackgroundTransparency = 1
		crestBox.Position = UDim2.fromScale(0.14, 0.4)
		crestBox.Size = UDim2.fromScale(0.16, 0.11)
		crestBox.ZIndex = 4
		crestBox.Parent = face
		Crest.draw(crestBox, opts and opts.clubName, 40)
	end

	label(face, string.upper(Format.cardName(p.name)), UDim2.fromScale(0.1, 0.585), UDim2.fromScale(0.8, 0.065), ink)
	for i, stat in CardStats.of(p) do
		local column = if i <= 3 then 0.14 else 0.54
		local rowY = 0.675 + ((i - 1) % 3) * 0.058
		label(face, tostring(stat.value), UDim2.fromScale(column, rowY), UDim2.fromScale(0.13, 0.05), ink, Enum.TextXAlignment.Right)
		label(face, stat.label, UDim2.fromScale(column + 0.15, rowY + 0.006), UDim2.fromScale(0.17, 0.04), ink, Enum.TextXAlignment.Left)
	end
	if p.wonderkid then
		-- the shiny: a band of light that keeps sweeping across the face
		local shine = Instance.new("UIGradient")
		shine.Name = "Shine"
		shine.Rotation = 20
		shine.Color = ColorSequence.new(Color3.new(1, 1, 1))
		shine.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.55, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
		shine.Offset = Vector2.new(-1, 0)
		shine.Parent = face
		TweenService:Create(shine, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 1.2), { Offset = Vector2.new(1, 0) }):Play()
	end

	local card = { frame = frame, tier = tier, faceUp = true } :: any

	function card.setFace(self: Card, up: boolean)
		self.faceUp = up
		face.Visible = up
		back.Visible = not up
	end

	-- 2D spin: the back is left-right symmetrical so the swap at zero width
	-- does not jump (docs/CARD_BACKGROUND_PROMPTS.md s7)
	function card.flip(self: Card)
		local full = frame.Size
		local shut = TweenService:Create(frame, HALF_FLIP, { Size = UDim2.new(0, 0, full.Y.Scale, full.Y.Offset) })
		aspect.Parent = nil -- or the constraint fights the squash
		shut:Play()
		shut.Completed:Wait()
		self:setFace(not self.faceUp)
		local open = TweenService:Create(frame, OPEN_FLIP, { Size = full })
		open:Play()
		open.Completed:Wait()
		aspect.Parent = frame
	end

	function card.destroy(self: Card)
		frame:Destroy()
	end

	card:setFace(not (opts ~= nil and opts.faceDown == true))
	return card :: Card
end

return PlayerCard
```

Known trap: with the aspect constraint removed, a `Size` of `fromScale(1, 1)` inside a non-2:3 parent would stretch. `PackOpening` and the lineup strip both give the card a parent that is already 2:3 (they put a `UIAspectRatioConstraint` on the slot), so it does not show. Keep that contract.

- [ ] **Step 3: Look at it.** In Play mode, from the **client** context is not scriptable through MCP (`loadstring` is off and `require` is refused), so add a temporary line at the bottom of `ClubPanel.client.luau`:

```lua
-- TEMP card preview, remove before commit
task.delay(3, function()
	local PlayerCard = require(script.Parent.PlayerCard)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(300, 450)
	holder.Position = UDim2.fromOffset(40, 120)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local c = PlayerCard.new(holder, { id = 1, name = "Kylian Moreau", role = "FWD", overall = 92, look = 4242, nation = "FR", wonderkid = true }, { signed = true, clubName = "Rivermere Town", faceDown = true })
	task.wait(1)
	c:flip()
end)
```

(Check `"FR"` is a real code in `Nations.luau`; use any code that is.) Start Play, `screen_capture`, and compare against `assets/ui/cards/card_filled_reference.png`. Nudge the scale numbers until overall, role, flag, name and both stat columns sit inside their areas on **all six** tier arts (change `overall` to 40, 60, 75, 84, 90, 95 to cycle tiers). Also capture at a phone size (Studio device emulator, a 16:9 phone) with the holder at `fromOffset(140, 210)`: every number must still be legible. Remove the TEMP block.

- [ ] **Step 4: Run the suite** (nothing should have changed; `PerClubModulesTest` lists client modules — if it fails, read its message and add the new modules where it says).

- [ ] **Step 5: Commit**

```bash
git add src/client/FlagView.luau src/client/PlayerCard.luau
git commit -m "PlayerCard: tier art, flag, bust, six stats and a 2D flip"
```

---

### Task 7: PackOpening

**Files:**
- Create: `src/client/PackOpening.luau`
- Modify: `src/client/ClubPanel.client.luau:1151-1156` (Scouting tab), `:1183-1195` (prompt), `renderScouting` (~646-730)

**Interfaces:**
- Consumes: `PlayerCard.new`, `Theme.screenGui/button/text`, `Focus.push/pop`, `Config.PackAudio`, `Config.CardTint`, `Config.Rarity`, the `ClubAction` remote, the `Club` JSON fields from Task 4.
- Produces: `PackOpening.open(getClub: () -> any?, actionEvent: RemoteEvent, opts: { fromDesk: boolean, folder: BasePart? })`, `PackOpening.isOpen(): boolean`, `PackOpening.refresh()` (re-draws the result state after the club JSON changes).

- [ ] **Step 1: Implement** — `src/client/PackOpening.luau`

```lua
--!strict
-- The scout pack, full screen. Presentation only: the three cards were rolled
-- by the server before the folder was touched (CLAUDE.md s22); this turns them
-- over. Anything that goes wrong in the show drops straight to the result
-- state, so the player is never left behind a dark screen.
--   1 camera pushes in on the folder (desk only)   2 three backs slide out
--   3 tap to turn, worst first, best last           4 Sign / Pin / Done

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Focus = require(script.Parent.Focus)
local PlayerCard = require(script.Parent.PlayerCard)
local Theme = require(script.Parent.Theme)

local PackOpening = {}

export type Options = { fromDesk: boolean, folder: BasePart? }

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local getClubNow: (() -> any?)? = nil
local action: RemoteEvent? = nil
local drawResult: (() -> ())? = nil

local TIER_RANK: { [string]: number } = {}
for i, tier in Config.Rarity do
	TIER_RANK[tier.name] = i
end
local BUILD_UP_FROM = TIER_RANK.Rare -- Rare and better get flag -> role -> card

local function sound(id: string, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch or 1
	s.Volume = 0.6
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
end

local function controls(): any
	local module = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	return module and (require(module) :: any):GetControls()
end

function PackOpening.isOpen(): boolean
	return gui ~= nil
end

function PackOpening.refresh()
	if drawResult then
		drawResult()
	end
end

function PackOpening.open(getClub: () -> any?, actionEvent: RemoteEvent, opts: Options)
	local club = getClub()
	if gui or not club or #club.shortlist + (if club.pinned then 1 else 0) == 0 then
		return
	end
	getClubNow, action = getClub, actionEvent
	actionEvent:FireServer("openReport") -- the folder stops glowing

	local screen = Theme.screenGui("PackOpening", 60) -- above the HUD and the club panel
	screen.IgnoreGuiInset = true
	gui = screen
	local ctl = controls()
	if ctl then
		ctl:Disable()
	end

	local camera = workspace.CurrentCamera
	local savedType, savedCFrame = camera.CameraType, camera.CFrame
	local skipped = false

	local shade = Instance.new("TextButton") -- a button so it swallows every tap
	shade.Name = "Shade"
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 9, 16)
	shade.BackgroundTransparency = 1
	shade.Parent = screen

	local function close()
		drawResult = nil
		if ctl then
			ctl:Enable()
		end
		Focus.pop("pack")
		camera.CameraType = savedType
		if opts.fromDesk then
			camera.CFrame = savedCFrame
		end
		screen:Destroy()
		gui = nil
	end

	-- three 2:3 slots in a row; a fourth, smaller, for the pinned card
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.46)
	row.Size = UDim2.fromScale(0.86, 0.62)
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local function slot(order: number, scale: number): Frame
		local s = Instance.new("Frame")
		s.BackgroundTransparency = 1
		s.LayoutOrder = order
		s.Size = UDim2.fromScale(0.28 * scale, scale)
		local shape = Instance.new("UIAspectRatioConstraint")
		shape.AspectRatio = Config.CardAspect
		shape.DominantAxis = Enum.DominantAxis.Height
		shape.Parent = s
		s.Parent = row
		return s
	end

	-- ------------------------------------------------------------ result state
	local function result()
		row:ClearAllChildren()
		layout.Parent = row
		local now = (getClubNow :: () -> any?)()
		if not now then
			return close()
		end
		local cash = PackOpening._cash()
		local function cardWithButtons(p: any, order: number, pinned: boolean)
			local s = slot(order, if pinned then 0.78 else 1)
			PlayerCard.new(s, p)
			local bar = Instance.new("Frame")
			bar.BackgroundTransparency = 1
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.new(0.5, 0, 1, 8)
			bar.Size = UDim2.new(1, 0, 0, 40)
			bar.Parent = s
			local short = p.fee - cash
			local signText = if p.fee == 0 then "KEEP  FREE" elseif short > 0 then ("NEED %s MORE"):format(Format.money(short)) else ("SIGN  %s"):format(Format.money(p.fee))
			local sign = Theme.button(bar, signText, if short > 0 then "ghost" else "primary", { Size = UDim2.new(0.62, -4, 1, 0), TextSize = 15 })
			sign.Activated:Connect(function()
				if short > 0 then
					return
				end
				if #now.players >= Config.SquadMax then
					PackOpening._pickRelease(screen, now, function(releaseId: number)
						(action :: RemoteEvent):FireServer("sign", p.id, releaseId)
					end)
				else
					(action :: RemoteEvent):FireServer("sign", p.id)
				end
			end)
			local pin = Theme.button(bar, if pinned then "UNPIN" else "PIN", if short > 0 and not pinned then "primary" else "ghost", { Size = UDim2.new(0.38, -4, 1, 0), Position = UDim2.new(0.62, 4, 0, 0), TextSize = 15 })
			pin.Activated:Connect(function()
				if pinned then
					(action :: RemoteEvent):FireServer("unpin")
				else
					(action :: RemoteEvent):FireServer("pin", p.id)
				end
			end)
			if pinned then
				Theme.text(s, "PINNED", "label", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(1, 0, 0, 18) })
			end
		end
		for i, p in now.shortlist do
			cardWithButtons(p, i, false)
		end
		if now.pinned then
			cardWithButtons(now.pinned, 10, true)
		end
	end

	local headline = Theme.text(screen, "", "display", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.new(0.9, 0, 0, 40),
		TextSize = 30,
	})
	local done = Theme.button(screen, "DONE", "primary", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.96, 0),
		Size = UDim2.fromOffset(200, 46),
		Visible = false,
	})
	done.Activated:Connect(close)

	local function showResult()
		local now = (getClubNow :: () -> any?)()
		headline.Text = if now and now.packFree then "KEEP ONE TRIALIST FOR FREE" else "SCOUT REPORT"
		done.Visible = true
		drawResult = function()
			local latest = (getClubNow :: () -> any?)()
			headline.Text = if latest and latest.packFree then "KEEP ONE TRIALIST FOR FREE" else "SCOUT REPORT"
			result()
		end
		result()
	end

	-- ---------------------------------------------------------------- the show
	local function show()
		if opts.fromDesk and opts.folder then
			camera.CameraType = Enum.CameraType.Scriptable
			local target = opts.folder.Position
			local goal = CFrame.lookAt(target + Vector3.new(0, 2.2, 0.01) + (savedCFrame.Position - target).Unit * 1.5, target)
			Focus.push("pack", { focusDistance = 2.5, inFocusRadius = 2, farIntensity = 0.7, nearIntensity = 0 })
			TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
			task.wait(0.45)
		else
			Focus.push("pack")
		end
		TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 0.12 }):Play()
		task.wait(0.3)

		-- worst first, best last
		local order = table.clone(club.shortlist)
		table.sort(order, function(a, b)
			return a.overall < b.overall
		end)
		local cards = {}
		for i, p in order do
			local s = slot(i, 1)
			local card = PlayerCard.new(s, p, { faceDown = true })
			-- slide up out of the folder
			card.frame.Position = UDim2.fromScale(0.5, 1.8)
			TweenService:Create(card.frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
			sound(Config.PackAudio.slide, 0.95 + i * 0.05)
			cards[i] = { card = card, slot = s, player = p }
			task.wait(0.14)
		end
		headline.Text = "TAP A CARD"

		local nextUp = 1
		local turning = false
		local function turn(i: number, quick: boolean)
			local entry = cards[i]
			local rank = TIER_RANK[entry.card.tier]
			if rank >= BUILD_UP_FROM and not quick then
				-- flag, then role, then the card
				local glow = Instance.new("UIStroke")
				glow.Color = Config.CardTint[entry.card.tier].glow
				glow.Thickness = 0
				glow.Parent = entry.slot
				TweenService:Create(glow, TweenInfo.new(0.5), { Thickness = 6 }):Play()
				headline.Text = string.upper(require(ReplicatedStorage.Shared.Nations).get(entry.player.nation).name)
				sound(Config.PackAudio.sting, 0.8)
				task.wait(0.7)
				headline.Text = entry.player.role
				task.wait(0.6)
				glow:Destroy()
			end
			sound(Config.PackAudio.flip)
			entry.card:flip()
			sound(Config.PackAudio.sting, 0.9 + rank * 0.08)
			headline.Text = ("%s  %d"):format(string.upper(entry.card.tier), entry.player.overall)
		end
		local function turnNext(quick: boolean)
			if turning or nextUp > #cards then
				return
			end
			turning = true
			turn(nextUp, quick)
			nextUp += 1
			turning = false
		end

		-- tap turns the next card; a double tap (or a second tap mid-turn) skips
		local lastTap = 0
		local conn = shade.Activated:Connect(function()
			local t = os.clock()
			if t - lastTap < 0.3 or turning then
				skipped = true
			end
			lastTap = t
			if not skipped then
				task.spawn(turnNext, false)
			end
		end)
		while nextUp <= #cards and not skipped do
			task.wait(0.05)
		end
		conn:Disconnect()
		while turning do
			task.wait(0.05)
		end
		while nextUp <= #cards do
			turnNext(true)
		end
		task.wait(0.5)
		;(action :: RemoteEvent):FireServer("packRevealed")
	end

	if club.packRevealed or #club.shortlist == 0 then
		Focus.push("pack")
		shade.BackgroundTransparency = 0.12
	else
		local ok, err = pcall(show)
		if not ok then
			warn("[FCT] pack show failed: " .. tostring(err))
			shade.BackgroundTransparency = 0.12
			actionEvent:FireServer("packRevealed")
		end
	end
	showResult()
end

return PackOpening
```

Two helpers referenced above go in the module before `PackOpening.open`:

```lua
-- Cash lives on the ClubState folder as an attribute, like everything ClubPanel reads.
function PackOpening._cash(): number
	local ClubRef = require(script.Parent.ClubRef)
	return (ClubRef.get("Cash") :: number?) or 0
end

-- Squad full: who makes way? Only men outside the XI, cheapest sale first.
function PackOpening._pickRelease(screen: ScreenGui, club: any, onPick: (number) -> ())
	local inXi: { [number]: boolean } = {}
	for _, id in club.lineup.xi do
		inXi[id] = true
	end
	local options = {}
	for _, p in club.players do
		if not inXi[p.id] then
			table.insert(options, p)
		end
	end
	table.sort(options, function(a, b)
		return a.overall < b.overall
	end)
	local panel = Theme.panel(screen, "ReleasePicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 60 + math.min(#options, 6) * 46 + 56),
		ZIndex = 20,
	})
	Theme.text(panel, ("SQUAD FULL (%d). WHO MAKES WAY?"):format(Config.SquadMax), "display", { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 30), TextSize = 20, ZIndex = 21 })
	for i = 1, math.min(#options, 6) do
		local p = options[i]
		local b = Theme.button(panel, ("%s   %s  %d   sells for %s"):format(Format.cardName(p.name), p.role, p.overall, Format.money(Squad.value(p))), "ghost", {
			Position = UDim2.fromOffset(16, 52 + (i - 1) * 46),
			Size = UDim2.new(1, -32, 0, 40),
			TextSize = 15,
			ZIndex = 21,
		})
		b.Activated:Connect(function()
			panel:Destroy()
			onPick(p.id)
		end)
	end
	local cancel = Theme.button(panel, "CANCEL", "ghost", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(140, 36), ZIndex = 21 })
	cancel.Activated:Connect(function()
		panel:Destroy()
	end)
end
```

Before using them, **read** `src/client/ClubRef.luau` and `Theme.luau:180-276` and confirm: how client code reads a ClubState attribute (`ClubPanel` has a local `get(...)`; use the same source), the exact `ButtonVariant` and `TextStyle` names (`"primary"`, `"ghost"`, `"display"`, `"label"`, `"body"` are assumptions — substitute the real ones), and that `Theme.screenGui(name, order)` parents to PlayerGui. `Squad.value` needs `apps`/age fields that exist on published players — they do.

- [ ] **Step 2: Wire the desk prompt.** `ClubPanel.client.luau` — add `local PackOpening = require(script.Parent.PackOpening)` with the other requires, and replace the `ScoutPrompt` branch (1189-1194):

```lua
	elseif prompt.Name == "ScoutPrompt" then
		local folder = prompt.Parent
		PackOpening.open(loadClub, actionEvent, { fromDesk = true, folder = if folder and folder:IsA("BasePart") then folder else nil })
	end
```

- [ ] **Step 3: Wire the menu.** In `render()` remove the `openReport` fire at 1153-1156 (the pack now clears the glow). In `renderScouting`, above the shortlist panel, add a button that is only shown while `club.packRevealed ~= true` and the shortlist is not empty:

```lua
	if not club.packRevealed and #club.shortlist > 0 then
		local open = button(content, "OPEN SCOUT REPORT", Theme.colors.info, { Size = UDim2.fromOffset(260, 44), TextSize = 17 })
		open.LayoutOrder = order
		order += 1
		open.Activated:Connect(function()
			setOpen(false)
			PackOpening.open(loadClub, actionEvent, { fromDesk = false })
		end)
		return -- the three names stay secret until the cards are turned
	end
```

(`button`, `content`, `order` are the existing locals in that file; match how neighbouring rows set `LayoutOrder`.) Below the shortlist rows, add one more row for `club.pinned` using the same row builder, with its action label `UNPIN` firing `actionEvent:FireServer("unpin")`, and title it "PINNED".

- [ ] **Step 4: Refresh on change.** Where `ClubPanel` reacts to the `Club` attribute changing (search `GetAttributeChangedSignal("Club")`), add:

```lua
	if PackOpening.isOpen() then
		PackOpening.refresh()
	end
```

- [ ] **Step 5: Playtest in Studio.** New save → name the club → play match 1 (`DebugCommand` `("playMatch", 5)` via `task.spawn`) → walk to the desk (`character_navigation` or teleport the character to the `ScoutReport` part) → trigger the prompt (`user_keyboard_input` E held). `screen_capture` at: backs out, after the first flip, result state. Check, in order:
  1. movement is locked and the HUD is covered;
  2. three taps turn three cards, best last; a double tap turns the rest;
  3. headline reads "KEEP ONE TRIALIST FOR FREE", all three say "KEEP FREE";
  4. keeping one: toast, the card leaves, the other two show real fees or "NEED £x MORE";
  5. PIN moves a card into the small fourth slot; UNPIN removes it;
  6. DONE restores camera and movement; re-opening goes straight to the result state;
  7. play match 2 → the folder glows again, the pin is still there, the pack is new.
  Force the squad-full path by temporarily setting `Config.SquadMax = 17` in Studio only and signing. Repeat captures 1-3 on the phone emulator.

- [ ] **Step 6: Run the suite**, then **commit**

```bash
git add src/client/PackOpening.luau src/client/ClubPanel.client.luau
git commit -m "Pack opening: fullscreen reveal from the desk folder, Sign / Pin / Done"
```

---

### Task 8: Meet your XI on the first walkout

**Files:**
- Modify: `src/client/Match.client.luau` (around the walkout at lines 78-84)

**Interfaces:**
- Consumes: `PlayerCard.new(parent, p, { signed = true, clubName = ... })`; the `Club` JSON (`players`, `lineup.xi`); ClubState `MatchesPlayed`, `ClubName`.

- [ ] **Step 1:** Read `Match.client.luau:40-125` to find how it reads ClubState attributes and whether it is the owner's own match (the branch at line ~118 handles "watching someone else" — the strip must only run for the owner). Add, called from the owner's walkout branch right after `task.spawn(cameraWalkout, walkout)`:

```lua
-- The very first walkout introduces the eleven as cards (the squad is never
-- "unpacked": the player meets them here, then opens his first pack after the
-- whistle). Presentation only, gone before kick-off.
local function meetTheEleven(seconds: number)
	if ((get("MatchesPlayed") :: number?) or 0) > 0 then
		return
	end
	local ok, club = pcall(function()
		return HttpService:JSONDecode(get("Club") :: string)
	end)
	if not ok or type(club) ~= "table" then
		return
	end
	local byId = {}
	for _, p in club.players do
		byId[p.id] = p
	end
	local screen = Theme.screenGui("MeetTheEleven", 20)
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.fromScale(0.5, 0.97)
	strip.Size = UDim2.fromScale(0.96, 0.26)
	strip.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.006, 0)
	layout.Parent = strip
	for i, id in club.lineup.xi do
		local p = byId[id]
		if p then
			local slot = Instance.new("Frame")
			slot.BackgroundTransparency = 1
			slot.LayoutOrder = i
			slot.Size = UDim2.fromScale(1 / 12, 1)
			local shape = Instance.new("UIAspectRatioConstraint")
			shape.AspectRatio = Config.CardAspect
			shape.Parent = slot
			slot.Parent = strip
			local card = PlayerCard.new(slot, p, { signed = true, clubName = get("ClubName") :: string?, faceDown = true })
			task.delay(0.4 + i * 0.18, function()
				if card.frame.Parent then
					card:flip()
				end
			end)
		end
	end
	task.delay(seconds, function()
		screen:Destroy()
	end)
end
```

Use the file's own attribute reader in place of `get` and add any missing requires (`HttpService`, `Theme`, `PlayerCard`, `Config`). Call it as `task.spawn(meetTheEleven, walkout)`.

- [ ] **Step 2: Playtest.** New save, press Play Match: eleven cards turn over along the bottom during the walkout and are gone at kick-off. Second match: no strip. `screen_capture` on desktop and the phone emulator; on the phone the cards may be too small to read stats — that is acceptable, the overall and name must be legible. If not, drop the strip height to show two rows (6 + 5) by setting `layout.Wraps = true` and the strip to `fromScale(0.7, 0.5)`.

- [ ] **Step 3: Run the suite, commit**

```bash
git add src/client/Match.client.luau
git commit -m "First walkout: meet the eleven as cards"
```

---

### Task 9: Odds table, docs and memory

**Files:**
- Modify: `tests/SquadTest.luau`, `src/shared/Config.luau`, `CLAUDE.md` (s8 Scouting), memory `football-club-tycoon-packs.md`

- [ ] **Step 1: Measure the odds.** Add to `tests/SquadTest.luau`:

```lua
-- Prints the tier odds per scout level at a mid-table squad, for
-- Config.PackOdds (Roblox wants odds published if packs are ever sold).
function T.packOddsAreDocumented()
	for level = 0, #Config.ScoutLevels do
		local counts: { [string]: number } = {}
		local total = 0
		for seed = 1, 1000 do
			for _, p in Squad.prospects(seed, 60, level) do
				local tier = Squad.rarity(p.overall)
				counts[tier] = (counts[tier] or 0) + 1
				total += 1
			end
		end
		local documented = Config.PackOdds[level + 1]
		for tier, n in counts do
			local measured = n / total
			assert(math.abs(measured - (documented[tier] or 0)) < 0.03, ("level %d %s: measured %.3f"):format(level, tier, measured))
		end
	end
end
```

- [ ] **Step 2:** Run it once with `Config.PackOdds = {}` filled with empty tables to read the measured numbers out of the assertion messages (or temporarily `print` them), then write the table into `Config.luau`:

```lua
-- Tier odds per pack card for a squad averaging 60, index = scout level + 1
-- (first row is no scout). Measured by SquadTest.packOddsAreDocumented, which
-- fails if balancing moves them by more than 3 points - update both together.
Config.PackOdds = {
	{ Bronze = 0.00, Silver = 0.00 }, -- fill every row with the measured values
}
```

Every row must hold the real measured numbers before committing; the test enforces it.

- [ ] **Step 3:** Update `CLAUDE.md` s8 "Initial flow" and "Example progression" to match the decided rules: a 3-card pack after every match from match 1, walk-in trialists with no scout, scout level buys quality / reach / accuracy (not list size), one pin slot. Update the memory file `football-club-tycoon-packs.md`: pack GUI landed, the new actions, the `trialDone` flag, and the 2:3-parent contract of `PlayerCard`.

- [ ] **Step 4: Full run-through** (spec build-order step 6): new save → match 1 → free trialist → match 2 pack → pin → hire scout → match 3 pack is visibly better → squad-full sign. Note anything rough in the summary for Marcel.

- [ ] **Step 5: Run the suite, commit**

```bash
git add tests/SquadTest.luau src/shared/Config.luau CLAUDE.md
git commit -m "Pack odds measured and documented; CLAUDE.md s8 matches the pack rules"
```
