--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchdayRoutes = require(ReplicatedStorage.Shared.MatchdayRoutes)

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
	assert(#bays == 8 + 14 + 14, "bay count " .. #bays)
	for _, b in bays do
		assert(b.X > -349 and b.X < -251, "inside the kerbs across")
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
	local route = MatchdayRoutes.ROUTES.fromTown
	local a, b = route[#route - 1], route[#route]
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
	assert(p.X + 7 < -160 or p.Z - 3 > -213, "clear of the team coach")
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

function T.queueSpotsStandInTheBarrieredLaneFacingTheTurnstiles()
	local spots = MatchdayRoutes.queueSpots(MatchdayRoutes.QUEUE_MAX)
	assert(#spots == MatchdayRoutes.QUEUE_MAX, "count")
	local turnstile = MatchdayRoutes.ROUTES.fromTown[#MatchdayRoutes.ROUTES.fromTown]
	local edge = MatchdayRoutes.ROUTES.fromTown[#MatchdayRoutes.ROUTES.fromTown - 1]
	local a = Vector3.new(turnstile.X, 0, turnstile.Z)
	local walk = Vector3.new(edge.X - a.X, 0, edge.Z - a.Z)
	for i, cf in spots do
		local rel = cf.Position - a
		local along = rel:Dot(walk.Unit)
		local lateral = math.abs(rel:Cross(walk.Unit).Y)
		assert(along > 2 and along < walk.Magnitude, "spot " .. i .. " between the turnstile and the forecourt edge")
		assert(lateral < MatchdayRoutes.BARRIER_OFFSET - 1, "spot " .. i .. " inside the barriers")
		assert(cf.LookVector:Dot(-walk.Unit) > 0.99, "spot " .. i .. " faces the turnstiles")
		for j = i + 1, #spots do
			assert((spots[j].Position - cf.Position).Magnitude >= 2, ("spots %d and %d crowd each other"):format(i, j))
		end
		for _, steward in MatchdayRoutes.STEWARD_SPOTS do
			assert((steward.Position - cf.Position).Magnitude >= 2, "spot " .. i .. " on a steward")
		end
	end
end

-- X125: bar drinkers stand on the supporters' bar patio, clear of the picnic
-- benches and of each other, facing into their huddle.
function T.barDrinkersStandOnThePatioClearOfBenches()
	local spots = MatchdayRoutes.barDrinkerSpots(4)
	assert(#spots == 4, "four drinkers")
	for i, cf in spots do
		local p = cf.Position
		assert(p.X > -372 + 1 and p.X < -344 - 1 and p.Z > -37.5 + 0.5 and p.Z < -30 - 0.5, "drinker " .. i .. " off the patio: " .. tostring(p))
		for _, bx in { -367, -349 } do
			-- a bench's end frames reach 2.7 either side of its centre line in z and 2.5 in x
			assert(math.abs(p.X - bx) > 2.5 + 0.8, "drinker " .. i .. " stands in a bench")
		end
		for j = i + 1, #spots do
			assert((spots[j].Position - p).Magnitude > 1.8, ("drinkers %d and %d overlap"):format(i, j))
		end
		local toCentre = (MatchdayRoutes.BAR_HUDDLE - p) * Vector3.new(1, 0, 1)
		assert(cf.LookVector:Dot(toCentre.Unit) > 0.99, "drinker " .. i .. " faces the huddle")
	end
end

-- X126: the kiosk queue stands in the grass between the hatch counter and the
-- footpath, clear of the pathside trees, facing the hatch.
function T.kioskQueueStandsBetweenHatchAndPath()
	local spots = MatchdayRoutes.kioskQueueSpots(3)
	assert(#spots == 3, "three fans")
	for i, cf in spots do
		local p = cf.Position
		assert(p.Z < 2.8 - 0.8, "fan " .. i .. " stands in the counter")
		assert(p.Z > -8 + 0.8, "fan " .. i .. " stands on the footpath")
		for _, tree in { Vector3.new(-326, 0, -2), Vector3.new(-302, 0, -2) } do
			assert((Vector3.new(p.X, 0, p.Z) - tree).Magnitude > 3, "fan " .. i .. " in a pathside tree")
		end
		assert(cf.LookVector.Z > 0.99, "fan " .. i .. " faces the hatch")
		if i > 1 then
			assert((spots[i - 1].Position - p).Magnitude > 1.9, "fans too close")
		end
	end
end

-- X161: leavers start at the turnstile end of the route, strung out behind the first
function T.leaversStartAtTheGateEnd()
	local route = MatchdayRoutes.ROUTES.fromTown
	local length = MatchdayRoutes.length(route)
	local n = 20
	local prev = math.huge
	for i = 1, n do
		local d = MatchdayRoutes.leavingStart(length, i, n)
		assert(d <= length and d >= length - MatchdayRoutes.LEAVE_SPREAD - 1e-6 and d >= 0, "start " .. d)
		assert(d < prev, "strung out in order")
		prev = d
	end
	assert(MatchdayRoutes.leavingStart(length, 1, 1) == length, "a lone leaver starts at the gate")
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

function T.concourseSpotsAreOnThePavingAndDoNotStack()
	local spots = MatchdayRoutes.concourseSpots(MatchdayRoutes.CONCOURSE_MAX, 5)
	assert(#spots == MatchdayRoutes.CONCOURSE_MAX, "should give every spot asked for")
	local box = MatchdayRoutes.CONCOURSE
	for i, cf in spots do
		local p = cf.Position
		assert(p.X >= box.x0 - 2 and p.X <= box.x1 + 2, "spot " .. i .. " is off the paving in X: " .. tostring(p.X))
		assert(p.Z >= box.z0 - 2 and p.Z <= box.z1 + 2, "spot " .. i .. " is off the paving in Z: " .. tostring(p.Z))
		for j = 1, i - 1 do
			local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(spots[j].Position.X, 0, spots[j].Position.Z)).Magnitude
			assert(d > 1.6, ("two people are stood on the same spot (%d and %d, %.1f apart)"):format(j, i, d))
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

function T.theHatchQueueFacesTheHatch()
	local spots = MatchdayRoutes.amenityQueueSpots(4)
	assert(#spots == 4, "four in the queue")
	for i, cf in spots do
		local toHatch = (MatchdayRoutes.AMENITY_HATCH - Vector3.new(cf.Position.X, 0, cf.Position.Z)).Unit
		local facing = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
		assert(facing:Dot(toHatch) > 0.3, "queuer " .. i .. " should be facing the hatch")
	end
	for i = 2, #spots do
		assert(spots[i].Position.Z > spots[i - 1].Position.Z, "the queue should stretch back from the hatch")
	end
end

return T
