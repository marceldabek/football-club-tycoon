--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ShopBuilder = require(ServerScriptService.Server.ShopBuilder)
local ShopDresser = require(ServerScriptService.Server.ShopDresser)

local T = {}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-4
end

-- local -X of a yaw, in world space
local function front(yaw: number): Vector3
	return CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(-1, 0, 0))
end

local function road(name: string, a: Vector3, b: Vector3): any
	return { name = name, kind = "residential", width = 20, points = { a, b } }
end

function T.bayCountIsAboutTwentyStudsWithAFloorOfOne()
	assert(ShopBuilder.bayCount(100) == 5, "100 -> " .. ShopBuilder.bayCount(100))
	assert(ShopBuilder.bayCount(120) == 6, "120 -> " .. ShopBuilder.bayCount(120))
	assert(ShopBuilder.bayCount(30) == 2, "30 -> " .. ShopBuilder.bayCount(30))
	assert(ShopBuilder.bayCount(24) == 1, "24 -> " .. ShopBuilder.bayCount(24))
	assert(ShopBuilder.bayCount(40) == 2, "40 -> " .. ShopBuilder.bayCount(40))
	assert(ShopBuilder.bayCount(0) == 1, "zero length still gets one bay")
end

function T.storeysSplitGroundFloorAndRoof()
	local f, wall, roof = ShopBuilder.storeys(30)
	assert(f == 1 and wall == 22 and roof == 8, ("30 -> %d %d %d"):format(f, wall, roof))
	f, wall, roof = ShopBuilder.storeys(24)
	assert(f == 1 and wall == 22 and roof == 3, ("24 -> %d %d %d"):format(f, wall, roof))
	f, wall, roof = ShopBuilder.storeys(36)
	assert(f == 2 and wall == 36 and roof == 0, ("36 -> %d %d %d"):format(f, wall, roof))
	f, wall, roof = ShopBuilder.storeys(14)
	assert(f == 0 and wall == 14 and roof == 0, ("14 -> %d %d %d"):format(f, wall, roof))
end

function T.baysFillTheFrontage()
	for _, case in { { length = 100, kind = "shops" }, { length = 30, kind = "pub" }, { length = 100, kind = "supermarket" }, { length = 50, kind = "supermarket" } } do
		local length, kind = case.length, case.kind
		local bays = ShopBuilder.bays(length, kind)
		local z = -length / 2
		for i, bay in bays do
			assert(near(bay.centre - bay.width / 2, z), ("%s %d bay %d does not start where the last ended"):format(kind, length, i))
			z = bay.centre + bay.width / 2
		end
		assert(near(z, length / 2), ("%s %d bays stop short"):format(kind, length))
	end
	local market = ShopBuilder.bays(100, "supermarket")
	assert(#market == 3 and market[2].wide and near(market[2].width, 60), "100-long supermarket: 20 + wide 60 + 20")
	local small = ShopBuilder.bays(50, "supermarket")
	assert(#small == 1 and small[1].wide, "short supermarket is one wide bay")
end

function T.frontsForPubsCornersAndShops()
	local pub = ShopBuilder.frontsFor("pub", 3, Random.new(1))
	assert(pub[1] == "shop_front_pub" and pub[2] == "shop_front_cafe", "pub first then cafe")
	assert(pub[3] ~= "shop_front_pub" and pub[3] ~= "shop_front_cafe", "then something else")
	assert(ShopBuilder.frontsFor("corner shop", 2, Random.new(1), "Northfields")[1] == "shop_front_corner2", "Northfields Stores")
	assert(ShopBuilder.frontsFor("corner shop", 1, Random.new(1), "Westdale")[1] == "shop_front_corner", "Westdale Stores")
	local shops = ShopBuilder.frontsFor("shops", 6, Random.new(7))
	local seen: { [string]: boolean } = {}
	for _, key in shops do
		assert(not seen[key], "shops repeat a front: " .. key)
		assert(ShopBuilder.TEXTURES[key] ~= nil, "no texture key " .. key)
		seen[key] = true
	end
	assert(#ShopBuilder.frontsFor("shops", 12, Random.new(7)) == 12, "cycles past nine")
end

function T.facingYawTurnsTheFrontToTheNearestRoad()
	-- long-X block with a road to the north (-Z): front faces -Z
	local block = { centre = Vector3.new(0, 15, 0), size = Vector3.new(100, 30, 30), yaw = 0, use = "shops" }
	local north = road("North", Vector3.new(-200, 0, -40), Vector3.new(200, 0, -40))
	local south = road("South", Vector3.new(-200, 0, 60), Vector3.new(200, 0, 60))
	local f = front(ShopDresser.facingYaw(block, { north, south }))
	assert(f.Z < -0.99, "should face the north road, got " .. tostring(f))
	-- a closer road to the east does not win for a long block: only the long sides count
	local east = road("East", Vector3.new(55, 0, -200), Vector3.new(55, 0, 200))
	f = front(ShopDresser.facingYaw(block, { south, east }))
	assert(f.Z > 0.99, "long block should face the south road, got " .. tostring(f))
	-- a near-square block may face any side
	local square = { centre = Vector3.new(0, 15, 0), size = Vector3.new(30, 30, 30), yaw = 0, use = "shops" }
	f = front(ShopDresser.facingYaw(square, { south, east }))
	assert(f.X > 0.99, "square block should face the east road, got " .. tostring(f))
	local west = road("West", Vector3.new(-30, 0, -200), Vector3.new(-30, 0, 200))
	f = front(ShopDresser.facingYaw(square, { west, south }))
	assert(f.X < -0.99, "square block should face the west road, got " .. tostring(f))
end

function T.placementRunsAlongTheBlocksLongSide()
	local block = { centre = Vector3.new(10, 15, 20), size = Vector3.new(100, 30, 30), yaw = 0, use = "shops" }
	local south = road("South", Vector3.new(-200, 0, 60), Vector3.new(200, 0, 60))
	local cf, length, depth = ShopDresser.placement(block, { south })
	assert(near(length, 100) and near(depth, 30), ("length %s depth %s"):format(tostring(length), tostring(depth)))
	assert((cf.Position - Vector3.new(10, 0, 20)).Magnitude < 1e-4, "position " .. tostring(cf.Position))
	local tall = { centre = Vector3.new(0, 15, 0), size = Vector3.new(24, 24, 40), yaw = 0, use = "corner shop" }
	local east = road("East", Vector3.new(40, 0, -200), Vector3.new(40, 0, 200))
	local cf2, l2, d2 = ShopDresser.placement(tall, { east })
	assert(near(l2, 40) and near(d2, 24), "long-Z block keeps its length")
	assert(cf2:VectorToWorldSpace(Vector3.new(-1, 0, 0)).X > 0.99, "and faces the east road")
end

function T.dresserHandlesOnlyShopFlatsAndCivicUses()
	for _, use in { "shops", "shops with flats", "pub", "pub and cafes", "corner shop", "supermarket", "park cafe", "flats", "waterfront flats", "town hall", "school" } do
		assert(ShopDresser.handles(use), use .. " should be handled")
	end
	for _, use in { "terraced row", "church", "warehouse", "park lawn" } do
		assert(not ShopDresser.handles(use), use .. " should not be handled")
	end
end

-- X106: rows with two or more upper storeys get a slate roof above the cornice;
-- lower rows keep the roof they had (a wedge roof, or flat for a single storey).
function T.tallRowsGetARoofAboveTheCornice()
	assert(ShopBuilder.roofAboveCornice(0) == 0 and ShopBuilder.roofAboveCornice(1) == 0, "low rows unchanged")
	assert(ShopBuilder.roofAboveCornice(2) > 0 and ShopBuilder.roofAboveCornice(3) > 0, "tall rows get a roof")
	local holder = Instance.new("Folder")
	local row = ShopBuilder.shopRow(CFrame.new(), 60, 24, 36, holder, Random.new(3), "shops with flats")
	local front, back, coping = row:FindFirstChild("RoofFront") :: BasePart?, row:FindFirstChild("RoofBack") :: BasePart?, row:FindFirstChild("Coping") :: BasePart?
	assert(front and back and coping, "roof wedges and cornice")
	local copingTop = coping.Position.Y + coping.Size.Y / 2
	local wedgeBottom = front.Position.Y - front.Size.Y / 2
	assert(math.abs(wedgeBottom - copingTop) < 1e-3, ("roof sits on the cornice: %.3f vs %.3f"):format(wedgeBottom, copingTop))
	local stack = row:FindFirstChild("Stack") :: BasePart?
	assert(stack and stack.Position.Y + stack.Size.Y / 2 > front.Position.Y + front.Size.Y / 2, "chimney rises through the ridge")
	holder:Destroy()
end

return T
