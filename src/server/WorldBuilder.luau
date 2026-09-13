--!strict
-- Builds the grassroots club out of primitive Parts. Intentionally ugly.
-- Layout (studs): pitch centred on origin, long axis along Z.
--   office block to the west (-X), stand to the east (+X).
-- Scale: ~2.75 studs per metre, so a 105m x 68m pitch is 290 x 190 studs.
-- A concourse strip is left free around the fence for future stands/facilities.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)

local WorldBuilder = {}

local PITCH_W, PITCH_L = Pitch.WIDTH, Pitch.LENGTH
local GROUND_Y = 0 -- top of the baseplate
local FENCE_OFFSET = 5 -- fence sits this far outside the touchline
local FENCE_GAP = 10 -- walk-through gap in the west and east fences
local CONCOURSE = 4 -- free strip between fence and the first structure

local FENCE_X = PITCH_W / 2 + FENCE_OFFSET
local FENCE_Z = PITCH_L / 2 + FENCE_OFFSET

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function box(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, parent: Instance): Part
	return part({
		Name = name,
		Size = size,
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function addPrompt(target: BasePart, objectText: string, actionText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
	return prompt
end

local function addSign(target: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 150
	billboard.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard
end

local function buildPitch(parent: Instance)
	local pitch = Instance.new("Model")
	pitch.Name = "Pitch"
	pitch.Parent = parent

	box("Grass", Vector3.new(PITCH_W, 1, PITCH_L), Vector3.new(0, GROUND_Y + 0.5, 0),
		Color3.fromRGB(75, 140, 60), Enum.Material.Grass, pitch)

	local lineY = GROUND_Y + 1.05
	local lineW = 1
	local white = Color3.new(1, 1, 1)
	-- touchlines / goal lines
	box("LineW", Vector3.new(lineW, 0.1, PITCH_L), Vector3.new(-PITCH_W / 2 + lineW / 2, lineY, 0), white, nil, pitch)
	box("LineE", Vector3.new(lineW, 0.1, PITCH_L), Vector3.new(PITCH_W / 2 - lineW / 2, lineY, 0), white, nil, pitch)
	box("LineN", Vector3.new(PITCH_W, 0.1, lineW), Vector3.new(0, lineY, -PITCH_L / 2 + lineW / 2), white, nil, pitch)
	box("LineS", Vector3.new(PITCH_W, 0.1, lineW), Vector3.new(0, lineY, PITCH_L / 2 - lineW / 2), white, nil, pitch)
	box("Halfway", Vector3.new(PITCH_W, 0.1, lineW), Vector3.new(0, lineY, 0), white, nil, pitch)

	-- penalty areas (16.5m deep, 40.3m wide -> ~45 x 111 studs)
	local boxD, boxW = 45, 111
	for _, zSign in { -1, 1 } do
		local edgeZ = zSign * (PITCH_L / 2)
		local innerZ = edgeZ - zSign * boxD
		box("BoxFront", Vector3.new(boxW, 0.1, lineW), Vector3.new(0, lineY, innerZ), white, nil, pitch)
		for _, xSign in { -1, 1 } do
			box("BoxSide", Vector3.new(lineW, 0.1, boxD), Vector3.new(xSign * boxW / 2, lineY, (edgeZ + innerZ) / 2), white, nil, pitch)
		end
	end

	-- centre spot, penalty spots (11m -> ~30 studs from the goal line)
	box("CentreSpot", Vector3.new(2, 0.1, 2), Vector3.new(0, lineY, 0), white, nil, pitch)
	for _, zSign in { -1, 1 } do
		box("PenaltySpot", Vector3.new(2, 0.1, 2), Vector3.new(0, lineY, zSign * (PITCH_L / 2 - 30)), white, nil, pitch)
	end

	-- centre circle (9.15m -> 25 studs) as a ring of short segments
	local circleR, segments = 25, 28
	for i = 1, segments do
		local a0 = (i - 1) / segments * math.pi * 2
		local a1 = i / segments * math.pi * 2
		local mid = (a0 + a1) / 2
		local segLen = circleR * (a1 - a0) + 0.4
		-- segment lies along the tangent: yaw of -mid - 90deg maps the part's X axis onto (-sin, cos)
		local seg = part({
			Name = "CentreCircle",
			Size = Vector3.new(segLen, 0.1, lineW),
			CFrame = CFrame.new(math.cos(mid) * circleR, lineY, math.sin(mid) * circleR) * CFrame.Angles(0, -mid - math.pi / 2, 0),
			Color = white,
			Parent = pitch,
		})
		seg.Material = Enum.Material.SmoothPlastic
	end

	-- corner flags
	for _, zSign in { -1, 1 } do
		for _, xSign in { -1, 1 } do
			local x, z = xSign * (PITCH_W / 2 - 0.5), zSign * (PITCH_L / 2 - 0.5)
			box("FlagPost", Vector3.new(0.3, 5, 0.3), Vector3.new(x, GROUND_Y + 1 + 2.5, z), Color3.fromRGB(240, 240, 240), nil, pitch)
			box("Flag", Vector3.new(0.1, 1.2, 1.8), Vector3.new(x, GROUND_Y + 1 + 4.4, z - zSign * 0.9), Color3.fromRGB(255, 200, 40), nil, pitch)
		end
	end

	-- goals: 7.32m x 2.44m -> ~20 x 7 studs, with a simple net box behind
	local goalW, goalH = Pitch.GOAL_WIDTH, Pitch.GOAL_HEIGHT
	local netDepth = 6
	for _, zSign in { -1, 1 } do
		local z = zSign * (PITCH_L / 2)
		local goal = Instance.new("Model")
		goal.Name = zSign < 0 and "GoalNorth" or "GoalSouth"
		goal.Parent = pitch
		for _, xSign in { -1, 1 } do
			box("Post", Vector3.new(0.6, goalH, 0.6), Vector3.new(xSign * goalW / 2, GROUND_Y + 1 + goalH / 2, z), white, nil, goal)
		end
		box("Crossbar", Vector3.new(goalW + 0.6, 0.6, 0.6), Vector3.new(0, GROUND_Y + 1 + goalH, z), white, nil, goal)

		local netZ = z + zSign * netDepth / 2
		local netY = GROUND_Y + 1 + goalH / 2
		local function net(name: string, size: Vector3, pos: Vector3)
			local n = box(name, size, pos, Color3.fromRGB(235, 235, 235), Enum.Material.Fabric, goal)
			n.Transparency = 0.55
			n.CanCollide = false
		end
		net("NetBack", Vector3.new(goalW, goalH, 0.2), Vector3.new(0, netY, z + zSign * netDepth))
		net("NetTop", Vector3.new(goalW, 0.2, netDepth), Vector3.new(0, GROUND_Y + 1 + goalH, netZ))
		for _, xSign in { -1, 1 } do
			net("NetSide", Vector3.new(0.2, goalH, netDepth), Vector3.new(xSign * goalW / 2, netY, netZ))
		end
	end
end

local function buildFence(parent: Instance)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = parent
	local grey = Color3.fromRGB(120, 120, 120)
	local h = 3
	local y = GROUND_Y + h / 2
	-- both ends are solid
	box("FenceN", Vector3.new(FENCE_X * 2, h, 0.4), Vector3.new(0, y, -FENCE_Z), grey, Enum.Material.Metal, fence)
	box("FenceS", Vector3.new(FENCE_X * 2, h, 0.4), Vector3.new(0, y, FENCE_Z), grey, Enum.Material.Metal, fence)
	-- west (office) and east (stand) sides have a walk-through gap in the middle
	local segLen = FENCE_Z - FENCE_GAP / 2
	local segZ = FENCE_GAP / 2 + segLen / 2
	for _, side in { { "W", -FENCE_X }, { "E", FENCE_X } } do
		local name, x = side[1] :: string, side[2] :: number
		box("Fence" .. name .. "1", Vector3.new(0.4, h, segLen), Vector3.new(x, y, -segZ), grey, Enum.Material.Metal, fence)
		box("Fence" .. name .. "2", Vector3.new(0.4, h, segLen), Vector3.new(x, y, segZ), grey, Enum.Material.Metal, fence)
	end
end

local function buildOffice(parent: Instance)
	local office = Instance.new("Model")
	office.Name = "Office"
	office.Parent = parent

	local w, d, h = 32, 32, 12
	-- west of the pitch, past the fence and a concourse strip, door facing the pitch
	local cx, cz = -(FENCE_X + CONCOURSE + 40 + w / 2), 0
	local wallColor = Color3.fromRGB(170, 160, 135) -- stained beige
	local wallMat = Enum.Material.Concrete

	box("Floor", Vector3.new(w, 1, d), Vector3.new(cx, GROUND_Y + 0.5, cz),
		Color3.fromRGB(95, 80, 60), Enum.Material.WoodPlanks, office)
	box("Roof", Vector3.new(w + 2, 1, d + 2), Vector3.new(cx, GROUND_Y + 1 + h + 0.5, cz),
		Color3.fromRGB(70, 70, 70), Enum.Material.Slate, office)

	local wy = GROUND_Y + 1 + h / 2
	box("WallW", Vector3.new(1, h, d), Vector3.new(cx - w / 2, wy, cz), wallColor, wallMat, office)
	box("WallN", Vector3.new(w, h, 1), Vector3.new(cx, wy, cz - d / 2), wallColor, wallMat, office)
	box("WallS", Vector3.new(w, h, 1), Vector3.new(cx, wy, cz + d / 2), wallColor, wallMat, office)
	-- east wall has a doorway facing the pitch
	local doorW = 8
	local segLen = (d - doorW) / 2
	box("WallE1", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz - (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("WallE2", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz + (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("DoorHeader", Vector3.new(1, 3, doorW), Vector3.new(cx + w / 2, GROUND_Y + 1 + h - 1.5, cz), wallColor, wallMat, office)

	-- furniture
	local desk = box("Desk", Vector3.new(4, 3, 10), Vector3.new(cx - 8, GROUND_Y + 1 + 1.5, cz),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood, office)
	box("Computer", Vector3.new(1, 2, 2.5), Vector3.new(cx - 8, desk.Position.Y + 1.5 + 1, cz),
		Color3.fromRGB(200, 200, 190), Enum.Material.Plastic, office)
	box("Chair", Vector3.new(2, 2, 2), Vector3.new(cx - 11.5, GROUND_Y + 1 + 1, cz),
		Color3.fromRGB(60, 60, 60), Enum.Material.Fabric, office)

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Parent = box("Bulb", Vector3.new(1, 0.5, 1), Vector3.new(cx, GROUND_Y + h, cz),
		Color3.fromRGB(255, 240, 200), Enum.Material.Neon, office)

	-- spawn inside the office, facing the door
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OfficeSpawn"
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = CFrame.new(cx + 2, GROUND_Y + 1.5, cz) * CFrame.Angles(0, -math.pi / 2, 0)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = office
end

local function buildMatchdayBoard(parent: Instance): ProximityPrompt
	-- Beside the west fence gap, on the walk from the office to the pitch.
	local board = box("MatchdayBoard", Vector3.new(1, 5, 5), Vector3.new(-(FENCE_X + CONCOURSE + 3), GROUND_Y + 2.5, FENCE_GAP / 2 + 6),
		Color3.fromRGB(30, 60, 30), Enum.Material.Wood, parent)
	addSign(board, "MATCHDAY")
	return addPrompt(board, "Matchday Board", "Play Match")
end

-- Stand geometry per level. Rebuildable so the upgrade physically changes it.
local STAND_X = FENCE_X + CONCOURSE

local STEP_DEPTH = 4

local function standSpec(level: number)
	return {
		length = level == 1 and 60 or 200,
		rows = level == 1 and 3 or 8,
		stepHeight = level == 1 and 1.5 or 2,
	}
end

function WorldBuilder.buildStand(level: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local old = club:FindFirstChild("Stand")
	if old then
		old:Destroy()
	end

	local stand = Instance.new("Model")
	stand.Name = "Stand"
	stand.Parent = club

	local spec = standSpec(level)
	local length, rows, stepDepth, stepHeight = spec.length, spec.rows, STEP_DEPTH, spec.stepHeight
	local stepColor = level == 1 and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(190, 190, 190)
	local stepMat = level == 1 and Enum.Material.Metal or Enum.Material.Concrete

	for i = 1, rows do
		local height = stepHeight * i
		box(("Row%d"):format(i), Vector3.new(stepDepth, height, length),
			Vector3.new(STAND_X + stepDepth * (i - 1) + stepDepth / 2, GROUND_Y + height / 2, 0),
			stepColor, stepMat, stand)
		if level >= 2 then
			-- seat blocks along each row
			local seatColor = Color3.fromRGB(30, 80, 200) -- TEMP: seat colour customisation later
			box(("Seats%d"):format(i), Vector3.new(1.5, 1, length - 2),
				Vector3.new(STAND_X + stepDepth * (i - 1) + stepDepth - 0.75, GROUND_Y + height + 0.5, 0),
				seatColor, Enum.Material.Plastic, stand)
		end
	end

	if level >= 2 then
		local backX = STAND_X + stepDepth * rows + 0.5
		local wallH = stepHeight * rows + 4
		box("BackWall", Vector3.new(1, wallH, length),
			Vector3.new(backX, GROUND_Y + wallH / 2, 0),
			Color3.fromRGB(200, 200, 200), Enum.Material.Concrete, stand)
	end

	-- empty crowd folder; filled at kickoff
	local crowd = Instance.new("Folder")
	crowd.Name = "Crowd"
	crowd.Parent = stand

	-- the persistent upgrade sign stands in front of the stand, beside the east fence gap
	local sign = club:FindFirstChild("StandSign") :: Part
	sign.CFrame = CFrame.new(STAND_X - 2, GROUND_Y + 2, FENCE_GAP / 2 + 6)
end

-- TEMP crowd palette: mostly home colours with some neutrals.
local CROWD_COLORS = {
	Config.HomeKit,
	Config.HomeKit,
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(40, 40, 40),
	Color3.fromRGB(70, 90, 130),
	Color3.fromRGB(220, 200, 150),
}
local FAN_SPACING = 2.2

-- Fills the stand with simple block fans at a density matching attendance.
-- One block stands for several fans, so `capacity` blocks means a full house.
function WorldBuilder.buildCrowd(standLevel: number, attendance: number, capacity: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local stand = club:FindFirstChild("Stand") :: Model
	local crowd = stand:FindFirstChild("Crowd") :: Folder
	crowd:ClearAllChildren()

	local spec = standSpec(standLevel)
	local perRow = math.floor((spec.length - 2) / FAN_SPACING)
	local slots = perRow * spec.rows
	local fill = math.clamp(attendance / math.max(capacity, 1), 0, 1)
	local rng = Random.new(attendance)

	local count = 0
	for row = 1, spec.rows do
		local top = GROUND_Y + spec.stepHeight * row
		local x = STAND_X + STEP_DEPTH * (row - 1) + STEP_DEPTH / 2 - 0.4
		for i = 1, perRow do
			-- deterministic scatter: skip seats so density visibly tracks attendance
			if rng:NextNumber() > fill then
				continue
			end
			local z = -spec.length / 2 + 1 + FAN_SPACING * (i - 0.5)
			local fan = box("Fan", Vector3.new(1.3, 2.2, 1.1), Vector3.new(x, top + 1.1, z),
				CROWD_COLORS[rng:NextInteger(1, #CROWD_COLORS)], Enum.Material.SmoothPlastic, crowd)
			fan.CanCollide = false
			count += 1
		end
	end
	stand:SetAttribute("CrowdSlots", slots)
	stand:SetAttribute("CrowdCount", count)
end

local function buildStandSign(parent: Instance): ProximityPrompt
	local sign = box("StandSign", Vector3.new(1, 4, 3), Vector3.new(0, 0, 0),
		Color3.fromRGB(200, 170, 40), Enum.Material.Wood, parent)
	addSign(sign, "STAND")
	return addPrompt(sign, "Stand", "Expand")
end

export type World = {
	model: Model,
	matchdayPrompt: ProximityPrompt,
	standPrompt: ProximityPrompt,
}

-- Turns the default checkered baseplate into rough grassland and gives the
-- sky some depth. Cheap, no assets.
local function dressSurroundings()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(96, 128, 70)
		baseplate.Material = Enum.Material.Grass
		local texture = baseplate:FindFirstChildOfClass("Texture")
		if texture then
			texture:Destroy()
		end
	end

	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 160)
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky") -- default skybox textures, nothing to load
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(199, 208, 220)
		atmosphere.Decay = Color3.fromRGB(110, 120, 140)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.06
		rays.Spread = 0.6
		rays.Parent = Lighting
	end
end

function WorldBuilder.build(standLevel: number): World
	dressSurroundings()
	local existing = workspace:FindFirstChild("Club")
	if existing then
		existing:Destroy()
	end
	local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
	if defaultSpawn then
		defaultSpawn:Destroy()
	end

	local club = Instance.new("Model")
	club.Name = "Club"
	club.Parent = workspace

	buildPitch(club)
	buildFence(club)
	buildOffice(club)
	local matchdayPrompt = buildMatchdayBoard(club)
	local standPrompt = buildStandSign(club)
	WorldBuilder.buildStand(standLevel)

	return {
		model = club,
		matchdayPrompt = matchdayPrompt,
		standPrompt = standPrompt,
	}
end

return WorldBuilder
