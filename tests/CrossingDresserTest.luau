--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrossingDresser = require(ServerScriptService.Server.CrossingDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

-- a synthetic T far from town: a residential side road ending on a main road
local O = Vector3.new(6000, 0, 6000)
local MAIN: TownLayout.Road = { name = "Test Main", kind = "main", width = 24, points = { O + Vector3.new(-200, 0, 0), O + Vector3.new(200, 0, 0) } }
local SIDE: TownLayout.Road = { name = "Test Side", kind = "residential", width = 20, points = { O, O + Vector3.new(0, 0, 150) } }

function T.aTJunctionGetsASlabEitherSideOfTheMouthOnTheMainRoadPavement()
	local slabs = CrossingDresser.slabs(SIDE, { MAIN, SIDE })
	assert(#slabs == 2, "two slabs, got " .. #slabs)
	for _, slab in slabs do
		local c = slab.cframe.Position
		local across = c.Z - O.Z -- distance out from the main road's centre line
		assert(across - CrossingDresser.CROSSING_WIDTH / 2 >= MAIN.width / 2 - 1e-3, "starts at or past the main road kerb")
		assert(across + CrossingDresser.CROSSING_WIDTH / 2 <= MAIN.width / 2 + TownLayout.PAVEMENT_WIDTH + 1e-3, "ends inside the main road pavement")
		local along = math.abs(c.X - O.X)
		assert(math.abs(along - (SIDE.width / 2 + CrossingDresser.CROSSING_DEPTH / 2)) < 1e-3, "against the side road's carriageway edge")
	end
	assert(math.abs(slabs[1].cframe.Position.X - slabs[2].cframe.Position.X) > SIDE.width, "one on each side of the mouth")
end

function T.theThroughRoadAndLanesGetNone()
	assert(#CrossingDresser.slabs(MAIN, { MAIN, SIDE }) == 0, "the main road passes straight through")
	local lane: TownLayout.Road = { name = "Test Lane", kind = "lane", width = 12, points = MAIN.points }
	assert(#CrossingDresser.slabs(SIDE, { lane, SIDE }) == 0, "no slabs on a lane with no pavement")
end

return T
