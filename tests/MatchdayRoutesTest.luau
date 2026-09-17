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

return T
