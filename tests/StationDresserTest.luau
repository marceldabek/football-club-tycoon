--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StationDresser = require(ServerScriptService.Server.StationDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.frontFacesAwayFromTheRailway()
	local f = StationDresser.frontFrame()
	local station = TownLayout.RAIL.station
	local centre = Vector3.new(station.centre.X, 0, station.centre.Z)
	assert(math.abs((f.Position - centre).Magnitude - station.size.Z / 2) < 0.01, "origin should sit on a long wall")
	local out = f.LookVector * -1 -- +Z of the frame
	local near = TownLayout.distanceToPolyline(f.Position + out * 20, TownLayout.RAIL.points)
	local far = TownLayout.distanceToPolyline(f.Position - out * 20, TownLayout.RAIL.points)
	assert(near > far, "the forecourt should be further from the rails than the building")
end

return T
