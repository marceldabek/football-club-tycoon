# Match Visuals: R15 Footballers, Ball, Headshots, Lineup Board, Crowd — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace block footballers with randomized R15 Roblox characters and real animations, make the ball roll and sit at feet, give every player a headshot on a drag-and-drop lineup board, and fix crowd scale and lifetime.

**Architecture:** A per-player `look` seed flows from squad generation through the timeline. A pure shared `Appearance` module turns a seed into a `HumanoidDescription`; the client `Footballer` module builds an R15 rig from it and keeps the same movement interface the presenter already uses. The presenter's ball becomes a rolling/lofted object owned by a holder. The Club Office Squad tab renders headshot cards on a 2D pitch with drag-to-swap over the existing `swap` action.

**Tech Stack:** Roblox Luau (strict), Rojo 7 sync, Studio MCP for playtests, `tests/RunAll.luau` for pure tests.

**Spec:** `docs/superpowers/specs/2026-09-13-match-visuals-r15-and-lineup-design.md`

## Global Constraints

- Simulation layer untouched: `MatchSim`, `Squad.assignScorers`, results and money never change.
- Every new rig part: `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `CastShadow = false`.
- Only Roblox-published catalog assets (hair, faces, accessories, animations). No store models with scripts.
- Rig creation failure must degrade to the block rig with a single `warn`, never an error.
- All tuning numbers are labelled `TEMP` in code.
- Tests run via `loadstring(game.ServerStorage.Tests.RunAll.Source)()()` in Studio Edit mode (Rojo sync first; HTTP sync fallback per `tools/studio-sync.luau` if the plugin is stale).
- Commit after each task.

---

### Task 1: Look seed on every player

**Files:**
- Modify: `src/shared/Squad.luau:14-38` (types), `:72-99` (`makePlayer`), `:202-217` (`matchSquad`)
- Modify: `src/shared/TeamGen.luau:47-58`
- Modify: `src/server/ClubService.luau:194-225` (`restore` backfills missing seeds)
- Test: `tests/SquadTest.luau`, `tests/TeamGenTest.luau`

**Interfaces:**
- Produces: `Player.look: number`, `MatchPlayer.look: number`, `TeamGen.Player.look: number`. `Squad.lookSeedFor(id: number, name: string): number` (stable hash for backfill).

- [ ] **Step 1: Failing tests**

In `tests/SquadTest.luau` add:

```lua
function T.playersCarryLookSeed()
	local a = Squad.generate(7, 45)
	local b = Squad.generate(7, 45)
	for i, p in a do
		assert(type(p.look) == "number" and p.look >= 1, "look seed missing")
		assert(p.look == b[i].look, "look seed not deterministic")
	end
	assert(a[1].look ~= a[2].look, "players share a look seed")
	local ms = Squad.matchSquad(a, Squad.autoLineup(a))
	assert(ms[1].look == Squad.byId(a)[ms[1].id].look, "matchSquad drops look")
	assert(Squad.lookSeedFor(3, "Bob") == Squad.lookSeedFor(3, "Bob"), "hash unstable")
	assert(Squad.lookSeedFor(3, "Bob") ~= Squad.lookSeedFor(4, "Bob"), "hash ignores id")
end
```

In `tests/TeamGenTest.luau` add:

```lua
function T.awayPlayersCarryLookSeed()
	local s = TeamGen.generate(11)
	assert(type(s[1].look) == "number", "away look missing")
	assert(s[1].look == TeamGen.generate(11)[1].look, "away look not deterministic")
end
```

- [ ] **Step 2: Run tests, expect the two new ones to FAIL** (`look` nil).

- [ ] **Step 3: Implement**

`Squad.luau`: add `look: number` to `Player` and `MatchPlayer`; in `makePlayer` add `look = rng:NextInteger(1, 2^30)` to the returned table; in `matchSquad` copy `look = p.look`. Add:

```lua
-- Stable seed for players saved before looks existed.
function Squad.lookSeedFor(id: number, name: string): number
	local h = 2166136261
	for i = 1, #name do
		h = (bit32.bxor(h, name:byte(i)) * 16777619) % 2 ^ 31
	end
	return (h + id * 7919) % 2 ^ 30 + 1
end
```

`TeamGen.luau`: add `look: number` to its `Player` type and `look = rng:NextInteger(1, 2^30)` to both inserts (after names are generated so name RNG order is unchanged).

`ClubService.restore`: after cloning players, `if type(p.look) ~= "number" then p.look = Squad.lookSeedFor(p.id, p.name) end`. `validPlayer` must not require `look`.

- [ ] **Step 4: Run tests, all pass.** Note `SquadTest.generateShape` only checks listed fields, so it still passes.

- [ ] **Step 5: Commit** `feat: per-player look seed`

---

### Task 2: Shared Appearance module

**Files:**
- Create: `src/shared/Appearance.luau`
- Test: `tests/AppearanceTest.luau`

**Interfaces:**
- Produces:
  - `Appearance.fromSeed(seed: number): Look` where `Look = { skin: Color3, heightScale: number, widthScale: number, depthScale: number, headScale: number, hair: number, face: number, beard: number, headband: number, boots: Color3 }`
  - `Appearance.toDescription(look: Look): HumanoidDescription`
  - `Appearance.applyKit(model: Model, look: Look, shirt: Color3, shorts: Color3, socks: Color3)` colours R15 parts.
  - `Appearance.HAIR`, `Appearance.FACES`, `Appearance.BEARDS`, `Appearance.HEADBANDS` (arrays of catalog ids).

- [ ] **Step 1: Failing test** `tests/AppearanceTest.luau`

```lua
local Appearance = require(game.ReplicatedStorage.Shared.Appearance)
local T = {}
local function inList(list, v) if v == 0 then return true end for _, x in list do if x == v then return true end end return false end
function T.deterministicAndInRange()
	for seed = 1, 200 do
		local a, b = Appearance.fromSeed(seed), Appearance.fromSeed(seed)
		assert(a.hair == b.hair and a.face == b.face and a.heightScale == b.heightScale, "not deterministic")
		assert(a.heightScale >= 0.92 and a.heightScale <= 1.08, "height out of range")
		assert(a.widthScale >= 0.9 and a.widthScale <= 1.1, "width out of range")
		assert(inList(Appearance.HAIR, a.hair) and inList(Appearance.FACES, a.face), "unknown id")
		assert(inList(Appearance.BEARDS, a.beard) and inList(Appearance.HEADBANDS, a.headband), "unknown accessory")
	end
end
function T.seedsVary()
	local hairs = {}
	for seed = 1, 60 do hairs[Appearance.fromSeed(seed).hair] = true end
	local n = 0 for _ in hairs do n += 1 end
	assert(n >= 4, "too little hair variety")
end
function T.descriptionCarriesLook()
	local look = Appearance.fromSeed(5)
	local d = Appearance.toDescription(look)
	assert(d.HeightScale == look.heightScale, "scale not applied")
	assert(d.HeadColor == look.skin, "skin not applied")
end
return T
```

- [ ] **Step 2: Run, expect FAIL (module missing).**

- [ ] **Step 3: Implement** `src/shared/Appearance.luau`

```lua
--!strict
-- Turns a player's look seed into a deterministic appearance and a
-- HumanoidDescription. Pure apart from creating the description instance.
-- Only Roblox-published catalog items: free and loadable from any experience.
local Appearance = {}
export type Look = { skin: Color3, heightScale: number, widthScale: number, depthScale: number, headScale: number,
	hair: number, face: number, beard: number, headband: number, boots: Color3 }

local SKIN = { Color3.fromRGB(255, 220, 185), Color3.fromRGB(240, 200, 165), Color3.fromRGB(225, 180, 140),
	Color3.fromRGB(200, 150, 110), Color3.fromRGB(165, 115, 80), Color3.fromRGB(130, 85, 55),
	Color3.fromRGB(95, 60, 40), Color3.fromRGB(70, 45, 30) }
-- TEMP curated catalog ids; verified with MarketplaceService:GetProductInfo in Studio (Task 3 step 1).
Appearance.HAIR = { --[[ filled in Task 3 after verification ]] }
Appearance.FACES = { }
Appearance.BEARDS = { }
Appearance.HEADBANDS = { }
local BOOTS = { Color3.fromRGB(20, 20, 20), Color3.fromRGB(240, 240, 240), Color3.fromRGB(255, 90, 30),
	Color3.fromRGB(40, 200, 120), Color3.fromRGB(60, 120, 255), Color3.fromRGB(255, 220, 40) }

local function pick<T>(rng: Random, list: { T }): T return list[rng:NextInteger(1, #list)] end
local function maybe(rng: Random, list: { number }, chance: number): number
	if #list == 0 or rng:NextNumber() > chance then return 0 end
	return pick(rng, list)
end

function Appearance.fromSeed(seed: number): Look
	local rng = Random.new(seed)
	return {
		skin = pick(rng, SKIN),
		heightScale = rng:NextNumber(0.92, 1.08),
		widthScale = rng:NextNumber(0.9, 1.1),
		depthScale = rng:NextNumber(0.95, 1.05),
		headScale = rng:NextNumber(0.95, 1.05),
		hair = maybe(rng, Appearance.HAIR, 0.9),
		face = if #Appearance.FACES > 0 then pick(rng, Appearance.FACES) else 0,
		beard = maybe(rng, Appearance.BEARDS, 0.2),
		headband = maybe(rng, Appearance.HEADBANDS, 0.1),
		boots = pick(rng, BOOTS),
	}
end

function Appearance.toDescription(look: Look): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor =
		look.skin, look.skin, look.skin, look.skin, look.skin, look.skin
	d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = look.heightScale, look.widthScale, look.depthScale, look.headScale
	d.HairAccessory = if look.hair ~= 0 then tostring(look.hair) else ""
	d.Face = look.face
	local face = {}
	if look.beard ~= 0 then table.insert(face, tostring(look.beard)) end
	d.FaceAccessory = table.concat(face, ",")
	d.HatAccessory = if look.headband ~= 0 then tostring(look.headband) else ""
	return d
end

local SHIRT = { "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }
local SHORTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }
local SOCKS = { "LeftLowerLeg", "RightLowerLeg" }
local FEET = { "LeftFoot", "RightFoot" }
local function paint(model: Model, names: { string }, color: Color3)
	for _, n in names do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then p.Color = color end
	end
end
function Appearance.applyKit(model: Model, look: Look, shirt: Color3, shorts: Color3, socks: Color3)
	paint(model, SHIRT, shirt); paint(model, SHORTS, shorts); paint(model, SOCKS, socks); paint(model, FEET, look.boots)
end
return Appearance
```

- [ ] **Step 4: Run tests: `seedsVary` still fails until Task 3 fills HAIR.** Acceptable for this commit only if Task 3 follows immediately; otherwise fill `HAIR` with placeholders `{1,2,3,4}` is NOT allowed. Do Task 3 step 1 first if unsure.

- [ ] **Step 5: Commit** `feat: Appearance module`

---

### Task 3: Verify catalog ids and fill the tables

**Files:**
- Modify: `src/shared/Appearance.luau` (id tables)

- [ ] **Step 1: In Studio (any mode), run through MCP `execute_luau`:**

```lua
local M = game:GetService("MarketplaceService")
local candidates = {
	hair = { 13745548, 14815761, 16630147, 376524487, 62234425, 15469587, 23759854, 30331986, 63690008, 20573073 },
	face = { 8329679, 10907541, 7074729, 20418658, 21635565, 15432080 },
	beard = { 13744850, 19399908 },
	headband = { 62236223, 1029025 },
}
local out = {}
for kind, ids in candidates do
	for _, id in ids do
		local ok, info = pcall(M.GetProductInfo, M, id)
		table.insert(out, ("%s %d %s %s"):format(kind, id, ok and tostring(info.Name) or "ERR", ok and tostring(info.Creator and info.Creator.Name) or ""))
	end
end
return table.concat(out, "\n")
```

Keep only ids whose creator is `Roblox` and whose `AssetTypeId` matches (Hair 41, Face 18, FaceAccessory 42, Hat 8). Replace any that fail using `search_asset` scope `creator_store` with facets from the spec, or catalog knowledge, until each table has: HAIR >= 8, FACES >= 5, BEARDS >= 2, HEADBANDS >= 2.

- [ ] **Step 2: Build one rig from a description with each accessory on the Server DataModel and confirm the accessory appears (`model:FindFirstChildOfClass("Accessory")`).**

- [ ] **Step 3: Write the verified ids into the four tables with a comment naming each asset.**

- [ ] **Step 4: Run tests: AppearanceTest passes fully.**

- [ ] **Step 5: Commit** `feat: verified catalog looks`

---

### Task 4: R15 Footballer with animations and block fallback

**Files:**
- Rename: `src/client/Footballer.luau` -> `src/client/BlockFootballer.luau` (unchanged content, module name comment updated)
- Create: `src/client/Footballer.luau`
- Modify: `src/client/MatchPresenter.luau:143` (pass `look`), `:520` (subs), timeline type gains `look`.

**Interfaces:**
- Consumes: `Appearance.fromSeed/toDescription/applyKit`, timeline squads with `look`.
- Produces: `Footballer.new(parent, kit: Color3, number, name, position, look: number, isKeeper: boolean)` plus the same methods/fields as `BlockFootballer`. Extra: `Footballer.ready(self): boolean`.

- [ ] **Step 1: Studio probe** on the Client DataModel (Play mode) confirming: animation ids `507766388` idle, `507777826` walk, `507767714` run, `507770677` cheer, `507771019` dance, `507770453` point all load (`track.Length > 0`).

- [ ] **Step 2: Implement** `src/client/Footballer.luau`. Structure:

```lua
--!strict
-- R15 footballer built from a HumanoidDescription. Same interface as
-- BlockFootballer (the fallback when rig creation fails).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Appearance = require(ReplicatedStorage.Shared.Appearance)
local BlockFootballer = require(script.Parent.BlockFootballer)

local ANIM = { idle = 507766388, walk = 507777826, run = 507767714 }
local CELEBRATE = { 507770677, 507771019, 507770453 } -- cheer, dance, point
local WALK_MAX = 15 -- TEMP: above this the run track plays
local POSE_LENGTH = { kick = 0.4, celebrate = 2.5, dive = 1.3 }
```

`Footballer.new`: create the object with the same fields as `BlockFootballer` plus `model = nil, root = nil, hipHeight = 2.8, tracks = {}, motors = {}, rigReady = false, fallback = nil`. Then `task.spawn` a builder:

```lua
local ok, err = pcall(function()
	local desc = Appearance.toDescription(look)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	local animate = model:FindFirstChild("Animate"); if animate then animate:Destroy() end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false end
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.EvaluateStateMachine = false
	local shorts = kit:Lerp(Color3.new(0, 0, 0), 0.55)
	Appearance.applyKit(model, look, kit, if isKeeper then Color3.new(0.1, 0.1, 0.1) else shorts, kit)
	-- number faces + name tag (copy helpers from BlockFootballer, on UpperTorso / Head)
	local root = model:WaitForChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	self.hipHeight = hum.HipHeight + root.Size.Y / 2
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for name, id in ANIM do local a = Instance.new("Animation"); a.AnimationId = "rbxassetid://" .. id; self.tracks[name] = animator:LoadAnimation(a) end
	self.motors.hip = model.RightUpperLeg:FindFirstChild("RightHip")
	self.motors.shoulderL = model.LeftUpperArm:FindFirstChild("LeftShoulder")
	self.motors.shoulderR = model.RightUpperArm:FindFirstChild("RightShoulder")
	model.Name = ("%d %s"):format(number, name)
	model.Parent = parent
	self.model, self.root, self.rigReady = model, root, true
	self.tracks.idle:Play()
end)
if not ok then
	if not warned then warned = true; warn("[FCT] rig build failed, using block rigs: " .. tostring(err)) end
	self.fallback = BlockFootballer.new(parent, kit, number, name, self.position)
end
```

`update(dt)`: if `self.fallback` then mirror `target/speed/busy` into it and call its update, return. Run the same velocity/position/yaw code as `BlockFootballer.update`. Then if `rigReady`: `root.CFrame = CFrame.new(position + (0, hipHeight, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, lift, 0)`; pick the track by speed (`idle` < 1.5, `walk` <= WALK_MAX, else `run`), play it with `0.2` fade if not already playing and stop the others, `AdjustSpeed(speedNow / (track == run and 16 or 8))`. Pose timers as in the block module.

Procedural layer: one module-level `RunService.Stepped` connection iterating a weak set of live footballers: kick writes `motors.hip.Transform = CFrame.Angles(-1.4 * sin(k * pi), 0, 0)`; dive writes both shoulders `CFrame.Angles(-pi/2, 0, 0)` and `tilt = diveDir * 1.35 * k`, `lift = -1.6 * k`; celebrate plays a random `CELEBRATE` track once (loaded lazily, cached on the object).

`face`, `kick`, `celebrate`, `dive`, `teleport`, `setTarget`, `setTagVisible`, `destroy` mirror the block module (forwarding to `fallback` when set). `destroy` disconnects nothing per object; the module-level Stepped loop skips destroyed ones.

- [ ] **Step 3: Presenter wiring.** `Presenter.new`: `Footballer.new(folder, kit, p.number, p.name, Pitch.TUNNEL, p.look or idx, idx == 1)`; same in `applySubs`. Timeline `Player` type gains `look: number?`.

- [ ] **Step 4: Studio test.** Sync, Play, run a 40 s match via `DebugCommand:Invoke("playMatch", 40)`. Check: no console errors, 22 R15 figures walk out, run with animation, one celebrates on a goal, keeper dives. `screen_capture` a stand-side view.

- [ ] **Step 5: Fallback test.** In the Client DataModel run `Players.CreateHumanoidModelFromDescription = nil`-style override is impossible; instead temporarily set `ANIM`? No: pass an invalid look (`hair = 1`) via a one-off `Appearance.HAIR = {1}` in the client VM, start a match, confirm the warn and block rigs. Restore.

- [ ] **Step 6: Commit** `feat: R15 footballers with Roblox animations`

---

### Task 5: Ball and passing rework

**Files:**
- Modify: `src/client/MatchPresenter.luau` (`makeBall`, `step`, `pass`, `fillerPass`, `playSequence`, holder handling)

**Interfaces:**
- Produces: internal only. `Flight` gains `kind: "ground" | "air"`, `spin: CFrame`.

- [ ] **Step 1: Ball part.** Size `0.9`, rest height `SURFACE_Y + 0.45`, add a black pentagon look with `Material = SmoothPlastic` and a `Decal`-free two-tone: keep white. Constants: `BALL_R = 0.45`, `GROUND_PASS_MAX = 45`, `TOUCH_AHEAD = 1.1`, `DRIBBLE_KNOCK = 3.5`, `DRIBBLE_PERIOD = 0.6`, `FIRST_TOUCH = 0.15` (all TEMP).

- [ ] **Step 2: Flight model.** In `pass(...)`, decide `kind`: `air` if `dist > GROUND_PASS_MAX` or `arcOverride`, else `ground`. Ground: `dur = clamp(dist / 55, 0.35, 1.4)`, position `from:Lerp(to, 1 - (1 - a)^2)` (ease-out), Y fixed at rest height. Air: existing arc. Rolling: each frame `moved = newPos - oldPos`; if `moved.Magnitude > 0`, `axis = Vector3.yAxis:Cross(moved.Unit)`, `ball.CFrame = CFrame.fromAxisAngle(axis, moved.Magnitude / BALL_R) * ball.CFrame.Rotation + newPos` (rotation only; keep position separate).

- [ ] **Step 3: At feet and dribble.** When `holder` set and not in flight: base position `fb.position + forward * TOUCH_AHEAD + right * 0.35`. For outfield holders the presenter keeps `dribbleT += dt`; every `DRIBBLE_PERIOD` the ball starts a tiny ground flight `DRIBBLE_KNOCK` studs ahead (no `onArrive`, holder unchanged) so it alternates at-feet/just-ahead. Keeper holds it in hand height (`+2.2` Y).

- [ ] **Step 4: First touch.** In `pass.onArrive`: `task.delay(FIRST_TOUCH, ...)` before assigning the holder; during that window the ball sits still at the landing spot.

- [ ] **Step 5: Build-up filler.** Replace `fillerPass`:

```lua
function Presenter.fillerPass(self)
	local holder = self.holder
	if not holder then self.holder = { team = "Home", idx = 7 }; return end
	local team = self.teams[holder.team]
	local from = team.players[holder.idx]
	local dir = attackDir(self:geom(holder.team))
	if math.random() < 0.15 then -- long switch to the far side
		local far = {} for idx = 6, 11 do if idx ~= holder.idx then table.insert(far, idx) end end
		table.sort(far, function(a, b) return (team.players[a].position.X - from.position.X) ^ 2 > (team.players[b].position.X - from.position.X) ^ 2 end)
		self:pass(holder.team, far[1], 6); return
	end
	local cands = {}
	for idx = 2, 11 do
		if idx ~= holder.idx then
			local p = team.players[idx]
			local d = (p.position - from.position).Magnitude
			local forward = (p.position.Z - from.position.Z) * dir
			table.insert(cands, { idx = idx, score = d - math.max(forward, 0) * 0.6 })
		end
	end
	table.sort(cands, function(a, b) return a.score < b.score end)
	local to = cands[math.random(1, math.min(3, #cands))].idx
	if math.random() < 0.2 then -- intercepted by the nearest opponent to the pass line
		local oppTeam = other(holder.team)
		local mid = (from.position + team.players[to].position) / 2
		local best, bestD = 7, math.huge
		for idx = 2, 11 do
			local d = (self.teams[oppTeam].players[idx].position - mid).Magnitude
			if d < bestD then best, bestD = idx, d end
		end
		self:pass(oppTeam, best); return
	end
	self:pass(holder.team, to)
end
```

`pass` must accept a receiver on the other team as today (it does).

- [ ] **Step 6: Sequences.** `playSequence` unchanged except shots use `kind = "air"` and the shooter's drive uses the dribble knock.

- [ ] **Step 7: Studio test:** 60 s match; ball rolls on short passes, lofts on switches and shots, sits at feet, first touch visible. No errors. Capture a screenshot at pitch level.

- [ ] **Step 8: Commit** `feat: rolling ball, dribbling, build-up passing`

---

### Task 6: Crowd scale and clearing

**Files:**
- Modify: `src/server/WorldBuilder.luau:714-766`
- Modify: `src/server/MatchService.luau:207` (after `Phase = Manage`)

- [ ] **Step 1: Sizes.** `FAN_SPACING = 2.6`; body `Vector3.new(1.8, bodyH, 1.4)` with `bodyH = 2.6 + jitter`; head `1.2` at `top + 0.9 + bodyH + 0.6`. Check the head does not clip the row above (`stepHeight` 1.5 on level 1: head top at `+0.9+2.6+1.2 = 4.7` > 1.5 step, so rows overlap visually as real stands do; shift each row's fan `x` by `-0.6` so heads sit in front of the next step). Verify with a screenshot.

- [ ] **Step 2: Clear at full time.** In `MatchService` right after `ClubState.set("Phase", "Manage")`: `WorldBuilder.clearCrowd()`; add `function WorldBuilder.clearCrowd()` that empties `Club.Stand.Crowd` and sets `CrowdCount = 0`.

- [ ] **Step 3: Studio test.** Play a 30 s match, screenshot the stand next to the player's character, confirm fans are about seated-person size and disappear at full time.

- [ ] **Step 4: Commit** `fix: crowd at character scale, cleared after full time`

---

### Task 7: Headshot module

**Files:**
- Create: `src/client/Headshot.luau`

**Interfaces:**
- Produces: `Headshot.attach(parent: GuiObject, look: number, kit: Color3): ViewportFrame` (fills parent; shows shirt-coloured placeholder until ready). `Headshot.preload(looks: { number })`.

- [ ] **Step 1: Implement**

```lua
--!strict
-- Face-only ViewportFrame for a look seed. Rigs are built once per seed and
-- their head (with hair, face, beard, headband) cached for the session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Headshot = {}
local cache: { [number]: Model } = {}
local pending: { [number]: boolean } = {}

local function buildHead(look: number): Model?
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, Appearance.toDescription(Appearance.fromSeed(look)), Enum.HumanoidRigType.R15)
	if not ok then return nil end
	local head = model:FindFirstChild("Head") :: BasePart
	local bust = Instance.new("Model")
	head.Parent = bust
	for _, acc in model:GetChildren() do
		if acc:IsA("Accessory") then acc.Parent = bust end -- welds to Head survive the move
	end
	bust.PrimaryPart = head
	model:Destroy()
	return bust
end

function Headshot.attach(parent: GuiObject, look: number, kit: Color3): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.fromScale(1, 1); vf.BackgroundColor3 = kit; vf.BackgroundTransparency = 0.35
	vf.Ambient = Color3.fromRGB(180, 180, 190); vf.LightColor = Color3.new(1, 1, 1)
	vf.Parent = parent
	task.spawn(function()
		while pending[look] do task.wait(0.1) end
		if not cache[look] then pending[look] = true; cache[look] = buildHead(look); pending[look] = nil end
		local src = cache[look]; if not src or not vf.Parent then return end
		local bust = src:Clone(); bust.Parent = vf
		local head = bust.PrimaryPart :: BasePart
		bust:PivotTo(CFrame.new(0, 0, 0))
		local cam = Instance.new("Camera"); cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(Vector3.new(0.15, 0.35, 3.2), Vector3.new(0, 0.05, 0))
		cam.Parent = vf; vf.CurrentCamera = cam
	end)
	return vf
end
return Headshot
```

- [ ] **Step 2: Studio test.** In the Client VM: attach one headshot to a temporary `ScreenGui` frame and screenshot; confirm face and hair visible; destroy.

- [ ] **Step 3: Commit** `feat: headshot viewport`

---

### Task 8: Lineup board with drag-and-drop

**Files:**
- Create: `src/client/LineupBoard.luau`
- Modify: `src/client/ClubPanel.client.luau:297-355` (`renderSquad` uses the board for XI and bench; reserves stay as rows)

**Interfaces:**
- Consumes: `Headshot.attach`, `actionEvent:FireServer("swap", idA, idB)`, `Pitch.formationSlots`.
- Produces: `LineupBoard.render(parent: GuiObject, club: Club, kit: Color3, canDrag: boolean, onSwap: (number, number) -> ()): Frame` (height 340 px; parent is the panel's content list).

- [ ] **Step 1: Implement.** Board: a `Frame` 100% wide, 340 px tall, `Theme.colors.bg2`, containing a pitch `Frame` (green `Color3.fromRGB(46, 120, 60)`, 60% width, centre, with halfway line and centre circle drawn by two thin frames plus a `UIStroke` circle) and a bench strip (right 36%). Slot positions: for slot `i`, `FORMATION` mapping `x -> 0.5 + x * 0.42`, `depth -> 0.92 - depth * 0.84` (own goal at bottom). Cards 64x84 px: `Headshot` top (64x56), number+surname line, OVR badge; red dot when `injured > 0`. Bench cards laid out in a `UIGridLayout` 64x84.

Drag: on `InputBegan` (MouseButton1 or Touch) of a card when `canDrag`: create a ghost clone in the top-level `ScreenGui`, follow `InputChanged` positions, on `InputEnded` hit-test against all cards (`AbsolutePosition/AbsoluteSize`), call `onSwap(dragId, targetId)` if over a different card, destroy the ghost. Also keep tap-to-select: a tap without movement (< 6 px) selects, second tap swaps (existing behaviour).

- [ ] **Step 2: Wire in `renderSquad`.** After the head row: `LineupBoard.render(content, club, Config.HomeKit colour, canManage() and not club.autoSquad, function(a, b) actionEvent:FireServer("swap", a, b) end)`. Remove the `STARTING XI` and `BENCH` row sections; keep `RESERVES` rows (they can be dragged only if also rendered as cards, so render reserves as a third card strip below the board instead of rows, with the Release button kept as a small "x" on the card when `canRelease`).

- [ ] **Step 3: Studio test.** Open the office panel, Squad tab: cards with faces on a pitch; Auto Squad off; drag a bench card onto a starter; server toast and re-render show the swap. Try on touch emulation (Studio device emulator) once.

- [ ] **Step 4: Commit** `feat: lineup board with headshots and drag-to-swap`

---

### Task 9: Docs, memory and final check

- [ ] **Step 1:** README: note the R15 rigs, catalog id tables in `Appearance.luau`, block fallback, headshot cache.
- [ ] **Step 2:** Run the full test suite; run one full 90 s match in Studio; console clean.
- [ ] **Step 3:** Update the milestone memory file with what was decided (rig source, ids, drag UI).
- [ ] **Step 4:** Commit `docs: match visuals`.

## Self-review

- Spec coverage: Part A = Tasks 1 to 4; Part B = Task 5; Part C = Task 6; Part D = Tasks 7 and 8; testing = each task's Studio step plus pure tests in 1 to 3.
- Placeholders: Task 2's id tables are intentionally empty until Task 3 verifies ids in Studio; Task 3 must run before the Task 2 commit is considered complete.
- Types: `look: number` everywhere; `Footballer.new` signature used identically in Task 4 and the presenter wiring.
