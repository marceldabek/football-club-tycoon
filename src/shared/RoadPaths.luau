--!strict
-- The line traffic and walkers actually follow along a TownLayout road. A
-- layout polyline turns 45 or 90 degrees at a single point, but the kit's bend
-- pieces are curved: following the raw polyline put a car 8 studs inside the
-- asphalt of a 90 bend (over the kerb, or in the oncoming lane) and 3 studs
-- inside a 45. RoadPaths.fillet replaces each corner with an arc of the kit
-- bend's own radius (RoadTiles.KIT_BEND90_RADIUS / KIT_BEND45_RADIUS).
--
-- Pure: no Instances. End points never move, so junction lookups made on the
-- layout's end points (TrafficMath.connections) still work on a filleted road.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)

local RoadPaths = {}

RoadPaths.MIN_TURN = math.rad(10) -- gentler than this is left as a corner
RoadPaths.SPLIT_TURN = math.rad(67.5) -- at or above: the 90 piece's radius, below: the 45's
RoadPaths.ARC_STEP = math.rad(15) -- one sample per this much turn
RoadPaths.MAX_SHARE = 0.45 -- of the shorter neighbouring segment an arc may use

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Arc samples (start to end inclusive) rounding the corner at `p`, entered along
-- unit `a` and left along unit `b`, or nil when the corner is kept as it is.
local function arc(p: Vector3, a: Vector3, b: Vector3, room: number, radius90: number, radius45: number): { Vector3 }?
	local turn = math.acos(math.clamp(a:Dot(b), -1, 1))
	if turn < RoadPaths.MIN_TURN or turn > math.rad(170) then
		return nil
	end
	local radius = if turn >= RoadPaths.SPLIT_TURN then radius90 else radius45
	local half = math.tan(turn / 2)
	local tangent = math.min(radius * half, room)
	if tangent < 1 then
		return nil
	end
	radius = tangent / half
	local sign = if a.X * b.Z - a.Z * b.X >= 0 then 1 else -1
	local start = p - a * tangent
	local centre = start + Vector3.new(-a.Z, 0, a.X) * (sign * radius)
	local spoke = start - centre
	local steps = math.max(2, math.ceil(turn / RoadPaths.ARC_STEP))
	local out: { Vector3 } = {}
	for k = 0, steps do
		local phi = sign * turn * k / steps
		local c, s = math.cos(phi), math.sin(phi)
		out[k + 1] = Vector3.new(centre.X + spoke.X * c - spoke.Z * s, p.Y, centre.Z + spoke.X * s + spoke.Z * c)
	end
	return out
end

-- `points` with every corner rounded. A closed polyline (first point == last
-- point) has its seam rounded too and stays closed.
function RoadPaths.fillet(points: { Vector3 }, radius90: number, radius45: number): { Vector3 }
	local n = #points
	if n < 3 then
		return table.clone(points)
	end
	local closed = (flat(points[1]) - flat(points[n])).Magnitude <= 1e-3

	local function corner(prev: Vector3, p: Vector3, nxt: Vector3): { Vector3 }?
		local inSeg, outSeg = flat(p - prev), flat(nxt - p)
		if inSeg.Magnitude < 1e-3 or outSeg.Magnitude < 1e-3 then
			return nil
		end
		local room = math.min(inSeg.Magnitude, outSeg.Magnitude) * RoadPaths.MAX_SHARE
		return arc(p, inSeg.Unit, outSeg.Unit, room, radius90, radius45)
	end

	local out: { Vector3 } = {}
	local seam = if closed then corner(points[n - 1], points[1], points[2]) else nil
	if seam then
		for _, q in seam do
			table.insert(out, q)
		end
	else
		table.insert(out, points[1])
	end
	for i = 2, n - 1 do
		local rounded = corner(points[i - 1], points[i], points[i + 1])
		if rounded then
			for _, q in rounded do
				table.insert(out, q)
			end
		else
			table.insert(out, points[i])
		end
	end
	table.insert(out, if seam then seam[1] else points[n])
	return out
end

-- TownLayout.ROADS with each road's points filleted at its kind's kit scale.
-- Same order and indices as TownLayout.ROADS. Built once.
local cached: { TownLayout.Road }? = nil
function RoadPaths.townRoads(): { TownLayout.Road }
	if cached then
		return cached
	end
	local out: { TownLayout.Road } = {}
	for i, road in TownLayout.ROADS do
		local scale = RoadTiles.SCALE[road.kind] or RoadTiles.STREET_SCALE
		local copy = table.clone(road)
		copy.points = RoadPaths.fillet(road.points, RoadTiles.KIT_BEND90_RADIUS * scale, RoadTiles.KIT_BEND45_RADIUS * scale)
		out[i] = copy
	end
	cached = out
	return out
end

return RoadPaths
