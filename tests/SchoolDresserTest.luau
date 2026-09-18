--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SchoolDresser = require(ServerScriptService.Server.SchoolDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.everySchoolBlockIsFound()
	local blocks = 0
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use == "school" then
				blocks += 1
			end
		end
	end
	assert(blocks > 0, "the town should have schools in it")
	assert(#SchoolDresser.schools() == blocks, "every school block should be dressed")
end

function T.eachSchoolFacesARoad()
	for _, school in SchoolDresser.schools() do
		local axis = school.toRoad
		assert(math.abs(axis.Y) < 0.001, "the road direction is flat")
		assert(math.abs(math.abs(axis.X) + math.abs(axis.Z) - 1) < 0.001, "and is one of the four axes")
		assert(school.roadDistance >= 0 and school.roadDistance < 400, "the nearest road should be findable: " .. tostring(school.roadDistance))
		assert(school.roadHalf > 0, "and should have a width")
	end
end

function T.theRoadItFacesIsTheNearestOne()
	for _, school in SchoolDresser.schools() do
		local half = if math.abs(school.toRoad.X) > 0.5 then school.size.X / 2 else school.size.Z / 2
		local chosen = TownLayout.distanceToPolyline(school.centre + school.toRoad * (half + 10), TownLayout.ROADS[1].points)
		local best = math.huge
		for _, axis in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local h = if math.abs(axis.X) > 0.5 then school.size.X / 2 else school.size.Z / 2
			for _, road in TownLayout.ROADS do
				best = math.min(best, TownLayout.distanceToPolyline(school.centre + axis * (h + 10), road.points))
			end
		end
		assert(math.abs(school.roadDistance - best) < 0.001, "the chosen side should be the closest to any road")
		assert(chosen >= 0, "sanity")
	end
end

return T
