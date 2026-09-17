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

-- X99: aerials and dishes are seeded by position (same answer every build),
-- land on roughly their TEMP share of rows, and a dish sits in the upper
-- floor of its own house bay, clear of the front wall.
function T.aerialsAndDishesAreSeededSparseAndOnTheFront()
	local a1, d1 = TerraceBuilder.extras(Vector3.new(120, 0, -333), 6, 3)
	local a2, d2 = TerraceBuilder.extras(Vector3.new(120, 0, -333), 6, 3)
	assert(a1 == a2 and d1 == d2, "same position, same extras")
	local aerials, dishes, n = 0, 0, 400
	for i = 1, n do
		local a, d = TerraceBuilder.extras(Vector3.new(i * 37.3, 0, i * -21.9), 5, 2)
		if a then
			aerials += 1
			assert(a >= 1 and a <= 2, "aerial stack " .. a)
		end
		if d then
			dishes += 1
			assert(d >= 0 and d <= 4, "dish house " .. d)
		end
	end
	for _, pair in { { aerials, TerraceBuilder.AERIAL_SHARE }, { dishes, TerraceBuilder.DISH_SHARE } } do
		local share = pair[1] / n
		assert(math.abs(share - pair[2]) < 0.1, ("share %.2f want about %.2f"):format(share, pair[2]))
	end
	local a0 = TerraceBuilder.extras(Vector3.new(5, 0, 5), 2, 0)
	assert(a0 == nil, "no aerial without a stack")
	for _, facade in { "front_a", "front_b", "front_c" } do
		local z, y = TerraceBuilder.dishSpot(facade, 2, 16, 96, 16)
		assert(z > -48 + 2 * 16 + 1 and z < -48 + 3 * 16 - 1, facade .. " dish outside its bay: " .. z)
		assert(y > 16 / 2 and y < 16 - 1, facade .. " dish not on the upper floor: " .. y)
	end
	local holder = Instance.new("Folder")
	for i = 1, 30 do
		local row = TerraceBuilder.row(CFrame.new(i * 51.7, 0, i * 13.1), 96, 24, 24, holder, Random.new(i))
		local parts = 0
		for _, d in row:GetChildren() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		assert(parts <= 16, "row parts " .. parts)
		local dish = row:FindFirstChild("Dish") :: BasePart?
		if dish then
			local lx = row.Body.CFrame:PointToObjectSpace(dish.Position).X
			assert(lx < -12 - 0.4, "dish clear of the front wall: " .. lx)
		end
	end
	holder:Destroy()
end

return T
