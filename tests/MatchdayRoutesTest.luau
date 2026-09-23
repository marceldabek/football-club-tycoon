--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchdayRoutes = require(ReplicatedStorage.Shared.MatchdayRoutes)
local ConcourseLayout = require(ReplicatedStorage.Shared.ConcourseLayout)
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

local EPS = 1e-3

function T.routesHavePositiveLength()
	for name, route in MatchdayRoutes.ROUTES do
		local len = MatchdayRoutes.length(route)
		assert(len > 0, name .. " should have a positive length")
	end
end

function T.pointAtZeroIsTheFirstPoint()
	for name, route in MatchdayRoutes.ROUTES do
		local point = MatchdayRoutes.pointAt(route, 0)
		assert((point - route[1]).Magnitude < EPS, name .. " pointAt(0) should be the first point")
	end
end

function T.pointAtLengthIsTheLastPoint()
	for name, route in MatchdayRoutes.ROUTES do
		local len = MatchdayRoutes.length(route)
		local point = MatchdayRoutes.pointAt(route, len)
		assert((point - route[#route]).Magnitude < EPS, name .. " pointAt(length) should be the last point")
	end
end

function T.pointAtClampsPastTheEnd()
	for name, route in MatchdayRoutes.ROUTES do
		local len = MatchdayRoutes.length(route)
		local point = MatchdayRoutes.pointAt(route, len + 500)
		assert((point - route[#route]).Magnitude < EPS, name .. " pointAt beyond the end should clamp to the last point")
	end
end

function T.pointAtReturnsAUnitDirection()
	for name, route in MatchdayRoutes.ROUTES do
		local len = MatchdayRoutes.length(route)
		for _, d in { 0, len / 2, len } do
			local _, direction = MatchdayRoutes.pointAt(route, d)
			assert(math.abs(direction.Magnitude - 1) < EPS, ("%s direction at %.1f is not a unit vector"):format(name, d))
		end
	end
end

function T.stewardSpotsArePresent()
	assert(#MatchdayRoutes.STEWARD_SPOTS == 5, "expected 5 steward spots")
	for _, cf in MatchdayRoutes.STEWARD_SPOTS do
		assert(typeof(cf) == "CFrame", "steward spot should be a CFrame")
	end
end

function T.fanCountZeroCapacityIsZero()
	assert(MatchdayRoutes.fanCount(0, 0) == 0, "zero capacity should give zero fans")
	assert(MatchdayRoutes.fanCount(500, 0) == 0, "zero capacity should give zero fans even with attendance")
end

function T.fanCountFullStadiumIsFortyEight()
	assert(MatchdayRoutes.fanCount(1000, 1000) == 48, "a full stadium should show the max 48 fans")
end

function T.fanCountEmptyStadiumIsTwelve()
	assert(MatchdayRoutes.fanCount(0, 1000) == 12, "an empty stadium should still show the baseline 12 fans")
end

function T.fanCountNeverExceedsBounds()
	for _, pair in { { 0, 10 }, { 5, 10 }, { 10, 10 }, { 50, 10 }, { 1, 1 } } do
		local n = MatchdayRoutes.fanCount(pair[1], pair[2])
		assert(n >= 0 and n <= 48, ("fanCount(%d, %d) = %d out of bounds"):format(pair[1], pair[2], n))
	end
end

function T.carParkBaysSitOnTheAsphaltClearOfTheRoadMouth()
	local bays = MatchdayRoutes.carParkBays()
	assert(#bays == 8 + 12 + 12, "bay count " .. #bays)
	for _, b in bays do
		assert(b.X > -349 and b.X < -251, "inside the kerbs across")
		-- playtest #25: no matchday car in the team coach's bay (x -312..-276, z 42..56)
		assert(b.X + 9 <= -312 or b.X - 9 >= -276 or b.Z - 4.5 >= 56 or b.Z + 4.5 <= 42, ("bay at %g, %g is in the coach bay"):format(b.X, b.Z))
		assert(b.Z - 4.5 >= 41 - 1e-6 and b.Z + 4.5 <= 189 + 1e-6, "inside the kerbs along")
		if b.X < -330 then
			assert(b.Z - 4.5 >= 104 - 1e-6, "west row starts past the road mouth")
		end
	end
	for i = 1, #bays do
		for j = i + 1, #bays do
			local d = bays[i] - bays[j]
			assert(math.abs(d.X) >= 18 - 1e-6 or math.abs(d.Z) >= 9 - 1e-6, "bays don't overlap")
		end
	end
end

function T.parkedCarsScaleWithAttendance()
	assert(MatchdayRoutes.parkedCars(0, 36) == 0, "empty ground")
	assert(MatchdayRoutes.parkedCars(150, 36) == 4, "small crowd trickle (10% floor)")
	assert(MatchdayRoutes.parkedCars(750, 36) == 18, "half full")
	assert(MatchdayRoutes.parkedCars(30000, 36) == 36, "full")
	assert(MatchdayRoutes.parkedCars(500, 0) == 0, "no bays")
end

function T.barriersLineTheTurnstileApproachWithoutBlockingIt()
	local sections = MatchdayRoutes.barrierSections()
	assert(#sections >= 8 and #sections % 2 == 0, "pairs of sections, got " .. #sections)
	-- fromTown now carries on past the turnstile into the concourse (#14), so
	-- the barriered approach leg is fixed points 3 and 4 (NORTH_TURN, TURNSTILE),
	-- not the route's end.
	local route = MatchdayRoutes.ROUTES.fromTown
	local a, b = route[3], route[4]
	for _, cf in sections do
		local p = cf.Position
		-- distance from the last leg of the walk
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local t = math.clamp(Vector3.new(p.X - a.X, 0, p.Z - a.Z):Dot(ab) / ab.Magnitude ^ 2, 0, 1)
		local q = Vector3.new(a.X, 0, a.Z) + ab * t
		local off = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
		assert(math.abs(off - MatchdayRoutes.BARRIER_OFFSET) < 1e-3, "beside the walk, got " .. off)
		assert(t > 0 and t < 1, "within the final leg")
		assert(Vector3.new(p.X - b.X, 0, p.Z - b.Z).Magnitude > 12, "clear of the turnstile piers")
		assert(math.abs(cf.LookVector:Dot(ab.Unit) - 1) < 1e-3, "runs along the walk")
	end
end

function T.mediaVanComesWithACrowdAndStaysOffTheWalk()
	assert(not MatchdayRoutes.hasMedia(1, 150), "a small Sunday league crowd gets no TV")
	assert(MatchdayRoutes.hasMedia(1, 400), "a big crowd does")
	assert(MatchdayRoutes.hasMedia(2, 0), "so does a higher division")
	local p = MatchdayRoutes.MEDIA_VAN.Position
	for _, cf in MatchdayRoutes.barrierSections() do
		assert((cf.Position - p).Magnitude > 12, "clear of the barriers")
	end
	-- playtest #25: the van (~16.5 long along X, ~7.5 wide) on the media bay pad
	-- outside the wall, x -266..-240, z -252..-230 (PlotGrounds.MEDIA_BAY)
	assert(p.X - 8.5 >= -266 and p.X + 8.5 <= -240, "van along the media bay")
	assert(p.Z - 4 >= -252 and p.Z + 4 <= -230, "van across the media bay")
	assert(math.abs(MatchdayRoutes.MEDIA_VAN.LookVector.X) > 0.99, "van parked along the bay (long axis X)")
end

-- X104: queues only before kick-off, bigger with a fuller ground, standing
-- inside the barriers, facing the turnstiles, clear of each other and of the
-- turnstile stewards.
function T.queuesFormOnlyBeforeKickOffAndGrowWithTheCrowd()
	assert(MatchdayRoutes.queueCount(500, 1000, "Match") == 0, "none once the match is on")
	assert(MatchdayRoutes.queueCount(500, 1000, nil) == 0, "none outside matchday")
	assert(MatchdayRoutes.queueCount(0, 1000, "PreMatch") == 0, "none with no crowd")
	local small, full = MatchdayRoutes.queueCount(100, 1000, "PreMatch"), MatchdayRoutes.queueCount(1000, 1000, "PreMatch")
	assert(small > 0 and full > small and full <= MatchdayRoutes.QUEUE_MAX, ("small %d full %d"):format(small, full))
end

-- #14: the standing queue is one file at each block, to the walkers' left of
-- the walk in, inside the barriers, facing the turnstiles, clear of each other
-- and the stewards; the walking fans' file (gateLane) is on the other side.
function T.queueSpotsStandInOneFileAtEachBlock()
	local spots = MatchdayRoutes.queueSpots(MatchdayRoutes.QUEUE_MAX)
	assert(#spots == MatchdayRoutes.QUEUE_MAX, "count")
	local blocks = {
		{ from = MatchdayRoutes.ROUTES.fromTown[3], gate = MatchdayRoutes.ROUTES.fromTown[4] },
		{ from = MatchdayRoutes.ROUTES.fromCarPark[2], gate = MatchdayRoutes.ROUTES.fromCarPark[3] },
	}
	local perBlock = { 0, 0 }
	for i, cf in spots do
		local b = blocks[(i - 1) % 2 + 1]
		perBlock[(i - 1) % 2 + 1] += 1
		local a = Vector3.new(b.gate.X, 0, b.gate.Z)
		local walk = Vector3.new(a.X - b.from.X, 0, a.Z - b.from.Z)
		local rel = cf.Position - a
		local back = -rel:Dot(walk.Unit)
		local left = Vector3.new(-walk.Unit.Z, 0, walk.Unit.X)
		assert(back > 2 and back < walk.Magnitude, "spot " .. i .. " between the turnstile and the start of the approach")
		assert(math.abs(rel:Dot(left) - MatchdayRoutes.QUEUE_FILE) < 1e-3, "spot " .. i .. " in the standing file")
		assert(MatchdayRoutes.QUEUE_FILE + 2 <= MatchdayRoutes.BARRIER_OFFSET, "a ~4-wide figure clears the barrier")
		assert(cf.LookVector:Dot(walk.Unit) > 0.99, "spot " .. i .. " faces the turnstiles")
		for j = i + 1, #spots do
			assert((spots[j].Position - cf.Position).Magnitude >= 2, ("spots %d and %d crowd each other"):format(i, j))
		end
		for _, steward in MatchdayRoutes.STEWARD_SPOTS do
			assert((steward.Position - cf.Position).Magnitude >= 2, "spot " .. i .. " on a steward")
		end
	end
	assert(perBlock[1] == 7 and perBlock[2] == 7, "split between the two blocks")
end

-- #14: walkers close into the far file and shuffle, then go through the
-- turnstile on the centre line and spread out again inside.
function T.walkersShuffleThroughTheQueueInTheOtherFile()
	local gate = 100
	local pace, lat = MatchdayRoutes.gateLane(gate, 10, 2)
	assert(pace == 1 and lat == 2, "well before the queue: unchanged")
	pace, lat = MatchdayRoutes.gateLane(gate, gate - 15, 2)
	assert(pace == MatchdayRoutes.QUEUE_SHUFFLE and lat == -MatchdayRoutes.QUEUE_FILE, "in the queue: shuffling in the far file")
	pace, lat = MatchdayRoutes.gateLane(gate, gate, 2)
	assert(math.abs(lat) < 1e-6, "through the turnstile on the centre line")
	pace, lat = MatchdayRoutes.gateLane(gate, gate + 20, 2)
	assert(pace == 1 and lat == 2, "inside the ground: back to walking")
	pace, lat = MatchdayRoutes.gateLane(nil, 50, 1.5)
	assert(pace == 1 and lat == 1.5, "no turnstile on the route")
	-- the walking file and the standing file never share a lateral
	for d = gate - MatchdayRoutes.QUEUE_ZONE + 6, gate - MatchdayRoutes.QUEUE_START, 1 do
		local _, l = MatchdayRoutes.gateLane(gate, d, 2.5)
		assert(math.abs(l - MatchdayRoutes.QUEUE_FILE) >= 4, "walkers keep off the standing file at " .. d)
	end
end

-- X161 / #10: leavers start strung out from the stand end of the route, in
-- order, and the crowd waits for the slowest of them to reach the way out.
function T.leaversStartAtTheStandEndAndTheCrowdWaitsForThem()
	local length = 600
	local n = 20
	local prev = math.huge
	for i = 1, n do
		local d = MatchdayRoutes.leavingStart(length, i, n)
		assert(d <= length and d >= length * (1 - MatchdayRoutes.LEAVE_SPREAD) - 1e-6, "start " .. d)
		assert(d < prev, "strung out in order")
		prev = d
	end
	assert(MatchdayRoutes.leavingStart(length, 1, 1) == length, "a lone leaver starts in the stand")
	assert(MatchdayRoutes.leaveSeconds(10, 5) == MatchdayRoutes.LEAVE_SECONDS, "never shorter than the old wait")
	assert(MatchdayRoutes.leaveSeconds(600, 6) > 100, "long enough for a long way out")
	assert(MatchdayRoutes.leaveSeconds(1e6, 1) == MatchdayRoutes.LEAVE_MAX_SECONDS, "but capped")
end

-- X318: the concourse

function T.nobodyQueuesAtAHatchTheClubHasNotBuilt()
	assert(MatchdayRoutes.amenityQueueCount(0, 900, 1000, "Match") == 0, "no amenity means no hatch to queue at")
	assert(MatchdayRoutes.amenityQueueCount(2, 0, 1000, "Match") == 0, "nobody in the ground means nobody queueing")
	assert(MatchdayRoutes.amenityQueueCount(2, 900, 0, "Match") == 0, "no capacity means no crowd")
end

function T.theHatchQueueGrowsWithTheAmenityAndTheCrowd()
	local small = MatchdayRoutes.amenityQueueCount(1, 200, 1000, "Match")
	local bigger = MatchdayRoutes.amenityQueueCount(3, 950, 1000, "Match")
	assert(small >= 1, "a snack bar with a crowd in should have somebody at it")
	assert(bigger > small, "a fan zone at a full house should have more, got " .. bigger .. " vs " .. small)
	assert(bigger <= 5, "but never a queue round the block, got " .. bigger)
end

function T.theQueueIsOnlyThereOnMatchday()
	assert(MatchdayRoutes.amenityQueueCount(2, 900, 1000, "Manage") == 0, "nobody queues on a Tuesday")
	assert(MatchdayRoutes.amenityQueueCount(2, 900, 1000, "PreMatch") > 0, "they queue before kick-off")
end

function T.theConcourseOnlyFillsOnceTheMatchIsOn()
	assert(MatchdayRoutes.concourseCount(2, 900, 1000, "PreMatch") == 0, "before kick-off they are still outside the turnstiles")
	assert(MatchdayRoutes.concourseCount(2, 900, 1000, "Manage") == 0, "and there is nobody there between matches")
	assert(MatchdayRoutes.concourseCount(2, 900, 1000, "Match") > 0, "with the match on, some people are stood about")
end

function T.theConcourseIsSizedByTheCrowdAndCapped()
	local quiet = MatchdayRoutes.concourseCount(0, 100, 1000, "Match")
	local busy = MatchdayRoutes.concourseCount(3, 1000, 1000, "Match")
	assert(busy > quiet, "a full house with a fan zone should be busier")
	assert(busy <= MatchdayRoutes.CONCOURSE_MAX, "and still inside the budget")
end

local function overlaps(p: Vector3, r: ConcourseLayout.Rect, pad: number): boolean
	return p.X > r.x0 - pad and p.X < r.x1 + pad and p.Z > r.z0 - pad and p.Z < r.z1 + pad
end

-- #7: people stood about keep ~4 apart (a figure's shoulders) and off
-- everything on the concourse, wherever the van is parked.
function T.concourseSpotsStandClearOfEachOtherAndTheCatering()
	for _, west in { 0, 2, 4 } do
		local levels = { East = 4, West = west, North = 4, South = 4 }
		local spots = MatchdayRoutes.concourseSpots(MatchdayRoutes.CONCOURSE_MAX, 5, levels)
		assert(#spots == MatchdayRoutes.CONCOURSE_MAX, "should give every spot asked for")
		local box = ConcourseLayout.millingBox(levels)
		local obstacles = ConcourseLayout.obstacles(levels, 3)
		for i, cf in spots do
			local p = cf.Position
			assert(overlaps(p, box, 0), "spot " .. i .. " is off the milling box")
			for _, r in obstacles do
				assert(not overlaps(p, r, 2), ("spot %d (%g, %g) stands in %s"):format(i, p.X, p.Z, r.name))
			end
			for j = 1, i - 1 do
				local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(spots[j].Position.X, 0, spots[j].Position.Z)).Magnitude
				assert(d > 3.8, ("two people are stood too close (%d and %d, %.1f apart)"):format(j, i, d))
			end
		end
	end
end

function T.theSameMatchdayLooksTheSame()
	local a = MatchdayRoutes.concourseSpots(8, 42)
	local b = MatchdayRoutes.concourseSpots(8, 42)
	for i, cf in a do
		assert((cf.Position - b[i].Position).Magnitude < 0.001, "the same seed must give the same concourse")
	end
end

-- #7: the hatch queue lines up at the burger van's hatch, wherever it's parked.
function T.theHatchQueueFacesTheVanHatch()
	for _, west in { 0, 2, 3 } do
		local levels = { East = 1, West = west, North = 0, South = 0 }
		local van = ConcourseLayout.van(levels, 1) :: ConcourseLayout.Spot
		local spots = MatchdayRoutes.amenityQueueSpots(5, levels)
		assert(#spots == 5, "five in the queue")
		for i, cf in spots do
			local p = cf.Position
			assert(not overlaps(p, van.rect, 1.5), "queuer " .. i .. " stands in the van")
			local facing = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
			assert(facing:Dot(-van.face) > 0.99, "queuer " .. i .. " faces the hatch side")
			for _, r in ConcourseLayout.obstacles(levels, 3) do
				if r.name ~= "BurgerVan" then
					assert(not overlaps(p, r, 1.5), ("queuer %d stands in %s"):format(i, r.name))
				end
			end
		end
		local first = spots[1].Position
		assert((Vector3.new(first.X, 0, first.Z) - van.at):Dot(van.face) > 0, "the line starts on the hatch side")
	end
end

-- ------------------------------------------------------------------ fan routes

-- A segment against an axis-aligned rect grown by `pad` (slab test).
local function segmentHits(a: Vector3, b: Vector3, r: ConcourseLayout.Rect, pad: number): boolean
	local x0, x1, z0, z1 = r.x0 - pad, r.x1 + pad, r.z0 - pad, r.z1 + pad
	local t0, t1 = 0, 1
	local d = b - a
	for _, axis in { { a.X, d.X, x0, x1 }, { a.Z, d.Z, z0, z1 } } do
		local p, dp, lo, hi = axis[1], axis[2], axis[3], axis[4]
		if math.abs(dp) < 1e-9 then
			if p <= lo or p >= hi then
				return false
			end
		else
			local ta, tb = (lo - p) / dp, (hi - p) / dp
			if ta > tb then
				ta, tb = tb, ta
			end
			t0, t1 = math.max(t0, ta), math.min(t1, tb)
			if t0 >= t1 then
				return false
			end
		end
	end
	return true
end

-- The stand levels the route test walks: every stand through every level on
-- its own, with the others empty, and with the others at full size.
local function levelSets(): { { [string]: number } }
	local sets = {}
	for _, others in { 0, 4 } do
		for _, key in { "East", "West", "North", "South" } do
			for level = 0, 4 do
				local l = { East = math.max(others, 1), West = others, North = others, South = others }
				l[key] = if key == "East" then math.max(level, 1) else level
				table.insert(sets, l)
			end
		end
	end
	table.insert(sets, { East = 1, West = 0, North = 0, South = 0 })
	table.insert(sets, { East = 2, West = 2, North = 2, South = 2 })
	table.insert(sets, { East = 3, West = 3, North = 3, South = 3 })
	table.insert(sets, { East = 2, West = 4, North = 1, South = 3 })
	return sets
end

-- #14/#10: every route a crowd walks starts at the street gate or the car
-- park, goes through a turnstile block or an exit gate, and inside the wall
-- keeps a fan's half-width plus a margin (3.5) off every stand, hut, toilet
-- block, mast, the catering and the rest, at every stand level and catering
-- tier -- except the last two legs, which step up to and into its own stand.
function T.fanRoutesWalkClearOfEverythingInsideTheGround()
	local street, carPark = Vector3.new(-380, 0.3, -12), Vector3.new(-300, 0.3, 115)
	local W = ConcourseLayout.WALL
	for _, levels in levelSets() do
		local routes = MatchdayRoutes.fanRoutes(levels)
		local stands = 0
		for _, plot in Config.StandPlots do
			if (levels[plot.key] or 0) >= 1 then
				stands += 1
			end
		end
		assert(#routes.arrivals >= stands, "a route for every built stand")
		for tier = 0, 3 do
			local obstacles = ConcourseLayout.obstacles(levels, tier)
			for _, list in { routes.arrivals, routes.leaving } do
				for _, fr in list do
					local route = fr.route
					local first = route[1]
					assert((first - street).Magnitude < 1e-3 or (first - carPark).Magnitude < 1e-3, fr.name .. " starts at a way out")
					for i = 1, #route - 1 do
						local a, b = route[i], route[i + 1]
						local inside = math.max(a.X, b.X) > W.x0 and math.min(a.X, b.X) < W.x1
							and math.max(a.Z, b.Z) > W.z0 and math.min(a.Z, b.Z) < W.z1
						if not inside then
							continue
						end
						local ownStand = i >= #route - 2
						for _, r in obstacles do
							if ownStand and string.sub(r.name, 1, 5) == "Stand" then
								continue
							end
							assert(not segmentHits(a, b, r, 3.5), ("%s leg %d (%g,%g)->(%g,%g) runs through %s at tier %d, levels E%d W%d N%d S%d")
								:format(fr.name, i, a.X, a.Z, b.X, b.Z, r.name, tier, levels.East, levels.West, levels.North, levels.South))
						end
					end
				end
			end
		end
	end
end

-- #14: arrivals end inside their own stand, and the ones through a turnstile
-- know where it is (the queue shuffle).
function T.arrivalsEndInTheirStand()
	for _, levels in levelSets() do
		for _, fr in MatchdayRoutes.fanRoutes(levels).arrivals do
			local key = string.match(fr.name, "^(%a+)Via") :: string
			local last = fr.route[#fr.route]
			local inStand = false
			for _, r in ConcourseLayout.standRects(key, levels[key]) do
				if overlaps(last, r, 0) then
					inStand = true
				end
			end
			assert(inStand, fr.name .. " should end inside the " .. key .. " stand")
			assert(fr.gate and fr.gate > 0, fr.name .. " passes a turnstile")
		end
	end
end

-- #10: the long ways out use the exit gates, and half a stand's leavers take them.
function T.leaversSplitBetweenTheTurnstilesAndTheExitGates()
	local routes = MatchdayRoutes.fanRoutes({ East = 3, West = 2, North = 2, South = 1 })
	local names = {}
	for _, fr in routes.leaving do
		names[fr.name] = fr
	end
	for _, want in { "NorthViaNWNorthExit", "EastViaNWEastExit", "EastViaSWEastExit" } do
		assert(names[want], "missing leaving route " .. want)
	end
	local function passes(route: { Vector3 }, p: Vector3): boolean
		for _, q in route do
			if (q - p).Magnitude < 1e-3 then
				return true
			end
		end
		return false
	end
	assert(passes(names.NorthViaNWNorthExit.route, Vector3.new(0, 0.3, -259)), "through the north exit gate")
	assert(passes(names.EastViaSWEastExit.route, Vector3.new(201, 0.3, 0)), "through the east exit gate")
	assert(not names.SouthViaSWEastExit, "bleachers have no back opening onto a lane")
	-- weights: every stand's leavers add up to its seats
	local total, seats = 0, 0
	for _, fr in routes.leaving do
		total += fr.weight
	end
	for _, fr in routes.arrivals do
		seats += fr.weight
	end
	assert(math.abs(total - seats) < 1e-6, "leavers and arrivals weigh the same")
end

function T.pickSplitsACrowdByWeight()
	local list = { { route = {}, weight = 3, name = "a" }, { route = {}, weight = 1, name = "b" } }
	local a = 0
	for i = 1, 400 do
		if (MatchdayRoutes.pick(list :: any, i) :: any).name == "a" then
			a += 1
		end
	end
	assert(a > 280 and a < 320, "about three in four, got " .. a)
	assert(MatchdayRoutes.pick({}, 1) == nil, "nothing to pick")
end

return T
