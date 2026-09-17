--!strict
-- Builds the grassroots club out of primitive Parts. Intentionally ugly.
--
-- Layout (studs), pitch centred on the origin with its long axis along Z:
--   pitch -> turf run-off -> ad boards -> hardstanding (the paved ring fans
--         walk on) -> perimeter wall -> stand plot.
-- The turf carries on `Pitch.GRASS_MARGIN` past the markings, so the nets, the
-- technical areas and the corner flags all stand on grass and the paving never
-- starts at the touchline. The wall line is `Pitch.SIDE_EDGE` beside a
-- touchline and `Pitch.END_EDGE` behind a goal. All four sides are independent
-- plots on the same upgrade chain (Config.StandPlots), so the ground grows
-- asymmetrically. The corners stay open; the north-west one is the turnstile
-- entrance.
--
-- The west side is the way in and out. The tunnel runs from the middle of the
-- west wall straight back through the stand to the dressing rooms and the
-- office, where the player spawns. The terrace stops against the tunnel's own
-- side walls and carries over its roof once the stand is tall enough, so the
-- only hole in that stand is the mouth itself.
-- Scale: ~2.75 studs per metre, so a 105m x 68m pitch is 290 x 190 studs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Assets = require(script.Parent.Assets)
local PlotContext = require(script.Parent.PlotContext)

local WorldBuilder = {}

local PITCH_W, PITCH_L = Pitch.WIDTH, Pitch.LENGTH
local GROUND_Y = 0 -- top of the baseplate
local DECK_Y = Pitch.SURFACE_Y -- top of the pitch, and of the paving around it

local GRASS_X = Pitch.GRASS_EDGE_X -- where the turf stops and the paving starts
local GRASS_Z = Pitch.GRASS_EDGE_Z
local SIDE_EDGE = Pitch.SIDE_EDGE -- wall line beside a touchline
local END_EDGE = Pitch.END_EDGE -- wall line behind a goal
-- The walls stop short of the corners, which stay open like a real
-- lower-league ground. These are also the longest a stand on that side can be.
local CORNER_Z = PITCH_L / 2 + 10 -- where the east/west walls stop
local CORNER_X = PITCH_W / 2 + 10 -- where the north/south walls stop
local WALL_H = 3.2
local TUNNEL_GAP = Pitch.TUNNEL_GAP -- players' tunnel mouth, west side, centred

-- The west block. The tunnel does not stop at the wall: it runs straight back
-- through the gap in the west stand into the building behind it, where the
-- dressing rooms are and, at the far end, the office. The player spawns in the
-- office and walks out down the tunnel onto the pitch, which is also how the
-- team comes out.
local TUNNEL_H = 9
local TUNNEL_HALF = TUNNEL_GAP / 2 -- inner face of a corridor wall
local WALL_T = 0.8
local TUNNEL_OUT = TUNNEL_HALF + WALL_T -- outer face; the terrace stops here
local PORTAL_D = 4 -- club-coloured surround at the mouth
local CORRIDOR_END = -(SIDE_EDGE + 94) -- the office door
local OFFICE_W, OFFICE_D, OFFICE_H = 28, 30, 12 -- W runs along X, D along Z
local OFFICE_CX, OFFICE_CZ = CORRIDOR_END - OFFICE_W / 2, 0
-- Dressing rooms, one either side of the corridor, clear of the deepest a west
-- stand can ever reach (STAND_X0 + 16 rows * STEP_DEPTH + roof).
local ROOM_X0, ROOM_X1 = -(SIDE_EDGE + 90), -(SIDE_EDGE + 62)
local ROOM_DEPTH = 28 -- how far a room reaches out from the corridor wall
local ROOM_DOOR = { -(SIDE_EDGE + 78), -(SIDE_EDGE + 70) } -- gap in the corridor wall

-- Forecourt: outside the open north-west corner, where the turnstiles, the
-- concourse and the car park are. The player only comes here to spend money.
local FORECOURT_CX, FORECOURT_CZ = -(SIDE_EDGE + 40), -(END_EDGE + 16)
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
	-- Turf run-off: unmown grass carrying on past the markings, so the paving
	-- does not start at the touchline. A ring of four slabs, level with the
	-- pitch and never overlapping it, so nothing z-fights with the stripes.
	local runOff = Color3.fromRGB(80, 138, 60)
	local margin = Pitch.GRASS_MARGIN
	for _, xSign in { -1, 1 } do
		box("RunOffSide", Vector3.new(margin, DECK_Y, PITCH_L), Vector3.new(xSign * (PITCH_W / 2 + margin / 2), DECK_Y / 2, 0),
			runOff, Enum.Material.Grass, pitch)
	end
	for _, zSign in { -1, 1 } do
		box("RunOffEnd", Vector3.new(GRASS_X * 2, DECK_Y, margin), Vector3.new(0, DECK_Y / 2, zSign * (PITCH_L / 2 + margin / 2)),
			runOff, Enum.Material.Grass, pitch)
	end

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

	-- X235: corner arcs (1m -> ~3 studs) round each flag, from pitch-board.png.
	-- Centred where the touchline and goal line cross; 5 overlapping segments a
	-- quarter (3 read as a bracket with a gap at this small radius).
	-- Lifted a hair above the lines so the overlapping ends don't z-fight.
	for _, zSign in { -1, 1 } do
		for _, xSign in { -1, 1 } do
			local cx, cz = xSign * (PITCH_W / 2 - lineW / 2), zSign * (PITCH_L / 2 - lineW / 2)
			local towardCentre = math.atan2(-zSign, -xSign)
			local radius = 3
			for i = 1, 5 do
				local a0 = towardCentre - math.pi / 4 + (math.pi / 2) * (i - 1) / 5
				local a1 = towardCentre - math.pi / 4 + (math.pi / 2) * i / 5
				local mid = (a0 + a1) / 2
				part({
					Name = "CornerArc",
					Size = Vector3.new(radius * (a1 - a0) + 0.6, 0.1, lineW),
					CFrame = CFrame.new(cx + math.cos(mid) * radius, lineY + 0.01, cz + math.sin(mid) * radius) * CFrame.Angles(0, -mid - math.pi / 2, 0),
					Color = white,
					Material = Enum.Material.SmoothPlastic,
					Parent = pitch,
				})
			end
		end
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
	-- starts at the edge of the turf run-off, not at the touchline
	local sideW = SIDE_EDGE - GRASS_X
	local endD = END_EDGE - GRASS_Z
	for _, xSign in { -1, 1 } do
		box("Side", Vector3.new(sideW, DECK_Y, GRASS_Z * 2), Vector3.new(xSign * (GRASS_X + sideW / 2), y, 0), paving, Enum.Material.Concrete, ground)
	end
	for _, zSign in { -1, 1 } do
		box("End", Vector3.new(SIDE_EDGE * 2, DECK_Y, endD), Vector3.new(0, y, zSign * (GRASS_Z + endD / 2)), paving, Enum.Material.Concrete, ground)
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
	local g = TUNNEL_OUT -- the tunnel's own walls close the gap
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

-- Dugouts. `DUGOUT_Z` is the near and far edge of a bench, mirrored about
-- z = 0; the technical area is the marked box in front of it, which by the
-- laws runs a metre past the seats at each end (~2.75 studs).
local DUGOUT_Z = Pitch.DUGOUT_Z
local DUGOUT_FRONT = -Pitch.DUGOUT_FRONT -- distance from the centre line, positive
local TECHNICAL_Z = { DUGOUT_Z[1] - 3, DUGOUT_Z[2] + 3 }
local STAND_BRICK = Color3.fromRGB(150, 84, 62) -- X134: the turnstiles' brick, on the stands, dugouts and tunnel

-- Pitch-side advertising boards with fictional sponsors, standing on the front
-- edge of the paving. The gaps are the tunnel mouth and the two dugouts.
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
	local segLen = 24
	local index = 0
	for _, xSign in { -1, 1 } do
		-- on the front edge of the paving, so the turf run-off is left clear
		local x = xSign * (GRASS_X + 1.5)
		local count = math.floor(PITCH_L / segLen)
		for i = 1, count do
			local z = -PITCH_L / 2 + segLen * (i - 0.5)
			-- leave the tunnel mouth clear on the west side
			if xSign < 0 and math.abs(z) < TUNNEL_GAP / 2 + segLen / 2 then
				continue
			end
			-- and the stretch in front of each dugout, so the bench has room
			-- to get out and a clear view of the pitch
			if xSign < 0 and math.abs(z) < TECHNICAL_Z[2] + segLen / 2 and math.abs(z) > TECHNICAL_Z[1] - segLen / 2 then
				continue
			end
			index += 1
			-- Front (-Z of the part) must face the pitch: yaw so that -Z points toward x = 0
			local yaw = if xSign < 0 then -math.pi / 2 else math.pi / 2
			sponsorBoard(boards, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), segLen - 1, index)
		end
	end
	for _, zSign in { -1, 1 } do
		local z = zSign * (GRASS_Z + 1.5)
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
-- from the boards the way real ones are.
--
-- Every piece is given as extents rather than centre + size, and no two of
-- them overlap. Overlapping boxes were what made the red seat flicker through
-- the black base and the corners strobe: two coplanar faces on the same plane
-- have no depth order, so the renderer picks one per frame.
local function buildDugouts(parent: Instance)
	local dugouts = Instance.new("Model")
	dugouts.Name = "Dugouts"
	dugouts.Parent = parent
	local dark = Color3.fromRGB(45, 45, 50)
	local frame = Color3.fromRGB(190, 215, 235)

	-- extents in a frame where x grows away from the pitch (the west side is
	-- mirrored back into world space on the way out)
	local function slab(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, colour: Color3, material: Enum.Material): Part
		return part({
			Name = name,
			Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
			CFrame = CFrame.new(-(x0 + x1) / 2, DECK_Y + (y0 + y1) / 2, (z0 + z1) / 2),
			Color = colour,
			Material = material,
			Parent = dugouts,
		})
	end

	-- character scale: ~2.75 studs per metre
	local front = DUGOUT_FRONT -- pitch-side face
	local plinthBack = front + 5.2
	local shelterH = 7.2
	for _, zSign in { -1, 1 } do
		local z0, z1 = zSign * DUGOUT_Z[1], zSign * DUGOUT_Z[2]
		if z0 > z1 then
			z0, z1 = z1, z0
		end
		-- raised concrete step the bench stands on, so it reads as a dugout not
		-- a box. Substitutes rest their feet on it, so its height is shared.
		local step = Pitch.DUGOUT_STEP
		local cushion = Pitch.BENCH_SEAT_Y
		slab("Plinth", front, plinthBack, 0, step, z0, z1, Color3.fromRGB(165, 165, 160), Enum.Material.Concrete)
		-- bench: dark pedestal, cushion on top of it, back panel behind it.
		-- Stacked, never interleaved.
		slab("SeatBase", front + 2.6, front + 4.6, step, cushion - 0.5, z0 + 1, z1 - 1, dark, Enum.Material.Plastic)
		slab("Seat", front + 2.6, front + 4.6, cushion - 0.5, cushion, z0 + 1, z1 - 1, Config.SeatColor, Enum.Material.Fabric)
		-- a low back: any taller and it hides a seated substitute's head
		slab("SeatBack", front + 4.6, front + 5.2, cushion, cushion + 1.2, z0 + 1, z1 - 1, Config.SeatColor, Enum.Material.Fabric)
		-- rear wall sits behind the plinth, not through it; brick like the stands (X134)
		slab("RearWall", plinthBack, plinthBack + 0.8, 0, shelterH, z0, z1, STAND_BRICK, Enum.Material.Brick)
		for _, zEnd in { z0, z1 } do
			local near = if zEnd == z0 then zEnd else zEnd - 0.6
			-- corner post at the open front, glass panel behind it: side by side
			slab("Post", front, front + 0.6, 0.6, shelterH, near, near + 0.6, dark, Enum.Material.Metal)
			local side = slab("Side", front + 0.6, plinthBack, 0.6, shelterH, near + 0.15, near + 0.45, frame, Enum.Material.Glass)
			side.Transparency = 0.45
		end
		local roof = slab("Shelter", front - 1.2, plinthBack + 0.8, shelterH, shelterH + 0.35, z0 - 0.3, z1 + 0.3, frame, Enum.Material.Glass)
		roof.Transparency = 0.3
		slab("RoofEdge", front - 1.2, front - 0.6, shelterH - 0.5, shelterH, z0 - 0.3, z1 + 0.3, Config.HomeKit, Enum.Material.SmoothPlastic)

		-- Technical area: the box the coaching staff have to stay inside. Runs
		-- from a metre off the touchline back to the front of the bench, and a
		-- metre past the seats at each end. Painted flush on whatever it
		-- crosses (turf, then paving) at the same height as the pitch lines.
		local paint = Color3.fromRGB(235, 235, 235)
		local markY = DECK_Y + 0.05
		local inner = PITCH_W / 2 + 2.75
		local tz0, tz1 = zSign * TECHNICAL_Z[1], zSign * TECHNICAL_Z[2]
		if tz0 > tz1 then
			tz0, tz1 = tz1, tz0
		end
		box("TechnicalFront", Vector3.new(0.6, 0.1, tz1 - tz0), Vector3.new(-inner, markY, (tz0 + tz1) / 2), paint, Enum.Material.SmoothPlastic, dugouts)
		for _, tz in { tz0, tz1 } do
			box("TechnicalSide", Vector3.new(front - inner, 0.1, 0.6), Vector3.new(-(inner + front) / 2, markY, tz), paint, Enum.Material.SmoothPlastic, dugouts)
		end
	end
end

-- The tunnel: a mouth in the middle of the west wall with the club name over
-- it, and a corridor that runs all the way back through the stand to the
-- dressing rooms and the office. The footballers come out of it; so does the
-- player, who spawns at the far end of it.
local function buildTunnel(parent: Instance)
	local tunnel = Instance.new("Model")
	tunnel.Name = "Tunnel"
	tunnel.Parent = parent
	local h = TUNNEL_H
	local w = TUNNEL_GAP
	local colour = Config.HomeKit
	local dark = Color3.fromRGB(55, 55, 60)
	local concrete = Color3.fromRGB(96, 98, 104)

	-- Corridor, from the wall line to the office door. Its outer faces are
	-- what the terrace butts up against, which is why the mouth is the only
	-- hole in the west stand rather than a slot through the whole thing.
	local x0, x1 = CORRIDOR_END, -SIDE_EDGE -- x0 is further from the pitch
	box("Floor", Vector3.new(x1 - x0, DECK_Y, w + WALL_T * 2), Vector3.new((x0 + x1) / 2, DECK_Y / 2, 0),
		Color3.fromRGB(130, 128, 122), Enum.Material.Concrete, tunnel)
	box("Ceiling", Vector3.new(x1 - x0 - PORTAL_D, 0.6, w + WALL_T * 2), Vector3.new((x0 + x1 - PORTAL_D) / 2, DECK_Y + h + 0.3, 0),
		dark, Enum.Material.Concrete, tunnel)
	-- side walls, broken by a doorway into each dressing room. The front few
	-- studs are brick piers (X134), under the club-colour header.
	for _, zSign in { -1, 1 } do
		local zc = zSign * (TUNNEL_HALF + WALL_T / 2)
		local runs = { { x0, ROOM_DOOR[1] }, { ROOM_DOOR[2], x1 - PORTAL_D } }
		for _, run in runs do
			box("Wall", Vector3.new(run[2] - run[1], h, WALL_T), Vector3.new((run[1] + run[2]) / 2, DECK_Y + h / 2, zc),
				concrete, Enum.Material.Concrete, tunnel)
		end
		box("Surround", Vector3.new(PORTAL_D, h, WALL_T), Vector3.new(x1 - PORTAL_D / 2, DECK_Y + h / 2, zc),
			STAND_BRICK, Enum.Material.Brick, tunnel)
		-- header over the doorway
		box("DoorHeader", Vector3.new(ROOM_DOOR[2] - ROOM_DOOR[1], 3, WALL_T), Vector3.new((ROOM_DOOR[1] + ROOM_DOOR[2]) / 2, DECK_Y + h - 1.5, zc),
			concrete, Enum.Material.Concrete, tunnel)
	end
	-- lintel over the mouth, carrying the club name
	local header = box("Header", Vector3.new(PORTAL_D, 3, w + WALL_T * 2), Vector3.new(x1 - PORTAL_D / 2, DECK_Y + h + 1.5, 0),
		colour, Enum.Material.SmoothPlastic, tunnel)
	box("HeaderTrim", Vector3.new(PORTAL_D + 0.3, 0.4, w + WALL_T * 2 + 0.3), Vector3.new(x1 - PORTAL_D / 2, DECK_Y + h + 3.2, 0),
		Color3.fromRGB(206, 196, 176), Enum.Material.Concrete, tunnel)
	-- strip lights down the middle
	for i = 0, 5 do
		local lx = x1 - 10 - i * ((x1 - x0) - 14) / 5
		local strip = box("Strip", Vector3.new(5, 0.3, 1.6), Vector3.new(lx, DECK_Y + h - 0.3, 0),
			Color3.fromRGB(255, 250, 230), Enum.Material.Neon, tunnel)
		strip.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 1.6
		light.Range = 30
		light.Color = Color3.fromRGB(255, 245, 225)
		light.Parent = strip
	end

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

-- Home and away dressing rooms, one off each side of the tunnel corridor.
-- No mechanics yet: they are a place, and the team walks out of them.
local function buildDressingRooms(parent: Instance)
	local rooms = Instance.new("Model")
	rooms.Name = "DressingRooms"
	rooms.Parent = parent
	local concrete = Color3.fromRGB(96, 98, 104)
	local tile = Color3.fromRGB(150, 148, 142)
	local h = TUNNEL_H
	local inner = TUNNEL_HALF + WALL_T -- the corridor wall is the room's near wall
	local outer = inner + ROOM_DEPTH

	for _, zSign in { -1, 1 } do
		local home = zSign > 0
		local room = Instance.new("Model")
		room.Name = if home then "Home" else "Away"
		room.Parent = rooms
		local kit = if home then Config.HomeKit else Color3.fromRGB(150, 150, 155)

		-- extents helper: z is given as a distance from the corridor and
		-- mirrored onto this side, so both rooms are built from one set of numbers
		local function slab(name: string, x0: number, x1: number, y0: number, y1: number, zNear: number, zFar: number, colour: Color3, material: Enum.Material): Part
			return part({
				Name = name,
				Size = Vector3.new(x1 - x0, y1 - y0, zFar - zNear),
				CFrame = CFrame.new((x0 + x1) / 2, DECK_Y + (y0 + y1) / 2, zSign * (zNear + zFar) / 2),
				Color = colour,
				Material = material,
				Parent = room,
			})
		end

		slab("Floor", ROOM_X0 - WALL_T, ROOM_X1 + WALL_T, -DECK_Y, 0, inner, outer + WALL_T, tile, Enum.Material.Concrete)
		slab("Ceiling", ROOM_X0 - WALL_T, ROOM_X1 + WALL_T, h, h + 0.6, inner, outer + WALL_T, Color3.fromRGB(55, 55, 60), Enum.Material.Concrete)
		slab("WallOuter", ROOM_X0 - WALL_T, ROOM_X1 + WALL_T, 0, h, outer, outer + WALL_T, concrete, Enum.Material.Concrete)
		slab("WallEndFar", ROOM_X0 - WALL_T, ROOM_X0, 0, h, inner, outer, concrete, Enum.Material.Concrete)
		slab("WallEndNear", ROOM_X1, ROOM_X1 + WALL_T, 0, h, inner, outer, concrete, Enum.Material.Concrete)
		-- X141: brick skins on the outside faces (the rooms stay concrete inside),
		-- wrapping the corners and up over the ceiling's edge
		local skin, top = 0.2, h + 0.6
		slab("Cladding", ROOM_X0 - WALL_T - skin, ROOM_X1 + WALL_T + skin, -0.2, top, outer + WALL_T, outer + WALL_T + skin, STAND_BRICK, Enum.Material.Brick)
		slab("Cladding", ROOM_X0 - WALL_T - skin, ROOM_X0 - WALL_T, -0.2, top, inner, outer + WALL_T, STAND_BRICK, Enum.Material.Brick)
		slab("Cladding", ROOM_X1 + WALL_T, ROOM_X1 + WALL_T + skin, -0.2, top, inner, outer + WALL_T, STAND_BRICK, Enum.Material.Brick)
		-- and the bit of corridor wall showing between the room and the office
		slab("Cladding", CORRIDOR_END + 0.5 + skin, ROOM_X0 - WALL_T - skin, -0.2, top, TUNNEL_HALF + WALL_T, TUNNEL_HALF + WALL_T + skin, STAND_BRICK, Enum.Material.Brick)

		-- Benches down both long sides with a peg rail and a hung shirt above
		-- each place. The inner run is broken either side of the doorway so
		-- the way in from the corridor stays clear.
		local sides = {
			{ name = "Outer", wallZ = outer, dir = -1, runs = { { ROOM_X0 + 2, ROOM_X1 - 2 } } },
			{ name = "Inner", wallZ = inner, dir = 1, runs = { { ROOM_X0 + 2, ROOM_DOOR[1] - 1 }, { ROOM_DOOR[2] + 1, ROOM_X1 - 2 } } },
		}
		for _, side in sides do
			local seatZ = side.wallZ + side.dir * 3.2 -- front edge of the bench
			local z0 = math.min(side.wallZ, seatZ)
			local z1 = math.max(side.wallZ, seatZ)
			local legZ = side.wallZ + side.dir * 2.4
			local railZ = side.wallZ + side.dir * 0.4
			for _, run in side.runs do
				if run[2] - run[1] < 4 then
					continue
				end
				slab("Bench" .. side.name, run[1], run[2], 1.6, 2.1, z0, z1, Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
				slab("BenchLeg" .. side.name, run[1], run[2], 0, 1.6, math.min(legZ, legZ + side.dir * 0.8), math.max(legZ, legZ + side.dir * 0.8), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
				slab("PegRail" .. side.name, run[1], run[2], 6.4, 6.8, math.min(side.wallZ, railZ), math.max(side.wallZ, railZ), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
				-- shirts on the pegs, one per place
				local places = math.max(1, math.floor((run[2] - run[1]) / 4))
				local step = (run[2] - run[1]) / places
				for i = 1, places do
					local sx = run[1] + step * (i - 0.5)
					local sz0 = math.min(side.wallZ + side.dir * 0.4, side.wallZ + side.dir * 0.8)
					local shirt = slab("Shirt", sx - 1.6, sx + 1.6, 3.4, 6.4, sz0, sz0 + 0.4, kit, Enum.Material.Fabric)
					shirt.CanCollide = false
				end
			end
		end

		-- tactics board flat on the far end wall, and a light in the middle
		local board = slab("TacticsBoard", ROOM_X0, ROOM_X0 + 0.4, 3.5, 8.5, inner + 8, outer - 8, Color3.fromRGB(35, 70, 45), Enum.Material.SmoothPlastic)
		addSign(board, if home then "HOME" else "AWAY", { Enum.NormalId.Right })
		local bulb = slab("Bulb", (ROOM_X0 + ROOM_X1) / 2 - 3, (ROOM_X0 + ROOM_X1) / 2 + 3, h - 0.6, h - 0.3, inner + ROOM_DEPTH / 2 - 1, inner + ROOM_DEPTH / 2 + 1,
			Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
		bulb.CanCollide = false
		local light = Instance.new("PointLight")
		light.Brightness = 1.5
		light.Range = 34
		light.Color = Color3.fromRGB(255, 245, 225)
		light.Parent = bulb
	end
end

-- Scoreboard: on two posts on the paving by the open north-east corner,
-- angled at the centre circle. Deliberately a cheap non-league board for now
-- (painted panel, no video) with room for a proper screen later.
local SCOREBOARD_POS = Vector3.new(100, 0, -(Pitch.GRASS_EDGE_Z + 9))

local function scoreLabel(parent: Instance, name: string, pos: UDim2, size: UDim2, text: string, colour: Color3, align: Enum.TextXAlignment?)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = pos
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.Text = text
	label.Parent = parent
end

local function buildScoreboard(parent: Instance)
	local board = Instance.new("Model")
	board.Name = "Scoreboard"
	board.Parent = parent
	local base = CFrame.lookAt(SCOREBOARD_POS + Vector3.new(0, DECK_Y, 0), Vector3.new(0, DECK_Y, 0))
	local dark = Color3.fromRGB(28, 30, 34)
	local postH = 13

	local function at(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material): Part
		return part({
			Name = name,
			Size = size,
			CFrame = base * offset,
			Color = colour,
			Material = material,
			Parent = board,
		})
	end

	for _, side in { -1, 1 } do
		at("Post", Vector3.new(1.2, postH, 1.2), CFrame.new(side * 9, postH / 2, 0), Color3.fromRGB(90, 92, 98), Enum.Material.Metal)
	end
	local panel = at("Panel", Vector3.new(24, 10, 0.8), CFrame.new(0, postH + 5, 0), dark, Enum.Material.SmoothPlastic)
	at("Trim", Vector3.new(25, 0.8, 1.2), CFrame.new(0, postH + 10.4, 0), Config.HomeKit, Enum.Material.SmoothPlastic)
	at("TrimBase", Vector3.new(25, 0.8, 1.2), CFrame.new(0, postH - 0.4, 0), Config.HomeKit, Enum.Material.SmoothPlastic)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0 -- reads at dusk under the floodlights
	gui.MaxDistance = 600
	gui.Parent = panel
	local amber = Color3.fromRGB(255, 190, 60)
	scoreLabel(gui, "HomeName", UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.22, 0.38), "HOME", Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	scoreLabel(gui, "AwayName", UDim2.fromScale(0.74, 0.1), UDim2.fromScale(0.22, 0.38), "AWAY", Color3.new(1, 1, 1), Enum.TextXAlignment.Right)
	scoreLabel(gui, "Score", UDim2.fromScale(0.31, 0.02), UDim2.fromScale(0.38, 0.56), "0 - 0", amber)
	scoreLabel(gui, "Clock", UDim2.fromScale(0.2, 0.6), UDim2.fromScale(0.6, 0.32), "", amber)
end

-- Short name for the board: three letters is all that fits legibly.
local function abbreviate(name: string): string
	local letters = string.gsub(name, "[^%a]", "")
	return string.upper(string.sub(letters, 1, 3))
end

-- Keeps the physical board in step with the match. Bound once per server: the
-- labels are looked up fresh each time so a world rebuild does not leak.
local scoreboardBound = false
local function bindScoreboard()
	if scoreboardBound then
		return
	end
	local state = PlotContext.stateFolder()
	if not state then
		return
	end
	scoreboardBound = true
	local function refresh()
		local club = PlotContext.clubModel()
		local model = club and club:FindFirstChild("Scoreboard")
		local panel = model and model:FindFirstChild("Panel")
		local gui = panel and panel:FindFirstChild("Face")
		if not gui then
			return
		end
		local function set(name: string, text: string)
			local label = gui:FindFirstChild(name) :: TextLabel?
			if label then
				label.Text = text
			end
		end
		local phase = state:GetAttribute("Phase")
		local inMatch = phase == "Match" or phase == "PreMatch"
		set("HomeName", abbreviate((state:GetAttribute("ClubName") :: string?) or Config.ClubName))
		set("AwayName", if inMatch then abbreviate((state:GetAttribute("Opponent") :: string?) or "Away") else "")
		if not inMatch then
			set("Score", "- -")
			set("Clock", "")
			return
		end
		set("Score", ("%d - %d"):format((state:GetAttribute("HomeGoals") :: number?) or 0, (state:GetAttribute("AwayGoals") :: number?) or 0))
		local left = (state:GetAttribute("TimeLeft") :: number?) or 0
		local total = math.max((state:GetAttribute("MatchDuration") :: number?) or 90, 1)
		local minute = math.clamp(math.floor((1 - left / total) * 90), 0, 90)
		set("Clock", if phase == "PreMatch" then "KICK-OFF" else ("%d'"):format(minute))
	end
	for _, key in { "Phase", "HomeGoals", "AwayGoals", "TimeLeft", "Opponent", "ClubName" } do
		state:GetAttributeChangedSignal(key):Connect(refresh)
	end
	task.defer(refresh)
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
	-- X52: brick piers with stone caps and open iron gate leaves folded against
	-- them, like RivermereTurnstileEntrance.png; the club colour stays on the fascia
	local brick = Color3.fromRGB(150, 84, 62)
	local stone = Color3.fromRGB(214, 204, 184)
	local iron = Color3.fromRGB(28, 34, 48)
	-- X166: lane signs and plaques in a dark shade of the club colour, like the
	-- fascia, club shop and bar sign (the reference's navy is its club's colour)
	local SIGN_DARK = Config.HomeKit:Lerp(Color3.new(0, 0, 0), 0.45)
	for i = 0, lanes do
		local z = TURNSTILE_Z - total / 2 + pierW / 2 + i * (laneW + pierW)
		box("Pier", Vector3.new(7, h, pierW), Vector3.new(x - 1, DECK_Y + h / 2, z), brick, Enum.Material.Brick, gate)
		box("PierCap", Vector3.new(7.3, 0.4, pierW + 0.3), Vector3.new(x - 1, DECK_Y + h - 0.15, z), stone, Enum.Material.Limestone, gate)
	end
	for i = 1, lanes do
		local z = TURNSTILE_Z - total / 2 + pierW + laneW / 2 + (i - 1) * (laneW + pierW)
		-- an open gate leaf folded flat against the outer face of each pier, clear of the lane
		-- X53: a navy lane sign under the fascia, facing the walk-up side
		local laneSign = box("LaneSign", Vector3.new(0.2, 1.3, laneW - 0.4), Vector3.new(x - 4.7, DECK_Y + h - 1.15, z), SIGN_DARK, Enum.Material.SmoothPlastic, gate)
		laneSign.CanCollide = false
		local signGui = Instance.new("SurfaceGui")
		signGui.Face = Enum.NormalId.Left
		signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		signGui.PixelsPerStud = 40
		signGui.Parent = laneSign
		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.fromScale(0.9, 0.7)
		signText.Position = UDim2.fromScale(0.05, 0.15)
		signText.BackgroundTransparency = 1
		signText.Font = Enum.Font.GothamBold
		signText.TextScaled = true
		signText.TextColor3 = Color3.fromRGB(240, 240, 240)
		signText.Text = if i == 2 then "TICKETS" else "HOME SUPPORTERS" -- X155: the reference board's wording
		signText.Parent = signGui
		for _, side in { -1, 1 } do
			-- X153: a barred leaf (top and bottom rails, four uprights) rather than a
			-- solid panel, which read as a dark doorway on each pier
			local lz = z + side * (laneW / 2 + pierW / 2)
			for _, ry in { 0.4, 6.5 } do
				box("GateRail", Vector3.new(0.2, 0.2, 2.2), Vector3.new(x - 4.65, DECK_Y + ry, lz), iron, Enum.Material.Metal, gate).CanCollide = false
			end
			for _, bz in { -0.95, -0.32, 0.32, 0.95 } do
				box("GateBar", Vector3.new(0.12, 5.9, 0.15), Vector3.new(x - 4.65, DECK_Y + 0.5 + 2.95, lz + bz), iron, Enum.Material.Metal, gate).CanCollide = false
			end
		end
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
	-- X236: room for a crest badge at each end, as on RivermereTurnstileEntrance.png
	label.Size = UDim2.new(1, -150, 1, 0)
	label.Position = UDim2.fromOffset(75, 0)
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
	-- the badges are GUI frames on the same SurfaceGui: no extra parts
	for _, anchorX in { 0, 1 } do
		local badge = Instance.new("Frame")
		badge.Name = "CrestBadge"
		badge.AnchorPoint = Vector2.new(anchorX, 0.5)
		badge.Position = UDim2.new(anchorX, if anchorX == 0 then 18 else -18, 0.5, 0)
		badge.Size = UDim2.fromOffset(42, 52)
		badge.BackgroundColor3 = SIGN_DARK
		badge.BorderSizePixel = 0
		badge.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = badge
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 2
		stroke.Parent = badge
		-- a battlemented wall over river waves, the Rivermere crest shorthand
		local wall = Instance.new("Frame")
		wall.Name = "Wall"
		wall.AnchorPoint = Vector2.new(0.5, 0)
		wall.Position = UDim2.new(0.5, 0, 0, 14)
		wall.Size = UDim2.fromOffset(24, 8)
		wall.BackgroundColor3 = Color3.new(1, 1, 1)
		wall.BorderSizePixel = 0
		wall.Parent = badge
		for m = -1, 1 do
			local merlon = Instance.new("Frame")
			merlon.Name = "Merlon"
			merlon.AnchorPoint = Vector2.new(0.5, 0)
			merlon.Position = UDim2.new(0.5, m * 9, 0, 9)
			merlon.Size = UDim2.fromOffset(6, 6)
			merlon.BackgroundColor3 = Color3.new(1, 1, 1)
			merlon.BorderSizePixel = 0
			merlon.Parent = badge
		end
		for wv = 1, 2 do
			local wave = Instance.new("Frame")
			wave.Name = "Wave"
			wave.AnchorPoint = Vector2.new(0.5, 0)
			wave.Position = UDim2.new(0.5, 0, 0, 28 + (wv - 1) * 7)
			wave.Size = UDim2.fromOffset(24, 2)
			wave.BackgroundColor3 = Color3.new(1, 1, 1)
			wave.BorderSizePixel = 0
			wave.Parent = badge
		end
	end

	-- X84: navy slogan plaques on the outer side faces of the end piers (the
	-- walk-up faces carry the open gate leaves) and a shrub planter beside the
	-- gates (RivermereTurnstileEntrance.png)
	for i, slogan in { "PRIDE\nPEOPLE\nRIVERMERE", "MATCH DAYS\nBRING PEOPLE\nTOGETHER" } do
		local side = if i == 1 then -1 else 1
		-- x - 3.9 .. x - 0.5: clear of the perimeter wall (x +- 0.4) that starts at the pier
		local plaque = box("Plaque", Vector3.new(3.4, 3.4, 0.15), Vector3.new(x - 2.2, DECK_Y + 4.6, TURNSTILE_Z + side * (total / 2 + 0.075)), SIGN_DARK, Enum.Material.SmoothPlastic, gate)
		plaque.CanCollide = false
		local plaqueGui = Instance.new("SurfaceGui")
		plaqueGui.Face = if side < 0 then Enum.NormalId.Front else Enum.NormalId.Back
		plaqueGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		plaqueGui.PixelsPerStud = 50
		plaqueGui.Parent = plaque
		local plaqueText = Instance.new("TextLabel")
		plaqueText.Size = UDim2.fromScale(0.86, 0.8)
		plaqueText.Position = UDim2.fromScale(0.07, 0.1)
		plaqueText.BackgroundTransparency = 1
		plaqueText.Font = Enum.Font.GothamBold
		plaqueText.TextScaled = true
		plaqueText.TextColor3 = Color3.fromRGB(240, 240, 240)
		plaqueText.Text = slogan
		plaqueText.Parent = plaqueGui
	end
	-- out beside the plaque (x - 3.9 .. x - 0.5), not in front of it
	local planterX, planterZ = x - 7.5, TURNSTILE_Z + total / 2 + 2.5
	box("Planter", Vector3.new(3, 2.2, 3), Vector3.new(planterX, DECK_Y + 1.1, planterZ), Color3.fromRGB(58, 60, 64), Enum.Material.Concrete, gate)
	local shrub = part({
		Name = "Shrub",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3.4, 3.4),
		CFrame = CFrame.new(planterX, DECK_Y + 2.2 + 1.2, planterZ),
		Color = Color3.fromRGB(62, 104, 50),
		Material = Enum.Material.LeafyGrass,
		Parent = gate,
	})
	shrub.CanCollide = false
	shrub.CastShadow = false

	-- X53: a black lamp post outside, beside the entrance, flying a club banner
	-- (RivermereTurnstileEntrance.png: "OUR TOWN / OUR GAME")
	local lx, lz = x - 7, TURNSTILE_Z - total / 2 - 4
	local lampBlack = Color3.fromRGB(24, 26, 30)
	box("LampBase", Vector3.new(1.2, 1.2, 1.2), Vector3.new(lx, DECK_Y + 0.6, lz), lampBlack, Enum.Material.Metal, gate)
	box("LampPost", Vector3.new(0.5, 15.4, 0.5), Vector3.new(lx, DECK_Y + 1 + 7.7, lz), lampBlack, Enum.Material.Metal, gate)
	box("Lantern", Vector3.new(1, 1.6, 1), Vector3.new(lx, DECK_Y + 17, lz), Color3.fromRGB(250, 236, 196), Enum.Material.Glass, gate)
	box("LanternCap", Vector3.new(1.4, 0.4, 1.4), Vector3.new(lx, DECK_Y + 17.9, lz), lampBlack, Enum.Material.Metal, gate)
	-- the arm reaches away from the entrance so the banner hangs clear of the post
	box("BannerArm", Vector3.new(0.25, 0.25, 3.6), Vector3.new(lx, DECK_Y + 14.4, lz - 2.05), lampBlack, Enum.Material.Metal, gate).CanCollide = false
	local banner = box("LampBanner", Vector3.new(0.15, 7, 3), Vector3.new(lx, DECK_Y + 10.8, lz - 2.3), Config.HomeKit, Enum.Material.Fabric, gate)
	banner.CanCollide = false
	banner.CastShadow = false
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local bannerGui = Instance.new("SurfaceGui")
		bannerGui.Face = face
		bannerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		bannerGui.PixelsPerStud = 40
		bannerGui.LightInfluence = 0.85
		bannerGui.Parent = banner
		local bannerName = Instance.new("TextLabel")
		bannerName.Name = "ClubName" -- WorldBuilder.setClubName repaints it
		bannerName.Size = UDim2.fromScale(0.86, 0.3)
		bannerName.Position = UDim2.fromScale(0.07, 0.06)
		bannerName.BackgroundTransparency = 1
		bannerName.Font = Enum.Font.GothamBlack
		bannerName.TextScaled = true
		bannerName.TextColor3 = Color3.new(1, 1, 1)
		bannerName.Text = "CLUB"
		bannerName.Parent = bannerGui
		local motto = Instance.new("TextLabel")
		motto.Name = "Motto"
		motto.Size = UDim2.fromScale(0.8, 0.26)
		motto.Position = UDim2.fromScale(0.1, 0.62)
		motto.BackgroundTransparency = 1
		motto.Font = Enum.Font.GothamBold
		motto.TextScaled = true
		motto.TextColor3 = Color3.new(1, 1, 1)
		motto.Text = "OUR TOWN\nOUR GAME"
		motto.Parent = bannerGui
	end
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
		-- X124: warm block paving like RivermereTurnstileEntrance.png (was flat grey concrete)
		Color3.fromRGB(196, 176, 148), Enum.Material.Pavement, yard)
	-- car park bays between the office and the corner
	local bayZ = FORECOURT_Z1 - 13
	for i = 0, 5 do
		local bx = FORECOURT_X0 + 12 + i * 9
		box("Bay", Vector3.new(0.6, 0.08, 18), Vector3.new(bx, DECK_Y + 0.04, bayZ), Color3.fromRGB(215, 212, 200), Enum.Material.Concrete, yard)
	end
end

local OFFICE_Y = DECK_Y + 0.1 -- office floor, a touch proud of the corridor floor

local function buildOffice(parent: Instance)
	local office = Instance.new("Model")
	office.Name = "Office"
	office.Parent = parent

	local w, d, h = OFFICE_W, OFFICE_D, OFFICE_H
	-- door faces east, onto the far end of the tunnel corridor
	local cx, cz = OFFICE_CX, OFFICE_CZ
	local wallColor = Color3.fromRGB(170, 160, 135) -- stained beige
	local wallMat = Enum.Material.Concrete

	box("Floor", Vector3.new(w, 1, d), Vector3.new(cx, OFFICE_Y - 0.5, cz),
		Color3.fromRGB(95, 80, 60), Enum.Material.WoodPlanks, office)
	box("Roof", Vector3.new(w + 2, 1, d + 2), Vector3.new(cx, OFFICE_Y + h + 0.5, cz),
		Color3.fromRGB(70, 70, 70), Enum.Material.Slate, office)

	local wy = OFFICE_Y + h / 2
	local wallW = box("WallW", Vector3.new(1, h, d), Vector3.new(cx - w / 2, wy, cz), wallColor, wallMat, office)
	local wallN = box("WallN", Vector3.new(w, h, 1), Vector3.new(cx, wy, cz - d / 2), wallColor, wallMat, office)
	-- X170: the early office is rundown (CLAUDE.md s5): damp stains on the
	-- inside of the west and north walls and a curling fixtures notice behind
	-- the desk, drawn with SurfaceGuis (no parts)
	local function wallGui(wall: BasePart, face: Enum.NormalId): SurfaceGui
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Wear"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 1
		gui.Parent = wall
		return gui
	end
	local function stain(gui: SurfaceGui, x: number, y: number, sw: number, sh: number)
		local f = Instance.new("Frame")
		f.Name = "Damp"
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(sw, sh)
		f.BackgroundColor3 = Color3.fromRGB(110, 96, 70)
		f.BackgroundTransparency = 0.72
		f.BorderSizePixel = 0
		f.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	local westGui = wallGui(wallW, Enum.NormalId.Right) -- +X, into the room
	stain(westGui, 0.02, 0.62, 0.22, 0.34)
	stain(westGui, 0.1, 0.8, 0.3, 0.2)
	stain(westGui, 0.8, 0.0, 0.18, 0.2)
	local northGui = wallGui(wallN, Enum.NormalId.Back) -- +Z, into the room
	stain(northGui, 0.0, 0.0, 0.16, 0.24)
	stain(northGui, 0.86, 0.7, 0.14, 0.3)
	local notice = Instance.new("Frame")
	notice.Name = "FixturesNotice"
	notice.AnchorPoint = Vector2.new(0.5, 0.5)
	notice.Position = UDim2.fromScale(0.5, 0.38)
	notice.Size = UDim2.fromOffset(60, 76)
	notice.Rotation = -4
	notice.BackgroundColor3 = Color3.fromRGB(236, 228, 204)
	notice.BorderSizePixel = 0
	notice.Parent = westGui
	local noticeText = Instance.new("TextLabel")
	noticeText.BackgroundTransparency = 1
	noticeText.Size = UDim2.fromScale(0.86, 0.9)
	noticeText.Position = UDim2.fromScale(0.07, 0.05)
	noticeText.Font = Enum.Font.PatrickHand
	noticeText.TextScaled = true
	noticeText.TextColor3 = Color3.fromRGB(40, 40, 46)
	noticeText.Text = "FIXTURES\nSat 3pm\nSat 3pm\nTue 7:45\nSat 3pm"
	noticeText.Parent = notice
	box("WallS", Vector3.new(w, h, 1), Vector3.new(cx, wy, cz + d / 2), wallColor, wallMat, office)
	-- east wall has a doorway facing the ground
	local doorW = 8
	local segLen = (d - doorW) / 2
	box("WallE1", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz - (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("WallE2", Vector3.new(1, h, segLen), Vector3.new(cx + w / 2, wy, cz + (doorW / 2 + segLen / 2)), wallColor, wallMat, office)
	box("DoorHeader", Vector3.new(1, 3, doorW), Vector3.new(cx + w / 2, OFFICE_Y + h - 1.5, cz), wallColor, wallMat, office)
	-- X141: brick skins outside (the stained beige stays inside), wrapping the
	-- corners; the east skins stop at the tunnel corridor's walls
	local skin = 0.2
	local skinH = h + 1
	local skinY = OFFICE_Y - 1 + skinH / 2
	local ow, od = w / 2 + 0.5, d / 2 + 0.5 -- outer faces
	box("Cladding", Vector3.new(skin, skinH, od * 2), Vector3.new(cx - ow - skin / 2, skinY, cz), STAND_BRICK, Enum.Material.Brick, office)
	for _, zSign in { -1, 1 } do
		box("Cladding", Vector3.new(ow * 2 + skin * 2, skinH, skin), Vector3.new(cx, skinY, cz + zSign * (od + skin / 2)), STAND_BRICK, Enum.Material.Brick, office)
		local z0 = TUNNEL_HALF + WALL_T
		box("Cladding", Vector3.new(skin, skinH, od - z0), Vector3.new(cx + ow + skin / 2, skinY, cz + zSign * (z0 + od) / 2), STAND_BRICK, Enum.Material.Brick, office)
	end

	-- furniture
	local desk = box("Desk", Vector3.new(4, 3, 10), Vector3.new(cx - 8, OFFICE_Y + 1.5, cz),
		Color3.fromRGB(110, 75, 45), Enum.Material.Wood, office)
	local computer = box("Computer", Vector3.new(1, 2, 2.5), Vector3.new(cx - 8, desk.Position.Y + 1.5 + 1, cz),
		Color3.fromRGB(200, 200, 190), Enum.Material.Plastic, office)
	-- X169: an old green-screen monitor facing the chair (-X)
	local screen = Instance.new("SurfaceGui")
	screen.Name = "Screen"
	screen.Face = Enum.NormalId.Left
	screen.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screen.PixelsPerStud = 60
	screen.LightInfluence = 0
	screen.Parent = computer
	local glass = Instance.new("TextLabel")
	glass.Name = "Display"
	glass.Position = UDim2.fromScale(0.08, 0.1)
	glass.Size = UDim2.fromScale(0.84, 0.66)
	glass.BackgroundColor3 = Color3.fromRGB(12, 30, 16)
	glass.BorderSizePixel = 0
	glass.Font = Enum.Font.Code
	glass.TextScaled = true
	glass.TextXAlignment = Enum.TextXAlignment.Left
	glass.TextColor3 = Color3.fromRGB(90, 230, 110)
	glass.Text = " CLUB OFFICE\n > _"
	glass.Parent = screen
	-- Club management lives on the office computer. The client opens the panel
	-- when this prompt fires (ProximityPromptService.PromptTriggered).
	local clubPrompt = addPrompt(computer, "Club Office", "Manage squad, scouting & staff")
	clubPrompt.Name = "ClubPrompt"
	clubPrompt.HoldDuration = 0
	-- X168: a cheap swivel chair facing the desk (+X): pedestal, seat, back
	local chairX = cx - 11.5
	box("ChairBase", Vector3.new(0.4, 1.4, 0.4), Vector3.new(chairX, OFFICE_Y + 0.7, cz), Color3.fromRGB(40, 40, 42), Enum.Material.Metal, office)
	box("Chair", Vector3.new(2, 0.5, 2), Vector3.new(chairX, OFFICE_Y + 1.65, cz), Color3.fromRGB(60, 60, 60), Enum.Material.Fabric, office)
	box("ChairBack", Vector3.new(0.4, 2.2, 1.8), Vector3.new(chairX - 0.8, OFFICE_Y + 3, cz), Color3.fromRGB(60, 60, 60), Enum.Material.Fabric, office)

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
	local club = PlotContext.clubModel()
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
	PlotContext.place(model)
end


local function buildMatchdayBoard(parent: Instance): ProximityPrompt
	-- Hung on the corridor wall between the office door and the dressing
	-- rooms, so the player passes it every time they walk out to the pitch.
	local post = box("MatchdayBoard", Vector3.new(11, 5, 0.4), Vector3.new(CORRIDOR_END + 9, DECK_Y + 4, TUNNEL_HALF - 0.2),
		Color3.fromRGB(30, 60, 30), Enum.Material.Wood, parent)
	addSign(post, "MATCHDAY", { Enum.NormalId.Front })
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
--
-- The west stand has the tunnel through it. Rows low enough to hit the tunnel
-- stop dead against its side walls; from `crossRow` up the terrace is high
-- enough to carry straight over the corridor roof, so the only hole left in
-- that stand is the mouth itself. Which row that is falls out of the rake, so
-- the gap closes itself as the stand is upgraded.
type PlotGeometry = {
	frame: CFrame,
	length: number,
	rows: number,
	stepHeight: number,
	spans: { { number } }, -- runs of seating along local Z, split around the tunnel
	crossRow: number, -- first row that carries over the tunnel; rows + 1 if none does
	crossY: number, -- underside of that row, sitting on the corridor roof
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
	local spans: { { number } } = { { -half, half } }
	local crossRow, crossY = spec.rows + 1, 0
	if plot.key == "West" then
		local g = TUNNEL_OUT
		spans = if half > g + 8 then { { -half, -g }, { g, half } } else {}
		crossY = DECK_Y + TUNNEL_H + 0.6 -- top of the corridor roof
		-- the first row whose deck clears it
		for i = 1, spec.rows do
			if DECK_Y + spec.stepHeight * i > crossY then
				crossRow = i
				break
			end
		end
	end
	return {
		frame = frame,
		length = length,
		rows = spec.rows,
		stepHeight = spec.stepHeight,
		spans = spans,
		crossRow = crossRow,
		crossY = crossY,
		spec = spec,
	}
end

-- The runs of terrace on one row: { z0, z1, underside }. Below `crossRow` the
-- west stand is two runs either side of the tunnel; at and above it, one run
-- straight across, resting on the corridor roof.
local function rowRuns(geo: PlotGeometry, row: number): { { number } }
	local runs = {}
	for _, span in geo.spans do
		table.insert(runs, { span[1], span[2], 0 })
	end
	if #geo.spans == 2 and row >= geo.crossRow then
		-- the first crossing row rests on the corridor roof, the rest on the
		-- row below, so the terrace over the tunnel is solid all the way up
		local under = if row == geo.crossRow then geo.crossY else DECK_Y + geo.stepHeight * (row - 1)
		table.insert(runs, { geo.spans[1][2], geo.spans[2][1], under })
	end
	return runs
end

function WorldBuilder.buildPlot(plotIndex: number, level: number)
	local club = PlotContext.clubModel() :: Model
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

	local rail = Color3.fromRGB(205, 208, 212)
	local RAIL_H = 3.4 -- waist height on a standing character
	local aisles: { number } = {} -- z of each aisle, collected on the first row

	for i = 1, rows do
		local height = stepHeight * i
		local rowX = STAND_X0 + STEP_DEPTH * (i - 1) + STEP_DEPTH / 2
		local stepBack = STAND_X0 + STEP_DEPTH * i -- back edge of this step
		local top = DECK_Y + height
		for _, run in rowRuns(geo, i) do
			local z0, z1, under = run[1], run[2], run[3]
			local runLen = z1 - z0
			local zc = (z0 + z1) / 2
			-- Sections are stretched to fill the run exactly rather than left
			-- short, which used to leave a bare grey step at each end.
			local sections = math.max(1, math.floor((runLen + aisleW) / (sectionLen + aisleW) + 0.5))
			local secLen = (runLen - (sections - 1) * aisleW) / sections
			local startZ = z0

			lbox(("Row%d"):format(i), Vector3.new(STEP_DEPTH, top - under, runLen),
				Vector3.new(rowX, (under + top) / 2, zc), stepColor, stepMat)
			if spec.seats then
				-- seat blocks per section; an alternate shade every other section so the
				-- seating reads as blocks rather than one long strip
				for s = 1, sections do
					local z = startZ + (s - 1) * (secLen + aisleW) + secLen / 2
					local colour = if s % 2 == 0 then Config.SeatColor:Lerp(Color3.new(1, 1, 1), 0.25) else Config.SeatColor
					local seat = lbox(("Seats%d_%d"):format(i, s), Vector3.new(1.6, 1.1, secLen),
						Vector3.new(stepBack - 0.8, top + 0.55, z), colour, Enum.Material.Plastic)
					seat.CanCollide = false
					local back = lbox(("SeatBack%d_%d"):format(i, s), Vector3.new(0.3, 1.6, secLen),
						Vector3.new(stepBack - 0.15, top + 0.8, z), colour, Enum.Material.Plastic)
					back.CanCollide = false
				end
				-- aisle treads between sections, lighter so they read as steps
				for s = 1, sections - 1 do
					local z = startZ + s * (secLen + aisleW) - aisleW / 2
					local tread = lbox(("Aisle%d_%d"):format(i, s), Vector3.new(STEP_DEPTH, 0.2, aisleW),
						Vector3.new(rowX, top + 0.1, z), Color3.fromRGB(215, 215, 210), Enum.Material.Concrete)
					tread.CanCollide = false
					if i == 1 then
						table.insert(aisles, z)
					end
				end
			else
				-- level 1: a plank bench along each bleacher row
				lbox(("Bench%d"):format(i), Vector3.new(1.8, 0.4, runLen - 2),
					Vector3.new(stepBack - 0.9, top + 0.2, zc),
					Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
			end
		end
	end

	-- Railings. A terrace with nothing to hold on to reads as unfinished, but
	-- a rail per row per aisle is thousands of parts, so each aisle gets one
	-- bar raked the whole way up with a post every few rows instead.
	local function railBar(name: string, x0: number, y0: number, x1: number, y1: number, z: number)
		local dx, dy = x1 - x0, y1 - y0
		local bar = part({
			Name = name,
			Size = Vector3.new(math.sqrt(dx * dx + dy * dy), 0.25, 0.25),
			CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.atan2(dy, dx)),
			Color = rail,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = stand,
		})
		return bar
	end

	for _, z in aisles do
		for _, side in { -1, 1 } do
			local zr = z + side * (aisleW / 2 + 0.15)
			railBar("AisleRail", STAND_X0, DECK_Y + stepHeight + RAIL_H, STAND_X0 + depth, DECK_Y + stepHeight * rows + RAIL_H, zr)
			for i = 1, rows, 3 do
				local post = lbox("AislePost", Vector3.new(0.25, RAIL_H, 0.25),
					Vector3.new(STAND_X0 + STEP_DEPTH * (i - 0.5), DECK_Y + stepHeight * i + RAIL_H / 2, zr), rail, Enum.Material.Metal)
				post.CanCollide = false
			end
		end
	end
	-- front rail along row 1 and a crush barrier across the back row
	for _, run in rowRuns(geo, 1) do
		local z0, z1 = run[1], run[2]
		local top = DECK_Y + stepHeight
		local bar = lbox("FrontBar", Vector3.new(0.3, 0.3, z1 - z0), Vector3.new(STAND_X0 + 0.15, top + RAIL_H, (z0 + z1) / 2), rail, Enum.Material.Metal)
		bar.CanCollide = false
		local posts = math.max(2, math.floor((z1 - z0) / 10))
		for p = 0, posts do
			local post = lbox("FrontPost", Vector3.new(0.3, RAIL_H, 0.3),
				Vector3.new(STAND_X0 + 0.15, top + RAIL_H / 2, z0 + (z1 - z0) * p / posts), rail, Enum.Material.Metal)
			post.CanCollide = false
		end
	end
	for _, run in rowRuns(geo, rows) do
		local top = DECK_Y + stepHeight * rows
		local bar = lbox("BackBar", Vector3.new(0.3, 0.3, run[2] - run[1]),
			Vector3.new(STAND_X0 + depth - 0.15, top + RAIL_H, (run[1] + run[2]) / 2), rail, Enum.Material.Metal)
		bar.CanCollide = false
	end

	-- End walls. A WedgePart is full height at its local +Z and tapers to
	-- nothing at -Z, so the slope has to rise AWAY from the pitch: yaw +90
	-- sends local +Z along local +X (outward). Getting this backwards is
	-- what made the side panels look inside out.
	--
	-- The ends beside the tunnel only close off the rows that stop there, so
	-- they are as tall as the terrace is at that point and no taller.
	for s, span in geo.spans do
		for e, zEnd in { span[1], span[2] } do
			local atTunnel = #geo.spans == 2 and ((s == 1 and e == 2) or (s == 2 and e == 1))
			local capRows = if atTunnel then math.min(geo.crossRow - 1, rows) else rows
			if capRows < 1 then
				continue
			end
			local wallH = stepHeight * capRows
			local wedgeD = STEP_DEPTH * capRows
			local wedge = Instance.new("WedgePart")
			wedge.Name = "EndWall"
			wedge.Anchored = true
			wedge.Size = Vector3.new(0.8, wallH, wedgeD)
			wedge.CFrame = frame * CFrame.new(STAND_X0 + wedgeD / 2, DECK_Y + wallH / 2, zEnd) * CFrame.Angles(0, math.pi / 2, 0)
			-- X134: brick like the turnstiles and the town (Q25: the kit sets the style)
			wedge.Color = STAND_BRICK
			wedge.Material = Enum.Material.Brick
			wedge.Parent = stand
		end
	end

	if level >= 2 then
		local length = geo.length
		local wallH = stepHeight * rows + 3
		local backX = STAND_X0 + depth + 0.5
		-- X134: brick back walls with a stone coping and a club-colour band on
		-- the outside, like the town's brick (was pale concrete)
		local brick = STAND_BRICK
		-- The back wall parts either side of the tunnel corridor, which runs
		-- out through here, and carries on as a lintel above it.
		local wallRuns = { { -length / 2, length / 2 } }
		if #geo.spans == 2 then
			wallRuns = { { -length / 2, -TUNNEL_OUT }, { TUNNEL_OUT, length / 2 } }
			lbox("BackWall", Vector3.new(1, DECK_Y + wallH - geo.crossY, TUNNEL_OUT * 2),
				Vector3.new(backX, (geo.crossY + DECK_Y + wallH) / 2, 0), brick, Enum.Material.Brick)
		end
		for _, run in wallRuns do
			lbox("BackWall", Vector3.new(1, wallH, run[2] - run[1]), Vector3.new(backX, DECK_Y + wallH / 2, (run[1] + run[2]) / 2),
				brick, Enum.Material.Brick)
			lbox("BackBand", Vector3.new(0.1, 1, run[2] - run[1] - 0.2), Vector3.new(backX + 0.55, DECK_Y + wallH - 2, (run[1] + run[2]) / 2),
				Config.HomeKit, Enum.Material.SmoothPlastic)
		end
		-- coping sunk 0.1 into the wall top, overhanging both faces by 0.2
		lbox("BackCoping", Vector3.new(1.4, 0.5, length + 0.4), Vector3.new(backX, DECK_Y + wallH + 0.15, 0),
			Color3.fromRGB(206, 196, 176), Enum.Material.Concrete)

		if spec.roof then
			-- cantilever roof over the seats, held by pillars along the back wall
			local roofY = DECK_Y + stepHeight * rows + 8
			local roofDepth = depth + 4
			-- X134: slate-grey steel sheeting (ridged DiamondPlate), dark steel pillars
			lbox("Roof", Vector3.new(roofDepth, 0.8, length + 4), Vector3.new(roofDepth / 2 - 2, roofY, 0),
				Color3.fromRGB(88, 94, 102), Enum.Material.DiamondPlate)
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
				if #geo.spans == 2 and math.abs(z) < TUNNEL_OUT + 2 then
					continue -- the tunnel corridor comes out here
				end
				lbox("Pillar", Vector3.new(1.5, roofY - DECK_Y, 1.5), Vector3.new(backX + 1.5, DECK_Y + (roofY - DECK_Y) / 2, z),
					Color3.fromRGB(58, 62, 68), Enum.Material.Metal)
			end
		end
	end

	PlotContext.place(stand)
	local state = PlotContext.stateFolder()
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
local HAIR_COLORS = {
	Color3.fromRGB(30, 22, 18),
	Color3.fromRGB(70, 45, 25),
	Color3.fromRGB(190, 160, 90),
	Color3.fromRGB(140, 60, 35),
	Color3.fromRGB(190, 190, 190),
}
local FAN_SPACING = 2.8 -- a character is 2 studs across; this is elbow room
-- Fan budget for a full house across the whole ground (mobile). A fan is a
-- seated blocky character: torso, head, hair, two arms and, on the front rows
-- where you can actually see them, thighs. Five parts each on average.
local FAN_PART_BUDGET = 3300
local MAX_FANS = FAN_PART_BUDGET // 5
local FAN_LEG_ROWS = 3 -- above this the row in front hides the legs anyway

-- One seated fan, built like a Roblox character rather than a block with a
-- ball on it: blocky torso, square head with a face, arms down at the sides
-- and thighs forward over the edge of the step. `seat` faces the pitch.
local function buildFan(seat: CFrame, rng: Random, parent: Instance, legs: boolean)
	local shirt = CROWD_COLORS[rng:NextInteger(1, #CROWD_COLORS)]
	local skin = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
	local trousers = Color3.fromRGB(45, 48, 58):Lerp(Color3.new(1, 1, 1), rng:NextNumber() * 0.3)
	local function limb(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material?)
		return part({
			Name = name,
			Size = size,
			CFrame = seat * offset,
			Color = colour,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = parent,
		})
	end
	-- torso sits 1 stud above the step, head on top, arms either side
	limb("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 2, 0), shirt)
	limb("ArmL", Vector3.new(1, 2, 1), CFrame.new(-1.5, 2, 0), shirt)
	limb("ArmR", Vector3.new(1, 2, 1), CFrame.new(1.5, 2, 0), shirt)
	-- thighs forward over the edge of the step, knees down
	if legs then
		limb("Legs", Vector3.new(2, 1, 2), CFrame.new(0, 0.5, -1), trousers)
	end
	local head = limb("Head", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 3.6, 0), skin)
	-- a hair block reads at distance where a face does not
	limb("Hair", Vector3.new(1.5, 0.35, 1.5), CFrame.new(0, 4.375, 0), HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)])
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
end

-- Fills every built stand with fans at a density matching attendance. One fan
-- stands for several real ones, so a full house means every slot filled. The
-- budget is shared across all four plots.
function WorldBuilder.buildCrowd(levels: { [string]: number }, attendance: number, capacity: number)
	local club = PlotContext.clubModel() :: Model
	local stands = club:FindFirstChild("Stands") :: Folder
	local fill = math.clamp(attendance / math.max(capacity, 1), 0, 1)
	local rng = Random.new(attendance)

	-- count the seat slots first, so the budget is shared across the ground
	local totalSlots = 0
	for _, plot in PLOTS do
		local geo = plotGeometry(plot, levels[plot.key] or 0)
		if geo then
			for row = 1, geo.rows do
				for _, run in rowRuns(geo, row) do
					totalSlots += math.floor((run[2] - run[1] - 2) / FAN_SPACING)
				end
			end
		end
	end
	-- Fans always sit at the real seat pitch. When the ground is bigger than
	-- the budget they thin out instead of spreading out: stretching the
	-- spacing put the same z in every row, which read as vertical columns of
	-- people rather than a crowd.
	local spacing = FAN_SPACING
	local base = math.min(fill, MAX_FANS / math.max(totalSlots, 1))

	-- X239: the front-to-back swing, shrunk when the crowd is dense enough that
	-- the front rows would pass 100%; capping them there used to lose ~13% of fans
	local swing = if base > 0 then math.min(0.5, (1 - base) / base) else 0.5

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
		for row = 1, geo.rows do
			local top = DECK_Y + geo.stepHeight * row
			-- sit toward the front of the step so knees clear the row in front
			local x = STAND_X0 + STEP_DEPTH * (row - 1) + STEP_DEPTH / 2 + 0.3
			-- the good seats near the pitch fill first, the back rows thin out;
			-- the weights average to 1 so the budget is still what it says
			local weight = 1 + swing * (1 - 2 * (row - 1) / math.max(geo.rows - 1, 1))
			local chance = math.min(1, base * weight)
			-- offset each row a little so identical seat positions never line
			-- up into a column of people
			local nudge = (row * 0.37) % 1 * spacing
			for _, run in rowRuns(geo, row) do
				local perRow = math.floor((run[2] - run[1] - 2 - nudge) / spacing)
				slots += perRow
				for i = 1, perRow do
					-- deterministic scatter: skip seats so density visibly tracks attendance
					if rng:NextNumber() > chance then
						continue
					end
					local z = run[1] + 1 + nudge + spacing * (i - 0.5)
					-- yaw so the fan's front faces the pitch (local -X)
					buildFan(PlotContext.cframe * geo.frame * CFrame.new(x, top, z) * CFrame.Angles(0, math.pi / 2, 0), rng, crowd, row <= FAN_LEG_ROWS)
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
	local club = PlotContext.clubModel()
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
local AMENITY_POS = Vector3.new(FORECOURT_CX - 2, GROUND_Y, FORECOURT_CZ + 23)

function WorldBuilder.buildAmenity(level: number)
	local club = PlotContext.clubModel() :: Model
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
	PlotContext.place(amenity)
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
	local club = PlotContext.clubModel()
	if not club then
		return
	end
	for _, d in club:GetDescendants() do
		if d:IsA("TextLabel") and d.Name == "ClubName" then
			d.Text = string.upper(name)
		end
	end
end

-- The team coach, parked on the forecourt beside the office (decorative).
-- Primitive on purpose: the store coach was 587 parts per club, this is 11.
-- Nose points +X; built from extents so nothing shares a face.
local function buildTeamBus(parent: Instance, centre: Vector3)
	local bus = Instance.new("Model")
	bus.Name = "TeamBus"
	bus.Parent = parent
	local L, W = 34, 8.5
	local function piece(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, colour: Color3, material: Enum.Material?): Part
		return part({
			Name = name,
			Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
			CFrame = CFrame.new(centre + Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)),
			Color = colour,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = bus,
		})
	end
	local white = Color3.fromRGB(235, 235, 238)
	local glass = Color3.fromRGB(40, 55, 70)
	-- lower body in club colours, white upper body, a glazed band between
	piece("Skirt", -L / 2, L / 2, 1.2, 4.5, -W / 2, W / 2, Config.HomeKit)
	piece("Band", -L / 2, L / 2, 4.5, 8.5, -W / 2 + 0.15, W / 2 - 0.15, glass, Enum.Material.Glass)
	piece("Upper", -L / 2, L / 2, 8.5, 10.8, -W / 2, W / 2, white)
	piece("Roof", -L / 2 + 1, L / 2 - 1, 10.8, 11.2, -W / 2 + 0.5, W / 2 - 0.5, white)
	-- windscreen and destination board at the nose, proud of the body
	piece("Windscreen", L / 2, L / 2 + 0.2, 4.5, 9.5, -W / 2 + 0.6, W / 2 - 0.6, glass, Enum.Material.Glass)
	local board = piece("Destination", L / 2, L / 2 + 0.2, 9.5, 10.6, -W / 2 + 1, W / 2 - 1, Color3.fromRGB(20, 20, 20))
	addSign(board, "TEAM COACH", { Enum.NormalId.Right })
	-- wheels: cylinders run along X, roll them to face sideways
	for _, wx in { -L / 2 + 6, L / 2 - 7 } do
		for _, wz in { -W / 2 + 0.5, W / 2 - 0.5 } do -- 0.1 proud of the body sides
			local wheel = part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 3.2, 3.2),
				CFrame = CFrame.new(centre + Vector3.new(wx, 1.6, wz)) * CFrame.Angles(0, math.pi / 2, 0),
				Color = Color3.fromRGB(25, 25, 25),
				Parent = bus,
			})
			wheel.CastShadow = false
		end
	end
end

function WorldBuilder.build(standLevels: { [string]: number }, amenityLevel: number?): World
	local existing = PlotContext.clubModel()
	if existing then
		existing:Destroy()
	end
	local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
	if defaultSpawn then
		defaultSpawn:Destroy()
	end

	local club = Instance.new("Model")
	club.Name = "Club"
	club.Parent = PlotContext.worldParent()

	buildPitch(club)
	buildHardstanding(club)
	buildPerimeter(club)
	buildAdBoards(club)
	buildDugouts(club)
	buildTunnel(club)
	buildDressingRooms(club)
	buildScoreboard(club)
	buildTurnstiles(club)
	buildForecourt(club)
	buildOffice(club)
	-- the team coach, parked on the forecourt beside the office (decorative)
	buildTeamBus(club, Vector3.new(FORECOURT_CX + 18, DECK_Y, FORECOURT_CZ - 22))

	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = club

	local matchdayPrompt = buildMatchdayBoard(club)
	local standPrompts: { [string]: ProximityPrompt } = {}
	for _, plot in PLOTS do
		standPrompts[plot.key] = buildStandSign(club, plot)
	end
	local amenityPrompt = buildAmenitySign(club)
	-- everything so far was built around the origin; the stands and the
	-- amenity move themselves into the plot as they are (re)built
	PlotContext.place(club)
	WorldBuilder.buildStands(standLevels)
	WorldBuilder.buildAmenity(amenityLevel or 0)
	local state = PlotContext.stateFolder()
	if state then
		WorldBuilder.setClubName((state:GetAttribute("ClubName") :: string?) or Config.ClubName)
	end
	bindScoreboard()

	return {
		model = club,
		matchdayPrompt = matchdayPrompt,
		standPrompts = standPrompts,
		amenityPrompt = amenityPrompt,
	}
end

return WorldBuilder
