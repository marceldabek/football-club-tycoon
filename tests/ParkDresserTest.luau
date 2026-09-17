--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParkDresser = require(ServerScriptService.Server.ParkDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function getPlan(): ParkDresser.Plan
	local plan = ParkDresser.plan()
	assert(plan, "TownLayout should have a park lawn")
	return plan
end

function T.octagonHasEightEqualSidesAtTheRadius()
	local centre = Vector3.new(10, 0, -20)
	local points = ParkDresser.octagonPoints(centre, 12, math.pi / 8)
	assert(#points == 8, "expected 8 points, got " .. #points)
	local side = (points[1] - points[8]).Magnitude
	for i, p in points do
		assert(math.abs(flatDistance(p, centre) - 12) < 1e-4, "point " .. i .. " is off the radius")
		assert(p.Y == centre.Y, "points stay at the centre's height")
		local q = points[i % 8 + 1]
		assert(math.abs((q - p).Magnitude - side) < 1e-4, "sides should all be equal")
	end
	-- offset pi/8: the east edge is square to X, at the apothem
	local mid = (points[1] + points[8]) / 2
	assert(math.abs(mid.Z - centre.Z) < 1e-4, "east edge midpoint should be due east")
	assert(math.abs(mid.X - centre.X - 12 * math.cos(math.pi / 8)) < 1e-4, "edge midpoint at the apothem")
end

function T.loopIsClosedAndOnTheEllipse()
	local centre = Vector3.new(100, 0, 50)
	local loop = ParkDresser.loopPoints(centre, 40, 25, 20)
	assert(#loop == 21, "20 segments need 21 points")
	assert(loop[1] == loop[21], "loop should close")
	for _, p in loop do
		local e = ((p.X - centre.X) / 40) ^ 2 + ((p.Z - centre.Z) / 25) ^ 2
		assert(math.abs(e - 1) < 1e-6, "point off the ellipse")
	end
	assert(math.abs(ParkDresser.ellipseHalf(40, 25, 0) - 25) < 1e-9)
	assert(ParkDresser.ellipseHalf(40, 25, 50) == 0, "outside the ellipse clamps to 0")
end

function T.planSitsInsideTheLawnAndFeaturesDoNotOverlap()
	local plan = getPlan()
	for _, p in plan.loop do
		assert(ParkDresser.inPark(plan, p, 10), "loop leaves the lawn")
	end
	assert(ParkDresser.inPark(plan, plan.pond.centre, plan.pond.radius), "pond leaves the lawn")
	local g = plan.playground
	assert(ParkDresser.inPark(plan, g.centre, math.max(g.size.X, g.size.Z) / 2), "playground leaves the lawn")
	-- pond, playground and plaza keep apart
	assert(flatDistance(plan.pond.centre, plan.plaza.centre) > plan.pond.radius + plan.plaza.radius + 10, "pond hits the plaza")
	local dx = math.abs(g.centre.X - plan.plaza.centre.X) - g.size.X / 2
	local dz = math.abs(g.centre.Z - plan.plaza.centre.Z) - g.size.Z / 2
	assert(math.max(dx, dz) > plan.plaza.radius, "playground hits the plaza")
	-- nothing on the loop runs through the pond or the playground
	for _, p in plan.loop do
		assert(flatDistance(p, plan.pond.centre) > plan.pond.radius + 8, "loop runs through the pond")
		assert(math.abs(p.X - g.centre.X) > g.size.X / 2 + 4 or math.abs(p.Z - g.centre.Z) > g.size.Z / 2 + 4, "loop runs through the playground")
	end
end

function T.pathsAvoidBuildingsAndEntrancesReachARoad()
	local plan = getPlan()
	local all = table.clone(plan.paths)
	table.insert(all, plan.loop)
	table.insert(all, plan.crossing)
	for _, path in all do
		for k = 1, #path - 1 do
			local a, b = path[k], path[k + 1]
			local n = math.max(1, math.ceil((b - a).Magnitude / 2))
			for j = 0, n do
				local p = a:Lerp(b, j / n)
				assert(not ParkDresser.hitsBuilding(p, 0), ("path runs into a building at %.0f, %.0f"):format(p.X, p.Z))
			end
		end
	end
	local entrance = plan.entrance
	assert(entrance, "the south path should reach a road")
	local nearest = math.huge
	for _, road in TownLayout.ROADS do
		nearest = math.min(nearest, TownLayout.distanceToPolyline(entrance, road.points) - road.width / 2)
	end
	assert(nearest <= TownLayout.PAVEMENT_WIDTH and nearest > 0, "entrance should end on a pavement, not the carriageway")
end

function T.buildingsRoadsAndRiverAreNotClear()
	local stand = ParkDresser.findBlock("bandstand")
	assert(stand, "bandstand block")
	assert(not ParkDresser.isClear(stand.centre), "the bandstand should not be clear")
	local cafe = ParkDresser.findBlock("park cafe")
	if cafe then
		assert(not ParkDresser.isClear(cafe.centre), "the park cafe should not be clear")
	end
	local road = TownLayout.ROADS[1]
	assert(not ParkDresser.isClear(road.points[1]:Lerp(road.points[2], 0.5)), "a carriageway should not be clear")
	local river = TownLayout.RIVER.points
	assert(not ParkDresser.isClear(river[2]:Lerp(river[3], 0.5)), "the river should not be clear")
	local lawn = ParkDresser.findBlock("park lawn")
	assert(lawn, "park lawn block")
	assert(not ParkDresser.hitsBuilding(Vector3.new(lawn.centre.X + 60, 0, lawn.centre.Z + 150), 0), "open lawn is not a building")
end

function T.treesAreClearAndInsideThePark()
	local plan = getPlan()
	local trees = ParkDresser.treePositions(plan, Random.new(1884))
	assert(#trees >= 20, "expected a proper park of trees, got " .. #trees)
	assert(#trees <= ParkDresser.MAX_TREES, "too many trees for the part budget")
	for i, p in trees do
		assert(ParkDresser.inPark(plan, p, 0), "tree outside the park")
		assert(ParkDresser.isClear(p, 6), "tree on a road, building or the river")
		assert(ParkDresser.clearOfPaths(plan, p, 2), "tree on a path")
		assert(flatDistance(p, plan.pond.centre) > plan.pond.radius + 2.5, "tree in the pond")
		for j = i + 1, #trees do
			assert(flatDistance(p, trees[j]) >= 14 - 1e-6, "trees too close together")
		end
	end
end

function T.treePositionsAreDeterministic()
	local plan = getPlan()
	local a = ParkDresser.treePositions(plan, Random.new(42))
	local b = ParkDresser.treePositions(plan, Random.new(42))
	assert(#a == #b, "same seed, same count")
	for i = 1, #a do
		assert(a[i] == b[i], "same seed, same positions")
	end
end

function T.furnitureIsClearOfPathsAndBuildings()
	local plan = getPlan()
	assert(#plan.benches >= 6, "expected benches, got " .. #plan.benches)
	assert(#plan.lamps >= 4, "expected lamps, got " .. #plan.lamps)
	for _, cf in plan.benches do
		assert(ParkDresser.isClear(cf.Position, 1), "bench not clear")
		assert(ParkDresser.clearOfPaths(plan, cf.Position, 1), "bench on a path")
	end
	for _, cf in plan.lamps do
		assert(ParkDresser.isClear(cf.Position, 1), "lamp not clear")
		assert(ParkDresser.clearOfPaths(plan, cf.Position, 0.5), "lamp on a path")
	end
	for _, p in plan.bins do
		assert(ParkDresser.clearOfPaths(plan, p, 0.5), "bin on a path")
	end
end

return T
