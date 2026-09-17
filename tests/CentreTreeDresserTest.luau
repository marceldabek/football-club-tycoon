--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CentreTreeDresser = require(ServerScriptService.Server.CentreTreeDresser)
local TerraceStreetDresser = require(ServerScriptService.Server.TerraceStreetDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.centreRoadsGetKerbTreesNearTheSquareOnly()
	local total = 0
	local centre = TownLayout.SQUARE.centre
	for _, name in CentreTreeDresser.ROADS do
		local road
		for _, r in TownLayout.ROADS do
			if r.name == name then
				road = r
			end
		end
		assert(road, "no road " .. name)
		assert(road.kind == "main", name .. " is not a main road")
		for _, spot in CentreTreeDresser.spots(road) do
			total += 1
			local p = spot.position
			local fromSquare = Vector3.new(p.X - centre.X, 0, p.Z - centre.Z).Magnitude
			assert(fromSquare <= CentreTreeDresser.CENTRE_RADIUS, name .. " tree beyond the centre")
			assert(fromSquare > TownLayout.SQUARE.radius + TownLayout.PAVEMENT_WIDTH, name .. " tree in the square")
			local d = TownLayout.distanceToPolyline(p, road.points)
			assert(math.abs(d - (road.width / 2 + TerraceStreetDresser.TREE_INSET)) < 0.1, ("%s tree %.2f off the centre line"):format(name, d))
		end
	end
	assert(total >= 8, "only " .. total .. " candidate trees")
end

return T
