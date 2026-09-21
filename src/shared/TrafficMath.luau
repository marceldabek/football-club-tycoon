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

-- Roundabouts. A car does not follow its road through a roundabout's centre: it
-- leaves the road where the road crosses the roundabout's ring (an "arm"), drives
-- the ring the UK way round (island on its right) and rejoins a road at another
-- arm. Driving the arc itself keeps its speed steady; the old approach projected
-- the straight-through position onto the ring, which swept a car passing 4 studs
-- from the centre round the ring at about 7 times its road speed.
--
-- Angles are atan2(z, x) about the centre; circulation is towards larger angles.

export type RoundaboutLike = { centre: Vector3, radius: number }

export type RingArm = {
	roadIndex: number,
	distance: number, -- along the road, where its centreline crosses the ring
	outward: number, -- travel direction along the polyline (1 / -1) that leaves the roundabout
	entryAngle: number, -- where an inbound car's lane meets the ring
	exitAngle: number, -- where an outbound car's lane leaves it
	heading: Vector3, -- unit, outward along the road
}

-- Every place a road's centreline crosses the circle of `ringRadius` round `centre`.
-- `laneOffset(roadIndex)` is how far left of the centreline that road's traffic drives.
function TrafficMath.ringArms(roads: { RoadLike }, centre: Vector3, ringRadius: number, laneOffset: (number) -> number): { RingArm }
	local out: { RingArm } = {}
	local c = flat(centre)
	for roadIndex, road in roads do
		local cumulative = 0
		for i = 1, #road.points - 1 do
			local a, b = flat(road.points[i]), flat(road.points[i + 1])
			local seg = b - a
			local len = seg.Magnitude
			if len > 1e-6 then
				local dir = seg / len
				-- |a + dir * t - c| = ringRadius
				local rel = a - c
				local half = rel:Dot(dir)
				local disc = half * half - (rel:Dot(rel) - ringRadius * ringRadius)
				if disc > 0 then
					local root = math.sqrt(disc)
					for _, t in { -half - root, -half + root } do
						-- half-open, so a crossing on a shared vertex is counted once
						if t >= 0 and t < len then
							local p = a + dir * t
							local outward = if (p - c):Dot(dir) > 0 then 1 else -1
							local heading = dir * outward
							local right = Vector3.new(-heading.Z, 0, heading.X)
							local lane = laneOffset(roadIndex)
							local entry = p + right * lane - c -- inbound: heading -heading, its left is +right
							local exit = p - right * lane - c
							table.insert(out, {
								roadIndex = roadIndex,
								distance = cumulative + t,
								outward = outward,
								entryAngle = math.atan2(entry.Z, entry.X),
								exitAngle = math.atan2(exit.Z, exit.X),
								heading = heading,
							})
						end
					end
				end
			end
			cumulative += len
		end
	end
	return out
end

-- The inbound arm a car reaches moving from `from` to `to` along road `roadIndex`
-- (travel direction `direction`), or nil. `length` is given for a closed road, so
-- a step across its seam still finds an arm on the other side.
function TrafficMath.armReached(arms: { RingArm }, roadIndex: number, from: number, to: number, direction: number, length: number?): RingArm?
	local lo, hi = math.min(from, to), math.max(from, to)
	for _, arm in arms do
		if arm.roadIndex == roadIndex and arm.outward == -direction then
			for _, shift in { 0, length or 0, -(length or 0) } do
				local d = arm.distance + shift
				if d >= lo and d <= hi then
					return arm
				end
			end
		end
	end
	return nil
end

-- Radians a car drives round the ring from `entry` to `leave`. Leaving by the arm
-- it came in on is a full lap less the width of the road, not a reverse.
function TrafficMath.ringSweep(entry: RingArm, leave: RingArm): number
	local sweep = (leave.exitAngle - entry.entryAngle) % (2 * math.pi)
	return sweep
end

-- Position and unit tangent (the way traffic circulates) at `angle` on the ring.
function TrafficMath.ringPose(centre: Vector3, ringRadius: number, angle: number): (Vector3, Vector3)
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(centre.X + c * ringRadius, centre.Y, centre.Z + s * ringRadius), Vector3.new(-s, 0, c)
end

-- A car's heading `travelled` studs into an arc of `arcLength`: it swings from the
-- road it came in on (`inbound`, unit, its heading as it arrived) onto the ring's
-- tangent over `blend` studs, and out to `outbound` over the last `blend` studs.
function TrafficMath.ringHeading(tangent: Vector3, inbound: Vector3, outbound: Vector3, travelled: number, arcLength: number, blend: number): Vector3
	local reach = math.min(blend, arcLength / 2)
	local mixed = tangent
	if reach > 1e-6 and travelled < reach then
		mixed = inbound:Lerp(tangent, travelled / reach)
	elseif reach > 1e-6 and arcLength - travelled < reach then
		mixed = outbound:Lerp(tangent, math.max(arcLength - travelled, 0) / reach)
	end
	return if mixed.Magnitude > 1e-6 then mixed.Unit else tangent
end

-- Free speed eased down to `slowSpeed` over the last `zone` studs before (and the
-- first `zone` studs after) a roundabout, so a car neither arrives at full speed
-- nor leaves at it. `gap` is the distance along the road to the nearest arm.
function TrafficMath.easeNear(freeSpeed: number, slowSpeed: number, gap: number, zone: number): number
	if zone <= 0 or gap >= zone or slowSpeed >= freeSpeed then
		return freeSpeed
	end
	local t = math.clamp(gap / zone, 0, 1)
	return slowSpeed + (freeSpeed - slowSpeed) * (t * t * (3 - 2 * t))
end

-- X88: true if any of `positions` is within `clear` studs (XZ) of `point`.
function TrafficMath.junctionBusy(point: Vector3, positions: { Vector3 }, clear: number): boolean
	for _, p in positions do
		if Vector3.new(p.X - point.X, 0, p.Z - point.Z).Magnitude < clear then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------ spacing

-- Centre-to-centre distance a follower keeps behind its leader: both half
-- lengths plus `clear` studs of daylight. (A fixed 14 between centres put a car's
-- bonnet 4 studs inside a 27-long bus.)
function TrafficMath.followGap(leaderHalfLength: number, followerHalfLength: number, clear: number): number
	return leaderHalfLength + followerHalfLength + clear
end

-- The follower's speed for this frame. Free-flowing beyond 2 x minGap, eased
-- down to the leader's speed at minGap, and slower than the leader inside it so
-- the gap opens again. Never negative, never above `freeSpeed`.
function TrafficMath.followSpeed(freeSpeed: number, leaderSpeed: number, gap: number, minGap: number): number
	if minGap <= 0 or gap >= 2 * minGap then
		return freeSpeed
	end
	local cap: number
	if gap >= minGap then
		cap = leaderSpeed + math.max(freeSpeed - leaderSpeed, 0) * ((gap - minGap) / minGap)
	else
		cap = leaderSpeed * math.max(gap, 0) / minGap
	end
	return math.max(0, math.min(freeSpeed, cap))
end

-- Index i such that cumulative[i - 1] <= r * total < cumulative[i], for picking
-- an entry with probability proportional to its weight. `cumulative` is the
-- running sum of the weights; `r` is in [0, 1). Returns nil for an empty list.
function TrafficMath.weightedIndex(cumulative: { number }, r: number): number?
	local n = #cumulative
	if n == 0 or cumulative[n] <= 0 then
		return nil
	end
	local target = math.clamp(r, 0, 1) * cumulative[n]
	for i = 1, n do
		if target < cumulative[i] then
			return i
		end
	end
	return n
end

-- True if any of `positions` is within `clear` studs (XZ) of `point`. (Same test
-- as junctionBusy; named for the spawn check.)
function TrafficMath.crowded(point: Vector3, positions: { Vector3 }, clear: number): boolean
	return TrafficMath.junctionBusy(point, positions, clear)
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
