--!strict
-- Pure geometry for town traffic (backlog F2.1): following a TownLayout.Road
-- polyline, picking a lane offset, and finding the next road to join when a
-- car reaches a polyline end. No Roblox services are touched here, so this
-- module is safe to require and test on the server, the client, or a bare
-- Luau VM. Presentation (Traffic.client.luau) decides what to spawn/move;
-- this module only answers geometry questions.
--
-- Coordinates follow TownLayout: XZ plane, Y ignored for all distance/side
-- work, UK traffic drives on the left.

local TrafficMath = {}

-- A road-shaped table: only the fields this module reads. TownLayout.Road
-- satisfies this shape (it also carries name/kind, which we don't need here).
export type RoadLike = { points: { Vector3 }, width: number }

export type Connection = { roadIndex: number, distance: number, direction: number }

local FALLBACK_DIR = Vector3.new(0, 0, -1)

-- Flattens to the XZ plane (Y dropped) so all distance work ignores height.
local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end

-- ----------------------------------------------------------------- length

-- Total length of a polyline (sum of segment lengths, XZ only via Magnitude
-- on the full vector -- Y is expected to be constant/0 for road points).
function TrafficMath.polylineLength(points: { Vector3 }): number
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end
	return total
end

-- True if a polyline's first and last points coincide within eps (e.g. the
-- Ring Road, which lists its start point again as its last point).
function TrafficMath.isClosed(points: { Vector3 }, eps: number): boolean
	if #points < 2 then
		return false
	end
	return (flat(points[1]) - flat(points[#points])).Magnitude <= eps
end

-- The position and forward-facing (XZ, normalized) direction `distance`
-- studs along `points`. An open polyline clamps to its ends; a closed one
-- (first point == last point) wraps, so a car can drive through the seam
-- without a special case at the join.
function TrafficMath.pointAt(points: { Vector3 }, distance: number): (Vector3, Vector3)
	if #points == 0 then
		return Vector3.zero, FALLBACK_DIR
	end
	if #points == 1 then
		return points[1], FALLBACK_DIR
	end

	local total = TrafficMath.polylineLength(points)
	local d = distance
	if TrafficMath.isClosed(points, 1e-3) and total > 1e-6 then
		d = d % total
		if d < 0 then
			d += total
		end
	else
		d = math.clamp(d, 0, total)
	end

	local remaining = d
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = b - a
		local segLen = seg.Magnitude
		if remaining <= segLen or i == #points - 1 then
			local t = if segLen > 1e-6 then math.clamp(remaining / segLen, 0, 1) else 0
			local dir = if segLen > 1e-6 then seg.Unit else FALLBACK_DIR
			return a:Lerp(b, t), dir
		end
		remaining -= segLen
	end
	return points[#points], FALLBACK_DIR
end

-- ------------------------------------------------------------------- lane

-- Sideways offset from the polyline centreline, perpendicular to `direction`
-- in the XZ plane. `side` is a signed multiplier: UK left-hand traffic uses
-- side = -1, giving an offset of -(width/4) -- a quarter of the carriageway
-- each side of centre, i.e. the middle of that direction's lane.
function TrafficMath.laneOffset(direction: Vector3, width: number, side: number): Vector3
	local perp = Vector3.new(-direction.Z, 0, direction.X)
	if perp.Magnitude > 1e-6 then
		perp = perp.Unit
	end
	return perp * (side * (width / 4))
end

-- F3.3: a cyclist rides `inset` studs in from the kerb on the left-hand side
-- (the same side laneOffset(..., -1) drives on).
function TrafficMath.kerbOffset(direction: Vector3, width: number, inset: number): Vector3
	local perp = Vector3.new(-direction.Z, 0, direction.X)
	if perp.Magnitude > 1e-6 then
		perp = perp.Unit
	end
	return perp * -(math.max(width / 2 - inset, 0))
end

-- --------------------------------------------------------------- junctions

-- Distance-along, closest point, and closest XZ distance from `p` to the
-- nearest point of a polyline.
local function nearestOnPolyline(points: { Vector3 }, p: Vector3): (number, Vector3, number)
	local flatP = flat(p)
	local bestDistAlong, bestPoint, bestDist = 0, points[1], math.huge
	local cumulative = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = b - a
		local segLen = seg.Magnitude
		local t = 0
		if segLen > 1e-6 then
			local ap = flatP - flat(a)
			local abFlat = flat(seg)
			t = math.clamp(ap:Dot(abFlat) / (segLen * segLen), 0, 1)
		end
		local closest = a:Lerp(b, t)
		local d = (flatP - flat(closest)).Magnitude
		if d < bestDist then
			bestDist = d
			bestDistAlong = cumulative + t * segLen
			bestPoint = closest
		end
		cumulative += segLen
	end
	return bestDistAlong, bestPoint, bestDist
end

-- Roads a car can join when it reaches one end of roads[roadIndex] (the last
-- point if atEnd, otherwise the first point). Two kinds of join:
--   * a shared endpoint: another road's start or end lies within `tolerance`
--     of this end (e.g. a plot lane starting exactly on the ring road).
--   * a mid-road junction: another road passes within its own width of this
--     end (e.g. a residential road that meets a main road away from either
--     of the main road's own ends) -- the car joins at the nearest point
--     along that road and either direction is valid, so both are returned.
-- Returns {} when nothing is close enough; the caller then U-turns.
function TrafficMath.connections(roads: { RoadLike }, roadIndex: number, atEnd: boolean, tolerance: number): { Connection }
	local own = roads[roadIndex]
	local out: { Connection } = {}
	if not own or #own.points == 0 then
		return out
	end
	local endPoint = if atEnd then own.points[#own.points] else own.points[1]

	for i, road in roads do
		if i == roadIndex or #road.points == 0 then
			continue
		end
		local width = road.width
		local tolA = tolerance + width / 2

		local roadStart, roadEnd = road.points[1], road.points[#road.points]
		local dStart = (flat(endPoint) - flat(roadStart)).Magnitude
		local dEnd = (flat(endPoint) - flat(roadEnd)).Magnitude
		local matchedStart = dStart <= tolA
		local matchedEnd = dEnd <= tolA and #road.points > 1
		if matchedStart then
			table.insert(out, { roadIndex = i, distance = 0, direction = 1 })
		end
		if matchedEnd then
			table.insert(out, { roadIndex = i, distance = TrafficMath.polylineLength(road.points), direction = -1 })
		end

		if not (matchedStart or matchedEnd) then
			local distAlong, closest, closeness = nearestOnPolyline(road.points, endPoint)
			local nearOwnEnd = (flat(closest) - flat(roadStart)).Magnitude <= tolA
				or (flat(closest) - flat(roadEnd)).Magnitude <= tolA
			if closeness <= width and not nearOwnEnd then
				table.insert(out, { roadIndex = i, distance = distAlong, direction = 1 })
				table.insert(out, { roadIndex = i, distance = distAlong, direction = -1 })
			end
		end
	end

	return out
end

-- X79: roundabout islands. TownBuilder paints each island at ISLAND_SHARE of
-- the roundabout's radius; a car closer than island + clearance to a centre is
-- pushed out onto that ring, heading along it (blended with its road heading
-- by how deep it was), so it drives round the island instead of over it.
TrafficMath.ISLAND_SHARE = 0.35

export type RoundaboutLike = { centre: Vector3, radius: number }

function TrafficMath.aroundIslands(pos: Vector3, direction: Vector3, roundabouts: { RoundaboutLike }, clearance: number): (Vector3, Vector3)
	for _, r in roundabouts do
		local ring = r.radius * TrafficMath.ISLAND_SHARE + clearance
		local offset = Vector3.new(pos.X - r.centre.X, 0, pos.Z - r.centre.Z)
		local d = offset.Magnitude
		if d < ring then
			-- dead centre: go round on the left, the way the lane offset already points
			local radial = if d > 1e-3 then offset / d else Vector3.new(direction.Z, 0, -direction.X)
			local tangent = Vector3.new(-radial.Z, 0, radial.X)
			if tangent:Dot(direction) < 0 then
				tangent = -tangent
			end
			local depth = 1 - d / ring
			local blended = direction * (1 - depth) + tangent * depth
			local heading = if blended.Magnitude > 1e-6 then blended.Unit else tangent
			return Vector3.new(r.centre.X, pos.Y, r.centre.Z) + radial * ring, heading
		end
	end
	return pos, direction
end

-- F2.2 bus stops: distances along a road's polyline where a bus should pull
-- up, for every stop within `maxOffset` studs of the road. Sorted ascending.
function TrafficMath.stopDistances(points: { Vector3 }, stops: { Vector3 }, maxOffset: number): { number }
	local out = {}
	if #points < 2 then
		return out
	end
	for _, stop in stops do
		local along, _, offset = nearestOnPolyline(points, stop)
		if offset <= maxOffset then
			table.insert(out, along)
		end
	end
	table.sort(out)
	return out
end

-- Pure: the stop distance a bus passed moving from `from` to `to` along the
-- road (either direction), or nil. Only one per step: the first reached.
function TrafficMath.passedStop(from: number, to: number, stops: { number }): number?
	if to >= from then
		for _, d in stops do
			if d > from and d <= to then
				return d
			end
		end
	else
		for i = #stops, 1, -1 do
			local d = stops[i]
			if d < from and d >= to then
				return d
			end
		end
	end
	return nil
end

return TrafficMath
