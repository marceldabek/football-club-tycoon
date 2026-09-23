--!strict
-- X371: ONE townsperson, and it is a real Roblox character.
--
-- Every bit of street life used to build its own figure out of Parts --
-- Pedestrians, Strollers, BenchSitters, CafeSitters, StallHolders, YardWorkers,
-- PlayAreaLife, MatchdayLife and TrainingLife each had their own proportions,
-- colours and part counts -- so the town read as a different game in every
-- district, and none of them looked like a Roblox player.
--
-- No primitives. `Players:CreateHumanoidModelFromDescription` returns the
-- genuine R6 avatar: Head, Torso, Left/Right Arm, Left/Right Leg, at the
-- standard 5.00 studs. That is Roblox's own model, so there is no third-party
-- asset to vet, nothing to moderate, and townspeople stand exactly as tall as
-- the player.
--
-- It is built ONCE and cloned. Creating a rig per NPC would hit the avatar
-- pipeline hundreds of times; cloning an anchored, Humanoid-free copy costs
-- about as much as the old block figures did.
--
-- #6c/#9/#35 (2026-09-23): this is the ONE avatar pipeline for every crowd,
-- fan and pedestrian NPC -- stand fans (StandCrowd), walking fans and
-- stewards (MatchdayLife), pedestrians, strollers and the sitters all come
-- from here. A small pool of variant rigs is built in the background from
-- HumanoidDescriptions with the same Roblox-made hair and faces as the
-- footballers (Shared.Appearance), so townspeople are no longer identical
-- yellow "noobs". Hair is welded to the anchored head, so every poser that
-- moves the head (BulkMoveTo or CFrame) carries it along. Also here: the
-- walk cycle (limbCFrames' swing), a cheap idle animator for people who
-- stand still (Townsfolk.idle), and the seated pose for the stands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Appearance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Appearance"))

local Townsfolk = {}

-- ---------------------------------------------------------------- metrics
-- Real R6 numbers, read off the model rather than guessed, so callers that
-- animate limbs and the rig itself cannot drift apart.

Townsfolk.HEIGHT = 5.0

Townsfolk.LEG_SIZE = Vector3.new(1, 2, 1)
Townsfolk.TORSO_SIZE = Vector3.new(2, 2, 1)
Townsfolk.ARM_SIZE = Vector3.new(1, 2, 1)

Townsfolk.HIP_Y = 2 -- top of the legs / bottom of the torso
Townsfolk.TORSO_Y = 3 -- torso centre
Townsfolk.SHOULDER_Y = 4 -- top of the torso
Townsfolk.HEAD_Y = 4.5 -- head centre
Townsfolk.ARM_X = 1.5 -- torso half-width + arm half-width
Townsfolk.LEG_X = 0.5

-- ---------------------------------------------------------------- palettes

Townsfolk.SHIRTS = {
	Color3.fromRGB(164, 219, 166), -- the mint of the classic avatar
	Color3.fromRGB(196, 74, 74),
	Color3.fromRGB(72, 110, 178),
	Color3.fromRGB(238, 238, 238),
	Color3.fromRGB(96, 100, 110),
	Color3.fromRGB(226, 176, 72),
	Color3.fromRGB(122, 160, 96),
	Color3.fromRGB(150, 96, 150),
}

Townsfolk.TROUSERS = {
	Color3.fromRGB(38, 46, 62), -- the navy of the classic avatar
	Color3.fromRGB(38, 46, 62),
	Color3.fromRGB(58, 58, 64),
	Color3.fromRGB(84, 72, 60),
	Color3.fromRGB(46, 62, 84),
	Color3.fromRGB(120, 116, 108),
}

-- #35: no classic Roblox yellow any more; it read as the default "noob" rig
-- next to the footballers' real skin tones.
Townsfolk.SKIN = {
	Color3.fromRGB(240, 200, 165),
	Color3.fromRGB(225, 180, 140),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(205, 148, 108),
	Color3.fromRGB(150, 103, 70),
	Color3.fromRGB(104, 72, 50),
}

function Townsfolk.pick<T>(list: { T }, rng: Random?): T
	local n = if rng then rng:NextInteger(1, #list) else math.random(1, #list)
	return list[n]
end

-- ---------------------------------------------------------------- template

-- TEMP: how many different rigs (hair x face) the town is cloned from. Each
-- one is a single CreateHumanoidModelFromDescription call at start-up; the
-- per-NPC cost is the same clone either way.
Townsfolk.VARIANTS = 12
Townsfolk.HAIR_CHANCE = 0.8 -- TEMP: the rest are bald or close-cropped

local template: Model? = nil
local templateFailed = false
local variants: { Model } = {}
local prewarming = false

-- Strips a freshly built R6 avatar down to scenery: anchored, no Humanoid, no
-- Animate script, no physics. Hair (and any other accessory) is put on the
-- head by its attachments -- a torn-down rig never solves the accessory weld
-- -- and welded to it unanchored, so moving the anchored head carries it.
local function strip(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Humanoid") or d:IsA("LocalScript") or d:IsA("Script") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local head = m:FindFirstChild("Head") :: BasePart?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	for _, acc in ipairs(m:GetChildren()) do
		if not acc:IsA("Accessory") then
			continue
		end
		local handle = acc:FindFirstChild("Handle")
		local att = handle and handle:FindFirstChildOfClass("Attachment")
		local onHead = att and head and head:FindFirstChild(att.Name)
		if not (handle and handle:IsA("BasePart") and att and onHead and onHead:IsA("Attachment") and head) then
			acc:Destroy() -- #9a: nothing that does not sit on the head
			continue
		end
		for _, j in ipairs(handle:GetChildren()) do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
				j:Destroy()
			end
		end
		handle.Anchored = false
		handle.CastShadow = false
		-- A Weld, not a WeldConstraint: callers pose a figure before parenting
		-- it into the workspace, and a WeldConstraint freezes whatever offset
		-- the parts have when it wakes up, which left the hair behind in the
		-- sky. A Weld's C0 puts it back on the head whenever it activates.
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = handle
		weld.C0 = onHead.CFrame
		weld.C1 = att.CFrame
		weld.Parent = handle
	end
	-- HumanoidRootPart only exists to carry the Humanoid, which is gone. Left in
	-- place it never gets posed, so it sits wherever the rig was created and
	-- drags the model's bounding box out to ~19 studs -- which breaks anything
	-- that measures the figure. Removing it also saves a part per townsperson.
	local root = m:FindFirstChild("HumanoidRootPart")
	if root then
		root:Destroy()
	end
end

local function fromDescription(desc: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		return nil
	end
	strip(model :: Model)
	return model :: Model
end

-- The plain rig (no hair, default face), built on first use. Everyone falls
-- back to it until the variants are ready.
function Townsfolk.template(): Model?
	if template then
		return template
	end
	if templateFailed then
		return nil
	end
	local m = fromDescription(Instance.new("HumanoidDescription"))
	if not m then
		templateFailed = true
		warn("[FCT] Townsfolk: could not build the R6 rig, street life will not spawn")
		return nil
	end
	template = m
	return m
end

-- Builds the variant pool (idempotent), all variants at once in parallel.
-- Called on first build; the avatar service yields while it loads hair and
-- faces, so the first build waits for the pool (at most VARIANT_WAIT) rather
-- than spawning bald default rigs that would stay on screen all session.
local VARIANT_WAIT = 8 -- TEMP seconds; after this, build with what is ready
local pending = 0
local prewarmStarted = 0

function Townsfolk.prewarm()
	if prewarming then
		return
	end
	prewarming = true
	prewarmStarted = os.clock()
	local rng = Random.new(20260923)
	for i = 1, Townsfolk.VARIANTS do
		local desc = Instance.new("HumanoidDescription")
		if #Appearance.HAIR > 0 and rng:NextNumber() < Townsfolk.HAIR_CHANCE then
			desc.HairAccessory = tostring(Appearance.HAIR[(i - 1) % #Appearance.HAIR + 1])
		end
		if #Appearance.FACES > 0 then
			desc.Face = Appearance.FACES[rng:NextInteger(1, #Appearance.FACES)]
		end
		pending += 1
		task.spawn(function()
			local m = fromDescription(desc)
			if m then
				table.insert(variants, m)
			end
			pending -= 1
		end)
	end
end

local function waitForVariants()
	Townsfolk.prewarm()
	while pending > 0 and os.clock() - prewarmStarted < VARIANT_WAIT do
		task.wait(0.1)
	end
end

-- How many variant rigs are ready (for probes and tests).
function Townsfolk.variantCount(): number
	return #variants
end

-- ------------------------------------------------------------------ build

export type Look = {
	skin: Color3?,
	shirt: Color3?, -- e.g. the home kit on matchday
	trousers: Color3?,
	rng: Random?,
}

-- Named limbs, plus `all` for callers that want to sweep every part (fading,
-- Quality toggles, despawn). `all` is the six limbs only; the hair is welded
-- to the head and follows it.
export type Figure = {
	model: Model,
	torso: BasePart,
	head: BasePart,
	legL: BasePart,
	legR: BasePart,
	armL: BasePart,
	armR: BasePart,
	all: { BasePart },
}

-- Returns nil when the rig could not be built; callers must skip spawning
-- rather than falling back to blocks.
function Townsfolk.build(parent: Instance, look: Look?): Figure?
	waitForVariants()
	local o: Look = look or {}
	local rng = o.rng
	local base: Model? = if #variants > 0 then Townsfolk.pick(variants, rng) else Townsfolk.template()
	if not base then
		return nil
	end
	local skin = o.skin or Townsfolk.pick(Townsfolk.SKIN, rng)
	local shirt = o.shirt or Townsfolk.pick(Townsfolk.SHIRTS, rng)
	local trousers = o.trousers or Townsfolk.pick(Townsfolk.TROUSERS, rng)

	local m = base:Clone()
	local torso = m:FindFirstChild("Torso") :: BasePart
	local head = m:FindFirstChild("Head") :: BasePart
	local armL = m:FindFirstChild("Left Arm") :: BasePart
	local armR = m:FindFirstChild("Right Arm") :: BasePart
	local legL = m:FindFirstChild("Left Leg") :: BasePart
	local legR = m:FindFirstChild("Right Leg") :: BasePart
	if not (torso and head and armL and armR and legL and legR) then
		m:Destroy()
		return nil
	end

	torso.Color = shirt
	head.Color = skin
	armL.Color = skin -- short sleeves, like the classic avatar
	armR.Color = skin
	legL.Color = trousers
	legR.Color = trousers

	local all: { BasePart } = { torso, head, legL, legR, armL, armR }
	m.Parent = parent

	return {
		model = m,
		torso = torso,
		head = head,
		legL = legL,
		legR = legR,
		armL = armL,
		armR = armR,
		all = all,
	}
end

-- --------------------------------------------------------------------- pose
-- `base.Position` is between the feet on the ground, and `base` looks the way
-- the figure faces. `swing` in radians drives the walk cycle; 0 is at rest.

-- `armRatio` scales the arm swing against the leg swing; Pedestrians walked with
-- arms at 0.7 of the leg amplitude, which reads better than a full-amplitude
-- march, so callers can keep their own feel rather than all moving identically.
--
-- `scale` must match whatever was passed to `fig.model:ScaleTo`. ScaleTo shrinks
-- the PARTS but not these offsets, so a 0.6-scale child posed at scale 1 hangs
-- in the air with its feet off the ground. Children in the play area and youth
-- players at the academy are both scaled, so this is not a corner case.
--
-- Returns the six limb CFrames in `fig.all` order, so a caller moving many
-- figures can batch them into one workspace:BulkMoveTo instead of writing 6
-- properties each (matchday runs up to 48 fans a plot).
function Townsfolk.limbCFrames(fig: Figure, base: CFrame, swing: number?, armRatio: number?, scale: number?): { CFrame }
	local s = swing or 0
	local a = s * (armRatio or 1)
	local k = scale or 1
	local halfLeg = Townsfolk.LEG_SIZE.Y / 2 * k
	local halfArm = Townsfolk.ARM_SIZE.Y / 2 * k

	return {
		base * CFrame.new(0, Townsfolk.TORSO_Y * k, 0), -- torso
		base * CFrame.new(0, Townsfolk.HEAD_Y * k, 0), -- head
		-- limbs pivot about the hip/shoulder, not their own centres
		base * CFrame.new(-Townsfolk.LEG_X * k, Townsfolk.HIP_Y * k, 0) * CFrame.Angles(s, 0, 0) * CFrame.new(0, -halfLeg, 0),
		base * CFrame.new(Townsfolk.LEG_X * k, Townsfolk.HIP_Y * k, 0) * CFrame.Angles(-s, 0, 0) * CFrame.new(0, -halfLeg, 0),
		base * CFrame.new(-Townsfolk.ARM_X * k, Townsfolk.SHOULDER_Y * k, 0) * CFrame.Angles(-a, 0, 0) * CFrame.new(0, -halfArm, 0),
		base * CFrame.new(Townsfolk.ARM_X * k, Townsfolk.SHOULDER_Y * k, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -halfArm, 0),
	}
end

function Townsfolk.pose(fig: Figure, base: CFrame, swing: number?, armRatio: number?, scale: number?)
	local cfs = Townsfolk.limbCFrames(fig, base, swing, armRatio, scale)
	fig.torso.CFrame = cfs[1]
	fig.head.CFrame = cfs[2]
	fig.legL.CFrame = cfs[3]
	fig.legR.CFrame = cfs[4]
	fig.armL.CFrame = cfs[5]
	fig.armR.CFrame = cfs[6]
end

-- Batched form: appends this figure's parts and their CFrames to the caller's
-- arrays, for one workspace:BulkMoveTo per frame across every figure.
function Townsfolk.appendPose(fig: Figure, base: CFrame, swing: number?, armRatio: number?, scale: number?,
	parts: { BasePart }, cframes: { CFrame })
	local cfs = Townsfolk.limbCFrames(fig, base, swing, armRatio, scale)
	for i = 1, 6 do
		table.insert(parts, fig.all[i])
		table.insert(cframes, cfs[i])
	end
end

-- Seated: thighs forward and horizontal, shins down. `base` sits on the seat
-- surface, looking the way the figure faces.
-- `scale` must match fig.model:ScaleTo, for the same reason as in pose.
function Townsfolk.poseSeated(fig: Figure, base: CFrame, scale: number?)
	local k = scale or 1
	local halfLeg = Townsfolk.LEG_SIZE.Y / 2 * k
	local halfArm = Townsfolk.ARM_SIZE.Y / 2 * k
	fig.torso.CFrame = base * CFrame.new(0, Townsfolk.TORSO_SIZE.Y / 2 * k, 0)
	fig.head.CFrame = base * CFrame.new(0, (Townsfolk.TORSO_SIZE.Y + 0.5) * k, 0)
	-- Rotating -90 about X maps the leg's local +Y onto the figure's forward
	-- (-Z), so the thigh must be pushed along +Y to end up in FRONT of the hip.
	-- Using -Y here sat everyone with their legs out behind them.
	fig.legL.CFrame = base * CFrame.new(-Townsfolk.LEG_X * k, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, halfLeg, 0)
	fig.legR.CFrame = base * CFrame.new(Townsfolk.LEG_X * k, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, halfLeg, 0)
	fig.armL.CFrame = base * CFrame.new(-Townsfolk.ARM_X * k, (Townsfolk.TORSO_SIZE.Y - 0.1) * k, 0) * CFrame.new(0, -halfArm, 0)
	fig.armR.CFrame = base * CFrame.new(Townsfolk.ARM_X * k, (Townsfolk.TORSO_SIZE.Y - 0.1) * k, 0) * CFrame.new(0, -halfArm, 0)
end

-- #6: a fan in a stand seat. `base` is the hips on the cushion, looking the way
-- the fan faces; `drop` is how far below the hips the step is, so the legs
-- angle down and forward until the feet reach it (an R6 leg has no knee).
-- Hands rest on the thighs. Returns the six CFrames in `fig.all` order, for
-- BulkMoveTo (a full ground is a few hundred fans).
function Townsfolk.seatedCFrames(base: CFrame, drop: number): { CFrame }
	local halfLeg = Townsfolk.LEG_SIZE.Y / 2
	local halfArm = Townsfolk.ARM_SIZE.Y / 2
	local down = math.asin(math.clamp(drop / Townsfolk.LEG_SIZE.Y, 0, 0.95))
	-- a turn of -(90 + down) degrees about X takes the leg's +Y to forward and down
	local leg = CFrame.Angles(-(math.pi / 2 + down), 0, 0) * CFrame.new(0, halfLeg, 0)
	local arm = CFrame.Angles(0.45, 0, 0) * CFrame.new(0, -halfArm, 0)
	local shoulder = Townsfolk.TORSO_SIZE.Y - 0.1
	return {
		base * CFrame.new(0, Townsfolk.TORSO_SIZE.Y / 2, 0),
		base * CFrame.new(0, Townsfolk.TORSO_SIZE.Y + 0.5, 0),
		base * CFrame.new(-Townsfolk.LEG_X, 0, 0) * leg,
		base * CFrame.new(Townsfolk.LEG_X, 0, 0) * leg,
		base * CFrame.new(-Townsfolk.ARM_X, shoulder, 0) * arm,
		base * CFrame.new(Townsfolk.ARM_X, shoulder, 0) * arm,
	}
end

-- --------------------------------------------------------------------- idle
-- #9b: people who stand still (stewards, queues, the concourse, the bar) used
-- to be posed once and frozen. Townsfolk.idle poses them and hands them to one
-- shared animator: a slow look round, a little weight shift and arm sway.
-- Cheap on purpose: IDLE_HZ updates a second, only within IDLE_RADIUS of the
-- camera, one BulkMoveTo for everybody. A figure drops out on its own once its
-- model is destroyed or unparented.

local IDLE_HZ = 12
local IDLE_RADIUS = 140 -- TEMP: beyond this nobody can see the sway
local IDLE_MAX = 60 -- TEMP: per-tick cap, nearest first is not worth sorting for

type Idler = { fig: Figure, base: CFrame, scale: number, phase: number }
local idlers: { Idler } = {}
local idleConn: RBXScriptConnection? = nil
local idleClock = 0

function Townsfolk.idleCFrames(fig: Figure, base: CFrame, t: number, scale: number?): { CFrame }
	local k = scale or 1
	local halfArm = Townsfolk.ARM_SIZE.Y / 2 * k
	local sway = math.sin(t * 0.9) * 0.05
	local turn = math.sin(t * 0.37) * 0.35 * math.max(0, math.sin(t * 0.21)) -- looks round now and then
	local shift = base * CFrame.Angles(0, 0, math.sin(t * 0.55) * 0.025) -- weight from foot to foot
	local cfs = Townsfolk.limbCFrames(fig, base, 0, nil, scale)
	cfs[1] = shift * CFrame.new(0, Townsfolk.TORSO_Y * k, 0)
	cfs[2] = shift * CFrame.new(0, Townsfolk.HEAD_Y * k, 0) * CFrame.Angles(0, turn, 0)
	cfs[5] = shift * CFrame.new(-Townsfolk.ARM_X * k, Townsfolk.SHOULDER_Y * k, 0) * CFrame.Angles(sway, 0, 0.04) * CFrame.new(0, -halfArm, 0)
	cfs[6] = shift * CFrame.new(Townsfolk.ARM_X * k, Townsfolk.SHOULDER_Y * k, 0) * CFrame.Angles(-sway, 0, -0.04) * CFrame.new(0, -halfArm, 0)
	return cfs
end

local function idleStep(dt: number)
	idleClock += dt
	if idleClock < 1 / IDLE_HZ then
		return
	end
	local now = os.clock()
	idleClock = 0
	local camera = workspace.CurrentCamera
	local cam = if camera then camera.CFrame.Position else Vector3.zero
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local shown = 0
	for i = #idlers, 1, -1 do
		local it = idlers[i]
		if it.fig.model.Parent == nil then
			table.remove(idlers, i)
			continue
		end
		if shown >= IDLE_MAX or (it.base.Position - cam).Magnitude > IDLE_RADIUS then
			continue
		end
		shown += 1
		local cfs = Townsfolk.idleCFrames(it.fig, it.base, now + it.phase, it.scale)
		for j = 1, 6 do
			table.insert(parts, it.fig.all[j])
			table.insert(cframes, cfs[j])
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if #idlers == 0 and idleConn then
		idleConn:Disconnect()
		idleConn = nil
	end
end

-- Poses `fig` standing at `base` (as Townsfolk.pose) and keeps it idling.
function Townsfolk.idle(fig: Figure, base: CFrame, scale: number?)
	Townsfolk.pose(fig, base, 0, nil, scale)
	table.insert(idlers, { fig = fig, base = base, scale = scale or 1, phase = math.random() * 100 })
	if not idleConn then
		idleConn = RunService.Heartbeat:Connect(idleStep)
	end
end

return Townsfolk
