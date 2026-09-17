--!strict
-- Rivermere greybox master plan as pure data (no Instances). The plan and the
-- reasoning behind every number live in docs/TOWN_PLAN.md; keep the two in step.
--
-- World frame (TEMP, see docs/BACKLOG.md "TEMP world frame"):
--   * market square centre at (0, 0, 0); +X east, +Z south, so north is -Z
--   * 2.75 studs per metre; ground at y = 0
--   * every polyline (roads, river, rail) sits at y = 0 and is measured in XZ
--
-- Shapes:
--   EXTENT      { minX, maxX, minZ, maxZ } walkable town bounds
--   PLOT_SIZE   side of the square club plot (TEMP 760)
--   PLOTS[i]    i = map plot number. Plot frame = plotCFrame(i): origin is the
--               pitch centre, pitch long axis along local Z, local -X faces the
--               access road (office / entrance side). yaw is degrees about +Y.
--   ROADS       polylines with a kind ("ring" | "main" | "residential" | "lane")
--               and a full carriageway width (pavements come on top, 8 each side).
--               "Plot N Lane" starts on the ring road / a roundabout and ends at
--               plotCFrame(N) * PLOT_LANE_END, 10 studs outside the vehicle gate
--               (PlotGrounds: gate at plot-local x = -380, z 60..100).
--   RIVER       the River Lune centreline, flowing west -> east, with its width
--   BRIDGES     from/to are the deck ends (both on dry land); kind "road" | "rail" | "foot"
--   RAIL        track centreline plus the station building box
--   DISTRICTS   greybox volumes: centre.Y = size.Y / 2 so each box sits on the ground.
--               All yaw 0. No two boxes overlap (a building may stand on a flat
--               ground piece, e.g. the bandstand on the park lawn), and every box
--               keeps clear of carriageway + pavements, the river (width/2 + 20,
--               except the marina basin), the rail, roundabouts, bus stops,
--               landmarks and plots (+20). Most rows were laid out by a frontage
--               script: rows set back 6 from the pavement, back-to-back pairs with a
--               12 alley (see docs/TOWN_PLAN.md).
--   SQUARE      the round market square
--   ROUNDABOUTS ring-road junctions (radius = central island + circulating lane)
--   LANDMARKS   position at ground level plus the top height in studs
--   BUS_STOPS   fast-travel stops; yaw is the direction the shelter faces
--
-- Helpers are all XZ-plane: segmentDistance, distanceToPolyline, riverSide,
-- plotCFrame, plotCorners, pointInPlot, plotEntranceDirection.

local TownLayout = {}

export type Plot = { index: number, name: string, centre: Vector3, yaw: number, busStop: Vector3 }
export type RoadKind = "ring" | "main" | "residential" | "lane"
export type Road = { name: string, kind: RoadKind, width: number, points: { Vector3 } }
export type River = { name: string, width: number, points: { Vector3 } }
export type Bridge = { name: string, kind: "road" | "rail" | "foot", from: Vector3, to: Vector3, width: number }
export type Box = { centre: Vector3, size: Vector3, yaw: number, use: string }
export type Station = { name: string, centre: Vector3, size: Vector3, yaw: number }
export type Rail = { width: number, points: { Vector3 }, station: Station }
export type District = { name: string, kind: string, blocks: { Box } }
export type Landmark = { name: string, position: Vector3, height: number }
export type BusStop = { name: string, position: Vector3, yaw: number }
export type Roundabout = { name: string, centre: Vector3, radius: number }

TownLayout.STUDS_PER_METRE = 2.75
TownLayout.EXTENT = { minX = -2400, maxX = 2400, minZ = -1700, maxZ = 1700 }
TownLayout.PLOT_SIZE = 760 -- TEMP: fits a ~30k stadium (~480 x 560) + car park, shop, two training pitches
TownLayout.PAVEMENT_WIDTH = 8
TownLayout.PLOT_LANE_END = Vector3.new(-390, 0, 80) -- plot-local, 10 outside the vehicle gate centre

TownLayout.SQUARE = { name = "Market Square", centre = Vector3.new(0, 0, 0), radius = 60 }

-- X51: the station taxi rank / drop-off lay-by, cut into Station Road's
-- station-side pavement between the forecourt and the carriageway. TownBuilder
-- lays no pavement over it; StationDresser surfaces it and parks the taxis.
TownLayout.STATION_LAYBY = { from = Vector3.new(-890, 0, -354), to = Vector3.new(-804, 0, -354), width = 8 }

TownLayout.ROUNDABOUTS = {
	{ name = "Northfields Roundabout", centre = Vector3.new(0, 0, -1050), radius = 40 },
	{ name = "Plot 4 Roundabout", centre = Vector3.new(-1300, 0, -800), radius = 40 },
	{ name = "Plot 2 Roundabout", centre = Vector3.new(1300, 0, -800), radius = 40 },
	{ name = "Plot 3 Roundabout", centre = Vector3.new(1400, 0, 400), radius = 40 },
	{ name = "Hollingford Roundabout", centre = Vector3.new(1250, 0, 720), radius = 40 },
	{ name = "Sports Centre Roundabout", centre = Vector3.new(0, 0, 800), radius = 40 },
	{ name = "Westdale Roundabout", centre = Vector3.new(-1100, 0, 700), radius = 40 },
	{ name = "High Street Roundabout", centre = Vector3.new(-1250, 0, -100), radius = 40 },
	{ name = "Mapleford Roundabout", centre = Vector3.new(-1350, 0, -400), radius = 40 },
	-- X55: a small planted roundabout at the industrial estate entrance (Foundry Way x Estate Road)
	{ name = "Foundry Way Roundabout", centre = Vector3.new(-1480, 0, -102), radius = 16 },
} :: { Roundabout }

TownLayout.PLOTS = {
	{ -- south-east, entrance faces north
		index = 1,
		name = "Plot 1",
		centre = Vector3.new(1050, 0, 1250),
		yaw = 270,
		busStop = Vector3.new(992, 0, 840),
	},
	{ -- north-east, entrance faces west
		index = 2,
		name = "Plot 2",
		centre = Vector3.new(1900, 0, -1200),
		yaw = 0,
		busStop = Vector3.new(1490, 0, -1142),
	},
	{ -- east, entrance faces west
		index = 3,
		name = "Plot 3",
		centre = Vector3.new(1950, 0, 420),
		yaw = 0,
		busStop = Vector3.new(1540, 0, 522),
	},
	{ -- north-west, entrance faces east
		index = 4,
		name = "Plot 4",
		centre = Vector3.new(-1900, 0, -1200),
		yaw = 180,
		busStop = Vector3.new(-1490, 0, -1302),
	},
} :: { Plot }

TownLayout.ROADS = {
	{
		name = "Ring Road",
		kind = "ring",
		width = 32,
		points = {
			Vector3.new(-1300, 0, -800), Vector3.new(-650, 0, -1000), Vector3.new(0, 0, -1050),
			Vector3.new(650, 0, -1000), Vector3.new(1300, 0, -800), Vector3.new(1400, 0, -400),
			Vector3.new(1400, 0, -60), Vector3.new(1400, 0, 150), Vector3.new(1400, 0, 400),
			Vector3.new(1250, 0, 720), Vector3.new(700, 0, 800), Vector3.new(0, 0, 800), Vector3.new(-600, 0, 800),
			Vector3.new(-1100, 0, 700), Vector3.new(-1150, 0, 430), Vector3.new(-1150, 0, 200),
			Vector3.new(-1250, 0, -100), Vector3.new(-1350, 0, -400), Vector3.new(-1300, 0, -800),
		},
	},
	{
		name = "Mapleford Road",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(-1350, 0, -400), Vector3.new(-2400, 0, -380),
		},
	},
	{
		name = "Greenbridge Road",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(-1100, 0, 700), Vector3.new(-1100, 0, 1100), Vector3.new(-2400, 0, 1500),
		},
	},
	{
		name = "Hollingford Road",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(1250, 0, 720), Vector3.new(1500, 0, 840), Vector3.new(2400, 0, 860),
		},
	},
	{
		name = "High Street",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(-1250, 0, -100), Vector3.new(-460, 0, -60), Vector3.new(-60, 0, 0),
		},
	},
	{
		name = "Riverside Road",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(60, 0, 0), Vector3.new(500, 0, 40), Vector3.new(900, 0, 60), Vector3.new(1400, 0, -60),
		},
	},
	{
		name = "North Road",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(0, 0, -60), Vector3.new(0, 0, -1050),
		},
	},
	{
		name = "Bridge Street",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(0, 0, 60), Vector3.new(100, 0, 300), Vector3.new(100, 0, 540), Vector3.new(0, 0, 800),
		},
	},
	{
		name = "Station Road",
		kind = "main",
		width = 26,
		points = {
			-- X51: turns to run along the station forecourt and on to the car park
			Vector3.new(-460, 0, -60), Vector3.new(-700, 0, -300), Vector3.new(-790, 0, -337), Vector3.new(-938, 0, -337),
		},
	},
	{
		name = "Estate Road",
		kind = "main",
		width = 26,
		points = {
			Vector3.new(-1250, 0, -100), Vector3.new(-2300, 0, -110),
		},
	},
	{
		name = "Mill Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(0, 0, -200), Vector3.new(900, 0, -200),
		},
	},
	{
		name = "Weaver Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-430, 0, -330), Vector3.new(900, 0, -330),
		},
	},
	{
		name = "Elm Grove",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-500, 0, -440), Vector3.new(900, 0, -440),
		},
	},
	{
		name = "Northfields Avenue",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1320, 0, -600), Vector3.new(1345, 0, -600),
		},
	},
	{
		name = "Hayfield Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(400, 0, -600), Vector3.new(400, 0, -920),
		},
	},
	{
		name = "Rowan Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-200, 0, -600), Vector3.new(-200, 0, -920),
		},
	},
	{
		name = "Westdale Avenue",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1100, 0, 950), Vector3.new(-690, 0, 950),
		},
	},
	{
		name = "Westdale Crescent",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1250, 0, 1250), Vector3.new(-690, 0, 1250),
		},
	},
	{
		name = "Sports Centre Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(0, 0, 800), Vector3.new(0, 0, 1200), Vector3.new(520, 0, 1200),
		},
	},
	{
		name = "Linden Way",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-700, 0, -920), Vector3.new(700, 0, -920),
		},
	},
	{
		name = "Elder Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1200, 0, -600), Vector3.new(-1200, 0, -827),
		},
	},
	{
		name = "Ash Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1000, 0, -600), Vector3.new(-1000, 0, -888),
		},
	},
	{
		name = "Birch Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-800, 0, -600), Vector3.new(-800, 0, -950),
		},
	},
	{
		name = "Cherry Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-600, 0, -600), Vector3.new(-600, 0, -920),
		},
	},
	{
		name = "Hazel Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-400, 0, -600), Vector3.new(-400, 0, -920),
		},
	},
	{
		name = "Holly Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(225, 0, -600), Vector3.new(225, 0, -920),
		},
	},
	{
		name = "Laurel Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(650, 0, -600), Vector3.new(650, 0, -920),
		},
	},
	{
		name = "Maple Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(850, 0, -600), Vector3.new(850, 0, -935),
		},
	},
	{
		name = "Oak Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(1050, 0, -600), Vector3.new(1050, 0, -873),
		},
	},
	{
		name = "Poplar Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(1250, 0, -600), Vector3.new(1250, 0, -812),
		},
	},
	{
		name = "Church Lane",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-360, 0, -45), Vector3.new(-360, 0, -330),
		},
	},
	{
		name = "Cooper Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1296, 0, -240), Vector3.new(-640, 0, -240),
		},
	},
	{
		name = "Lock Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1160, 0, 150), Vector3.new(-540, 0, 150),
		},
	},
	{
		name = "Lune Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-440, 0, 260), Vector3.new(480, 0, 260),
		},
	},
	{
		name = "Meadow Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(92, 0, 560), Vector3.new(1325, 0, 560),
		},
	},
	{
		name = "Viaduct Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-545, 0, 620), Vector3.new(69, 0, 620),
		},
	},
	{
		name = "Weir Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1126, 0, 560), Vector3.new(-615, 0, 560),
		},
	},
	{
		name = "Westdale Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-915, 0, 737), Vector3.new(-915, 0, 1400),
		},
	},
	{
		name = "Brook Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1100, 0, 1100), Vector3.new(-690, 0, 1100),
		},
	},
	{
		name = "Orchard Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1700, 0, 1400), Vector3.new(-690, 0, 1400),
		},
	},
	{
		name = "Alder Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1250, 0, 1146), Vector3.new(-1250, 0, 1400),
		},
	},
	{
		name = "Cedar Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-470, 0, 800), Vector3.new(-470, 0, 1500),
		},
	},
	{
		name = "Moss Lane",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1800, 0, 560), Vector3.new(-1134, 0, 560),
		},
	},
	{
		name = "Fern Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1800, 0, 800), Vector3.new(-1113, 0, 800),
		},
	},
	{
		name = "Reed Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1600, 0, 380), Vector3.new(-1600, 0, 1110),
		},
	},
	{
		name = "Hollins Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(520, 0, 800), Vector3.new(520, 0, 1500),
		},
	},
	{
		name = "Foundry Way",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1480, 0, -397), Vector3.new(-1480, 0, 120),
		},
	},
	{
		name = "Plot 1 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(970, 0, 761), Vector3.new(970, 0, 860),
		},
	},
	{
		name = "Plot 2 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(1300, 0, -800), Vector3.new(1300, 0, -1120), Vector3.new(1510, 0, -1120),
		},
	},
	{
		name = "Plot 3 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(1400, 0, 400), Vector3.new(1460, 0, 500), Vector3.new(1560, 0, 500),
		},
	},
	{
		name = "Plot 4 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(-1300, 0, -800), Vector3.new(-1300, 0, -1280), Vector3.new(-1510, 0, -1280),
		},
	},
} :: { Road }

TownLayout.RIVER = {
	name = "River Lune",
	width = 90,
	points = {
		Vector3.new(-2400, 0, 180), Vector3.new(-1800, 0, 220), Vector3.new(-1200, 0, 300),
		Vector3.new(-700, 0, 380), Vector3.new(-200, 0, 420), Vector3.new(300, 0, 420), Vector3.new(800, 0, 360),
		Vector3.new(1200, 0, 220), Vector3.new(1450, 0, 0), Vector3.new(1600, 0, -250), Vector3.new(1900, 0, -400),
		Vector3.new(2400, 0, -450),
	},
} :: River

TownLayout.BRIDGES = {
	{ name = "West Bridge", kind = "road", from = Vector3.new(-1150, 0, 400), to = Vector3.new(-1150, 0, 215), width = 32 },
	{ name = "Lune Bridge", kind = "road", from = Vector3.new(100, 0, 330), to = Vector3.new(100, 0, 510), width = 26 },
	{ name = "East Bridge", kind = "road", from = Vector3.new(1400, 0, -60), to = Vector3.new(1400, 0, 150), width = 32 },
	{ name = "Lune Viaduct", kind = "rail", from = Vector3.new(-530, 0, 260), to = Vector3.new(-570, 0, 540), width = 16 },
} :: { Bridge }

-- Road bridges are humped (X31, RivermereRiverside.png): straight ramps of
-- BRIDGE_RAMP studs from each end climb BRIDGE_RISE above the street, and the
-- middle stays level over the water (every road bridge's water starts ~45 in).
TownLayout.BRIDGE_RISE = 6 -- TEMP
TownLayout.BRIDGE_RAMP = 40 -- TEMP

export type BridgeSection = { s0: number, s1: number, rise0: number, rise1: number }

-- Horizontal length of a bridge.
function TownLayout.bridgeLength(bridge: Bridge): number
	return Vector3.new(bridge.to.X - bridge.from.X, 0, bridge.to.Z - bridge.from.Z).Magnitude
end

-- Height of the deck above its flat level `along` studs from bridge.from.
-- Rail bridges (and anything off the ends) are 0.
function TownLayout.bridgeRise(bridge: Bridge, along: number): number
	if bridge.kind ~= "road" then
		return 0
	end
	local length = TownLayout.bridgeLength(bridge)
	if along <= 0 or along >= length then
		return 0
	end
	local ramp = math.min(TownLayout.BRIDGE_RAMP, length / 2)
	local fromEnd = math.min(along, length - along)
	return TownLayout.BRIDGE_RISE * math.min(1, fromEnd / ramp)
end

-- The straight pieces a deck is built from: up-ramp, level middle, down-ramp.
function TownLayout.bridgeSections(bridge: Bridge): { BridgeSection }
	local length = TownLayout.bridgeLength(bridge)
	if bridge.kind ~= "road" then
		return { { s0 = 0, s1 = length, rise0 = 0, rise1 = 0 } }
	end
	local ramp = math.min(TownLayout.BRIDGE_RAMP, length / 2)
	local rise = TownLayout.BRIDGE_RISE
	local sections = { { s0 = 0, s1 = ramp, rise0 = 0, rise1 = rise } }
	if length - 2 * ramp > 1e-3 then
		table.insert(sections, { s0 = ramp, s1 = length - ramp, rise0 = rise, rise1 = rise })
	end
	table.insert(sections, { s0 = length - ramp, s1 = length, rise0 = rise, rise1 = 0 })
	return sections
end

-- How far along a bridge `p` is (from bridge.from, horizontal), and how far
-- off its centreline.
function TownLayout.bridgeAlong(bridge: Bridge, p: Vector3): (number, number)
	local seg = Vector3.new(bridge.to.X - bridge.from.X, 0, bridge.to.Z - bridge.from.Z)
	local length = seg.Magnitude
	if length < 1e-6 then
		return 0, Vector3.new(p.X - bridge.from.X, 0, p.Z - bridge.from.Z).Magnitude
	end
	local u = seg / length
	local ap = Vector3.new(p.X - bridge.from.X, 0, p.Z - bridge.from.Z)
	local along = ap:Dot(u)
	local across = math.abs(ap.X * -u.Z + ap.Z * u.X)
	return along, across
end

TownLayout.RAIL = {
	width = 16,
	points = {
		Vector3.new(-2400, 0, -560), Vector3.new(-1400, 0, -470), Vector3.new(-1000, 0, -440),
		Vector3.new(-600, 0, -440), Vector3.new(-480, 0, -340), Vector3.new(-460, 0, -100),
		Vector3.new(-500, 0, 150), Vector3.new(-530, 0, 260), Vector3.new(-570, 0, 540), Vector3.new(-650, 0, 900),
		Vector3.new(-620, 0, 1700),
	},
	station = { name = "Rivermere Station", centre = Vector3.new(-800, 12, -400), size = Vector3.new(240, 24, 40), yaw = 0 },
} :: Rail

TownLayout.DISTRICTS = {
	{
		name = "Town Centre",
		kind = "centre",
		blocks = {
			{ centre = Vector3.new(-130, 20, -100), size = Vector3.new(100, 40, 40), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(120, 20, -100), size = Vector3.new(100, 40, 40), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(-130, 18, 100), size = Vector3.new(100, 36, 40), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(130, 18, 100), size = Vector3.new(100, 36, 40), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(260, 17, -45), size = Vector3.new(100, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(260, 17, 70), size = Vector3.new(100, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(400, 15, -35), size = Vector3.new(100, 30, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(400, 15, 85), size = Vector3.new(100, 30, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-260, 17, -80), size = Vector3.new(100, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-260, 17, 30), size = Vector3.new(100, 34, 30), yaw = 0, use = "supermarket" },
			{ centre = Vector3.new(-150, 15, 200), size = Vector3.new(120, 30, 60), yaw = 0, use = "town hall" },
			{ centre = Vector3.new(-220, 20, -230), size = Vector3.new(40, 40, 90), yaw = 0, use = "church" },
			{ centre = Vector3.new(87, 18, 50), size = Vector3.new(30, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(-36, 15, 135), size = Vector3.new(30, 30, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-50, 18, 87), size = Vector3.new(30, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(-87, 17, 50), size = Vector3.new(30, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-135, 16, 36), size = Vector3.new(30, 32, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-87, 15, -50), size = Vector3.new(30, 30, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-50, 15, -87), size = Vector3.new(30, 30, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(87, 17, -50), size = Vector3.new(30, 34, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(135, 17, -36), size = Vector3.new(30, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-431, 16, -15), size = Vector3.new(30, 32, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-385, 17, -7), size = Vector3.new(50, 34, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-339, 16, -1), size = Vector3.new(30, 32, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-173, 17, 24), size = Vector3.new(30, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-420, 20, 50), size = Vector3.new(70, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-271, 20, 73), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-409, 16, -94), size = Vector3.new(50, 32, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-183, 17, -59), size = Vector3.new(30, 34, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-147, 16, -54), size = Vector3.new(30, 32, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-300, 20, -140), size = Vector3.new(70, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(131, 18, 46), size = Vector3.new(30, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(167, 17, 49), size = Vector3.new(30, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(478, 18, 78), size = Vector3.new(40, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(231, 20, 111), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(365, 19, 124), size = Vector3.new(80, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(459, 18, 131), size = Vector3.new(60, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(484, 16, -1), size = Vector3.new(40, 32, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(499, 20, -56), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(38, 17, -85), size = Vector3.new(30, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(38, 18, -121), size = Vector3.new(30, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(-38, 17, -130), size = Vector3.new(30, 34, 40), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-38, 17, -181), size = Vector3.new(30, 34, 50), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-83, 20, -160), size = Vector3.new(36, 40, 60), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1, 17, 177), size = Vector3.new(30, 34, 40), yaw = 0, use = "shops" },
			{ centre = Vector3.new(91, 18, 157), size = Vector3.new(30, 36, 50), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(106, 16, 205), size = Vector3.new(30, 32, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(190, 19, 175), size = Vector3.new(36, 38, 70), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-250, 15, 310), size = Vector3.new(120, 30, 60), yaw = 0, use = "school" },
		},
	},
	{
		name = "Mill Street Terraces",
		kind = "terraced",
		blocks = {
			{ centre = Vector3.new(100, 12, -164), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -164), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(100, 12, -236), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -236), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(100, 12, -294), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -294), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(100, 12, -366), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -366), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(440, 13, -164), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(580, 12, -164), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(720, 13, -164), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(860, 11, -164), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(235, 11, -128), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(365, 12, -128), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(505, 13, -128), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(635, 12, -128), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(750, 13, -128), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(870, 12, -128), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(430, 11, -236), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(560, 11, -236), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(705, 13, -236), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(835, 12, -236), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(440, 11, -272), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(565, 13, -272), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(690, 12, -272), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(830, 13, -272), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-280, 13, -294), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-155, 11, -294), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-140, 12, -258), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-365, 13, -366), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-240, 13, -366), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-120, 12, -366), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(430, 11, -366), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(550, 12, -366), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(670, 11, -366), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(785, 12, -366), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-380, 11, -402), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-250, 12, -402), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-105, 11, -402), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(90, 13, -402), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(210, 13, -402), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(335, 13, -402), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(480, 13, -402), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(625, 11, -402), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(765, 13, -402), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(895, 13, -402), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-396, 11, -165), size = Vector3.new(24, 22, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-432, 13, -195), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
		},
	},
	{
		name = "Northfields",
		kind = "estate",
		blocks = {
			{ centre = Vector3.new(-150, 12, -470), size = Vector3.new(120, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(200, 12, -470), size = Vector3.new(120, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(350, 12, -470), size = Vector3.new(120, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-290, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-100, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(150, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(550, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(750, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-290, 12, -630), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-100, 12, -630), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(150, 12, -630), size = Vector3.new(100, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(300, 12, -630), size = Vector3.new(100, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(550, 12, -630), size = Vector3.new(100, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(750, 12, -630), size = Vector3.new(100, 24, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(370, 12, -720), size = Vector3.new(24, 24, 100), yaw = 0, use = "semis" },
			{ centre = Vector3.new(430, 12, -720), size = Vector3.new(24, 24, 100), yaw = 0, use = "semis" },
			{ centre = Vector3.new(370, 12, -840), size = Vector3.new(24, 24, 100), yaw = 0, use = "semis" },
			{ centre = Vector3.new(430, 12, -840), size = Vector3.new(24, 24, 100), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-230, 12, -720), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-170, 12, -720), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-230, 12, -840), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-170, 12, -840), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1100, 15, -750), size = Vector3.new(140, 30, 90), yaw = 0, use = "school" },
			{ centre = Vector3.new(-430, 12, -476), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-285, 12, -476), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(490, 12, -476), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(630, 11, -476), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(765, 13, -476), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(900, 12, -476), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-450, 11, -512), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-320, 13, -512), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-180, 13, -512), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(90, 12, -512), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(220, 12, -512), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(350, 12, -512), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(470, 11, -512), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(595, 12, -512), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(735, 13, -512), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(860, 11, -512), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1165, 10, -640), size = Vector3.new(22, 20, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1131, 11, -645), size = Vector3.new(22, 22, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1235, 10, -643), size = Vector3.new(22, 20, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1235, 10, -698), size = Vector3.new(22, 20, 44), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1235, 10, -759), size = Vector3.new(22, 20, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1269, 11, -645), size = Vector3.new(22, 22, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1269, 11, -705), size = Vector3.new(22, 22, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-964, 12, -675), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-964, 12, -795), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-928, 12, -685), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-764, 12, -680), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-764, 13, -800), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-764, 12, -890), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-728, 12, -675), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-728, 12, -790), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-836, 12, -640), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-836, 12, -720), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-836, 11, -845), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-872, 12, -675), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-872, 12, -790), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-564, 11, -685), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-564, 11, -810), size = Vector3.new(24, 22, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-528, 12, -690), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-528, 11, -830), size = Vector3.new(24, 22, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-636, 11, -680), size = Vector3.new(24, 22, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-636, 12, -770), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-672, 12, -690), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-672, 12, -820), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-364, 13, -690), size = Vector3.new(24, 26, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-364, 11, -830), size = Vector3.new(24, 22, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-328, 11, -710), size = Vector3.new(24, 22, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-328, 12, -845), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-436, 12, -685), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-436, 12, -810), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-472, 13, -680), size = Vector3.new(24, 26, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-472, 13, -815), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-128, 12, -710), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-272, 12, -720), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(261, 11, -710), size = Vector3.new(24, 22, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(261, 12, -835), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(297, 12, -715), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(189, 12, -710), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(189, 12, -835), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(153, 12, -705), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(153, 13, -830), size = Vector3.new(24, 26, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(472, 13, -670), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(472, 13, -780), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(328, 11, -710), size = Vector3.new(24, 22, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(328, 13, -835), size = Vector3.new(24, 26, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(686, 12, -700), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(686, 13, -825), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(722, 13, -720), size = Vector3.new(24, 26, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(614, 11, -715), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(578, 11, -705), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(578, 11, -825), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(886, 12, -685), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(886, 11, -825), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(922, 12, -680), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(922, 13, -815), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(814, 13, -700), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(814, 12, -820), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(778, 12, -700), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(778, 12, -830), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1085, 10, -640), size = Vector3.new(22, 20, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1085, 10, -690), size = Vector3.new(22, 20, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1085, 10, -744), size = Vector3.new(22, 20, 44), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1085, 10, -799), size = Vector3.new(22, 20, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1119, 10, -645), size = Vector3.new(22, 20, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1119, 11, -706), size = Vector3.new(22, 22, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1119, 10, -765), size = Vector3.new(22, 20, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1015, 11, -645), size = Vector3.new(22, 22, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1015, 11, -704), size = Vector3.new(22, 22, 44), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1015, 10, -760), size = Vector3.new(22, 20, 44), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1015, 10, -818), size = Vector3.new(22, 20, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(981, 10, -642), size = Vector3.new(22, 20, 44), yaw = 0, use = "semis" },
			{ centre = Vector3.new(981, 11, -701), size = Vector3.new(22, 22, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(981, 10, -757), size = Vector3.new(22, 20, 46), yaw = 0, use = "semis" },
			{ centre = Vector3.new(981, 11, -817), size = Vector3.new(22, 22, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1285, 11, -640), size = Vector3.new(22, 22, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1215, 10, -640), size = Vector3.new(22, 20, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1215, 10, -695), size = Vector3.new(22, 20, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1215, 10, -754), size = Vector3.new(22, 20, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1181, 11, -640), size = Vector3.new(22, 22, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1181, 11, -699), size = Vector3.new(22, 22, 50), yaw = 0, use = "semis" },
			{ centre = Vector3.new(1181, 11, -754), size = Vector3.new(22, 22, 40), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1230, 13, -564), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1100, 12, -564), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1020, 12, -564), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-920, 13, -564), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-780, 13, -564), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-645, 13, -564), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-550, 12, -564), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-470, 13, -564), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-200, 12, -564), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(380, 12, -564), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(875, 13, -564), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1250, 13, -528), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1120, 12, -528), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-990, 13, -528), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-870, 13, -528), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-730, 12, -528), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-580, 12, -528), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(39, 13, -685), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(39, 11, -825), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(75, 12, -670), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(75, 12, -780), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-39, 12, -705), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-39, 12, -835), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-75, 11, -710), size = Vector3.new(24, 22, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-75, 12, -840), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-130, 12, -884), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(80, 12, -884), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(500, 12, -884), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(510, 12, -848), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-610, 12, -956), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-495, 11, -956), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-380, 13, -956), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-265, 11, -956), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-140, 13, -956), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(85, 13, -956), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(205, 11, -956), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(340, 12, -956), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(470, 11, -956), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(590, 12, -956), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-220, 13, -992), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-100, 13, -992), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(85, 11, -992), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(210, 12, -992), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
		},
	},
	{
		name = "Riverside",
		kind = "riverside",
		blocks = {
			{ centre = Vector3.new(560, 15, 130), size = Vector3.new(120, 30, 40), yaw = 0, use = "pub and cafes" },
			{ centre = Vector3.new(720, 15, 140), size = Vector3.new(120, 30, 40), yaw = 0, use = "flats" },
			{ centre = Vector3.new(620, 14, 230), size = Vector3.new(140, 28, 40), yaw = 0, use = "waterfront flats" },
			{ centre = Vector3.new(900, 0.5, 240), size = Vector3.new(140, 1, 80), yaw = 0, use = "marina" },
			{ centre = Vector3.new(828, 20, 103), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(830, 19, 156), size = Vector3.new(70, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(547, 18, -4), size = Vector3.new(70, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(626, 18, 0), size = Vector3.new(60, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(710, 18, 3), size = Vector3.new(80, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(794, 19, 8), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(868, 19, 12), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(585, 19, -56), size = Vector3.new(80, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(669, 19, -51), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(748, 19, -47), size = Vector3.new(70, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(832, 18, -43), size = Vector3.new(70, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(947, 18, 103), size = Vector3.new(70, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1026, 20, 83), size = Vector3.new(60, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1100, 18, 65), size = Vector3.new(60, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1185, 20, 47), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1268, 20, 25), size = Vector3.new(60, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(958, 18, 171), size = Vector3.new(60, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1032, 19, 154), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1106, 19, 136), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(938, 20, -2), size = Vector3.new(60, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1012, 19, -20), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(1091, 19, -40), size = Vector3.new(70, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(916, 20, -70), size = Vector3.new(70, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-400, 20, 302), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-146, 18, 302), size = Vector3.new(60, 36, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-62, 19, 302), size = Vector3.new(80, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(27, 19, 302), size = Vector3.new(70, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(156, 20, 302), size = Vector3.new(60, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(240, 20, 302), size = Vector3.new(80, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(334, 19, 302), size = Vector3.new(80, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(423, 20, 302), size = Vector3.new(70, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-410, 19, 218), size = Vector3.new(60, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-331, 20, 218), size = Vector3.new(70, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-252, 20, 218), size = Vector3.new(60, 40, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(257, 19, 218), size = Vector3.new(70, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(346, 19, 218), size = Vector3.new(80, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(435, 19, 218), size = Vector3.new(70, 38, 36), yaw = 0, use = "flats" },
			{ centre = Vector3.new(-385, 12, 176), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(275, 11, 176), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(400, 12, 176), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(172, 12, 596), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(297, 12, 596), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(427, 12, 596), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(567, 12, 596), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(707, 12, 596), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(802, 12, 596), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(902, 12, 596), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1002, 12, 596), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(1102, 11, 596), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(157, 12, 632), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(272, 12, 632), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(397, 11, 632), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(537, 12, 632), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(682, 13, 632), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(812, 12, 632), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(927, 11, 632), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1042, 12, 632), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1167, 11, 632), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(152, 12, 524), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(247, 12, 524), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(387, 11, 524), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(482, 12, 524), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(562, 12, 524), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(687, 13, 524), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(817, 11, 524), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(902, 12, 524), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(987, 12, 524), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1107, 13, 524), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1237, 12, 524), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(447, 13, 488), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(562, 12, 488), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(682, 11, 488), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(812, 11, 488), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(947, 13, 488), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1072, 11, 488), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1202, 13, 488), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-495, 12, 656), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-375, 12, 656), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-250, 12, 656), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-125, 12, 656), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-485, 13, 692), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-365, 13, 692), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-240, 12, 692), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-105, 12, 692), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-485, 12, 584), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-345, 12, 584), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-210, 13, 584), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-90, 11, 584), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-475, 12, 548), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-345, 12, 548), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-230, 11, 548), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-115, 12, 548), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(0, 12, 548), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(99, 13, 700), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(172, 11, 711), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1153, 12, 685), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1023, 12, 701), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(873, 12, 722), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(723, 12, 744), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(951, 12, 663), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(831, 12, 680), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(700, 12, 697), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1167, 13, 785), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1056, 12, 793), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(882, 12, 825), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(1214, 13, 825), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(590, 11, 758), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(480, 12, 758), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(350, 11, 758), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(560, 12, 722), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(435, 12, 722), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(310, 11, 722), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(440, 12, 842), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(315, 13, 842), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(200, 13, 842), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(80, 12, 842), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(590, 12, 878), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(440, 12, 878), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, 878), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(155, 13, 878), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-90, 11, 758), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-205, 12, 758), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-340, 12, 758), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-480, 12, 758), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-70, 12, 722), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-200, 12, 722), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-315, 13, 722), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-435, 11, 722), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-60, 12, 842), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-150, 13, 842), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-270, 11, 842), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-545, 13, 842), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-80, 13, 878), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-205, 12, 878), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-330, 12, 878), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-555, 12, 878), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(484, 11, 950), size = Vector3.new(24, 22, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(484, 12, 1060), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(484, 12, 1285), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(484, 12, 1380), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(484, 11, 1475), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(448, 12, 950), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(448, 12, 1080), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(448, 12, 1270), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(448, 11, 1385), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(448, 13, 1500), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(556, 12, 965), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(556, 12, 1110), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(556, 11, 1240), size = Vector3.new(24, 22, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(556, 12, 1370), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(592, 12, 970), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(592, 11, 1105), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(592, 12, 1225), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(592, 13, 1360), size = Vector3.new(24, 26, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(592, 13, 1505), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(303, 11, 1235), size = Vector3.new(46, 22, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(361, 10, 1235), size = Vector3.new(50, 20, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(312, 10, 1269), size = Vector3.new(44, 20, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(369, 10, 1269), size = Vector3.new(50, 20, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(305, 11, 1165), size = Vector3.new(50, 22, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(365, 10, 1165), size = Vector3.new(46, 20, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(305, 10, 1131), size = Vector3.new(50, 20, 22), yaw = 0, use = "semis" },
			{ centre = Vector3.new(369, 11, 1131), size = Vector3.new(50, 22, 22), yaw = 0, use = "semis" },
		},
	},
	{
		name = "Riverside Park",
		kind = "park",
		blocks = {
			{ centre = Vector3.new(1150, 0.5, -320), size = Vector3.new(360, 1, 480), yaw = 0, use = "park lawn" },
			{ centre = Vector3.new(1150, 5, -300), size = Vector3.new(20, 10, 20), yaw = 0, use = "bandstand" },
			{ centre = Vector3.new(1050, 7, -120), size = Vector3.new(40, 14, 30), yaw = 0, use = "park cafe" },
		},
	},
	{
		name = "Station",
		kind = "station",
		blocks = {
			{ centre = Vector3.new(-1000, 0.5, -350), size = Vector3.new(120, 1, 60), yaw = 0, use = "station car park" },
			{ centre = Vector3.new(-1226, 12, -204), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1131, 12, -204), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-991, 13, -204), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-866, 12, -204), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-746, 12, -204), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1181, 12, -168), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1051, 12, -168), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-911, 13, -168), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-776, 12, -168), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1226, 13, -276), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1111, 12, -276), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-981, 11, -276), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-836, 11, -276), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1231, 12, -312), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1132, 12, -51), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-987, 12, -44), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-862, 13, -39), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-732, 13, -31), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-597, 13, -25), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1119, 12, -10), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-994, 13, -4), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-874, 11, 2), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-744, 11, 9), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-619, 12, 15), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1128, 12, -136), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-988, 12, -129), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-868, 13, -122), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-758, 13, -117), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-648, 12, -111), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1065, 13, 186), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-945, 13, 186), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-810, 11, 186), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-680, 12, 186), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-560, 12, 186), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1050, 12, 222), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-905, 12, 222), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-780, 12, 222), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-655, 12, 222), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1070, 12, 114), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-920, 12, 114), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-775, 13, 114), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-640, 13, 114), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1090, 11, 78), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-950, 13, 78), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-825, 11, 78), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-695, 12, 78), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-570, 12, 78), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-504, 18, -166), size = Vector3.new(30, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(-542, 16, -210), size = Vector3.new(40, 32, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-588, 18, -256), size = Vector3.new(40, 36, 30), yaw = 0, use = "shops with flats" },
			{ centre = Vector3.new(-632, 17, -294), size = Vector3.new(30, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-668, 17, -330), size = Vector3.new(30, 34, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-614, 17, -146), size = Vector3.new(40, 34, 30), yaw = 0, use = "shops" },
			{ centre = Vector3.new(-652, 18, -190), size = Vector3.new(30, 36, 30), yaw = 0, use = "shops with flats" },
		},
	},
	{
		name = "Industrial Estate",
		kind = "industrial",
		blocks = {
			{ centre = Vector3.new(-2150, 15, -250), size = Vector3.new(160, 30, 100), yaw = 0, use = "warehouse" },
			{ centre = Vector3.new(-1900, 15, -250), size = Vector3.new(160, 30, 100), yaw = 0, use = "warehouse" },
			{ centre = Vector3.new(-1650, 15, -250), size = Vector3.new(160, 30, 100), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2150, 13, 20), size = Vector3.new(160, 26, 90), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1900, 13, 20), size = Vector3.new(160, 26, 90), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1650, 13, 20), size = Vector3.new(160, 26, 90), yaw = 0, use = "builders yard" },
			{ centre = Vector3.new(-1350, 10, -153), size = Vector3.new(80, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1546, 10, -155), size = Vector3.new(60, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1652, 10, -156), size = Vector3.new(60, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1738, 12, -157), size = Vector3.new(80, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1834, 10, -158), size = Vector3.new(80, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1920, 10, -159), size = Vector3.new(60, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2006, 10, -160), size = Vector3.new(80, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2092, 12, -160), size = Vector3.new(60, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2178, 12, -161), size = Vector3.new(80, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2274, 10, -162), size = Vector3.new(80, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1350, 12, -48), size = Vector3.new(100, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1766, 10, -53), size = Vector3.new(60, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2022, 12, -55), size = Vector3.new(60, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2118, 10, -56), size = Vector3.new(100, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2224, 12, -57), size = Vector3.new(80, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1411, 14, -287), size = Vector3.new(90, 28, 120), yaw = 0, use = "warehouse" },
			{ centre = Vector3.new(-1411, 13, 53), size = Vector3.new(90, 26, 140), yaw = 0, use = "warehouse" },
			{ centre = Vector3.new(-1681, 10, -446), size = Vector3.new(80, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1777, 10, -445), size = Vector3.new(80, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1873, 10, -443), size = Vector3.new(80, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1979, 10, -441), size = Vector3.new(100, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2075, 12, -439), size = Vector3.new(60, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2171, 12, -437), size = Vector3.new(100, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2287, 12, -435), size = Vector3.new(100, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1529, 10, -344), size = Vector3.new(60, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1625, 12, -342), size = Vector3.new(100, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1741, 12, -340), size = Vector3.new(100, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-1837, 12, -338), size = Vector3.new(60, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1933, 10, -336), size = Vector3.new(100, 20, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2029, 12, -334), size = Vector3.new(60, 24, 50), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2125, 12, -332), size = Vector3.new(100, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2231, 10, -331), size = Vector3.new(60, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2327, 12, -328), size = Vector3.new(100, 24, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-2320, 13, 60), size = Vector3.new(120, 26, 90), yaw = 0, use = "workshop" },
			{ centre = Vector3.new(-2360, 10, -70), size = Vector3.new(60, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1580, 10, -535), size = Vector3.new(100, 20, 50), yaw = 0, use = "trade counter" },
			{ centre = Vector3.new(-1474, 10, -535), size = Vector3.new(80, 20, 50), yaw = 0, use = "trade counter" },
		},
	},
	{
		name = "Westdale",
		kind = "estate",
		blocks = {
			{ centre = Vector3.new(-900, 11, 520), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-900, 11, 600), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1000, 11, 920), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-830, 11, 920), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1000, 11, 980), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-830, 11, 980), size = Vector3.new(120, 22, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1000, 11, 1220), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-830, 11, 1220), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1000, 11, 1280), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-830, 11, 1280), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1350, 11, 1080), size = Vector3.new(120, 22, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1350, 11, 1270), size = Vector3.new(120, 22, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1550, 11, 1150), size = Vector3.new(120, 22, 24), yaw = 0, use = "semis" },
			{ centre = Vector3.new(-1031, 12, 596), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-761, 12, 596), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-656, 12, 596), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1011, 11, 632), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-866, 12, 632), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-731, 12, 632), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1036, 13, 524), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-746, 13, 524), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1056, 13, 488), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-936, 12, 488), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-806, 12, 488), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-686, 12, 488), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-700, 11, 726), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-834, 11, 698), size = Vector3.new(130, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-970, 12, 672), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-689, 12, 671), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-726, 12, 830), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-995, 13, 775), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-726, 13, 885), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1007, 12, 831), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1165, 12, 640), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1198, 12, 470), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1212, 13, 669), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1246, 13, 489), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-730, 12, 986), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1005, 12, 1022), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-835, 12, 1022), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1005, 12, 878), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1035, 13, 1136), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-835, 13, 1136), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1040, 12, 1172), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-820, 12, 1172), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1005, 12, 1064), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-830, 11, 1064), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1175, 12, 1286), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1180, 11, 1322), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1070, 12, 1322), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-820, 13, 1322), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1170, 11, 1214), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1180, 13, 1178), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-879, 12, 797), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1630, 13, 1436), size = Vector3.new(140, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1485, 12, 1436), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1360, 12, 1436), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1250, 13, 1436), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1170, 12, 1436), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1080, 11, 1436), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-955, 13, 1436), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-825, 12, 1436), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1635, 12, 1472), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1500, 12, 1472), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1370, 11, 1472), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1240, 13, 1472), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1115, 12, 1472), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-985, 12, 1472), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-850, 11, 1472), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-715, 12, 1472), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1645, 12, 1364), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1520, 13, 1364), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1400, 13, 1364), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1210, 12, 1364), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1115, 13, 1364), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-990, 12, 1364), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-830, 12, 1364), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-710, 13, 1364), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1640, 12, 1328), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1505, 13, 1328), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1360, 12, 1328), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-506, 12, 950), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-506, 11, 1075), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-506, 12, 1200), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-506, 12, 1325), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-506, 12, 1470), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-542, 13, 955), size = Vector3.new(24, 26, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-542, 12, 1085), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-542, 12, 1210), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-542, 11, 1325), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-542, 11, 1455), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-434, 13, 880), size = Vector3.new(24, 26, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-434, 13, 995), size = Vector3.new(24, 26, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-434, 12, 1125), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-434, 12, 1265), size = Vector3.new(24, 24, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-434, 12, 1390), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-434, 12, 1500), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-398, 12, 970), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-398, 12, 1110), size = Vector3.new(24, 24, 120), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-398, 11, 1250), size = Vector3.new(24, 22, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-398, 11, 1400), size = Vector3.new(24, 22, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1730, 12, 596), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1530, 12, 596), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1400, 12, 596), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1260, 12, 596), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1750, 12, 632), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1510, 12, 632), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1375, 11, 632), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1730, 12, 524), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1515, 12, 524), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1380, 11, 524), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1750, 13, 488), size = Vector3.new(100, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1525, 12, 488), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1395, 13, 488), size = Vector3.new(130, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1750, 11, 836), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1660, 12, 836), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1525, 13, 836), size = Vector3.new(110, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1440, 12, 836), size = Vector3.new(40, 24, 24), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1345, 12, 836), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1210, 12, 836), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1745, 11, 872), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1520, 11, 872), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1395, 12, 872), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1270, 13, 872), size = Vector3.new(120, 26, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1750, 11, 764), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1525, 11, 764), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1410, 12, 764), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1295, 12, 764), size = Vector3.new(110, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1180, 11, 764), size = Vector3.new(100, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1740, 12, 728), size = Vector3.new(120, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1510, 12, 728), size = Vector3.new(140, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1370, 11, 728), size = Vector3.new(120, 22, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1636, 12, 430), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1636, 12, 520), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" },
			{ centre = Vector3.new(-1636, 13, 645), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1636, 13, 925), size = Vector3.new(24, 26, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1636, 12, 1055), size = Vector3.new(24, 24, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1672, 11, 915), size = Vector3.new(24, 22, 110), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1672, 11, 1045), size = Vector3.new(24, 22, 130), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1564, 12, 940), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1564, 12, 1050), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1528, 12, 960), size = Vector3.new(24, 24, 140), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(-1250, 15, 1000), size = Vector3.new(140, 30, 90), yaw = 0, use = "school" },
		},
	},
	{
		name = "Community Sports Centre",
		kind = "sports",
		blocks = {
			{ centre = Vector3.new(220, 0.5, 1000), size = Vector3.new(240, 1, 160), yaw = 0, use = "grass pitch" },
			{ centre = Vector3.new(-220, 0.5, 1050), size = Vector3.new(160, 1, 240), yaw = 0, use = "grass pitch" },
			{ centre = Vector3.new(-220, 0.5, 1400), size = Vector3.new(160, 1, 200), yaw = 0, use = "3G pitch" },
			{ centre = Vector3.new(220, 12, 1300), size = Vector3.new(120, 24, 80), yaw = 0, use = "sports hall" },
			{ centre = Vector3.new(-60, 0.5, 1000), size = Vector3.new(60, 1, 120), yaw = 0, use = "3G pitch" },
			{ centre = Vector3.new(220, 0.5, 1450), size = Vector3.new(120, 1, 80), yaw = 0, use = "grass pitch" },
		},
	},
} :: { District }

TownLayout.LANDMARKS = {
	{ name = "Church Spire", position = Vector3.new(-220, 0, -240), height = 130 },
	{ name = "Lune Viaduct", position = Vector3.new(-550, 0, 400), height = 45 },
	{ name = "Lune Bridge", position = Vector3.new(100, 0, 420), height = 14 },
} :: { Landmark }

TownLayout.BUS_STOPS = {
	{ name = "Town Centre", position = Vector3.new(90, 0, -20), yaw = 0 },
	-- X71: on Station Road's station-side pavement west of the taxi lay-by, facing the road
	-- (it stood on the forecourt over a planter and bench once the road moved, X51)
	{ name = "Station", position = Vector3.new(-915, 0, -355), yaw = 180 },
	{ name = "Riverside", position = Vector3.new(700, 0, 80), yaw = 0 },
	{ name = "Riverside Park", position = Vector3.new(1180, 0, -40), yaw = 0 },
	{ name = "Industrial Estate", position = Vector3.new(-1600, 0, -130), yaw = 0 },
	{ name = "Westdale", position = Vector3.new(-1075, 0, 964), yaw = 0 },
	{ name = "Sports Centre", position = Vector3.new(40, 0, 1180), yaw = 0 },
	{ name = "Plot 1", position = Vector3.new(992, 0, 840), yaw = 90 },
	{ name = "Plot 2", position = Vector3.new(1490, 0, -1142), yaw = 180 },
	{ name = "Plot 3", position = Vector3.new(1540, 0, 522), yaw = 0 },
	{ name = "Plot 4", position = Vector3.new(-1490, 0, -1302), yaw = 180 },
} :: { BusStop }

-- Helpers --------------------------------------------------------------------

-- Distance from p to the segment a-b, ignoring Y.
function TownLayout.segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local apx, apz = p.X - a.X, p.Z - a.Z
	local lenSq = abx * abx + abz * abz
	local t = 0
	if lenSq > 0 then
		t = math.clamp((apx * abx + apz * abz) / lenSq, 0, 1)
	end
	local dx, dz = apx - abx * t, apz - abz * t
	return math.sqrt(dx * dx + dz * dz)
end

-- Distance from p to the nearest point of a polyline, ignoring Y.
function TownLayout.distanceToPolyline(p: Vector3, points: { Vector3 }): number
	if #points == 1 then
		return TownLayout.segmentDistance(p, points[1], points[1])
	end
	local best = math.huge
	for i = 1, #points - 1 do
		best = math.min(best, TownLayout.segmentDistance(p, points[i], points[i + 1]))
	end
	return best
end

-- Signed distance from p to the River Lune centreline, using the nearest
-- segment. Positive = right bank looking downstream (the south bank), negative
-- = left / north bank.
function TownLayout.riverSide(p: Vector3): number
	local points = TownLayout.RIVER.points
	local bestDist, bestCross = math.huge, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local d = TownLayout.segmentDistance(p, a, b)
		if d < bestDist then
			bestDist = d
			bestCross = (b.X - a.X) * (p.Z - a.Z) - (b.Z - a.Z) * (p.X - a.X)
		end
	end
	return if bestCross < 0 then -bestDist else bestDist
end

function TownLayout.plotCFrame(i: number): CFrame
	local plot = TownLayout.PLOTS[i]
	assert(plot, "no plot " .. tostring(i))
	return CFrame.new(plot.centre) * CFrame.Angles(0, math.rad(plot.yaw), 0)
end

-- World-space corners of plot i at ground level, in order around the square.
function TownLayout.plotCorners(i: number): { Vector3 }
	local cf = TownLayout.plotCFrame(i)
	local h = TownLayout.PLOT_SIZE / 2
	return {
		cf * Vector3.new(-h, 0, -h),
		cf * Vector3.new(h, 0, -h),
		cf * Vector3.new(h, 0, h),
		cf * Vector3.new(-h, 0, h),
	}
end

-- True if p (any Y) lies inside plot i's square, edges included.
function TownLayout.pointInPlot(p: Vector3, i: number): boolean
	local cf = TownLayout.plotCFrame(i)
	local localP = cf:PointToObjectSpace(Vector3.new(p.X, cf.Position.Y, p.Z))
	local h = TownLayout.PLOT_SIZE / 2
	return math.abs(localP.X) <= h and math.abs(localP.Z) <= h
end

-- World direction the plot's entrance side (local -X) faces.
function TownLayout.plotEntranceDirection(i: number): Vector3
	return TownLayout.plotCFrame(i):VectorToWorldSpace(Vector3.new(-1, 0, 0))
end

return TownLayout
