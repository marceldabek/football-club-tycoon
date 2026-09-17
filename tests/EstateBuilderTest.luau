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

return T
