--!strict
-- Pure geometry for town pedestrians (backlog F3.1): where the pavement is
-- relative to a TownLayout road, a mitred pavement line that follows the road
-- round its bends, ping-pong walking along that line, a cheap walk cycle, and
-- the ground height (pavement vs road-bridge footway) plus a river check.
-- No Roblox services or Instances are touched, so this is safe to require and
-- test anywhere. Presentation lives in Pedestrians.client.luau.
--
-- Heights mirror TownBuilder's Y table (it is server-only, so the client
-- cannot require it): pavement top 0.45; a road bridge deck top is road top
-- + 0.5 and its footways sit 0.25 above that. Footway lateral centre on a
-- deck is bridge.width / 2 + PAVEMENT_WIDTH / 2, the same as on the street.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)

local PedestrianMath = {}

export type SegmentRef = { roadIndex: number, segment: number }

PedestrianMath.PAVEMENT_TOP = RoadTiles.SURFACE_Y
-- v3 kit roads: the paved strip of a ModularRoads piece (unscaled studs from the
-- centreline, measured from the Straight mesh: carriageway edge 7.93, paving out to
-- 12.26, kerb about 0.7). Beyond it is the grass verge, which is where the v2
-- width-based offset put walkers.
PedestrianMath.KIT_PAVING_INNER = 8.6
PedestrianMath.KIT_PAVING_OUTER = 12.26
PedestrianMath.WALKER_HALF_WIDTH = 1
PedestrianMath.ROAD_TOP = { ring = 0.20, main = 0.21, residential = 0.22, lane = 0.23 } :: { [string]: number }
PedestrianMath.FOOTWAY_ABOVE_ROAD = 0.75 -- deck +0.5, footway +0.25
PedestrianMath.PARAPET_THICK = 1.5
PedestrianMath.MITER_MIN_COS = 0.5 -- a sharp bend's corner point is pushed out at most 2x the offset
PedestrianMath.STEP_LENGTH = 2.5 -- TEMP studs per step (one leg swing forward)
PedestrianMath.MAX_SWING = 0.55 -- TEMP radians of leg swing at full stride
PedestrianMath.BOB_HEIGHT = 0.12 -- TEMP studs of body rise at mid-stance

local FALLBACK_DIR = Vector3.new(0, 0, -1)

-- Roads whose pavements get walkers. Ring road is out-of-town dual carriageway
-- and lanes have no pavements (TownBuilder skips them).
local WALKABLE: { [string]: boolean } = { main = true, residential = true }

local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end

-- Perpendicular to `direction` in XZ, same handedness as TrafficMath.laneOffset.
local function perp(direction: Vector3): Vector3
	local n = Vector3.new(-direction.Z, 0, direction.X)
	return if n.Magnitude > 1e-6 then n.Unit else Vector3.new(1, 0, 0)
end

function PedestrianMath.isWalkableKind(kind: string): boolean
	return WALKABLE[kind] == true
end

-- Indices into `roads` whose kind has walkers.
function PedestrianMath.walkableRoadIndices(roads: { TownLayout.Road }): { number }
	local out: { number } = {}
	for i, road in roads do
		if PedestrianMath.isWalkableKind(road.kind) and #road.points >= 2 then
			table.insert(out, i)
		end
	end
	return out
end

-- Distance from the road centreline to the middle of its pavement.
function PedestrianMath.pavementDistance(roadWidth: number): number
	return roadWidth / 2 + TownLayout.PAVEMENT_WIDTH / 2
end

-- v3: distance from the centreline to the middle of the kit road's paved strip.
function PedestrianMath.kitPavementDistance(kind: string): number
	local scale = RoadTiles.SCALE[kind] or RoadTiles.SCALE.residential
	return scale * (PedestrianMath.KIT_PAVING_INNER + PedestrianMath.KIT_PAVING_OUTER) / 2
end

-- v3: how far a walker may stray either side of that line and keep both feet on it.
function PedestrianMath.kitPavementJitter(kind: string): number
	local scale = RoadTiles.SCALE[kind] or RoadTiles.SCALE.residential
	local half = scale * (PedestrianMath.KIT_PAVING_OUTER - PedestrianMath.KIT_PAVING_INNER) / 2
	return math.max(0, half - PedestrianMath.WALKER_HALF_WIDTH)
end

-- Offset from the road centreline to the middle of the pavement on `side`
-- (-1 or 1), perpendicular to `direction` in the XZ plane.
function PedestrianMath.pavementOffset(direction: Vector3, roadWidth: number, side: number): Vector3
	return perp(direction) * (side * PedestrianMath.pavementDistance(roadWidth))
end

-- ------------------------------------------------------------ pavement line

-- The pavement centreline on `side` of a road: one point per road point (so
-- segment i of the result runs alongside segment i of the road), mitred at
-- bends so the walker follows the corner instead of jumping across it.
-- Zero-length road segments borrow the nearest real segment's direction. A
-- closed road (first point == last point) mitres its seam as well.
-- `distance` overrides the width-based pavement distance (kitPavementDistance).
function PedestrianMath.offsetPolyline(points: { Vector3 }, roadWidth: number, side: number, distance: number?): { Vector3 }
	local n = #points
	local out: { Vector3 } = {}
	if n == 0 then
		return out
	end
	local dist = side * (distance or PedestrianMath.pavementDistance(roadWidth))
	if n == 1 then
		out[1] = points[1] + perp(FALLBACK_DIR) * dist
		return out
	end

	local dirs: { Vector3 | false } = {}
	local anyDir: Vector3? = nil
	for i = 1, n - 1 do
		local seg = flat(points[i + 1] - points[i])
		if seg.Magnitude > 1e-6 then
			dirs[i] = seg.Unit
			if not anyDir then
				anyDir = seg.Unit
			end
		else
			dirs[i] = false
		end
	end
	local closed = (flat(points[1]) - flat(points[n])).Magnitude <= 1e-3

	-- nearest real segment direction at or before index j (wrapping if closed)
	local function dirBack(j: number): Vector3?
		for k = j, 1, -1 do
			local d = dirs[k]
			if d then
				return d
			end
		end
		if closed then
			for k = n - 1, j + 1, -1 do
				local d = dirs[k]
				if d then
					return d
				end
			end
		end
		return nil
	end
	-- nearest real segment direction at or after index j (wrapping if closed)
	local function dirForward(j: number): Vector3?
		for k = j, n - 1 do
			local d = dirs[k]
			if d then
				return d
			end
		end
		if closed then
			for k = 1, math.min(j - 1, n - 1) do
				local d = dirs[k]
				if d then
					return d
				end
			end
		end
		return nil
	end

	for i = 1, n do
		local inDir: Vector3? = nil
		local outDir: Vector3? = nil
		if i > 1 or closed then
			inDir = dirBack(if i > 1 then i - 1 else n - 1)
		end
		if i < n or closed then
			outDir = dirForward(if i < n then i else 1)
		end
		local a = inDir or outDir or anyDir or FALLBACK_DIR
		local b = outDir or inDir or anyDir or FALLBACK_DIR
		local na, nb = perp(a), perp(b)
		local m = na + nb
		local offset: Vector3
		if m.Magnitude < 1e-6 then
			offset = na * dist -- full reversal: no sensible mitre, keep one side
		else
			local mu = m.Unit
			local cosHalf = math.max(mu:Dot(na), PedestrianMath.MITER_MIN_COS)
			offset = mu * (dist / cosHalf)
		end
		out[i] = points[i] + offset
	end
	return out
end

-- cumulative[i] = length along `points` from point 1 to point i (XZ).
function PedestrianMath.cumulativeLengths(points: { Vector3 }): { number }
	local out: { number } = {}
	local total = 0
	for i = 1, #points do
		if i > 1 then
			total += flat(points[i] - points[i - 1]).Magnitude
		end
		out[i] = total
	end
	return out
end

-- -------------------------------------------------------------------- walking

-- Moves `delta` (>= 0) studs along a line of `length` in `direction` (1 / -1).
-- An open line bounces off its ends (the walker turns round); a closed one
-- wraps. Returns the new distance and direction.
function PedestrianMath.advance(distance: number, direction: number, delta: number, length: number, closed: boolean): (number, number)
	if length <= 1e-6 then
		return 0, direction
	end
	local d = distance + direction * delta
	if closed then
		return d % length, direction
	end
	local dir = direction
	for _ = 1, 8 do
		if d > length then
			d = 2 * length - d
			dir = -1
		elseif d < 0 then
			d = -d
			dir = 1
		else
			break
		end
	end
	return math.clamp(d, 0, length), dir
end

-- Walk cycle at time `t` for a walker moving at `speed` studs/s: a small
-- vertical bob (0..BOB_HEIGHT, highest when the legs pass vertical) and a leg
-- swing angle in radians (-MAX_SWING..MAX_SWING). Standing still gives 0, 0.
function PedestrianMath.walkCycle(t: number, speed: number): (number, number)
	if speed <= 0 then
		return 0, 0
	end
	local phase = t * speed * math.pi / PedestrianMath.STEP_LENGTH
	local swing = math.sin(phase) * PedestrianMath.MAX_SWING
	local bob = math.abs(math.cos(phase)) * PedestrianMath.BOB_HEIGHT
	return bob, swing
end

-- ------------------------------------------------------------ spawn candidates

-- Centreline segments of the given roads that pass within `radius` of `p`.
function PedestrianMath.segmentsNear(roads: { TownLayout.Road }, indices: { number }, p: Vector3, radius: number): { SegmentRef }
	local out: { SegmentRef } = {}
	for _, roadIndex in indices do
		local road = roads[roadIndex]
		if not road then
			continue
		end
		local reach = radius + PedestrianMath.pavementDistance(road.width)
		for s = 1, #road.points - 1 do
			if TownLayout.segmentDistance(p, road.points[s], road.points[s + 1]) <= reach then
				table.insert(out, { roadIndex = roadIndex, segment = s })
			end
		end
	end
	return out
end

-- ---------------------------------------------------------- ground and river

-- The road bridge whose deck (carriageway + both footways) covers `p`, or nil.
-- `lengthSlack` extends the deck along its length at both ends.
function PedestrianMath.roadBridgeAt(p: Vector3, bridges: { TownLayout.Bridge }, lengthSlack: number): TownLayout.Bridge?
	for _, bridge in bridges do
		if bridge.kind ~= "road" then
			continue
		end
		local seg = flat(bridge.to - bridge.from)
		local segLen = seg.Magnitude
		if segLen < 1e-6 then
			continue
		end
		local u = seg / segLen
		local ap = flat(p - bridge.from)
		local along = ap:Dot(u)
		if along < -lengthSlack or along > segLen + lengthSlack then
			continue
		end
		local across = math.abs(ap:Dot(perp(u)))
		local halfDeck = bridge.width / 2 + TownLayout.PAVEMENT_WIDTH + PedestrianMath.PARAPET_THICK
		if across <= halfDeck then
			return bridge
		end
	end
	return nil
end

-- Top of whatever a walker on a `kind` road's pavement stands on at `p`.
function PedestrianMath.groundY(p: Vector3, kind: string, bridges: { TownLayout.Bridge }): number
	local bridge = PedestrianMath.roadBridgeAt(p, bridges, 0)
	if bridge then
		local roadTop = PedestrianMath.ROAD_TOP[kind] or PedestrianMath.ROAD_TOP.lane
		-- humped decks (X31): ramps up from each end, level over the water
		local along = TownLayout.bridgeAlong(bridge, p)
		return roadTop + PedestrianMath.FOOTWAY_ABOVE_ROAD + TownLayout.bridgeRise(bridge, along)
	end
	return PedestrianMath.PAVEMENT_TOP
end

-- True if `p` is over the river's water (plus `margin`).
function PedestrianMath.inRiver(p: Vector3, river: TownLayout.River, margin: number): boolean
	return TownLayout.distanceToPolyline(p, river.points) <= river.width / 2 + margin
end

-- True if a walker must not stand at `p`: over the water and not on a road
-- bridge (the deck test is stretched by `bridgeSlack` so a pavement corner
-- beside a deck end is not mistaken for the river).
function PedestrianMath.blockedByRiver(p: Vector3, river: TownLayout.River, bridges: { TownLayout.Bridge }, bridgeSlack: number): boolean
	return PedestrianMath.inRiver(p, river, 0) and PedestrianMath.roadBridgeAt(p, bridges, bridgeSlack) == nil
end

-- X80: true if `p` is on a roundabout's carriageway disc (TownBuilder lays no
-- pavement there), so a walker turns round at its edge like at the river.
function PedestrianMath.onRoundabout(p: Vector3, roundabouts: { TownLayout.Roundabout }): boolean
	for _, r in roundabouts do
		if Vector3.new(p.X - r.centre.X, 0, p.Z - r.centre.Z).Magnitude < r.radius then
			return true
		end
	end
	return false
end

return PedestrianMath
