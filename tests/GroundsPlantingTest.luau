--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local GroundsPlanting = require(ServerScriptService.Server.GroundsPlanting)
local PlotGrounds = require(ServerScriptService.Server.PlotGrounds)
local TreeKit = require(ServerScriptService.Server.TreeKit)

local T = {}

local HALF = 380

local function inRect(p: Vector3, x0: number, x1: number, z0: number, z1: number): boolean
	return p.X >= x0 and p.X <= x1 and p.Z >= z0 and p.Z <= z1
end

function T.everyAreaMarcelNamedGetsGreenery()
	local plan = GroundsPlanting.plan(PlotGrounds.plantingKeepOut(), 1)
	local function trees(x0: number, x1: number, z0: number, z1: number): number
		local n = 0
		for _, t in plan.trees do
			if inRect(t.at, x0, x1, z0, z1) then
				n += 1
			end
		end
		return n
	end
	assert(trees(-380, -350, 40, 130) >= 2, "oaks by the entrance road")
	assert(trees(-240, -195, -80, 100) >= 4, "oaks on the clubhouse lawn")
	assert(trees(205, 380, -200, 200) >= 12, "oaks round the training pitches")
	assert(trees(-380, 380, 256, 380) + trees(-380, 380, -380, -256) >= 6, "groves in the open ends of the plot")
	assert(#plan.hedges >= 8 and #plan.bushes >= 40 and #plan.rocks >= 6,
		("hedges %d bushes %d rocks %d"):format(#plan.hedges, #plan.bushes, #plan.rocks))
	-- TEMP phone budget: keep a plot's extra oaks under 70
	assert(#plan.trees <= 70, "trees " .. #plan.trees)
end

function T.nothingStandsOnAPathABuildingOrTheStadium()
	local keepOut = PlotGrounds.plantingKeepOut()
	for seed = 1, 4 do
		local plan = GroundsPlanting.plan(keepOut, seed)
		local points: { { name: string, at: Vector3, reach: number } } = {}
		for _, t in plan.trees do
			table.insert(points, { name = "tree", at = t.at, reach = 2 })
		end
		for _, b in plan.bushes do
			table.insert(points, { name = "bush", at = b.at, reach = b.width / 2 - 0.6 })
		end
		for _, r in plan.rocks do
			table.insert(points, { name = "rock", at = r.at, reach = 1 })
		end
		for _, h in plan.hedges do
			-- a hedge is checked along its length, 1.6 to each side
			local len = (h.to - h.from).Magnitude
			for d = 0, len, 2 do
				table.insert(points, { name = "hedge", at = h.from:Lerp(h.to, d / len), reach = 1.6 })
			end
		end
		for _, p in points do
			assert(math.abs(p.at.X) < HALF - 2 and math.abs(p.at.Z) < HALF - 2, p.name .. " outside the wall")
			for _, r in keepOut do
				assert(GroundsPlanting.distance(p.at, r) >= p.reach,
					("seed %d: %s at (%g, %g) is on %s"):format(seed, p.name, p.at.X, p.at.Z, r.name))
			end
		end
	end
end

function T.foundationBushesFlankTheClubhouseDoors()
	local plan = GroundsPlanting.plan(PlotGrounds.plantingKeepOut(), 1)
	assert(#plan.foundation >= 4, "bushes against the club building")
	for _, b in plan.foundation do
		-- Clubhouse.luau: front wall x -157, z -40..40; doors' apron z -16..16
		assert(b.at.X + b.width / 2 <= -157 and b.at.X > -165, "against the front wall, not in it")
		assert(math.abs(b.at.Z) - b.width / 2 >= 16 and math.abs(b.at.Z) + b.width / 2 <= 40, "clear of the doors, within the wall: z " .. b.at.Z)
	end
end

function T.treesKeepApartAndThePlanIsRepeatable()
	local keepOut = PlotGrounds.plantingKeepOut()
	local a, b = GroundsPlanting.plan(keepOut, 3), GroundsPlanting.plan(keepOut, 3)
	assert(#a.trees == #b.trees and #a.bushes == #b.bushes, "same seed, same plan")
	for i, t in a.trees do
		assert(t.at == b.trees[i].at, "same seed, same spots")
		for j = i + 1, #a.trees do
			assert((t.at - a.trees[j].at).Magnitude >= 12, ("trees %d and %d crowd each other"):format(i, j))
		end
	end
	local other = GroundsPlanting.plan(keepOut, 4)
	local last = a.trees[#a.trees].at
	assert(other.trees[#other.trees].at ~= last, "another plot, other groves")
end

function T.buildFallsBackToPrimitivesWithoutTheKit()
	TreeKit.setLibraryRoot(Instance.new("Folder"))
	local parent = Instance.new("Folder")
	local ok, err = pcall(function()
		local m = GroundsPlanting.build(parent, PlotGrounds.plantingKeepOut(), 1)
		assert(m:FindFirstChild("Trunk") and m:FindFirstChild("Crown"), "primitive trees")
		assert(m:FindFirstChild("Hedge") and m:FindFirstChild("Bush") and m:FindFirstChild("Rock"), "primitive hedge, bush, rock")
		assert((m:GetAttribute("Trees") :: number) > 20, "counts published")
	end)
	TreeKit.setLibraryRoot(nil)
	parent:Destroy()
	assert(ok, err)
end

function T.hedgeRunFillsTheRunExactly()
	local pack = Instance.new("Folder")
	local hedge = Instance.new("Model")
	hedge.Name = TreeKit.HEDGE
	local leaves = Instance.new("MeshPart")
	leaves.Size = Vector3.new(4, 10, 18)
	leaves.Position = Vector3.new(500, 5, 500)
	leaves.Parent = hedge
	hedge.Parent = pack
	TreeKit.setLibraryRoot(pack)
	local parent = Instance.new("Folder")
	local ok, err = pcall(function()
		local from, to = Vector3.new(-100, 0, 20), Vector3.new(-100, 0, 71)
		local run = TreeKit.hedgeRun(parent, from, to, { height = 5, thickness = 3 }) :: Model
		assert(run, "placed")
		local cf, size = run:GetBoundingBox()
		assert(math.abs(size.Y - 5) < 0.05, "height " .. size.Y)
		local lo, hi = math.huge, -math.huge
		for _, d in run:GetChildren() do
			if d:IsA("MeshPart") then
				assert(math.abs(d.Position.X - -100) < 0.01, "on the line")
				assert(math.abs(d.Size.X - 3) < 0.01, "thickness " .. d.Size.X)
				lo = math.min(lo, d.Position.Z - d.Size.Z / 2)
				hi = math.max(hi, d.Position.Z + d.Size.Z / 2)
			end
		end
		assert(math.abs(lo - 20) < 0.01 and math.abs(hi - 71) < 0.01, ("runs %g..%g"):format(lo, hi))
		assert(run:FindFirstChild("HedgeCollider"), "solid")
		local _ = cf
	end)
	TreeKit.setLibraryRoot(nil)
	pack:Destroy()
	parent:Destroy()
	assert(ok, err)
end

return T
