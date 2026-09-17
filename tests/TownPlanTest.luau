--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownPlan = require(ReplicatedStorage.Shared.TownPlan)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.boundsHoldEveryStopAndPlot()
	local b = TownPlan.bounds(150)
	for _, stop in TownLayout.BUS_STOPS do
		assert(stop.position.X > b.minX and stop.position.X < b.maxX, stop.name .. " outside the plan in X")
		assert(stop.position.Z > b.minZ and stop.position.Z < b.maxZ, stop.name .. " outside the plan in Z")
	end
	for _, plot in TownLayout.PLOTS do
		assert(plot.centre.X > b.minX and plot.centre.X < b.maxX, plot.name .. " outside the plan in X")
		assert(plot.centre.Z > b.minZ and plot.centre.Z < b.maxZ, plot.name .. " outside the plan in Z")
	end
end

function T.everyStopProjectsInsideTheRectangle()
	-- the card's own size, and a narrow phone's, since the card shrinks
	for _, size in { Vector2.new(332, 148), Vector2.new(260, 120), Vector2.new(166, 74) } do
		local plan = TownPlan.fit(size.X, size.Y)
		for _, stop in TownLayout.BUS_STOPS do
			local p = TownPlan.project(plan, stop.position)
			assert(p.X >= 0 and p.X <= size.X, ("%s projected off a %d-wide card: %s"):format(stop.name, size.X, tostring(p.X)))
			assert(p.Y >= 0 and p.Y <= size.Y, ("%s projected off a %d-tall card: %s"):format(stop.name, size.Y, tostring(p.Y)))
		end
	end
end

function T.theFitKeepsTheTownsShape()
	local plan = TownPlan.fit(332, 150)
	local a = TownPlan.project(plan, Vector3.new(0, 0, 0))
	local alongX = TownPlan.project(plan, Vector3.new(500, 0, 0)) - a
	local alongZ = TownPlan.project(plan, Vector3.new(0, 0, 500)) - a
	assert(math.abs(alongX.X - alongZ.Y) < 0.001, "the same distance should be the same number of pixels either way")
	assert(alongX.X > 0 and alongZ.Y > 0, "east should be right and south should be down")
end

function T.northIsUpAndEastIsRight()
	local plan = TownPlan.fit(332, 150)
	local centre = TownPlan.project(plan, Vector3.new(0, 0, 0))
	local north = TownPlan.project(plan, Vector3.new(0, 0, -800))
	local east = TownPlan.project(plan, Vector3.new(800, 0, 0))
	assert(north.Y < centre.Y, "north should be higher up the card")
	assert(east.X > centre.X, "east should be further right")
end

function T.simplifyKeepsTheEndsAndTheCount()
	local points = {}
	for i = 1, 19 do
		table.insert(points, Vector3.new(i * 10, 0, 0))
	end
	local thin = TownPlan.simplify(points, 8)
	assert(#thin == 8, "should keep exactly the asked-for count, got " .. #thin)
	assert(thin[1] == points[1], "the first point should survive")
	assert(thin[#thin] == points[#points], "the last point should survive")
	local same = TownPlan.simplify(points, 40)
	assert(#same == #points, "asking for more points than there are should change nothing")
end

function T.distanceTextRoundsLikeASignpost()
	assert(TownPlan.distanceText(0) == "0 m", "zero should read 0 m")
	-- 2.75 studs to the metre
	assert(TownPlan.distanceText(137.5) == "50 m", "137.5 studs is 50 m, got " .. TownPlan.distanceText(137.5))
	assert(TownPlan.distanceText(1100) == "400 m", "1100 studs is 400 m, got " .. TownPlan.distanceText(1100))
	assert(TownPlan.distanceText(3850) == "1.4 km", "3850 studs is 1.4 km, got " .. TownPlan.distanceText(3850))
	-- review: 950-999 m used to round up into "1.0 km"
	assert(TownPlan.distanceText(2700) == "980 m", "2700 studs is 980 m, got " .. TownPlan.distanceText(2700))
	assert(TownPlan.distanceText(2750) == "1.0 km", "2750 studs is exactly 1 km, got " .. TownPlan.distanceText(2750))
end

function T.walkTimeIsMinutesAtWalkingPace()
	assert(TownPlan.walkTimeText(100) == "<1 min", "100 studs is well under a minute")
	-- 16 studs a second: 960 studs is a minute
	assert(TownPlan.walkTimeText(960) == "1 min", "960 studs should be 1 min, got " .. TownPlan.walkTimeText(960))
	assert(TownPlan.walkTimeText(2880) == "3 min", "2880 studs should be 3 min, got " .. TownPlan.walkTimeText(2880))
end

function T.walkLabelPutsBoth()
	local label = TownPlan.walkLabel(1100)
	assert(label:find("400 m", 1, true), "the label should carry the distance: " .. label)
	assert(label:find("min", 1, true), "the label should carry the time: " .. label)
end

function T.walkableIsTheShortTrips()
	assert(TownPlan.isWalkable(500), "500 studs is a walk")
	assert(not TownPlan.isWalkable(1500), "1500 studs is past a minute on foot, so it is a bus ride")
	assert(not TownPlan.isWalkable(4000), "4000 studs is a bus ride")
end

function T.everyDestinationNameResolvesToAStop()
	for _, stop in TownLayout.BUS_STOPS do
		local found = TownPlan.stop(stop.name)
		assert(found ~= nil and found.position == stop.position, "lookup failed for " .. stop.name)
	end
	assert(TownPlan.stop("Nowhere") == nil, "an unknown name should not resolve")
end

function T.flatDistanceIgnoresHeight()
	local a = Vector3.new(0, 0, 0)
	local b = Vector3.new(300, 900, 400)
	assert(math.abs(TownPlan.flatDistance(a, b) - 500) < 0.001, "height should not count towards a walk")
end

return T
