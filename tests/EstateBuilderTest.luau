--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local EstateBuilder = require(ServerScriptService.Server.EstateBuilder)
local EstateDresser = require(ServerScriptService.Server.EstateDresser)

local T = {}

function T.pairCountIsOnePairForABlockPairAndScalesByFortyEightForLongerRows()
	assert(EstateBuilder.pairCount(40) == 1, "40 -> " .. EstateBuilder.pairCount(40))
	assert(EstateBuilder.pairCount(50) == 1, "50 -> " .. EstateBuilder.pairCount(50))
	assert(EstateBuilder.pairCount(100) == 2, "100 -> " .. EstateBuilder.pairCount(100))
	assert(EstateBuilder.pairCount(120) == 2, "120 -> " .. EstateBuilder.pairCount(120))
	assert(EstateBuilder.pairCount(150) == 3, "150 -> " .. EstateBuilder.pairCount(150))
	assert(EstateBuilder.pairCount(10) == 1, "a very short block still gets one pair")
	assert(EstateBuilder.pairCount(0) == 1, "a zero-length block still gets one pair")
end

function T.frontSidePicksTheSideNearestARoad()
	local block = { centre = Vector3.new(0, 12, 0), size = Vector3.new(100, 20, 24), yaw = 0, use = "semis" }

	local westRoad = { name = "West St", kind = "residential", width = 20, points = { Vector3.new(-80, 0, -200), Vector3.new(-80, 0, 200) } }
	assert(EstateDresser.frontSide(block, { westRoad }) == "-X", "west road should pick -X, got " .. EstateDresser.frontSide(block, { westRoad }))

	local eastRoad = { name = "East St", kind = "residential", width = 20, points = { Vector3.new(80, 0, -200), Vector3.new(80, 0, 200) } }
	assert(EstateDresser.frontSide(block, { eastRoad }) == "+X", "east road should pick +X, got " .. EstateDresser.frontSide(block, { eastRoad }))

	local northRoad = { name = "North St", kind = "residential", width = 20, points = { Vector3.new(-200, 0, -60), Vector3.new(200, 0, -60) } }
	assert(EstateDresser.frontSide(block, { northRoad }) == "-Z", "north (-Z) road should pick -Z, got " .. EstateDresser.frontSide(block, { northRoad }))

	local southRoad = { name = "South St", kind = "residential", width = 20, points = { Vector3.new(-200, 0, 60), Vector3.new(200, 0, 60) } }
	assert(EstateDresser.frontSide(block, { southRoad }) == "+Z", "south (+Z) road should pick +Z, got " .. EstateDresser.frontSide(block, { southRoad }))
end

function T.frontSideAccountsForBlockYaw()
	-- yawed 90 degrees: the block's local -X side now sits at world +Z
	local block = { centre = Vector3.new(0, 10, 0), size = Vector3.new(100, 20, 24), yaw = 90, use = "warehouse" }
	local road = { name = "R", kind = "main", width = 20, points = { Vector3.new(-200, 0, 60), Vector3.new(200, 0, 60) } }
	assert(EstateDresser.frontSide(block, { road }) == "-X", "yawed block should still pick its own -X side, got " .. EstateDresser.frontSide(block, { road }))
end

function T.frontSidePicksTheClosestOfSeveralRoads()
	-- a block near two roads: one runs vertically 20 studs east of the +X
	-- side, the other horizontally 5 studs north of the -Z side. Even though
	-- the vertical road is checked first, the closer horizontal one must win,
	-- so the function has to take the minimum over every road for every side
	-- rather than stopping at the first road that has an opinion.
	local block = { centre = Vector3.new(500, 10, -300), size = Vector3.new(80, 20, 50), yaw = 0, use = "workshop" }
	local eastRoad = { name = "East", kind = "main", width = 26, points = { Vector3.new(560, 0, -1000), Vector3.new(560, 0, 1000) } }
	local northRoad = { name = "North", kind = "residential", width = 20, points = { Vector3.new(300, 0, -320), Vector3.new(900, 0, -320) } }
	assert(EstateDresser.frontSide(block, { eastRoad, northRoad }) == "-Z", "the nearer road (north) should win, got " .. EstateDresser.frontSide(block, { eastRoad, northRoad }))
end

return T
