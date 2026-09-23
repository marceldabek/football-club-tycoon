--!strict
-- #28 street trees on the verges and #31 front paths: the pure halves.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StreetTrees = require(ServerScriptService.Server.StreetTrees)
local FrontPaths = require(ReplicatedStorage.Shared.FrontPaths)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function T.streetTreesStandOnVergesClearOfTheRoadsStopsAndPlots()
	local spots = StreetTrees.spots()
	assert(#spots >= 60, "only " .. #spots .. " street trees")
	assert(#spots <= StreetTrees.MAX, "over the cap")
	local again = StreetTrees.spots()
	assert(#again == #spots and (again[1] - spots[1]).Magnitude < 1e-6, "same spots every build")
	for i, p in spots do
		-- off every road's paving: the nearest road is one with a verge, and the spot is past
		-- its paving
		for _, road in TownLayout.ROADS do
			local d = TownLayout.distanceToPolyline(p, road.points)
			assert(d > FrontPaths.pavingReach(road), ("tree %d is on %s's paving (%.1f)"):format(i, road.name, d))
		end
		for _, stop in TownLayout.BUS_STOPS do
			assert((flat(stop.position) - flat(p)).Magnitude >= StreetTrees.STOP_CLEAR, ("tree %d at the %s bus stop"):format(i, stop.name))
		end
		for _, rb in TownLayout.ROUNDABOUTS do
			assert((flat(rb.centre) - flat(p)).Magnitude > rb.radius + TownLayout.PAVEMENT_WIDTH, ("tree %d on %s"):format(i, rb.name))
		end
		for k = 1, #TownLayout.PLOTS do
			assert(not TownLayout.pointInPlot(p, k), ("tree %d on Plot %d"):format(i, k))
		end
	end
end

function T.onlyRingAndMainRoadsHaveVergesWideEnough()
	for _, road in TownLayout.ROADS do
		local offset = StreetTrees.vergeOffset(road)
		if road.kind == "residential" or road.kind == "lane" or road.kind == "alley" then
			assert(offset == nil, road.name .. " (" .. road.kind .. ") got street trees")
		end
		if offset then
			local corridor = RoadTiles.corridorHalf(road.kind, road.width) :: number
			assert(offset > FrontPaths.pavingReach(road) and offset < corridor, road.name .. "'s trees are off its verge")
		end
	end
end

function T.frontPathsCrossTheVergeToThePaving()
	local seen = 0
	for _, road in TownLayout.ROADS do
		local corridor = RoadTiles.corridorHalf(road.kind, road.width)
		-- a point well outside the town centre (RoadTiles.CENTRE), where PavingStrips widen the walked pavements
		local verge = FrontPaths.verge(road.name, false, Vector3.new(2000, 0, 1600), Vector3.xAxis)
		if corridor then
			seen += 1
			-- garden edge (the corridor) minus the verge lands on the paving's edge
			assert(math.abs(corridor - verge - FrontPaths.pavingReach(road, Vector3.new(2000, 0, 1600))) < 1e-6 or verge == FrontPaths.MAX_VERGE, road.name .. ": the path stops short of the paving")
			-- in the town centre the kit's own paving is all there is, so the path goes further
			local central = FrontPaths.verge(road.name, false, Vector3.zero, Vector3.xAxis)
			assert(central >= verge, road.name .. ": a town-centre path is shorter than one outside it")
		else
			assert(verge == 0, road.name .. " has no pavement but got a verge")
		end
		assert(FrontPaths.verge(road.name, true) == 0, "a lot closing a street gets no verge")
	end
	assert(seen > 20, "no roads with pavements")
	assert(FrontPaths.verge("No Such Street", false) == 0, "an unknown street has no verge")
	-- the path top shows over the tallest kit verge (a 45-degree bend's, 0.42) and stays a lip at
	-- the pavement strips (0.33)
	assert(FrontPaths.TOP > 0.42 and FrontPaths.TOP < 0.5, "front path height")
end

return T
