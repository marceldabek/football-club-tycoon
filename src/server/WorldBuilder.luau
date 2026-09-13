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
local FENCE_OFFSET = 5 -- side fences sit this far outside the touchline
local END_FENCE_OFFSET = 12 -- end fences sit behind the goal nets (net depth 6)
local FENCE_GAP = 10 -- walk-through gap in the west and east fences
local CONCOURSE = 4 -- free strip between fence and the first structure

local FENCE_X = PITCH_W / 2 + FENCE_OFFSET
local FENCE_Z = PITCH_L / 2 + END_FENCE_OFFSET

-- Office block: west of the pitch, past the fence and a concourse strip.
local OFFICE_W, OFFICE_D, OFFICE_H = 32, 32, 12
local OFFICE_CX, OFFICE_CZ = -(FENCE_X + CONCOURSE + 40 + OFFICE_W / 2), 0

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

	-- mowing stripes: alternating shades across the length
	local stripes = 14
	local stripeL = PITCH_L / stripes
	local light, dark = Color3.fromRGB(88, 150, 66), Color3.fromRGB(72, 132, 56)
	for i = 1, stripes do
		local z = -PITCH_L / 2 + stripeL * (i - 0.5)
		box(("Stripe%d"):format(i), Vector3.new(PITCH_W, 1, stripeL + 0.02), Vector3.new(0, GROUND_Y + 0.5, z),
			if i % 2 == 0 then light else dark, Enum.Material.Grass, pitch)
	end
	-- worn goalmouths and centre circle: thin dusty patches just above the grass
	local worn = Color3.fromRGB(120, 130, 70)
	for _, zSign in { -1, 1 } do
		local patch = box("Goalmouth", Vector3.new(30, 0.08, 14), Vector3.new(0, GROUND_Y + 1.02, zSign * (PITCH_L / 2 - 8)), worn, Enum.Material.Sand, pitch)
		patch.Transparency = 0.45
	end
	local centreWear = box("CentreWear", Vector3.new(16, 0.08, 16), Vector3.new(0, GROUND_Y + 1.02, 0), worn, Enum.Material.Sand, pitch)
	centreWear.Transparency = 0.6

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

	-- goal areas (5.5m deep, 18.3m wide -> ~15 x 50 studs)
	local sixD, sixW = 15, 50
	for _, zSign in { -1, 1 } do
		local edgeZ = zSign * (PITCH_L / 2)
		local innerZ = edgeZ - zSign * sixD
		box("SixFront", Vector3.new(sixW, 0.1, lineW), Vector3.new(0, lineY, innerZ), white, nil, pitch)
		for _, xSign in { -1, 1 } do
			box("SixSide", Vector3.new(lineW, 0.1, sixD), Vector3.new(xSign * sixW / 2, lineY, (edgeZ + innerZ) / 2), white, nil, pitch)
		end
	end

	-- centre spot, penalty spots (11m -> ~30 studs from the goal line)
	box("CentreSpot", Vector3.new(2, 0.1, 2), Vector3.new(0, lineY, 0), white, nil, pitch)
	for _, zSign in { -1, 1 } do
		box("PenaltySpot", Vector3.new(2, 0.1, 2), Vector3.new(0, lineY, zSign * (PITCH_L / 2 - 30)), white, nil, pitch)
	end

	-- arcs as rings of short segments: segment lies along the tangent
	local function arc(name: string, cx: number, cz: number, radius: number, fromAngle: number, toAngle: number, segments: number)
		for i = 1, segments do
			local a0 = fromAngle + (toAngle - fromAngle) * (i - 1) / segments
			local a1 = fromAngle + (toAngle - fromAngle) * i / segments
			local mid = (a0 + a1) / 2
			local segLen = radius * (a1 - a0) + 0.4
			part({
				Name = name,
				Size = Vector3.new(segLen, 0.1, lineW),
				CFrame = CFrame.new(cx + math.cos(mid) * radius, lineY, cz + math.sin(mid) * radius) * CFrame.Angles(0, -mid - math.pi / 2, 0),
				Color = white,
				Material = Enum.Material.SmoothPlastic,
				Parent = pitch,
			})
		end
	end
	-- centre circle (9.15m -> 25 studs)
	arc("CentreCircle", 0, 0, 25, 0, math.pi * 2, 28)
	-- penalty arcs: the part of the 25-stud circle round the spot that lies outside the box
	-- box front is 15 studs from the spot; cos(a) = 15/25 -> the D spans ±53 degrees about the pitch axis
	local half = math.acos(15 / 25)
	arc("ArcNorth", 0, -(PITCH_L / 2 - 30), 25, math.pi / 2 - half, math.pi / 2 + half, 10)
	arc("ArcSouth", 0, PITCH_L / 2 - 30, 25, -math.pi / 2 - half, -math.pi / 2 + half, 10)

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

-- Pitch-side advertising boards with fictional sponsors. Gaps at the fence
-- gaps (walkout path) and where the dugouts sit.
local BOARD_H = 3
local DUGOUT_Z = { 18, 40 } -- dugouts occupy |z| in this range on the west side

local function sponsorBoard(parent: Instance, cframe: CFrame, length: number, index: number)
	local sponsor = Config.Sponsors[((index - 1) % #Config.Sponsors) + 1]
	local board = part({
		Name = "AdBoard",
		Size = Vector3.new(length, BOARD_H, 0.6),
		CFrame = cframe,
		Color = sponsor.bg,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = sponsor.fg
	label.Text = sponsor.text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = label
	return board
end

local function buildAdBoards(parent: Instance)
	local boards = Instance.new("Model")
	boards.Name = "AdBoards"
	boards.Parent = parent
	local y = GROUND_Y + BOARD_H / 2
	local offset = 2.6 -- outside the touchline, inside the fence
	local segLen = 24
	local index = 0
	-- side boards, facing the pitch
	for _, xSign in { -1, 1 } do
		local x = xSign * (PITCH_W / 2 + offset)
		local count = math.floor(PITCH_L / segLen)
		for i = 1, count do
			local z = -PITCH_L / 2 + segLen * (i - 0.5)
			local inGap = math.abs(z) < FENCE_GAP / 2 + segLen / 2
			local inDugout = xSign < 0 and math.abs(z) > DUGOUT_Z[1] - segLen / 2 and math.abs(z) < DUGOUT_Z[2] + segLen / 2
			if inGap or inDugout then
				continue
			end
			index += 1
			-- Front (-Z of the part) must face the pitch: yaw so that -Z points toward x = 0
			local yaw = if xSign < 0 then -math.pi / 2 else math.pi / 2
			sponsorBoard(boards, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), segLen - 1, index)
		end
	end
	-- end boards behind the nets
	for _, zSign in { -1, 1 } do
		local z = zSign * (PITCH_L / 2 + 8.5)
		local count = math.floor(PITCH_W / segLen)
		for i = 1, count do
			local x = -PITCH_W / 2 + segLen * (i - 0.5)
			index += 1
			-- Front (-Z local) toward the pitch: north boards face +Z, south boards face -Z
			local yaw = if zSign < 0 then math.pi else 0
			sponsorBoard(boards, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), segLen - 1, index)
		end
	end
end

-- Two dugouts on the west touchline: bench under a perspex shelter.
local function buildDugouts(parent: Instance)
	local dugouts = Instance.new("Model")
	dugouts.Name = "Dugouts"
	dugouts.Parent = parent
	local x = -(PITCH_W / 2 + 3.2)
	for _, zSign in { -1, 1 } do
		local zc = zSign * (DUGOUT_Z[1] + DUGOUT_Z[2]) / 2
		local len = DUGOUT_Z[2] - DUGOUT_Z[1]
		box("Bench", Vector3.new(2, 1.6, len - 2), Vector3.new(x - 0.5, GROUND_Y + 0.8, zc), Color3.fromRGB(50, 50, 55), Enum.Material.Plastic, dugouts)
		box("BenchBack", Vector3.new(0.4, 3.5, len - 2), Vector3.new(x - 1.6, GROUND_Y + 1.75, zc), Color3.fromRGB(50, 50, 55), Enum.Material.Plastic, dugouts)
		local roof = box("Shelter", Vector3.new(4.5, 0.3, len), Vector3.new(x - 0.2, GROUND_Y + 5.5, zc), Color3.fromRGB(180, 210, 230), Enum.Material.Glass, dugouts)
		roof.Transparency = 0.35
		for _, zEnd in { -1, 1 } do
			local side = box("Side", Vector3.new(4.5, 5.2, 0.3), Vector3.new(x - 0.2, GROUND_Y + 2.7, zc + zEnd * (len / 2 - 0.15)), Color3.fromRGB(180, 210, 230), Enum.Material.Glass, dugouts)
			side.Transparency = 0.35
		end
		box("Frame", Vector3.new(0.4, 5.5, 0.4), Vector3.new(x - 2.3, GROUND_Y + 2.75, zc + len / 2 - 0.3), Color3.fromRGB(90, 90, 95), Enum.Material.Metal, dugouts)
		box("Frame", Vector3.new(0.4, 5.5, 0.4), Vector3.new(x - 2.3, GROUND_Y + 2.75, zc - len / 2 + 0.3), Color3.fromRGB(90, 90, 95), Enum.Material.Metal, dugouts)
	end
end

-- Arch over the west fence gap where the teams walk out, with the club name.
local function buildTunnel(parent: Instance): TextLabel
	local tunnel = Instance.new("Model")
	tunnel.Name = "Tunnel"
	tunnel.Parent = parent
	local x = -(FENCE_X + 0.5)
	local h = 9
	local w = FENCE_GAP + 4
	local colour = Config.HomeKit
	for _, zSign in { -1, 1 } do
		box("Pillar", Vector3.new(1.4, h, 1.4), Vector3.new(x, GROUND_Y + h / 2, zSign * (w / 2)), colour, Enum.Material.SmoothPlastic, tunnel)
	end
	local header = box("Header", Vector3.new(1.4, 2.6, w + 1.4), Vector3.new(x, GROUND_Y + h + 1.3, 0), colour, Enum.Material.SmoothPlastic, tunnel)
	-- name plate facing the pitch (+X side of the header)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.8
	gui.Parent = header
	local label = Instance.new("TextLabel")
	label.Name = "ClubName"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "CLUB"
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.15, 0)
	pad.PaddingBottom = UDim.new(0.15, 0)
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = label
	-- a strip of paving from the office door through the arch to the touchline
	local pathLen = 40 + CONCOURSE + FENCE_OFFSET
	box("Path", Vector3.new(pathLen, 0.2, 6), Vector3.new(x - pathLen / 2 + FENCE_OFFSET + 1, GROUND_Y + 0.1, 0), Color3.fromRGB(150, 145, 135), Enum.Material.Cobblestone, tunnel)
	return label
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

	local w, d, h = OFFICE_W, OFFICE_D, OFFICE_H
	-- door faces the pitch
	local cx, cz = OFFICE_CX, OFFICE_CZ
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
	local computer = box("Computer", Vector3.new(1, 2, 2.5), Vector3.new(cx - 8, desk.Position.Y + 1.5 + 1, cz),
		Color3.fromRGB(200, 200, 190), Enum.Material.Plastic, office)
	-- Club management lives on the office computer. The client opens the panel
	-- when this prompt fires (ProximityPromptService.PromptTriggered).
	local clubPrompt = addPrompt(computer, "Club Office", "Manage squad, scouting & staff")
	clubPrompt.Name = "ClubPrompt"
	clubPrompt.HoldDuration = 0
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

-- Trophy shelf on the inside of the office's north wall: one gold cup per
-- league title (Milestone 5 club history). Safe to call again after a title.
function WorldBuilder.buildTrophies(count: number)
	local club = workspace:FindFirstChild("Club")
	local office = club and club:FindFirstChild("Office")
	if not office then
		return
	end
	local existing = office:FindFirstChild("Trophies")
	if existing then
		existing:Destroy()
	end
	local shown = math.clamp(math.floor(count), 0, Config.TrophiesShown)
	if shown == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Trophies"
	model.Parent = office

	local shelfLen = OFFICE_W - 6
	local shelfY = GROUND_Y + 1 + 7
	local shelfZ = OFFICE_CZ - OFFICE_D / 2 + 1.5
	box("Shelf", Vector3.new(shelfLen, 0.5, 2), Vector3.new(OFFICE_CX, shelfY, shelfZ),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood, model)

	local gold = Color3.fromRGB(230, 190, 60)
	local spacing = 3
	local startX = OFFICE_CX - (shown - 1) * spacing / 2
	for i = 1, shown do
		local x = startX + (i - 1) * spacing
		local base = part({
			Name = "CupBase" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 1.6, 1.6),
			CFrame = CFrame.new(x, shelfY + 0.45, shelfZ) * CFrame.Angles(0, 0, math.pi / 2),
			Color = gold,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		part({
			Name = "CupStem" .. i,
			Size = Vector3.new(0.4, 1.2, 0.4),
			CFrame = CFrame.new(x, base.Position.Y + 0.8, shelfZ),
			Color = gold,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		part({
			Name = "Cup" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(x, base.Position.Y + 2, shelfZ),
			Color = gold,
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
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

-- One entry per Config.StandLevels level.
local STAND_SPECS = {
	{ length = 60, rows = 3, stepHeight = 1.5, roof = false },
	{ length = 200, rows = 8, stepHeight = 2, roof = false },
	{ length = 240, rows = 12, stepHeight = 2, roof = false },
	{ length = 270, rows = 16, stepHeight = 2, roof = true },
}
local function standSpec(level: number)
	return STAND_SPECS[math.clamp(level, 1, #STAND_SPECS)]
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
	local stepColor = level == 1 and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(175, 175, 172)
	local stepMat = level == 1 and Enum.Material.Metal or Enum.Material.Concrete

	-- seating is split into sections with a stepped aisle between each
	local sectionLen = 26
	local aisleW = 3
	local sections = math.max(1, math.floor((length + aisleW) / (sectionLen + aisleW)))
	local usedLen = sections * sectionLen + (sections - 1) * aisleW
	local startZ = -usedLen / 2

	for i = 1, rows do
		local height = stepHeight * i
		local rowX = STAND_X + stepDepth * (i - 1) + stepDepth / 2
		box(("Row%d"):format(i), Vector3.new(stepDepth, height, length),
			Vector3.new(rowX, GROUND_Y + height / 2, 0),
			stepColor, stepMat, stand)
		if level >= 2 then
			-- seat blocks per section; an alternate shade every other section so the
			-- seating reads as blocks rather than one long strip
			for s = 1, sections do
				local z = startZ + (s - 1) * (sectionLen + aisleW) + sectionLen / 2
				local colour = if s % 2 == 0 then Config.SeatColor:Lerp(Color3.new(1, 1, 1), 0.25) else Config.SeatColor
				local seat = box(("Seats%d_%d"):format(i, s), Vector3.new(1.6, 1.1, sectionLen),
					Vector3.new(STAND_X + stepDepth * (i - 1) + stepDepth - 0.8, GROUND_Y + height + 0.55, z),
					colour, Enum.Material.Plastic, stand)
				seat.CanCollide = false
				-- seat back, a thinner lip behind each row
				local back = box(("SeatBack%d_%d"):format(i, s), Vector3.new(0.3, 1.6, sectionLen),
					Vector3.new(STAND_X + stepDepth * (i - 1) + stepDepth - 0.15, GROUND_Y + height + 0.8, z),
					colour, Enum.Material.Plastic, stand)
				back.CanCollide = false
			end
			-- aisle treads between sections, lighter so they read as steps
			for s = 1, sections - 1 do
				local z = startZ + s * (sectionLen + aisleW) - aisleW / 2
				local tread = box(("Aisle%d_%d"):format(i, s), Vector3.new(stepDepth, 0.2, aisleW),
					Vector3.new(rowX, GROUND_Y + height + 0.1, z), Color3.fromRGB(215, 215, 210), Enum.Material.Concrete, stand)
				tread.CanCollide = false
			end
		else
			-- level 1: a plank bench along each bleacher row
			box(("Bench%d"):format(i), Vector3.new(1.8, 0.4, length - 2),
				Vector3.new(STAND_X + stepDepth * (i - 1) + stepDepth - 0.9, GROUND_Y + height + 0.2, 0),
				Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks, stand)
		end
	end

	-- front wall with the club name, and a railing along the top of it
	local frontH = if level == 1 then 1.2 else 2.6
	local frontWall = box("FrontWall", Vector3.new(0.8, frontH, length), Vector3.new(STAND_X - 0.4, GROUND_Y + frontH / 2, 0),
		if level == 1 then Color3.fromRGB(120, 120, 120) else Config.HomeKit, if level == 1 then Enum.Material.Metal else Enum.Material.SmoothPlastic, stand)
	if level >= 2 then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "NameGui"
		gui.Face = Enum.NormalId.Left -- -X, toward the pitch
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 16
		gui.LightInfluence = 0.9
		gui.Parent = frontWall
		local label = Instance.new("TextLabel")
		label.Name = "ClubName"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextTransparency = 0.15
		label.Text = "" -- WorldBuilder.setClubName fills it
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.2, 0)
		pad.PaddingBottom = UDim.new(0.2, 0)
		pad.Parent = label
		local rail = box("Rail", Vector3.new(0.3, 0.3, length), Vector3.new(STAND_X - 0.4, GROUND_Y + frontH + 1.1, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, stand)
		rail.CanCollide = false
		for i = 0, math.floor(length / 8) do
			local post = box("RailPost", Vector3.new(0.25, 1.1, 0.25), Vector3.new(STAND_X - 0.4, GROUND_Y + frontH + 0.55, -length / 2 + i * 8), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, stand)
			post.CanCollide = false
		end
	end

	if level >= 2 then
		local backX = STAND_X + stepDepth * rows + 0.5
		local wallH = stepHeight * rows + 4
		box("BackWall", Vector3.new(1, wallH, length),
			Vector3.new(backX, GROUND_Y + wallH / 2, 0),
			Color3.fromRGB(200, 200, 200), Enum.Material.Concrete, stand)
		-- end walls close the sides off
		for _, zSign in { -1, 1 } do
			local depth = stepDepth * rows + 1
			local wedge = Instance.new("WedgePart")
			wedge.Name = "EndWall"
			wedge.Anchored = true
			wedge.Size = Vector3.new(0.8, wallH - 4, depth)
			-- slope rises toward the back wall (+X)
			wedge.CFrame = CFrame.new(STAND_X + depth / 2, GROUND_Y + (wallH - 4) / 2, zSign * (length / 2 + 0.4)) * CFrame.Angles(0, -math.pi / 2, 0)
			wedge.Color = Color3.fromRGB(200, 200, 200)
			wedge.Material = Enum.Material.Concrete
			wedge.Parent = stand
		end
		if spec.roof then
			-- cantilever roof over the seats, held by pillars along the back wall
			local roofY = GROUND_Y + wallH + 6
			local roofDepth = stepDepth * rows + 6
			box("Roof", Vector3.new(roofDepth, 0.8, length + 4),
				Vector3.new(STAND_X + roofDepth / 2 - 2, roofY, 0),
				Color3.fromRGB(90, 95, 105), Enum.Material.Metal, stand)
			for i = 0, 6 do
				local z = -length / 2 + (length / 6) * i
				box("Pillar", Vector3.new(1.5, roofY - GROUND_Y, 1.5),
					Vector3.new(backX + 1.5, GROUND_Y + (roofY - GROUND_Y) / 2, z),
					Color3.fromRGB(120, 120, 130), Enum.Material.Metal, stand)
			end
		end
	end

	-- empty crowd folder; filled at kickoff
	local crowd = Instance.new("Folder")
	crowd.Name = "Crowd"
	crowd.Parent = stand

	-- the persistent upgrade sign stands in front of the stand, beside the east fence gap
	local sign = club:FindFirstChild("StandSign") :: Part
	sign.CFrame = CFrame.new(STAND_X - 2, GROUND_Y + 2, FENCE_GAP / 2 + 6)
	local state = ReplicatedStorage:FindFirstChild("ClubState")
	if state then
		WorldBuilder.setClubName((state:GetAttribute("ClubName") :: string?) or Config.ClubName)
	end
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
local SKIN_TONES = {
	Color3.fromRGB(240, 200, 170),
	Color3.fromRGB(200, 150, 110),
	Color3.fromRGB(150, 100, 70),
	Color3.fromRGB(100, 65, 45),
}
local FAN_SPACING = 2.2
-- Fan budget for a full house (mobile); each fan is two parts.
local MAX_FAN_BLOCKS = 500

-- Fills the stand with simple block fans at a density matching attendance.
-- One block stands for several fans, so a full house means every slot filled.
function WorldBuilder.buildCrowd(standLevel: number, attendance: number, capacity: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local stand = club:FindFirstChild("Stand") :: Model
	local crowd = stand:FindFirstChild("Crowd") :: Folder
	crowd:ClearAllChildren()

	local spec = standSpec(standLevel)
	local spacing = math.max(FAN_SPACING, (spec.length - 2) * spec.rows / MAX_FAN_BLOCKS)
	local perRow = math.floor((spec.length - 2) / spacing)
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
			local z = -spec.length / 2 + 1 + spacing * (i - 0.5)
			-- seated fan: torso block plus a head; a little height jitter so rows do not look stamped
			local bodyH = 1.5 + rng:NextNumber(-0.15, 0.15)
			local fan = box("Fan", Vector3.new(1.2, bodyH, 1.0), Vector3.new(x, top + 0.9 + bodyH / 2, z),
				CROWD_COLORS[rng:NextInteger(1, #CROWD_COLORS)], Enum.Material.SmoothPlastic, crowd)
			fan.CanCollide = false
			fan.CastShadow = false
			local head = part({
				Name = "Head",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.9, 0.9),
				CFrame = CFrame.new(x, top + 0.9 + bodyH + 0.45, z),
				Color = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)],
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CastShadow = false,
				Parent = crowd,
			})
			head.Name = "Head"
			count += 1
		end
	end
	stand:SetAttribute("CrowdSlots", slots)
	stand:SetAttribute("CrowdCount", count)
end

-- Concourse amenity chain (snack bar -> club shop -> fan zone), opposite the
-- matchday board on the walk from the office. Rebuilt on each upgrade.
local AMENITY_POS = Vector3.new(-(FENCE_X + CONCOURSE + 10), GROUND_Y, -(FENCE_GAP / 2 + 14))

function WorldBuilder.buildAmenity(level: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local old = club:FindFirstChild("Amenity")
	if old then
		old:Destroy()
	end
	local amenity = Instance.new("Model")
	amenity.Name = "Amenity"
	amenity.Parent = club
	local p = AMENITY_POS
	if level >= 1 then
		-- snack bar: hut with a serving hatch and a striped awning
		box("Hut", Vector3.new(10, 7, 8), p + Vector3.new(0, 3.5, 0), Color3.fromRGB(190, 120, 70), Enum.Material.Wood, amenity)
		box("Hatch", Vector3.new(0.3, 3, 5), p + Vector3.new(5.1, 4, 0), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic, amenity)
		box("Awning", Vector3.new(5, 0.3, 9), p + Vector3.new(7, 6.5, 0), Color3.fromRGB(220, 60, 60), Enum.Material.Fabric, amenity)
		box("Counter", Vector3.new(2, 1, 6), p + Vector3.new(6, 2.5, 0), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, amenity)
	end
	if level >= 2 then
		-- club shop: larger unit beside the hut, club-coloured facade
		box("Shop", Vector3.new(12, 9, 12), p + Vector3.new(-1, 4.5, -13), Color3.fromRGB(220, 220, 225), Enum.Material.Concrete, amenity)
		box("ShopFascia", Vector3.new(0.4, 2.5, 12), p + Vector3.new(5.2, 8, -13), Config.HomeKit, Enum.Material.SmoothPlastic, amenity)
		local window = box("ShopWindow", Vector3.new(0.3, 4, 8), p + Vector3.new(5.1, 4, -13), Color3.fromRGB(150, 200, 230), Enum.Material.Glass, amenity)
		window.Transparency = 0.4
	end
	if level >= 3 then
		-- fan zone: paved square with flag poles and a small stage
		box("Paving", Vector3.new(30, 0.3, 24), p + Vector3.new(16, 0.15, -6), Color3.fromRGB(160, 160, 150), Enum.Material.Cobblestone, amenity)
		box("Stage", Vector3.new(10, 2, 6), p + Vector3.new(24, 1, -14), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, amenity)
		for i = 0, 3 do
			local pole = box("Pole", Vector3.new(0.4, 14, 0.4), p + Vector3.new(6 + i * 7, 7, 4), Color3.fromRGB(220, 220, 220), Enum.Material.Metal, amenity)
			box("Flag", Vector3.new(0.1, 2.5, 4), pole.Position + Vector3.new(0, 5.5, 2), Config.HomeKit, Enum.Material.Fabric, amenity)
		end
	end
end

local function buildAmenitySign(parent: Instance): ProximityPrompt
	local sign = box("AmenitySign", Vector3.new(1, 4, 3), AMENITY_POS + Vector3.new(6, 2, 8),
		Color3.fromRGB(200, 170, 40), Enum.Material.Wood, parent)
	addSign(sign, "CONCOURSE")
	return addPrompt(sign, "Concourse", "Build")
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
	amenityPrompt: ProximityPrompt,
}

-- Every place the club's name is painted in the world (tunnel arch, stand wall).
function WorldBuilder.setClubName(name: string)
	local club = workspace:FindFirstChild("Club")
	if not club then
		return
	end
	for _, d in club:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "ClubName" then
			d.Text = string.upper(name)
		end
	end
end

function WorldBuilder.build(standLevel: number, amenityLevel: number?): World
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
	buildAdBoards(club)
	buildDugouts(club)
	buildTunnel(club)
	buildOffice(club)
	local matchdayPrompt = buildMatchdayBoard(club)
	local standPrompt = buildStandSign(club)
	local amenityPrompt = buildAmenitySign(club)
	WorldBuilder.buildStand(standLevel)
	WorldBuilder.buildAmenity(amenityLevel or 0)
	local state = ReplicatedStorage:FindFirstChild("ClubState")
	if state then
		WorldBuilder.setClubName((state:GetAttribute("ClubName") :: string?) or Config.ClubName)
	end

	return {
		model = club,
		matchdayPrompt = matchdayPrompt,
		standPrompt = standPrompt,
		amenityPrompt = amenityPrompt,
	}
end

return WorldBuilder
