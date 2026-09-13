--!strict
-- A footballer made of primitive parts with procedural run / kick / celebrate /
-- dive poses. No animation assets, so nothing can fail to load. Every part is
-- anchored and repositioned each frame with BulkMoveTo.
-- TEMP: swap for real rigs + animations once the match loop is proven fun.

local Footballer = {}
Footballer.__index = Footballer

local TORSO = Vector3.new(2, 2.2, 1)
local HEAD = 1.2
local LEG = Vector3.new(0.7, 2, 0.7)
local ARM = Vector3.new(0.6, 2, 0.6)
local SKIN = Color3.fromRGB(230, 190, 150) -- TEMP: single tone for now

export type Pose = "idle" | "kick" | "celebrate" | "dive" | "throw"

export type Footballer = typeof(setmetatable(
	{} :: {
		model: Model,
		parts: { BasePart },
		position: Vector3,
		yaw: number,
		target: Vector3?,
		speed: number,
		velocity: Vector3,
		moving: boolean,
		phase: number,
		pose: Pose,
		poseT: number,
		diveDir: number,
		busy: boolean,
		jitter: Vector3,
		number: number,
		name: string,
	},
	Footballer
))

local POSE_LENGTH: { [Pose]: number } = { idle = 0, kick = 0.4, celebrate = 2.5, dive = 1.3, throw = 0.8 }

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function numberFace(torso: Part, face: Enum.NormalId, number: number)
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

local function nameTag(head: Part, number: number, name: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 22)
	billboard.Name = "NameTag"
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
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
end

function Footballer.new(parent: Instance, kit: Color3, number: number, name: string, position: Vector3): Footballer
	local model = Instance.new("Model")
	model.Name = ("%d %s"):format(number, name)
	local shorts = kit:Lerp(Color3.new(0, 0, 0), 0.55)

	local torso = part("Torso", TORSO, kit, model)
	local head = part("Head", Vector3.new(HEAD, HEAD, HEAD), SKIN, model)
	head.Shape = Enum.PartType.Ball
	local legL = part("LegL", LEG, shorts, model)
	local legR = part("LegR", LEG, shorts, model)
	local armL = part("ArmL", ARM, kit, model)
	local armR = part("ArmR", ARM, kit, model)
	numberFace(torso, Enum.NormalId.Back, number)
	numberFace(torso, Enum.NormalId.Front, number)
	nameTag(head, number, name)
	model.Parent = parent

	local self = setmetatable({
		model = model,
		parts = { torso, head, legL, legR, armL, armR },
		position = position,
		yaw = 0,
		target = nil,
		speed = 22,
		velocity = Vector3.zero,
		moving = false,
		phase = 0,
		pose = "idle" :: Pose,
		poseT = 0,
		diveDir = 1,
		busy = false,
		jitter = Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4),
		number = number,
		name = name,
	}, Footballer)
	self:update(0)
	return self
end

function Footballer.setTarget(self: Footballer, target: Vector3?)
	self.target = target
end

function Footballer.teleport(self: Footballer, position: Vector3)
	self.position = position
	self.target = nil
	self:update(0)
end

function Footballer.setTagVisible(self: Footballer, visible: boolean)
	local tag = self.parts[2]:FindFirstChild("NameTag")
	if tag then
		(tag :: BillboardGui).Enabled = visible
	end
end

function Footballer.face(self: Footballer, point: Vector3)
	local d = point - self.position
	if d.X ~= 0 or d.Z ~= 0 then
		self.yaw = math.atan2(-d.X, -d.Z)
	end
end

local function setPose(self: Footballer, pose: Pose)
	self.pose = pose
	self.poseT = 0
end

function Footballer.kick(self: Footballer)
	setPose(self, "kick")
end

function Footballer.celebrate(self: Footballer)
	setPose(self, "celebrate")
end

function Footballer.throw(self: Footballer)
	setPose(self, "throw")
end

-- dir: -1 dives to the player's left, 1 to the right.
function Footballer.dive(self: Footballer, dir: number)
	self.diveDir = dir >= 0 and 1 or -1
	setPose(self, "dive")
end

-- Advances movement and pose timers, then writes all part CFrames.
function Footballer.update(self: Footballer, dt: number)
	-- Velocity with acceleration and ease-out, so players lean into runs and
	-- slow into position instead of stopping dead.
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
		self.yaw = math.atan2(-self.velocity.X, -self.velocity.Z)
		self.phase += dt * (speedNow * 0.55)
	end
	self.moving = speedNow > 1.5

	if self.pose ~= "idle" then
		self.poseT += dt
		if self.poseT >= POSE_LENGTH[self.pose] then
			self.pose = "idle"
		end
	end

	local amp = math.clamp(self.velocity.Magnitude / 22, 0, 1) * 0.7
	local swing = self.moving and math.sin(self.phase) * amp or 0
	local legLA, legRA = swing, -swing
	local armLA, armRA = -swing * 0.8, swing * 0.8
	local bob = self.moving and math.abs(math.sin(self.phase)) * 0.15 or 0
	local tilt = 0
	local lift = 0

	if self.pose == "kick" then
		legRA = 1.4 * math.sin(math.min(self.poseT / POSE_LENGTH.kick, 1) * math.pi)
	elseif self.pose == "celebrate" then
		armLA, armRA = math.pi - 0.3, math.pi - 0.3
		bob = math.abs(math.sin(self.poseT * 9)) * 1.2
	elseif self.pose == "throw" then
		-- both arms overhead, snapping forward at release
		local k = math.min(self.poseT / POSE_LENGTH.throw, 1)
		local arm = math.pi - 0.2 - math.sin(k * math.pi) * 1.2
		armLA, armRA = arm, arm
	elseif self.pose == "dive" then
		local k = math.min(self.poseT / 0.25, 1)
		tilt = self.diveDir * 1.35 * k
		lift = -1.6 * k
		armLA, armRA = math.pi / 2, math.pi / 2
	end

	local torsoCenterY = LEG.Y + TORSO.Y / 2 + bob + lift
	local root = CFrame.new(self.position + Vector3.new(0, torsoCenterY, 0))
		* CFrame.Angles(0, self.yaw, 0)
		* CFrame.Angles(0, 0, tilt)

	local cframes = {
		root,
		root * CFrame.new(0, TORSO.Y / 2 + HEAD / 2, 0),
		root * CFrame.new(-0.5, -TORSO.Y / 2, 0) * CFrame.Angles(legLA, 0, 0) * CFrame.new(0, -LEG.Y / 2, 0),
		root * CFrame.new(0.5, -TORSO.Y / 2, 0) * CFrame.Angles(legRA, 0, 0) * CFrame.new(0, -LEG.Y / 2, 0),
		root * CFrame.new(-(TORSO.X / 2 + ARM.X / 2), TORSO.Y / 2 - 0.2, 0) * CFrame.Angles(armLA, 0, 0) * CFrame.new(0, -ARM.Y / 2, 0),
		root * CFrame.new(TORSO.X / 2 + ARM.X / 2, TORSO.Y / 2 - 0.2, 0) * CFrame.Angles(armRA, 0, 0) * CFrame.new(0, -ARM.Y / 2, 0),
	}
	workspace:BulkMoveTo(self.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function Footballer.destroy(self: Footballer)
	self.model:Destroy()
end

return Footballer
