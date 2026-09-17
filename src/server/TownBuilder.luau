--!strict
-- Rivermere greybox (backlog C2.1): turns Shared.TownLayout into walkable,
-- anchored primitive geometry under workspace.Town and carves the River Lune
-- into the flat grass terrain that Scenery.setupTown lays down. Reads only
-- TownLayout (no Assets / KitPlacer yet); plot sites belong to PlotService.
--
-- workspace.Town (Folder, rebuilt from scratch by build())
--   Roads      carriageways, bend joints, pavements, roundabouts, market square
--   River      empty marker model; the river itself is terrain (Mud banks, Air, Water)
--   Bridges    one Model per bridge: road/foot decks with parapets, the rail viaduct
--   Rail       ballast bed, rails, viaduct approach ramps, the station
--   Districts  Folder, one Model per district of building volumes
--   Landmarks  church tower + spire (bridges already stand in for the other two)
--   BusStops   one Model per stop, attribute BusStop = stop name
--
-- Y levels (studs; terrain surface is y = 0). Every horizontal top differs so
-- nothing overlapping shares a face plane (no z-fighting):
--   -18 .. -2   river bank / bed Mud (same band as the grass fill)
--   -14         river bed (Air carved from -14 up to +4)
--   -4          top of the Water fill (renders ~2 higher, about -2)
--   -16         foot of bridge and viaduct piers
--   0.190       roundabout disc top
--   0.200 ring / 0.210 main / 0.220 residential / 0.230 lane carriageway tops;
--               odd segments of a polyline +0.004, bend joint discs -0.004
--   0.250       market square top
--   0.300       flat district pieces (lawns, pitches, car park, marina)
--   0.450       pavement (kerb) top
--   0.596/0.600/0.604 rail joint / ballast bed tops (odd/even segments), rails +0.5
--   0.800       roundabout island top
--   road top + 0.5  road / foot bridge deck top at the ends (deck 2 thick), footways +0.25,
--               parapets +3.5; road bridges climb TownLayout.BRIDGE_RISE (6) over their ramps
--   3           station platform top; canopy 11..11.6
--   22          viaduct deck top (19..22), rails 22..22.5, parapets +3
--   h-1 .. h    district building body / roof cap (h from the layout box)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local TownBuilder = {}

local Y = {
	MUD_BOTTOM = -18,
	MUD_TOP = -2,
	RIVER_BED = -14,
	RIVER_AIR_TOP = 4,
	WATER_TOP = -4,
	PIER_FOOT = -16,
	ROUNDABOUT = 0.19,
	ROAD = { ring = 0.20, main = 0.21, residential = 0.22, lane = 0.23 } :: { [string]: number },
	STEP = 0.004,
	SQUARE = 0.25,
	FLAT = 0.3,
	PAVEMENT = 0.45,
	RAIL_BED = 0.6,
	ISLAND = 0.8,
	DECK_ABOVE_ROAD = 0.5,
	PLATFORM = 3,
	CANOPY = 11,
	VIADUCT = 22,
}
TownBuilder.Y = Y

local PAVEMENT_WIDTH = TownLayout.PAVEMENT_WIDTH
local RIVER_BANK = 12 -- Mud strip each side of the water
local RIVER_END_EXTENSION = 400 -- run the river off the grass edge instead of stopping in a pit
local DECK_THICK = 2
local PARAPET_THICK = 1.5
local PARAPET_HEIGHT = 3.5
local FOOTWAY_HEIGHT = 0.25
local VIADUCT_THICK = 3
local RAMP_MAX = 180 -- viaduct approach embankment length
local RAIL_OFFSETS = { -5.95, -2.05, 2.05, 5.95 } -- twin track, two rails each
local PAVE_CELL = 2 -- pavement clipping resolution
local PAVE_MIN_RUN = 3
local OVERLAP_TOL = 0.05

local COLOURS = {
	asphalt = Color3.fromRGB(78, 80, 84),
	pavement = Color3.fromRGB(186, 184, 178),
	square = Color3.fromRGB(196, 186, 168),
	island = Color3.fromRGB(96, 140, 80),
	ballast = Color3.fromRGB(122, 114, 106),
	rail = Color3.fromRGB(150, 150, 155),
	stone = Color3.fromRGB(176, 166, 148),
	brick = Color3.fromRGB(150, 96, 78),
	concrete = Color3.fromRGB(190, 190, 186),
	houses = Color3.fromRGB(226, 208, 178),
	shops = Color3.fromRGB(204, 146, 126),
	industrial = Color3.fromRGB(172, 184, 198),
	civic = Color3.fromRGB(240, 230, 200),
	lawn = Color3.fromRGB(104, 150, 84),
	pitch3G = Color3.fromRGB(70, 128, 76),
	carPark = Color3.fromRGB(92, 94, 98),
	marina = Color3.fromRGB(86, 136, 176),
	station = Color3.fromRGB(206, 172, 140),
	shelter = Color3.fromRGB(60, 70, 80),
	sign = Color3.fromRGB(200, 40, 40),
}

local HOUSES = { ["terraced row"] = true, semis = true, flats = true, ["waterfront flats"] = true }
local SHOPS = {
	["shops with flats"] = true,
	shops = true,
	pub = true,
	supermarket = true,
	["corner shop"] = true,
	["pub and cafes"] = true,
	["park cafe"] = true,
}
local INDUSTRIAL = { warehouse = true, ["trade counter"] = true, workshop = true, ["builders yard"] = true }

-- --------------------------------------------------------------- pure helpers

-- Centre CFrame of the XZ segment a -> b at height y, LookVector along the
-- segment (so a Part sized (width, h, length) lies on it), plus its length.
-- Input Y values are ignored.
function TownBuilder.segmentCFrame(a: Vector3, b: Vector3, y: number): (CFrame, number)
	local dx, dz = b.X - a.X, b.Z - a.Z
	local length = math.sqrt(dx * dx + dz * dz)
	local mid = Vector3.new((a.X + b.X) / 2, y, (a.Z + b.Z) / 2)
	if length < 1e-6 then
		return CFrame.new(mid), 0
	end
	return CFrame.lookAt(mid, mid + Vector3.new(dx, 0, dz)), length
end

-- Carriageway top for a road kind.
function TownBuilder.roadTop(kind: string): number
	return Y.ROAD[kind] or Y.ROAD.lane
end

-- Runs of unblocked cells: { {startDistance, endDistance} }, dropping runs
-- shorter than minLength.
function TownBuilder.freeRuns(blocked: { boolean }, cellLength: number, minLength: number): { { number } }
	local runs: { { number } } = {}
	local start: number? = nil
	for i = 1, #blocked + 1 do
		local free = i <= #blocked and not blocked[i]
		if free and start == nil then
			start = i
		elseif not free and start ~= nil then
			local s0, s1 = (start - 1) * cellLength, (i - 1) * cellLength
			if s1 - s0 >= minLength - 1e-6 then
				table.insert(runs, { s0, s1 })
			end
			start = nil
		end
	end
	return runs
end

-- Oriented rectangle in XZ: centre, unit long axis (ux, uz), half length, half width.
export type Rect = { cx: number, cz: number, ux: number, uz: number, hl: number, hw: number, br: number }

function TownBuilder.rect(cx: number, cz: number, ux: number, uz: number, hl: number, hw: number): Rect
	return { cx = cx, cz = cz, ux = ux, uz = uz, hl = hl, hw = hw, br = math.sqrt(hl * hl + hw * hw) }
end

function TownBuilder.segmentRect(a: Vector3, b: Vector3, halfWidth: number): Rect?
	local dx, dz = b.X - a.X, b.Z - a.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return nil
	end
	return TownBuilder.rect((a.X + b.X) / 2, (a.Z + b.Z) / 2, dx / length, dz / length, length / 2, halfWidth)
end

local function radiusOn(r: Rect, ax: number, az: number): number
	return r.hl * math.abs(r.ux * ax + r.uz * az) + r.hw * math.abs(-r.uz * ax + r.ux * az)
end

-- True if the rectangles overlap by more than a hair (touching counts as apart).
function TownBuilder.rectsOverlap(p: Rect, q: Rect): boolean
	local dx, dz = q.cx - p.cx, q.cz - p.cz
	local reach = p.br + q.br
	if dx * dx + dz * dz >= reach * reach then
		return false
	end
	local axes = { p.ux, p.uz, -p.uz, p.ux, q.ux, q.uz, -q.uz, q.ux }
	for i = 1, 7, 2 do
		local ax, az = axes[i], axes[i + 1]
		if math.abs(dx * ax + dz * az) >= radiusOn(p, ax, az) + radiusOn(q, ax, az) - OVERLAP_TOL then
			return false
		end
	end
	return true
end

function TownBuilder.circleOverlapsRect(cx: number, cz: number, radius: number, q: Rect): boolean
	local dx, dz = cx - q.cx, cz - q.cz
	local reach = radius + q.br
	if dx * dx + dz * dz >= reach * reach then
		return false
	end
	local lx = dx * q.ux + dz * q.uz
	local lz = -dx * q.uz + dz * q.ux
	local nx = lx - math.clamp(lx, -q.hl, q.hl)
	local nz = lz - math.clamp(lz, -q.hw, q.hw)
	local limit = radius - OVERLAP_TOL
	return limit > 0 and nx * nx + nz * nz < limit * limit
end

local function near(p: Vector3, q: Vector3, tolerance: number): boolean
	local dx, dz = p.X - q.X, p.Z - q.Z
	return dx * dx + dz * dz <= tolerance * tolerance
end

-- ------------------------------------------------------------ instance helpers

local function part(props: { [string]: any }, className: string?): BasePart
	local p = (Instance.new :: any)(className or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape ~= nil then
		(p :: any).Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Flat cylinder with its top at `top`.
local function disc(parent: Instance, name: string, centre: Vector3, radius: number, top: number, height: number, color: Color3, material: Enum.Material): BasePart
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(centre.X, top - height / 2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		CastShadow = false,
		Parent = parent,
	})
end

-- Rails along `cf` (positioned on the surface they sit on, LookVector along the track).
local function addRails(parent: Instance, cf: CFrame, length: number)
	for _, lateral in RAIL_OFFSETS do
		part({
			Name = "Rail",
			Size = Vector3.new(0.4, 0.5, length),
			CFrame = cf * CFrame.new(lateral, 0.25, 0),
			Color = COLOURS.rail,
			Material = Enum.Material.Metal,
			CastShadow = false,
			Parent = parent,
		})
	end
end

-- ------------------------------------------------------------------- river

local function buildRiver()
	local terrain = workspace.Terrain
	local river = TownLayout.RIVER
	local points = table.clone(river.points)
	local n = #points
	if n < 2 then
		return
	end
	local startDir = Vector3.new(points[1].X - points[2].X, 0, points[1].Z - points[2].Z).Unit
	local endDir = Vector3.new(points[n].X - points[n - 1].X, 0, points[n].Z - points[n - 1].Z).Unit
	points[1] = points[1] + startDir * RIVER_END_EXTENSION
	points[n] = points[n] + endDir * RIVER_END_EXTENSION

	-- phases run over the whole river so a later segment never refills an
	-- earlier segment's channel: banks and bed, then the channel, then water
	local phases = {
		{ material = Enum.Material.Mud, width = river.width + RIVER_BANK * 2, bottom = Y.MUD_BOTTOM, top = Y.MUD_TOP },
		{ material = Enum.Material.Air, width = river.width, bottom = Y.RIVER_BED, top = Y.RIVER_AIR_TOP },
		{ material = Enum.Material.Water, width = river.width, bottom = Y.RIVER_BED, top = Y.WATER_TOP },
	}
	for _, phase in phases do
		local height = phase.top - phase.bottom
		local cy = (phase.top + phase.bottom) / 2
		for i = 1, n - 1 do
			local cf, length = TownBuilder.segmentCFrame(points[i], points[i + 1], cy)
			if length > 0 then
				terrain:FillBlock(cf, Vector3.new(phase.width, height, length), phase.material)
			end
		end
		for i = 2, n - 1 do
			terrain:FillCylinder(CFrame.new(points[i].X, cy, points[i].Z), height, phase.width / 2, phase.material)
		end
	end
end

-- ------------------------------------------------------------------- roads

local function nearRoundabout(p: Vector3): boolean
	for _, r in TownLayout.ROUNDABOUTS do
		if near(p, r.centre, 1) then
			return true
		end
	end
	return false
end

local function interiorIndices(points: { Vector3 }): { number }
	local out = {}
	local n = #points
	if n > 2 and near(points[1], points[n], 0.5) then
		table.insert(out, 1)
	end
	for i = 2, n - 1 do
		table.insert(out, i)
	end
	return out
end

type Blockers = { rects: { Rect }, circles: { { number } }, roadRects: { [string]: { [number]: Rect } } }

-- Everything a pavement must not be laid over: carriageways, bend joints,
-- roundabouts, the square, bridge decks and the railway.
local function pavementBlockers(): Blockers
	local rects: { Rect } = {}
	local circles: { { number } } = {}
	local roadRects: { [string]: { [number]: Rect } } = {}
	for _, road in TownLayout.ROADS do
		local half = road.width / 2
		local own: { [number]: Rect } = {}
		roadRects[road.name] = own
		for i = 1, #road.points - 1 do
			local r = TownBuilder.segmentRect(road.points[i], road.points[i + 1], half)
			if r then
				table.insert(rects, r)
				own[i] = r
			end
		end
		for _, i in interiorIndices(road.points) do
			table.insert(circles, { road.points[i].X, road.points[i].Z, half })
		end
	end
	for _, r in TownLayout.ROUNDABOUTS do
		table.insert(circles, { r.centre.X, r.centre.Z, r.radius })
	end
	table.insert(circles, { TownLayout.SQUARE.centre.X, TownLayout.SQUARE.centre.Z, TownLayout.SQUARE.radius })
	for _, bridge in TownLayout.BRIDGES do
		local deckWidth = if bridge.kind == "road" then bridge.width + 2 * (PAVEMENT_WIDTH + PARAPET_THICK) else bridge.width + 4
		local r = TownBuilder.segmentRect(bridge.from, bridge.to, deckWidth / 2)
		if r then
			table.insert(rects, r)
		end
	end
	local rail = TownLayout.RAIL
	for i = 1, #rail.points - 1 do
		local r = TownBuilder.segmentRect(rail.points[i], rail.points[i + 1], rail.width / 2 + 1)
		if r then
			table.insert(rects, r)
		end
	end
	for i = 2, #rail.points - 1 do
		table.insert(circles, { rail.points[i].X, rail.points[i].Z, rail.width / 2 + 1 })
	end
	return { rects = rects, circles = circles, roadRects = roadRects }
end

local function cellBlocked(cell: Rect, blockers: Blockers, own: Rect?, accepted: { Rect }): boolean
	for _, r in blockers.rects do
		if r ~= own and TownBuilder.rectsOverlap(cell, r) then
			return true
		end
	end
	for _, c in blockers.circles do
		if TownBuilder.circleOverlapsRect(c[1], c[2], c[3], cell) then
			return true
		end
	end
	for _, r in accepted do
		if TownBuilder.rectsOverlap(cell, r) then
			return true
		end
	end
	return false
end

local function buildPavements(parent: Instance, road: TownLayout.Road, blockers: Blockers, accepted: { Rect })
	local half = road.width / 2
	local ownRects = blockers.roadRects[road.name] or {}
	for i = 1, #road.points - 1 do
		local a = road.points[i]
		local own = ownRects[i]
		if not own then
			continue
		end
		local ux, uz = own.ux, own.uz
		local rx, rz = -uz, ux
		local length = own.hl * 2
		local count = math.max(1, math.floor(length / PAVE_CELL + 0.5))
		local cellLength = length / count
		for _, side in { -1, 1 } do
			local lateral = side * (half + PAVEMENT_WIDTH / 2)
			local ox, oz = a.X + rx * lateral, a.Z + rz * lateral
			local blocked: { boolean } = table.create(count, false)
			for k = 1, count do
				local s = (k - 0.5) * cellLength
				local cell = TownBuilder.rect(ox + ux * s, oz + uz * s, ux, uz, cellLength / 2, PAVEMENT_WIDTH / 2)
				blocked[k] = cellBlocked(cell, blockers, own, accepted)
			end
			for _, run in TownBuilder.freeRuns(blocked, cellLength, PAVE_MIN_RUN) do
				local s = (run[1] + run[2]) / 2
				local runLength = run[2] - run[1]
				local cx, cz = ox + ux * s, oz + uz * s
				local centre = Vector3.new(cx, Y.PAVEMENT / 2, cz)
				part({
					Name = "Pavement",
					Size = Vector3.new(PAVEMENT_WIDTH, Y.PAVEMENT, runLength),
					CFrame = CFrame.lookAt(centre, centre + Vector3.new(ux, 0, uz)),
					Color = COLOURS.pavement,
					Material = Enum.Material.Concrete,
					CastShadow = false,
					Parent = parent,
				})
				table.insert(accepted, TownBuilder.rect(cx, cz, ux, uz, runLength / 2, PAVEMENT_WIDTH / 2))
			end
		end
	end
end

local function buildRoads(parent: Instance)
	for _, r in TownLayout.ROUNDABOUTS do
		local m = model(r.name, parent)
		disc(m, "Roundabout", r.centre, r.radius, Y.ROUNDABOUT, Y.ROUNDABOUT, COLOURS.asphalt, Enum.Material.Asphalt)
		disc(m, "Island", r.centre, r.radius * 0.35, Y.ISLAND, Y.ISLAND, COLOURS.island, Enum.Material.Grass)
	end

	local square = TownLayout.SQUARE
	disc(parent, square.name, square.centre, square.radius, Y.SQUARE, Y.SQUARE, COLOURS.square, Enum.Material.Pavement)

	local blockers = pavementBlockers()
	local accepted: { Rect } = {}
	for _, road in TownLayout.ROADS do
		local m = model(road.name, parent)
		local top = TownBuilder.roadTop(road.kind)
		for i = 1, #road.points - 1 do
			local segTop = top + (if i % 2 == 0 then Y.STEP else 0)
			local cf, length = TownBuilder.segmentCFrame(road.points[i], road.points[i + 1], segTop / 2)
			if length > 0 then
				part({
					Name = "Road",
					Size = Vector3.new(road.width, segTop, length),
					CFrame = cf,
					Color = COLOURS.asphalt,
					Material = Enum.Material.Asphalt,
					CastShadow = false,
					Parent = m,
				})
			end
		end
		-- bend joints sit just under the segments so they only show in the gaps
		for _, i in interiorIndices(road.points) do
			local p = road.points[i]
			if not nearRoundabout(p) then
				disc(m, "Joint", p, road.width / 2, top - Y.STEP, top - Y.STEP, COLOURS.asphalt, Enum.Material.Asphalt)
			end
		end
		if road.kind ~= "lane" then
			buildPavements(m, road, blockers, accepted)
		end
	end
end

-- ----------------------------------------------------------------- bridges

local function roadTopNear(p: Vector3): number
	local best, top = math.huge, Y.ROAD.lane
	for _, road in TownLayout.ROADS do
		local d = TownLayout.distanceToPolyline(p, road.points)
		if d < best then
			best, top = d, TownBuilder.roadTop(road.kind)
		end
	end
	return top
end

local function buildPiers(parent: Instance, from: Vector3, to: Vector3, count: number, deckBottom: number, width: number, depth: number, material: Enum.Material, color: Color3)
	local height = deckBottom - Y.PIER_FOOT
	for k = 1, count do
		local t = k / (count + 1)
		local p = from:Lerp(to, t)
		local cf = TownBuilder.segmentCFrame(from, to, (deckBottom + Y.PIER_FOOT) / 2)
		part({
			Name = "Pier",
			Size = Vector3.new(width, height, depth),
			CFrame = CFrame.new(p.X, cf.Position.Y, p.Z) * cf.Rotation,
			Color = color,
			Material = material,
			Parent = parent,
		})
	end
end

local function buildViaduct(m: Model, bridge: TownLayout.Bridge)
	local deckWidth = bridge.width + 4
	local cf, length = TownBuilder.segmentCFrame(bridge.from, bridge.to, Y.VIADUCT - VIADUCT_THICK / 2)
	if length <= 0 then
		return
	end
	part({
		Name = "Deck",
		Size = Vector3.new(deckWidth, VIADUCT_THICK, length),
		CFrame = cf,
		Color = COLOURS.stone,
		Material = Enum.Material.Slate,
		Parent = m,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Parapet",
			Size = Vector3.new(1, 3, length),
			CFrame = cf * CFrame.new(side * (deckWidth / 2 - 0.5), VIADUCT_THICK / 2 + 1.5, 0),
			Color = COLOURS.brick,
			Material = Enum.Material.Brick,
			Parent = m,
		})
	end
	local piers = math.clamp(math.floor(length / 50 + 0.5), 4, 6)
	buildPiers(m, bridge.from, bridge.to, piers, Y.VIADUCT - VIADUCT_THICK, deckWidth - 2, 10, Enum.Material.Brick, COLOURS.stone)
	addRails(m, cf * CFrame.new(0, VIADUCT_THICK / 2, 0), length)
end

local function buildBridge(parent: Instance, bridge: TownLayout.Bridge)
	local m = model(bridge.name, parent)
	if bridge.kind == "rail" then
		buildViaduct(m, bridge)
		return
	end
	local isRoad = bridge.kind == "road"
	local roadTop = if isRoad then roadTopNear(bridge.from:Lerp(bridge.to, 0.5)) else Y.ROAD.lane
	local deckTop = roadTop + Y.DECK_ABOVE_ROAD
	local deckWidth = if isRoad then bridge.width + 2 * (PAVEMENT_WIDTH + PARAPET_THICK) else bridge.width + 2 * PARAPET_THICK
	local length = TownLayout.bridgeLength(bridge)
	if length <= 0 then
		return
	end
	local dir = Vector3.new(bridge.to.X - bridge.from.X, 0, bridge.to.Z - bridge.from.Z) / length
	-- one straight piece per section (X31): up-ramp "DeckRamp", level "Deck",
	-- down-ramp "DeckRamp". `top` is the deck's top surface line; everything
	-- sits on it in the piece's own (pitched) frame.
	for _, section in TownLayout.bridgeSections(bridge) do
		local a = bridge.from + dir * section.s0 + Vector3.new(0, deckTop + section.rise0, 0)
		local b = bridge.from + dir * section.s1 + Vector3.new(0, deckTop + section.rise1, 0)
		local pieceLength = (b - a).Magnitude
		if pieceLength <= 0.01 then
			continue
		end
		local level = section.rise0 == section.rise1
		-- ramps overlap the level piece a little so the kink shows no gap
		local overlap = if level then 0 else 0.3
		local top = CFrame.lookAt((a + b) / 2, b)
		local size = pieceLength + overlap
		part({
			Name = if level then "Deck" else "DeckRamp",
			Size = Vector3.new(deckWidth, DECK_THICK, size),
			CFrame = top * CFrame.new(0, -DECK_THICK / 2, 0),
			Color = if isRoad then COLOURS.asphalt else COLOURS.concrete,
			Material = if isRoad then Enum.Material.Asphalt else Enum.Material.Concrete,
			CastShadow = false,
			Parent = m,
		})
		for _, side in { -1, 1 } do
			part({
				Name = "Parapet",
				Size = Vector3.new(PARAPET_THICK, PARAPET_HEIGHT, size),
				CFrame = top * CFrame.new(side * (deckWidth / 2 - PARAPET_THICK / 2), PARAPET_HEIGHT / 2, 0),
				Color = if isRoad then COLOURS.brick else COLOURS.concrete,
				Material = if isRoad then Enum.Material.Brick else Enum.Material.Concrete,
				Parent = m,
			})
			if isRoad then
				part({
					Name = "Footway",
					Size = Vector3.new(PAVEMENT_WIDTH, FOOTWAY_HEIGHT, size),
					CFrame = top * CFrame.new(side * (deckWidth / 2 - PARAPET_THICK - PAVEMENT_WIDTH / 2), FOOTWAY_HEIGHT / 2, 0),
					Color = COLOURS.pavement,
					Material = Enum.Material.Concrete,
					CastShadow = false,
					Parent = m,
				})
			end
		end
	end
	-- the piers stand under the level middle (at 1/3 and 2/3 of the length)
	local pierRise = TownLayout.bridgeRise(bridge, length / 3)
	buildPiers(m, bridge.from, bridge.to, 2, deckTop + pierRise - DECK_THICK, deckWidth - 4, 8, Enum.Material.Slate, COLOURS.stone)
end

-- -------------------------------------------------------------------- rail

local function railBridgeEnd(p: Vector3): TownLayout.Bridge?
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind == "rail" and (near(p, bridge.from, 2) or near(p, bridge.to, 2)) then
			return bridge
		end
	end
	return nil
end

local function flatBed(parent: Instance, a: Vector3, b: Vector3, top: number)
	local width = TownLayout.RAIL.width
	local cf, length = TownBuilder.segmentCFrame(a, b, top / 2)
	if length <= 0.5 then
		return
	end
	part({
		Name = "Ballast",
		Size = Vector3.new(width, top, length),
		CFrame = cf,
		Color = COLOURS.ballast,
		Material = Enum.Material.Pebble,
		CastShadow = false,
		Parent = parent,
	})
	addRails(parent, cf * CFrame.new(0, top / 2, 0), length)
end

-- Embankment from ground at g up to the viaduct deck at e.
local function ramp(parent: Instance, g: Vector3, e: Vector3)
	local dx, dz = g.X - e.X, g.Z - e.Z
	local length = math.sqrt(dx * dx + dz * dz)
	local rampLength = math.min(length, RAMP_MAX)
	local s = Vector3.new(e.X + dx / length * rampLength, 0, e.Z + dz / length * rampLength)
	if length - rampLength > 0.5 then
		flatBed(parent, g, s, Y.RAIL_BED)
	end
	local h = Y.VIADUCT
	local mid = Vector3.new((s.X + e.X) / 2, h / 2, (s.Z + e.Z) / 2)
	-- WedgePart: tall face at local +Z, slope falls to local -Z, so look toward the low end
	part({
		Name = "Embankment",
		Size = Vector3.new(TownLayout.RAIL.width + 2, h, rampLength),
		CFrame = CFrame.lookAt(mid, Vector3.new(s.X, h / 2, s.Z)),
		Color = COLOURS.ballast,
		Material = Enum.Material.Slate,
		Parent = parent,
	}, "WedgePart")
	local low = Vector3.new(s.X, 0, s.Z)
	local high = Vector3.new(e.X, h, e.Z)
	addRails(parent, CFrame.lookAt((low + high) / 2, high), (high - low).Magnitude)
end

local function buildStation(parent: Instance)
	local station = TownLayout.RAIL.station
	local m = model(station.name, parent)
	local base = CFrame.new(station.centre.X, 0, station.centre.Z) * CFrame.Angles(0, math.rad(station.yaw), 0)
	local sx, sh, sz = station.size.X, station.size.Y, station.size.Z
	part({
		Name = "Station Building",
		Size = Vector3.new(sx, sh - 1, sz),
		CFrame = base * CFrame.new(0, (sh - 1) / 2, 0),
		Color = COLOURS.station,
		Parent = m,
	})
	part({
		Name = "Station Building roof",
		Size = Vector3.new(sx, 1, sz),
		CFrame = base * CFrame.new(0, sh - 0.5, 0),
		Color = COLOURS.station:Lerp(Color3.new(0, 0, 0), 0.2),
		Parent = m,
	})

	local railPoints = TownLayout.RAIL.points
	local minusFace = base * Vector3.new(0, 0, -sz / 2)
	local plusFace = base * Vector3.new(0, 0, sz / 2)
	local minusDist = TownLayout.distanceToPolyline(minusFace, railPoints)
	local plusDist = TownLayout.distanceToPolyline(plusFace, railPoints)
	local side = if minusDist <= plusDist then -1 else 1
	local faceDist = math.min(minusDist, plusDist)
	local depth = math.clamp(faceDist - TownLayout.RAIL.width / 2 - 0.5, 6, 20)
	local z = side * (sz / 2 + depth / 2)
	part({
		Name = "Platform",
		Size = Vector3.new(sx, Y.PLATFORM, depth),
		CFrame = base * CFrame.new(0, Y.PLATFORM / 2, z),
		Color = COLOURS.concrete,
		Material = Enum.Material.Concrete,
		Parent = m,
	})
	if sh > Y.CANOPY + 1 then
		part({
			Name = "Canopy",
			Size = Vector3.new(sx * 0.8, 0.6, depth),
			CFrame = base * CFrame.new(0, Y.CANOPY + 0.3, z),
			Color = COLOURS.shelter,
			Parent = m,
		})
		for k = 0, 4 do
			local x = -sx * 0.35 + k * (sx * 0.7 / 4)
			part({
				Name = "Canopy Post",
				Size = Vector3.new(0.6, Y.CANOPY - Y.PLATFORM, 0.6),
				CFrame = base * CFrame.new(x, (Y.CANOPY + Y.PLATFORM) / 2, side * (sz / 2 + depth - 1.5)),
				Color = COLOURS.shelter,
				Material = Enum.Material.Metal,
				Parent = m,
			})
		end
	end
end

local function buildRail(parent: Instance)
	local points = TownLayout.RAIL.points
	local track = model("Track", parent)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local aBridge, bBridge = railBridgeEnd(a), railBridgeEnd(b)
		if aBridge and aBridge == bBridge then
			continue -- the viaduct carries this span
		elseif bBridge then
			ramp(track, a, b)
		elseif aBridge then
			ramp(track, b, a)
		else
			flatBed(track, a, b, Y.RAIL_BED + (if i % 2 == 0 then Y.STEP else 0))
		end
	end
	for _, i in interiorIndices(points) do
		local p = points[i]
		if not railBridgeEnd(p) then
			disc(track, "Joint", p, TownLayout.RAIL.width / 2, Y.RAIL_BED - Y.STEP, Y.RAIL_BED - Y.STEP, COLOURS.ballast, Enum.Material.Pebble)
		end
	end
	buildStation(parent)
end

-- --------------------------------------------------------------- districts

-- colour, material, flat (a ground piece rather than a building)
local function styleFor(use: string, height: number): (Color3, Enum.Material, boolean)
	if use == "park lawn" or use == "grass pitch" then
		return COLOURS.lawn, Enum.Material.Grass, true
	elseif use == "3G pitch" then
		return COLOURS.pitch3G, Enum.Material.SmoothPlastic, true
	elseif use == "station car park" then
		return COLOURS.carPark, Enum.Material.Asphalt, true
	elseif use == "marina" then
		return COLOURS.marina, Enum.Material.SmoothPlastic, true
	elseif HOUSES[use] then
		return COLOURS.houses, Enum.Material.SmoothPlastic, false
	elseif SHOPS[use] then
		return COLOURS.shops, Enum.Material.SmoothPlastic, false
	elseif INDUSTRIAL[use] then
		return COLOURS.industrial, Enum.Material.SmoothPlastic, false
	end
	local color = if height <= 2 then COLOURS.concrete else COLOURS.civic
	return color, Enum.Material.SmoothPlastic, height <= 2
end

local function buildBlock(parent: Instance, block: TownLayout.Box)
	local color, material, flat = styleFor(block.use, block.size.Y)
	local base = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
	local sx, sh, sz = block.size.X, block.size.Y, block.size.Z
	if flat then
		local h = math.min(sh, Y.FLAT)
		part({
			Name = block.use,
			Size = Vector3.new(sx, h, sz),
			CFrame = base * CFrame.new(0, h / 2, 0),
			Color = color,
			Material = material,
			CastShadow = false,
			Parent = parent,
		})
		return
	end
	part({
		Name = block.use,
		Size = Vector3.new(sx, sh - 1, sz),
		CFrame = base * CFrame.new(0, (sh - 1) / 2, 0),
		Color = color,
		Material = material,
		Parent = parent,
	})
	part({
		Name = block.use .. " roof",
		Size = Vector3.new(sx, 1, sz),
		CFrame = base * CFrame.new(0, sh - 0.5, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.18),
		Material = material,
		Parent = parent,
	})
end

local function buildDistricts(parent: Instance)
	for _, district in TownLayout.DISTRICTS do
		local m = model(district.name, parent)
		m:SetAttribute("DistrictKind", district.kind)
		for _, block in district.blocks do
			buildBlock(m, block)
		end
	end
end

-- --------------------------------------------------------------- landmarks

local function churchBlockAt(p: Vector3): TownLayout.Box?
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use == "church" and math.abs(block.centre.X - p.X) <= block.size.X / 2 and math.abs(block.centre.Z - p.Z) <= block.size.Z / 2 then
				return block
			end
		end
	end
	return nil
end

local function buildChurch(parent: Instance, landmark: TownLayout.Landmark)
	local m = model(landmark.name, parent)
	local p = landmark.position
	local body = churchBlockAt(p)
	local bodyTop: number
	if body then
		bodyTop = body.size.Y -- the district builds the nave
	else
		local nave = { centre = Vector3.new(p.X, 18, p.Z), size = Vector3.new(30, 36, 60), yaw = 0, use = "church" }
		buildBlock(m, nave)
		bodyTop = nave.size.Y
	end
	local towerTop = math.min(math.max(bodyTop + 20, landmark.height * 0.45), landmark.height - 10)
	part({
		Name = "Tower",
		Size = Vector3.new(18, towerTop, 18),
		CFrame = CFrame.new(p.X, towerTop / 2, p.Z),
		Color = COLOURS.stone,
		Material = Enum.Material.Slate,
		Parent = m,
	})
	-- tapering stack of tiers reads as a spire from across town
	local tiers = 7
	local tierHeight = (landmark.height - towerTop) / tiers
	for k = 1, tiers do
		local width = 14 * (1 - (k - 1) / tiers)
		local bottom = towerTop + (k - 1) * tierHeight
		part({
			Name = "Spire",
			Size = Vector3.new(width, tierHeight, width),
			CFrame = CFrame.new(p.X, bottom + tierHeight / 2, p.Z),
			Color = COLOURS.stone:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.Slate,
			Parent = m,
		})
	end
end

local function buildLandmarks(parent: Instance)
	for _, landmark in TownLayout.LANDMARKS do
		local isBridge = false
		for _, bridge in TownLayout.BRIDGES do
			if bridge.name == landmark.name then
				isBridge = true
			end
		end
		if isBridge then
			continue -- the bridge builder already made it
		elseif landmark.name:find("Church") then
			buildChurch(parent, landmark)
		else
			local m = model(landmark.name, parent)
			part({
				Name = landmark.name,
				Size = Vector3.new(8, landmark.height, 8),
				CFrame = CFrame.new(landmark.position.X, landmark.height / 2, landmark.position.Z),
				Color = COLOURS.stone,
				Material = Enum.Material.Slate,
				Parent = m,
			})
		end
	end
end

-- --------------------------------------------------------------- bus stops

local function buildBusStop(parent: Instance, stop: TownLayout.BusStop)
	local m = model(stop.name, parent)
	m:SetAttribute("BusStop", stop.name)
	-- shelter opens toward local -Z (the yaw direction)
	local base = CFrame.new(stop.position.X, 0, stop.position.Z) * CFrame.Angles(0, math.rad(stop.yaw), 0)
	part({
		Name = "Back Panel",
		Size = Vector3.new(8, 8.5, 0.4),
		CFrame = base * CFrame.new(0, 0.5 + 4.25, 1.8),
		Color = COLOURS.shelter,
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Parent = m,
	})
	for _, x in { -3.8, 3.8 } do
		part({
			Name = "Post",
			Size = Vector3.new(0.4, 9, 0.4),
			CFrame = base * CFrame.new(x, 4.5, -1.8),
			Color = COLOURS.shelter,
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end
	part({
		Name = "Roof",
		Size = Vector3.new(8.4, 0.3, 4.4),
		CFrame = base * CFrame.new(0, 9.15, 0),
		Color = COLOURS.shelter,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Pole",
		Size = Vector3.new(0.4, 10, 0.4),
		CFrame = base * CFrame.new(6, 5, 0),
		Color = COLOURS.rail,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(2.4, 2.4, 0.2),
		CFrame = base * CFrame.new(6, 9, -0.3),
		Color = COLOURS.sign,
		Parent = m,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "BUS\n" .. stop.name
	label.Parent = gui
end

-- ---------------------------------------------------------------------- API

function TownBuilder.build(): Folder
	local existing = workspace:FindFirstChild("Town")
	if existing then
		existing:Destroy()
	end
	buildRiver() -- terrain edits are idempotent

	-- build detached, parent once at the end
	local town = Instance.new("Folder")
	town.Name = "Town"
	buildRoads(model("Roads", town))
	model("River", town)
	local bridges = model("Bridges", town)
	for _, bridge in TownLayout.BRIDGES do
		buildBridge(bridges, bridge)
	end
	buildRail(model("Rail", town))
	local districts = Instance.new("Folder")
	districts.Name = "Districts"
	districts.Parent = town
	buildDistricts(districts)
	buildLandmarks(model("Landmarks", town))
	local stops = model("BusStops", town)
	for _, stop in TownLayout.BUS_STOPS do
		buildBusStop(stops, stop)
	end
	town.Parent = workspace
	return town
end

-- BasePart count per top-level child of workspace.Town, plus "Districts/<name>".
function TownBuilder.stats(): { [string]: number }
	local out: { [string]: number } = {}
	local town = workspace:FindFirstChild("Town")
	if not town then
		return out
	end
	local function count(inst: Instance): number
		local n = 0
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end
	for _, child in town:GetChildren() do
		out[child.Name] = count(child)
		if child.Name == "Districts" then
			for _, district in child:GetChildren() do
				out["Districts/" .. district.Name] = count(district)
			end
		end
	end
	return out
end

return TownBuilder
