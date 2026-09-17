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
-- X95: a matchday snack kiosk just inside the pedestrian gate, south of the
-- footpath, hatch facing the path (-Z). TEMP.
local KIOSK_CX, KIOSK_CZ = -314, 8 -- between the south-side trees at x -326 and -302
local KIOSK_W, KIOSK_H, KIOSK_D = 12, 9, 8 -- along X, height, along Z
-- X97: a supporters' bar just inside the pedestrian gate, north of the
-- footpath and facing it (+Z), with a patio of picnic benches
-- (RivermereTurnstileEntrance.png has a pub right by the entrance). TEMP.
local PUB_X0, PUB_X1 = -372, -344
local PUB_Z0, PUB_Z1 = -70, -38
local PUB_WALL_H, PUB_ROOF_H, PUB_EAVE = 12, 5, 0.8
local PUB_PATIO_D = 8
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
		{ name = "SupportersBar", min = Vector2.new(PUB_X0 - PUB_EAVE, PUB_Z0 - PUB_EAVE), max = Vector2.new(PUB_X1 + PUB_EAVE, PUB_Z1 + PUB_PATIO_D) },
		{ name = "Kiosk", min = Vector2.new(KIOSK_CX - KIOSK_W / 2 - 0.5, KIOSK_CZ - KIOSK_D / 2 - 1.5), max = Vector2.new(KIOSK_CX + KIOSK_W / 2 + 0.5, KIOSK_CZ + KIOSK_D / 2 + 0.5) },
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

-- X95: planted borders inside the entrance (-X) wall, either side of the two
-- gates (RivermereNorthfields.png / RivermereTurnstileEntrance.png beds of
-- shrubs and lavender). Pure pitch-local rects (x = across, y = along z); the
-- bed starts 0.1 in from the wall's inner face and stops 0.5 short of each pier.
PlotGrounds.BORDER_DEPTH = 4
local BORDER_H = 0.6
local BORDER_RUNS = {
	{ -80, PEDESTRIAN_GATE[1] - PIER_W - 0.5 }, -- north of the pedestrian gate
	{ PEDESTRIAN_GATE[2] + PIER_W + 0.5, VEHICLE_GATE[1] - PIER_W - 0.5 }, -- between the gates
	{ VEHICLE_GATE[2] + PIER_W + 0.5, 160 }, -- south of the vehicle gate
}
local SHRUB_STEP = 12
function PlotGrounds.borderBeds(): { Footprint }
	local out: { Footprint } = {}
	local x0 = -HALF + WALL_T + 0.1
	for i, run in BORDER_RUNS do
		table.insert(out, {
			name = "Border" .. i,
			min = Vector2.new(x0, run[1]),
			max = Vector2.new(x0 + PlotGrounds.BORDER_DEPTH, run[2]),
		})
	end
	return out
end

local function buildBorders(parent: Instance)
	local m = model("Borders", parent)
	local shrubColours = { Color3.fromRGB(62, 104, 50), Color3.fromRGB(78, 120, 58) }
	local flowerColours = { Color3.fromRGB(150, 120, 196), Color3.fromRGB(226, 196, 84), Color3.fromRGB(206, 96, 130) }
	for i, bed in PlotGrounds.borderBeds() do
		local x0, x1, z0, z1 = bed.min.X, bed.max.X, bed.min.Y, bed.max.Y
		extents("Soil", x0, x1, GROUND_Y, GROUND_Y + BORDER_H, z0, z1, Color3.fromRGB(92, 70, 52), Enum.Material.Ground, m)
		-- a low flower strip along the front edge, one colour per bed
		extents("Flowers", x1 - 1.6, x1 - 0.2, GROUND_Y + BORDER_H, GROUND_Y + BORDER_H + 0.5, z0 + 0.3, z1 - 0.3,
			flowerColours[(i - 1) % #flowerColours + 1], Enum.Material.LeafyGrass, m)
		-- rounded shrubs against the wall
		local count = math.max(1, math.floor((z1 - z0) / SHRUB_STEP))
		local step = (z1 - z0) / count
		for k = 1, count do
			local d = 2.6 + (k % 2) * 0.4
			local shrub = box("Shrub", Vector3.one * d, CFrame.new(x0 + 1.7, GROUND_Y + BORDER_H + d * 0.3, z0 + (k - 0.5) * step),
				shrubColours[k % 2 + 1], Enum.Material.LeafyGrass, m)
			shrub.Shape = Enum.PartType.Ball
			shrub.CastShadow = false
		end
	end
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

local function buildKiosk(parent: Instance)
	local m = model("Kiosk", parent)
	local x0, x1 = KIOSK_CX - KIOSK_W / 2, KIOSK_CX + KIOSK_W / 2
	local z0, z1 = KIOSK_CZ - KIOSK_D / 2, KIOSK_CZ + KIOSK_D / 2
	extents("Body", x0, x1, GROUND_Y, GROUND_Y + KIOSK_H, z0, z1, Color3.fromRGB(40, 90, 60), Enum.Material.WoodPlanks, m)
	extents("Roof", x0 - 0.5, x1 + 0.5, GROUND_Y + KIOSK_H, GROUND_Y + KIOSK_H + 0.6, z0 - 1.5, z1 + 0.5, Color3.fromRGB(60, 62, 66), Enum.Material.Metal, m)
	-- serving hatch and counter on the path side, and a sign board over it
	extents("Hatch", x0 + 2, x1 - 2, GROUND_Y + 3.4, GROUND_Y + 6.4, z0 - 0.1, z0, Color3.fromRGB(240, 232, 210), Enum.Material.SmoothPlastic, m)
	extents("Counter", x0 + 1.5, x1 - 1.5, GROUND_Y + 3.2, GROUND_Y + 3.5, z0 - 1.2, z0, Color3.fromRGB(150, 110, 70), Enum.Material.Wood, m)
	local board = extents("SignBoard", x0 + 0.5, x1 - 0.5, GROUND_Y + 6.9, GROUND_Y + 8.6, z0 - 0.2, z0, Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic, m)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(40, 90, 60)
	label.Text = "PIES · TEAS · CHIPS"
	label.Parent = gui
end

local function buildSupportersBar(parent: Instance)
	local m = model("SupportersBar", parent)
	local x0, x1, z0, z1 = PUB_X0, PUB_X1, PUB_Z0, PUB_Z1
	local xc = (x0 + x1) / 2
	local paint = Color3.fromRGB(28, 58, 44) -- pub green ground floor
	local cream = Color3.fromRGB(236, 230, 212)
	extents("Body", x0, x1, GROUND_Y, GROUND_Y + PUB_WALL_H, z0, z1, BRICK, Enum.Material.Brick, m)
	-- painted ground-floor frontage with two lit windows and a door, then the fascia
	extents("Frontage", x0 + 0.5, x1 - 0.5, GROUND_Y, GROUND_Y + 5.2, z1, z1 + 0.3, paint, Enum.Material.WoodPlanks, m)
	for _, wx in { x0 + 6, x1 - 6 } do
		local glass = extents("Window", wx - 3.5, wx + 3.5, GROUND_Y + 1.6, GROUND_Y + 4.6, z1 + 0.3, z1 + 0.45, Color3.fromRGB(96, 78, 52), Enum.Material.Glass, m)
		glass.Transparency = 0.1
	end
	extents("Door", xc - 1.6, xc + 1.6, GROUND_Y, GROUND_Y + 4.8, z1 + 0.3, z1 + 0.5, Color3.fromRGB(60, 36, 24), Enum.Material.Wood, m)
	local fascia = extents("Fascia", x0 + 0.5, x1 - 0.5, GROUND_Y + 5.2, GROUND_Y + 7, z1, z1 + 0.5, Config.HomeKit, Enum.Material.SmoothPlastic, m)
	addSign(fascia, "SUPPORTERS' BAR", { Enum.NormalId.Back })
	for _, wx in { x0 + 6, xc, x1 - 6 } do
		extents("UpperWindow", wx - 1.6, wx + 1.6, GROUND_Y + 8, GROUND_Y + 11, z1, z1 + 0.15, cream, Enum.Material.SmoothPlastic, m)
		extents("UpperPane", wx - 1.3, wx + 1.3, GROUND_Y + 8.3, GROUND_Y + 10.7, z1 + 0.15, z1 + 0.25, Color3.fromRGB(58, 74, 90), Enum.Material.Glass, m)
	end
	-- slate roof: two wedges meeting over the middle of the depth (tall side at local +Z)
	local zc = (z0 + z1) / 2
	local half = (z1 - z0) / 2 + PUB_EAVE
	local roofY = GROUND_Y + PUB_WALL_H + PUB_ROOF_H / 2
	local length = x1 - x0 + PUB_EAVE * 2
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.Size = Vector3.new(length, PUB_ROOF_H, half)
		-- the back slope (side -1) rises toward +Z as built; the front one is turned round
		wedge.CFrame = CFrame.new(xc, roofY, zc + side * half / 2) * (if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		wedge.Color = Color3.fromRGB(74, 82, 96)
		wedge.Material = Enum.Material.Slate
		wedge.Parent = m
	end
	extents("Chimney", x0 + 3, x0 + 5.5, GROUND_Y + PUB_WALL_H + 2, GROUND_Y + PUB_WALL_H + PUB_ROOF_H + 2.5, zc - 1.5, zc + 1.5, BRICK, Enum.Material.Brick, m)
	-- patio in front, a link to the footpath and two picnic benches
	local py0, py1 = GROUND_Y, GROUND_Y + PATH_TOP
	extents("Patio", x0, x1, py0, py1, z1 + 0.5, z1 + PUB_PATIO_D, CONCRETE, Enum.Material.Concrete, m)
	extents("PatioPath", xc - 2, xc + 2, py0, py1, z1 + PUB_PATIO_D, PATH_Z - PATH_W / 2, CONCRETE, Enum.Material.Concrete, m)
	-- X115 (RivermereTurnstileEntrance.png's pub): a hanging sign on an iron
	-- bracket at the east corner, planters either side of the door and a
	-- chalkboard at the patio's edge
	local iron = Color3.fromRGB(24, 24, 26)
	local signX = x1 - 1.5
	extents("SignBracket", signX - 0.1, signX + 0.1, GROUND_Y + 9.5, GROUND_Y + 9.7, z1, z1 + 3.4, iron, Enum.Material.Metal, m)
	local sign = extents("HangingSign", signX - 0.08, signX + 0.08, GROUND_Y + 6.2, GROUND_Y + 9.3, z1 + 0.8, z1 + 3.2, Config.HomeKit, Enum.Material.Wood, m)
	addSign(sign, "SUPPORTERS' BAR", { Enum.NormalId.Left, Enum.NormalId.Right })
	for _, px in { xc - 3.2, xc + 3.2 } do
		extents("Planter", px - 0.8, px + 0.8, py1, py1 + 1.3, z1 + 0.7, z1 + 1.9, Color3.fromRGB(58, 60, 64), Enum.Material.Concrete, m)
		local shrub = box("PlanterShrub", Vector3.one * 1.8, CFrame.new(px, py1 + 1.3 + 0.6, z1 + 1.3), Color3.fromRGB(64, 108, 52), Enum.Material.LeafyGrass, m)
		shrub.Shape = Enum.PartType.Ball
		shrub.CastShadow = false
	end
	local chalk = extents("Chalkboard", x1 - 2.2, x1 - 0.4, py1, py1 + 3, z1 + 6.6, z1 + 6.75, Color3.fromRGB(34, 38, 36), Enum.Material.Wood, m)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- +Z, toward the footpath
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = chalk
	local words = Instance.new("TextLabel")
	words.BackgroundTransparency = 1
	words.Size = UDim2.fromScale(0.86, 0.86)
	words.Position = UDim2.fromScale(0.07, 0.07)
	words.Font = Enum.Font.PatrickHand
	words.TextScaled = true
	words.TextWrapped = true
	words.TextColor3 = Color3.fromRGB(244, 240, 228)
	words.Text = "Good Food Great Company All Welcome"
	words.Parent = gui

	local wood = Color3.fromRGB(140, 104, 68)
	for _, bx in { x0 + 5, x1 - 5 } do
		local bz = z1 + 4.6
		-- solid end frames carry the top and both seats
		for _, ex in { bx - 2, bx + 2 } do
			extents("PicnicFrame", ex - 0.15, ex + 0.15, py1, py1 + 2.4, bz - 2.7, bz + 2.7, wood, Enum.Material.Wood, m)
		end
		extents("PicnicTop", bx - 2.5, bx + 2.5, py1 + 2.4, py1 + 2.7, bz - 1.2, bz + 1.2, wood, Enum.Material.Wood, m)
		for _, sz in { -1, 1 } do
			extents("PicnicSeat", bx - 2.5, bx + 2.5, py1 + 1.3, py1 + 1.55, bz + sz * 2.3 - 0.45, bz + sz * 2.3 + 0.45, wood, Enum.Material.Wood, m)
		end
	end
end

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
	-- X123: a glazed door with a dark frame and a push bar in the doorway,
	-- walk-through (the shop is visual only)
	local door = extents("ShopDoor", fx0 + 0.3, fx1 - 0.3, GROUND_Y + PATH_TOP, doorTop, doorZ0 + 0.15, doorZ1 - 0.15, Color3.fromRGB(70, 92, 108), Enum.Material.Glass, shop)
	door.Transparency = 0.25
	door.CanCollide = false
	extents("ShopDoorBar", fx1 - 0.3, fx1 - 0.1, GROUND_Y + 3.6, GROUND_Y + 3.9, doorZ0 + 1, doorZ1 - 1, IRON, Enum.Material.Metal, shop).CanCollide = false
	extents("WallFront", fx0, fx1, GROUND_Y, frontTop, doorZ1, z1, BRICK, brick, shop)

	-- club-coloured fascia across the front, standing proud of the brick
	local fascia = extents("Fascia", fx0, x1 + FASCIA_PROUD, frontTop, top, z0, z1, Config.HomeKit, Enum.Material.SmoothPlastic, shop)
	-- X122 (RivermereTurnstileEntrance.png: "<CLUB> CLUB SHOP"): the club's name
	-- on the left of the fascia, in a label named ClubName so
	-- WorldBuilder.setClubName repaints it after a rename, "CLUB SHOP" on the right
	addSign(fascia, "", { Enum.NormalId.Right })
	local shopGui = fascia:FindFirstChild("Sign") :: SurfaceGui
	local shopText = shopGui:FindFirstChild("Text") :: TextLabel
	shopText.Size = UDim2.fromScale(0.36, 1)
	shopText.Position = UDim2.fromScale(0.62, 0)
	shopText.Text = "CLUB SHOP"
	local nameText = shopText:Clone()
	nameText.Name = "ClubName"
	nameText.Size = UDim2.fromScale(0.58, 1)
	nameText.Position = UDim2.fromScale(0.02, 0)
	local stateName = PlotContext.stateFolder():GetAttribute("ClubName")
	nameText.Text = string.upper(if type(stateName) == "string" and stateName ~= "" then stateName else Config.ClubName)
	nameText.Parent = shopGui
	extents("RoofCap", x0 - 0.5, x1 + FASCIA_PROUD + 0.5, top, top + 1, z0 - 0.5, z1 + 0.5,
		Color3.fromRGB(70, 70, 74), Enum.Material.Concrete, shop)

	-- floor inside, a threshold in the doorway, and an apron out to the path
	extents("Floor", x0 + t, fx0, GROUND_Y, GROUND_Y + PATH_TOP, z0 + t, z1 - t, CONCRETE, Enum.Material.Concrete, shop)
	extents("Threshold", fx0, fx1, GROUND_Y, GROUND_Y + PATH_TOP, doorZ0, doorZ1, CONCRETE, Enum.Material.Concrete, shop)
	extents("Apron", fx1, PATH_X - PATH_W / 2, GROUND_Y, GROUND_Y + PATH_TOP, doorZ0 - 2, doorZ1 + 2, CONCRETE, Enum.Material.Concrete, shop)

	-- X179: stock inside (8 parts): a counter with a till facing the door, a
	-- shelf of folded shirts on the back wall and a scarf rail on the north wall
	local floorTop = GROUND_Y + PATH_TOP
	local wood = Color3.fromRGB(110, 78, 50)
	local white = Color3.fromRGB(236, 236, 232)
	extents("Counter", x0 + t + 8, x0 + t + 10, floorTop, floorTop + 3.4, z0 + t + 6, z0 + t + 16, wood, Enum.Material.Wood, shop)
	extents("Till", x0 + t + 8.5, x0 + t + 9.5, floorTop + 3.4, floorTop + 4.3, z0 + t + 13, z0 + t + 14.2, Color3.fromRGB(40, 40, 44), Enum.Material.SmoothPlastic, shop)
	local shelfX0, shelfX1 = x0 + t, x0 + t + 1.4
	local shelfY = floorTop + 4.5
	extents("Shelf", shelfX0, shelfX1, shelfY - 0.3, shelfY, z0 + t + 6, z1 - t - 6, wood, Enum.Material.Wood, shop)
	for k, colour in { Config.HomeKit, white, Config.HomeKit } do
		local zc = z0 + t + 6 + k * (SHOP_D - 2 * t - 12) / 4
		extents("FoldedShirts", shelfX0 + 0.1, shelfX1 - 0.1, shelfY, shelfY + 0.9, zc - 1.2, zc + 1.2, colour, Enum.Material.Fabric, shop)
	end
	local railZ0 = z0 + t
	extents("ScarfRail", x0 + t + 12, x0 + t + 20, floorTop + 6.4, floorTop + 6.6, railZ0 + 0.3, railZ0 + 0.5, IRON, Enum.Material.Metal, shop)
	local scarves = extents("Scarves", x0 + t + 12.3, x0 + t + 19.7, floorTop + 3.4, floorTop + 6.4, railZ0 + 0.35, railZ0 + 0.45, Config.HomeKit, Enum.Material.Fabric, shop)
	-- white bars on the room side so the block reads as a row of striped scarves
	local scarfGui = Instance.new("SurfaceGui")
	scarfGui.Face = Enum.NormalId.Back -- +Z, into the shop
	scarfGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	scarfGui.PixelsPerStud = 20
	scarfGui.Parent = scarves
	for k = 0, 5 do
		local gap = Instance.new("Frame")
		gap.BackgroundColor3 = white
		gap.BorderSizePixel = 0
		gap.Position = UDim2.fromScale(k / 6 + 0.13, 0)
		gap.Size = UDim2.fromScale(0.03, 1)
		gap.Parent = scarfGui
		local band = Instance.new("Frame")
		band.BackgroundColor3 = white
		band.BorderSizePixel = 0
		band.Position = UDim2.fromScale(k / 6 + 0.02, 0.62)
		band.Size = UDim2.fromScale(0.1, 0.1)
		band.Parent = scarfGui
	end
	-- a warm ceiling light over the counter
	local shopLight = Instance.new("PointLight")
	shopLight.Color = Color3.fromRGB(255, 232, 196)
	shopLight.Brightness = 1.3
	shopLight.Range = 20
	shopLight.Shadows = false
	shopLight.Parent = scarves
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
	buildKiosk(grounds)
	buildBorders(grounds)
	buildSupportersBar(grounds)

	PlotContext.place(grounds)
	return grounds
end

return PlotGrounds
