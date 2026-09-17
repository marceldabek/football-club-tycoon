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

return T
