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

local Players = game:GetService("Players")

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
-- Roblox yellow first: a crowd that is mostly yellow reads as Roblox people.

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

Townsfolk.SKIN = {
	Color3.fromRGB(245, 205, 48), -- classic Roblox yellow
	Color3.fromRGB(245, 205, 48),
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

local template: Model? = nil
local templateFailed = false

-- The one rig every townsperson is cloned from. Anchored, no Humanoid, no
-- Animate script: these are scenery driven by CFrame, so a state machine and a
-- physics body per NPC would cost a lot and buy nothing.
function Townsfolk.template(): Model?
	if template then
		return template
	end
	if templateFailed then
		return nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		templateFailed = true
		warn("[FCT] Townsfolk: could not build the R6 rig, street life will not spawn: " .. tostring(model))
		return nil
	end
	local m = model :: Model
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Humanoid") or d:IsA("LocalScript") or d:IsA("Script") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	-- HumanoidRootPart only exists to carry the Humanoid, which is gone. Left in
	-- place it never gets posed, so it sits wherever the rig was created and
	-- drags the model's bounding box out to ~19 studs -- which breaks anything
	-- that measures the figure. Removing it also saves a part per townsperson.
	local root = m:FindFirstChild("HumanoidRootPart")
	if root then
		root:Destroy()
	end
	template = m
	return m
end

-- ------------------------------------------------------------------ build

export type Look = {
	skin: Color3?,
	shirt: Color3?, -- e.g. the home kit on matchday
	trousers: Color3?,
	rng: Random?,
}

-- Named limbs, plus `all` for callers that want to sweep every part (fading,
-- Quality toggles, despawn).
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
	local base = Townsfolk.template()
	if not base then
		return nil
	end
	local o: Look = look or {}
	local rng = o.rng
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

function Townsfolk.pose(fig: Figure, base: CFrame, swing: number?)
	local s = swing or 0
	local halfLeg = Townsfolk.LEG_SIZE.Y / 2
	local halfArm = Townsfolk.ARM_SIZE.Y / 2

	fig.torso.CFrame = base * CFrame.new(0, Townsfolk.TORSO_Y, 0)
	fig.head.CFrame = base * CFrame.new(0, Townsfolk.HEAD_Y, 0)
	-- limbs pivot about the hip/shoulder, not their own centres
	fig.legL.CFrame = base * CFrame.new(-Townsfolk.LEG_X, Townsfolk.HIP_Y, 0) * CFrame.Angles(s, 0, 0) * CFrame.new(0, -halfLeg, 0)
	fig.legR.CFrame = base * CFrame.new(Townsfolk.LEG_X, Townsfolk.HIP_Y, 0) * CFrame.Angles(-s, 0, 0) * CFrame.new(0, -halfLeg, 0)
	fig.armL.CFrame = base * CFrame.new(-Townsfolk.ARM_X, Townsfolk.SHOULDER_Y, 0) * CFrame.Angles(-s, 0, 0) * CFrame.new(0, -halfArm, 0)
	fig.armR.CFrame = base * CFrame.new(Townsfolk.ARM_X, Townsfolk.SHOULDER_Y, 0) * CFrame.Angles(s, 0, 0) * CFrame.new(0, -halfArm, 0)
end

-- Seated: thighs forward and horizontal, shins down. `base` sits on the seat
-- surface, looking the way the figure faces.
function Townsfolk.poseSeated(fig: Figure, base: CFrame)
	local halfLeg = Townsfolk.LEG_SIZE.Y / 2
	local halfArm = Townsfolk.ARM_SIZE.Y / 2
	fig.torso.CFrame = base * CFrame.new(0, Townsfolk.TORSO_SIZE.Y / 2, 0)
	fig.head.CFrame = base * CFrame.new(0, Townsfolk.TORSO_SIZE.Y + 0.5, 0)
	-- Rotating -90 about X maps the leg's local +Y onto the figure's forward
	-- (-Z), so the thigh must be pushed along +Y to end up in FRONT of the hip.
	-- Using -Y here sat everyone with their legs out behind them.
	fig.legL.CFrame = base * CFrame.new(-Townsfolk.LEG_X, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, halfLeg, 0)
	fig.legR.CFrame = base * CFrame.new(Townsfolk.LEG_X, 0, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, halfLeg, 0)
	fig.armL.CFrame = base * CFrame.new(-Townsfolk.ARM_X, Townsfolk.TORSO_SIZE.Y - 0.1, 0) * CFrame.new(0, -halfArm, 0)
	fig.armR.CFrame = base * CFrame.new(Townsfolk.ARM_X, Townsfolk.TORSO_SIZE.Y - 0.1, 0) * CFrame.new(0, -halfArm, 0)
end

return Townsfolk
