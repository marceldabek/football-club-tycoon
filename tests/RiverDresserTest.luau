--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RiverDresser = require(ServerScriptService.Server.RiverDresser)
local KitPlacer = require(ServerScriptService.Server.KitPlacer)
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

function T.cafeSiteIsClearGrassBesideThePromenade()
	-- the site passes the promenade's own clearance rules (roads + pavement + 3,
	-- blocks + 3, 30 past a bridge deck); the Lune Bridge is 45 away
	assert(RiverDresser.isClear(RiverDresser.CAFE_SITE, 0), "café site clear of roads, blocks and bridges")
	-- and it faces the river: a step towards the facing gets nearer the river line
	local d0 = TownLayout.distanceToPolyline(RiverDresser.CAFE_SITE, TownLayout.RIVER.points)
	local d1 = TownLayout.distanceToPolyline(RiverDresser.CAFE_SITE + RiverDresser.CAFE_FACING * 5, TownLayout.RIVER.points)
	assert(d1 < d0, "faces the river")
	assert(d0 > TownLayout.RIVER.width / 2 + 12, "on land behind the quay and promenade")
end

function T.heritageLampIsLightWithABasketOverThePromenadeSide()
	for _, basket in { false, true } do
		local holder = Instance.new("Folder")
		local lamp = RiverDresser.heritageLamp(CFrame.new(10, 0.35, 20), holder, basket, Random.new(3))
		local parts, lowest = 0, math.huge
		for _, d in lamp:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				local ext = d.CFrame:VectorToWorldSpace(d.Size / 2)
				lowest = math.min(lowest, d.Position.Y - math.abs(ext.Y))
			end
		end
		assert(parts == 9, ("basket %s: %d parts (basket or banner)"):format(tostring(basket), parts))
		assert((lamp:FindFirstChild("Banner") ~= nil) == not basket, "a banner exactly when there is no basket")
		assert(lowest >= 0.35 - 1e-3, "nothing below the ground it stands on")
		local b = lamp:FindFirstChild("Basket") :: BasePart?
		assert((b ~= nil) == basket, "basket only when asked")
		if b then
			assert(b.Position.Z < 20 - 1.5, "hangs clear of the post towards local -Z")
			local glass = lamp:FindFirstChild("Glass") :: BasePart
			assert(b.Position.Y + b.Size.Y / 2 < glass.Position.Y - glass.Size.Y / 2, "below the lantern")
		end
		holder:Destroy()
	end
end

function T.aboutHalfTheBoatsHaveAMast()
	local masts, total = 0, 0
	for x = 0, 200, 9 do
		for z = 0, 90, 11 do
			total += 1
			if RiverDresser.hasMast(Vector3.new(x + 0.5, 0, z + 0.5)) then
				masts += 1
			end
		end
	end
	local share = masts / total
	assert(share > 0.35 and share < 0.65, "mast share " .. share)
	-- a stand-in kit, so the test needs no ServerStorage.Kit
	local kit = Instance.new("Folder")
	local boats = Instance.new("Folder")
	boats.Name = "Boats"
	boats.Parent = kit
	local names = table.clone(RiverDresser.MOTOR_BOATS)
	table.insert(names, RiverDresser.SAIL_BOAT)
	for _, name in names do
		if not boats:FindFirstChild(name) then
			local m = Instance.new("Model")
			m.Name = name
			local hull = Instance.new("MeshPart")
			hull.Name = "Hull"
			hull.Size = Vector3.new(6, 3, 20)
			hull.Parent = m
			m.WorldPivot = CFrame.new(0, -0.5, 0) -- the waterline
			m.Parent = boats
		end
	end
	KitPlacer.setLibraryRoot(kit)
	local folder = Instance.new("Folder")
	local rng = Random.new(3)
	local with, without = nil, nil
	for x = 0, 12 do
		local p = Vector3.new(x * 21, 0, 0)
		if RiverDresser.hasMast(p) and not with then
			with = RiverDresser.buildBoat(folder, CFrame.new(p), rng)
		elseif not RiverDresser.hasMast(p) and not without then
			without = RiverDresser.buildBoat(folder, CFrame.new(p), rng)
		end
	end
	KitPlacer.setLibraryRoot(nil)
	assert(with and with:GetAttribute("Kit") == RiverDresser.SAIL_BOAT, "sailing yacht on a mast berth")
	assert(without and table.find(RiverDresser.MOTOR_BOATS, without:GetAttribute("Kit")), "motor boat elsewhere")
	for _, boat in { with, without } do
		assert(boat.Name == "Boat", "named Boat so Quality can hide it")
		assert(boat:GetAttribute("KitMissing") == nil, "a real kit model, not the fallback")
		assert(math.abs(boat:GetPivot().Position.Y - -0.9) < 1e-3, "waterline pivot sits on the water")
		for _, d in boat:GetDescendants() do
			if d:IsA("BasePart") then
				assert(d:IsA("MeshPart"), "no primitive parts in a boat: " .. d.Name)
				assert(d.Anchored and not d.CanCollide, "anchored, no collision")
			end
		end
	end
	folder:Destroy()
	kit:Destroy()
end

function T.aMissingBoatIsFlaggedNotBuiltFromPrimitives()
	local empty = Instance.new("Folder")
	KitPlacer.setLibraryRoot(empty)
	local folder = Instance.new("Folder")
	local boat = RiverDresser.buildBoat(folder, CFrame.new(0, 0, 0), Random.new(1))
	KitPlacer.setLibraryRoot(nil)
	assert(boat:GetAttribute("KitMissing") ~= nil, "flagged KitMissing")
	assert(#boat:GetChildren() == 1, "one fallback block")
	folder:Destroy()
	empty:Destroy()
end

return T
