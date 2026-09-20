--!strict
-- Rivermere v3 master plan as pure data (no Instances). The plan and the
-- reasoning behind every number live in docs/TOWN_PLAN.md; keep the two in step.
--
-- THIS FILE IS THE SOURCE OF TRUTH for the town. tools/town_plan_v3.py is only
-- the drawing tool (docs/town_map_v3.png) and the parity reference: ROADS, PLOTS
-- and ROUNDABOUTS are written from it by tools/town_v3_emit.py (comments inside
-- those three tables are not kept), and tools/town_v3_parity.py checks the two
-- agree. Everything built along a street is NOT here: it is generated from
-- ROADS by src/shared/TownFrontage.luau.
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
--   ROADS       polylines with a kind ("ring" | "main" | "residential" | "lane" | "alley")
--               and a full carriageway width (pavements come on top, 8 each side).
--               Every segment is axis-aligned or 45 degrees so the road kit tiles.
--               front  = which sides TownFrontage builds along ("left" is left of
--                        the direction of travel, first point to last)
--               use    = the TownFrontage.TYPES key built there, or
--               useAt  = the name of a TownFrontage.RULES rule that picks the use
--                        (and district) from the position along the street
--               head   = the last point is a cul-de-sac turning head, HEAD_RADIUS
--               "Plot N Lane" starts on the ring road / a roundabout and ends at
--               plotCFrame(N) * PLOT_LANE_END, on the vehicle gate line
--               (PlotGrounds: gate at plot-local x = -380, z 60..100).
--   RIVER       the River Lune centreline, flowing west -> east, with its width
--   BRIDGES     from/to are the deck ends (both on dry land); kind "road" | "rail" | "foot"
--   RAIL        track centreline plus the station building box
--   DISTRICTS   the hand-placed SPECIAL blocks only (church, town hall, schools,
--               pubs, parks, marina, sports centre...): centre.Y = size.Y / 2 so
--               each box sits on the ground. A district with no specials keeps an
--               empty entry so the list of district names stays complete. No two
--               boxes overlap (a building may stand on a flat ground piece, e.g.
--               the bandstand on the park lawn), and every box keeps clear of
--               carriageway + pavements, the river (width/2 + 20, except the
--               marina basin), the rail, roundabouts, bus stops, landmarks and
--               plots (+20). Housing, shops, flats and industry are TownFrontage lots.
--   SQUARE      the round market square
--   ROUNDABOUTS ring-road junctions (radius = central island + circulating lane)
--   LANDMARKS   position at ground level plus the top height in studs
--   BUS_STOPS   fast-travel stops; yaw is the direction the shelter faces
--
-- Helpers are all XZ-plane: segmentDistance, distanceToPolyline, riverSide,
-- plotCFrame, plotCorners, pointInPlot, plotEntranceDirection.

local TownLayout = {}

export type Plot = { index: number, name: string, centre: Vector3, yaw: number, busStop: Vector3 }
export type RoadKind = "ring" | "main" | "residential" | "lane" | "alley"
export type Front = "both" | "left" | "right" | "none"
export type Road = {
	name: string,
	kind: RoadKind,
	width: number,
	points: { Vector3 },
	front: Front, -- left of the direction of travel
	use: string?, -- a TownFrontage.TYPES key; nil when useAt decides (or front is "none")
	useAt: string?, -- name of a rule in TownFrontage.RULES ("centre", "industrial", ...)
	district: string?,
	head: boolean?, -- last point is a cul-de-sac turning head
}
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
TownLayout.HEAD_RADIUS = 34 -- cul-de-sac turning head (kit CulDeSac is 96 x 69 at town scale)
TownLayout.PLOT_LANE_END = Vector3.new(-381, 0, 80) -- plot-local, on the vehicle gate line (1 outside the plot); PlotGrounds' access road starts here

TownLayout.SQUARE = { name = "Market Square", centre = Vector3.new(0, 0, 0), radius = 60 }

-- X51: the station taxi rank / drop-off lay-by, cut into Station Road's
-- station-side pavement between the forecourt and the carriageway. TownBuilder
-- lays no pavement over it; StationDresser surfaces it and parks the taxis.
TownLayout.STATION_LAYBY = { from = Vector3.new(-890, 0, -354), to = Vector3.new(-804, 0, -354), width = 8 }

TownLayout.ROUNDABOUTS = {
	{ name = "Northfields Roundabout", centre = Vector3.new(0, 0, -1080), radius = 40 },
	{ name = "Plot 4 Roundabout", centre = Vector3.new(-1350, 0, -750), radius = 40 },
	{ name = "Plot 2 Roundabout", centre = Vector3.new(1400, 0, -600), radius = 40 },
	{ name = "Lunebank Roundabout", centre = Vector3.new(1400, 0, 300), radius = 40 },
	{ name = "Hollingford Roundabout", centre = Vector3.new(1250, 0, 600), radius = 40 },
	{ name = "Sports Centre Roundabout", centre = Vector3.new(0, 0, 800), radius = 40 },
	{ name = "Westdale Roundabout", centre = Vector3.new(-1150, 0, 560), radius = 40 },
	{ name = "High Street Roundabout", centre = Vector3.new(-1255, 0, -105), radius = 40 },
	{ name = "Mapleford Roundabout", centre = Vector3.new(-1350, 0, -400), radius = 40 },
	{ name = "Foundry Way Roundabout", centre = Vector3.new(-1480, 0, -105), radius = 16 },
} :: { Roundabout }

TownLayout.PLOTS = {
	{ -- south-east, entrance faces north
		index = 1,
		name = "Plot 1",
		centre = Vector3.new(1050, 0, 1250),
		yaw = 270,
		busStop = Vector3.new(992, 0, 840),
	},
	{ -- north-east (Millbrook), entrance faces west
		index = 2,
		name = "Plot 2",
		centre = Vector3.new(1830, 0, -1160),
		yaw = 0,
		busStop = Vector3.new(1420, 0, -1058),
	},
	{ -- south-west (Westdale), entrance faces north
		index = 3,
		name = "Plot 3",
		centre = Vector3.new(-1780, 0, 1020),
		yaw = 270,
		busStop = Vector3.new(-1838, 0, 610),
	},
	{ -- north-west (Mapleford), entrance faces east
		index = 4,
		name = "Plot 4",
		centre = Vector3.new(-1790, 0, -1130),
		yaw = 180,
		busStop = Vector3.new(-1380, 0, -1232),
	},
} :: { Plot }

TownLayout.ROADS = {
	{
		name = "Ring Road", kind = "ring", width = 32, front = "none",
		points = {
			Vector3.new(-1100, 0, -1000), Vector3.new(-500, 0, -1000), Vector3.new(-420, 0, -1080),
			Vector3.new(420, 0, -1080), Vector3.new(500, 0, -1000), Vector3.new(1000, 0, -1000),
			Vector3.new(1400, 0, -600), Vector3.new(1400, 0, 400), Vector3.new(1250, 0, 550),
			Vector3.new(1250, 0, 650), Vector3.new(1100, 0, 800), Vector3.new(-1000, 0, 800),
			Vector3.new(-1150, 0, 650), Vector3.new(-1150, 0, 0), Vector3.new(-1350, 0, -200),
			Vector3.new(-1350, 0, -750), Vector3.new(-1100, 0, -1000),
		},
	},
	{
		name = "North Road", kind = "main", width = 26, front = "both", useAt = "north road",
		points = {
			Vector3.new(0, 0, -60), Vector3.new(0, 0, -1080),
		},
	},
	{
		name = "High Street", kind = "main", width = 26, front = "both", useAt = "high street",
		points = {
			Vector3.new(-60, 0, 0), Vector3.new(-400, 0, 0), Vector3.new(-505, 0, -105),
			Vector3.new(-1255, 0, -105),
		},
	},
	{
		name = "Station Road", kind = "main", width = 26, front = "both", use = "shops", district = "Station",
		points = {
			Vector3.new(-505, 0, -105), Vector3.new(-737, 0, -337), Vector3.new(-938, 0, -337),
		},
	},
	{
		name = "Riverside Road", kind = "main", width = 26, front = "both", useAt = "centre",
		points = {
			Vector3.new(60, 0, 0), Vector3.new(1340, 0, 0), Vector3.new(1400, 0, -60),
		},
	},
	{
		name = "Bridge Street", kind = "main", width = 26, front = "both", useAt = "bridge street",
		points = {
			Vector3.new(0, 0, 60), Vector3.new(0, 0, 200), Vector3.new(100, 0, 300),
			Vector3.new(100, 0, 700), Vector3.new(0, 0, 800),
		},
	},
	{
		name = "Mapleford Road", kind = "main", width = 26, front = "both", useAt = "industrial",
		points = {
			Vector3.new(-1350, 0, -400), Vector3.new(-2400, 0, -400),
		},
	},
	{
		name = "Estate Road", kind = "main", width = 26, front = "both", useAt = "industrial",
		points = {
			Vector3.new(-1255, 0, -105), Vector3.new(-2400, 0, -105),
		},
	},
	{
		name = "Greenbridge Road", kind = "main", width = 26, front = "right", use = "terraced row",
		district = "Westdale",
		points = {
			Vector3.new(-1150, 0, 560), Vector3.new(-2400, 0, 560),
		},
	},
	{
		name = "Hollingford Road", kind = "main", width = 26, front = "both", use = "terraced row",
		district = "Hollingford",
		points = {
			Vector3.new(1250, 0, 600), Vector3.new(1300, 0, 600), Vector3.new(1500, 0, 800),
			Vector3.new(2400, 0, 800),
		},
	},
	{
		name = "Guild Street", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(-330, 0, 130), Vector3.new(0, 0, 130),
		},
	},
	{
		name = "Quay Street", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(0, 0, 130), Vector3.new(480, 0, 130),
		},
	},
	{
		name = "Tanner Row", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(-330, 0, 0), Vector3.new(-330, 0, 260),
		},
	},
	{
		name = "Wharf Street", kind = "residential", width = 20, front = "none",
		points = {
			Vector3.new(250, 0, 0), Vector3.new(250, 0, 260),
		},
	},
	{
		name = "Marina Way", kind = "residential", width = 20, front = "both", useAt = "centre", head = true,
		points = {
			Vector3.new(760, 0, 0), Vector3.new(760, 0, 190),
		},
	},
	{
		name = "Chapel Street", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(-150, 0, 0), Vector3.new(-150, 0, -330),
		},
	},
	{
		name = "Fountain Street", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(250, 0, 0), Vector3.new(250, 0, -200),
		},
	},
	{
		name = "Dyers Lane", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(500, 0, 0), Vector3.new(500, 0, -200),
		},
	},
	{
		name = "Park Street", kind = "residential", width = 20, front = "both", useAt = "centre",
		points = {
			Vector3.new(750, 0, 0), Vector3.new(750, 0, -200),
		},
	},
	{
		name = "Spinner Street", kind = "residential", width = 20, front = "none", district = "Mill Street Terraces",
		points = {
			Vector3.new(450, 0, -200), Vector3.new(450, 0, -600),
		},
	},
	{
		name = "Park Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mill Street Terraces",
		points = {
			Vector3.new(900, 0, -200), Vector3.new(900, 0, -600),
		},
	},
	{
		name = "Loom Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mill Street Terraces",
		points = {
			Vector3.new(-200, 0, -330), Vector3.new(-200, 0, -600),
		},
	},
	{
		name = "Mill Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mill Street Terraces",
		points = {
			Vector3.new(0, 0, -200), Vector3.new(900, 0, -200),
		},
	},
	{
		name = "Weaver Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mill Street Terraces",
		points = {
			Vector3.new(-430, 0, -330), Vector3.new(900, 0, -330),
		},
	},
	{
		name = "Elm Grove", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mill Street Terraces",
		points = {
			Vector3.new(-500, 0, -440), Vector3.new(900, 0, -440),
		},
	},
	{
		name = "Northfields Avenue", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(-1350, 0, -600), Vector3.new(1400, 0, -600),
		},
	},
	{
		name = "Linden Way", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(-1000, 0, -920), Vector3.new(850, 0, -920),
		},
	},
	{
		name = "Elder Close", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Northfields", head = true,
		points = {
			Vector3.new(-1200, 0, -600), Vector3.new(-1200, 0, -815),
		},
	},
	{
		name = "Ash Close", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Northfields",
		points = {
			Vector3.new(-1000, 0, -600), Vector3.new(-1000, 0, -920),
		},
	},
	{
		name = "Birch Close", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Northfields",
		points = {
			Vector3.new(-800, 0, -600), Vector3.new(-800, 0, -920),
		},
	},
	{
		name = "Cherry Close", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(-600, 0, -600), Vector3.new(-600, 0, -920),
		},
	},
	{
		name = "Hazel Close", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(-400, 0, -600), Vector3.new(-400, 0, -920),
		},
	},
	{
		name = "Rowan Close", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(-200, 0, -600), Vector3.new(-200, 0, -920),
		},
	},
	{
		name = "Holly Close", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(225, 0, -600), Vector3.new(225, 0, -920),
		},
	},
	{
		name = "Hayfield Close", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(400, 0, -600), Vector3.new(400, 0, -920),
		},
	},
	{
		name = "Laurel Close", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Northfields",
		points = {
			Vector3.new(650, 0, -600), Vector3.new(650, 0, -920),
		},
	},
	{
		name = "Maple Close", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Northfields",
		points = {
			Vector3.new(850, 0, -600), Vector3.new(850, 0, -920),
		},
	},
	{
		name = "Oak Close", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Northfields", head = true,
		points = {
			Vector3.new(1050, 0, -600), Vector3.new(1050, 0, -865),
		},
	},
	{
		name = "Church Lane", kind = "residential", width = 20, front = "none", district = "Town Centre",
		points = {
			Vector3.new(-360, 0, 0), Vector3.new(-360, 0, -330),
		},
	},
	{
		name = "Cooper Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Station",
		points = {
			Vector3.new(-1350, 0, -240), Vector3.new(-640, 0, -240),
		},
	},
	{
		name = "Signal Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Station",
		points = {
			Vector3.new(-1150, 0, 25), Vector3.new(-560, 0, 25),
		},
	},
	{
		name = "Lock Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Station",
		points = {
			Vector3.new(-1150, 0, 150), Vector3.new(-540, 0, 150),
		},
	},
	{
		name = "Foundry Way", kind = "residential", width = 20, front = "both", useAt = "industrial",
		points = {
			Vector3.new(-1480, 0, -400), Vector3.new(-1480, 0, 110),
		},
	},
	{
		name = "Lune Street", kind = "residential", width = 20, front = "both", useAt = "centre", head = true,
		points = {
			Vector3.new(-440, 0, 260), Vector3.new(700, 0, 260),
		},
	},
	{
		name = "Platform Street", kind = "residential", width = 20, front = "none", district = "Station",
		points = {
			Vector3.new(-850, 0, -240), Vector3.new(-850, 0, 150),
		},
	},
	{
		name = "Goods Yard Lane", kind = "residential", width = 20, front = "none", district = "Station",
		points = {
			Vector3.new(-1000, 0, -105), Vector3.new(-1000, 0, -240),
		},
	},
	{
		name = "Forge Lane", kind = "residential", width = 20, front = "both", useAt = "industrial",
		points = {
			Vector3.new(-1800, 0, -400), Vector3.new(-1800, 0, 110),
		},
	},
	{
		name = "Furnace Lane", kind = "residential", width = 20, front = "both", useAt = "industrial",
		points = {
			Vector3.new(-2120, 0, -400), Vector3.new(-2120, 0, 110),
		},
	},
	{
		name = "Wharf Road", kind = "residential", width = 20, front = "none",
		points = {
			Vector3.new(-1480, 0, 110), Vector3.new(-2250, 0, 110),
		},
	},
	{
		name = "Meadow Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside", head = true,
		points = {
			Vector3.new(100, 0, 560), Vector3.new(1180, 0, 560),
		},
	},
	{
		name = "Tannery Row", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside", head = true,
		points = {
			Vector3.new(100, 0, 680), Vector3.new(1100, 0, 680),
		},
	},
	{
		name = "Viaduct Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside",
		points = {
			Vector3.new(-545, 0, 620), Vector3.new(100, 0, 620),
		},
	},
	{
		name = "Weir Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside",
		points = {
			Vector3.new(-1150, 0, 560), Vector3.new(-615, 0, 560),
		},
	},
	{
		name = "Fuller Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside",
		points = {
			Vector3.new(-1090, 0, 690), Vector3.new(-615, 0, 690),
		},
	},
	{
		name = "Sluice Lane", kind = "residential", width = 20, front = "none", district = "Riverside",
		points = {
			Vector3.new(-850, 0, 560), Vector3.new(-850, 0, 800),
		},
	},
	{
		name = "Dye Works Lane", kind = "residential", width = 20, front = "none", district = "Riverside",
		points = {
			Vector3.new(600, 0, 560), Vector3.new(600, 0, 800),
		},
	},
	{
		name = "Osier Lane", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside",
		points = {
			Vector3.new(-250, 0, 620), Vector3.new(-250, 0, 800),
		},
	},
	{
		name = "Sports Centre Road", kind = "residential", width = 20, front = "none", district = "Riverside",
		points = {
			Vector3.new(0, 0, 800), Vector3.new(0, 0, 1200), Vector3.new(590, 0, 1200),
		},
	},
	{
		name = "Cedar Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside", head = true,
		points = {
			Vector3.new(-470, 0, 800), Vector3.new(-470, 0, 1500),
		},
	},
	{
		name = "Paddock Road", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Riverside", head = true,
		points = {
			Vector3.new(400, 0, 800), Vector3.new(400, 0, 1500),
		},
	},
	{
		name = "Hollins Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Riverside", head = true,
		points = {
			Vector3.new(590, 0, 800), Vector3.new(590, 0, 1500),
		},
	},
	{
		name = "Plot 1 Lane", kind = "lane", width = 20, front = "none",
		points = {
			Vector3.new(970, 0, 800), Vector3.new(970, 0, 869),
		},
	},
	{
		name = "Moss Lane", kind = "residential", width = 20, front = "both", use = "semis", district = "Westdale",
		points = {
			Vector3.new(-2240, 0, 430), Vector3.new(-1250, 0, 430),
		},
	},
	{
		name = "Reed Road", kind = "residential", width = 20, front = "none", district = "Westdale",
		points = {
			Vector3.new(-1600, 0, 430), Vector3.new(-1600, 0, 560),
		},
	},
	{
		name = "Alder Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale",
		points = {
			Vector3.new(-1310, 0, 560), Vector3.new(-1310, 0, 1480),
		},
	},
	{
		name = "Tanner's Lane", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Westdale",
		points = {
			Vector3.new(-2240, 0, 560), Vector3.new(-2240, 0, 1480),
		},
	},
	{
		name = "Orchard Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale", head = true,
		points = {
			Vector3.new(-2240, 0, 1480), Vector3.new(-730, 0, 1480),
		},
	},
	{
		name = "Fern Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale",
		points = {
			Vector3.new(-1310, 0, 800), Vector3.new(-1000, 0, 800),
		},
	},
	{
		name = "Westdale Avenue", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale", head = true,
		points = {
			Vector3.new(-1310, 0, 950), Vector3.new(-730, 0, 950),
		},
	},
	{
		name = "Brook Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale", head = true,
		points = {
			Vector3.new(-1310, 0, 1100), Vector3.new(-730, 0, 1100),
		},
	},
	{
		name = "Westdale Crescent", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale", head = true,
		points = {
			Vector3.new(-1310, 0, 1250), Vector3.new(-730, 0, 1250),
		},
	},
	{
		name = "Coronation Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale", head = true,
		points = {
			Vector3.new(-1310, 0, 1365), Vector3.new(-730, 0, 1365),
		},
	},
	{
		name = "Westdale Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Westdale",
		points = {
			Vector3.new(-915, 0, 800), Vector3.new(-915, 0, 1480),
		},
	},
	{
		name = "Plot 3 Lane", kind = "lane", width = 20, front = "none",
		points = {
			Vector3.new(-1860, 0, 560), Vector3.new(-1860, 0, 639),
		},
	},
	{
		name = "Plot 4 Lane", kind = "lane", width = 20, front = "none",
		points = {
			Vector3.new(-1350, 0, -750), Vector3.new(-1350, 0, -1210), Vector3.new(-1409, 0, -1210),
		},
	},
	{
		name = "Mapleford Lane", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mapleford",
		points = {
			Vector3.new(-2250, 0, -670), Vector3.new(-1350, 0, -670),
		},
	},
	{
		name = "Drift Close", kind = "residential", width = 20, front = "both", use = "detached house",
		district = "Mapleford", head = true,
		points = {
			Vector3.new(-2250, 0, -670), Vector3.new(-2250, 0, -1060),
		},
	},
	{
		name = "Tollgate Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mapleford", head = true,
		points = {
			Vector3.new(-1350, 0, -1210), Vector3.new(-1350, 0, -1590), Vector3.new(-2120, 0, -1590),
		},
	},
	{
		name = "Drovers Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Mapleford", head = true,
		points = {
			Vector3.new(-1350, 0, -1210), Vector3.new(-760, 0, -1210),
		},
	},
	{
		name = "Pinfold Close", kind = "residential", width = 20, front = "both", use = "detached house",
		district = "Mapleford", head = true,
		points = {
			Vector3.new(-950, 0, -1210), Vector3.new(-950, 0, -1110),
		},
	},
	{
		name = "Smithy Close", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Mapleford", head = true,
		points = {
			Vector3.new(-1120, 0, -1210), Vector3.new(-1120, 0, -1460), Vector3.new(-880, 0, -1460),
		},
	},
	{
		name = "Plot 2 Lane", kind = "lane", width = 20, front = "none",
		points = {
			Vector3.new(1400, 0, -600), Vector3.new(1400, 0, -1080), Vector3.new(1449, 0, -1080),
		},
	},
	{
		name = "Millbrook Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Millbrook",
		points = {
			Vector3.new(1400, 0, -700), Vector3.new(2300, 0, -700),
		},
	},
	{
		name = "Lune View", kind = "residential", width = 20, front = "both", use = "detached house",
		district = "Millbrook", head = true,
		points = {
			Vector3.new(1560, 0, -570), Vector3.new(2250, 0, -570),
		},
	},
	{
		name = "Fell Lane", kind = "residential", width = 20, front = "both", use = "semis", district = "Millbrook",
		head = true,
		points = {
			Vector3.new(2300, 0, -700), Vector3.new(2300, 0, -1320),
		},
	},
	{
		name = "Quarry Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Millbrook", head = true,
		points = {
			Vector3.new(1400, 0, -1080), Vector3.new(900, 0, -1080), Vector3.new(780, 0, -1200),
		},
	},
	{
		name = "Kiln Close", kind = "residential", width = 20, front = "both", use = "semis", district = "Millbrook",
		head = true,
		points = {
			Vector3.new(1180, 0, -1080), Vector3.new(1180, 0, -1400),
		},
	},
	{
		name = "Millbrook Rise", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Millbrook", head = true,
		points = {
			Vector3.new(1400, 0, -1080), Vector3.new(1400, 0, -1330),
		},
	},
	{
		name = "Lunebank Road", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Hollingford",
		points = {
			Vector3.new(1400, 0, 300), Vector3.new(1500, 0, 300), Vector3.new(1940, 0, 740),
			Vector3.new(1940, 0, 800),
		},
	},
	{
		name = "Ferry Lane", kind = "residential", width = 20, front = "none", district = "Hollingford",
		points = {
			Vector3.new(1500, 0, 300), Vector3.new(1593, 0, 207),
		},
	},
	{
		name = "Fellmonger Street", kind = "residential", width = 20, front = "both", use = "terraced row",
		district = "Hollingford",
		points = {
			Vector3.new(1500, 0, 480), Vector3.new(1760, 0, 740), Vector3.new(1760, 0, 800),
		},
	},
	{
		name = "Bleach Street", kind = "residential", width = 20, front = "both", use = "semis",
		district = "Hollingford",
		points = {
			Vector3.new(1593, 0, 207), Vector3.new(2126, 0, 740), Vector3.new(2126, 0, 800),
		},
	},
	{
		name = "Garth Road", kind = "residential", width = 20, front = "both", use = "detached house",
		district = "Hollingford", head = true,
		points = {
			Vector3.new(1510, 0, 800), Vector3.new(1510, 0, 1560),
		},
	},
	{
		name = "Ropewalk", kind = "residential", width = 20, front = "none", district = "Hollingford",
		points = {
			Vector3.new(1660, 0, 640), Vector3.new(1843, 0, 457),
		},
	},
	-- Back alleys (Marcel, 2026-09-20): the small, fully paved road size
	-- (RoadTiles.ALLEY_SCALE, 22 studs across). Each runs down the middle of the gap
	-- between two terraced rows that stand back to back, where that gap is 29 to 36
	-- studs, and opens onto the streets it meets. width is the paved carriageway.
	{
		name = "Back Cooper Street", kind = "alley", width = 10, front = "none", district = "Station",
		points = { Vector3.new(-1190, 0, -174), Vector3.new(-740, 0, -174) },
	},
	{
		name = "Back Signal Street", kind = "alley", width = 10, front = "none", district = "Station",
		points = { Vector3.new(-1100, 0, -38), Vector3.new(-745, 0, -38) },
	},
	{
		name = "Back Lock Street", kind = "alley", width = 10, front = "none", district = "Station",
		points = { Vector3.new(-1100, 0, 88), Vector3.new(-595, 0, 88) },
	},
	{
		name = "Back Mill Street", kind = "alley", width = 10, front = "none", district = "Mill Street Terraces",
		points = { Vector3.new(0, 0, -265), Vector3.new(900, 0, -265) },
	},
	{
		name = "Back Fuller Street", kind = "alley", width = 10, front = "none", district = "Riverside",
		points = { Vector3.new(-1060, 0, 625), Vector3.new(-655, 0, 625) },
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
			{ centre = Vector3.new(400, 15, -41), size = Vector3.new(100, 30, 30), yaw = 0, use = "pub" }, -- v3: was (400, -35), placed clear of the v3 roads
			{ centre = Vector3.new(-260, 17, 36), size = Vector3.new(100, 34, 30), yaw = 0, use = "supermarket" }, -- v3: was (-260, 30), placed clear of the v3 roads
			{ centre = Vector3.new(-150, 15, 200), size = Vector3.new(120, 30, 60), yaw = 0, use = "town hall" },
			{ centre = Vector3.new(-220, 20, -230), size = Vector3.new(40, 40, 90), yaw = 0, use = "church" },
			{ centre = Vector3.new(-50, 15, -87), size = Vector3.new(30, 30, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(87, 17, -50), size = Vector3.new(30, 34, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-385, 17, 41), size = Vector3.new(50, 34, 30), yaw = 0, use = "pub" }, -- v3: was (-385, -7), placed clear of the v3 roads
			{ centre = Vector3.new(-183, 17, -59), size = Vector3.new(30, 34, 30), yaw = 0, use = "pub" },
			{ centre = Vector3.new(-117, 16, -54), size = Vector3.new(30, 32, 30), yaw = 0, use = "pub" }, -- v3: was (-147, -54), placed clear of the v3 roads
			{ centre = Vector3.new(-250, 15, 310), size = Vector3.new(120, 30, 60), yaw = 0, use = "school" },
			{ centre = Vector3.new(-365, 15, 95), size = Vector3.new(30, 30, 30), yaw = 0, use = "pub" }, -- v3: new
		},
	},
	{
		name = "Mill Street Terraces",
		kind = "terraced",
		blocks = {}, -- all generated: see TownFrontage
	},
	{
		name = "Northfields",
		kind = "estate",
		blocks = {
			{ centre = Vector3.new(-1100, 15, -750), size = Vector3.new(140, 30, 90), yaw = 0, use = "school" },
			{ centre = Vector3.new(1155, 0.5, -675), size = Vector3.new(150, 1, 106), yaw = 0, use = "park" }, -- v3: new, the green where Poplar Close was, inside the ring chamfer
			{ centre = Vector3.new(-100, 0.5, -760), size = Vector3.new(100, 1, 180), yaw = 0, use = "park" }, -- v3: new
			{ centre = Vector3.new(525, 0.5, -760), size = Vector3.new(110, 1, 180), yaw = 0, use = "park" }, -- v3: new
			{ centre = Vector3.new(80, 15, -645), size = Vector3.new(110, 30, 30), yaw = 0, use = "shops" }, -- v3: new
			{ centre = Vector3.new(-80, 15, -555), size = Vector3.new(110, 30, 30), yaw = 0, use = "shops" }, -- v3: new
		},
	},
	{
		name = "Riverside",
		kind = "riverside",
		blocks = {
			{ centre = Vector3.new(560, 15, 130), size = Vector3.new(120, 30, 40), yaw = 0, use = "pub and cafes" },
			{ centre = Vector3.new(600, 14, 214), size = Vector3.new(140, 28, 40), yaw = 0, use = "waterfront flats" }, -- v3: was (620, 230), now fronts Lune Street
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
			{ centre = Vector3.new(-1020, 0.5, -350), size = Vector3.new(120, 1, 60), yaw = 0, use = "station car park" },
			{ centre = Vector3.new(-668, 17, -330), size = Vector3.new(30, 34, 30), yaw = 0, use = "pub" },
		},
	},
	{
		name = "Industrial Estate",
		kind = "industrial",
		blocks = {
			{ centre = Vector3.new(-1650, 13, 20), size = Vector3.new(160, 26, 90), yaw = 0, use = "builders yard" },
		},
	},
	{
		name = "Westdale",
		kind = "estate",
		blocks = {
			{ centre = Vector3.new(-1110, 15, 1025), size = Vector3.new(140, 30, 90), yaw = 0, use = "school" }, -- v3: new
			{ centre = Vector3.new(-820, 0.5, 1175), size = Vector3.new(140, 1, 80), yaw = 0, use = "park" }, -- v3: new
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
	{
		name = "Mapleford",
		kind = "estate",
		blocks = {}, -- all generated: see TownFrontage
	},
	{
		name = "Millbrook",
		kind = "estate",
		blocks = {}, -- all generated: see TownFrontage
	},
	{
		name = "Hollingford",
		kind = "estate",
		blocks = {
			{ centre = Vector3.new(1600, 0.5, 80), size = Vector3.new(120, 1, 120), yaw = 45, use = "park" }, -- v3: new, the river meadow, square to the 45-degree estate
		},
	},
} :: { District }

TownLayout.LANDMARKS = {
	{ name = "Church Spire", position = Vector3.new(-220, 0, -240), height = 130 },
	{ name = "Lune Viaduct", position = Vector3.new(-550, 0, 400), height = 45 },
	{ name = "Lune Bridge", position = Vector3.new(100, 0, 420), height = 14 },
} :: { Landmark }

-- X268 (review): `yaw` is the direction the shelter opens. Four stops had it
-- backwards, so the shelter's back panel faced the road and passengers sat
-- looking at the verge; the painted bay made that obvious. Checked against the
-- bay each stop resolves: Town Centre, Riverside Park, Industrial Estate and
-- Sports Centre all have their road at +Z, so they open at 180.
TownLayout.BUS_STOPS = {
	{ name = "Town Centre", position = Vector3.new(90, 0, -20), yaw = 180 },
	-- X71: on Station Road's station-side pavement west of the taxi lay-by, facing the road
	-- (it stood on the forecourt over a planter and bench once the road moved, X51)
	{ name = "Station", position = Vector3.new(-915, 0, -355), yaw = 180 },
	{ name = "Riverside", position = Vector3.new(700, 0, 22), yaw = 0 }, -- v3: on Riverside Road's south pavement (was 80 off any road)
	{ name = "Riverside Park", position = Vector3.new(1180, 0, -22), yaw = 180 }, -- v3: on the pavement (was 27 behind the kerb)
	{ name = "Industrial Estate", position = Vector3.new(-1600, 0, -130), yaw = 180 },
	{ name = "Westdale", position = Vector3.new(-1075, 0, 964), yaw = 0 },
	{ name = "Sports Centre", position = Vector3.new(40, 0, 1180), yaw = 180 },
	{ name = "Plot 1", position = Vector3.new(992, 0, 840), yaw = 90 },
	{ name = "Plot 2", position = Vector3.new(1420, 0, -1058), yaw = 0 },
	{ name = "Plot 3", position = Vector3.new(-1838, 0, 610), yaw = 90 },
	{ name = "Plot 4", position = Vector3.new(-1380, 0, -1232), yaw = 180 },
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
