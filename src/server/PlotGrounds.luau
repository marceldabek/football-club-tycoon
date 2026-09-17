--!strict
-- The rest of a claimed plot around the stadium (backlog E8.1 / H2.1 / H3.1,
-- visual only): boundary wall, access road, car park, club shop, two training
-- pitches and a footpath. CLAUDE.md s27: "A plot holds the stadium, office, car
-- park, club shop and a couple of training pitches". Reference images:
-- assets/references/RivermereAImap.png (grounds with car parks and training
-- pitches alongside) and RivermereTurnstileEntrance.png (brick club shop with a
-- big display window and a club-coloured fascia, black lamp columns).
--
-- Built in pitch-local coordinates like WorldBuilder, then moved into the plot
-- once with PlotContext.place. The plot is a 760 x 760 square centred on the
-- pitch. North is -Z, the entrance side is -X.
--
-- Layout (pitch-local studs; SIDE_EDGE = 121, END_EDGE = 179, CORNER_Z = 155):
--
--   thing              x range            z range          notes
--   boundary wall      edge of -380..380  edge of -380..380 1 thick, 3 high
--   vehicle gate       x = -380           60..100          40-wide gap, road behind it
--   pedestrian gate    x = -380           -20..-4          16-wide gap, footpath behind it
--   access road        -379..-349         68..92           ends on the car park asphalt
--   car park           -350..-250         40..190          kerb included (TEMP: halved, X9)
--   club shop          -313..-287         -165..-135       front (door, window) faces +X;
--                      (-313.5..-286)     (-165.5..-134.5) with fascia and roof overhang
--   footpath           -379..-261 / -269..-261 / -261..-190  along z -12, north, then east
--                                                          onto the forecourt at z -187
--   training pitch 1   230..330           -170..-10        centre (280, -90)
--   training pitch 2   230..330           10..170          centre (280, 90)
--   training fence     222..338           -178..178        gap at z -6..6 on the west side
--
-- What the constants had to avoid (WorldBuilder / Scenery):
--   * office x -243..-215, z -15..15; dressing rooms x -211..-183 either side of
--     the tunnel corridor (|z| up to ~37). The car park starts at z 40 (south of the
--     office, +Z) and never reaches x > -250, so it clears both.
--   * forecourt + turnstiles x -190..-121, z -225..-150 (the NORTH-west corner,
--     north = -Z). The shop at z -150 sits 97 studs west of it, so it keeps the
--     requested spot and ends up on the walk from the pedestrian gate to the
--     turnstiles, like the reference photo.
--   * deepest stand: STEP_DEPTH is 3 in WorldBuilder (16 rows = 48 studs + roof),
--     so the east stand ends near x 175. The training fence starts at x 222,
--     which also clears the test's more cautious 4.5-per-row keep-out (x 203).
--   * floodlight masts at (+-187, +-245): outside every rectangle above.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PlotContext = require(script.Parent.PlotContext)

local PlotGrounds = {}

-- ------------------------------------------------------------------ constants

local HALF = 380 -- half the plot side (TownLayout.PLOT_SIZE / 2)
local GROUND_Y = 0

-- boundary wall
local WALL_H, WALL_T = 3, 1
local PIER_W, PIER_H = 2, 4 -- square gate piers, along the wall and inward
local VEHICLE_GATE = { 60, 100 } -- z range of the gap on the -X wall
local PEDESTRIAN_GATE = { -20, -4 }

-- access road
local ROAD_W = 24
local ROAD_Z = (VEHICLE_GATE[1] + VEHICLE_GATE[2]) / 2 -- 80
local ROAD_TOP = 0.2

-- car park (kerb included in the rectangle)
-- TEMP (X9): was z 40..340 (100 x 300), which ran most of the way down the
-- entrance side. Halved to 100 x 150: the road mouth (z 68..92) still lands on
-- its west kerb, and the south half of the entrance side is left open.
local PARK_X0, PARK_X1 = -350, -250
local PARK_Z0, PARK_Z1 = 40, 190
local KERB_T, KERB_TOP = 1, 0.5
local ASPHALT_TOP = 0.2
local BAY_W, BAY_D = 9, 18 -- along Z, along X
local BAY_LINE_W = 0.4
local ENTRY_CLEAR_Z = 104 -- the west bay row starts past the road mouth
local LAMP_H = 20
local LAMP_SPOTS = { { -319, 110 }, { -319, 165 }, { -261, 110 }, { -261, 165 } } -- in the two aisles

-- club shop
local SHOP_CX, SHOP_CZ = -300, -150
local SHOP_W, SHOP_H, SHOP_D = 26, 14, 30 -- along X, height, along Z
local SHOP_WALL_T = 1
local FASCIA_H, FASCIA_PROUD = 3, 0.5

-- training pitches
local TRAIN_CX = 280
local TRAIN_CZ = { -90, 90 }
local TRAIN_W, TRAIN_L = 100, 160 -- along X, along Z
local TRAIN_GRASS_TOP = 0.2
local TRAIN_INSET = 6 -- markings sit this far inside the grass edge
local TRAIN_LINE_W = 0.6
local TRAIN_CIRCLE_R = 15
local TRAIN_CIRCLE_SEGMENTS = 16
local TRAIN_GOAL_W, TRAIN_GOAL_H = 12, 5
local FENCE_MARGIN = 8 -- fence line this far outside the grass
local FENCE_H = 8
local FENCE_POST_STEP = 22
local FENCE_GAP = 6 -- half-width of the west gate between the pitches

-- footpath
local PATH_W, PATH_TOP = 8, 0.3
local PATH_Z = (PEDESTRIAN_GATE[1] + PEDESTRIAN_GATE[2]) / 2 -- -12
local PATH_X = -265 -- the north-running leg, between the shop and the office
local FORECOURT_X0 = -(121 + 69) -- WorldBuilder FORECOURT_X0 (-(SIDE_EDGE + 69))
local PATH_END_Z = -187 -- joins the forecourt's west edge about half-way along

-- colours
local BRICK = Color3.fromRGB(150, 82, 62)
local PIER = Color3.fromRGB(128, 70, 54)
local ASPHALT = Color3.fromRGB(58, 58, 62)
local KERB = Color3.fromRGB(170, 168, 160)
local LINE = Color3.fromRGB(235, 235, 230)
local IRON = Color3.fromRGB(28, 30, 32)
local CONCRETE = Color3.fromRGB(150, 148, 142)
local TRAIN_GRASS = Color3.fromRGB(96, 158, 72)
local FENCE_GREEN = Color3.fromRGB(40, 90, 50)

-- ------------------------------------------------------------------- helpers

local function box(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

-- An axis-aligned box from its extents, the way everything here is measured.
local function extents(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number,
	color: Color3, material: Enum.Material, parent: Instance): Part
	return box(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, parent)
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function addSign(target: BasePart, text: string, faces: { Enum.NormalId }, textColor: Color3?)
	for _, face in faces do
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
		label.TextColor3 = textColor or Color3.new(1, 1, 1)
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

-- ----------------------------------------------------------------- footprints

export type Footprint = { name: string, min: Vector2, max: Vector2 }

-- Pitch-local XZ rectangles of the big pieces. Pure; the test checks them
-- against the plot square, each other and the stadium keep-out.
function PlotGrounds.footprints(): { Footprint }
	local out: { Footprint } = {
		{ name = "CarPark", min = Vector2.new(PARK_X0, PARK_Z0), max = Vector2.new(PARK_X1, PARK_Z1) },
		{
			name = "ClubShop",
			-- the fascia stands proud of the front wall and the roof cap overhangs 0.5
			min = Vector2.new(SHOP_CX - SHOP_W / 2 - 0.5, SHOP_CZ - SHOP_D / 2 - 0.5),
			max = Vector2.new(SHOP_CX + SHOP_W / 2 + FASCIA_PROUD + 0.5, SHOP_CZ + SHOP_D / 2 + 0.5),
		},
	}
	for i, cz in TRAIN_CZ do
		table.insert(out, {
			name = "TrainingPitch" .. i,
			min = Vector2.new(TRAIN_CX - TRAIN_W / 2, cz - TRAIN_L / 2),
			max = Vector2.new(TRAIN_CX + TRAIN_W / 2, cz + TRAIN_L / 2),
		})
	end
	return out
end

-- X94: trees and lamp posts along the first leg of the footpath (from the
-- pedestrian gate), so the walk in isn't bare lawn. Pure pitch-local ground
-- points: trees PATH_TREE_SIDE off the path centre on both sides, lamps on the
-- north side between them. Kept clear of the gate opening.
local PATH_TREE_SIDE = 10
local PATH_LAMP_SIDE = 6
function PlotGrounds.pathsideSpots(): ({ Vector3 }, { Vector3 })
	local trees, lamps = {}, {}
	local x0, x1 = -HALF + 30, PATH_X - 18
	local x = x0
	local k = 0
	while x <= x1 do
		for _, side in { -1, 1 } do
			table.insert(trees, Vector3.new(x, GROUND_Y, PATH_Z + side * PATH_TREE_SIDE))
		end
		if k % 2 == 0 and x + 12 <= x1 then
			table.insert(lamps, Vector3.new(x + 12, GROUND_Y, PATH_Z - PATH_LAMP_SIDE))
		end
		x += 24
		k += 1
	end
	return trees, lamps
end

local function buildPathside(parent: Instance)
	local m = model("Pathside", parent)
	local trees, lamps = PlotGrounds.pathsideSpots()
	for i, p in trees do
		local h = 9 + (i % 3)
		extents("Trunk", p.X - 0.45, p.X + 0.45, p.Y, p.Y + h, p.Z - 0.45, p.Z + 0.45, Color3.fromRGB(92, 72, 54), Enum.Material.Wood, m)
		local crown = box("Crown", Vector3.one * (7 + (i % 2)), CFrame.new(p.X, p.Y + h + 2.5, p.Z), Color3.fromRGB(80, 124, 56), Enum.Material.Grass, m)
		crown.Shape = Enum.PartType.Ball
		crown.CastShadow = false
	end
	for _, p in lamps do
		extents("LampPost", p.X - 0.25, p.X + 0.25, p.Y, p.Y + 12, p.Z - 0.25, p.Z + 0.25, Color3.fromRGB(24, 26, 30), Enum.Material.Metal, m)
		extents("Lantern", p.X - 0.6, p.X + 0.6, p.Y + 12, p.Y + 13.4, p.Z - 0.6, p.Z + 0.6, Color3.fromRGB(250, 236, 196), Enum.Material.Glass, m)
		extents("LampCap", p.X - 0.8, p.X + 0.8, p.Y + 13.4, p.Y + 13.8, p.Z - 0.8, p.Z + 0.8, Color3.fromRGB(24, 26, 30), Enum.Material.Metal, m)
	end
end

-- -------------------------------------------------------------- boundary wall

local function buildBoundary(parent: Instance)
	local wall = model("BoundaryWall", parent)
	local y0, y1 = GROUND_Y, GROUND_Y + WALL_H
	-- north and south run the full width; east and west fit between them
	extents("WallN", -HALF, HALF, y0, y1, -HALF, -HALF + WALL_T, BRICK, Enum.Material.Brick, wall)
	extents("WallS", -HALF, HALF, y0, y1, HALF - WALL_T, HALF, BRICK, Enum.Material.Brick, wall)
	local inner0, inner1 = -HALF + WALL_T, HALF - WALL_T
	extents("WallE", HALF - WALL_T, HALF, y0, y1, inner0, inner1, BRICK, Enum.Material.Brick, wall)

	-- west: three runs broken by the two gates, each gap flanked by piers. The
	-- runs stop at the piers so no two pieces share volume.
	local gaps = { PEDESTRIAN_GATE, VEHICLE_GATE } -- sorted by z
	local z = inner0
	for _, gap in gaps do
		local pierStart = gap[1] - PIER_W
		extents("WallW", -HALF, -HALF + WALL_T, y0, y1, z, pierStart, BRICK, Enum.Material.Brick, wall)
		extents("GatePier", -HALF, -HALF + PIER_W, y0, GROUND_Y + PIER_H, pierStart, gap[1], PIER, Enum.Material.Brick, wall)
		extents("GatePier", -HALF, -HALF + PIER_W, y0, GROUND_Y + PIER_H, gap[2], gap[2] + PIER_W, PIER, Enum.Material.Brick, wall)
		z = gap[2] + PIER_W
	end
	extents("WallW", -HALF, -HALF + WALL_T, y0, y1, z, inner1, BRICK, Enum.Material.Brick, wall)
end

-- ------------------------------------------------------------ road + car park

local function buildRoad(parent: Instance)
	-- from just inside the wall to the car park asphalt, through the kerb gap
	extents("AccessRoad", -HALF + WALL_T, PARK_X0 + KERB_T, GROUND_Y, GROUND_Y + ROAD_TOP,
		ROAD_Z - ROAD_W / 2, ROAD_Z + ROAD_W / 2, ASPHALT, Enum.Material.Asphalt, parent)
end

local function buildLamp(x: number, z: number, parent: Instance)
	local base = GROUND_Y + ASPHALT_TOP
	-- Cylinder parts run along X, so stand the column up with a roll
	box("LampColumn", Vector3.new(LAMP_H, 0.8, 0.8), CFrame.new(x, base + LAMP_H / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		IRON, Enum.Material.Metal, parent).Shape = Enum.PartType.Cylinder
	local headY0 = base + LAMP_H
	extents("LampHead", x - 1.5, x + 1.5, headY0, headY0 + 0.6, z - 0.8, z + 0.8, IRON, Enum.Material.Metal, parent)
	-- lens on the underside of the head, not inside it
	extents("LampLens", x - 1.1, x + 1.1, headY0 - 0.1, headY0, z - 0.5, z + 0.5,
		Color3.fromRGB(255, 240, 200), Enum.Material.Neon, parent)
end

local function buildCarPark(parent: Instance)
	local park = model("CarPark", parent)
	local ax0, ax1 = PARK_X0 + KERB_T, PARK_X1 - KERB_T
	local az0, az1 = PARK_Z0 + KERB_T, PARK_Z1 - KERB_T
	extents("Asphalt", ax0, ax1, GROUND_Y, GROUND_Y + ASPHALT_TOP, az0, az1, ASPHALT, Enum.Material.Asphalt, park)

	-- kerb ring: north/south full width, east/west between them; the west kerb
	-- breaks where the road comes in
	local ky0, ky1 = GROUND_Y, GROUND_Y + KERB_TOP
	extents("Kerb", PARK_X0, PARK_X1, ky0, ky1, PARK_Z0, az0, KERB, Enum.Material.Concrete, park)
	extents("Kerb", PARK_X0, PARK_X1, ky0, ky1, az1, PARK_Z1, KERB, Enum.Material.Concrete, park)
	extents("Kerb", ax1, PARK_X1, ky0, ky1, az0, az1, KERB, Enum.Material.Concrete, park)
	local roadZ0, roadZ1 = ROAD_Z - ROAD_W / 2, ROAD_Z + ROAD_W / 2
	extents("Kerb", PARK_X0, ax0, ky0, ky1, az0, roadZ0, KERB, Enum.Material.Concrete, park)
	extents("Kerb", PARK_X0, ax0, ky0, ky1, roadZ1, az1, KERB, Enum.Material.Concrete, park)

	-- Bays: three rows of 18-deep bays running along Z.
	--   west row  x ax0 .. ax0+18   (starts past the road mouth)
	--   aisle     24 wide
	--   middle double row, back to back on a shared centre line
	--   aisle     to the east kerb
	local lineY0, lineY1 = GROUND_Y + ASPHALT_TOP, GROUND_Y + ASPHALT_TOP + 0.1
	local lines = model("BayLines", park)
	local function bayRow(x0: number, z0: number, z1: number)
		local z = z0
		while z <= z1 + 1e-6 do
			extents("BayLine", x0, x0 + BAY_D, lineY0, lineY1, z - BAY_LINE_W / 2, z + BAY_LINE_W / 2, LINE, Enum.Material.SmoothPlastic, lines)
			z += BAY_W
		end
	end
	local westRow = ax0
	local midRow = westRow + BAY_D + 24
	bayRow(westRow, ENTRY_CLEAR_Z, az1 - 6)
	bayRow(midRow, az0 + 8, az1 - 6)
	bayRow(midRow + BAY_D, az0 + 8, az1 - 6)
	-- the shared line down the back of the double row; taller than the bay
	-- lines by a hair so the crossings never have coplanar tops
	local spineZ0, spineZ1 = az0 + 8, az0 + 8 + BAY_W * math.floor((az1 - 6 - (az0 + 8)) / BAY_W)
	extents("BayLineSpine", midRow + BAY_D - BAY_LINE_W / 2, midRow + BAY_D + BAY_LINE_W / 2, lineY0, lineY1 + 0.02,
		spineZ0, spineZ1, LINE, Enum.Material.SmoothPlastic, lines)

	for _, spot in LAMP_SPOTS do
		buildLamp(spot[1], spot[2], park)
	end

	-- pay-and-display machine by the entrance, on the asphalt
	local mx, mz = ax0 + 4, az0 + 4
	extents("PayMachine", mx - 0.75, mx + 0.75, lineY0, lineY0 + 5, mz - 0.5, mz + 0.5,
		Color3.fromRGB(60, 64, 70), Enum.Material.Metal, park)
	extents("PayMachineTop", mx - 0.85, mx + 0.85, lineY0 + 5, lineY0 + 5.4, mz - 0.6, mz + 0.6,
		Color3.fromRGB(230, 190, 40), Enum.Material.SmoothPlastic, park)

	-- MATCHDAY PARKING board on two posts on the verge, facing the gate (-X)
	local sx = PARK_X0 - 5
	local sz0, sz1 = roadZ1 + 4, roadZ1 + 18
	local board = extents("ParkingSign", sx - 0.5, sx, GROUND_Y + 5, GROUND_Y + 9, sz0, sz1,
		Color3.fromRGB(20, 50, 120), Enum.Material.SmoothPlastic, park)
	addSign(board, "MATCHDAY PARKING", { Enum.NormalId.Left })
	for _, pz in { sz0 + 1, sz1 - 1 } do
		-- behind the board, touching its back face
		extents("SignPost", sx, sx + 0.5, GROUND_Y, GROUND_Y + 9, pz - 0.25, pz + 0.25, IRON, Enum.Material.Metal, park)
	end
end

-- ------------------------------------------------------------------ club shop

local function buildShop(parent: Instance)
	local shop = model("ClubShop", parent)
	local x0, x1 = SHOP_CX - SHOP_W / 2, SHOP_CX + SHOP_W / 2
	local z0, z1 = SHOP_CZ - SHOP_D / 2, SHOP_CZ + SHOP_D / 2
	local t = SHOP_WALL_T
	local top = GROUND_Y + SHOP_H - 1 -- walls stop under the 1-thick roof cap
	local frontTop = top - FASCIA_H -- the fascia fills the front above this
	local brick = Enum.Material.Brick

	-- back wall and the two side walls (front/back span the full depth)
	extents("WallBack", x0, x0 + t, GROUND_Y, top, z0, z1, BRICK, brick, shop)
	extents("WallSide", x0 + t, x1 - t, GROUND_Y, top, z0, z0 + t, BRICK, brick, shop)
	extents("WallSide", x0 + t, x1 - t, GROUND_Y, top, z1 - t, z1, BRICK, brick, shop)

	-- front wall (faces +X, towards the footpath), z from north to south:
	--   pier 3 | window 14 | pier 4 | door 6 | pier 3
	local fx0, fx1 = x1 - t, x1
	local winZ0, winZ1 = z0 + 3, z0 + 17
	local doorZ0, doorZ1 = winZ1 + 4, winZ1 + 10
	local sillTop, winTop, doorTop = GROUND_Y + 2.5, GROUND_Y + 8.5, GROUND_Y + 8
	extents("WallFront", fx0, fx1, GROUND_Y, frontTop, z0, winZ0, BRICK, brick, shop)
	extents("Sill", fx0, fx1, GROUND_Y, sillTop, winZ0, winZ1, BRICK, brick, shop)
	local glass = extents("Window", fx0 + 0.2, fx1 - 0.2, sillTop, winTop, winZ0, winZ1,
		Color3.fromRGB(170, 200, 215), Enum.Material.Glass, shop)
	glass.Transparency = 0.45
	extents("WindowHeader", fx0, fx1, winTop, frontTop, winZ0, winZ1, BRICK, brick, shop)
	-- X60: home shirts on show behind the glass (RivermereTurnstileEntrance.png's
	-- club shop window): a rail with three shirts, each a body and a sleeve bar,
	-- and a warm light so they read through the tinted glass
	local rx0, rx1 = fx0 - 1.6, fx0 - 1.4
	extents("DisplayRail", rx0, rx1, winTop - 1, winTop - 0.8, winZ0 + 1, winZ1 - 1, IRON, Enum.Material.Metal, shop)
	for k = 1, 3 do
		local zc = winZ0 + k * (winZ1 - winZ0) / 4
		extents("Shirt", rx0 - 0.1, rx1 + 0.1, sillTop + 1.2, winTop - 1.4, zc - 1.1, zc + 1.1, Config.HomeKit, Enum.Material.Fabric, shop)
		-- sleeves sit inside the body's depth and top (no shared planes) and stop short of the next shirt
		extents("ShirtSleeves", rx0 - 0.05, rx1 + 0.05, winTop - 2.6, winTop - 1.45, zc - 1.6, zc + 1.6, Config.HomeKit, Enum.Material.Fabric, shop)
	end
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 230, 190)
	lamp.Brightness = 1.2
	lamp.Range = 10
	lamp.Parent = glass
	extents("WallFront", fx0, fx1, GROUND_Y, frontTop, winZ1, doorZ0, BRICK, brick, shop)
	extents("DoorHeader", fx0, fx1, doorTop, frontTop, doorZ0, doorZ1, BRICK, brick, shop)
	extents("WallFront", fx0, fx1, GROUND_Y, frontTop, doorZ1, z1, BRICK, brick, shop)

	-- club-coloured fascia across the front, standing proud of the brick
	local fascia = extents("Fascia", fx0, x1 + FASCIA_PROUD, frontTop, top, z0, z1, Config.HomeKit, Enum.Material.SmoothPlastic, shop)
	addSign(fascia, "CLUB SHOP", { Enum.NormalId.Right })
	extents("RoofCap", x0 - 0.5, x1 + FASCIA_PROUD + 0.5, top, top + 1, z0 - 0.5, z1 + 0.5,
		Color3.fromRGB(70, 70, 74), Enum.Material.Concrete, shop)

	-- floor inside, a threshold in the doorway, and an apron out to the path
	extents("Floor", x0 + t, fx0, GROUND_Y, GROUND_Y + PATH_TOP, z0 + t, z1 - t, CONCRETE, Enum.Material.Concrete, shop)
	extents("Threshold", fx0, fx1, GROUND_Y, GROUND_Y + PATH_TOP, doorZ0, doorZ1, CONCRETE, Enum.Material.Concrete, shop)
	extents("Apron", fx1, PATH_X - PATH_W / 2, GROUND_Y, GROUND_Y + PATH_TOP, doorZ0 - 2, doorZ1 + 2, CONCRETE, Enum.Material.Concrete, shop)
end

-- ----------------------------------------------------------- training pitches

local function buildGoal(cx: number, lineZ: number, parent: Instance)
	local y0 = GROUND_Y + TRAIN_GRASS_TOP
	local half = TRAIN_GOAL_W / 2
	for _, sx in { -1, 1 } do
		local px = cx + sx * (half + 0.25)
		extents("GoalPost", px - 0.25, px + 0.25, y0, y0 + TRAIN_GOAL_H, lineZ - 0.25, lineZ + 0.25, LINE, Enum.Material.SmoothPlastic, parent)
	end
	-- crossbar between the posts' inner faces, level with their tops
	extents("Crossbar", cx - half, cx + half, y0 + TRAIN_GOAL_H - 0.5, y0 + TRAIN_GOAL_H, lineZ - 0.25, lineZ + 0.25,
		LINE, Enum.Material.SmoothPlastic, parent)
end

local function buildTrainingPitch(i: number, cz: number, parent: Instance)
	local pitch = model("TrainingPitch" .. i, parent)
	local gx0, gx1 = TRAIN_CX - TRAIN_W / 2, TRAIN_CX + TRAIN_W / 2
	local gz0, gz1 = cz - TRAIN_L / 2, cz + TRAIN_L / 2
	extents("Grass", gx0, gx1, GROUND_Y, GROUND_Y + TRAIN_GRASS_TOP, gz0, gz1, TRAIN_GRASS, Enum.Material.Grass, pitch)

	local lines = model("Markings", pitch)
	local y0, y1 = GROUND_Y + TRAIN_GRASS_TOP, GROUND_Y + TRAIN_GRASS_TOP + 0.1
	local w = TRAIN_LINE_W
	local mx0, mx1 = gx0 + TRAIN_INSET, gx1 - TRAIN_INSET
	local mz0, mz1 = gz0 + TRAIN_INSET, gz1 - TRAIN_INSET
	-- touchlines full length; goal lines and halfway fit between them
	extents("Touchline", mx0, mx0 + w, y0, y1, mz0, mz1, LINE, Enum.Material.SmoothPlastic, lines)
	extents("Touchline", mx1 - w, mx1, y0, y1, mz0, mz1, LINE, Enum.Material.SmoothPlastic, lines)
	extents("GoalLine", mx0 + w, mx1 - w, y0, y1, mz0, mz0 + w, LINE, Enum.Material.SmoothPlastic, lines)
	extents("GoalLine", mx0 + w, mx1 - w, y0, y1, mz1 - w, mz1, LINE, Enum.Material.SmoothPlastic, lines)
	extents("Halfway", mx0 + w, mx1 - w, y0, y1, cz - w / 2, cz + w / 2, LINE, Enum.Material.SmoothPlastic, lines)
	-- centre circle: chords, a touch thicker than the lines so where one
	-- crosses the halfway line the tops are not coplanar. Neighbouring chords
	-- overlap a sliver at their inner corners, so they alternate heights too.
	local n = TRAIN_CIRCLE_SEGMENTS
	local chord = 2 * TRAIN_CIRCLE_R * math.sin(math.pi / n)
	for k = 0, n - 1 do
		local ringH = if k % 2 == 0 then 0.12 else 0.14
		local a = (k + 0.5) * 2 * math.pi / n
		local pos = Vector3.new(TRAIN_CX + math.cos(a) * TRAIN_CIRCLE_R * math.cos(math.pi / n), y0 + ringH / 2,
			cz + math.sin(a) * TRAIN_CIRCLE_R * math.cos(math.pi / n))
		-- chord tangent to the circle: its length runs along the tangent
		box("CentreCircle", Vector3.new(w, ringH, chord), CFrame.new(pos) * CFrame.Angles(0, -a, 0),
			LINE, Enum.Material.SmoothPlastic, lines)
	end

	-- goals on the goal lines, posts centred on the line
	buildGoal(TRAIN_CX, mz0 + w / 2, pitch)
	buildGoal(TRAIN_CX, mz1 - w / 2, pitch)
end

local function buildTrainingFence(parent: Instance)
	local fence = model("TrainingFence", parent)
	local fx0 = TRAIN_CX - TRAIN_W / 2 - FENCE_MARGIN
	local fx1 = TRAIN_CX + TRAIN_W / 2 + FENCE_MARGIN
	local fz0 = TRAIN_CZ[1] - TRAIN_L / 2 - FENCE_MARGIN
	local fz1 = TRAIN_CZ[2] + TRAIN_L / 2 + FENCE_MARGIN
	local y0, y1 = GROUND_Y, GROUND_Y + FENCE_H
	local panelT = 0.2
	local function panel(x0: number, x1: number, z0: number, z1: number)
		local p = extents("MeshPanel", x0, x1, y0, y1, z0, z1, FENCE_GREEN, Enum.Material.SmoothPlastic, fence)
		p.Transparency = 0.4
		p.CastShadow = false
	end
	-- panels on the inside of the fence line; north/south full width, east/west between
	panel(fx0, fx1, fz0, fz0 + panelT)
	panel(fx0, fx1, fz1 - panelT, fz1)
	panel(fx1 - panelT, fx1, fz0 + panelT, fz1 - panelT)
	panel(fx0, fx0 + panelT, fz0 + panelT, -FENCE_GAP) -- west, gate between the pitches
	panel(fx0, fx0 + panelT, FENCE_GAP, fz1 - panelT)

	-- posts just outside the panels (touching, never inside them)
	local postH, postT = FENCE_H + 0.4, 0.4
	local function post(x0: number, z0: number)
		extents("FencePost", x0, x0 + postT, y0, y0 + postH, z0, z0 + postT, FENCE_GREEN, Enum.Material.Metal, fence)
	end
	local function run(from: number, to: number, place: (number) -> ())
		local len = to - from
		local count = math.max(1, math.ceil(len / FENCE_POST_STEP))
		for k = 0, count do
			place(from + len * k / count)
		end
	end
	-- north and south: posts along X, outside the panel face
	run(fx0, fx1 - postT, function(x)
		post(x, fz0 - postT)
		post(x, fz1)
	end)
	-- east: along Z
	run(fz0, fz1 - postT, function(z)
		post(fx1, z)
	end)
	-- west: two runs ending at the gate
	run(fz0, -FENCE_GAP - postT, function(z)
		post(fx0 - postT, z)
	end)
	run(FENCE_GAP, fz1 - postT, function(z)
		post(fx0 - postT, z)
	end)
end

-- ------------------------------------------------------------------- footpath

local function buildFootpath(parent: Instance)
	local path = model("Footpath", parent)
	local y0, y1 = GROUND_Y, GROUND_Y + PATH_TOP
	local hw = PATH_W / 2
	-- in from the pedestrian gate, along z = PATH_Z
	extents("Path", -HALF + WALL_T, PATH_X + hw, y0, y1, PATH_Z - hw, PATH_Z + hw, CONCRETE, Enum.Material.Concrete, path)
	-- north past the shop front (abuts the first leg, no overlap)
	extents("Path", PATH_X - hw, PATH_X + hw, y0, y1, PATH_END_Z - hw, PATH_Z - hw, CONCRETE, Enum.Material.Concrete, path)
	-- east onto the forecourt's west edge
	extents("Path", PATH_X + hw, FORECOURT_X0, y0, y1, PATH_END_Z - hw, PATH_END_Z + hw, CONCRETE, Enum.Material.Concrete, path)
end

-- ---------------------------------------------------------------------- build

-- Builds `Grounds` under the club model. Rebuilding replaces the old one.
-- Part count: wall ~10, road 1, car park ~63 (40 bay lines), shop 15,
-- training pitches 2 x 24 + fence ~5 panels + ~48 posts, footpath 3: ~190.
function PlotGrounds.build(club: Model): Model
	local old = club:FindFirstChild("Grounds")
	if old then
		old:Destroy()
	end
	local grounds = Instance.new("Model")
	grounds.Name = "Grounds"
	grounds:SetAttribute("PlotGrounds", true)
	grounds.Parent = club

	buildBoundary(grounds)
	buildRoad(grounds)
	buildCarPark(grounds)
	buildShop(grounds)
	for i, cz in TRAIN_CZ do
		buildTrainingPitch(i, cz, grounds)
	end
	buildTrainingFence(grounds)
	buildFootpath(grounds)
	buildPathside(grounds)

	PlotContext.place(grounds)
	return grounds
end

return PlotGrounds
