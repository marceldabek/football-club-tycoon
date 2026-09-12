--!strict
-- Builds the grassroots club out of primitive Parts. Intentionally ugly.
-- Layout (studs): pitch centred on origin, long axis along Z.
--   office block to the west (-X), stand to the east (+X).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local PITCH_W, PITCH_L = 60, 100
local GROUND_Y = 0 -- top of the baseplate

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
	billboard.MaxDistance = 60
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
	local white = Color3.new(1, 1, 1)
	-- touchlines / goal lines
	box("LineW", Vector3.new(0.5, 0.1, PITCH_L), Vector3.new(-PITCH_W / 2 + 0.25, lineY, 0), white, nil, pitch)
	box("LineE", Vector3.new(0.5, 0.1, PITCH_L), Vector3.new(PITCH_W / 2 - 0.25, lineY, 0), white, nil, pitch)
	box("LineN", Vector3.new(PITCH_W, 0.1, 0.5), Vector3.new(0, lineY, -PITCH_L / 2 + 0.25), white, nil, pitch)
	box("LineS", Vector3.new(PITCH_W, 0.1, 0.5), Vector3.new(0, lineY, PITCH_L / 2 - 0.25), white, nil, pitch)
	box("Halfway", Vector3.new(PITCH_W, 0.1, 0.5), Vector3.new(0, lineY, 0), white, nil, pitch)

	-- goals: two posts and a crossbar at each end
	for _, zSign in { -1, 1 } do
		local z = zSign * (PITCH_L / 2)
		local goal = Instance.new("Model")
		goal.Name = zSign < 0 and "GoalNorth" or "GoalSouth"
		goal.Parent = pitch
		for _, xSign in { -1, 1 } do
			box("Post", Vector3.new(0.5, 8, 0.5), Vector3.new(xSign * 12, GROUND_Y + 1 + 4, z), white, nil, goal)
		end
		box("Crossbar", Vector3.new(24.5, 0.5, 0.5), Vector3.new(0, GROUND_Y + 1 + 8, z), white, nil, goal)
	end
end

local function buildFence(parent: Instance)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = parent
	local grey = Color3.fromRGB(120, 120, 120)
	local h = 3
	local y = GROUND_Y + h / 2
	local fx = PITCH_W / 2 + 4
	local fz = PITCH_L / 2 + 4
	-- east and both ends are solid
	box("FenceE", Vector3.new(0.4, h, fz * 2), Vector3.new(fx, y, 0), grey, Enum.Material.Metal, fence)
	box("FenceN", Vector3.new(fx * 2, h, 0.4), Vector3.new(0, y, -fz), grey, Enum.Material.Metal, fence)
	box("FenceS", Vector3.new(fx * 2, h, 0.4), Vector3.new(0, y, fz), grey, Enum.Material.Metal, fence)
	-- west side has a gap in the middle for the walk from the office
	local gap = 8
	local segLen = fz - gap / 2
	box("FenceW1", Vector3.new(0.4, h, segLen), Vector3.new(-fx, y, -(gap / 2 + segLen / 2)), grey, Enum.Material.Metal, fence)
	box("FenceW2", Vector3.new(0.4, h, segLen), Vector3.new(-fx, y, gap / 2 + segLen / 2), grey, Enum.Material.Metal, fence)
end

local function buildOffice(parent: Instance)
	local office = Instance.new("Model")
	office.Name = "Office"
	office.Parent = parent

	local cx, cz = -75, 0
	local w, d, h = 24, 24, 10
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
	local doorW = 6
	local segLen = (d - doorW) / 2
	box("WallE1", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz - (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("WallE2", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz + (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("DoorHeader", Vector3.new(1, 2, doorW), Vector3.new(cx + w / 2, GROUND_Y + 1 + h - 1, cz), wallColor, wallMat, office)

	-- furniture
	local desk = box("Desk", Vector3.new(4, 3, 8), Vector3.new(cx - 6, GROUND_Y + 1 + 1.5, cz),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood, office)
	box("Computer", Vector3.new(1, 2, 2.5), Vector3.new(cx - 6, desk.Position.Y + 1.5 + 1, cz),
		Color3.fromRGB(200, 200, 190), Enum.Material.Plastic, office)
	box("Chair", Vector3.new(2, 2, 2), Vector3.new(cx - 9.5, GROUND_Y + 1 + 1, cz),
		Color3.fromRGB(60, 60, 60), Enum.Material.Fabric, office)

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 30
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
	-- Sits just outside the west fence gap, on the walk from office to pitch.
	local board = box("MatchdayBoard", Vector3.new(1, 5, 5), Vector3.new(-PITCH_W / 2 - 7, GROUND_Y + 2.5, 8),
		Color3.fromRGB(30, 60, 30), Enum.Material.Wood, parent)
	addSign(board, "MATCHDAY")
	return addPrompt(board, "Matchday Board", "Play Match")
end

-- Stand geometry per level. Rebuildable so the upgrade physically changes it.
local STAND_X = PITCH_W / 2 + 6

local function standLength(level: number): number
	return level == 1 and 30 or 70
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

	local length = standLength(level)
	local rows = level == 1 and 3 or 7
	local stepDepth = 3
	local stepHeight = level == 1 and 1.5 or 2
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
			box(("Seats%d"):format(i), Vector3.new(1.2, 1, length - 2),
				Vector3.new(STAND_X + stepDepth * (i - 1) + stepDepth - 0.6, GROUND_Y + height + 0.5, 0),
				seatColor, Enum.Material.Plastic, stand)
		end
	end

	if level >= 2 then
		local backX = STAND_X + stepDepth * rows + 0.5
		box("BackWall", Vector3.new(1, stepHeight * rows + 4, length),
			Vector3.new(backX, GROUND_Y + (stepHeight * rows + 4) / 2, 0),
			Color3.fromRGB(200, 200, 200), Enum.Material.Concrete, stand)
	end

	-- reposition the persistent upgrade sign just past the stand's north end
	local sign = club:FindFirstChild("StandSign") :: Part
	sign.CFrame = CFrame.new(STAND_X + 1.5, GROUND_Y + 2, -(length / 2) - 4)
end

local function buildStandSign(parent: Instance): ProximityPrompt
	local sign = box("StandSign", Vector3.new(3, 4, 1), Vector3.new(0, 0, 0),
		Color3.fromRGB(200, 170, 40), Enum.Material.Wood, parent)
	addSign(sign, "STAND")
	return addPrompt(sign, "Stand", "Expand")
end

export type World = {
	model: Model,
	matchdayPrompt: ProximityPrompt,
	standPrompt: ProximityPrompt,
}

function WorldBuilder.build(standLevel: number): World
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
