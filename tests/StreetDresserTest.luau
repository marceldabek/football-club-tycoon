--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StreetDresser = require(ServerScriptService.Server.StreetDresser)

local T = {}

function T.rowTurnsToFollowALongXBlock()
	local block = { centre = Vector3.new(100, 12, -172), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" }
	local cf, scale = StreetDresser.rowPlacement(block)
	-- the kit row runs along its local Z; after placement that must be world X
	local along = cf.LookVector
	assert(math.abs(math.abs(along.X) - 1) < 1e-4 and math.abs(along.Z) < 1e-4, "row not along X: " .. tostring(along))
	assert(math.abs(scale - 130 / 128) < 1e-4, "scale " .. scale)
	assert((cf.Position - Vector3.new(100, 0, -172)).Magnitude < 1e-4, "position " .. tostring(cf.Position))
end

function T.rowKeepsALongZBlockAndClampsScale()
	local block = { centre = Vector3.new(0, 12, 0), size = Vector3.new(24, 24, 300), yaw = 0, use = "terraced row" }
	local cf, scale = StreetDresser.rowPlacement(block)
	assert(math.abs(math.abs(cf.LookVector.Z) - 1) < 1e-4, "row not along Z")
	assert(scale == 1.2, "scale should clamp to 1.2, got " .. scale)
end

function T.stationsAreEvenlySpacedAcrossBends()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100) }
	local st = StreetDresser.stations(points, 40)
	assert(#st == 5, "expected 5 stations, got " .. #st) -- 20, 60, 100 on the first leg, then 40, 80 on the second
	assert((st[1].position - Vector3.new(20, 0, 0)).Magnitude < 1e-4, "first station")
	assert((st[2].position - Vector3.new(60, 0, 0)).Magnitude < 1e-4, "second station")
	assert((st[3].position - Vector3.new(100, 0, 0)).Magnitude < 1e-4, "third station at the corner")
	assert((st[4].position - Vector3.new(100, 0, 40)).Magnitude < 1e-4, "fourth station on the second leg")
	assert(st[4].direction.Z > 0.99, "direction follows the second leg")
end

return T
