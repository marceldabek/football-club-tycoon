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
--   front pavement     -384.4..-380       -380..380        outside the wall, to the street's own paving
--   gate apron         -387.6..-381       72..88           dropped kerb from the street to the gate
--   access road        -381..-349         72..88           kit lane section; ends on the car park asphalt
--   car park           -350..-250         40..190          kerb included (TEMP: halved, X9)
--   club shop          -313..-287         -165..-135       front (door, window) faces +X;
--                      (-313.5..-286)     (-165.5..-134.5) with fascia and roof overhang
--   footpath           -379..-261 / -269..-261 / -261..-190  along z -12, north, then east
--                                                          onto the forecourt at z -187
--   clubhouse spur     -261..-169         -16..-8          on east to the front doors' apron
--   office path        -250..-157         40..46           car park kerb to the office side door
--   training pitch 1   230..330           -170..-10        centre (280, -90)
--   training pitch 2   230..330           10..170          centre (280, 90)
--   training fence     222..338           -178..178        gap at z -6..6 on the west side
--
-- What the constants had to avoid (WorldBuilder / Scenery):
--   * the clubhouse (WorldBuilder/Clubhouse.luau) x -157..-121, z -40..40, with a
--     paved apron at its front doors (x -169..-157, z -16..16) and one at the
--     office side door (x -157..-147, z 40..46). The car park never reaches
--     x > -250, so it clears them; two paths here join them up.
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
local CrestBadge = require(ReplicatedStorage.Shared.CrestBadge)
local HttpService = game:GetService("HttpService") -- X289: the academy intake
local PlotContext = require(script.Parent.PlotContext)
local KitPlacer = require(script.Parent.KitPlacer)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local PlotGrounds = {}

-- ------------------------------------------------------------------ constants

local HALF = 380 -- half the plot side (TownLayout.PLOT_SIZE / 2)
local GROUND_Y = 0

-- boundary wall. WALL_H/PIER_H are set so the primitive runs finish at the same
-- height as the UKSP__BondaryWall kit pieces (wall 4.6, posts 5.5 including the
-- coping), so the two meet flush where the kit frontage ends.
local WALL_H, WALL_T = 4.1, 1
local PIER_W, PIER_H = 2, 5 -- square gate piers, along the wall and inward
local VEHICLE_GATE = { 60, 100 } -- z range of the gap on the -X wall
local PEDESTRIAN_GATE = { -20, -4 }

-- X369: the stretch of the entrance (-X) wall built from the bought kit instead
-- of stretched Parts. The whole 3,040-stud perimeter in kit pieces would be
-- ~2,120 MeshParts per plot, which four plots cannot afford on a mid-range
-- phone, so the kit covers only the band the player actually walks through --
-- both gates sit inside it -- and the rest of the perimeter stays primitive.
-- TEMP band; widen it once a phone measurement exists.
local KIT_FRONTAGE = { -60, 140 }
local KIT_WALL = "UKSP__BondaryWall__WallStraight"
local KIT_POSTS = "UKSP__BondaryWall__GatePosts"
local KIT_WALL_W = 4.3 -- one piece along the run
local KIT_POSTS_W = 9.3 -- both piers; the opening between them is 6.5
local KIT_GATE_SCALE = 0.39 -- the gate leaves are modelled ~3.6x the wall height
local KIT_GATE_W = 8.9 * KIT_GATE_SCALE

-- access road. It carries on from the town's kit lane (UKSP ModularRoads at
-- RoadTiles.SCALE.lane), which ends on the gate line at x = -381, so it keeps that
-- road's section (unscaled kit numbers from the Straight mesh: carriageway 15.85
-- wide with its top 0.281 below the pavement, paving 4.33 wide each side).
local LANE_SCALE = RoadTiles.SCALE.lane
local ROAD_W = 15.85 * LANE_SCALE
local ROAD_PAVE_W = 4.33 * LANE_SCALE
local ROAD_PAVE_TOP = RoadTiles.SURFACE_Y
local ROAD_START_X = -HALF - 1 -- TownLayout.PLOT_LANE_END.X
local ROAD_Z = (VEHICLE_GATE[1] + VEHICLE_GATE[2]) / 2 -- 80
local ROAD_TOP = RoadTiles.SURFACE_Y - 0.281 * LANE_SCALE

-- the street. Marcel, 2026-09-20: no driveway; the entrance wall stands along the
-- back of the street's pavement, TownLayout.PLOT_STREET_GAP from its centreline.
-- So the street's kerb is at STREET_KERB_X, and between it and the wall are the
-- kit road's own paved strip and (on a walked street) PavingStrips' widening.
--   front pavement  the same widening, laid here for the whole entrance side so a
--                   ground on the ring road (never widened) has one too. It sits a
--                   hair under PavingStrips' top so the two are never one plane.
--   gate apron      a dropped kerb: asphalt over the pavement from the kerb to the
--                   gate line, a hair proud of the paving it crosses
local STREET_GAP = TownLayout.PLOT_STREET_GAP
local STREET_KERB_X = -HALF - (STREET_GAP - ROAD_W / 2)
local FRONT_PAVE_X0 = -HALF - (STREET_GAP - (RoadTiles.KIT_PAVING_OUTER * LANE_SCALE - 1.2))
local FRONT_PAVE_TOP = RoadTiles.SURFACE_Y - 0.04
local APRON_TOP = RoadTiles.SURFACE_Y + 0.03

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
-- X374: was 28 x 32 studs with a 12-high wall, about 10 x 12 x 6 m. A real
-- two-storey pub is nearer 12 x 15 x 7, and this one has to hold its own
-- beside a stadium, so the shell is up about a fifth on every axis.
local PUB_X0, PUB_X1 = -374, -341
-- the extra depth goes BACKWARDS, away from the footpath: growing the front
-- edge instead pushed the patio boundary into the pathside tree line
-- (PlotGroundsTest.pathsideTreesAndLampsKeepOffThePathAndBuildings).
local PUB_Z0, PUB_Z1 = -78, -38
local PUB_WALL_H, PUB_ROOF_H, PUB_EAVE = 13.5, 5.5, 0.9
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
local PATH_X = -265 -- the north-running leg, past the shop front
-- Clubhouse.luau's aprons, which the two clubhouse paths run up to
local CLUBHOUSE_FRONT_APRON_X = -(121 + 36 + 12) -- west edge of the front doors' apron
local CLUBHOUSE_SIDE_APRON = { x = -(121 + 36), z0 = 40, z1 = 46 } -- west edge, z range
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
		gui.LightInfluence = 0.25 -- X270: near-unlit, so it still reads at an evening fixture
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
	extents("Frontage", x0 + 0.5, x1 - 0.5, GROUND_Y, GROUND_Y + 6.2, z1, z1 + 0.3, paint, Enum.Material.WoodPlanks, m)
	for _, wx in { x0 + 6, x1 - 6 } do
		local glass = extents("Window", wx - 3.5, wx + 3.5, GROUND_Y + 2.0, GROUND_Y + 5.4, z1 + 0.3, z1 + 0.45, Color3.fromRGB(96, 78, 52), Enum.Material.Glass, m)
		glass.Transparency = 0.1
	end
	-- X374: the door was 3.2 x 4.8 studs, so SHORTER than the 5-stud characters
	-- walking up to it - the single clearest reason the pub read as a doll's
	-- house. A real door is 0.9 x 2.0 m, which at 2.75 studs/m is 2.5 x 5.5.
	extents("Door", xc - 1.3, xc + 1.3, GROUND_Y, GROUND_Y + 5.8, z1 + 0.3, z1 + 0.5, Color3.fromRGB(60, 36, 24), Enum.Material.Wood, m)
	local fascia = extents("Fascia", x0 + 0.5, x1 - 0.5, GROUND_Y + 6.2, GROUND_Y + 8.2, z1, z1 + 0.5, Config.HomeKit, Enum.Material.SmoothPlastic, m)
	addSign(fascia, "SUPPORTERS' BAR", { Enum.NormalId.Back })
	for _, wx in { x0 + 6, xc, x1 - 6 } do
		extents("UpperWindow", wx - 1.6, wx + 1.6, GROUND_Y + 9.2, GROUND_Y + 12.4, z1, z1 + 0.15, cream, Enum.Material.SmoothPlastic, m)
		extents("UpperPane", wx - 1.3, wx + 1.3, GROUND_Y + 9.5, GROUND_Y + 12.1, z1 + 0.15, z1 + 0.25, Color3.fromRGB(58, 74, 90), Enum.Material.Glass, m)
		-- X257: a flower box on the sill of every upper window (the reference pubs
		-- are covered in flowers); it sits proud of the pane, not through it
		extents("WindowBox", wx - 1.7, wx + 1.7, GROUND_Y + 8.6, GROUND_Y + 9.2, z1 + 0.25, z1 + 1.1,
			Color3.fromRGB(70, 48, 34), Enum.Material.Wood, m)
		extents("WindowBlooms", wx - 1.6, wx + 1.6, GROUND_Y + 9.2, GROUND_Y + 9.7, z1 + 0.3, z1 + 1.05,
			Color3.fromRGB(196, 74, 92), Enum.Material.LeafyGrass, m)
	end
	-- X257: two hanging baskets on brackets between the ground-floor windows
	for _, bx in { x0 + 10.5, x1 - 10.5 } do
		-- bracket arm from the frontage face (z1 + 0.3), basket hung under it,
		-- blooms spilling below. Above head height and walk-through, so nobody
		-- bumps into them on the patio.
		local bracket = extents("BasketBracket", bx - 0.15, bx + 0.15, GROUND_Y + 7.1, GROUND_Y + 7.4, z1 + 0.3, z1 + 1.6,
			Color3.fromRGB(24, 26, 30), Enum.Material.Metal, m)
		local basket = extents("Basket", bx - 0.9, bx + 0.9, GROUND_Y + 6.2, GROUND_Y + 7.1, z1 + 0.7, z1 + 1.5,
			Color3.fromRGB(70, 48, 34), Enum.Material.Wood, m)
		local blooms = extents("BasketBlooms", bx - 1.1, bx + 1.1, GROUND_Y + 5.7, GROUND_Y + 6.2, z1 + 0.6, z1 + 1.6,
			Color3.fromRGB(226, 158, 62), Enum.Material.LeafyGrass, m)
		bracket.CanCollide = false
		basket.CanCollide = false
		blooms.CanCollide = false
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

local COPING = Color3.fromRGB(206, 196, 176) -- limestone, like the stand coping
local COPING_H = 0.5
local COPING_OUT = 0.2 -- overhangs both faces, as on RivermereTurnstileEntrance.png

local function buildBoundary(parent: Instance)
	local wall = model("BoundaryWall", parent)
	local y0, y1 = GROUND_Y, GROUND_Y + WALL_H
	-- X255: coping sits on top of a run; piers get their own, taller cap. The
	-- overhang is only on the wall's thickness axis ("both faces"): overhanging
	-- the run's ends too made the four corners share volume with coplanar tops,
	-- and buried each west run 0.2 into the gate piers.
	local function coping(name: string, x0: number, x1: number, z0: number, z1: number, acrossZ: boolean)
		local ox = if acrossZ then 0 else COPING_OUT
		local oz = if acrossZ then COPING_OUT else 0
		extents(name, x0 - ox, x1 + ox, y1, y1 + COPING_H, z0 - oz, z1 + oz,
			COPING, Enum.Material.Concrete, wall)
	end
	local function pierCap(x0: number, x1: number, z0: number, z1: number)
		-- the pier stands proud of the wall already, so its cap overhangs both ways
		extents("PierCap", x0 - COPING_OUT, x1 + COPING_OUT, GROUND_Y + PIER_H, GROUND_Y + PIER_H + COPING_H,
			z0, z1, COPING, Enum.Material.Concrete, wall)
	end
	-- north and south run the full width; east and west fit between them
	extents("WallN", -HALF, HALF, y0, y1, -HALF, -HALF + WALL_T, BRICK, Enum.Material.Brick, wall)
	coping("CopingN", -HALF, HALF, -HALF, -HALF + WALL_T, true)
	extents("WallS", -HALF, HALF, y0, y1, HALF - WALL_T, HALF, BRICK, Enum.Material.Brick, wall)
	coping("CopingS", -HALF, HALF, HALF - WALL_T, HALF, true)
	local inner0, inner1 = -HALF + WALL_T, HALF - WALL_T
	extents("WallE", HALF - WALL_T, HALF, y0, y1, inner0, inner1, BRICK, Enum.Material.Brick, wall)
	coping("CopingE", HALF - WALL_T, HALF, inner0, inner1, false)

	-- X369: inside KIT_FRONTAGE the entrance wall is built from kit pieces
	-- instead of a stretched Part, so the stretch the player walks through is
	-- brick-and-railings rather than a flat box. Outside the band it stays
	-- primitive, at the same finished height so the two meet flush. If the kit
	-- is not installed, every run falls back to the primitive wall.
	local kitOk = KitPlacer.find(KIT_WALL) ~= nil
	local function wallRun(z0: number, z1: number)
		if z1 - z0 <= 0 then
			return
		end
		local k0 = math.max(z0, KIT_FRONTAGE[1])
		local k1 = math.min(z1, KIT_FRONTAGE[2])
		local pieces = if kitOk then math.floor((k1 - k0) / KIT_WALL_W) else 0
		if pieces < 1 then
			extents("WallW", -HALF, -HALF + WALL_T, y0, y1, z0, z1, BRICK, Enum.Material.Brick, wall)
			coping("CopingW", -HALF, -HALF + WALL_T, z0, z1, false)
			return
		end
		-- whole pieces only; the remainder either side stays primitive so the
		-- run still reaches the piers exactly
		local kitEnd = k0 + pieces * KIT_WALL_W
		KitPlacer.row(KIT_WALL,
			CFrame.new(-HALF + WALL_T / 2, GROUND_Y, k0 + KIT_WALL_W / 2) * CFrame.Angles(0, -math.pi / 2, 0),
			pieces, KIT_WALL_W, wall)
		if k0 > z0 then
			extents("WallW", -HALF, -HALF + WALL_T, y0, y1, z0, k0, BRICK, Enum.Material.Brick, wall)
			coping("CopingW", -HALF, -HALF + WALL_T, z0, k0, false)
		end
		if kitEnd < z1 then
			extents("WallW", -HALF, -HALF + WALL_T, y0, y1, kitEnd, z1, BRICK, Enum.Material.Brick, wall)
			coping("CopingW", -HALF, -HALF + WALL_T, kitEnd, z1, false)
		end
	end

	-- west: three runs broken by the two gates, each gap flanked by piers. The
	-- runs stop at the piers so no two pieces share volume.
	local gaps = { PEDESTRIAN_GATE, VEHICLE_GATE } -- sorted by z
	local z = inner0
	for _, gap in gaps do
		local pierStart = gap[1] - PIER_W
		wallRun(z, pierStart)
		extents("GatePier", -HALF, -HALF + PIER_W, y0, GROUND_Y + PIER_H, pierStart, gap[1], PIER, Enum.Material.Brick, wall)
		pierCap(-HALF, -HALF + PIER_W, pierStart, gap[1])
		extents("GatePier", -HALF, -HALF + PIER_W, y0, GROUND_Y + PIER_H, gap[2], gap[2] + PIER_W, PIER, Enum.Material.Brick, wall)
		pierCap(-HALF, -HALF + PIER_W, gap[2], gap[2] + PIER_W)
		z = gap[2] + PIER_W
	end
	wallRun(z, inner1)
end

-- ------------------------------------------------------------ road + car park

local function buildRoad(parent: Instance)
	-- from the end of the town lane on the gate line to the car park asphalt,
	-- through the kerb gap
	local z0, z1 = ROAD_Z - ROAD_W / 2, ROAD_Z + ROAD_W / 2
	extents("AccessRoad", ROAD_START_X, PARK_X0 + KERB_T, GROUND_Y, GROUND_Y + ROAD_TOP, z0, z1, ASPHALT, Enum.Material.Asphalt, parent)
	-- paved strips stop at the car park kerb
	extents("AccessPavement", ROAD_START_X, PARK_X0, GROUND_Y, GROUND_Y + ROAD_PAVE_TOP, z0 - ROAD_PAVE_W, z0, KERB, Enum.Material.Concrete, parent)
	extents("AccessPavement", ROAD_START_X, PARK_X0, GROUND_Y, GROUND_Y + ROAD_PAVE_TOP, z1, z1 + ROAD_PAVE_W, KERB, Enum.Material.Concrete, parent)

	-- outside the wall: pavement along the whole entrance side, and the dropped
	-- kerb the cars cross it on. Walked over, never bumped into.
	local front = extents("FrontPavement", FRONT_PAVE_X0, -HALF, GROUND_Y, GROUND_Y + FRONT_PAVE_TOP, -HALF, HALF, CONCRETE, Enum.Material.Pavement, parent)
	front.CastShadow = false
	local apron = extents("GateApron", STREET_KERB_X, ROAD_START_X, GROUND_Y, GROUND_Y + APRON_TOP, z0, z1, ASPHALT, Enum.Material.Asphalt, parent)
	apron.CastShadow = false
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
	-- X256 (part): window vinyl, as the reference shopfronts are lettered. Only
	-- the club shop gets it: the town's fronts are single textured parts whose
	-- artwork already carries their own signage, so blind text would land on
	-- brick or a door. The glass faces the path (+X local, the Right face).
	local vinyl = Instance.new("SurfaceGui")
	vinyl.Name = "WindowVinyl"
	vinyl.Face = Enum.NormalId.Right
	vinyl.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	vinyl.PixelsPerStud = 24
	vinyl.LightInfluence = 0.4
	vinyl.MaxDistance = 200
	vinyl.Parent = glass
	for i, line in { "SHIRTS  ·  SCARVES  ·  GIFTS", "OPEN MATCHDAYS FROM 10" } do
		local text = Instance.new("TextLabel")
		text.Name = if i == 1 then "VinylTop" else "VinylBottom"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(0.9, if i == 1 then 0.16 else 0.1)
		text.Position = UDim2.fromScale(0.05, if i == 1 then 0.06 else 0.78)
		text.Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(246, 246, 240)
		text.TextTransparency = 0.12
		text.Text = line
		text.Parent = vinyl
	end
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
	shopText.Size = UDim2.fromScale(0.3, 1)
	shopText.Position = UDim2.fromScale(0.6, 0)
	shopText.Text = "CLUB SHOP"
	local nameText = shopText:Clone()
	nameText.Name = "ClubName"
	nameText.Size = UDim2.fromScale(0.56, 1)
	nameText.Position = UDim2.fromScale(0.02, 0)
	local stateName = PlotContext.stateFolder():GetAttribute("ClubName")
	nameText.Text = string.upper(if type(stateName) == "string" and stateName ~= "" then stateName else Config.ClubName)
	nameText.Parent = shopGui
	-- X244: a crest after "CLUB SHOP", as on the reference fascia
	CrestBadge.draw(shopGui, Config.HomeKit:Lerp(Color3.new(0, 0, 0), 0.45), UDim2.fromScale(0.08, 0.72), UDim2.fromScale(0.95, 0.5))
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
	-- straight on from the gate to the clubhouse's front doors (docs/CLUBHOUSE_PLAN.md)
	extents("ClubhousePath", PATH_X + hw, CLUBHOUSE_FRONT_APRON_X, y0, y1, PATH_Z - hw, PATH_Z + hw, CONCRETE, Enum.Material.Concrete, path)
	-- and from the car park's east kerb to the office side door
	local side = CLUBHOUSE_SIDE_APRON
	extents("OfficePath", PARK_X1, side.x, y0, y1, side.z0, side.z1, CONCRETE, Enum.Material.Concrete, path)
end

-- ---------------------------------------------------------------------- build

-- Builds `Grounds` under the club model. Rebuilding replaces the old one.
-- Part count: wall ~10, road 1, car park ~63 (40 bay lines), shop 15,
-- training pitches 2 x 24 + fence ~5 panels + ~48 posts, footpath 3: ~190.
-- ----------------------------------------------------------------- academy
--
-- X289: academy players walk into the squad from nowhere (X277). The plot had
-- two identical training pitches, no youth setup and nothing anywhere that says
-- the word academy, so the renewal that keeps a squad alive was invisible until
-- a new name appeared in the XI. A hut and a board beside training pitch 2,
-- with this season's intake chalked on it.
local ACADEMY_CX = TRAIN_CX + TRAIN_W / 2 + 18 -- outside the training fence
local ACADEMY_CZ = TRAIN_CZ[2]

local function buildAcademy(parent: Instance)
	local academy = model("Academy", parent)
	local y0 = GROUND_Y
	local w, d, h = 14, 10, 8
	local x0, x1 = ACADEMY_CX - w / 2, ACADEMY_CX + w / 2
	local z0, z1 = ACADEMY_CZ - d / 2, ACADEMY_CZ + d / 2

	-- a portable cabin: slab, two long walls, one end wall, a door end and a
	-- shallow roof. The door faces the pitches (west).
	extents("Slab", x0 - 1, x1 + 1, y0, y0 + 0.4, z0 - 1, z1 + 1, Color3.fromRGB(150, 150, 146), Enum.Material.Concrete, academy)
	local wall = Color3.fromRGB(226, 222, 210)
	extents("WallN", x0, x1, y0 + 0.4, y0 + h, z0, z0 + 0.4, wall, Enum.Material.SmoothPlastic, academy)
	extents("WallS", x0, x1, y0 + 0.4, y0 + h, z1 - 0.4, z1, wall, Enum.Material.SmoothPlastic, academy)
	extents("WallE", x1 - 0.4, x1, y0 + 0.4, y0 + h, z0, z1, wall, Enum.Material.SmoothPlastic, academy)
	-- the west face has the doorway in it: two piers and a header
	extents("WallW", x0, x0 + 0.4, y0 + 0.4, y0 + h, z0, z0 + 3.5, wall, Enum.Material.SmoothPlastic, academy)
	extents("WallW", x0, x0 + 0.4, y0 + 0.4, y0 + h, z1 - 3.5, z1, wall, Enum.Material.SmoothPlastic, academy)
	extents("DoorHeader", x0, x0 + 0.4, y0 + 6.4, y0 + h, z0 + 3.5, z1 - 3.5, wall, Enum.Material.SmoothPlastic, academy)
	extents("Roof", x0 - 0.8, x1 + 0.8, y0 + h, y0 + h + 0.5, z0 - 0.8, z1 + 0.8,
		Color3.fromRGB(86, 90, 96), Enum.Material.Metal, academy)
	local fascia = extents("Fascia", x0 - 0.5, x0 - 0.2, y0 + h - 2.4, y0 + h - 0.4, z0, z1,
		Color3.fromRGB(32, 38, 48), Enum.Material.SmoothPlastic, academy)
	addSign(fascia, "ACADEMY", { Enum.NormalId.Left })

	-- the intake board on the pitch side of the hut, filled in by
	-- PlotGrounds.setAcademyIntake when a season rolls over
	local board = extents("IntakeBoard", x0 - 0.9, x0 - 0.5, y0 + 1.6, y0 + 6.2, z0 + 1, z1 - 1,
		Color3.fromRGB(28, 60, 40), Enum.Material.SmoothPlastic, academy)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Intake"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 26
	gui.LightInfluence = 0.3
	gui.MaxDistance = 220
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.92, 0.2)
	title.Position = UDim2.fromScale(0.04, 0.05)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(240, 240, 235)
	title.Text = "THIS SEASON'S INTAKE"
	title.Parent = gui
	local names = Instance.new("TextLabel")
	names.Name = "Names"
	names.BackgroundTransparency = 1
	names.Size = UDim2.fromScale(0.92, 0.68)
	names.Position = UDim2.fromScale(0.04, 0.27)
	names.Font = Enum.Font.PatrickHand
	names.TextScaled = true
	names.TextWrapped = true
	names.TextXAlignment = Enum.TextXAlignment.Left
	names.TextYAlignment = Enum.TextYAlignment.Top
	names.TextColor3 = Color3.fromRGB(226, 232, 226)
	names.Text = "nobody yet"
	names.Parent = gui
end

-- X289: the names the club's own academy has produced this season, as published
-- by ClubService. Safe to call before the grounds exist.
function PlotGrounds.setAcademyIntake(lines: { string })
	local club = PlotContext.clubModel()
	local grounds = club and club:FindFirstChild("Grounds")
	local label = grounds and grounds:FindFirstChild("Names", true)
	if label and label:IsA("TextLabel") then
		label.Text = if #lines > 0 then table.concat(lines, "\n") else "nobody yet"
	end
end

local intakeBound = false

local function bindAcademy()
	local state = PlotContext.stateFolder()
	if not state then
		return
	end
	local function refresh()
		local raw = state:GetAttribute("Academy")
		local lines = {}
		if type(raw) == "string" and raw ~= "" then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(decoded) == "table" then
				for _, line in decoded do
					if type(line) == "string" then
						table.insert(lines, line)
					end
				end
			end
		end
		PlotGrounds.setAcademyIntake(lines)
	end
	if not intakeBound then
		intakeBound = true
		state:GetAttributeChangedSignal("Academy"):Connect(refresh)
	end
	task.defer(refresh) -- review: a rebuilt board starts blank
end

-- X300: buying the £6,000 amenity changed the concourse hut and nothing else,
-- while the club shop building on the plot looked identical from the first
-- match to the last (X179 stocked it once, for good). The shop now grows with
-- the amenity the club has actually bought:
--   0  nothing sold here: the shelves are bare, the sign is unlit
--   1  stock in (counter, shirts, scarves) and the light on
--   2  the fascia lights up and a shirt goes in the window
--   3  a second window display and an A-board out on the path
-- Rebuilt on every change, and on a world rebuild, like the office fittings.
local SHOP_STOCK = { "Counter", "Till", "Shelf", "FoldedShirts", "ScarfRail", "Scarves" }

function PlotGrounds.dressShop(amenityLevel: number)
	local club = PlotContext.clubModel()
	local grounds = club and club:FindFirstChild("Grounds")
	local shop = grounds and grounds:FindFirstChild("ClubShop")
	if not shop then
		return
	end
	local level = math.clamp(math.floor(amenityLevel), 0, 3)

	local stocked = {}
	for _, name in SHOP_STOCK do
		stocked[name] = true
	end
	for _, d in shop:GetChildren() do
		if d:IsA("BasePart") and stocked[d.Name] then
			d.Transparency = if level >= 1 then 0 else 1
			d.CanCollide = level >= 1
		elseif d:IsA("BasePart") and d.Name == "Fascia" then
			-- the sign is lit from the tier that is actually a shop
			d.Material = if level >= 2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	-- the ceiling light hangs off the scarf rail (X179)
	local light = shop:FindFirstChildWhichIsA("PointLight", true)
	if light then
		light.Enabled = level >= 1
	end

	local old = shop:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	if level < 2 then
		return
	end
	-- the window display: a shirt on a stand, behind the glass
	local display = Instance.new("Model")
	display.Name = "Display"
	display.Parent = shop
	local x0, x1 = SHOP_CX - SHOP_W / 2, SHOP_CX + SHOP_W / 2
	local z0 = SHOP_CZ - SHOP_D / 2
	local floorTop = GROUND_Y + PATH_TOP
	local fx0 = x1 - SHOP_WALL_T
	local stands = if level >= 3 then 2 else 1
	for i = 1, stands do
		local zc = z0 + 6 + (i - 1) * 6
		extents(("DisplayStand%d"):format(i), fx0 - 3.2, fx0 - 2.4, floorTop, floorTop + 3.6, zc - 0.4, zc + 0.4,
			Color3.fromRGB(60, 62, 68), Enum.Material.Metal, display)
		extents(("DisplayShirt%d"):format(i), fx0 - 4.2, fx0 - 1.4, floorTop + 3.6, floorTop + 6.2, zc - 1.6, zc + 1.6,
			if i == 1 then Config.HomeKit else Color3.fromRGB(236, 236, 232), Enum.Material.Fabric, display)
	end
	if level >= 3 then
		-- an A-board out on the apron, the way a shop that wants trade does
		local boardZ = z0 + 20
		local board = extents("ShopBoard", fx0 + 3, fx0 + 3.4, GROUND_Y + PATH_TOP, GROUND_Y + PATH_TOP + 4, boardZ - 2, boardZ + 2,
			Color3.fromRGB(40, 34, 28), Enum.Material.Wood, display)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Right
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 34
		gui.LightInfluence = 0.5
		gui.MaxDistance = 120
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.9, 0.8)
		label.Position = UDim2.fromScale(0.05, 0.1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(240, 236, 226)
		label.Text = "NEW SHIRT\nIN STOCK"
		label.Parent = gui
	end
	PlotContext.place(display)
end

local shopBound = false

local function bindShop()
	local state = PlotContext.stateFolder()
	if not state then
		return
	end
	local function refresh()
		PlotGrounds.dressShop((state:GetAttribute("AmenityLevel") :: number?) or 0)
	end
	if not shopBound then
		shopBound = true
		state:GetAttributeChangedSignal("AmenityLevel"):Connect(refresh)
	end
	task.defer(refresh) -- a rebuilt shop starts bare
end

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
	buildAcademy(grounds) -- X289

	PlotContext.place(grounds)
	bindAcademy()
	bindShop() -- X300
	return grounds
end

return PlotGrounds
