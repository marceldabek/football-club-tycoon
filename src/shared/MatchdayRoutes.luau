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
-- along x=-265 to z=-187, then east along z=-187 to the NW turnstile block;
-- car park x -350..-250, z 40..190, path along z=187 to the SW block) and
-- GroundEnvelope (#15, ground plan spec s2): turnstile blocks in the west
-- ground wall (x -201) at z -200..-175 and 175..200, lanes on z -187 / 187.
-- Fans stop just outside the block's street face (x -205) and go in.
--
-- Lane A2 (#14/#10, ground plan spec s2 "Fan routes"): a fan's route runs
-- from where they come from (the pedestrian gate, the car park) through a
-- turnstile block, across the concourse and into their own stand: through a
-- rear gate / vomitory at the back of a stand that has them, or round the
-- pitch-side paving to the foot of its end stairs. Leaving fans walk a route
-- backwards, so every route starts outside (street gate or car park) and ends
-- in a stand: whichever way out they take -- back through the turnstiles, or
-- the north / east exit gates and round the walk-round loop -- they only ever
-- vanish at a street gate or the car park (#10). fanRoutes() builds the set
-- for a club's current stands; the concourse lanes are chosen to clear every
-- stand level, the catering (ConcourseLayout) and the huts, which
-- MatchdayRoutesTest checks level by level.

local Config = require(script.Parent.Config)
local ConcourseLayout = require(script.Parent.ConcourseLayout)
local Pitch = require(script.Parent.Pitch)
local StandAccess = require(script.Parent.StandAccess)

local MatchdayRoutes = {}

local ROUTE_Y = 0.3

local TURNSTILE_X = -206
local TURNSTILE_Z = -187 -- GroundEnvelope.APPROACH_Z.NWTurnstiles
local SW_TURNSTILE_Z = 187

local function pt(x: number, z: number): Vector3
	return Vector3.new(x, ROUTE_Y, z)
end

export type Route = { Vector3 }

-- The footpath from the pedestrian gate turns north here, then east along
-- z -187 to the NW turnstiles (PlotGrounds.luau footpath comment).
local STREET_GATE = pt(-380, -12)
local JOIN = pt(-265, -12)
local NORTH_TURN = pt(-265, -187)
-- where the barriered approach to the NW block starts (was the old forecourt's edge)
local FORECOURT_EDGE = NORTH_TURN
local TURNSTILE = pt(TURNSTILE_X, TURNSTILE_Z)
local SW_TURNSTILE = pt(TURNSTILE_X, SW_TURNSTILE_Z)
local CAR_PARK = pt(-300, 115) -- car park centre
local SW_APPROACH = pt(-255, SW_TURNSTILE_Z) -- the car park's south-east corner, on the SW turnstile path
-- the walk-round loop's centre lines (PlotGrounds buildWalkRoundLoop: west
-- legs x -234..-226, north/south legs z +-267..+-275, east leg x 208..216)
local LOOP_W, LOOP_Z, LOOP_E = -230, 271, 212

-- The two ways in, street / car park to just inside the block. `s` is -1 for
-- the NW half of the ground and +1 for the SW half, here and below.
local function outside(s: number): { Vector3 }
	if s < 0 then
		return { STREET_GATE, JOIN, NORTH_TURN, TURNSTILE, pt(-190, TURNSTILE_Z) }
	end
	return { CAR_PARK, SW_APPROACH, SW_TURNSTILE, pt(-190, SW_TURNSTILE_Z) }
end

-- Concourse lanes inside the wall, clear of everything at every stand level:
-- up the west strip at x -164 (between the TV van's and the team coach's
-- spots) to the lane behind the end stand (z +-240); round the far corner past
-- the mast and the corner toilet block to the lane behind the East stand
-- (x 178); or through the open corner between the west wing and the end stand
-- onto the pitch-side paving, from where every stand's end stairs are reached.
local LANE_END_Z = 240
local LANE_EAST_X = 178
local PITCHSIDE_Z = 173 -- between the end stands' fronts (179) and the scoreboard / low wall
local PITCHSIDE_X = 114.5 -- between the low wall (108) and the side stands' fronts (121)

local function lanePoint(s: number, x: number, z: number): Vector3
	return pt(x, s * z)
end

local function appendAll(to: { Vector3 }, from: { Vector3 })
	for _, p in from do
		table.insert(to, p)
	end
end

local function toEndLane(s: number): { Vector3 }
	return { lanePoint(s, -164, 196), lanePoint(s, -164, LANE_END_Z) }
end
local function toPitchside(s: number): { Vector3 }
	return { lanePoint(s, -164, 196), lanePoint(s, -113, PITCHSIDE_Z) }
end
-- From the end lane round the far corner to the east lane, level with z.
local function endLaneToEast(s: number, z: number): { Vector3 }
	return { lanePoint(s, 160, LANE_END_Z), lanePoint(s, 165, 190), lanePoint(s, LANE_EAST_X, 150), pt(LANE_EAST_X, z) }
end

-- In through a stand's back opening: to just outside it, then 5 in.
local function throughOpening(at: Vector3, out: Vector3): { Vector3 }
	local a = Vector3.new(at.X, ROUTE_Y, at.Z)
	return { a + out * 1.5, a - out * 5 }
end

-- An end stair's foot on the pitch-side paving and a point 3 up it: the East
-- stand's `s` end, an end stand's west end, a west wing's far end.
local function stairFoot(key: string, level: number, s: number): (Vector3, Vector3)
	local axis = if key == "East" or key == "West" then "Z" else "X"
	local spans = StandAccess.spans(key, axis, level)
	local mid = StandAccess.STAIR_W / 2
	if key == "East" then
		local z = s * (spans[1][2] + mid)
		return pt(PITCHSIDE_X, z), pt(Pitch.SIDE_EDGE + 3, z)
	elseif key == "West" then
		local z = s * (spans[2][2] + mid)
		return pt(-PITCHSIDE_X, z), pt(-(Pitch.SIDE_EDGE + 3), z)
	end
	local x = -(spans[1][2] + mid)
	return pt(x, s * PITCHSIDE_Z), pt(x, s * (Pitch.END_EDGE + 3))
end

-- The legs from just inside the block into stand `key` on side `s`.
local function insideLegs(key: string, level: number, s: number): { Vector3 }
	local legs: { Vector3 } = {}
	local openings = ConcourseLayout.openings(key, level)
	if key == "East" and #openings > 0 then
		local target = openings[1]
		for _, o in openings do
			if o.at.Z * s > 0 then
				target = o
			end
		end
		appendAll(legs, toEndLane(s))
		appendAll(legs, endLaneToEast(s, target.at.Z))
		appendAll(legs, throughOpening(target.at, target.out))
		return legs
	end
	if (key == "North" or key == "South") and #openings > 0 then
		local target = openings[1]
		for _, o in openings do
			if o.at.X < target.at.X then
				target = o
			end
		end
		appendAll(legs, toEndLane(s))
		table.insert(legs, pt(target.at.X, s * LANE_END_Z))
		appendAll(legs, throughOpening(target.at, target.out))
		return legs
	end
	-- bleachers (no openings) and the west wings: round the pitch-side paving
	-- to the foot of the end stairs
	appendAll(legs, toPitchside(s))
	if key == "East" then
		table.insert(legs, pt(PITCHSIDE_X, s * PITCHSIDE_Z))
	elseif key == "West" then
		table.insert(legs, pt(-PITCHSIDE_X, s * PITCHSIDE_Z))
	end
	local foot, up = stairFoot(key, level, s)
	table.insert(legs, foot)
	table.insert(legs, up)
	return legs
end

-- #10: the spec's other ways out, through the north or east exit gate and round
-- the walk-round loop to the street gate or the car park. Written outside-in
-- like every route, ending with `inside` (legs from the end lane or east lane).
local function viaNorthExit(inside: { Vector3 }): { Vector3 }
	local r = { STREET_GATE, JOIN, NORTH_TURN, pt(LOOP_W, TURNSTILE_Z), pt(LOOP_W, -LOOP_Z), pt(0, -LOOP_Z), pt(0, -259), pt(0, -LANE_END_Z) }
	appendAll(r, inside)
	return r
end
local function viaEastExit(s: number, inside: { Vector3 }): { Vector3 }
	local r: { Vector3 }
	if s < 0 then
		r = { STREET_GATE, JOIN, NORTH_TURN, pt(LOOP_W, TURNSTILE_Z), pt(LOOP_W, -LOOP_Z), pt(LOOP_E, -LOOP_Z) }
	else
		r = { CAR_PARK, SW_APPROACH, pt(LOOP_W, SW_TURNSTILE_Z), pt(LOOP_W, LOOP_Z), pt(LOOP_E, LOOP_Z) }
	end
	appendAll(r, { pt(LOOP_E, 0), pt(201, 0), pt(190, 0), pt(LANE_EAST_X, 0) })
	appendAll(r, inside)
	return r
end

-- Distance along a route to `target`, if the route passes through it.
local function distanceTo(route: Route, target: Vector3): number?
	local d = 0
	for i = 1, #route do
		if (route[i] - target).Magnitude < 1e-3 then
			return d
		end
		if i < #route then
			d += (route[i + 1] - route[i]).Magnitude
		end
	end
	return nil
end

export type FanRoute = { route: Route, weight: number, name: string, gate: number? }
export type FanRoutes = { arrivals: { FanRoute }, leaving: { FanRoute } }

-- Every route a club's fans walk with its stands as they are, weighted by the
-- seats each stand holds (Config.plotCapacity). The East stand's and the west
-- wings' fans split between the two blocks; the end stands' use their own.
-- Leaving fans walk these backwards; for a stand with a back opening on the
-- end or east lane, half of them go out the north / east exit gate instead.
function MatchdayRoutes.fanRoutes(levels: { [string]: number }): FanRoutes
	local arrivals: { FanRoute } = {}
	local leaving: { FanRoute } = {}
	for _, plot in Config.StandPlots do
		local level = levels[plot.key] or 0
		if level < 1 then
			continue
		end
		local seats = Config.plotCapacity(plot, level)
		local sides = if plot.key == "North" then { -1 } elseif plot.key == "South" then { 1 } else { -1, 1 }
		for _, s in sides do
			local w = seats / #sides
			local inside = insideLegs(plot.key, level, s)
			local route = outside(s)
			appendAll(route, inside)
			local name = plot.key .. (if s < 0 then "ViaNW" else "ViaSW")
			table.insert(arrivals, {
				route = route,
				weight = w,
				name = name,
				gate = distanceTo(route, if s < 0 then TURNSTILE else SW_TURNSTILE),
			})
			local exitWay = (plot.key == "North" or plot.key == "East") and #ConcourseLayout.openings(plot.key, level) > 0
			if not exitWay then
				table.insert(leaving, { route = route, weight = w, name = name })
				continue
			end
			table.insert(leaving, { route = route, weight = w / 2, name = name })
			local other: { Vector3 }
			if plot.key == "North" then
				-- from the end lane: drop the two legs up the west strip
				other = viaNorthExit({ table.unpack(inside, 3) })
			else
				-- from the east lane level with the opening: the last three legs
				other = viaEastExit(s, { table.unpack(inside, #inside - 2) })
			end
			table.insert(leaving, { route = other, weight = w / 2, name = name .. (if plot.key == "North" then "NorthExit" else "EastExit") })
		end
	end
	return { arrivals = arrivals, leaving = leaving }
end

-- The i-th fan's pick from a weighted list: a golden-ratio walk through the
-- cumulative weights, so any run of fans splits in proportion.
function MatchdayRoutes.pick(list: { FanRoute }, i: number): FanRoute?
	local total = 0
	for _, r in list do
		total += r.weight
	end
	if #list == 0 or total <= 0 then
		return nil
	end
	local u = ((i * 0.6180339887) % 1) * total
	for _, r in list do
		u -= r.weight
		if u <= 0 then
			return r
		end
	end
	return list[#list]
end

-- #14: the queue at the turnstiles. Over the last QUEUE_ZONE studs before a
-- block a walking fan slows to a shuffle and closes up into one file on the
-- far side of the lane from the standing queue (queueSpots), then goes through
-- the turnstile on the lane's centre line. `gate` is FanRoute.gate. Returns
-- (speed factor, lateral offset).
MatchdayRoutes.QUEUE_ZONE = 34
MatchdayRoutes.QUEUE_FILE = 2.2 -- either side of the walk: a figure is ~4 across the shoulders
MatchdayRoutes.QUEUE_SHUFFLE = 0.35
local CLOSE_UP = 6
function MatchdayRoutes.gateLane(gate: number?, distance: number, lateral: number): (number, number)
	if not gate then
		return 1, lateral
	end
	local before = gate - distance
	if before > MatchdayRoutes.QUEUE_ZONE or before < 0 then
		return 1, if before < 0 and before > -CLOSE_UP then lateral * (-before / CLOSE_UP) else lateral
	end
	local file = -MatchdayRoutes.QUEUE_FILE
	if before > MatchdayRoutes.QUEUE_ZONE - CLOSE_UP then
		local t = (MatchdayRoutes.QUEUE_ZONE - before) / CLOSE_UP
		return 1 - (1 - MatchdayRoutes.QUEUE_SHUFFLE) * t, lateral + (file - lateral) * t
	end
	if before > MatchdayRoutes.QUEUE_START then
		return MatchdayRoutes.QUEUE_SHUFFLE, file
	end
	return MatchdayRoutes.QUEUE_SHUFFLE, file * before / MatchdayRoutes.QUEUE_START
end

-- The two ways in on their own, street / car park to just inside each block:
-- the turnstile approaches the barriers and the standing queues line.
MatchdayRoutes.ROUTES = {
	fromTown = outside(-1) :: Route,
	fromCarPark = outside(1) :: Route,
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

-- X104 (roadmap G1 "queues"): fans standing in line at the turnstiles before
-- kick-off. Lane A2 (#14): one file at each block (NW and SW, filled in turn)
-- from QUEUE_START back along the walk, QUEUE_FILE to the walkers' left, so
-- the fans still walking in (gateLane) shuffle past in the other file without
-- walking through them. A figure is ~4 across the shoulders, so the two files
-- clear each other and the barriers (+-5). Pitch-local ground CFrames facing
-- the turnstiles. Only in PreMatch: once the game is on everyone is in. TEMP.
MatchdayRoutes.QUEUE_MAX = 14
MatchdayRoutes.QUEUE_START = 4
MatchdayRoutes.QUEUE_SPACING = 2.2
function MatchdayRoutes.queueCount(attendance: number, capacity: number, phase: any): number
	if phase ~= "PreMatch" or capacity <= 0 or attendance <= 0 then
		return 0
	end
	return math.clamp(math.round(4 + 10 * (attendance / capacity)), 0, MatchdayRoutes.QUEUE_MAX)
end

function MatchdayRoutes.queueSpots(count: number): { CFrame }
	local blocks = {
		{ gate = TURNSTILE, from = FORECOURT_EDGE },
		{ gate = SW_TURNSTILE, from = SW_APPROACH },
	}
	local out = {}
	for i = 1, math.min(count, MatchdayRoutes.QUEUE_MAX) do
		local b = blocks[(i - 1) % 2 + 1]
		local a = Vector3.new(b.gate.X, 0, b.gate.Z)
		local walk = Vector3.new(a.X - b.from.X, 0, a.Z - b.from.Z).Unit -- the way fans walk in
		local left = Vector3.new(-walk.Z, 0, walk.X) -- gateLane's +lateral side
		local d = MatchdayRoutes.QUEUE_START + math.floor((i - 1) / 2) * MatchdayRoutes.QUEUE_SPACING
		local c = a - walk * d + left * MatchdayRoutes.QUEUE_FILE
		table.insert(out, CFrame.lookAt(c, c + walk))
	end
	return out
end

-- X318: fans at the catering the player buys, and nobody stood about while
-- the fans who walk in vanish at the gate. Lane A2 (#7): the old concourse hut
-- is gone; the queue is at the burger van's hatch (ConcourseLayout.hatchQueue)
-- and the scatter on the concourse beside it (ConcourseLayout.millingBox).
-- `levels` (the club's Stand_* levels) says where the van is parked. Pitch-
-- local ground CFrames like every other route here.
MatchdayRoutes.AMENITY_QUEUE_GAP = 2.4
MatchdayRoutes.CONCOURSE_MAX = 14
local SPOT_Y = 0.1

-- How many are queueing at the hatch: nobody before the club has built
-- anything, then a line that grows a little with each amenity.
function MatchdayRoutes.amenityQueueCount(amenityLevel: number, attendance: number, capacity: number, phase: any): number
	if amenityLevel < 1 or capacity <= 0 or attendance <= 0 then
		return 0
	end
	if phase ~= "Match" and phase ~= "PreMatch" then
		return 0
	end
	local full = math.clamp(attendance / capacity, 0, 1)
	return math.clamp(math.round(1 + amenityLevel + full * 2), 0, 5)
end

-- And how many are milling about on the concourse: only while the match is on
-- (before kick-off they are still queueing outside, X104), more when the
-- ground is full and when there is somewhere to stand about.
function MatchdayRoutes.concourseCount(amenityLevel: number, attendance: number, capacity: number, phase: any): number
	if phase ~= "Match" or capacity <= 0 or attendance <= 0 then
		return 0
	end
	local full = math.clamp(attendance / capacity, 0, 1)
	return math.clamp(math.round(2 + full * 8 + amenityLevel * 2), 0, MatchdayRoutes.CONCOURSE_MAX)
end

function MatchdayRoutes.amenityQueueSpots(count: number, levels: { [string]: number }?): { CFrame }
	local out = {}
	local first, back, face = ConcourseLayout.hatchQueue(levels or {})
	local side = Vector3.new(-back.Z, 0, back.X)
	for i = 1, count do
		local p = first + back * ((i - 1) * MatchdayRoutes.AMENITY_QUEUE_GAP) + side * (if i % 2 == 0 then 0.5 else -0.4)
		p = Vector3.new(p.X, SPOT_Y, p.Z)
		table.insert(out, CFrame.lookAt(p, p + face))
	end
	return out
end

-- A scatter with no two people on the same spot: a coarse grid with a seeded
-- jitter, which also keeps it identical every time the match is rebuilt.
-- Three columns and a small jitter, so the ~4-wide figures don't overlap.
function MatchdayRoutes.concourseSpots(count: number, seed: number, levels: { [string]: number }?): { CFrame }
	local out = {}
	if count <= 0 then
		return out
	end
	local rng = Random.new(seed)
	local box = ConcourseLayout.millingBox(levels or {})
	local columns = 3
	local rows = math.ceil(MatchdayRoutes.CONCOURSE_MAX / columns)
	local stepX = (box.x1 - box.x0) / columns
	local stepZ = (box.z1 - box.z0) / rows
	for i = 1, math.min(count, MatchdayRoutes.CONCOURSE_MAX) do
		local cell = i - 1
		local cx = cell % columns
		local cz = math.floor(cell / columns)
		local p = Vector3.new(
			box.x0 + stepX * (cx + 0.5) + rng:NextNumber(-0.3, 0.3),
			SPOT_Y,
			box.z0 + stepZ * (cz + 0.5) + rng:NextNumber(-0.3, 0.3)
		)
		-- facing anywhere: they are standing about, not queueing
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(out, CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a))))
	end
	return out
end

-- X93 (roadmap H1 "media presence") / playtest #25: an outside-broadcast van
-- on matchday once the club draws a crowd, parked in the media bay outside
-- the ground wall (ground plan spec s5: x -266..-240, z -252..-230), not on
-- the forecourt paving. Pitch-local ground CFrame, same rotation as before
-- (nose to world -X). TEMP thresholds.
MatchdayRoutes.MEDIA_VAN = CFrame.new(-253, 0, -241) * CFrame.Angles(0, math.pi / 2, 0)
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
-- playtest #25: the double row starts south of the team coach's bay
-- (PlotGrounds.COACH_BAY, z 42..56), like PlotGrounds' MID_ROW_Z0
local MID_ROW_Z0 = 67

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
	bayRow(out, MID_ROW_X, MID_ROW_Z0, PARK_AZ1 - 6)
	bayRow(out, MID_ROW_X + BAY_D, MID_ROW_Z0, PARK_AZ1 - 6)
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

-- X161: after the final whistle fans walk back out along their route (a
-- route walked backwards, stand to street / car park). Pure: the start
-- distance of leaver i of n, strung out along the inner LEAVE_SPREAD share of
-- the route, nearest the stand last. #10: the crowd stays until the last
-- leaver is out (leaveSeconds), so nobody vanishes mid-plot; LEAVE_SECONDS is
-- the least it stays and LEAVE_MAX_SECONDS the most. TEMP.
MatchdayRoutes.LEAVE_SECONDS = 45
MatchdayRoutes.LEAVE_MAX_SECONDS = 150
MatchdayRoutes.LEAVE_SPREAD = 0.7
MatchdayRoutes.LEAVE_PACE = 1.6 -- leavers walk this much quicker than arrivals: the whistle's gone
function MatchdayRoutes.leavingStart(length: number, i: number, n: number): number
	local spread = length * MatchdayRoutes.LEAVE_SPREAD
	return length - (i - 1) / math.max(n - 1, 1) * spread
end
function MatchdayRoutes.leaveSeconds(longest: number, slowest: number): number
	return math.clamp(longest / math.max(slowest, 1) + 2, MatchdayRoutes.LEAVE_SECONDS, MatchdayRoutes.LEAVE_MAX_SECONDS)
end

return MatchdayRoutes
