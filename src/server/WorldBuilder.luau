--!strict
-- Builds the grassroots club out of primitive Parts. Intentionally ugly.
--
-- Layout (studs), pitch centred on the origin with its long axis along Z:
--   pitch -> ad boards -> hardstanding (the paved ring fans walk on)
--         -> perimeter wall -> stand plot.
-- The wall line is `Pitch.SIDE_EDGE` beside a touchline and `Pitch.END_EDGE`
-- behind a goal. All four sides are independent plots on the same upgrade
-- chain (Config.StandPlots), so the ground grows asymmetrically. The corners
-- stay open; the north-west one is the turnstile entrance.
-- Scale: ~2.75 studs per metre, so a 105m x 68m pitch is 290 x 190 studs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Assets = require(script.Parent.Assets)

local WorldBuilder = {}

local PITCH_W, PITCH_L = Pitch.WIDTH, Pitch.LENGTH
local GROUND_Y = 0 -- top of the baseplate
local DECK_Y = Pitch.SURFACE_Y -- top of the pitch, and of the paving around it

local SIDE_EDGE = Pitch.SIDE_EDGE -- wall line beside a touchline
local END_EDGE = Pitch.END_EDGE -- wall line behind a goal
-- The walls stop short of the corners, which stay open like a real
-- lower-league ground. These are also the longest a stand on that side can be.
local CORNER_Z = PITCH_L / 2 + 10 -- where the east/west walls stop
local CORNER_X = PITCH_W / 2 + 10 -- where the north/south walls stop
local WALL_H = 3.2
local TUNNEL_GAP = Pitch.TUNNEL_GAP -- players' tunnel mouth, west side, centred

-- Office and forecourt: outside the open north-west corner, so no stand plot
-- has a building in the way. The player spawns inside and walks in through the
-- turnstiles; the footballers use the tunnel on the west side.
local OFFICE_W, OFFICE_D, OFFICE_H = 32, 32, 12
local OFFICE_CX, OFFICE_CZ = -(SIDE_EDGE + 40), -(END_EDGE + 16)
local TURNSTILE_Z = -(CORNER_Z + END_EDGE) / 2 -- middle of the corner gap
-- Paved forecourt outside the west wall line, up to but not over the ring.
local FORECOURT_X0, FORECOURT_X1 = -(SIDE_EDGE + 69), -SIDE_EDGE
local FORECOURT_Z0, FORECOURT_Z1 = -(END_EDGE + 46), -(CORNER_Z - 5)

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
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = target
	return prompt
end

-- Painted on the face of a board rather than floating over it, so signs read
-- as part of the world instead of hovering a few studs off the wall.
local function addSign(target: BasePart, text: string, faces: { Enum.NormalId }?)
	for _, face in faces or { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Sign"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.85
		gui.MaxDistance = 260
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = text
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.14, 0)
		pad.PaddingBottom = UDim.new(0.14, 0)
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.Parent = label
	end
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
		local goalName = zSign < 0 and "GoalNorth" or "GoalSouth"
		-- Creator Store goal with a real net when the place has one; its crossbar is 33 wide
		-- box centre sits 1.75 studs behind the line so the posts land on it; net goes back ~5.6
		local placed = Assets.place("Goal", Vector3.new(0, GROUND_Y + 1, z + zSign * 1.75), pitch, {
			scale = goalW / 33,
			lookAt = Vector3.new(0, GROUND_Y + 1, 0),
			flip = true, -- the model's net is on its look side
			name = goalName,
		})
		if placed then
			for _, d in placed.model:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Name == "COLLIDABLE" then
						d.Transparency = 1
						d.CanCollide = false
					end
					d.CanCollide = false
				end
			end
			continue
		end
		local goal = Instance.new("Model")
		goal.Name = goalName
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

-- The paved ring between the pitch and the walls: the surface fans stand on,
-- the dugouts sit on and every stand fronts onto. Four slabs tile the ring
-- (the ends run full width so the corners are covered), flush with the grass.
local function buildHardstanding(parent: Instance)
	local ground = Instance.new("Model")
	ground.Name = "Hardstanding"
	ground.Parent = parent
	local paving = Color3.fromRGB(148, 146, 140)
	local y = DECK_Y / 2
	local sideW = SIDE_EDGE - PITCH_W / 2
	local endD = END_EDGE - PITCH_L / 2
	for _, xSign in { -1, 1 } do
		box("Side", Vector3.new(sideW, DECK_Y, PITCH_L), Vector3.new(xSign * (PITCH_W / 2 + sideW / 2), y, 0), paving, Enum.Material.Concrete, ground)
	end
	for _, zSign in { -1, 1 } do
		box("End", Vector3.new(SIDE_EDGE * 2, DECK_Y, endD), Vector3.new(0, y, zSign * (PITCH_L / 2 + endD / 2)), paving, Enum.Material.Concrete, ground)
	end
	-- a painted line a couple of studs in from the wall, like a track edge
	local trim = Color3.fromRGB(190, 188, 180)
	for _, xSign in { -1, 1 } do
		box("Trim", Vector3.new(1.2, 0.08, CORNER_Z * 2), Vector3.new(xSign * (SIDE_EDGE - 2), DECK_Y + 0.04, 0), trim, Enum.Material.Concrete, ground)
	end
	for _, zSign in { -1, 1 } do
		box("Trim", Vector3.new(CORNER_X * 2, 0.08, 1.2), Vector3.new(0, DECK_Y + 0.04, zSign * (END_EDGE - 2)), trim, Enum.Material.Concrete, ground)
	end
end

-- Perimeter wall. It stops short of all four corners; the north-west gap is
-- the way in, the other three are closed off with a diagonal panel. The wall
-- is also the front of whatever stand gets built behind it.
local function wallRun(parent: Instance, from: Vector3, to: Vector3, name: string)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local lift = Vector3.new(0, DECK_Y + WALL_H / 2, 0)
	local mid = (from + to) / 2 + lift
	part({
		Name = name,
		Size = Vector3.new(0.8, WALL_H, length),
		CFrame = CFrame.lookAt(mid, mid + delta),
		Color = Color3.fromRGB(96, 98, 104),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})
end

local function buildPerimeter(parent: Instance)
	local wall = Instance.new("Model")
	wall.Name = "Perimeter"
	wall.Parent = parent
	local g = TUNNEL_GAP / 2
	-- east side: continuous
	wallRun(wall, Vector3.new(SIDE_EDGE, 0, -CORNER_Z), Vector3.new(SIDE_EDGE, 0, CORNER_Z), "WallEast")
	-- west side: split around the tunnel mouth
	wallRun(wall, Vector3.new(-SIDE_EDGE, 0, -CORNER_Z), Vector3.new(-SIDE_EDGE, 0, -g), "WallWest")
	wallRun(wall, Vector3.new(-SIDE_EDGE, 0, g), Vector3.new(-SIDE_EDGE, 0, CORNER_Z), "WallWest")
	-- ends: continuous
	for _, zSign in { -1, 1 } do
		wallRun(wall, Vector3.new(-CORNER_X, 0, zSign * END_EDGE), Vector3.new(CORNER_X, 0, zSign * END_EDGE), "WallEnd")
	end
	-- close every corner but the north-west one, which is the entrance
	for _, corner in { { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local sx, sz = corner[1], corner[2]
		wallRun(wall, Vector3.new(sx * SIDE_EDGE, 0, sz * CORNER_Z), Vector3.new(sx * CORNER_X, 0, sz * END_EDGE), "WallCorner")
	end
end

-- Pitch-side advertising boards with fictional sponsors, standing on the
-- hardstanding. The only gap is the tunnel mouth.
local BOARD_H = 3

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
	local y = DECK_Y + BOARD_H / 2
	local offset = 3 -- outside the touchline, standing on the paving
	local segLen = 24
	local index = 0
	for _, xSign in { -1, 1 } do
		local x = xSign * (PITCH_W / 2 + offset)
		local count = math.floor(PITCH_L / segLen)
		for i = 1, count do
			local z = -PITCH_L / 2 + segLen * (i - 0.5)
			-- leave the tunnel mouth clear on the west side
			if xSign < 0 and math.abs(z) < TUNNEL_GAP / 2 + segLen / 2 then
				continue
			end
			index += 1
			-- Front (-Z of the part) must face the pitch: yaw so that -Z points toward x = 0
			local yaw = if xSign < 0 then -math.pi / 2 else math.pi / 2
			sponsorBoard(boards, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), segLen - 1, index)
		end
	end
	for _, zSign in { -1, 1 } do
		local z = zSign * (PITCH_L / 2 + 9)
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

-- Two dugouts on the west hardstanding, flanking the tunnel mouth and set back
-- behind the ad boards the way real ones are.
local DUGOUT_Z = { 16, 40 }

local function buildDugouts(parent: Instance)
	local dugouts = Instance.new("Model")
	dugouts.Name = "Dugouts"
	dugouts.Parent = parent
	-- character scale: ~2.75 studs per metre, so a seat is ~1.3 high and a shelter ~7.5
	local x = -(PITCH_W / 2 + 9)
	local depth = 5.5
	local shelterH = 7.5
	local dark = Color3.fromRGB(45, 45, 50)
	for _, zSign in { -1, 1 } do
		local zc = zSign * (DUGOUT_Z[1] + DUGOUT_Z[2]) / 2
		local len = DUGOUT_Z[2] - DUGOUT_Z[1]
		-- raised concrete step the bench sits on, so it reads as a dugout not a box
		box("Plinth", Vector3.new(depth, 0.6, len), Vector3.new(x - depth / 2 + 1.5, DECK_Y + 0.3, zc), Color3.fromRGB(165, 165, 160), Enum.Material.Concrete, dugouts)
		-- padded bench: seat plus a tall back against the rear wall, in club colours
		box("Seat", Vector3.new(2.2, 0.5, len - 2), Vector3.new(x - 1.2, DECK_Y + 1.55, zc), Config.SeatColor, Enum.Material.Fabric, dugouts)
		box("SeatBase", Vector3.new(2.2, 1.0, len - 2), Vector3.new(x - 1.2, DECK_Y + 1.1, zc), dark, Enum.Material.Plastic, dugouts)
		box("SeatBack", Vector3.new(0.5, 2.6, len - 2), Vector3.new(x - 2.4, DECK_Y + 2.9, zc), Config.SeatColor, Enum.Material.Fabric, dugouts)
		-- rear wall and end posts carry the perspex shelter
		box("RearWall", Vector3.new(0.4, shelterH, len), Vector3.new(x - depth + 1.5, DECK_Y + shelterH / 2, zc), dark, Enum.Material.Metal, dugouts)
		for _, zEnd in { -1, 1 } do
			local zEdge = zc + zEnd * (len / 2 - 0.2)
			box("Post", Vector3.new(0.4, shelterH, 0.4), Vector3.new(x + 1.3, DECK_Y + shelterH / 2, zEdge), dark, Enum.Material.Metal, dugouts)
			local side = box("Side", Vector3.new(depth - 0.4, shelterH - 0.6, 0.3), Vector3.new(x - depth / 2 + 1.5, DECK_Y + shelterH / 2, zEdge), Color3.fromRGB(190, 215, 235), Enum.Material.Glass, dugouts)
			side.Transparency = 0.45
		end
		local roof = box("Shelter", Vector3.new(depth + 0.6, 0.35, len + 0.4), Vector3.new(x - depth / 2 + 1.5, DECK_Y + shelterH, zc), Color3.fromRGB(190, 215, 235), Enum.Material.Glass, dugouts)
		roof.Transparency = 0.3
		box("RoofFrame", Vector3.new(depth + 0.8, 0.5, 0.5), Vector3.new(x - depth / 2 + 1.5, DECK_Y + shelterH + 0.2, zc), dark, Enum.Material.Metal, dugouts)
	end
end

-- The tunnel: a mouth in the middle of the west wall with the club name over
-- it. Only the footballers use it; the player walks in at the turnstiles.
local function buildTunnel(parent: Instance)
	local tunnel = Instance.new("Model")
	tunnel.Name = "Tunnel"
	tunnel.Parent = parent
	local x = -SIDE_EDGE
	local h = 11
	local w = TUNNEL_GAP
	local colour = Config.HomeKit
	local dark = Color3.fromRGB(55, 55, 60)
	for _, zSign in { -1, 1 } do
		box("Jamb", Vector3.new(7, h, 2.4), Vector3.new(x - 3, DECK_Y + h / 2, zSign * (w / 2 + 1.2)), colour, Enum.Material.SmoothPlastic, tunnel)
	end
	local header = box("Header", Vector3.new(7, 3, w + 4.8), Vector3.new(x - 3, DECK_Y + h + 1.5, 0), colour, Enum.Material.SmoothPlastic, tunnel)
	box("HeaderTrim", Vector3.new(7.3, 0.4, w + 5.1), Vector3.new(x - 3, DECK_Y + h + 3.2, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, tunnel)
	-- the mouth recedes away from the pitch, so it reads as a tunnel not a doorway
	box("Throat", Vector3.new(14, 0.6, w), Vector3.new(x - 13, DECK_Y + h, 0), dark, Enum.Material.Concrete, tunnel)
	for _, zSign in { -1, 1 } do
		box("ThroatWall", Vector3.new(14, h, 0.8), Vector3.new(x - 13, DECK_Y + h / 2, zSign * (w / 2)), dark, Enum.Material.Concrete, tunnel)
	end
	box("ThroatFloor", Vector3.new(14, DECK_Y, w), Vector3.new(x - 13, DECK_Y / 2, 0), Color3.fromRGB(130, 128, 122), Enum.Material.Concrete, tunnel)

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
	pad.Parent = label
end

-- Turnstile block in the open north-west corner: how the player gets in.
local function buildTurnstiles(parent: Instance)
	local gate = Instance.new("Model")
	gate.Name = "Turnstiles"
	gate.Parent = parent
	local x = -SIDE_EDGE
	local h = 9
	local lanes, laneW, pierW = 3, 5, 2.4
	local total = lanes * laneW + (lanes + 1) * pierW
	local dark = Color3.fromRGB(60, 60, 65)
	for i = 0, lanes do
		local z = TURNSTILE_Z - total / 2 + pierW / 2 + i * (laneW + pierW)
		box("Pier", Vector3.new(7, h, pierW), Vector3.new(x - 1, DECK_Y + h / 2, z), Config.HomeKit, Enum.Material.SmoothPlastic, gate)
	end
	for i = 1, lanes do
		local z = TURNSTILE_Z - total / 2 + pierW + laneW / 2 + (i - 1) * (laneW + pierW)
		-- a waist-high drum either side of the lane, so it reads as a turnstile
		for _, side in { -1, 1 } do
			local drum = box("Drum", Vector3.new(1.6, 3.4, 0.8), Vector3.new(x - 1, DECK_Y + 1.7, z + side * (laneW / 2 - 0.5)), Color3.fromRGB(150, 150, 155), Enum.Material.Metal, gate)
			drum.CanCollide = false
		end
	end
	local fascia = box("Fascia", Vector3.new(8, 3.2, total), Vector3.new(x - 1, DECK_Y + h + 1.6, TURNSTILE_Z), Config.HomeKit, Enum.Material.SmoothPlastic, gate)
	box("Roof", Vector3.new(9, 0.5, total + 1), Vector3.new(x - 1.5, DECK_Y + h + 3.4, TURNSTILE_Z), dark, Enum.Material.Metal, gate)
	-- club name across the outside face, where the player walks up
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 22
	gui.LightInfluence = 0.85
	gui.Parent = fascia
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
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = label
end

-- Paved forecourt outside the corner, with the car park. Everything the club
-- does away from the pitch (office, matchday board, concourse) sits on it.
local function buildForecourt(parent: Instance)
	local yard = Instance.new("Model")
	yard.Name = "Forecourt"
	yard.Parent = parent
	local w = FORECOURT_X1 - FORECOURT_X0
	local d = FORECOURT_Z1 - FORECOURT_Z0
	box("Paving", Vector3.new(w, DECK_Y, d), Vector3.new((FORECOURT_X0 + FORECOURT_X1) / 2, DECK_Y / 2, (FORECOURT_Z0 + FORECOURT_Z1) / 2),
		Color3.fromRGB(138, 136, 132), Enum.Material.Concrete, yard)
	-- car park bays between the office and the corner
	local bayZ = FORECOURT_Z1 - 13
	for i = 0, 5 do
		local bx = FORECOURT_X0 + 12 + i * 9
		box("Bay", Vector3.new(0.6, 0.08, 18), Vector3.new(bx, DECK_Y + 0.04, bayZ), Color3.fromRGB(215, 212, 200), Enum.Material.Concrete, yard)
	end
end

local OFFICE_Y = DECK_Y + 0.1 -- office floor, a touch proud of the forecourt paving

local function buildOffice(parent: Instance)
	local office = Instance.new("Model")
	office.Name = "Office"
	office.Parent = parent

	local w, d, h = OFFICE_W, OFFICE_D, OFFICE_H
	-- door faces east, toward the turnstiles and the ground
	local cx, cz = OFFICE_CX, OFFICE_CZ
	local wallColor = Color3.fromRGB(170, 160, 135) -- stained beige
	local wallMat = Enum.Material.Concrete

	box("Floor", Vector3.new(w, 1, d), Vector3.new(cx, OFFICE_Y - 0.5, cz),
		Color3.fromRGB(95, 80, 60), Enum.Material.WoodPlanks, office)
	box("Roof", Vector3.new(w + 2, 1, d + 2), Vector3.new(cx, OFFICE_Y + h + 0.5, cz),
		Color3.fromRGB(70, 70, 70), Enum.Material.Slate, office)

	local wy = OFFICE_Y + h / 2
	box("WallW", Vector3.new(1, h, d), Vector3.new(cx - w / 2, wy, cz), wallColor, wallMat, office)
	box("WallN", Vector3.new(w, h, 1), Vector3.new(cx, wy, cz - d / 2), wallColor, wallMat, office)
	box("WallS", Vector3.new(w, h, 1), Vector3.new(cx, wy, cz + d / 2), wallColor, wallMat, office)
	-- east wall has a doorway facing the ground
	local doorW = 8
	local segLen = (d - doorW) / 2
	box("WallE1", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz - (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("WallE2", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz + (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("DoorHeader", Vector3.new(1, 3, doorW), Vector3.new(cx + w / 2, OFFICE_Y + h - 1.5, cz), wallColor, wallMat, office)

	-- furniture
	local desk = box("Desk", Vector3.new(4, 3, 10), Vector3.new(cx - 8, OFFICE_Y + 1.5, cz),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood, office)
	local computer = box("Computer", Vector3.new(1, 2, 2.5), Vector3.new(cx - 8, desk.Position.Y + 1.5 + 1, cz),
		Color3.fromRGB(200, 200, 190), Enum.Material.Plastic, office)
	-- Club management lives on the office computer. The client opens the panel
	-- when this prompt fires (ProximityPromptService.PromptTriggered).
	local clubPrompt = addPrompt(computer, "Club Office", "Manage squad, scouting & staff")
	clubPrompt.Name = "ClubPrompt"
	clubPrompt.HoldDuration = 0
	box("Chair", Vector3.new(2, 2, 2), Vector3.new(cx - 11.5, OFFICE_Y + 1, cz),
		Color3.fromRGB(60, 60, 60), Enum.Material.Fabric, office)

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = Color3.fromRGB(255, 235, 200)
	light.Parent = box("Bulb", Vector3.new(1, 0.5, 1), Vector3.new(cx, OFFICE_Y + h - 1, cz),
		Color3.fromRGB(255, 240, 200), Enum.Material.Neon, office)

	-- spawn inside the office, facing the door
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OfficeSpawn"
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = CFrame.new(cx + 2, OFFICE_Y + 0.5, cz) * CFrame.Angles(0, -math.pi / 2, 0)
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
	local shelfY = OFFICE_Y + 7
	local shelfZ = OFFICE_CZ - OFFICE_D / 2 + 1.5
	box("Shelf", Vector3.new(shelfLen, 0.5, 2), Vector3.new(OFFICE_CX, shelfY, shelfZ),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood, model)

	local gold = Color3.fromRGB(230, 190, 60)
	local spacing = 3
	local startX = OFFICE_CX - (shown - 1) * spacing / 2
	for i = 1, shown do
		local x = startX + (i - 1) * spacing
		-- generated trophy mesh when the place has it (README "Assets"), else a primitive cup
		local placed = Assets.place("Trophy", Vector3.new(x, shelfY + 0.25, shelfZ), model, {
			height = 2.2,
			lookAt = Vector3.new(x, shelfY, OFFICE_CZ),
			name = "Trophy" .. i,
		})
		if placed then
			continue
		end
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
	-- On the forecourt, on the walk from the office door to the turnstiles.
	local post = box("MatchdayBoard", Vector3.new(6, 5, 0.8), Vector3.new(OFFICE_CX + 23, DECK_Y + 3.5, OFFICE_CZ + 9),
		Color3.fromRGB(30, 60, 30), Enum.Material.Wood, parent)
	addSign(post, "MATCHDAY")
	return addPrompt(post, "Matchday Board", "Play Match")
end

-- ---------------------------------------------------------------- stand plots

local PLOTS = Config.StandPlots

-- Every stand is built in a local frame where +X points away from the pitch,
-- +Z runs along the stand and the origin sits on the wall line at ground
-- level. One builder then serves all four sides.
-- Returns the frame and the longest a stand on that side can be.
local function plotFrame(plot: any): (CFrame, number)
	if plot.axis == "Z" then -- east or west side, stand runs along Z
		local yaw = if plot.sign > 0 then 0 else math.pi
		return CFrame.new(plot.sign * SIDE_EDGE, GROUND_Y, 0) * CFrame.Angles(0, yaw, 0), CORNER_Z * 2
	end
	-- north or south end, stand runs along X
	local yaw = if plot.sign < 0 then math.pi / 2 else -math.pi / 2
	return CFrame.new(0, GROUND_Y, plot.sign * END_EDGE) * CFrame.Angles(0, yaw, 0), CORNER_X * 2
end

local STEP_DEPTH = 3 -- one row of seats, ~1.1 m at 2.75 studs/m
local STAND_X0 = 0.6 -- stands start just behind the perimeter wall, which is their front

-- One entry per Config.StandLevels level. `lengthFrac` is of the plot's max.
local STAND_SPECS = {
	{ lengthFrac = 0.21, rows = 3, stepHeight = 1.5, roof = false, seats = false },
	{ lengthFrac = 0.66, rows = 8, stepHeight = 1.5, roof = false, seats = true },
	{ lengthFrac = 0.82, rows = 12, stepHeight = 1.5, roof = false, seats = true },
	{ lengthFrac = 0.94, rows = 16, stepHeight = 1.5, roof = true, seats = true },
}

-- Geometry for one plot at one level, in the plot's local frame. Shared by the
-- builder and the crowd filler so fans always land on the actual steps.
type PlotGeometry = {
	frame: CFrame,
	length: number,
	rows: number,
	stepHeight: number,
	spans: { { number } }, -- runs of seating along local Z, split around any gap
	spec: any,
}

local function plotGeometry(plot: any, level: number): PlotGeometry?
	if level < 1 then
		return nil
	end
	local spec = STAND_SPECS[math.clamp(level, 1, #STAND_SPECS)]
	local frame, maxLength = plotFrame(plot)
	local length = math.floor(maxLength * spec.lengthFrac)
	local half = length / 2
	local spans: { { number } }
	if plot.key == "West" then
		-- the west stand is split around the tunnel mouth
		local g = TUNNEL_GAP / 2 + 3
		spans = if half > g + 8 then { { -half, -g }, { g, half } } else {}
	else
		spans = { { -half, half } }
	end
	return { frame = frame, length = length, rows = spec.rows, stepHeight = spec.stepHeight, spans = spans, spec = spec }
end

function WorldBuilder.buildPlot(plotIndex: number, level: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local stands = club:FindFirstChild("Stands") :: Folder
	local plot = PLOTS[plotIndex]
	local old = stands:FindFirstChild(plot.key)
	if old then
		old:Destroy()
	end

	local stand = Instance.new("Model")
	stand.Name = plot.key
	stand.Parent = stands
	stand:SetAttribute("Level", level)

	-- empty crowd folder; filled at kickoff. Always present, even at level 0.
	local crowd = Instance.new("Folder")
	crowd.Name = "Crowd"
	crowd.Parent = stand

	local geo = plotGeometry(plot, level)
	if not geo then
		return -- empty plot: open hardstanding behind the perimeter wall
	end
	local frame, rows, stepHeight, spec = geo.frame, geo.rows, geo.stepHeight, geo.spec

	-- local-frame helper: +X away from the pitch, +Z along the stand
	local function lbox(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
		return part({
			Name = name,
			Size = size,
			CFrame = frame * CFrame.new(pos),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = stand,
		})
	end

	local stepColor = if level == 1 then Color3.fromRGB(150, 150, 150) else Color3.fromRGB(175, 175, 172)
	local stepMat = if level == 1 then Enum.Material.Metal else Enum.Material.Concrete
	local sectionLen, aisleW = 26, 3
	local depth = STEP_DEPTH * rows

	for _, span in geo.spans do
		local z0, z1 = span[1], span[2]
		local runLen = z1 - z0
		local zc = (z0 + z1) / 2
		local sections = math.max(1, math.floor((runLen + aisleW) / (sectionLen + aisleW)))
		local usedLen = sections * sectionLen + (sections - 1) * aisleW
		local startZ = zc - usedLen / 2

		for i = 1, rows do
			local height = stepHeight * i
			local rowX = STAND_X0 + STEP_DEPTH * (i - 1) + STEP_DEPTH / 2
			local stepBack = STAND_X0 + STEP_DEPTH * i -- back edge of this step
			lbox(("Row%d"):format(i), Vector3.new(STEP_DEPTH, DECK_Y + height, runLen),
				Vector3.new(rowX, (DECK_Y + height) / 2, zc), stepColor, stepMat)
			if spec.seats then
				-- seat blocks per section; an alternate shade every other section so the
				-- seating reads as blocks rather than one long strip
				for s = 1, sections do
					local z = startZ + (s - 1) * (sectionLen + aisleW) + sectionLen / 2
					local colour = if s % 2 == 0 then Config.SeatColor:Lerp(Color3.new(1, 1, 1), 0.25) else Config.SeatColor
					local seat = lbox(("Seats%d_%d"):format(i, s), Vector3.new(1.6, 1.1, sectionLen),
						Vector3.new(stepBack - 0.8, DECK_Y + height + 0.55, z), colour, Enum.Material.Plastic)
					seat.CanCollide = false
					local back = lbox(("SeatBack%d_%d"):format(i, s), Vector3.new(0.3, 1.6, sectionLen),
						Vector3.new(stepBack - 0.15, DECK_Y + height + 0.8, z), colour, Enum.Material.Plastic)
					back.CanCollide = false
				end
				-- aisle treads between sections, lighter so they read as steps
				for s = 1, sections - 1 do
					local z = startZ + s * (sectionLen + aisleW) - aisleW / 2
					local tread = lbox(("Aisle%d_%d"):format(i, s), Vector3.new(STEP_DEPTH, 0.2, aisleW),
						Vector3.new(rowX, DECK_Y + height + 0.1, z), Color3.fromRGB(215, 215, 210), Enum.Material.Concrete)
					tread.CanCollide = false
				end
			else
				-- level 1: a plank bench along each bleacher row
				lbox(("Bench%d"):format(i), Vector3.new(1.8, 0.4, runLen - 2),
					Vector3.new(stepBack - 0.9, DECK_Y + height + 0.2, zc),
					Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
			end
		end

		-- End walls. A WedgePart is full height at its local +Z and tapers to
		-- nothing at -Z, so the slope has to rise AWAY from the pitch: yaw +90
		-- sends local +Z along local +X (outward). Getting this backwards is
		-- what made the side panels look inside out.
		local wallH = stepHeight * rows
		for _, zEnd in { z0, z1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "EndWall"
			wedge.Anchored = true
			wedge.Size = Vector3.new(0.8, wallH, depth)
			wedge.CFrame = frame * CFrame.new(STAND_X0 + depth / 2, DECK_Y + wallH / 2, zEnd) * CFrame.Angles(0, math.pi / 2, 0)
			wedge.Color = Color3.fromRGB(200, 200, 200)
			wedge.Material = Enum.Material.Concrete
			wedge.Parent = stand
		end
	end

	if level >= 2 then
		local length = geo.length
		local wallH = stepHeight * rows + 3
		local backX = STAND_X0 + depth + 0.5
		lbox("BackWall", Vector3.new(1, wallH, length), Vector3.new(backX, DECK_Y + wallH / 2, 0),
			Color3.fromRGB(200, 200, 200), Enum.Material.Concrete)

		if spec.roof then
			-- cantilever roof over the seats, held by pillars along the back wall
			local roofY = DECK_Y + stepHeight * rows + 8
			local roofDepth = depth + 4
			lbox("Roof", Vector3.new(roofDepth, 0.8, length + 4), Vector3.new(roofDepth / 2 - 2, roofY, 0),
				Color3.fromRGB(168, 172, 178), Enum.Material.Metal)
			-- fascia across the front of the roof: the obvious place for the club name
			local fascia = lbox("Fascia", Vector3.new(0.7, 2.6, length + 4), Vector3.new(roofDepth - 2, roofY + 1.7, 0),
				Config.HomeKit, Enum.Material.SmoothPlastic)
			local gui = Instance.new("SurfaceGui")
			gui.Name = "NameGui"
			gui.Face = Enum.NormalId.Left -- -X local, toward the pitch
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 16
			gui.LightInfluence = 0.9
			gui.Parent = fascia
			local label = Instance.new("TextLabel")
			label.Name = "ClubName"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = "" -- WorldBuilder.setClubName fills it
			label.Parent = gui
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.18, 0)
			pad.PaddingBottom = UDim.new(0.18, 0)
			pad.Parent = label
			for i = 0, 6 do
				local z = -length / 2 + (length / 6) * i
				lbox("Pillar", Vector3.new(1.5, roofY - DECK_Y, 1.5), Vector3.new(backX + 1.5, DECK_Y + (roofY - DECK_Y) / 2, z),
					Color3.fromRGB(120, 120, 130), Enum.Material.Metal)
			end
		end
	end

	local state = ReplicatedStorage:FindFirstChild("ClubState")
	if state then
		WorldBuilder.setClubName((state:GetAttribute("ClubName") :: string?) or Config.ClubName)
	end
end

-- Rebuilds every plot. `levels` is keyed by Config.StandPlots[i].key.
function WorldBuilder.buildStands(levels: { [string]: number })
	for i, plot in PLOTS do
		WorldBuilder.buildPlot(i, levels[plot.key] or 0)
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
local FAN_SPACING = 2.6 -- seated fans at character scale need this much elbow room
-- Fan budget for a full house across the whole ground (mobile); 2 parts each.
local MAX_FAN_BLOCKS = 600

-- Fills every built stand with simple block fans at a density matching
-- attendance. One block stands for several fans, so a full house means every
-- slot filled. The budget is shared across all four plots.
function WorldBuilder.buildCrowd(levels: { [string]: number }, attendance: number, capacity: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local stands = club:FindFirstChild("Stands") :: Folder
	local fill = math.clamp(attendance / math.max(capacity, 1), 0, 1)
	local rng = Random.new(attendance)

	-- count the seat slots first, so the block budget is shared across the ground
	local totalSlots = 0
	for _, plot in PLOTS do
		local geo = plotGeometry(plot, levels[plot.key] or 0)
		if geo then
			for _, span in geo.spans do
				totalSlots += math.floor((span[2] - span[1] - 2) / FAN_SPACING) * geo.rows
			end
		end
	end
	local spacing = FAN_SPACING
	if totalSlots > MAX_FAN_BLOCKS then
		spacing = FAN_SPACING * totalSlots / MAX_FAN_BLOCKS
	end

	local placed, slots = 0, 0
	for _, plot in PLOTS do
		local stand = stands:FindFirstChild(plot.key)
		local crowd = stand and stand:FindFirstChild("Crowd")
		if not crowd then
			continue
		end
		crowd:ClearAllChildren()
		local geo = plotGeometry(plot, levels[plot.key] or 0)
		if not geo then
			continue
		end
		for _, span in geo.spans do
			local perRow = math.floor((span[2] - span[1] - 2) / spacing)
			slots += perRow * geo.rows
			for row = 1, geo.rows do
				local top = DECK_Y + geo.stepHeight * row
				-- sit toward the front of the step so heads clear the row behind
				local x = STAND_X0 + STEP_DEPTH * (row - 1) + STEP_DEPTH / 2 - 0.5
				for i = 1, perRow do
					-- deterministic scatter: skip seats so density visibly tracks attendance
					if rng:NextNumber() > fill then
						continue
					end
					local z = span[1] + 1 + spacing * (i - 0.5)
					-- seated fan at character scale (a standing character is ~5 studs):
					-- torso block plus a head; a little height jitter so rows do not look stamped
					local bodyH = 2.6 + rng:NextNumber(-0.2, 0.2)
					part({
						Name = "Fan",
						Size = Vector3.new(1.8, bodyH, 1.4),
						CFrame = geo.frame * CFrame.new(x, top + 0.9 + bodyH / 2, z),
						Color = CROWD_COLORS[rng:NextInteger(1, #CROWD_COLORS)],
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
						CastShadow = false,
						Parent = crowd,
					})
					part({
						Name = "Head",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(1.2, 1.2, 1.2),
						CFrame = geo.frame * CFrame.new(x, top + 0.9 + bodyH + 0.6, z),
						Color = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)],
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
						CastShadow = false,
						Parent = crowd,
					})
					placed += 1
				end
			end
		end
	end
	club:SetAttribute("CrowdSlots", slots)
	club:SetAttribute("CrowdCount", placed)
end

-- Fans go home at full time; the stands are empty between matches.
function WorldBuilder.clearCrowd()
	local club = workspace:FindFirstChild("Club")
	local stands = club and club:FindFirstChild("Stands")
	if not (club and stands) then
		return
	end
	for _, stand in stands:GetChildren() do
		local crowd = stand:FindFirstChild("Crowd")
		if crowd then
			crowd:ClearAllChildren()
		end
	end
	club:SetAttribute("CrowdCount", 0)
end

-- Concourse amenity chain (snack bar -> club shop -> fan zone), on the
-- forecourt between the office and the turnstiles. Rebuilt on each upgrade.
local AMENITY_POS = Vector3.new(OFFICE_CX - 2, GROUND_Y, OFFICE_CZ + 23)

function WorldBuilder.buildAmenity(level: number)
	local club = workspace:FindFirstChild("Club") :: Model
	local old = club:FindFirstChild("Amenity")
	if old then
		old:Destroy()
	end
	local amenity = Instance.new("Model")
	amenity.Name = "Amenity"
	amenity.Parent = club
	local p = AMENITY_POS + Vector3.new(0, DECK_Y, 0)
	if level >= 1 then
		-- snack bar: hut with a serving hatch and a striped awning
		box("Hut", Vector3.new(10, 7, 8), p + Vector3.new(0, 3.5, 0), Color3.fromRGB(190, 120, 70), Enum.Material.Wood, amenity)
		box("Hatch", Vector3.new(0.3, 3, 5), p + Vector3.new(5.1, 4, 0), Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic, amenity)
		box("Awning", Vector3.new(5, 0.3, 9), p + Vector3.new(7, 6.5, 0), Color3.fromRGB(220, 60, 60), Enum.Material.Fabric, amenity)
		box("Counter", Vector3.new(2, 1, 6), p + Vector3.new(6, 2.5, 0), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, amenity)
	end
	if level >= 2 then
		-- club shop: larger unit beside the hut, club-coloured facade
		box("Shop", Vector3.new(12, 9, 12), p + Vector3.new(-1, 4.5, 14), Color3.fromRGB(220, 220, 225), Enum.Material.Concrete, amenity)
		box("ShopFascia", Vector3.new(0.4, 2.5, 12), p + Vector3.new(5.2, 8, 14), Config.HomeKit, Enum.Material.SmoothPlastic, amenity)
		local window = box("ShopWindow", Vector3.new(0.3, 4, 8), p + Vector3.new(5.1, 4, 14), Color3.fromRGB(150, 200, 230), Enum.Material.Glass, amenity)
		window.Transparency = 0.4
	end
	if level >= 3 then
		-- fan zone: paved square with flag poles and a small stage, growing
		-- away from the ground (further -X) so nothing blocks the way in
		box("Paving", Vector3.new(30, 0.3, 24), p + Vector3.new(-13, 0.15, 7), Color3.fromRGB(160, 160, 150), Enum.Material.Cobblestone, amenity)
		box("Stage", Vector3.new(10, 2, 6), p + Vector3.new(-22, 1, 14), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, amenity)
		for i = 0, 3 do
			local pole = box("Pole", Vector3.new(0.4, 14, 0.4), p + Vector3.new(-(6 + i * 7), 7, -4), Color3.fromRGB(220, 220, 220), Enum.Material.Metal, amenity)
			box("Flag", Vector3.new(0.1, 2.5, 4), pole.Position + Vector3.new(0, 5.5, 2), Config.HomeKit, Enum.Material.Fabric, amenity)
		end
	end
end

local function buildAmenitySign(parent: Instance): ProximityPrompt
	local sign = box("AmenitySign", Vector3.new(5, 4, 0.8), AMENITY_POS + Vector3.new(9, DECK_Y + 3, -7),
		Color3.fromRGB(200, 170, 40), Enum.Material.Wood, parent)
	addSign(sign, "CONCOURSE")
	return addPrompt(sign, "Concourse", "Build")
end

-- One upgrade sign per plot, standing on the hardstanding in front of it, so
-- the player has to walk round the ground to find them.
local SIGN_OFFSET: { [string]: number } = { East = 40, West = -60, North = -34, South = 34 }

local function buildStandSign(parent: Instance, plot: any): ProximityPrompt
	local frame = plotFrame(plot)
	local sign = part({
		Name = "StandSign_" .. plot.key,
		Size = Vector3.new(0.8, 4, 6),
		CFrame = frame * CFrame.new(-6, DECK_Y + 3, SIGN_OFFSET[plot.key] or 0),
		Color = Color3.fromRGB(200, 170, 40),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	addSign(sign, string.upper(plot.label), { Enum.NormalId.Left, Enum.NormalId.Right })
	return addPrompt(sign, plot.label, "Expand")
end

export type World = {
	model: Model,
	matchdayPrompt: ProximityPrompt,
	standPrompts: { [string]: ProximityPrompt },
	amenityPrompt: ProximityPrompt,
}

-- Every place the club's name is painted in the world (tunnel, turnstiles,
-- roof fascias).
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

function WorldBuilder.build(standLevels: { [string]: number }, amenityLevel: number?): World
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
	buildHardstanding(club)
	buildPerimeter(club)
	buildAdBoards(club)
	buildDugouts(club)
	buildTunnel(club)
	buildTurnstiles(club)
	buildForecourt(club)
	buildOffice(club)
	-- the team coach, parked on the forecourt beside the office (decorative)
	Assets.place("Bus", Vector3.new(OFFICE_CX + 18, DECK_Y, OFFICE_CZ - 22), club, {
		lookAt = Vector3.new(OFFICE_CX + 80, DECK_Y, OFFICE_CZ - 22),
		flip = true, -- windscreen is on the model's far side
		name = "TeamBus",
	})

	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = club

	local matchdayPrompt = buildMatchdayBoard(club)
	local standPrompts: { [string]: ProximityPrompt } = {}
	for _, plot in PLOTS do
		standPrompts[plot.key] = buildStandSign(club, plot)
	end
	local amenityPrompt = buildAmenitySign(club)
	WorldBuilder.buildStands(standLevels)
	WorldBuilder.buildAmenity(amenityLevel or 0)
	local state = ReplicatedStorage:FindFirstChild("ClubState")
	if state then
		WorldBuilder.setClubName((state:GetAttribute("ClubName") :: string?) or Config.ClubName)
	end

	return {
		model = club,
		matchdayPrompt = matchdayPrompt,
		standPrompts = standPrompts,
		amenityPrompt = amenityPrompt,
	}
end

return WorldBuilder
