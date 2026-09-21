--!strict
-- Riverside Park (backlog E6.2). Reference: assets/references/RivermereAIMap.png
-- (Riverside Park: a looping path round open lawns, cross paths meeting at a
-- round feature in the middle, trees along the paths and in a belt round the
-- edge) plus RivermereRiverside.png for the street furniture (black lamps,
-- wooden benches, black litter bins, stone edging).
--
-- Everything is derived from TownLayout: the "park lawn" block gives the park
-- footprint, the "bandstand" block the bandstand, and the entrance paths walk
-- out from the loop until they meet a road's pavement. Built on top of
-- TownBuilder's lawn slab (top at TownBuilder.Y.FLAT = 0.3) into
-- workspace.Town.Park (Model, rebuilt from scratch):
--   Paths       tarmac loop (20 segments + joint discs), gravel cross paths, stone plaza
--   Pond        mud bed, glass water disc, 16-piece stone rim, lily pads, reeds
--   Playground  safety surface, railings with a gate, swings, slide, climbing frame, see-saw
--   Bandstand   octagonal stone base (4 crossed bars), steps, 8 posts, rails, tiered roof
--   Trees       trunk + 1-2 ball canopies, along the loop, a perimeter belt and a scatter
--   Furniture   kit benches and bins, TerraceBuilder lamps, a park name board
-- The greybox bandstand box TownBuilder put on the lawn is removed.
--
-- Y levels (every overlapping horizontal face differs by >= 0.05):
--  -0.10        bottom of every path / plaza / base slab (buried in lawn and terrain)
--   0.30        lawn top (TownBuilder)
--   0.35        loop joint discs
--   0.40 / 0.45 loop segments (alternating)
--   0.45        playground safety surface (does not touch any path)
--   0.50 / 0.55 cross path segments (alternating)
--   0.60        bandstand plaza
--   0.65        the pond-playground path (it crosses the spine)
--   0.50 .. 0.80 pond bed top / water top; rim tops 1.30 / 1.35
-- Budget: ~450 parts (MAX_TREES caps the biggest share), well under 600.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)
local TreeKit = require(script.Parent.TreeKit)
local V3Perf = require(script.Parent.V3Perf)

-- v3 Lane I stage 2: the kit street light replaces TerraceBuilder's 6-part primitive
-- lamp. `cframe` keeps the old convention (lantern toward local -Z); the kit lamp's
-- arm overhangs along its RightVector, hence the quarter turn.
local KIT_LAMP = "UKSP__StreetLights__StreetLight01"
local function kitLamp(cframe: CFrame, parent: Instance): Model
	local lamp = KitPlacer.place(KIT_LAMP, cframe * CFrame.Angles(0, math.pi / 2, 0), parent, {
		fallbackSize = Vector3.new(1, 14, 1),
	})
	lamp.Name = "ParkLamp"
	V3Perf.applyDefaults(lamp, "prop")
	return lamp
end
local TownBuilder = require(script.Parent.TownBuilder)

local ParkDresser = {}

export type Circle = { centre: Vector3, radius: number }
export type Plan = {
	district: string,
	centre: Vector3, -- lawn centre, y 0
	half: Vector3, -- lawn half extents (X, 0, Z)
	loop: { Vector3 }, -- closed: last point == first point
	paths: { { Vector3 } }, -- open polylines (entrances, spine, cross paths)
	crossing: { Vector3 }, -- pond rim -> playground gate, crossing the spine
	sign: Vector3?, -- park name board by the south entrance
	entrance: Vector3?, -- where the south path meets the road pavement
	plaza: Circle,
	bandstand: Circle, -- radius = apothem of the octagon
	pond: Circle, -- radius of open water (the rim sits outside it)
	playground: { centre: Vector3, size: Vector3 },
	benches: { CFrame },
	bins: { Vector3 },
	lamps: { CFrame },
}

local LAWN_USE = "park lawn"
local BANDSTAND_USE = "bandstand"

local Y = {
	SLAB_BOTTOM = -0.1,
	LAWN = TownBuilder.Y.FLAT,
	JOINT = 0.35,
	LOOP = { 0.40, 0.45 },
	CROSS = { 0.50, 0.55 },
	SAFETY = 0.45,
	PLAZA = 0.60,
	CROSSING = 0.65,
	POND_BED = 0.5,
	WATER_BOTTOM = 0.55,
	WATER = 0.8,
	RIM = { 1.30, 1.35 },
	BASE = 3.0, -- bandstand floor
	EAVE = 12.0, -- bandstand roof underside
}
ParkDresser.Y = Y

local PATH_W = 8
ParkDresser.PATH_WIDTH = PATH_W
local LOOP_POINTS = 20
local LOOP_INSET_X = 40 -- loop sits this far inside the lawn's east/west edges
local LOOP_INSET_Z = 50 -- ... and north/south edges
local PLAZA_MARGIN = 10 -- plaza radius = bandstand apothem + this
local POND_FRACTION = 0.22 -- pond radius as a fraction of the smaller loop radius
local RIM_W = 2.5
local PLAYGROUND_SIZE = Vector3.new(56, 0, 44)
local GATE_HALF = 5
local ROAD_SEARCH = 120

local MAX_TREES = 70
ParkDresser.MAX_TREES = MAX_TREES
local TREE_MARGIN = 6 -- isClear margin for a tree (canopy radius)
local TREE_EDGE_INSET = 6
local TREE_PATH_GAP = 3 -- trunk this far beyond a path edge
local TREE_FEATURE_GAP = 8
local TREE_SPACING = 14
local TREE_FURNITURE_GAP = 6
local LOOP_TREE_OFFSET = 11
local BELT_INSET = 10
local BELT_STEP = 26
local SCATTER_TRIES = 40
local BUS_STOP_CLEAR = 8
local PART_BUDGET = 600

local STONE = Color3.fromRGB(196, 184, 160)
local PAVING = Color3.fromRGB(206, 192, 170)
local TARMAC = Color3.fromRGB(104, 104, 106)
local GRAVEL = Color3.fromRGB(190, 172, 138)
local IRON = Color3.fromRGB(22, 22, 24)
local TIMBER = Color3.fromRGB(120, 92, 64)
local IRON_GREEN = Color3.fromRGB(34, 74, 52)
local CREAM = Color3.fromRGB(236, 226, 196)
local WATER = Color3.fromRGB(64, 112, 128)
local MUD = Color3.fromRGB(52, 60, 44)
local SAFETY = Color3.fromRGB(170, 72, 52)
local FENCE_GREEN = Color3.fromRGB(40, 90, 60)
local PLAY_RED = Color3.fromRGB(200, 50, 40)
local PLAY_BLUE = Color3.fromRGB(40, 90, 180)
local PLAY_YELLOW = Color3.fromRGB(240, 190, 40)
local TRUNK = Color3.fromRGB(90, 68, 45)

-- ------------------------------------------------------------ pure helpers

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- The first district block with this use, and its district's name.
function ParkDresser.findBlock(use: string): (TownLayout.Box?, string?)
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use == use then
				return block, district.name
			end
		end
	end
	return nil, nil
end

-- Pure: 8 points on a circle of `radius` (the octagon's vertex radius) round
-- `centre`, at `centre.Y`, starting at angle `offset` (radians, measured from
-- +X towards +Z). offset = pi/8 puts the edges square to the X and Z axes.
function ParkDresser.octagonPoints(centre: Vector3, radius: number, offset: number?): { Vector3 }
	local out: { Vector3 } = {}
	for k = 0, 7 do
		local a = (offset or 0) + k * math.pi / 4
		table.insert(out, centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
	end
	return out
end

-- Pure: a closed ellipse of `count` segments (count + 1 points, last == first)
-- with radii rx (X) and rz (Z), starting due east and turning towards +Z.
function ParkDresser.loopPoints(centre: Vector3, rx: number, rz: number, count: number): { Vector3 }
	local out: { Vector3 } = {}
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		table.insert(out, Vector3.new(centre.X + math.cos(a) * rx, 0, centre.Z + math.sin(a) * rz))
	end
	table.insert(out, out[1])
	return out
end

-- Half of the ellipse's extent along one axis at offset t along the other:
-- ellipseHalf(rx, rz, dx) is how far north/south the ellipse reaches at dx.
function ParkDresser.ellipseHalf(a: number, b: number, t: number): number
	return b * math.sqrt(math.max(0, 1 - (t / a) ^ 2))
end

-- Pure: does p (plus `margin`) land on a building volume? The park lawn itself
-- is ground, not a building, so it never blocks.
function ParkDresser.hitsBuilding(p: Vector3, margin: number): boolean
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use ~= LAWN_USE then
				local c, s = block.centre, block.size
				if math.abs(p.X - c.X) < s.X / 2 + margin and math.abs(p.Z - c.Z) < s.Z / 2 + margin then
					return true
				end
			end
		end
	end
	local station = TownLayout.RAIL.station
	if math.abs(p.X - station.centre.X) < station.size.X / 2 + margin and math.abs(p.Z - station.centre.Z) < station.size.Z / 2 + margin then
		return true
	end
	return false
end

-- Pure: is p (plus `margin`, default 3) clear of roads and their pavements,
-- roundabouts, the river, bridges, the railway, buildings, bus stops and plots?
function ParkDresser.isClear(p: Vector3, margin: number?): boolean
	local m = margin or 3
	if TownLayout.distanceToPolyline(p, TownLayout.RIVER.points) < TownLayout.RIVER.width / 2 + m then
		return false
	end
	for _, bridge in TownLayout.BRIDGES do
		if TownLayout.segmentDistance(p, bridge.from, bridge.to) < bridge.width / 2 + TownLayout.PAVEMENT_WIDTH + m then
			return false
		end
	end
	for _, road in TownLayout.ROADS do
		if TownLayout.distanceToPolyline(p, road.points) < road.width / 2 + TownLayout.PAVEMENT_WIDTH + m then
			return false
		end
	end
	for _, r in TownLayout.ROUNDABOUTS do
		if flatDistance(p, r.centre) < r.radius + TownLayout.PAVEMENT_WIDTH + m then
			return false
		end
	end
	if TownLayout.distanceToPolyline(p, TownLayout.RAIL.points) < TownLayout.RAIL.width / 2 + m then
		return false
	end
	if ParkDresser.hitsBuilding(p, m) then
		return false
	end
	for _, stop in TownLayout.BUS_STOPS do
		if flatDistance(p, stop.position) < BUS_STOP_CLEAR + m then
			return false
		end
	end
	for i = 1, #TownLayout.PLOTS do
		if TownLayout.pointInPlot(p, i) then
			return false
		end
	end
	return true
end

-- Pure: walk from `from` along `dir` one stud at a time until the centreline
-- is half a stud onto a road's pavement. nil if a building is in the way or
-- no road is within `maxDist`.
function ParkDresser.walkToRoad(from: Vector3, dir: Vector3, maxDist: number): Vector3?
	for d = 0, maxDist do
		local p = from + dir * d
		for _, road in TownLayout.ROADS do
			if TownLayout.distanceToPolyline(p, road.points) <= road.width / 2 + TownLayout.PAVEMENT_WIDTH - 0.5 then
				return p
			end
		end
		if ParkDresser.hitsBuilding(p, PATH_W / 2) then
			return nil
		end
	end
	return nil
end

-- Pure: is p at least `gap` beyond the edge of every path in the plan?
function ParkDresser.clearOfPaths(plan: Plan, p: Vector3, gap: number): boolean
	if TownLayout.distanceToPolyline(p, plan.loop) < PATH_W / 2 + gap then
		return false
	end
	if TownLayout.distanceToPolyline(p, plan.crossing) < PATH_W / 2 + gap then
		return false
	end
	for _, path in plan.paths do
		if TownLayout.distanceToPolyline(p, path) < PATH_W / 2 + gap then
			return false
		end
	end
	return true
end

-- Pure: inside the lawn (inset by `inset`)?
function ParkDresser.inPark(plan: Plan, p: Vector3, inset: number): boolean
	return math.abs(p.X - plan.centre.X) <= plan.half.X - inset and math.abs(p.Z - plan.centre.Z) <= plan.half.Z - inset
end

-- Pure: the whole park layout from TownLayout. nil if there is no park lawn.
function ParkDresser.plan(): Plan?
	local lawn, district = ParkDresser.findBlock(LAWN_USE)
	if not lawn or not district then
		return nil
	end
	local c = Vector3.new(lawn.centre.X, 0, lawn.centre.Z)
	local hx, hz = lawn.size.X / 2, lawn.size.Z / 2
	local rx, rz = hx - LOOP_INSET_X, hz - LOOP_INSET_Z
	local loop = ParkDresser.loopPoints(c, rx, rz, LOOP_POINTS)

	local stand = ParkDresser.findBlock(BANDSTAND_USE)
	local b = if stand then Vector3.new(stand.centre.X, 0, stand.centre.Z) else c
	local apothem = if stand then math.min(stand.size.X, stand.size.Z) / 2 else 10
	local plazaR = apothem + PLAZA_MARGIN
	local inner = plazaR - 2 -- paths run 2 studs under the plaza edge

	local paths: { { Vector3 } } = {}
	-- north-south spine through the plaza, out to the roads either side
	local reachZ = ParkDresser.ellipseHalf(rx, rz, b.X - c.X)
	local south = Vector3.new(b.X, 0, c.Z + reachZ)
	local north = Vector3.new(b.X, 0, c.Z - reachZ)
	local entrance = ParkDresser.walkToRoad(south, Vector3.new(0, 0, 1), ROAD_SEARCH)
	local northGate = ParkDresser.walkToRoad(north, Vector3.new(0, 0, -1), ROAD_SEARCH)
	local southPath = { south, b + Vector3.new(0, 0, inner) }
	if entrance then
		table.insert(southPath, 1, entrance)
	end
	local northPath = { north, b - Vector3.new(0, 0, inner) }
	if northGate then
		table.insert(northPath, 1, northGate)
	end
	table.insert(paths, southPath)
	table.insert(paths, northPath)
	-- east-west cross
	local reachX = ParkDresser.ellipseHalf(rz, rx, b.Z - c.Z)
	table.insert(paths, { Vector3.new(c.X - reachX, 0, b.Z), b - Vector3.new(inner, 0, 0) })
	table.insert(paths, { Vector3.new(c.X + reachX, 0, b.Z), b + Vector3.new(inner, 0, 0) })
	-- diagonals from the south-west and south-east of the loop
	for _, a in { math.pi * 3 / 4, math.pi / 4 } do
		local start = Vector3.new(c.X + math.cos(a) * rx, 0, c.Z + math.sin(a) * rz)
		table.insert(paths, { start, b + (start - b).Unit * inner })
	end

	-- pond (north-west) and playground (north-east), joined by a path across the spine
	local pondR = math.min(rx, rz) * POND_FRACTION
	local pond = { centre = Vector3.new(c.X - rx * 0.5, 0, c.Z - rz * 0.5), radius = pondR }
	local playground = { centre = Vector3.new(c.X + rx * 0.5, 0, c.Z - rz * 0.5), size = PLAYGROUND_SIZE }
	local crossing = {
		Vector3.new(pond.centre.X + pondR + RIM_W - 1, 0, pond.centre.Z),
		Vector3.new(playground.centre.X - PLAYGROUND_SIZE.X / 2, 0, playground.centre.Z),
	}

	local plan: Plan = {
		district = district,
		centre = c,
		half = Vector3.new(hx, 0, hz),
		loop = loop,
		paths = paths,
		crossing = crossing,
		sign = nil,
		entrance = entrance,
		plaza = { centre = b, radius = plazaR },
		bandstand = { centre = b, radius = apothem },
		pond = pond,
		playground = playground,
		benches = {},
		bins = {},
		lamps = {},
	}

	local function spotOk(p: Vector3, gap: number): boolean
		return ParkDresser.isClear(p, 1) and ParkDresser.clearOfPaths(plan, p, gap)
	end

	-- benches: beside the loop facing it, on the plaza facing the bandstand, by the pond
	local function addBench(seat: Vector3, faceTo: Vector3, withBin: boolean)
		if not spotOk(seat, 2) then
			return
		end
		local cf = CFrame.lookAt(seat, Vector3.new(faceTo.X, seat.Y, faceTo.Z))
		table.insert(plan.benches, cf)
		local bin = (cf * CFrame.new(4.5, 0, 0)).Position
		if withBin and spotOk(bin, 1.5) then
			table.insert(plan.bins, bin)
		end
	end
	for _, i in { 4, 9, 14, 19 } do
		local p = loop[i + 1]
		local outward = flat(p - c).Unit
		addBench(Vector3.new(p.X, Y.LAWN - 0.05, p.Z) + outward * (PATH_W / 2 + 3), p, true)
	end
	for _, deg in { 225, 315 } do
		local a = math.rad(deg)
		local seat = b + Vector3.new(math.cos(a), 0, math.sin(a)) * (plazaR - 2.5)
		addBench(Vector3.new(seat.X, Y.PLAZA - 0.05, seat.Z), b, true)
	end
	for _, deg in { 90, 135 } do
		local a = math.rad(deg)
		local seat = pond.centre + Vector3.new(math.cos(a), 0, math.sin(a)) * (pondR + RIM_W + 4)
		addBench(Vector3.new(seat.X, Y.LAWN - 0.05, seat.Z), pond.centre, false)
	end

	-- lamps: lantern (local -Z) hangs over the nearest path
	local function addLamp(p: Vector3, towards: Vector3)
		if spotOk(p, 1) then
			table.insert(plan.lamps, CFrame.lookAt(Vector3.new(p.X, Y.LAWN - 0.05, p.Z), Vector3.new(towards.X, Y.LAWN - 0.05, towards.Z)))
		end
	end
	for _, i in { 2, 7, 12, 17 } do
		local p = loop[i + 1]
		addLamp(p + flat(p - c).Unit * (PATH_W / 2 + 1.5), p)
	end
	local side = PATH_W / 2 + 1.5
	addLamp(b + Vector3.new(side, 0, plazaR + 6), b + Vector3.new(0, 0, plazaR + 6))
	addLamp(b + Vector3.new(-side, 0, -(plazaR + 6)), b - Vector3.new(0, 0, plazaR + 6))
	addLamp(south + Vector3.new(side, 0, 12), south + Vector3.new(0, 0, 12))

	-- name board beside the south entrance, just inside the lawn edge
	if entrance then
		local signAt = Vector3.new(b.X - (PATH_W / 2 + 6), 0, c.Z + hz - 4)
		if spotOk(signAt, 1) then
			plan.sign = signAt
		end
	end

	return plan
end

-- Pure: can a tree stand at p, given the trees already `placed`?
function ParkDresser.treeSpotOk(plan: Plan, p: Vector3, placed: { Vector3 }): boolean
	if not ParkDresser.inPark(plan, p, TREE_EDGE_INSET) then
		return false
	end
	if not ParkDresser.isClear(p, TREE_MARGIN) then
		return false
	end
	if not ParkDresser.clearOfPaths(plan, p, TREE_PATH_GAP) then
		return false
	end
	if flatDistance(p, plan.pond.centre) < plan.pond.radius + RIM_W + TREE_FEATURE_GAP then
		return false
	end
	if flatDistance(p, plan.plaza.centre) < plan.plaza.radius + TREE_FEATURE_GAP then
		return false
	end
	local g = plan.playground
	if math.abs(p.X - g.centre.X) < g.size.X / 2 + TREE_FEATURE_GAP and math.abs(p.Z - g.centre.Z) < g.size.Z / 2 + TREE_FEATURE_GAP then
		return false
	end
	for _, cf in plan.benches do
		if flatDistance(p, cf.Position) < TREE_FURNITURE_GAP then
			return false
		end
	end
	for _, cf in plan.lamps do
		if flatDistance(p, cf.Position) < TREE_FURNITURE_GAP then
			return false
		end
	end
	local sign = plan.sign
	if sign and flatDistance(p, sign) < TREE_FURNITURE_GAP + 4 then
		return false
	end
	for _, q in placed do
		if flatDistance(p, q) < TREE_SPACING then
			return false
		end
	end
	return true
end

-- Pure (given the rng): tree positions at y 0, along both sides of the loop,
-- in a belt round the lawn edge, then a scatter; at most MAX_TREES.
function ParkDresser.treePositions(plan: Plan, rng: Random): { Vector3 }
	local out: { Vector3 } = {}
	local function try(p: Vector3)
		local q = flat(p)
		if #out < MAX_TREES and ParkDresser.treeSpotOk(plan, q, out) then
			table.insert(out, q)
		end
	end
	local c = plan.centre
	for i = 1, #plan.loop - 1 do
		local a, b = plan.loop[i], plan.loop[i + 1]
		local mid = (a + b) / 2
		local along = (b - a).Unit
		local outward = flat(mid - c).Unit
		for _, s in { 1, -1 } do
			try(mid + outward * s * (LOOP_TREE_OFFSET + rng:NextNumber(0, 3)) + along * rng:NextNumber(-5, 5))
		end
	end
	local hx, hz = plan.half.X - BELT_INSET, plan.half.Z - BELT_INSET
	local corners = {
		c + Vector3.new(-hx, 0, -hz),
		c + Vector3.new(hx, 0, -hz),
		c + Vector3.new(hx, 0, hz),
		c + Vector3.new(-hx, 0, hz),
	}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local n = math.max(1, math.floor((b - a).Magnitude / BELT_STEP))
		for k = 0, n - 1 do
			local p = a:Lerp(b, (k + rng:NextNumber(0, 0.5)) / n)
			try(p + flat(c - p).Unit * rng:NextNumber(0, 4))
		end
	end
	for _ = 1, SCATTER_TRIES do
		try(c + Vector3.new(rng:NextNumber(-plan.half.X, plan.half.X), 0, rng:NextNumber(-plan.half.Z, plan.half.Z)))
	end
	return out
end

-- ------------------------------------------------------------ geometry

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- A box from extents in a local frame (x across, y up, z along).
local function slab(parent: Instance, frame: CFrame, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, colour: Color3, material: Enum.Material?): BasePart
	return part({
		Name = name,
		Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Color = colour,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- A (width x thick) bar from a to b (world points). Safe for vertical bars.
local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, thick: number, colour: Color3, material: Enum.Material?): BasePart
	local mid = (a + b) / 2
	local d = b - a
	local cf: CFrame
	if math.abs(d.X) + math.abs(d.Z) < 1e-3 then
		cf = CFrame.new(mid) * CFrame.Angles(math.pi / 2, 0, 0) -- LookVector up
	else
		cf = CFrame.lookAt(mid, b)
	end
	return part({
		Name = name,
		Size = Vector3.new(width, thick, d.Magnitude),
		CFrame = cf,
		Color = colour,
		Material = material or Enum.Material.Metal,
		Parent = parent,
	})
end

-- A vertical cylinder (disc or post) from y bottom to top.
local function disc(parent: Instance, name: string, centre: Vector3, radius: number, bottom: number, top: number, colour: Color3, material: Enum.Material?): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(top - bottom, radius * 2, radius * 2),
		CFrame = CFrame.new(centre.X, (top + bottom) / 2, centre.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = colour,
		Material = material or Enum.Material.SmoothPlastic,
		CastShadow = false,
		Parent = parent,
	})
end

-- A filled octagon of 4 crossed bars (edges square to X/Z). Each bar is
-- raised 0.05 over the last so no two top or bottom faces are coplanar.
local function octagon(parent: Instance, name: string, centre: Vector3, apothem: number, bottom: number, top: number, colour: Color3, material: Enum.Material)
	local side = 2 * apothem * math.tan(math.pi / 8)
	for k = 0, 3 do
		local lift = k * 0.05
		part({
			Name = name,
			Size = Vector3.new(side, top - bottom, 2 * apothem),
			CFrame = CFrame.new(centre.X, (top + bottom) / 2 + lift, centre.Z) * CFrame.Angles(0, k * math.pi / 4, 0),
			Color = colour,
			Material = material,
			Parent = parent,
		})
	end
end

local function pathSegment(parent: Instance, a: Vector3, b: Vector3, top: number, colour: Color3, material: Enum.Material)
	local cf, length = TownBuilder.segmentCFrame(a, b, (top + Y.SLAB_BOTTOM) / 2)
	if length < 0.5 then
		return
	end
	part({
		Name = "Path",
		Size = Vector3.new(PATH_W, top - Y.SLAB_BOTTOM, length),
		CFrame = cf,
		Color = colour,
		Material = material,
		CastShadow = false,
		Parent = parent,
	})
end

local function buildPaths(parent: Instance, plan: Plan)
	local loop = plan.loop
	for i = 1, #loop - 1 do
		pathSegment(parent, loop[i], loop[i + 1], Y.LOOP[i % 2 + 1], TARMAC, Enum.Material.Asphalt)
		disc(parent, "PathJoint", loop[i], PATH_W / 2, Y.SLAB_BOTTOM, Y.JOINT, TARMAC, Enum.Material.Asphalt)
	end
	for _, path in plan.paths do
		for k = 1, #path - 1 do
			pathSegment(parent, path[k], path[k + 1], Y.CROSS[k % 2 + 1], GRAVEL, Enum.Material.Pebble)
			if k > 1 then
				local d0 = flat(path[k] - path[k - 1])
				local d1 = flat(path[k + 1] - path[k])
				if d0.Magnitude > 0.5 and d1.Magnitude > 0.5 and d0.Unit:Dot(d1.Unit) < 0.999 then
					disc(parent, "PathJoint", path[k], PATH_W / 2, Y.SLAB_BOTTOM, Y.JOINT, GRAVEL, Enum.Material.Pebble)
				end
			end
		end
	end
	pathSegment(parent, plan.crossing[1], plan.crossing[2], Y.CROSSING, GRAVEL, Enum.Material.Pebble)
	disc(parent, "Plaza", plan.plaza.centre, plan.plaza.radius, Y.SLAB_BOTTOM, Y.PLAZA, PAVING, Enum.Material.Pavement)
end

local function buildPond(parent: Instance, pond: Circle, rng: Random)
	local c, r = pond.centre, pond.radius
	disc(parent, "Bed", c, r + 0.5, Y.SLAB_BOTTOM, Y.POND_BED, MUD, Enum.Material.Mud)
	local water = disc(parent, "Water", c, r + 0.5, Y.WATER_BOTTOM, Y.WATER, WATER, Enum.Material.Glass)
	water.Transparency = 0.25
	local pieces = 16
	local length = 2 * (r + RIM_W) * math.sin(math.pi / pieces) + 0.2
	for k = 0, pieces - 1 do
		local a = (k + 0.5) * math.pi * 2 / pieces
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tangent = Vector3.new(-dir.Z, 0, dir.X)
		local top = Y.RIM[k % 2 + 1]
		local mid = c + dir * (r + RIM_W / 2) + Vector3.new(0, (top + Y.SLAB_BOTTOM) / 2, 0)
		part({
			Name = "Rim",
			Size = Vector3.new(RIM_W, top - Y.SLAB_BOTTOM, length),
			CFrame = CFrame.lookAt(mid, mid + tangent),
			Color = STONE,
			Material = Enum.Material.Limestone,
			Parent = parent,
		})
	end
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0.2, 0.7) * r
		local pad = disc(parent, "LilyPad", p, rng:NextNumber(1, 1.6), 0.76, 0.86, Color3.fromRGB(70, 130, 60), Enum.Material.Grass)
		pad.CanCollide = false
	end
	-- two clumps of reeds just inside the rim (north side, away from the benches)
	for _, deg in { 250, 290 } do
		local a = math.rad(deg)
		local base = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (r - 2)
		for j = 0, 2 do
			local h = 3 + j * 0.6
			local p = base + Vector3.new((j - 1) * 0.9, 0, (j % 2) * 0.7)
			part({
				Name = "Reed",
				Size = Vector3.new(0.3, h, 0.3),
				CFrame = CFrame.new(p.X, Y.POND_BED + h / 2 - 0.1, p.Z) * CFrame.Angles(0, 0, math.rad((j - 1) * 8)),
				Color = Color3.fromRGB(96, 124, 60),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CastShadow = false,
				Parent = parent,
			})
		end
	end
end

local function buildPlayground(parent: Instance, g: { centre: Vector3, size: Vector3 })
	local f = CFrame.new(g.centre.X, 0, g.centre.Z)
	local hx, hz = g.size.X / 2, g.size.Z / 2
	slab(parent, f, "SafetySurface", -hx + 1, hx - 1, 0.25, Y.SAFETY, -hz + 1, hz - 1, SAFETY)

	-- railings: posts round the edge, two rails a side, a gate gap mid-west (local -X)
	local fence = Instance.new("Model")
	fence.Name = "Railings"
	fence.Parent = parent
	local corners = { Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz) }
	local function post(x: number, z: number)
		slab(fence, f, "Post", x - 0.2, x + 0.2, Y.LAWN - 0.1, 3.9, z - 0.2, z + 0.2, FENCE_GREEN, Enum.Material.Metal)
	end
	local function rails(a: Vector3, b: Vector3)
		for _, y in { 1.2, 3.4 } do
			beam(fence, "Rail", (f * CFrame.new(a.X, y, a.Z)).Position, (f * CFrame.new(b.X, y, b.Z)).Position, 0.2, 0.2, FENCE_GREEN)
		end
	end
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local isWest = i == 4 -- SW -> NW
		local n = math.max(1, math.ceil((b - a).Magnitude / 11))
		for k = 0, n - 1 do
			local p = a:Lerp(b, k / n)
			if not (isWest and math.abs(p.Z) < GATE_HALF + 0.5) then
				post(p.X, p.Z)
			end
		end
		if isWest then
			post(-hx, GATE_HALF)
			post(-hx, -GATE_HALF)
			rails(a, Vector3.new(-hx, 0, GATE_HALF))
			rails(Vector3.new(-hx, 0, -GATE_HALF), b)
		else
			rails(a, b)
		end
	end

	local top = Y.SAFETY
	local function at(x: number, y: number, z: number): Vector3
		return (f * CFrame.new(x, y, z)).Position
	end

	-- swings: A-frame each end, top bar, two seats on chains
	local swings = Instance.new("Model")
	swings.Name = "Swings"
	swings.Parent = parent
	local sx, sz = -8, -13
	for _, dx in { -6, 6 } do
		for _, dz in { -2.4, 2.4 } do
			beam(swings, "Leg", at(sx + dx, top - 0.1, sz + dz), at(sx + dx, 8.3, sz), 0.4, 0.4, PLAY_RED)
		end
	end
	slab(swings, f, "TopBar", sx - 6.2, sx + 6.2, 8.1, 8.5, sz - 0.2, sz + 0.2, PLAY_RED, Enum.Material.Metal)
	for _, dx in { -3, 3 } do
		slab(swings, f, "Seat", sx + dx - 1, sx + dx + 1, 1.8, 2.1, sz - 0.5, sz + 0.5, IRON, Enum.Material.SmoothPlastic)
		for _, cx in { -0.8, 0.8 } do
			local chain = slab(swings, f, "Chain", sx + dx + cx - 0.05, sx + dx + cx + 0.05, 2.1, 8.1, sz - 0.05, sz + 0.05, Color3.fromRGB(160, 160, 160), Enum.Material.Metal)
			chain.CanCollide = false
			chain.CastShadow = false
		end
	end

	-- slide: platform on legs, ladder up the north side, chute down to the south
	local slide = Instance.new("Model")
	slide.Name = "Slide"
	slide.Parent = parent
	local px, pz, ph = 14, -10, 6
	slab(slide, f, "Platform", px - 2, px + 2, ph - 0.3, ph, pz - 2, pz + 2, PLAY_BLUE, Enum.Material.Metal)
	for _, dx in { -1.7, 1.7 } do
		for _, dz in { -1.7, 1.7 } do
			slab(slide, f, "Leg", px + dx - 0.2, px + dx + 0.2, top - 0.1, ph - 0.2, pz + dz - 0.2, pz + dz + 0.2, PLAY_BLUE, Enum.Material.Metal)
		end
	end
	for _, dx in { -1.6, 1.6 } do
		beam(slide, "LadderRail", at(px + dx, top - 0.1, pz - 5), at(px + dx, ph + 1, pz - 2), 0.3, 0.3, PLAY_BLUE)
	end
	for t = 1, 4 do
		local p = at(px, top + (ph - top) * t / 5, pz - 5 + 3 * t / 5)
		part({ Name = "Rung", Size = Vector3.new(3.2, 0.25, 0.25), CFrame = CFrame.new(p), Color = PLAY_BLUE, Material = Enum.Material.Metal, Parent = slide })
	end
	local chuteTop, chuteEnd = at(px, ph - 0.1, pz + 2), at(px, top + 0.6, pz + 16)
	beam(slide, "Chute", chuteTop, chuteEnd, 3, 0.25, PLAY_YELLOW, Enum.Material.SmoothPlastic)
	for _, dx in { -1.6, 1.6 } do
		beam(slide, "ChuteSide", chuteTop + Vector3.new(dx, 0.5, 0), chuteEnd + Vector3.new(dx, 0.5, 0), 0.25, 1, PLAY_YELLOW, Enum.Material.SmoothPlastic)
	end

	-- climbing frame: a cube of bars (posts wider than bars so no faces coincide)
	local climb = Instance.new("Model")
	climb.Name = "ClimbingFrame"
	climb.Parent = parent
	local cx, cz, ch = -10, 10, 8
	for _, dx in { -4, 4 } do
		for _, dz in { -4, 4 } do
			slab(climb, f, "Post", cx + dx - 0.3, cx + dx + 0.3, top - 0.1, ch + 0.1, cz + dz - 0.3, cz + dz + 0.3, PLAY_BLUE, Enum.Material.Metal)
		end
	end
	for _, y in { 4, ch } do
		for _, dz in { -4, 4 } do
			slab(climb, f, "Bar", cx - 4, cx + 4, y - 0.2, y + 0.2, cz + dz - 0.2, cz + dz + 0.2, PLAY_RED, Enum.Material.Metal)
		end
		for _, dx in { -4, 4 } do
			slab(climb, f, "Bar", cx + dx - 0.2, cx + dx + 0.2, y - 0.2, y + 0.2, cz - 3.8, cz + 3.8, PLAY_RED, Enum.Material.Metal)
		end
	end

	-- see-saw
	slab(parent, f, "SeeSawPivot", 3.5, 4.5, top - 0.1, 1.6, 14, 16, IRON, Enum.Material.Metal)
	beam(parent, "SeeSaw", at(-1.5, 1.0, 15), at(9.5, 2.2, 15), 1.2, 0.25, PLAY_YELLOW, Enum.Material.WoodPlanks)

	-- a bench and bin for the grown-ups, inside the gate
	local benchAt = at(-23, top - 0.05, -14)
	KitPlacer.place("UKSP__ParkBenches__ParkBench01", CFrame.lookAt(benchAt, benchAt + Vector3.new(1, 0, 0)), parent, {
		fallbackSize = Vector3.new(6, 3, 2),
		fallbackColor = TIMBER,
		fallbackMaterial = Enum.Material.Wood,
	})
	KitPlacer.place("UKSP__LitterBin__LitterBin", CFrame.new(at(-24, top - 0.05, 16)), parent, {
		fallbackSize = Vector3.new(2, 3.5, 2),
		fallbackColor = IRON,
	})
end

local function buildBandstand(parent: Instance, stand: Circle, entranceDir: Vector3)
	local b, a = stand.centre, stand.radius
	local vertexR = a / math.cos(math.pi / 8)
	octagon(parent, "Base", b, a, Y.SLAB_BOTTOM, Y.BASE, STONE, Enum.Material.Limestone)
	-- two steps up from the plaza on the entrance side
	local stepFrame = CFrame.lookAt(b, b + entranceDir) -- local -Z = entranceDir
	slab(parent, stepFrame, "Step", -3, 3, Y.SLAB_BOTTOM, 1.4, -(a + 2.4), -(a + 0.7), STONE, Enum.Material.Limestone)
	slab(parent, stepFrame, "Step", -3, 3, Y.SLAB_BOTTOM, 2.2, -(a + 0.8), -(a - 0.4), STONE, Enum.Material.Limestone)

	local posts = ParkDresser.octagonPoints(b, vertexR - 1, math.pi / 8)
	for _, p in posts do
		part({
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Y.EAVE + 0.1 - (Y.BASE - 0.1), 0.7, 0.7),
			CFrame = CFrame.new(p.X, (Y.EAVE + 0.1 + Y.BASE - 0.1) / 2, p.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = IRON_GREEN,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
	-- railings on every edge but the one facing the steps
	local skip, best = 1, -math.huge
	for k = 1, 8 do
		local mid = (posts[k] + posts[k % 8 + 1]) / 2
		local d = flat(mid - b).Unit:Dot(entranceDir)
		if d > best then
			skip, best = k, d
		end
	end
	for k = 1, 8 do
		if k ~= skip then
			for _, y in { Y.BASE + 1.2, Y.BASE + 2.8 } do
				beam(parent, "Rail", posts[k] + Vector3.new(0, y, 0), posts[k % 8 + 1] + Vector3.new(0, y, 0), 0.25, 0.25, IRON_GREEN)
			end
		end
	end

	-- tiered roof: cream eave, green tiers, finial
	octagon(parent, "Eave", b, a * 1.08, Y.EAVE, Y.EAVE + 0.8, CREAM, Enum.Material.SmoothPlastic)
	octagon(parent, "Roof", b, a * 0.8, Y.EAVE + 0.5, Y.EAVE + 2.3, IRON_GREEN, Enum.Material.Metal)
	octagon(parent, "Roof", b, a * 0.5, Y.EAVE + 2.0, Y.EAVE + 3.9, IRON_GREEN, Enum.Material.Metal)
	octagon(parent, "Roof", b, a * 0.22, Y.EAVE + 3.6, Y.EAVE + 5.2, IRON_GREEN, Enum.Material.Metal)
	part({
		Name = "Finial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = CFrame.new(b.X, Y.EAVE + 5.9, b.Z),
		Color = CREAM,
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	slab(parent, CFrame.new(b.X, 0, b.Z), "Spike", -0.1, 0.1, Y.EAVE + 6.3, Y.EAVE + 7.8, -0.1, 0.1, IRON, Enum.Material.Metal)
end

local function buildTree(parent: Instance, pos: Vector3, rng: Random)
	-- the slice's oaks: mostly the upright ones, one in five a big spreading oak.
	-- The trunk and ball crowns below only when the place has no oak pack.
	local big = rng:NextNumber() < 0.2
	if TreeKit.tree(parent, Vector3.new(pos.X, Y.LAWN, pos.Z), {
		height = if big then rng:NextNumber(26, 32) else rng:NextNumber(20, 27),
		slim = not big,
		rng = rng,
	}) then
		return
	end
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	tree.Parent = parent
	local scale = rng:NextNumber(0.8, 1.35)
	local trunkH = 9 * scale
	disc(tree, "Trunk", pos, 0.65 * scale, Y.LAWN - 0.1, Y.LAWN + trunkH, TRUNK, Enum.Material.Wood).CastShadow = true
	local green = Color3.fromRGB(62 + rng:NextInteger(-10, 20), 116 + rng:NextInteger(-15, 25), 50 + rng:NextInteger(-10, 10))
	local canopy = 11 * scale
	part({
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * canopy,
		CFrame = CFrame.new(pos.X, Y.LAWN + trunkH + 2.5 * scale, pos.Z),
		Color = green,
		Material = Enum.Material.Grass,
		Parent = tree,
	})
	if rng:NextNumber() < 0.45 then
		local a = rng:NextNumber(0, math.pi * 2)
		part({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (canopy * 0.65),
			CFrame = CFrame.new(pos.X + math.cos(a) * 3 * scale, Y.LAWN + trunkH + 5.5 * scale, pos.Z + math.sin(a) * 3 * scale),
			Color = green:Lerp(Color3.fromRGB(150, 180, 90), 0.2),
			Material = Enum.Material.Grass,
			CastShadow = false,
			Parent = tree,
		})
	end
end

local function buildSign(parent: Instance, plan: Plan)
	local p = plan.sign
	if not p then
		return
	end
	local f = CFrame.new(p.X, 0, p.Z)
	for _, x in { -3.6, 3.6 } do
		slab(parent, f, "SignPost", x - 0.2, x + 0.2, Y.LAWN - 0.1, 5.4, -0.2, 0.2, IRON, Enum.Material.Metal)
	end
	local board = slab(parent, f, "SignBoard", -4.2, 4.2, 3, 5.2, -0.4, 0.4, Color3.fromRGB(28, 40, 70), Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.8)
		label.Position = UDim2.fromScale(0.03, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = CREAM
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.Text = plan.district
		label.Parent = gui
	end
end

local function removeGreyboxBandstand(town: Instance, plan: Plan)
	local districts = town:FindFirstChild("Districts")
	local park = districts and districts:FindFirstChild(plan.district)
	if not park then
		return
	end
	local c = plan.bandstand.centre
	for _, d in park:GetChildren() do
		if d:IsA("BasePart") and (d.Name == BANDSTAND_USE or d.Name == BANDSTAND_USE .. " roof") then
			if math.abs(d.Position.X - c.X) < 0.5 and math.abs(d.Position.Z - c.Z) < 0.5 then
				d:Destroy()
			end
		end
	end
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- X140: picnics on the open lawn (a blanket, two people sitting facing each
-- other, a basket), clear of paths, trees, the pond, the playground, the
-- bandstand plaza and each other. Pure; seeded by the caller's rng.
ParkDresser.PICNICS = 6
local PICNIC_TRIES = 200
local PICNIC_GAP = 6
function ParkDresser.picnicSpots(plan: Plan, trees: { Vector3 }, rng: Random): { CFrame }
	local out: { CFrame } = {}
	local c = plan.centre
	for _ = 1, PICNIC_TRIES do
		if #out >= ParkDresser.PICNICS then
			break
		end
		local p = c + Vector3.new(rng:NextNumber(-plan.half.X, plan.half.X), 0, rng:NextNumber(-plan.half.Z, plan.half.Z))
		local ok = ParkDresser.inPark(plan, p, 20) and ParkDresser.clearOfPaths(plan, p, PICNIC_GAP) and ParkDresser.isClear(p, PICNIC_GAP)
		ok = ok and (flat(p) - flat(plan.pond.centre)).Magnitude > plan.pond.radius + RIM_W + PICNIC_GAP
		ok = ok and (flat(p) - flat(plan.plaza.centre)).Magnitude > plan.plaza.radius + PICNIC_GAP
		local pg = plan.playground
		ok = ok and (math.abs(p.X - pg.centre.X) > pg.size.X / 2 + PICNIC_GAP or math.abs(p.Z - pg.centre.Z) > pg.size.Z / 2 + PICNIC_GAP)
		for _, t in trees do
			if not ok then
				break
			end
			ok = (flat(p) - flat(t)).Magnitude > PICNIC_GAP + 2
		end
		for _, q in out do
			if not ok then
				break
			end
			ok = (flat(p) - q.Position).Magnitude > 24
		end
		if ok then
			table.insert(out, CFrame.new(flat(p)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end
	return out
end

local PICNIC_TOPS = { Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 190), Color3.fromRGB(240, 200, 70), Color3.fromRGB(80, 150, 90), Color3.fromRGB(240, 240, 235) }
local PICNIC_SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }
local BLANKETS = { Color3.fromRGB(170, 40, 50), Color3.fromRGB(40, 90, 150), Color3.fromRGB(60, 120, 70) }

local function buildPicnic(parent: Instance, cf: CFrame, rng: Random)
	local m = model("Picnic", parent)
	m:SetAttribute("Decor", true)
	local function piece(name: string, size: Vector3, at: CFrame, colour: Color3, material: Enum.Material?, ball: boolean?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = at
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = m
		return p
	end
	-- lawn top is Y.LAWN (the grass slab); the blanket sits 0.05 into it
	local base = cf * CFrame.new(0, Y.LAWN, 0)
	piece("Blanket", Vector3.new(6, 0.12, 4.5), base * CFrame.new(0, 0.01, 0), BLANKETS[rng:NextInteger(1, #BLANKETS)], Enum.Material.Fabric)
	piece("Basket", Vector3.new(1.4, 1, 1), base * CFrame.new(0, 0.55, 0), Color3.fromRGB(170, 130, 80), Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		-- sitting, legs toward the basket, facing each other along local X
		local seat = base * CFrame.new(side * 2.1, 0.07, 0) * CFrame.Angles(0, side * math.pi / 2, 0)
		piece("Legs", Vector3.new(1.2, 0.5, 1.4), seat * CFrame.new(0, 0.25, -0.55), Color3.fromRGB(40, 44, 60))
		piece("Torso", Vector3.new(1.6, 1.8, 0.8), seat * CFrame.new(0, 1.4, 0.2), PICNIC_TOPS[rng:NextInteger(1, #PICNIC_TOPS)])
		local head = piece("Head", Vector3.one, seat * CFrame.new(0, 2.8, 0.2), PICNIC_SKIN[rng:NextInteger(1, #PICNIC_SKIN)], nil, true)
		local face = Instance.new("Decal")
		face.Name = "Face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = head
	end
end

function ParkDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "park: no town"
	end
	local old = town:FindFirstChild("Park")
	if old then
		old:Destroy()
	end
	local plan = ParkDresser.plan()
	if not plan then
		return "park: no park lawn in TownLayout"
	end
	local root = Instance.new("Model")
	root.Name = "Park"
	local rng = Random.new(1884)

	buildPaths(model("Paths", root), plan)
	buildPond(model("Pond", root), plan.pond, rng)
	buildPlayground(model("Playground", root), plan.playground)
	-- steps face the south spine (towards the main entrance)
	buildBandstand(model("Bandstand", root), plan.bandstand, Vector3.new(0, 0, 1))
	removeGreyboxBandstand(town, plan)

	local trees = model("Trees", root)
	local treeSpots = ParkDresser.treePositions(plan, rng)
	for _, p in treeSpots do
		buildTree(trees, p, rng)
	end
	-- X140: picnics on the open lawn
	local picnics = model("Picnics", root)
	for _, cf in ParkDresser.picnicSpots(plan, treeSpots, Random.new(1940)) do
		buildPicnic(picnics, cf, rng)
	end

	local furniture = model("Furniture", root)
	for _, cf in plan.benches do
		KitPlacer.place("UKSP__ParkBenches__ParkBench01", cf, furniture, {
			fallbackSize = Vector3.new(6, 3, 2),
			fallbackColor = TIMBER,
			fallbackMaterial = Enum.Material.Wood,
		})
	end
	for _, p in plan.bins do
		KitPlacer.place("UKSP__LitterBin__LitterBin", CFrame.new(p), furniture, {
			fallbackSize = Vector3.new(2, 3.5, 2),
			fallbackColor = IRON,
		})
	end
	for _, cf in plan.lamps do
		kitLamp(cf, furniture)
	end
	buildSign(furniture, plan)

	root.Parent = town
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	if parts > PART_BUDGET then
		warn(("ParkDresser: %d parts is over the %d budget"):format(parts, PART_BUDGET))
	end
	return ("park: %d parts, %d trees"):format(parts, #treeSpots)
end

return ParkDresser
