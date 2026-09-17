--!strict
-- Imperfection pass (backlog E10.1): the small wear and clutter that makes the
-- greybox streets read as lived in. Runs after the other dressers; output goes
-- to workspace.Town.Imperfections (rebuilt from scratch by build()):
--   Road      asphalt patches near junctions and along long stretches,
--             manhole covers, drain grates at the kerb
--   Markings  faded centre-line dashes (about 30% missing, some greyed) on
--             main / residential roads, nearest the town centre first, and
--             give-way double dashes at a few junction mouths
--   Weeds     small green clumps in the gutter, along the back of the
--             pavement and at the base of terrace walls
--   Clutter   posters (fictional text) on shop side walls and inside bus
--             shelters, wheelie bins by terrace ends, a few traffic cones on
--             the pavement, and one skip beside a terrace
--
-- Reference: assets/references/RiveremereWestdale.png (worn centre-line
-- dashes, weeds at the kerb, bins by the houses, a poster in the shelter) and
-- RivermereNorthfields.png (grass creeping in at the kerb edge).
--
-- Every part carries the attribute Decor = true, so Quality "Low" hides it.
-- Placement is seeded (Random.new(SEED)) so the town is the same every run.
--
-- Y levels. Carriageway tops are TownBuilder.Y.ROAD[kind] (+ Y.STEP on odd
-- segments), so everything on a road is measured from roadTop + STEP, which is
-- above both segment parities:
--   + 0.020  patches
--   + 0.045  road markings (dashes, give-way lines)
--   + 0.070  manhole covers and drain grates
-- Flat parts are 0.1 thick and hang down into the road body, so only their top
-- faces show. Patches never overlap each other; iron never overlaps a patch,
-- a marking or other iron; nothing on a road is laid within reach of another
-- road's carriageway, a roundabout, the square, a bridge or the railway, so no
-- two visible faces are ever coplanar.
-- Off-road things (weeds, bins, skip, cones, posters) are pushed >= 0.05 into
-- whatever they stand on or hang from (terrain y = 0, pavement 0.45, walls).
--
-- Part budget (PART_BUDGET 900): the category caps below add up to at most
-- ImperfectionDresser.maxParts(); centre-line dashes are placed last and get
-- whatever is left, so the total can never pass PART_BUDGET.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownBuilder = require(script.Parent.TownBuilder)
local ShopDresser = require(script.Parent.ShopDresser)
local StreetDresser = require(script.Parent.StreetDresser)

type Rect = TownBuilder.Rect
type Road = TownLayout.Road
type Box = TownLayout.Box

local ImperfectionDresser = {}

ImperfectionDresser.SEED = 1010
ImperfectionDresser.PART_BUDGET = 900

ImperfectionDresser.PATCH_LIFT = 0.02
ImperfectionDresser.MARK_LIFT = 0.045
ImperfectionDresser.IRON_LIFT = 0.07
local FLAT_THICK = 0.1

-- caps per category (parts per item in brackets)
ImperfectionDresser.CAPS = {
	patches = 110, -- [1]
	manholes = 45, -- [1]
	grates = 40, -- [1]
	giveWays = 12, -- [<= 2 lines x GIVE_WAY_MAX_DASHES]
	weedClumps = 95, -- [<= 2]
	bins = 24, -- [2]
	cones = 6, -- [4]
	skips = 1, -- [6]
	posters = 15, -- [1]
}
local GIVE_WAY_MAX_DASHES = 4
local PARTS_PER = { bin = 2, cone = 4, skip = 6, clump = 2 }

-- centre line
local DASH_LENGTH = 6
local DASH_PERIOD = 20
local DASH_WIDTH = 0.5
local DASH_SKIP_SHARE = 0.3
local DASH_PATTERN_LENGTH = 10
local DASH_FADED_CHANCE = 0.3

-- give way: two dashed lines across the approach lane
local GIVE_WAY_DASH = 2
local GIVE_WAY_GAP = 1
local GIVE_WAY_LINE_WIDTH = 0.5
local GIVE_WAY_LINE_GAP = 0.6
local GIVE_WAY_KERB_INSET = 0.6
local GIVE_WAY_CENTRE_GAP = 0.3
local MOUTH_CLEAR = 1.5
local MOUTH_MAX = 90

-- clearances
local OTHER_ROAD_MARGIN = 2 -- road-surface items keep this far off another road's carriageway
local DASH_JUNCTION_MARGIN = 5 -- centre dashes stop this far short of another carriageway
local ROUNDABOUT_MARGIN = 4
local RIVER_MARGIN = 45 -- beyond half the river width (banks, moorings, planters)
local RIVER_BANK_MARGIN = 15 -- road items: just clear of the Mud banks (12)
local BUS_STOP_CLEAR = 12
local SQUARE_ZONE_HALF = 125 -- ForecourtDresser paves +-110 round the market square
local STATION_MARGIN = 30
local LANDMARK_CLEAR = 40
-- off-road items keep this far from district blocks by use (semis have front
-- gardens 6 out, industrial sheds yards, park / station pieces are dressed)
local BLOCK_MARGIN_DEFAULT = 1.5
local BLOCK_MARGIN: { [string]: number } = {
	semis = 10,
	warehouse = 10,
	["trade counter"] = 10,
	workshop = 10,
	["builders yard"] = 10,
	["park lawn"] = 20,
	bandstand = 20,
	["park cafe"] = 10,
	marina = 20,
	["station car park"] = 15,
	["grass pitch"] = 8,
	["3G pitch"] = 8,
	["sports hall"] = 8,
	school = 6,
	church = 6,
	["town hall"] = 6,
}
-- StreetDresser's parked cars and kit bins on these stretches
local KIT_STREETS: { [string]: { number } } = {
	["Mill Street"] = { 0, 400 },
	["Weaver Street"] = { 0, 400 },
}

local COLOURS = {
	patchDark = Color3.fromRGB(58, 60, 64),
	patchMid = Color3.fromRGB(68, 70, 73),
	patchLight = Color3.fromRGB(102, 102, 104),
	iron = Color3.fromRGB(40, 40, 42),
	grate = Color3.fromRGB(32, 33, 35),
	paint = Color3.fromRGB(232, 232, 226),
	paintFaded = Color3.fromRGB(178, 178, 172),
	weeds = { Color3.fromRGB(88, 128, 60), Color3.fromRGB(106, 142, 70), Color3.fromRGB(74, 110, 52) },
	binBodies = { Color3.fromRGB(34, 36, 38), Color3.fromRGB(46, 70, 50), Color3.fromRGB(60, 62, 66) },
	binLids = { Color3.fromRGB(28, 30, 32), Color3.fromRGB(40, 80, 150), Color3.fromRGB(46, 110, 60), Color3.fromRGB(110, 76, 50) },
	cone = Color3.fromRGB(240, 110, 30),
	coneBase = Color3.fromRGB(30, 30, 30),
	white = Color3.fromRGB(240, 240, 236),
	skip = Color3.fromRGB(226, 176, 36),
	rubble = Color3.fromRGB(96, 84, 72),
	rubbleLight = Color3.fromRGB(150, 136, 118),
}

export type Poster = { text: string, paper: Color3, ink: Color3 }

-- Fictional notices only.
ImperfectionDresser.POSTERS = {
	{ text = "RIVERMERE BRASS BAND\n\nSAT 7PM\nTOWN HALL", paper = Color3.fromRGB(238, 226, 196), ink = Color3.fromRGB(120, 30, 36) },
	{ text = "LOST CAT\n\nBISCUIT\nginger, very friendly\nplease check sheds", paper = Color3.fromRGB(246, 246, 240), ink = Color3.fromRGB(30, 30, 34) },
	{ text = "CAR BOOT SALE\n\nSUNDAY 8AM\nSPORTS CENTRE", paper = Color3.fromRGB(246, 214, 70), ink = Color3.fromRGB(30, 30, 34) },
	{ text = "RIVERMERE JUNIORS FC\n\nTRIALS U9 - U14\nTUESDAY 6PM", paper = Color3.fromRGB(34, 60, 120), ink = Color3.fromRGB(245, 245, 240) },
	{ text = "LIVE MUSIC\n\nTHE LUNE RAMBLERS\nFRIDAY - RIVERSIDE ARMS", paper = Color3.fromRGB(26, 26, 30), ink = Color3.fromRGB(246, 200, 60) },
	{ text = "QUIZ NIGHT\n\nEVERY THURSDAY\n8PM", paper = Color3.fromRGB(40, 100, 64), ink = Color3.fromRGB(245, 245, 240) },
	{ text = "SUNDAY LEAGUE\n\nPLAYERS WANTED\nALL ABILITIES", paper = Color3.fromRGB(236, 236, 230), ink = Color3.fromRGB(26, 70, 40) },
	{ text = "FIREWORKS NIGHT\n\nRIVERSIDE PARK\n5 NOVEMBER", paper = Color3.fromRGB(24, 30, 64), ink = Color3.fromRGB(250, 140, 40) },
	{ text = "JUMBLE SALE\n\nCHURCH HALL\nSATURDAY 10AM", paper = Color3.fromRGB(220, 236, 246), ink = Color3.fromRGB(30, 50, 90) },
} :: { Poster }

-- ------------------------------------------------------------ pure helpers

-- Upper bound on parts from the caps (dashes excluded: they take what is left).
function ImperfectionDresser.maxParts(): number
	local c = ImperfectionDresser.CAPS
	return c.patches
		+ c.manholes
		+ c.grates
		+ c.giveWays * 2 * GIVE_WAY_MAX_DASHES
		+ c.weedClumps * PARTS_PER.clump
		+ c.bins * PARTS_PER.bin
		+ c.cones * PARTS_PER.cone
		+ c.skips * PARTS_PER.skip
		+ c.posters
end

function ImperfectionDresser.reversed(points: { Vector3 }): { Vector3 }
	local out = table.create(#points)
	for i = #points, 1, -1 do
		table.insert(out, points[i])
	end
	return out
end

function ImperfectionDresser.polylineLength(points: { Vector3 }): number
	local total = 0
	for i = 1, #points - 1 do
		local dx, dz = points[i + 1].X - points[i].X, points[i + 1].Z - points[i].Z
		total += math.sqrt(dx * dx + dz * dz)
	end
	return total
end

export type Station = {
	position: Vector3, -- y = 0
	direction: Vector3, -- unit, along the segment
	segment: number, -- index of the segment's first point
	along: number, -- distance from the segment start
	segmentLength: number,
}

-- The point at distance s along a polyline (XZ, clamped to its ends), or nil
-- for a polyline with no length.
function ImperfectionDresser.pointAt(points: { Vector3 }, s: number): Station?
	local remaining = math.max(0, s)
	local last: Station? = nil
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-6 then
			continue
		end
		local dir = Vector3.new(dx / length, 0, dz / length)
		local t = math.min(remaining, length)
		last = {
			position = Vector3.new(a.X + dir.X * t, 0, a.Z + dir.Z * t),
			direction = dir,
			segment = i,
			along = t,
			segmentLength = length,
		}
		if remaining <= length then
			return last
		end
		remaining -= length
	end
	return last
end

-- Distance along the polyline to the point nearest p (XZ).
function ImperfectionDresser.projectOnPolyline(p: Vector3, points: { Vector3 }): number
	local best, bestS, walked = math.huge, 0, 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local lenSq = abx * abx + abz * abz
		local length = math.sqrt(lenSq)
		local t = 0
		if lenSq > 0 then
			t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / lenSq, 0, 1)
		end
		local dx, dz = p.X - (a.X + abx * t), p.Z - (a.Z + abz * t)
		local d = dx * dx + dz * dz
		if d < best then
			best = d
			bestS = walked + t * length
		end
		walked += length
	end
	return bestS
end

-- A cyclic paint pattern of `length` slots with round(length * share) of them
-- false (missing), at rng-chosen positions.
function ImperfectionDresser.skipPattern(rng: Random, length: number, share: number): { boolean }
	local pattern: { boolean } = table.create(length, true)
	local misses = math.clamp(math.floor(length * share + 0.5), 0, length)
	local order: { number } = {}
	for i = 1, length do
		table.insert(order, i)
	end
	for i = length, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i = 1, misses do
		pattern[order[i]] = false
	end
	return pattern
end

export type Dash = { centre: Vector3, direction: Vector3, slot: number }

-- Centre-line dash slots every `period` along a polyline, the first centred at
-- period / 2. A slot is kept only if its whole dash lies inside one segment
-- (never across a bend) and pattern[(slot - 1) % #pattern + 1] is true (no
-- pattern = paint every slot).
function ImperfectionDresser.dashPositions(points: { Vector3 }, dashLength: number, period: number, pattern: { boolean }?): { Dash }
	local out: { Dash } = {}
	local total = ImperfectionDresser.polylineLength(points)
	local slot = 0
	local s = period / 2
	while s <= total do
		slot += 1
		local painted = true
		if pattern and #pattern > 0 then
			painted = pattern[(slot - 1) % #pattern + 1]
		end
		if painted then
			local st = ImperfectionDresser.pointAt(points, s)
			if st and st.along >= dashLength / 2 - 1e-6 and st.segmentLength - st.along >= dashLength / 2 - 1e-6 then
				table.insert(out, { centre = st.position, direction = st.direction, slot = slot })
			end
		end
		s += period
	end
	return out
end

local function inflate(r: Rect, margin: number): Rect
	return TownBuilder.rect(r.cx, r.cz, r.ux, r.uz, r.hl + margin, r.hw + margin)
end
ImperfectionDresser.inflate = inflate

-- Greedy: keeps each candidate that overlaps nothing in `taken` (grown by
-- `margin`), appending kept ones to `taken`. Returns the kept candidates.
function ImperfectionDresser.acceptRects(candidates: { Rect }, taken: { Rect }, margin: number?): { Rect }
	local kept: { Rect } = {}
	for _, c in candidates do
		local probe = if margin and margin > 0 then inflate(c, margin) else c
		local free = true
		for _, t in taken do
			if TownBuilder.rectsOverlap(probe, t) then
				free = false
				break
			end
		end
		if free then
			table.insert(taken, c)
			table.insert(kept, c)
		end
	end
	return kept
end

-- Rectangle along a road: centre on the centreline station, `lateral` to the
-- right of travel, long axis along the road.
function ImperfectionDresser.roadRect(st: Station, lateral: number, halfLength: number, halfWidth: number): Rect
	local rx, rz = -st.direction.Z, st.direction.X
	return TownBuilder.rect(st.position.X + rx * lateral, st.position.Z + rz * lateral, st.direction.X, st.direction.Z, halfLength, halfWidth)
end

-- Give-way double dashed line at a junction mouth. `away` is the unit
-- direction from the junction out along the minor road; traffic approaching
-- the junction drives the other way, on the left (UK), so the dashes span the
-- lane on the left of -away, from near the centreline to near the kerb.
function ImperfectionDresser.giveWayRects(mouth: Vector3, away: Vector3, halfWidth: number): { Rect }
	local out: { Rect } = {}
	local tx, tz = -away.X, -away.Z -- travel direction
	local lx, lz = tz, -tx -- left of travel
	local span = halfWidth - GIVE_WAY_KERB_INSET - GIVE_WAY_CENTRE_GAP
	if span <= GIVE_WAY_DASH then
		return out
	end
	local n = math.clamp(math.floor((span + GIVE_WAY_GAP) / (GIVE_WAY_DASH + GIVE_WAY_GAP)), 1, GIVE_WAY_MAX_DASHES)
	local pitch = span / n
	local dash = math.max(0.5, pitch - GIVE_WAY_GAP)
	for line = 0, 1 do
		local along = GIVE_WAY_LINE_WIDTH / 2 + line * (GIVE_WAY_LINE_WIDTH + GIVE_WAY_LINE_GAP)
		local ox, oz = mouth.X + away.X * along, mouth.Z + away.Z * along
		for k = 1, n do
			local lateral = GIVE_WAY_CENTRE_GAP + (k - 0.5) * pitch
			table.insert(out, TownBuilder.rect(ox + lx * lateral, oz + lz * lateral, lx, lz, dash / 2, GIVE_WAY_LINE_WIDTH / 2))
		end
	end
	return out
end

export type Junction = {
	road: Road, -- the minor road
	atStart: boolean, -- which end of the minor road meets the major one
	point: Vector3,
	major: Road?, -- nil when it meets a roundabout
	roundabout: TownLayout.Roundabout?,
	majorHalf: number, -- half carriageway width, or the roundabout radius
}

local function flatDistance(p: Vector3, q: Vector3): number
	local dx, dz = p.X - q.X, p.Z - q.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Road ends that sit on another road's carriageway (a T or crossroads, not
-- where two roads simply continue end to end) or on a roundabout. Closed
-- polylines (the ring) have no ends.
function ImperfectionDresser.junctions(roads: { Road }, roundabouts: { TownLayout.Roundabout }): { Junction }
	local out: { Junction } = {}
	for _, road in roads do
		local n = #road.points
		if n < 2 or flatDistance(road.points[1], road.points[n]) < 0.5 then
			continue
		end
		for _, atStart in { true, false } do
			local p = if atStart then road.points[1] else road.points[n]
			local found: Junction? = nil
			for _, rb in roundabouts do
				if flatDistance(p, rb.centre) <= rb.radius + 1 then
					found = { road = road, atStart = atStart, point = p, major = nil, roundabout = rb, majorHalf = rb.radius }
					break
				end
			end
			if not found then
				local bestD = math.huge
				for _, q in roads do
					if q == road or #q.points < 2 then
						continue
					end
					local half = q.width / 2
					local d = TownLayout.distanceToPolyline(p, q.points)
					if d > half + 1 or d >= bestD then
						continue
					end
					local qn = #q.points
					local qClosed = flatDistance(q.points[1], q.points[qn]) < 0.5
					if not qClosed and (flatDistance(p, q.points[1]) <= half or flatDistance(p, q.points[qn]) <= half) then
						continue -- end to end, not a junction
					end
					bestD = d
					found = { road = road, atStart = atStart, point = p, major = q, roundabout = nil, majorHalf = half }
				end
			end
			if found then
				table.insert(out, found)
			end
		end
	end
	return out
end

-- Walking out along `points` (starting at the junction end), the distance at
-- which distanceFn first exceeds reach, or nil if that is beyond maxS or the
-- polyline's end.
function ImperfectionDresser.mouthDistance(points: { Vector3 }, distanceFn: (Vector3) -> number, reach: number, maxS: number): number?
	local total = ImperfectionDresser.polylineLength(points)
	local s = 0
	while s <= math.min(maxS, total) do
		local st = ImperfectionDresser.pointAt(points, s)
		if st and distanceFn(st.position) > reach then
			return s
		end
		s += 0.5
	end
	return nil
end

-- Minor road points ordered from the junction outward.
local function fromJunction(j: Junction): { Vector3 }
	return if j.atStart then j.road.points else ImperfectionDresser.reversed(j.road.points)
end

local function junctionDistanceFn(j: Junction): (Vector3) -> number
	local major = j.major
	local rb = j.roundabout
	return function(p: Vector3): number
		if major then
			return TownLayout.distanceToPolyline(p, major.points)
		elseif rb then
			return flatDistance(p, rb.centre)
		end
		return math.huge
	end
end

-- --------------------------------------------------------- world clearance

type Tagged = { rect: Rect, road: string }
type Circle = { x: number, z: number, r: number, road: string? }
type BlockEntry = { rect: Rect, grown: Rect, block: Box, margin: number }

type World = {
	carriageways: { Tagged },
	reaches: { Tagged }, -- carriageway + pavements
	joints: { Circle }, -- carriageway radius at bends
	jointReaches: { Circle },
	fixedCircles: { Circle }, -- roundabouts, bus stops, landmarks
	fixedRects: { Rect }, -- bridges, railway
	railCircles: { Circle },
	blocks: { BlockEntry },
	station: Rect,
	grownCarriageways: { [number]: { Tagged } }, -- by margin, filled on demand
	grownReaches: { Tagged }, -- reaches + 0.5
}

local function blockRect(block: Box, margin: number): Rect
	local yaw = math.rad(block.yaw)
	return TownBuilder.rect(block.centre.X, block.centre.Z, math.cos(yaw), -math.sin(yaw), block.size.X / 2 + margin, block.size.Z / 2 + margin)
end
ImperfectionDresser.blockRect = blockRect

local function isClosed(points: { Vector3 }): boolean
	return #points > 2 and flatDistance(points[1], points[#points]) < 0.5
end

local function buildWorld(): World
	local w: World = {
		carriageways = {},
		reaches = {},
		joints = {},
		jointReaches = {},
		fixedCircles = {},
		fixedRects = {},
		railCircles = {},
		blocks = {},
		station = blockRect({ centre = TownLayout.RAIL.station.centre, size = TownLayout.RAIL.station.size, yaw = TownLayout.RAIL.station.yaw, use = "station" }, STATION_MARGIN),
		grownCarriageways = {},
		grownReaches = {},
	}
	for _, road in TownLayout.ROADS do
		local half = road.width / 2
		local reach = half + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH)
		for i = 1, #road.points - 1 do
			local c = TownBuilder.segmentRect(road.points[i], road.points[i + 1], half)
			local r = TownBuilder.segmentRect(road.points[i], road.points[i + 1], reach)
			if c and r then
				table.insert(w.carriageways, { rect = c, road = road.name })
				table.insert(w.reaches, { rect = r, road = road.name })
				table.insert(w.grownReaches, { rect = inflate(r, 0.5), road = road.name })
			end
		end
		local n = #road.points
		local first = if isClosed(road.points) then 1 else 2
		for i = first, n - 1 do
			local p = road.points[i]
			table.insert(w.joints, { x = p.X, z = p.Z, r = half, road = road.name })
			table.insert(w.jointReaches, { x = p.X, z = p.Z, r = reach, road = road.name })
		end
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		table.insert(w.fixedCircles, { x = rb.centre.X, z = rb.centre.Z, r = rb.radius + ROUNDABOUT_MARGIN })
	end
	for _, stop in TownLayout.BUS_STOPS do
		table.insert(w.fixedCircles, { x = stop.position.X, z = stop.position.Z, r = BUS_STOP_CLEAR })
	end
	for _, landmark in TownLayout.LANDMARKS do
		if landmark.name ~= "Church Spire" then -- the church is a district block
			table.insert(w.fixedCircles, { x = landmark.position.X, z = landmark.position.Z, r = LANDMARK_CLEAR })
		end
	end
	for _, bridge in TownLayout.BRIDGES do
		local deck = if bridge.kind == "road" then bridge.width + 2 * (TownLayout.PAVEMENT_WIDTH + 1.5) else bridge.width + 4
		local r = TownBuilder.segmentRect(bridge.from, bridge.to, deck / 2 + 4)
		if r then
			table.insert(w.fixedRects, inflate(r, 6))
		end
	end
	local rail = TownLayout.RAIL
	for i = 1, #rail.points - 1 do
		local r = TownBuilder.segmentRect(rail.points[i], rail.points[i + 1], rail.width / 2 + 4)
		if r then
			table.insert(w.fixedRects, r)
		end
	end
	for i = 2, #rail.points - 1 do
		table.insert(w.railCircles, { x = rail.points[i].X, z = rail.points[i].Z, r = rail.width / 2 + 4 })
	end
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			local margin = BLOCK_MARGIN[block.use] or BLOCK_MARGIN_DEFAULT
			table.insert(w.blocks, { rect = blockRect(block, 0), grown = blockRect(block, margin), block = block, margin = margin })
		end
	end
	return w
end

-- Carriageway rects grown by `margin`, built once per margin.
local function grownCarriageways(w: World, margin: number): { Tagged }
	local cached = w.grownCarriageways[margin]
	if cached then
		return cached
	end
	local list: { Tagged } = {}
	for _, t in w.carriageways do
		table.insert(list, { rect = inflate(t.rect, margin), road = t.road })
	end
	w.grownCarriageways[margin] = list
	return list
end

local function inAnyPlot(x: number, z: number): boolean
	local p = Vector3.new(x, 0, z)
	for i = 1, #TownLayout.PLOTS do
		if TownLayout.pointInPlot(p, i) then
			return true
		end
	end
	return false
end

local function nearRiver(x: number, z: number, margin: number): boolean
	return TownLayout.distanceToPolyline(Vector3.new(x, 0, z), TownLayout.RIVER.points) < TownLayout.RIVER.width / 2 + margin
end

local function inStation(w: World, rect: Rect): boolean
	return TownBuilder.rectsOverlap(rect, w.station)
end

-- riverMargin: past half the river width (road items only need to clear the
-- banks; ground items also keep off the moorings and planters)
local function commonClear(w: World, rect: Rect, riverMargin: number): boolean
	if inAnyPlot(rect.cx, rect.cz) or nearRiver(rect.cx, rect.cz, riverMargin) or inStation(w, rect) then
		return false
	end
	for _, c in w.fixedCircles do
		if TownBuilder.circleOverlapsRect(c.x, c.z, c.r, rect) then
			return false
		end
	end
	for _, r in w.fixedRects do
		if TownBuilder.rectsOverlap(rect, r) then
			return false
		end
	end
	for _, c in w.railCircles do
		if TownBuilder.circleOverlapsRect(c.x, c.z, c.r, rect) then
			return false
		end
	end
	local sq = TownLayout.SQUARE
	if TownBuilder.circleOverlapsRect(sq.centre.X, sq.centre.Z, sq.radius + ROUNDABOUT_MARGIN, rect) then
		return false
	end
	return true
end

-- A rectangle on `roadName`'s carriageway that keeps clear of every other
-- road, building, bridge, the rail, the river and the plots.
local function roadSurfaceClear(w: World, rect: Rect, roadName: string, margin: number): boolean
	if not commonClear(w, rect, RIVER_BANK_MARGIN) then
		return false
	end
	for _, t in grownCarriageways(w, margin) do
		if t.road ~= roadName and TownBuilder.rectsOverlap(rect, t.rect) then
			return false
		end
	end
	for _, c in w.joints do
		if c.road ~= roadName and TownBuilder.circleOverlapsRect(c.x, c.z, c.r + margin, rect) then
			return false
		end
	end
	for _, b in w.blocks do
		if TownBuilder.rectsOverlap(rect, b.rect) then
			return false
		end
	end
	return true
end

-- A rectangle on the ground (grass, forecourt) or hung on a wall: off every
-- carriageway and pavement (except `ownRoad`'s pavement, whose carriageway it
-- still avoids), clear of blocks by their margin (except `ownBlock`, which it
-- only must not overlap) and of the market-square paving zone.
local function groundClear(w: World, rect: Rect, ownRoad: string?, ownBlock: Box?): boolean
	if not commonClear(w, rect, RIVER_MARGIN) then
		return false
	end
	if math.abs(rect.cx - TownLayout.SQUARE.centre.X) < SQUARE_ZONE_HALF and math.abs(rect.cz - TownLayout.SQUARE.centre.Z) < SQUARE_ZONE_HALF then
		return false
	end
	for _, t in w.grownReaches do
		if t.road ~= ownRoad and TownBuilder.rectsOverlap(rect, t.rect) then
			return false
		end
	end
	for _, c in w.jointReaches do
		if c.road ~= ownRoad and TownBuilder.circleOverlapsRect(c.x, c.z, c.r + 0.5, rect) then
			return false
		end
	end
	if ownRoad then
		for _, t in grownCarriageways(w, 0.5) do
			if t.road == ownRoad and TownBuilder.rectsOverlap(rect, t.rect) then
				return false
			end
		end
	end
	for _, b in w.blocks do
		if TownBuilder.rectsOverlap(rect, if b.block == ownBlock then b.rect else b.grown) then
			return false
		end
	end
	return true
end

-- On `roadName`'s pavement (kerb top): off every other carriageway, junction
-- and building, so the pavement itself is there.
local function pavementClear(w: World, rect: Rect, roadName: string): boolean
	if not commonClear(w, rect, RIVER_MARGIN) then
		return false
	end
	for _, t in grownCarriageways(w, 0.2) do
		if t.road == roadName and TownBuilder.rectsOverlap(rect, t.rect) then
			return false
		end
	end
	for _, t in grownCarriageways(w, 2) do
		if t.road ~= roadName and TownBuilder.rectsOverlap(rect, t.rect) then
			return false
		end
	end
	for _, c in w.joints do
		if TownBuilder.circleOverlapsRect(c.x, c.z, c.r + 2, rect) then
			return false
		end
	end
	for _, b in w.blocks do
		if TownBuilder.rectsOverlap(rect, b.grown) then
			return false
		end
	end
	return true
end

local function overlapsAny(rect: Rect, list: { Rect }): boolean
	for _, r in list do
		if TownBuilder.rectsOverlap(rect, r) then
			return true
		end
	end
	return false
end

local function onKitStretch(road: Road, x: number): boolean
	local range = KIT_STREETS[road.name]
	return range ~= nil and x >= range[1] and x <= range[2]
end

-- StreetDresser's kit terrace rows (Mill Street Terraces, x 0..400).
local function onKitRows(block: Box): boolean
	-- the kit rows in the showpiece stretch carry extra geometry; leave them alone
	return block.centre.X >= -20 and block.centre.X <= 420 and block.centre.Z <= -140 and block.centre.Z >= -390
end

-- ------------------------------------------------------------ instances

type Ctx = {
	rng: Random,
	used: number,
	world: World,
	patches: { Rect },
	iron: { Rect },
	marks: { Rect },
	ground: { Rect },
	folders: { [string]: Folder },
	counts: { [string]: number },
}

local function part(ctx: Ctx, folder: string, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, collide: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p:SetAttribute("Decor", true)
	p.Parent = ctx.folders[folder]
	ctx.used += 1
	return p
end

local function wedge(ctx: Ctx, folder: string, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p:SetAttribute("Decor", true)
	p.Parent = ctx.folders[folder]
	ctx.used += 1
	return p
end

local function room(ctx: Ctx, parts: number): boolean
	return ctx.used + parts <= ImperfectionDresser.PART_BUDGET
end

local function bump(ctx: Ctx, key: string)
	ctx.counts[key] = (ctx.counts[key] or 0) + 1
end

local function surfaceTop(road: Road): number
	return TownBuilder.roadTop(road.kind) + TownBuilder.Y.STEP
end

-- Flat 0.1-thick part whose top sits at `top`, covering the rect.
local function flat(ctx: Ctx, folder: string, name: string, rect: Rect, top: number, color: Color3, material: Enum.Material)
	local centre = Vector3.new(rect.cx, top - FLAT_THICK / 2, rect.cz)
	local cf = CFrame.lookAt(centre, centre + Vector3.new(rect.ux, 0, rect.uz))
	part(ctx, folder, name, Vector3.new(rect.hw * 2, FLAT_THICK, rect.hl * 2), cf, color, material)
end

-- ---------------------------------------------------------------- road wear

local function tryPatch(ctx: Ctx, road: Road, points: { Vector3 }, s: number): boolean
	if (ctx.counts.patches or 0) >= ImperfectionDresser.CAPS.patches or not room(ctx, 1) then
		return false
	end
	local rng = ctx.rng
	local st = ImperfectionDresser.pointAt(points, s)
	if not st then
		return false
	end
	local half = road.width / 2
	local length = rng:NextNumber(4, 11)
	local across = rng:NextNumber(2.5, math.min(6.5, half - 2))
	if st.along < length / 2 + 1 or st.segmentLength - st.along < length / 2 + 1 then
		return false
	end
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local minLat, maxLat = across / 2 + 0.4, half - 0.6 - across / 2
	if maxLat < minLat then
		return false
	end
	local rect = ImperfectionDresser.roadRect(st, side * rng:NextNumber(minLat, maxLat), length / 2, across / 2)
	if not roadSurfaceClear(ctx.world, rect, road.name, OTHER_ROAD_MARGIN) then
		return false
	end
	if #ImperfectionDresser.acceptRects({ rect }, ctx.patches, 1) == 0 then
		return false
	end
	local roll = rng:NextNumber()
	local color = if roll < 0.45 then COLOURS.patchDark elseif roll < 0.75 then COLOURS.patchMid else COLOURS.patchLight
	flat(ctx, "Road", "Patch", rect, surfaceTop(road) + ImperfectionDresser.PATCH_LIFT, color, Enum.Material.Asphalt)
	bump(ctx, "patches")
	return true
end

local function placePatches(ctx: Ctx, junctions: { Junction })
	local rng = ctx.rng
	for _, j in junctions do
		local minor = j.road
		local points = fromJunction(j)
		local mouth = ImperfectionDresser.mouthDistance(points, junctionDistanceFn(j), j.majorHalf + MOUTH_CLEAR, MOUTH_MAX) or (j.majorHalf + 4)
		if rng:NextNumber() < 0.6 then
			tryPatch(ctx, minor, points, mouth + rng:NextNumber(6, 40))
		end
		local major = j.major
		if major and rng:NextNumber() < 0.55 then
			local along = ImperfectionDresser.projectOnPolyline(j.point, major.points)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			tryPatch(ctx, major, major.points, along + side * (minor.width / 2 + rng:NextNumber(8, 30)))
		end
	end
	-- a few along long stretches
	for _, road in TownLayout.ROADS do
		local total = ImperfectionDresser.polylineLength(road.points)
		local s = rng:NextNumber(60, 160)
		while s < total do
			if rng:NextNumber() < 0.3 then
				tryPatch(ctx, road, road.points, s)
			end
			s += rng:NextNumber(180, 320)
		end
	end
end

local function placeIron(ctx: Ctx)
	local rng = ctx.rng
	for _, road in TownLayout.ROADS do
		local half = road.width / 2
		local top = surfaceTop(road) + ImperfectionDresser.IRON_LIFT
		local total = ImperfectionDresser.polylineLength(road.points)
		-- manholes in a lane
		local s = rng:NextNumber(40, 120)
		while s < total do
			local st = ImperfectionDresser.pointAt(road.points, s)
			if st and (ctx.counts.manholes or 0) < ImperfectionDresser.CAPS.manholes and room(ctx, 1) and rng:NextNumber() < 0.45 then
				local radius = 1.1
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local rect = ImperfectionDresser.roadRect(st, side * half / 2, radius, radius)
				if
					st.along > 3
					and st.segmentLength - st.along > 3
					and roadSurfaceClear(ctx.world, rect, road.name, OTHER_ROAD_MARGIN)
					and not overlapsAny(rect, ctx.patches)
					and #ImperfectionDresser.acceptRects({ rect }, ctx.iron, 0.5) == 1
				then
					part(
						ctx,
						"Road",
						"Manhole",
						Vector3.new(FLAT_THICK, radius * 2, radius * 2),
						CFrame.new(rect.cx, top - FLAT_THICK / 2, rect.cz) * CFrame.Angles(0, 0, math.rad(90)),
						COLOURS.iron,
						Enum.Material.DiamondPlate,
						Enum.PartType.Cylinder
					)
					bump(ctx, "manholes")
				end
			end
			s += rng:NextNumber(110, 200)
		end
		-- grates in the gutter
		if road.kind == "lane" then
			continue
		end
		s = rng:NextNumber(30, 90)
		while s < total do
			local st = ImperfectionDresser.pointAt(road.points, s)
			if st and (ctx.counts.grates or 0) < ImperfectionDresser.CAPS.grates and room(ctx, 1) and rng:NextNumber() < 0.4 and not onKitStretch(road, st.position.X) then
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local rect = ImperfectionDresser.roadRect(st, side * (half - 0.75), 1.2, 0.6)
				if
					st.along > 2
					and st.segmentLength - st.along > 2
					and roadSurfaceClear(ctx.world, rect, road.name, OTHER_ROAD_MARGIN)
					and not overlapsAny(rect, ctx.patches)
					and #ImperfectionDresser.acceptRects({ rect }, ctx.iron, 0.5) == 1
				then
					flat(ctx, "Road", "Grate", rect, top, COLOURS.grate, Enum.Material.DiamondPlate)
					bump(ctx, "grates")
				end
			end
			s += rng:NextNumber(120, 220)
		end
	end
end

-- ---------------------------------------------------------------- markings

local function paint(ctx: Ctx): Color3
	return if ctx.rng:NextNumber() < DASH_FADED_CHANCE then COLOURS.paintFaded else COLOURS.paint
end

local function placeGiveWays(ctx: Ctx, junctions: { Junction })
	local rng = ctx.rng
	-- a deterministic shuffle so the few lines spread over the town
	local order: { number } = {}
	for i = 1, #junctions do
		table.insert(order, i)
	end
	for i = #order, 2, -1 do
		local k = rng:NextInteger(1, i)
		order[i], order[k] = order[k], order[i]
	end
	for _, index in order do
		if (ctx.counts.giveWays or 0) >= ImperfectionDresser.CAPS.giveWays then
			break
		end
		local j = junctions[index]
		if j.road.kind == "lane" then
			continue
		end
		local points = fromJunction(j)
		local mouth = ImperfectionDresser.mouthDistance(points, junctionDistanceFn(j), j.majorHalf + MOUTH_CLEAR, MOUTH_MAX)
		if not mouth then
			continue
		end
		-- step out until the whole line is clear of the major road
		local placed = false
		for extra = 0, 8, 2 do
			local st = ImperfectionDresser.pointAt(points, mouth + extra)
			if not st or st.along < 2 then
				continue
			end
			local rects = ImperfectionDresser.giveWayRects(st.position, st.direction, j.road.width / 2)
			if #rects == 0 or not room(ctx, #rects) then
				break
			end
			local ok = true
			for _, r in rects do
				if not roadSurfaceClear(ctx.world, r, j.road.name, OTHER_ROAD_MARGIN) or overlapsAny(r, ctx.iron) then
					ok = false
					break
				end
			end
			if ok then
				local top = surfaceTop(j.road) + ImperfectionDresser.MARK_LIFT
				for _, r in rects do
					table.insert(ctx.marks, r)
					if rng:NextNumber() < 0.2 then
						continue -- worn away
					end
					flat(ctx, "Markings", "GiveWay", r, top, paint(ctx), Enum.Material.SmoothPlastic)
				end
				placed = true
				break
			end
		end
		if placed then
			bump(ctx, "giveWays")
		end
	end
end

local function placeCentreLines(ctx: Ctx)
	local rng = ctx.rng
	local roads: { { road: Road, d: number } } = {}
	for _, road in TownLayout.ROADS do
		if road.kind == "main" or road.kind == "residential" then
			local mid = StreetDresser.polylineMidpoint(road.points)
			table.insert(roads, { road = road, d = flatDistance(mid, TownLayout.SQUARE.centre) })
		end
	end
	table.sort(roads, function(a, b)
		if a.d == b.d then
			return a.road.name < b.road.name
		end
		return a.d < b.d
	end)
	for _, entry in roads do
		local road = entry.road
		local pattern = ImperfectionDresser.skipPattern(rng, DASH_PATTERN_LENGTH, DASH_SKIP_SHARE)
		local top = surfaceTop(road) + ImperfectionDresser.MARK_LIFT
		for _, dash in ImperfectionDresser.dashPositions(road.points, DASH_LENGTH, DASH_PERIOD, pattern) do
			if not room(ctx, 1) then
				return
			end
			local rect = TownBuilder.rect(dash.centre.X, dash.centre.Z, dash.direction.X, dash.direction.Z, DASH_LENGTH / 2, DASH_WIDTH / 2)
			if roadSurfaceClear(ctx.world, rect, road.name, DASH_JUNCTION_MARGIN) and not overlapsAny(rect, ctx.iron) and not overlapsAny(rect, ctx.marks) then
				flat(ctx, "Markings", "CentreDash", rect, top, paint(ctx), Enum.Material.SmoothPlastic)
				bump(ctx, "dashes")
			end
		end
	end
end

-- ---------------------------------------------------------------- weeds

local function clump(ctx: Ctx, x: number, z: number, groundY: number)
	local rng = ctx.rng
	local d = rng:NextNumber(0.5, 0.85)
	local green = COLOURS.weeds[rng:NextInteger(1, #COLOURS.weeds)]
	-- centred on the surface: the lower half is buried, so it never floats
	part(ctx, "Weeds", "Weed", Vector3.one * d, CFrame.new(x, groundY + d * 0.1, z), green, Enum.Material.Grass, Enum.PartType.Ball)
	if rng:NextNumber() < 0.5 then
		local d2 = d * rng:NextNumber(0.55, 0.8)
		local a = rng:NextNumber(0, math.pi * 2)
		local green2 = COLOURS.weeds[rng:NextInteger(1, #COLOURS.weeds)]
		part(ctx, "Weeds", "Weed", Vector3.one * d2, CFrame.new(x + math.cos(a) * d * 0.45, groundY, z + math.sin(a) * d * 0.45), green2, Enum.Material.Grass, Enum.PartType.Ball)
	end
	bump(ctx, "weedClumps")
end

local function weedRoom(ctx: Ctx): boolean
	return (ctx.counts.weedClumps or 0) < ImperfectionDresser.CAPS.weedClumps and room(ctx, PARTS_PER.clump)
end

local GUTTER_SHARE = 0.4
local PAVEMENT_SHARE = 0.3 -- of the weed cap; walls get the rest

local function placeWeeds(ctx: Ctx)
	local rng = ctx.rng
	local cap = ImperfectionDresser.CAPS.weedClumps
	-- gutters: on the carriageway against the kerb
	local gutterCap = math.floor(cap * GUTTER_SHARE)
	for _, road in TownLayout.ROADS do
		if road.kind == "lane" or road.kind == "ring" then
			continue
		end
		local half = road.width / 2
		local total = ImperfectionDresser.polylineLength(road.points)
		local s = rng:NextNumber(20, 90)
		while s < total and (ctx.counts.weedClumps or 0) < gutterCap do
			local st = ImperfectionDresser.pointAt(road.points, s)
			if st and rng:NextNumber() < 0.3 and weedRoom(ctx) and not onKitStretch(road, st.position.X) then
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local rect = ImperfectionDresser.roadRect(st, side * (half - 0.45), 0.5, 0.45)
				if roadSurfaceClear(ctx.world, rect, road.name, OTHER_ROAD_MARGIN) and not overlapsAny(rect, ctx.iron) and not overlapsAny(rect, ctx.marks) then
					clump(ctx, rect.cx, rect.cz, surfaceTop(road))
				end
			end
			s += rng:NextNumber(70, 150)
		end
	end
	-- back edge of the pavement
	local pavementCap = gutterCap + math.floor(cap * PAVEMENT_SHARE)
	for _, road in TownLayout.ROADS do
		if road.kind ~= "residential" and road.kind ~= "main" then
			continue
		end
		local reach = road.width / 2 + TownLayout.PAVEMENT_WIDTH
		local total = ImperfectionDresser.polylineLength(road.points)
		local s = rng:NextNumber(30, 110)
		while s < total and (ctx.counts.weedClumps or 0) < pavementCap do
			local st = ImperfectionDresser.pointAt(road.points, s)
			if st and rng:NextNumber() < 0.35 and weedRoom(ctx) then
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				local rect = ImperfectionDresser.roadRect(st, side * (reach + 0.35), 0.45, 0.4)
				if groundClear(ctx.world, rect, road.name, nil) and not overlapsAny(rect, ctx.ground) then
					clump(ctx, rect.cx, rect.cz, 0.3)
				end
			end
			s += rng:NextNumber(90, 180)
		end
	end
	-- wall bases along terrace rows
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use ~= "terraced row" or rng:NextNumber() > 0.1 or onKitRows(block) then
				continue
			end
			if not weedRoom(ctx) then
				return
			end
			local longX = block.size.X >= block.size.Z
			local length = if longX then block.size.X else block.size.Z
			local depth = if longX then block.size.Z else block.size.X
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local along = rng:NextNumber(-length / 2 + 2, length / 2 - 2)
			local out = depth / 2 + 0.45
			local lx, lz = if longX then along else side * out, if longX then side * out else along
			local cf = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
			local p = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
			local rect = TownBuilder.rect(p.X, p.Z, 1, 0, 0.4, 0.4)
			if groundClear(ctx.world, rect, nil, block) and not overlapsAny(rect, ctx.ground) then
				clump(ctx, p.X, p.Z, 0.25)
			end
		end
	end
end

-- ---------------------------------------------------------------- clutter

-- Row frame of a terraced row block: the row runs along local Z, front -X.
local function rowFrame(block: Box): (CFrame, number, number)
	local longX = block.size.X >= block.size.Z
	local length = if longX then block.size.X else block.size.Z
	local depth = if longX then block.size.Z else block.size.X
	return StreetDresser.lightRowPlacement(block), length, depth
end

local function terraceBlocks(): { Box }
	local out: { Box } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use == "terraced row" and not onKitRows(block) then
				table.insert(out, block)
			end
		end
	end
	return out
end

local function placeSkip(ctx: Ctx, rows: { Box })
	local rng = ctx.rng
	if not room(ctx, PARTS_PER.skip) then
		return
	end
	local start = rng:NextInteger(1, math.max(1, #rows))
	for k = 0, math.min(#rows, 200) - 1 do
		local block = rows[(start + k - 1) % #rows + 1]
		local cf, length, depth = rowFrame(block)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		-- skip frame: long axis along the row's local X (front to back), beside the gable end
		local sx = -depth / 2 + 5.2 + 1 -- toward the street front
		local sz = side * (length / 2 + 1.2 + 2.75)
		local frame = cf * CFrame.new(sx, 0, sz) * CFrame.Angles(0, math.pi / 2, 0)
		local look = frame.LookVector
		local rect = TownBuilder.rect(frame.Position.X, frame.Position.Z, look.X, look.Z, 5.2, 2.75)
		if not groundClear(ctx.world, rect, nil, block) or overlapsAny(inflate(rect, 1), ctx.ground) then
			continue
		end
		table.insert(ctx.ground, rect)
		local h, bodyLength, width, endDepth = 3, 8, 5.5, 1.2
		local bottom = -0.05
		part(ctx, "Clutter", "Skip", Vector3.new(width, h, bodyLength), frame * CFrame.new(0, bottom + h / 2, 0), COLOURS.skip, Enum.Material.Metal, nil, true)
		-- sloped ends, wider at the top (upside-down wedges, full face against the body)
		wedge(ctx, "Clutter", "SkipEnd", Vector3.new(width, h, endDepth), frame * CFrame.new(0, bottom + h / 2, bodyLength / 2 + endDepth / 2) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, math.pi), COLOURS.skip, Enum.Material.Metal)
		wedge(ctx, "Clutter", "SkipEnd", Vector3.new(width, h, endDepth), frame * CFrame.new(0, bottom + h / 2, -bodyLength / 2 - endDepth / 2) * CFrame.Angles(0, 0, math.pi), COLOURS.skip, Enum.Material.Metal)
		-- rubble heaped just above the rim
		local rim = bottom + h
		part(ctx, "Clutter", "SkipRubble", Vector3.new(width - 0.6, 0.3, bodyLength + 1.6), frame * CFrame.new(0, rim + 0.1, 0), COLOURS.rubble, Enum.Material.Slate)
		part(ctx, "Clutter", "SkipRubble", Vector3.one * 1.6, frame * CFrame.new(-0.9, rim + 0.3, -1.5), COLOURS.rubbleLight, Enum.Material.Concrete, Enum.PartType.Ball)
		part(ctx, "Clutter", "SkipRubble", Vector3.one * 1.2, frame * CFrame.new(1.0, rim + 0.2, 2.2), COLOURS.rubble, Enum.Material.WoodPlanks, Enum.PartType.Ball)
		bump(ctx, "skips")
		return
	end
end

local function placeBins(ctx: Ctx, rows: { Box })
	local rng = ctx.rng
	for _, block in rows do
		if (ctx.counts.bins or 0) >= ImperfectionDresser.CAPS.bins then
			return
		end
		if rng:NextNumber() > 0.07 then
			continue
		end
		local cf, length, depth = rowFrame(block)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local count = rng:NextInteger(1, 2)
		for k = 1, count do
			if (ctx.counts.bins or 0) >= ImperfectionDresser.CAPS.bins or not room(ctx, PARTS_PER.bin) then
				return
			end
			local bx = -depth / 2 + 1.8 + (k - 1) * 2.6
			local bz = side * (length / 2 + 1.8)
			local base = cf * CFrame.new(bx, 0, bz) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0)
			local rect = TownBuilder.rect(base.Position.X, base.Position.Z, 1, 0, 1.6, 1.6)
			if not groundClear(ctx.world, rect, nil, block) or overlapsAny(rect, ctx.ground) then
				break
			end
			table.insert(ctx.ground, rect)
			local bodyH = 3.3
			local bottom = -0.05
			part(ctx, "Clutter", "WheelieBin", Vector3.new(2, bodyH, 2.2), base * CFrame.new(0, bottom + bodyH / 2, 0), COLOURS.binBodies[rng:NextInteger(1, #COLOURS.binBodies)], Enum.Material.Plastic, nil, true)
			-- lid overhangs the body on every side, bottom 0.05 into the body top
			part(ctx, "Clutter", "WheelieBinLid", Vector3.new(2.2, 0.25, 2.5), base * CFrame.new(0, bottom + bodyH - 0.05 + 0.125, -0.1), COLOURS.binLids[rng:NextInteger(1, #COLOURS.binLids)], Enum.Material.Plastic)
			bump(ctx, "bins")
		end
	end
end

local function cone(ctx: Ctx, x: number, z: number, surface: number)
	local base = surface - 0.05
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along local X
	part(ctx, "Clutter", "ConeBase", Vector3.new(1.3, 0.15, 1.3), CFrame.new(x, base + 0.075, z), COLOURS.coneBase, Enum.Material.Rubber)
	part(ctx, "Clutter", "Cone", Vector3.new(1.1, 0.8, 0.8), CFrame.new(x, base + 0.1 + 0.55, z) * up, COLOURS.cone, Enum.Material.Plastic, Enum.PartType.Cylinder)
	part(ctx, "Clutter", "Cone", Vector3.new(1.0, 0.5, 0.5), CFrame.new(x, base + 1.15 + 0.5, z) * up, COLOURS.cone, Enum.Material.Plastic, Enum.PartType.Cylinder)
	part(ctx, "Clutter", "ConeBand", Vector3.new(0.35, 0.6, 0.6), CFrame.new(x, base + 1.45, z) * up, COLOURS.white, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	bump(ctx, "cones")
end

local LIGHT_LAMP_SPACING = 80 -- StreetDresser: lamps at 40 + 80k along residential streets

local function placeCones(ctx: Ctx)
	local rng = ctx.rng
	local candidates: { Road } = {}
	for _, road in TownLayout.ROADS do
		if road.kind == "residential" and not KIT_STREETS[road.name] and ImperfectionDresser.polylineLength(road.points) > 200 then
			table.insert(candidates, road)
		end
	end
	if #candidates == 0 then
		return
	end
	local sites = 0
	local start = rng:NextInteger(1, #candidates)
	for k = 0, #candidates - 1 do
		if sites >= 2 or (ctx.counts.cones or 0) + 3 > ImperfectionDresser.CAPS.cones then
			return
		end
		local road = candidates[(start + k - 1) % #candidates + 1]
		-- halfway between two lamp stations
		local s = LIGHT_LAMP_SPACING * rng:NextInteger(1, math.max(1, math.floor(ImperfectionDresser.polylineLength(road.points) / LIGHT_LAMP_SPACING) - 1))
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local st = ImperfectionDresser.pointAt(road.points, s)
		if not st or st.along < 6 or st.segmentLength - st.along < 6 then
			continue
		end
		local lateral = side * (road.width / 2 + 1.2)
		local rects: { Rect } = {}
		for i = -1, 1 do
			local stI = ImperfectionDresser.pointAt(road.points, s + i * 2.4)
			if stI then
				table.insert(rects, ImperfectionDresser.roadRect(stI, lateral, 0.7, 0.7))
			end
		end
		local ok = #rects == 3 and room(ctx, 3 * PARTS_PER.cone)
		for _, r in rects do
			if not ok then
				break
			end
			ok = pavementClear(ctx.world, r, road.name)
		end
		if ok then
			for _, r in rects do
				cone(ctx, r.cx, r.cz, TownBuilder.Y.PAVEMENT)
			end
			sites += 1
		end
	end
end

local function posterGui(p: BasePart, face: Enum.NormalId, poster: Poster)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = poster.paper
	label.BackgroundTransparency = 0
	label.BorderSizePixel = 0
	label.TextColor3 = poster.ink
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = poster.text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.PaddingLeft = UDim.new(0.08, 0)
	pad.PaddingRight = UDim.new(0.08, 0)
	pad.Parent = label
end

local POSTER_SIZE = Vector3.new(2.2, 3.1, 0.2)
local POSTER_EMBED = 0.05

local function posterPart(ctx: Ctx, cf: CFrame, face: Enum.NormalId, index: number)
	local posters = ImperfectionDresser.POSTERS
	local poster = posters[(index - 1) % #posters + 1]
	local p = part(ctx, "Clutter", "Poster", POSTER_SIZE, cf, poster.paper, Enum.Material.SmoothPlastic)
	posterGui(p, face, poster)
	bump(ctx, "posters")
end

local function placePosters(ctx: Ctx)
	local rng = ctx.rng
	local cap = ImperfectionDresser.CAPS.posters
	local nextPoster = rng:NextInteger(1, #ImperfectionDresser.POSTERS)
	-- inside a few bus shelters: on the back panel's inner (-Z) face
	local shelters = 0
	for _, stop in TownLayout.BUS_STOPS do
		if shelters >= 5 or not room(ctx, 1) then
			break
		end
		if rng:NextNumber() > 0.55 then
			continue
		end
		local base = CFrame.new(stop.position.X, 0, stop.position.Z) * CFrame.Angles(0, math.rad(stop.yaw), 0)
		-- panel spans local z 1.6..2.0 and y 0.5..9; the poster's back face is 0.05 inside it
		local z = 1.6 - POSTER_SIZE.Z / 2 + POSTER_EMBED
		local x = if rng:NextNumber() < 0.5 then -2.2 else 2.2
		posterPart(ctx, base * CFrame.new(x, 4.6, z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-2, 2))), Enum.NormalId.Front, nextPoster)
		nextPoster += 1
		shelters += 1
	end
	-- shop side walls with open ground beside them
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if (ctx.counts.posters or 0) >= cap or not room(ctx, 1) then
				return
			end
			if not ShopDresser.SHOP_USES[block.use] or rng:NextNumber() > 0.3 then
				continue
			end
			local cf, length, depth = ShopDresser.placement(block, TownLayout.ROADS)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local x = -depth / 2 + rng:NextNumber(2.5, math.max(2.6, math.min(8, depth - 2)))
			-- the ground in front of the poster must be open (not another building)
			local probe = cf * CFrame.new(x, 0, side * (length / 2 + 2.2))
			local rect = TownBuilder.rect(probe.Position.X, probe.Position.Z, cf.RightVector.X, cf.RightVector.Z, 1.5, 2)
			local blocked = false
			for _, b in ctx.world.blocks do
				if b.block ~= block and TownBuilder.rectsOverlap(rect, inflate(b.rect, 1)) then
					blocked = true
					break
				end
			end
			if blocked or not commonClear(ctx.world, rect, RIVER_MARGIN) then
				continue
			end
			local z = side * (length / 2 + POSTER_SIZE.Z / 2 - POSTER_EMBED)
			local tilt = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3)))
			-- the wall's outward normal is local +Z (Back face) or -Z (Front face)
			posterPart(ctx, cf * CFrame.new(x, rng:NextNumber(4.2, 5.6), z) * tilt, if side > 0 then Enum.NormalId.Back else Enum.NormalId.Front, nextPoster)
			nextPoster += 1
		end
	end
end

-- ---------------------------------------------------------------------- API

-- Returns a summary line for the log.
function ImperfectionDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "imperfections: no town"
	end
	local old = town:FindFirstChild("Imperfections")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Imperfections"
	local folders: { [string]: Folder } = {}
	for _, name in { "Road", "Markings", "Weeds", "Clutter" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		folders[name] = f
	end
	local ctx: Ctx = {
		rng = Random.new(ImperfectionDresser.SEED),
		used = 0,
		world = buildWorld(),
		patches = {},
		iron = {},
		marks = {},
		ground = {},
		folders = folders,
		counts = {},
	}
	local junctions = ImperfectionDresser.junctions(TownLayout.ROADS, TownLayout.ROUNDABOUTS)
	local rows = terraceBlocks()
	-- big off-road pieces first, then road wear, then the budget-filling dashes
	placeSkip(ctx, rows)
	placeBins(ctx, rows)
	placeCones(ctx)
	placePosters(ctx)
	placePatches(ctx, junctions)
	placeIron(ctx)
	placeGiveWays(ctx, junctions)
	placeWeeds(ctx)
	placeCentreLines(ctx)
	root.Parent = town
	local c = ctx.counts
	return ("imperfections: %d parts (patches %d, manholes %d, grates %d, give-ways %d, dashes %d, weed clumps %d, bins %d, cones %d, skips %d, posters %d)"):format(
		ctx.used,
		c.patches or 0,
		c.manholes or 0,
		c.grates or 0,
		c.giveWays or 0,
		c.dashes or 0,
		c.weedClumps or 0,
		c.bins or 0,
		c.cones or 0,
		c.skips or 0,
		c.posters or 0
	)
end

return ImperfectionDresser
