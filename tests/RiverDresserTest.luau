--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RiverDresser = require(ServerScriptService.Server.RiverDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.bankRunsSitOnTheNorthEdgeOfTheWater()
	local runs = RiverDresser.bankRuns(-220, 1200, 10)
	assert(#runs > 50, "expected many runs, got " .. #runs)
	for _, run in runs do
		assert(run.normal.Z < 0, "land normal must point north (-Z)")
		local mid = (run.a + run.b) / 2
		local d = TownLayout.distanceToPolyline(mid, TownLayout.RIVER.points)
		assert(math.abs(d - TownLayout.RIVER.width / 2) < 1.5, ("run midpoint %.1f from the centreline"):format(d))
		assert(TownLayout.riverSide(mid) < 0, "run is not on the north bank")
		assert(mid.X >= -220 and mid.X <= 1200, "run outside the requested reach")
	end
end

function T.bridgesAndBuildingsAreNotClear()
	for _, bridge in TownLayout.BRIDGES do
		assert(not RiverDresser.isClear(bridge.from:Lerp(bridge.to, 0.5)), bridge.name .. " should block the promenade")
	end
	local block = TownLayout.DISTRICTS[1].blocks[1]
	assert(not RiverDresser.isClear(block.centre), "a building should block the promenade")
end

return T
