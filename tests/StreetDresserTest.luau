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

function T.lightStreetsPickTheDistrictsResidentialStreets()
	local function names(district: string): { [string]: boolean }
		local out: { [string]: boolean } = {}
		for _, road in StreetDresser.lightStreets(district) do
			out[road.name] = true
		end
		return out
	end
	local north = names("Northfields")
	assert(north["Northfields Avenue"] and north["Hayfield Close"] and north["Rowan Close"], "Northfields streets missing")
	assert(not north["Mill Street"] and not north["Elm Grove"] and not north["North Road"], "Northfields picked a street it should not")
	local west = names("Westdale")
	assert(west["Westdale Avenue"] and west["Westdale Crescent"], "Westdale streets missing")
	assert(not west["Sports Centre Road"], "Sports Centre Road is not Westdale's")
end

function T.lightRowsFaceTheNearestRoad()
	-- north of Northfields Avenue (z = -600): the front must face -Z
	local cf = StreetDresser.lightRowPlacement({ centre = Vector3.new(-290, 12, -570), size = Vector3.new(100, 24, 24), yaw = 0, use = "terraced row" })
	assert(cf:VectorToWorldSpace(Vector3.new(-1, 0, 0)).Z < -0.99, "row at z -570 should face the avenue")
	assert(math.abs(math.abs(cf.LookVector.X) - 1) < 1e-4, "row still runs along X")
	-- west of Rowan Close (x = -200): the front must face +X
	local cf2 = StreetDresser.lightRowPlacement({ centre = Vector3.new(-230, 12, -720), size = Vector3.new(24, 24, 100), yaw = 0, use = "terraced row" })
	assert(cf2:VectorToWorldSpace(Vector3.new(-1, 0, 0)).X > 0.99, "row at x -230 should face the close")
end

function T.polylineMidpointIsHalfwayByLength()
	local mid = StreetDresser.polylineMidpoint({ Vector3.new(0, 0, 800), Vector3.new(0, 0, 1200), Vector3.new(450, 0, 1200) })
	assert((mid - Vector3.new(25, 0, 1200)).Magnitude < 1e-4, "midpoint " .. tostring(mid))
end

return T
