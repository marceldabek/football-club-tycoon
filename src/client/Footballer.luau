--!strict
-- An R15 footballer built on the client from a HumanoidDescription (see
-- Appearance.luau), driven kinematically: only the HumanoidRootPart is anchored
-- and every other part hangs off it through Motor6Ds, so writing one CFrame per
-- frame moves the whole rig. Roblox-owned idle / walk / run / celebrate tracks
-- play through an Animator; kick and dive are procedural joint overrides.
--
-- Public interface matches BlockFootballer, which is the fallback when the rig
-- cannot be built (no network, description fetch failure).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local BlockFootballer = require(script.Parent.BlockFootballer)
local ClubRef = require(script.Parent.ClubRef)

local Footballer = {}
Footballer.__index = Footballer

export type Pose = "idle" | "kick" | "celebrate" | "dive" | "sit"

export type Footballer = typeof(setmetatable(
	{} :: {
		model: Model?,
		root: BasePart?,
		head: BasePart?,
		hipHeight: number,
		tracks: { [string]: AnimationTrack },
		current: string?,
		celebrateTrack: AnimationTrack?,
		joints: { [string]: Motor6D },
		rigReady: boolean,
		dead: boolean,
		fallback: BlockFootballer.BlockFootballer?,
		parent: Instance,
		kit: Color3,
		isKeeper: boolean,
		lookSeed: number,
		position: Vector3,
		yaw: number,
		target: Vector3?,
		speed: number,
		velocity: Vector3,
		moving: boolean,
		pose: Pose,
		poseT: number,
		diveDir: number,
		busy: boolean,
		jitter: Vector3,
		number: number,
		name: string,
		tagVisible: boolean,
	},
	Footballer
))

-- Roblox-owned animation assets (playable from any experience).
local ANIM = { idle = 507766388, walk = 507777826, run = 507767714, sit = 2506281703 }
local CELEBRATE = { 507770677, 507771019, 507770453 } -- cheer, dance, point
-- TEMP tuning
local WALK_MAX = 15 -- studs/s; faster than this plays the run track
local WALK_ANIM_SPEED = 8 -- studs/s at which the walk track plays at 1x
local RUN_ANIM_SPEED = 16 -- studs/s at which the run track plays at 1x
-- `sit` never expires on its own: a substitute stays on the bench until they
-- are brought on.
local POSE_LENGTH: { [Pose]: number } = { idle = 0, kick = 0.4, celebrate = 2.5, dive = 1.3, sit = math.huge }
-- Hip height while sitting, measured from the footballer's position. Shared
-- with the dugout geometry so a substitute neither floats above the bench nor
-- sinks through it.
local SIT_HIP = Pitch.BENCH_HIP_Y
local KEEPER_SHORTS = Color3.fromRGB(25, 25, 25)

local warnedFallback = false
-- every live footballer, for the shared procedural-pose step
local live: { [Footballer]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function numberFace(torso: BasePart, face: Enum.NormalId, number: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = torso
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = tostring(number)
	label.Parent = gui
end

local function nameTag(head: BasePart, number: number, name: string): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 22)
	billboard.Name = "NameTag"
	billboard.StudsOffset = Vector3.new(0, 1.9, 0)
	billboard.MaxDistance = 60
	billboard.AlwaysOnTop = false
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ("%d %s"):format(number, name)
	label.Parent = billboard
	return billboard
end

-- New rigs come with AnimationConstraint joints (physics driven). Swap each for
-- an equivalent Motor6D so the rig follows its anchored root kinematically and
-- the Animator still drives it. Returns the joints by name.
local function toMotor6D(model: Model): { [string]: Motor6D }
	local joints: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent then
				local motor = Instance.new("Motor6D")
				motor.Name = d.Name
				motor.Part0 = a0.Parent :: BasePart
				motor.Part1 = a1.Parent :: BasePart
				motor.C0 = a0.CFrame
				motor.C1 = a1.CFrame
				motor.Parent = a1.Parent
				joints[d.Name] = motor
			end
			d:Destroy()
		elseif d:IsA("Motor6D") then
			joints[d.Name] = d
		elseif d:IsA("BallSocketConstraint") or d:IsA("NoCollisionConstraint") then
			d:Destroy()
		end
	end
	return joints
end

local function buildRig(self: Footballer)
	local look = Appearance.fromSeed(self.lookSeed)
	local desc = Appearance.toDescription(look)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	desc:Destroy()
	if self.dead then
		model:Destroy()
		return
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.EvaluateStateMachine = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local shorts = if self.isKeeper then KEEPER_SHORTS else self.kit:Lerp(Color3.new(0, 0, 0), 0.55)
	Appearance.applyKit(model, look, self.kit, shorts, self.kit)

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	local joints = toMotor6D(model)
	root.Anchored = true
	numberFace(torso, Enum.NormalId.Back, self.number)
	numberFace(torso, Enum.NormalId.Front, self.number)
	local tag = nameTag(head, self.number, self.name)
	tag.Enabled = self.tagVisible

	-- the model must be in the DataModel before tracks load, or they play at zero weight
	model.Name = ("%d %s"):format(self.number, self.name)
	model.Parent = self.parent
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for name, id in ANIM do
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. id
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Core
		track.Looped = true
		self.tracks[name] = track
	end

	self.model = model
	self.root = root
	self.head = head
	self.joints = joints
	self.hipHeight = hum.HipHeight + root.Size.Y / 2
	self.rigReady = true
	self:update(0)
end

function Footballer.new(parent: Instance, kit: Color3, number: number, name: string, position: Vector3, look: number?, isKeeper: boolean?): Footballer
	local self = setmetatable({
		model = nil,
		root = nil,
		head = nil,
		hipHeight = 3.2,
		tracks = {},
		current = nil,
		celebrateTrack = nil,
		joints = {},
		rigReady = false,
		dead = false,
		fallback = nil,
		parent = parent,
		kit = kit,
		isKeeper = isKeeper == true,
		lookSeed = look or number,
		position = position,
		yaw = 0,
		target = nil,
		speed = 22,
		velocity = Vector3.zero,
		moving = false,
		pose = "idle" :: Pose,
		poseT = 0,
		diveDir = 1,
		busy = false,
		jitter = Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4),
		number = number,
		name = name,
		tagVisible = true,
	}, Footballer) :: any

	live[self] = true
	task.spawn(function()
		local ok, err = pcall(buildRig, self)
		if not ok and not self.dead then
			if not warnedFallback then
				warnedFallback = true
				warn("[FCT] R15 rig build failed, using block rigs: " .. tostring(err))
			end
			local block = BlockFootballer.new(parent, kit, number, name, self.position)
			block:setTagVisible(self.tagVisible)
			self.fallback = block
		end
	end)
	return self
end

function Footballer.setTarget(self: Footballer, target: Vector3?)
	self.target = target
end

function Footballer.teleport(self: Footballer, position: Vector3)
	self.position = position
	self.target = nil
	self.velocity = Vector3.zero
	if self.fallback then
		self.fallback:teleport(position)
	end
	self:update(0)
end

function Footballer.setTagVisible(self: Footballer, visible: boolean)
	self.tagVisible = visible
	local head = self.head
	local tag = head and head:FindFirstChild("NameTag")
	if tag then
		(tag :: BillboardGui).Enabled = visible
	end
	if self.fallback then
		self.fallback:setTagVisible(visible)
	end
end

function Footballer.face(self: Footballer, point: Vector3)
	local d = point - self.position
	if d.X ~= 0 or d.Z ~= 0 then
		self.yaw = math.atan2(-d.X, -d.Z)
	end
	if self.fallback then
		self.fallback:face(point)
	end
end

local function setPose(self: Footballer, pose: Pose)
	self.pose = pose
	self.poseT = 0
end

function Footballer.kick(self: Footballer)
	setPose(self, "kick")
	if self.fallback then
		self.fallback:kick()
	end
end

function Footballer.celebrate(self: Footballer)
	setPose(self, "celebrate")
	if self.fallback then
		self.fallback:celebrate()
		return
	end
	local model = self.model
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. CELEBRATE[math.random(1, #CELEBRATE)]
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if ok then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.1)
		self.celebrateTrack = track
	end
end

-- Substitutes wait on the bench rather than standing in the tunnel. Sitting
-- holds until stand() is called, which is what a substitution looks like.
function Footballer.sit(self: Footballer)
	self.target = nil
	self.velocity = Vector3.zero
	setPose(self, "sit")
	if self.fallback then
		self.fallback:sit()
	end
end

function Footballer.stand(self: Footballer)
	if self.pose == "sit" then
		setPose(self, "idle")
	end
	if self.fallback then
		self.fallback:stand()
	end
end

-- dir: -1 dives to the player's left, 1 to the right.
function Footballer.dive(self: Footballer, dir: number)
	self.diveDir = dir >= 0 and 1 or -1
	setPose(self, "dive")
	if self.fallback then
		self.fallback:dive(dir)
	end
end

local function playTrack(self: Footballer, name: string, speed: number)
	local track = self.tracks[name]
	if not track then
		return
	end
	if self.current ~= name then
		for other, t in self.tracks do
			if other ~= name and t.IsPlaying then
				t:Stop(0.2)
			end
		end
		track:Play(0.2)
		self.current = name
	end
	track:AdjustSpeed(speed)
end

-- Advances movement and pose timers, then writes the root CFrame and picks
-- the locomotion track.
function Footballer.update(self: Footballer, dt: number)
	local fallback = self.fallback
	if fallback then
		fallback.target = self.target
		fallback.speed = self.speed
		fallback.busy = self.busy
		fallback.jitter = self.jitter
		fallback:update(dt)
		self.position = fallback.position
		self.yaw = fallback.yaw
		self.velocity = fallback.velocity
		self.moving = fallback.moving
		self.pose = fallback.pose -- the block rig owns the pose timer in this mode
		return
	end

	local target = self.target
	local desired = Vector3.zero
	if target then
		local delta = Vector3.new(target.X - self.position.X, 0, target.Z - self.position.Z)
		local dist = delta.Magnitude
		if dist > 0.3 then
			desired = delta.Unit * math.min(self.speed, dist * 2.2)
		end
	end
	self.velocity = self.velocity:Lerp(desired, math.min(dt * 7, 1))
	local speedNow = self.velocity.Magnitude
	if speedNow > 0.4 then
		local step = self.velocity * dt
		if target and step.Magnitude > (target - self.position).Magnitude then
			self.position = Vector3.new(target.X, self.position.Y, target.Z)
		else
			self.position += step
		end
		-- X238: a diving keeper keeps facing the shooter while he shuffles across
		if self.pose ~= "dive" then
			self.yaw = math.atan2(-self.velocity.X, -self.velocity.Z)
		end
	end
	self.moving = speedNow > 1.5

	if self.pose ~= "idle" then
		self.poseT += dt
		if self.poseT >= POSE_LENGTH[self.pose] then
			self.pose = "idle"
			local track = self.celebrateTrack
			if track then
				track:Stop(0.2)
				self.celebrateTrack = nil
			end
		end
	end

	if not self.rigReady then
		return
	end
	local root = self.root :: BasePart

	local tilt, lift = 0, 0
	if self.pose == "dive" then
		local k = math.min(self.poseT / 0.25, 1)
		-- X238: a positive roll about the look axis leans the body to its own
		-- left (UpVector goes to -X), so a dive to the right rolls negative
		tilt = -self.diveDir * 1.35 * k
		lift = -1.6 * k
	elseif self.pose == "sit" then
		lift = SIT_HIP - self.hipHeight
	end
	root.CFrame = ClubRef.presentFrame() * CFrame.new(self.position + Vector3.new(0, self.hipHeight + lift, 0))
		* CFrame.Angles(0, self.yaw, 0)
		* CFrame.Angles(0, 0, tilt)

	if self.pose == "sit" then
		playTrack(self, "sit", 1)
	elseif self.pose == "celebrate" or self.pose == "dive" then
		playTrack(self, "idle", 1)
	elseif speedNow < 1.5 then
		playTrack(self, "idle", 1)
	elseif speedNow <= WALK_MAX then
		playTrack(self, "walk", math.max(speedNow / WALK_ANIM_SPEED, 0.5))
	else
		playTrack(self, "run", math.max(speedNow / RUN_ANIM_SPEED, 0.6))
	end
end

-- Procedural overrides written after the Animator each frame: kick swings the
-- right leg, dive throws both arms up.
RunService.Stepped:Connect(function()
	for fb in live do
		if not fb.rigReady or fb.dead then
			continue
		end
		if fb.pose == "kick" then
			local hip = fb.joints.RightHip
			if hip then
				local k = math.min(fb.poseT / POSE_LENGTH.kick, 1)
				hip.Transform = CFrame.Angles(-1.5 * math.sin(k * math.pi), 0, 0)
			end
		elseif fb.pose == "dive" then
			local k = math.min(fb.poseT / 0.25, 1)
			for _, name in { "LeftShoulder", "RightShoulder" } do
				local shoulder = fb.joints[name]
				if shoulder then
					shoulder.Transform = CFrame.Angles(-2.6 * k, 0, 0)
				end
			end
		end
	end
end)

function Footballer.destroy(self: Footballer)
	self.dead = true
	live[self] = nil
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if self.fallback then
		self.fallback:destroy()
		self.fallback = nil
	end
end

return Footballer
