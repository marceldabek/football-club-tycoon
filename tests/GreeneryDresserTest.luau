--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GreeneryDresser = require(ServerScriptService.Server.GreeneryDresser)
local StreetDresser = require(ServerScriptService.Server.StreetDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.greenerySpotsStayOffRoadsBuildingsRiverAndPlots()
	local spots = GreeneryDresser.spots()
	assert(#spots >= 40, "only " .. #spots .. " greenery spots")
	assert(#spots <= GreeneryDresser.MAX, "over the cap")
	local south = 0
	for _, p in spots do
		if p.Z > 600 then
			south += 1
		end
	end
	assert(south >= 10, "Westdale (south of the river) gets greenery too, got " .. south)
	local again = GreeneryDresser.spots()
	assert(#again == #spots and (again[1] - spots[1]).Magnitude < 1e-6, "seeded: same spots every build")
	for i, p in spots do
		for _, road in TownLayout.ROADS do
			local reach = road.width / 2 + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH)
			assert(TownLayout.distanceToPolyline(p, road.points) > reach, ("spot %d on %s"):format(i, road.name))
		end
		for _, district in TownLayout.DISTRICTS do
			for _, block in district.blocks do
				assert(StreetDresser.distanceToBlock(p, block) > 1, ("spot %d in a %s block"):format(i, block.use))
			end
		end
		assert(TownLayout.distanceToPolyline(p, TownLayout.RIVER.points) > TownLayout.RIVER.width / 2, "spot in the river")
		for k = 1, #TownLayout.PLOTS do
			assert(not TownLayout.pointInPlot(p, k), "spot inside plot " .. k)
		end
	end
end

-- v3: houses are TownFrontage lots; no tree may stand in a house or its garden
function T.greenerySpotsStayOutOfEveryLotAndReachEveryHousingDistrict()
	local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)
	local spots = GreeneryDresser.spots()
	local lots = TownFrontage.generate()
	for i, p in spots do
		for _, lot in lots do
			assert(not GreeneryDresser.inLot(p, lot, 0), ("spot %d stands in lot %s"):format(i, lot.id))
		end
	end
	-- Mill Street Terraces has no DISTRICTS blocks at all in v3; it must still get trees
	local mill = 0
	for _, p in spots do
		if p.X > -50 and p.X < 450 and p.Z < -60 and p.Z > -700 then
			mill += 1
		end
	end
	assert(mill >= 5, "Mill Street Terraces should get greenery from its lots' area, got " .. mill)
end

function T.clearRejectsALotCentre()
	local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)
	local lot = TownFrontage.generate()[1]
	assert(not GreeneryDresser.clear(lot.centre), "a lot centre is not clear")
end

function T.clearRejectsARoadCentre()
	local road = TownLayout.ROADS[1]
	assert(not GreeneryDresser.clear(road.points[1]), "a road centre point is not clear")
end

return T
