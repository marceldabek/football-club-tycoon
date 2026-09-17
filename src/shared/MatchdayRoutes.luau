--!strict
-- Pure pitch-local geometry for the matchday crowd (backlog G1.1): how fans
-- walk from the town (pedestrian gate) or the car park to the turnstiles, and
-- where stewards stand. Pitch centre is the origin, north is -Z, the entrance
-- side is -X, same convention as WorldBuilder/PlotGrounds. No Roblox services
-- are touched here, so this module is safe to require and test on the server,
-- the client, or a bare Luau VM.
--
-- Coordinates come from PlotGrounds.luau's layout comment (pedestrian gate at
-- x=-380 z -20..-4, footpath along z=-12 from x=-379 to x=-265, then north
-- along x=-265 to z=-187, then east along z=-187 to the forecourt edge
-- x=-190; car park x -350..-250, z 40..190) and WorldBuilder's turnstile
-- constants (SIDE_EDGE=121, END_EDGE=179, CORNER_Z=155,
-- TURNSTILE_Z = -(CORNER_Z + END_EDGE)/2 = -167, turnstile lanes at
-- x = -SIDE_EDGE = -121).

local MatchdayRoutes = {}

local ROUTE_Y = 0.3

local TURNSTILE_X = -121
local TURNSTILE_Z = -167 -- -(CORNER_Z + END_EDGE) / 2, CORNER_Z = 155, END_EDGE = 179

local function pt(x: number, z: number): Vector3
	return Vector3.new(x, ROUTE_Y, z)
end

export type Route = { Vector3 }

-- Shared with both routes: the footpath from the pedestrian gate meets the
-- leg coming up from the car park here, then both continue north and east
-- onto the forecourt together (PlotGrounds.luau footpath comment).
local JOIN = pt(-265, -12)
local NORTH_TURN = pt(-265, -187)
local FORECOURT_EDGE = pt(-190, -187)
local TURNSTILE = pt(TURNSTILE_X, TURNSTILE_Z)

MatchdayRoutes.ROUTES = {
	fromTown = {
		pt(-380, -12), -- pedestrian gate
		JOIN,
		NORTH_TURN,
		FORECOURT_EDGE,
		TURNSTILE,
	} :: Route,
	fromCarPark = {
		pt(-300, 115), -- car park centre
		pt(-350, 40), -- north-west corner of the car park
		JOIN,
		NORTH_TURN,
		FORECOURT_EDGE,
		TURNSTILE,
	} :: Route,
}

-- Standing spots for stewards: pedestrian gate (both sides), turnstiles (2
-- lanes) and the car park exit, as CFrames facing the fans walking past.
MatchdayRoutes.STEWARD_SPOTS = {
	CFrame.lookAt(Vector3.new(-380, 0, -22), Vector3.new(-370, 0, -22)), -- gate, south side
	CFrame.lookAt(Vector3.new(-380, 0, -2), Vector3.new(-370, 0, -2)), -- gate, north side
	CFrame.lookAt(Vector3.new(TURNSTILE_X, 0, TURNSTILE_Z - 5), Vector3.new(TURNSTILE_X - 10, 0, TURNSTILE_Z - 5)), -- turnstile lane A
	CFrame.lookAt(Vector3.new(TURNSTILE_X, 0, TURNSTILE_Z + 5), Vector3.new(TURNSTILE_X - 10, 0, TURNSTILE_Z + 5)), -- turnstile lane B
	CFrame.lookAt(Vector3.new(-350, 0, 38), Vector3.new(-265, 0, -12)), -- car park exit, facing the path to the gate
} :: { CFrame }

-- Total length of a route's polyline.
function MatchdayRoutes.length(route: Route): number
	local total = 0
	for i = 1, #route - 1 do
		total += (route[i + 1] - route[i]).Magnitude
	end
	return total
end

-- The position and forward-facing (XZ, normalized) direction `distance`
-- studs along `route`, clamped to the route's ends.
function MatchdayRoutes.pointAt(route: Route, distance: number): (Vector3, Vector3)
	local fallbackDir = Vector3.new(0, 0, -1)
	if #route == 1 then
		return route[1], fallbackDir
	end
	if distance <= 0 then
		local seg = route[2] - route[1]
		return route[1], if seg.Magnitude > 0 then seg.Unit else fallbackDir
	end
	local remaining = distance
	for i = 1, #route - 1 do
		local a, b = route[i], route[i + 1]
		local seg = b - a
		local segLen = seg.Magnitude
		if remaining <= segLen or i == #route - 1 then
			local t = if segLen > 0 then math.clamp(remaining / segLen, 0, 1) else 0
			local dir = if segLen > 0 then seg.Unit else fallbackDir
			return a:Lerp(b, t), dir
		end
		remaining -= segLen
	end
	return route[#route], fallbackDir
end

-- How many fans to show for a given attendance/capacity, clamped 0..48.
function MatchdayRoutes.fanCount(attendance: number, capacity: number): number
	if capacity <= 0 then
		return 0
	end
	local n = 12 + 36 * (attendance / capacity)
	return math.clamp(math.round(n), 0, 48)
end

return MatchdayRoutes
