--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local EstateBuilder = require(ServerScriptService.Server.EstateBuilder)
local EstateDresser = require(ServerScriptService.Server.EstateDresser)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

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

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end

function T.splitAroundGapsCutsEachGapAndDropsStubs()
	-- two gaps inside the run: three pieces
	local s = EstateBuilder.splitAroundGaps(-24, 24, { -20, 4 }, 4, 1)
	assert(#s == 3, "pieces " .. #s)
	assert(near(s[1].z0, -24) and near(s[1].z1, -22), "first " .. s[1].z0 .. ".." .. s[1].z1)
	assert(near(s[2].z0, -18) and near(s[2].z1, 2), "middle " .. s[2].z0 .. ".." .. s[2].z1)
	assert(near(s[3].z0, 6) and near(s[3].z1, 24), "last " .. s[3].z0 .. ".." .. s[3].z1)
	-- unsorted centres give the same result
	local u = EstateBuilder.splitAroundGaps(-24, 24, { 4, -20 }, 4, 1)
	assert(#u == 3 and near(u[2].z0, -18), "unsorted")
	-- a stub shorter than minLength at the end is dropped (-23..-22.7 is 0.3 long)
	local d = EstateBuilder.splitAroundGaps(-23, 23, { -20.5 }, 4.4, 1)
	assert(#d == 1 and near(d[1].z0, -18.3) and near(d[1].z1, 23), "stub not dropped")
	-- overlapping gaps merge; a gap running off the end clips
	local o = EstateBuilder.splitAroundGaps(0, 20, { 5, 7, 19 }, 4, 0.5)
	assert(#o == 2, "overlap pieces " .. #o)
	assert(near(o[1].z0, 0) and near(o[1].z1, 3), "before merged gap")
	assert(near(o[2].z0, 9) and near(o[2].z1, 17), "between merged gap and end gap")
	-- no gaps: the whole run
	local w = EstateBuilder.splitAroundGaps(-5, 5, {}, 4, 1)
	assert(#w == 1 and near(w[1].z0, -5) and near(w[1].z1, 5), "no gaps")
end

function T.doorZMatchesTheFrontTextureAndMirrors()
	local a0 = EstateBuilder.doorZ(48, "semi_front_a", 0)
	local a1 = EstateBuilder.doorZ(48, "semi_front_a", 1)
	assert(near(a0, -24 + 24 * 83 / 512), "a house 0 " .. a0)
	assert(near(a1 - a0, 24), "doors one house apart")
	local b0 = EstateBuilder.doorZ(48, "semi_front_b", 0)
	assert(near(b0, -24 + 24 * (1 - 83 / 512)), "b house 0 " .. b0)
	assert(near(EstateBuilder.doorZ(48, nil, 0), -12), "unknown front is mid-house")
end

-- Builds real pairs (unparented) and checks the budget, the gate gaps and the roof.
function T.semiPairHasGateGapsAGableRoofAndStaysInBudget()
	for seed = 1, 6 do
		local holder = Instance.new("Folder")
		local width, depth, height = 48 + seed * 3, 22, 20
		local model = EstateBuilder.semiPair(CFrame.new(), width, depth, height, holder, Random.new(seed))
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		assert(parts <= 16, ("seed %d: %d parts"):format(seed, parts))
		assert(model:FindFirstChild("RoofLeftEnd") == nil and model:FindFirstChild("RoofRightEnd") == nil, "hip end wedges are gone")

		local front = model:GetAttribute("Front")
		assert(type(front) == "string", "Front attribute")
		for house = 0, 1 do
			local doorZ = EstateBuilder.doorZ(width, front, house)
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and (p.Name == "GardenWall" or p.Name == "Hedge") then
					local z0, z1 = p.Position.Z - p.Size.Z / 2, p.Position.Z + p.Size.Z / 2
					-- a 3-wide front path must pass clear
					assert(z1 <= doorZ - 1.5 or z0 >= doorZ + 1.5, ("seed %d: %s %.2f..%.2f blocks door at %.2f"):format(seed, p.Name, z0, z1, doorZ))
				end
			end
		end

		-- each roof slab lies GAP above its attic slope and faces outward
		local wallH = math.max(6, math.floor(height * 0.62 + 0.5))
		local roofH = height - wallH
		local theta = math.atan2(roofH, depth / 2)
		for _, spec in { { name = "RoofFront", s = -1 }, { name = "RoofBack", s = 1 } } do
			local slab = model:FindFirstChild(spec.name) :: BasePart?
			assert(slab, spec.name)
			local n = Vector3.new(spec.s * math.sin(theta), math.cos(theta), 0)
			assert((slab.CFrame.UpVector - n).Magnitude < 1e-3, ("%s up %s, want %s"):format(spec.name, tostring(slab.CFrame.UpVector), tostring(n)))
			local underside = slab.CFrame:PointToWorldSpace(Vector3.new(0, -slab.Size.Y / 2, 0))
			local lift = (underside - Vector3.new(0, wallH + roofH, 0)):Dot(n)
			assert(math.abs(lift - 0.05) < 1e-3, ("%s lift %.4f"):format(spec.name, lift))
			-- the eave end hangs past the wall
			local eave = slab.CFrame:PointToWorldSpace(Vector3.new(spec.s * slab.Size.X / 2, 0, 0))
			local lowEnd = if math.abs(eave.X) > depth / 2 then eave else slab.CFrame:PointToWorldSpace(Vector3.new(-spec.s * slab.Size.X / 2, 0, 0))
			assert(math.abs(lowEnd.X) > depth / 2, spec.name .. " stops short of the wall")
		end
		holder:Destroy()
	end
end

-- X30: the front garden fits inside the block, the house shrinks (not below the minimum) first
function T.fitPairPushesTheHouseBackSoTheGardenStaysInsideTheBlock()
	local reach = EstateBuilder.GARDEN_REACH
	assert(near(reach, 6.5), "garden reach " .. reach)
	local d24, x24 = EstateBuilder.fitPair(24, reach, 14)
	assert(near(d24, 17) and near(x24, 3.5), ("24 deep -> %.2f at %.2f"):format(d24, x24))
	local d22, x22 = EstateBuilder.fitPair(22, reach, 14)
	assert(near(d22, 15) and near(x22, 3.5), ("22 deep -> %.2f at %.2f"):format(d22, x22))
	-- too shallow: the house stops at the minimum and the garden still stays inside the road edge
	local d18, x18 = EstateBuilder.fitPair(18, reach, 14)
	assert(near(d18, 14) and near(x18, 5), ("18 deep -> %.2f at %.2f"):format(d18, x18))
	-- a deep block caps the house at maxDepth (default MAX_HOUSE_DEPTH) behind the garden
	local d50, x50 = EstateBuilder.fitPair(50, reach, 14, 20)
	assert(near(d50, 20) and near(x50, -25 + 0.5 + reach + 10), ("50 deep -> %.2f at %.2f"):format(d50, x50))
	local dDefault = EstateBuilder.fitPair(120, reach, 14)
	assert(near(dDefault, EstateBuilder.MAX_HOUSE_DEPTH), "default max " .. dDefault)
	for blockDepth = 10, 40 do
		local houseDepth, houseX = EstateBuilder.fitPair(blockDepth, reach, 14, 100)
		assert(houseDepth >= 14 - 1e-6, "below the minimum at " .. blockDepth)
		local gardenOuter = houseX - houseDepth / 2 - reach
		assert(near(gardenOuter, -blockDepth / 2 + EstateBuilder.PLOT_MARGIN), ("depth %d: garden reaches %.2f"):format(blockDepth, gardenOuter))
		if blockDepth - reach - EstateBuilder.PLOT_MARGIN >= 14 then
			assert(near(houseX + houseDepth / 2, blockDepth / 2), ("depth %d: house back %.2f"):format(blockDepth, houseX + houseDepth / 2))
		end
	end
end

function T.rowLayoutCentresNarrowedPairsWithDrivewaysBetween()
	local slots, drives = EstateBuilder.rowLayout(100, 10)
	assert(#slots == 2 and #drives == 3, ("100: %d slots, %d drives"):format(#slots, #drives))
	assert(near(slots[1].z, -25) and near(slots[2].z, 25), "slot centres")
	assert(near(slots[1].width, 40) and near(slots[2].width, 40), "pair width " .. slots[1].width)
	assert(near(drives[1].z0, -49.95) and near(drives[1].z1, -44.9), ("end drive %.2f..%.2f"):format(drives[1].z0, drives[1].z1))
	assert(near(drives[2].z0, -5.1) and near(drives[2].z1, 5.1), ("middle drive %.2f..%.2f"):format(drives[2].z0, drives[2].z1))
	assert(near(drives[3].z0, 44.9) and near(drives[3].z1, 49.95), ("end drive %.2f..%.2f"):format(drives[3].z0, drives[3].z1))
	-- a single-pair block: half a gap each side
	local one, oneDrives = EstateBuilder.rowLayout(40, 10)
	assert(#one == 1 and near(one[1].z, 0) and near(one[1].width, 30) and #oneDrives == 2, "40 wide")
	-- the gap is capped at a quarter of the slot
	local short = EstateBuilder.rowLayout(20, 10)
	assert(near(short[1].width, 15), "20 wide pair " .. short[1].width)
	-- every width: pairs stay inside the block, neighbours sit >= 8 apart, and
	-- no driveway covers more than DRIVE_UNDER (0.1) of a pair
	for width = 40, 160, 7 do
		local s, d = EstateBuilder.rowLayout(width, EstateBuilder.SIDE_GAP)
		for i, slot in s do
			assert(slot.z - slot.width / 2 >= -width / 2 - 1e-6 and slot.z + slot.width / 2 <= width / 2 + 1e-6, "pair off the block at " .. width)
			if i > 1 then
				local prev = s[i - 1]
				local gap = (slot.z - slot.width / 2) - (prev.z + prev.width / 2)
				assert(gap >= 8 - 1e-6, ("width %d: pairs %.2f apart"):format(width, gap))
			end
			for _, drive in d do
				local overlap = math.min(drive.z1, slot.z + slot.width / 2) - math.max(drive.z0, slot.z - slot.width / 2)
				assert(overlap <= 0.1 + 1e-6, ("width %d: drive %.2f..%.2f covers the pair by %.2f"):format(width, drive.z0, drive.z1, overlap))
			end
		end
		for _, drive in d do
			assert(drive.z0 >= -width / 2 + 0.05 - 1e-6 and drive.z1 <= width / 2 - 0.05 + 1e-6, "drive off the block at " .. width)
		end
	end
end

function T.drivewayIsAtMostThreePartsOnItsOwnHeight()
	local cars = 0
	for seed = 1, 12 do
		local holder = Instance.new("Folder")
		local model = EstateBuilder.driveway(CFrame.new(), 5.05, 23.9, holder, true, Random.new(seed))
		local parts = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		assert(parts <= 3, ("seed %d: %d parts"):format(seed, parts))
		local drive = model:FindFirstChild("Drive") :: BasePart?
		assert(drive, "Drive slab")
		local top = drive.Position.Y + drive.Size.Y / 2
		for _, other in { 0.30, 0.40, 0.45 } do
			assert(math.abs(top - other) >= 0.05 - 1e-6, ("drive top %.3f too close to %.2f"):format(top, other))
		end
		local body = model:FindFirstChild("CarBody") :: BasePart?
		if body then
			cars += 1
			assert(body.Position.Y - body.Size.Y / 2 < top - 0.05 + 1e-6, "car floats on / is coplanar with the slab")
			assert(body.Size.Z <= 5.05 - 0.2, "car wider than the drive")
			assert(body.Position.X - body.Size.X / 2 >= -23.9 / 2, "car past the road end")
		end
		holder:Destroy()
	end
	assert(cars == 12, "withCar on a 5-wide drive should always park one")
	local holder = Instance.new("Folder")
	local narrow = EstateBuilder.driveway(CFrame.new(), 4.5, 23.9, holder, true, Random.new(1))
	assert(narrow:FindFirstChild("CarBody") == nil, "no car on a 4.5-wide strip")
	holder:Destroy()
end

function T.semiPairGardenReachesNoFurtherThanGardenReach()
	for seed = 1, 4 do
		local holder = Instance.new("Folder")
		local depth = 15 + seed
		local model = EstateBuilder.semiPair(CFrame.new(), 30 + seed * 5, depth, 22, holder, Random.new(seed))
		local walls = 0
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "GardenWall" or p.Name == "Hedge") then
				walls += 1
				local outer = p.Position.X - p.Size.X / 2
				assert(outer >= -(depth / 2 + EstateBuilder.GARDEN_REACH) - 1e-3, ("seed %d: %s reaches %.2f"):format(seed, p.Name, outer))
				assert(p.Position.X + p.Size.X / 2 < -depth / 2, p.Name .. " runs into the house")
			end
		end
		assert(walls > 0, "no garden wall")
		holder:Destroy()
	end
end

-- Every semis block in the layout: garden wall >= PLOT_MARGIN inside the road edge, houses inside the block.
function T.layoutSemisPlotsStayInsideTheirBlocks()
	local checked = 0
	for _, district in TownLayout.DISTRICTS do
		for _, b in district.blocks do
			if b.use ~= "semis" then
				continue
			end
			local _, width, depth = EstateDresser.placement(b, TownLayout.ROADS)
			local houseDepth, houseX = EstateDresser.pairFit(depth)
			local label = ("%s block at %s"):format(district.name, tostring(b.centre))
			assert(houseDepth >= EstateBuilder.MIN_HOUSE_DEPTH - 1e-6, label .. ": house too shallow")
			assert(houseX - houseDepth / 2 - EstateBuilder.GARDEN_REACH >= -depth / 2 + 0.5 - 1e-6, label .. ": garden on the pavement")
			assert(houseX + houseDepth / 2 <= depth / 2 + 1e-6, label .. ": house past the back edge")
			assert(houseDepth <= EstateBuilder.MAX_HOUSE_DEPTH + 1e-6, label .. ": house too deep")
			local slots = EstateBuilder.rowLayout(width, EstateBuilder.SIDE_GAP)
			for _, slot in slots do
				-- 22-wide blocks facing the road on their short side get a 16.5-wide pair
				assert(slot.width >= 16, ("%s: pair only %.1f wide"):format(label, slot.width))
			end
			checked += 1
		end
	end
	assert(checked > 0, "no semis blocks found")
end

function T.driveCarFitShrinksTheKitCarOntoTheDrive()
	local kit = Vector3.new(9.8, 6, 19.4) -- long axis on Z
	local scale, yaw = EstateDresser.driveCarFit(kit, 10, 40)
	assert(scale and math.abs(scale - 8.8 / 9.8) < 1e-6, "width-limited scale, got " .. tostring(scale))
	assert(math.abs(yaw - math.rad(90)) < 1e-6, "long axis turned onto local X")
	local s2, yaw2 = EstateDresser.driveCarFit(Vector3.new(19.4, 6, 9.8), 30, 40)
	assert(s2 == 1 and yaw2 == 0, "never scaled up; already along X")
	assert(EstateDresser.driveCarFit(kit, 7, 40) == nil, "too narrow: block car")
	assert(EstateDresser.driveCarFit(kit, 10, 12) == nil, "too short: block car")
end

function T.narrowDrivesGetNoBlockCar()
	assert(EstateDresser.wantsBlockCar(true, nil, 5.1) == false, "5.1 wide: empty drive")
	assert(EstateDresser.wantsBlockCar(true, nil, 3) == false, "3 wide: empty drive")
	assert(EstateDresser.wantsBlockCar(true, nil, 8) == true, "8 wide, kit car too big: block car")
	assert(EstateDresser.wantsBlockCar(true, 0.9, 10) == false, "kit car fitted: no block car")
	assert(EstateDresser.wantsBlockCar(false, nil, 10) == false, "not picked for a car")
end

function T.totemSpotIsOnTheVergeNotTheRoadOrABlock()
	local roads: { TownLayout.Road } = {
		{ name = "Test Road", kind = "main", width = 20, points = { Vector3.new(-200, 0, 0), Vector3.new(200, 0, 0) } },
	}
	local blocks: { TownLayout.Box } = {
		{ centre = Vector3.new(0, 0, 40), size = Vector3.new(60, 10, 30), yaw = 0, use = "warehouse" },
	}
	local stop = Vector3.new(0, 0, 20)
	local spot, facing = EstateDresser.totemSpot(stop, roads, blocks)
	assert(spot and facing, "found a spot")
	local d = math.abs(spot.Z)
	local reach = 10 + TownLayout.PAVEMENT_WIDTH
	assert(d >= reach + 1.5 and d <= reach + 6 + 1e-6, "on the verge beside the pavement, got " .. d)
	assert((Vector3.new(spot.X, 0, spot.Z) - stop).Magnitude >= 10, "clear of the bus stop")
	assert(not (math.abs(spot.X) <= 33 and spot.Z >= 22 and spot.Z <= 58), "not inside the block")
	assert(math.abs(facing.Z) < 1e-3 and math.abs(facing.X - spot.X) < 1e-3, "faces the closest road point") -- Vector3 is float32
	assert(EstateDresser.totemSpot(Vector3.new(0, 0, 5000), roads, blocks) == nil, "no road nearby -> nil")
end

function T.realEstateTotemSpotExists()
	local blocks = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(blocks, block)
		end
	end
	for _, stop in TownLayout.BUS_STOPS do
		if stop.name == "Industrial Estate" then
			assert(EstateDresser.totemSpot(stop.position, TownLayout.ROADS, blocks) ~= nil, "the estate stop has a clear verge")
		end
	end
end

function T.districtSignsHaveAGatewayAndAVerge()
	local blocks = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(blocks, block)
		end
	end
	for _, name in { "Northfields", "Westdale", "Riverside" } do
		local found = false
		for _, district in TownLayout.DISTRICTS do
			if district.name == name then
				found = true
				local gateway = EstateDresser.gatewayBlock(district, TownLayout.SQUARE.centre)
				assert(gateway, name .. " has blocks")
				assert(EstateDresser.totemSpot(gateway.centre, TownLayout.ROADS, blocks, 120) ~= nil, name .. " has a clear verge near its gateway block")
			end
		end
		assert(found, name .. " district exists")
	end
end

function T.playAreaSpotIsClearGrassByARoadWithTheGateTowardIt()
	local roads: { TownLayout.Road } = {
		{ name = "Test Road", kind = "residential", width = 20, points = { Vector3.new(-300, 0, 0), Vector3.new(300, 0, 0) } },
	}
	local blocks: { TownLayout.Box } = {
		{ centre = Vector3.new(0, 0, 60), size = Vector3.new(100, 10, 30), yaw = 0, use = "semis" },
	}
	local centre, facing = EstateDresser.playAreaSpot(Vector3.new(0, 0, 60), roads, blocks, 28, 160)
	assert(centre and facing, "found a spot")
	local reach = 10 + TownLayout.PAVEMENT_WIDTH
	local nearEdge = math.abs(centre.Z) - 14
	assert(nearEdge >= reach + 2 - 1e-3 and nearEdge <= reach + 8 + 1e-3, "near edge beside the pavement, got " .. nearEdge)
	-- the block spans x -50..50, z 45..75; keep 3 clear of it
	local clear = math.abs(centre.X) - 14 >= 53 - 1e-3 or centre.Z + 14 <= 42 + 1e-3 or centre.Z - 14 >= 78 - 1e-3
	assert(clear, "clear of the block, got " .. tostring(centre))
	assert(math.abs(facing.X) < 1e-6 and math.abs(math.abs(facing.Z) - 1) < 1e-6, "gate on a Z side")
	assert(math.sign(facing.Z) == -math.sign(centre.Z), "gate faces the road")
	local moved = EstateDresser.playAreaSpot(Vector3.new(0, 0, 60), roads, blocks, 28, 160, { centre })
	assert(moved and (moved - centre).Magnitude >= 28 - 1e-3, "keeps clear of an avoid point")
	assert(EstateDresser.playAreaSpot(Vector3.new(0, 0, 5000), roads, blocks, 28, 40) == nil, "no road nearby -> nil")
end

function T.northfieldsHasRoomForAPlayArea()
	local blocks = {}
	local gateway
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(blocks, block)
		end
		if district.name == "Northfields" then
			gateway = EstateDresser.gatewayBlock(district, TownLayout.SQUARE.centre)
		end
	end
	assert(gateway, "Northfields has blocks")
	assert(EstateDresser.playAreaSpot(gateway.centre, TownLayout.ROADS, blocks, 28, 200) ~= nil, "a play area fits near the Northfields gateway")
end

function T.flowerBedsSitOffTheFrontWallInsideTheGardenClearOfDoorPaths()
	for seed = 1, 6 do
		local holder = Instance.new("Folder")
		local width, depth = 48 + seed * 3, 22
		local pair = EstateBuilder.semiPair(CFrame.new(), width, depth, 20, holder, Random.new(seed))
		local front = pair:GetAttribute("Front") :: string
		local beds = EstateBuilder.flowerBeds(CFrame.new(), width, depth, front, pair, Random.new(seed))
		assert(#beds == 2, ("seed %d: %d beds"):format(seed, #beds))
		local hedgeBack = -(depth / 2 + EstateBuilder.GARDEN_OUT) + 1 + 0.7
		for house, bed in beds do
			assert(bed:GetAttribute("Decor") == true, "tagged Decor for Quality Low")
			local xMax, xMin = bed.Position.X + bed.Size.X / 2, bed.Position.X - bed.Size.X / 2
			assert(xMax < -depth / 2 - 1e-3, "off the front wall, got " .. xMax)
			assert(xMin > hedgeBack, "in front of the hedge")
			local zMin, zMax = bed.Position.Z - bed.Size.Z / 2, bed.Position.Z + bed.Size.Z / 2
			local lo, hi = -width / 2 + (house - 1) * width / 2, (house - 1) * width / 2
			assert(zMin >= lo - 1e-3 and zMax <= hi + 1e-3, "inside its own house front")
			local door = EstateBuilder.doorZ(width, front, house - 1)
			assert(zMax <= door - EstateBuilder.GATE_WIDTH / 2 + 1e-3 or zMin >= door + EstateBuilder.GATE_WIDTH / 2 - 1e-3, "clear of the door path")
			assert(bed.Position.Y - bed.Size.Y / 2 >= -1e-3, "sits on the ground")
		end
		holder:Destroy()
	end
end

function T.shedYardsGetAForkliftClearOfPalletsAndSandUnlessALorryIsThere()
	local function aabb(p: BasePart): (Vector3, Vector3)
		local half = p.CFrame:VectorToWorldSpace(p.Size / 2)
		local ext = Vector3.new(math.abs(half.X), math.abs(half.Y), math.abs(half.Z))
		-- a rotated box: use its largest horizontal half-extent both ways
		local r = math.max(p.Size.X, p.Size.Z) / 2
		ext = Vector3.new(math.max(ext.X, r), ext.Y, math.max(ext.Z, r))
		return p.Position - ext, p.Position + ext
	end
	for seed = 1, 6 do
		for _, kind in { "workshop", "builders yard", "trade counter" } do
			local holder = Instance.new("Folder")
			local shed = EstateBuilder.shed(CFrame.new(), Vector3.new(24 + seed * 2, 16, 30), holder, Random.new(seed), kind, seed)
			local forklift, others, parts = {}, {}, 0
			for _, d in shed:GetChildren() do
				if d:IsA("BasePart") then
					parts += 1
					if string.sub(d.Name, 1, 8) == "Forklift" then
						table.insert(forklift, d)
					elseif string.sub(d.Name, 1, 6) == "Pallet" or d.Name == "SandHeap" then
						table.insert(others, d)
					end
				end
			end
			local want = if seed % 3 == 1 then 8 else 0 -- every third unit
			assert(#forklift == want, ("%s seed %d: %d forklift parts"):format(kind, seed, #forklift))
			assert(parts <= 30, ("%s seed %d: %d parts"):format(kind, seed, parts))
			for _, f in forklift do
				local fMin, fMax = aabb(f)
				for _, o in others do
					local oMin, oMax = aabb(o)
					local apart = fMax.X <= oMin.X or oMax.X <= fMin.X or fMax.Z <= oMin.Z or oMax.Z <= fMin.Z
					assert(apart, ("%s seed %d: %s overlaps %s"):format(kind, seed, f.Name, o.Name))
				end
			end
			holder:Destroy()
		end
	end
	local holder = Instance.new("Folder")
	local warehouse = EstateBuilder.shed(CFrame.new(), Vector3.new(44, 20, 30), holder, Random.new(1), "warehouse", 1)
	assert(warehouse:FindFirstChild("Trailer") and not warehouse:FindFirstChild("ForkliftBody"), "a lorry yard has no forklift")
	holder:Destroy()
end

function T.shedFitKeepsTheYardInsideTheBlock()
	for _, blockDepth in { 50, 90, 100, 140 } do
		local bodyDepth, bodyX = EstateBuilder.shedFit(blockDepth)
		local yardFront = bodyX - bodyDepth / 2 - EstateBuilder.YARD_DEPTH
		assert(near(yardFront, -blockDepth / 2 + EstateBuilder.PLOT_MARGIN), ("depth %d: yard front %.2f"):format(blockDepth, yardFront))
		assert(near(bodyX + bodyDepth / 2, blockDepth / 2), ("depth %d: back on the block edge"):format(blockDepth))
	end
	local bodyDepth = EstateBuilder.shedFit(20)
	assert(bodyDepth == 10, "a tiny block still gets a 10-deep body")
end

function T.ballPartsInShedsAreRound()
	-- X70: a Ball renders at its smallest axis, so a non-uniform size is a bug
	local holder = Instance.new("Folder")
	for unit = 1, 3 do
		local shed = EstateBuilder.shed(CFrame.new(), Vector3.new(30, 16, 30), holder, Random.new(unit), "builders yard", unit)
		for _, d in shed:GetDescendants() do
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				assert(math.abs(d.Size.X - d.Size.Y) < 1e-3 and math.abs(d.Size.Y - d.Size.Z) < 1e-3, d.Name .. " is not round: " .. tostring(d.Size))
			end
		end
	end
	holder:Destroy()
end

function T.kerbTreeSpotSitsOnTheKerbSideOfTheFrontRoad()
	-- synthetic streets well away from the town's bus stops and roundabouts
	local o = Vector3.new(5000, 0, 5000)
	local street: TownLayout.Road = { name = "Test Street", kind = "residential", width = 20, points = { o + Vector3.new(-200, 0, 0), o + Vector3.new(200, 0, 0) } }
	local spot = EstateDresser.kerbTreeSpot(o + Vector3.new(0, 0, 30), { street }, {})
	assert(spot, "a spot in front of the pair")
	assert(math.abs(spot.X - o.X) < 1e-3 and math.abs(spot.Z - (o.Z + 10 + 2.2)) < 1e-3, "TREE_INSET in from the kerb on the pair's side, got " .. tostring(spot))
	assert(EstateDresser.kerbTreeSpot(o + Vector3.new(0, 0, 30), { street }, { o + Vector3.new(3, 0, 12) }) == nil, "keeps clear of a lamp")
	local crossing: TownLayout.Road = { name = "Cross Street", kind = "residential", width = 20, points = { o + Vector3.new(25, 0, -200), o + Vector3.new(25, 0, 5) } } -- ends 35 from the pair, 26 from the spot
	assert(EstateDresser.kerbTreeSpot(o + Vector3.new(0, 0, 30), { street, crossing }, {}) == nil, "not in a junction mouth")
	local lane: TownLayout.Road = { name = "Test Lane", kind = "lane", width = 12, points = street.points }
	assert(EstateDresser.kerbTreeSpot(o + Vector3.new(0, 0, 30), { lane }, {}) == nil, "no trees on lanes")
end

function T.nameWallSpotStandsBesideTheStoneOnTheVerge()
	local o = Vector3.new(5000, 0, 5000)
	local street: TownLayout.Road = { name = "Hayfield Close", kind = "residential", width = 20, points = { o + Vector3.new(-200, 0, 0), o + Vector3.new(200, 0, 0) } }
	local stone = o + Vector3.new(0, 0, 21.5)
	local facing = o
	local at, name = EstateDresser.nameWallSpot(stone, facing, { street }, {})
	assert(at and name == "Hayfield Close", "found a spot and the road name")
	assert(math.abs((at - stone).Magnitude - 11) < 1e-3, "11 along the verge from the stone")
	assert(math.abs(at.Z - stone.Z) < 1e-3, "same distance from the road as the stone")
	-- a block on the right-hand side pushes it to the left
	local rightHand = at
	local block: TownLayout.Box = { centre = rightHand + Vector3.new(0, 0, 2), size = Vector3.new(6, 10, 6), yaw = 0, use = "semis" }
	local other = EstateDresser.nameWallSpot(stone, facing, { street }, { block })
	assert(other and (other - rightHand).Magnitude > 20, "moves to the other side of the stone")
end

-- X55: palisade sections are at most PALISADE_SECTION long, and a shed yard
-- gets palisade (or the fallback panels) on both sides and the front.
function T.palisadeSectionsCoverTheFence()
	local L = EstateBuilder.PALISADE_SECTION
	for _, length in { 0.5, L - 0.5, L, L + 0.1, 19.5, 43.5 } do
		local n = EstateBuilder.palisadeSections(length)
		assert(n >= 1 and length / n <= L + 1e-6, ("length %g: %d sections"):format(length, n))
		assert(n == 1 or length / (n - 1) > L, ("length %g: %d sections is more than needed"):format(length, n))
	end
	local holder = Instance.new("Folder")
	local shed = EstateBuilder.shed(CFrame.new(), Vector3.new(30, 16, 40), holder, Random.new(2), "workshop", 2)
	local palisade, panels = 0, 0
	for _, d in shed:GetChildren() do
		if d.Name == "Palisade" then
			palisade += 1
			assert(math.abs(d.Size.Y - EstateBuilder.PALISADE_H) < 0.2, "palisade height " .. d.Size.Y)
		elseif string.sub(d.Name, 1, 5) == "Fence" then
			panels += 1
		end
	end
	local want = 2 * EstateBuilder.palisadeSections(EstateBuilder.YARD_DEPTH - 0.5) + EstateBuilder.palisadeSections(30 - 0.5) -- size.X is the frontage
	assert(palisade == want or (palisade == 0 and panels == 3), ("palisade %d (want %d), panels %d"):format(palisade, want, panels))
	holder:Destroy()
end

return T
