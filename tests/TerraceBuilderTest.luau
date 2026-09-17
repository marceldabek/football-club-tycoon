--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local TerraceBuilder = require(ServerScriptService.Server.TerraceBuilder)

local T = {}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-4
end

function T.houseCountIsOneBayPer16StudsWithAFloorOfTwo()
	assert(TerraceBuilder.houseCount(100) == 6, "100 -> " .. TerraceBuilder.houseCount(100))
	assert(TerraceBuilder.houseCount(130) == 8, "130 -> " .. TerraceBuilder.houseCount(130))
	assert(TerraceBuilder.houseCount(140) == 8, "140 -> " .. TerraceBuilder.houseCount(140))
	assert(TerraceBuilder.houseCount(32) == 2, "32 -> " .. TerraceBuilder.houseCount(32))
	assert(TerraceBuilder.houseCount(20) == 2, "short rows still get two houses")
	assert(TerraceBuilder.houseCount(0) == 2, "zero length still gets two houses")
end

function T.stacksSitOnEveryOtherPartyWall()
	-- 96 long: 6 houses of 16, party walls at -32, -16, 0, 16, 32; stacks on walls 1, 3, 5
	local z = TerraceBuilder.stackPositions(96)
	assert(#z == 3, "expected 3 stacks, got " .. #z)
	assert(near(z[1], -32) and near(z[2], 0) and near(z[3], 32), ("got %s %s %s"):format(tostring(z[1]), tostring(z[2]), tostring(z[3])))
	-- two houses share the single middle wall
	local two = TerraceBuilder.stackPositions(20)
	assert(#two == 1 and near(two[1], 0), "two-house row has one central stack")
end

function T.stacksCapAtFourAndStayInsideTheRow()
	for _, length in { 100, 120, 130, 140, 200, 400 } do
		local z = TerraceBuilder.stackPositions(length)
		assert(#z >= 1 and #z <= TerraceBuilder.MAX_STACKS, ("length %d gave %d stacks"):format(length, #z))
		local w = length / TerraceBuilder.houseCount(length)
		for i, v in z do
			assert(math.abs(v) <= length / 2 - w + 1e-4, ("length %d stack %d at %s is off the party walls"):format(length, i, tostring(v)))
			if i > 1 then
				assert(v > z[i - 1], "stacks must be in order along the row")
			end
		end
	end
	local long = TerraceBuilder.stackPositions(400) -- 25 houses, 12 candidate walls
	assert(#long == 4, "long rows cap at 4")
	assert(near(long[1], -200 + 16) and near(long[4], -200 + 23 * 16), "cap keeps both end stacks")
end

return T
