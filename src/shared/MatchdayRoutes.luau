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

-- X91 (roadmap G1 "queues, barriers"): crowd-control barrier sections either
-- side of the final walk from the forecourt edge to the turnstiles, pitch-local
-- CFrames at ground level looking along the walk. Sections are BARRIER_LENGTH
-- long with small gaps; they start BARRIER_START in from the forecourt edge and
-- stop BARRIER_STOP short of the turnstile piers. Fans walk within +-2.5 of the
-- line, so +-BARRIER_OFFSET keeps them in the lane.
MatchdayRoutes.BARRIER_LENGTH = 7
MatchdayRoutes.BARRIER_OFFSET = 5
local BARRIER_STEP = 7.6
local BARRIER_START = 6
local BARRIER_STOP = 16
function MatchdayRoutes.barrierSections(): { CFrame }
	local a, b = FORECOURT_EDGE, TURNSTILE
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = along.Magnitude
	local dir = along.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local out = {}
	local d = BARRIER_START + MatchdayRoutes.BARRIER_LENGTH / 2
	while d + MatchdayRoutes.BARRIER_LENGTH / 2 <= len - BARRIER_STOP do
		for _, s in { -1, 1 } do
			local c = Vector3.new(a.X, 0, a.Z) + dir * d + side * s * MatchdayRoutes.BARRIER_OFFSET
			table.insert(out, CFrame.lookAt(c, c + dir))
		end
		d += BARRIER_STEP
	end
	return out
end

-- X104 (roadmap G1 "queues"): fans standing in two short lines behind the
-- turnstile stewards before kick-off. Pitch-local ground CFrames facing the
-- turnstiles, filled alternately left/right from QUEUE_START back along the
-- walk, QUEUE_LANE either side of it (inside the barriers). Only in PreMatch:
-- once the game is on everyone is in. TEMP numbers.
MatchdayRoutes.QUEUE_MAX = 14
MatchdayRoutes.QUEUE_START = 4
MatchdayRoutes.QUEUE_SPACING = 2.2
MatchdayRoutes.QUEUE_LANE = 3.2
function MatchdayRoutes.queueCount(attendance: number, capacity: number, phase: any): number
	if phase ~= "PreMatch" or capacity <= 0 or attendance <= 0 then
		return 0
	end
	return math.clamp(math.round(4 + 10 * (attendance / capacity)), 0, MatchdayRoutes.QUEUE_MAX)
end

function MatchdayRoutes.queueSpots(count: number): { CFrame }
	local a = Vector3.new(TURNSTILE.X, 0, TURNSTILE.Z)
	local back = Vector3.new(FORECOURT_EDGE.X - a.X, 0, FORECOURT_EDGE.Z - a.Z).Unit
	local side = Vector3.new(-back.Z, 0, back.X)
	local out = {}
	for i = 1, math.min(count, MatchdayRoutes.QUEUE_MAX) do
		local line = if i % 2 == 1 then -1 else 1
		local d = MatchdayRoutes.QUEUE_START + math.floor((i - 1) / 2) * MatchdayRoutes.QUEUE_SPACING
		local c = a + back * d + side * line * MatchdayRoutes.QUEUE_LANE
		table.insert(out, CFrame.lookAt(c, c - back))
	end
	return out
end

-- X93 (roadmap H1 "media presence"): an outside-broadcast van on the forecourt
-- on matchday once the club draws a crowd. Pitch-local ground CFrame, long axis
-- along local X, clear of the team coach (x -160..-126, z -221..-213) and the
-- barriered walk to the turnstiles. TEMP thresholds.
MatchdayRoutes.MEDIA_VAN = CFrame.new(-176, 0, -209) * CFrame.Angles(0, math.pi / 2, 0)
MatchdayRoutes.MEDIA_TIER = 2
MatchdayRoutes.MEDIA_ATTENDANCE = 400
function MatchdayRoutes.hasMedia(tier: number, attendance: number): boolean
	return tier >= MatchdayRoutes.MEDIA_TIER or attendance >= MatchdayRoutes.MEDIA_ATTENDANCE
end

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

-- Matchday cars in the club car park (backlog G1.2). Bay centres match
-- PlotGrounds' bay lines (pitch-local): a west row past the road mouth and a
-- back-to-back double row. Kept here so the client can place cars without
-- requiring a server module. yaw 0 = the car's length along local X.
local BAY_W, BAY_D = 9, 18
local PARK_AX0, PARK_AZ0, PARK_AZ1 = -349, 41, 189 -- asphalt inside the kerb
local ENTRY_CLEAR_Z = 104
local MID_ROW_X = PARK_AX0 + BAY_D + 24

local function bayRow(out: { Vector3 }, x0: number, z0: number, z1: number)
	local z = z0
	while z + BAY_W <= z1 + 1e-6 do
		table.insert(out, Vector3.new(x0 + BAY_D / 2, 0, z + BAY_W / 2))
		z += BAY_W
	end
end

function MatchdayRoutes.carParkBays(): { Vector3 }
	local out = {}
	bayRow(out, PARK_AX0, ENTRY_CLEAR_Z, PARK_AZ1 - 6)
	bayRow(out, MID_ROW_X, PARK_AZ0 + 8, PARK_AZ1 - 6)
	bayRow(out, MID_ROW_X + BAY_D, PARK_AZ0 + 8, PARK_AZ1 - 6)
	return out
end

-- How many bays fill on matchday: a trickle for a tiny crowd, full at a
-- TEMP 1,500 attendance (bigger crowds come by bus and on foot).
MatchdayRoutes.CARS_FULL_AT = 1500 -- TEMP

function MatchdayRoutes.parkedCars(attendance: number, bays: number): number
	if bays <= 0 or attendance <= 0 then
		return 0
	end
	local share = math.clamp(attendance / MatchdayRoutes.CARS_FULL_AT, 0.1, 1)
	return math.clamp(math.round(bays * share), 1, bays)
end

return MatchdayRoutes
