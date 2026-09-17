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

function T.clearRejectsARoadCentre()
	local road = TownLayout.ROADS[1]
	assert(not GreeneryDresser.clear(road.points[1]), "a road centre point is not clear")
end

return T
