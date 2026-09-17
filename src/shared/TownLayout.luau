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
--               and a full carriageway width (pavements come on top, 8 each side)
--   RIVER       the River Lune centreline, flowing west -> east, with its width
--   BRIDGES     from/to are the deck ends (both on dry land); kind "road" | "rail" | "foot"
--   RAIL        track centreline plus the station building box
--   DISTRICTS   greybox volumes: centre.Y = size.Y / 2 so each box sits on the ground
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

TownLayout.SQUARE = { name = "Market Square", centre = Vector3.new(0, 0, 0), radius = 60 }

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
} :: { Roundabout }

TownLayout.PLOTS = {
	{ -- south-east, entrance faces north
		index = 1,
		name = "Plot 1",
		centre = Vector3.new(1050, 0, 1250),
		yaw = 270,
		busStop = Vector3.new(1090, 0, 835),
	},
	{ -- north-east, entrance faces west
		index = 2,
		name = "Plot 2",
		centre = Vector3.new(1900, 0, -1200),
		yaw = 0,
		busStop = Vector3.new(1470, 0, -1160),
	},
	{ -- east, entrance faces west
		index = 3,
		name = "Plot 3",
		centre = Vector3.new(1950, 0, 420),
		yaw = 0,
		busStop = Vector3.new(1520, 0, 460),
	},
	{ -- north-west, entrance faces east
		index = 4,
		name = "Plot 4",
		centre = Vector3.new(-1900, 0, -1200),
		yaw = 180,
		busStop = Vector3.new(-1470, 0, -1160),
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
			Vector3.new(-460, 0, -60), Vector3.new(-700, 0, -300), Vector3.new(-800, 0, -340),
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
			Vector3.new(0, 0, -200), Vector3.new(450, 0, -200),
		},
	},
	{
		name = "Weaver Street",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(0, 0, -330), Vector3.new(450, 0, -330),
		},
	},
	{
		name = "Elm Grove",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-350, 0, -440), Vector3.new(450, 0, -440),
		},
	},
	{
		name = "Northfields Avenue",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-350, 0, -600), Vector3.new(900, 0, -600),
		},
	},
	{
		name = "Hayfield Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(400, 0, -600), Vector3.new(400, 0, -900),
		},
	},
	{
		name = "Rowan Close",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-200, 0, -600), Vector3.new(-200, 0, -900),
		},
	},
	{
		name = "Westdale Avenue",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1100, 0, 950), Vector3.new(-720, 0, 950),
		},
	},
	{
		name = "Westdale Crescent",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(-1100, 0, 1250), Vector3.new(-720, 0, 1250),
		},
	},
	{
		name = "Sports Centre Road",
		kind = "residential",
		width = 20,
		points = {
			Vector3.new(0, 0, 800), Vector3.new(0, 0, 1200), Vector3.new(450, 0, 1200),
		},
	},
	{
		name = "Plot 1 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(1050, 0, 750), Vector3.new(1050, 0, 850),
		},
	},
	{
		name = "Plot 2 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(1300, 0, -800), Vector3.new(1320, 0, -1200), Vector3.new(1500, 0, -1200),
		},
	},
	{
		name = "Plot 3 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(1400, 0, 400), Vector3.new(1550, 0, 420),
		},
	},
	{
		name = "Plot 4 Lane",
		kind = "lane",
		width = 20,
		points = {
			Vector3.new(-1300, 0, -800), Vector3.new(-1320, 0, -1200), Vector3.new(-1500, 0, -1200),
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
		},
	},
	{
		name = "Mill Street Terraces",
		kind = "terraced",
		blocks = {
			{ centre = Vector3.new(100, 12, -172), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -172), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(100, 12, -228), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -228), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(100, 12, -302), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -302), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(100, 12, -358), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
			{ centre = Vector3.new(300, 12, -358), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" },
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
	{ name = "Station", position = Vector3.new(-740, 0, -355), yaw = 0 },
	{ name = "Riverside", position = Vector3.new(700, 0, 80), yaw = 0 },
	{ name = "Riverside Park", position = Vector3.new(1180, 0, -40), yaw = 0 },
	{ name = "Industrial Estate", position = Vector3.new(-1600, 0, -130), yaw = 0 },
	{ name = "Westdale", position = Vector3.new(-1060, 0, 930), yaw = 0 },
	{ name = "Sports Centre", position = Vector3.new(40, 0, 1180), yaw = 0 },
	{ name = "Plot 1", position = Vector3.new(1090, 0, 835), yaw = 0 },
	{ name = "Plot 2", position = Vector3.new(1470, 0, -1160), yaw = 90 },
	{ name = "Plot 3", position = Vector3.new(1520, 0, 460), yaw = 90 },
	{ name = "Plot 4", position = Vector3.new(-1470, 0, -1160), yaw = 270 },
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
