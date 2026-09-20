--!strict
-- Rivermere v3, Lane H: builds a sample of the real TownFrontage lots (the Station terraces, the
-- Smithy Close semis, the Pinfold/Drift Close detached houses, the 45-degree Quarry Road rows)
-- into a throwaway model and checks the definition of done: one building per lot, no KitMissing,
-- no primitives, inside the section 9 allowances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local HouseAssembler = require(ServerScriptService.Server.HouseAssembler)
local HouseRecipes = require(ReplicatedStorage.Shared.HouseRecipes)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)

local SAMPLE_STREETS = { ["Smithy Close"] = true, ["Pinfold Close"] = true, ["Drift Close"] = true, ["Quarry Road"] = true }

local tests = {}

local sampleCache: { any }? = nil
local function fixtureLots(): { any }
	if sampleCache then
		return sampleCache
	end
	local lots = {}
	for _, lot in TownFrontage.generate() do
		if TownFrontage.HOMES[lot.use] and (lot.district == "Station" or SAMPLE_STREETS[lot.street]) then
			table.insert(lots, lot)
		end
	end
	sampleCache = lots
	return lots
end

local function kitInstalled(): boolean
	local kit = ServerStorage:FindFirstChild("Kit")
	local meshes = kit and kit:FindFirstChild("Meshes")
	return meshes ~= nil and meshes:FindFirstChild("MEH__Wall_A__ts1") ~= nil
end

local function withBuild(filter, detail, check)
	local holder = Instance.new("Model")
	holder.Name = "HouseAssemblerTest"
	local ok, err = pcall(function()
		local counts = HouseAssembler.buildLots(holder, CFrame.new(0, 0, 0), fixtureLots(), filter, detail)
		check(holder, counts)
	end)
	holder:Destroy()
	assert(ok, err)
end

-- RunAll ignores return values, so this doubles as the sample accessor for sandbox builds.
function tests.sample_covers_every_case()
	local lots = fixtureLots()
	assert(#lots >= 40, "sample is too small: " .. #lots)
	local uses, diagonal, closes, corner = {}, false, false, false
	for _, lot in lots do
		uses[lot.use] = true
		diagonal = diagonal or (lot.yaw % 90 ~= 0)
		closes = closes or lot.closesStreet
		corner = corner or lot.corner
		assert(math.abs(lot.front.Magnitude - 1) < 0.01, lot.id .. " front is not a unit vector")
	end
	assert(uses["terraced row"] and uses["semis"] and uses["detached house"], "sample must cover all three uses")
	assert(diagonal and closes and corner, "sample must include a 45-degree lot, a closesStreet row and a corner lot")
	return lots
end

function tests.lot_frame_faces_the_street_with_x_along_it()
	for _, lot in TownFrontage.generate() do
		if TownFrontage.HOMES[lot.use] then
			local frame = HouseAssembler.lotFrame(lot)
			assert(frame.LookVector:Dot(lot.front) > 0.99, lot.id .. ": local -Z is not Lot.front")
			local contract = TownFrontage.lotCFrame(lot)
			assert(math.abs(frame.RightVector:Dot(contract.RightVector)) > 0.99, lot.id .. ": X axis left the street line")
		end
	end
end

function tests.every_home_lot_has_a_recipe_plan()
	local n = 0
	for _, lot in TownFrontage.generate() do
		if TownFrontage.HOMES[lot.use] then
			n += 1
			assert(HouseRecipes.USE_KIND[lot.use], "no recipe kind for " .. lot.use)
			assert(#HouseRecipes.planLot(lot.use, lot.id, lot.units) == lot.units)
		end
	end
	assert(n > 600, "expected the whole town's home lots, got " .. n)
end

function tests.one_building_per_lot_no_missing_no_primitives()
	if not kitInstalled() then
		return
	end
	withBuild(nil, nil, function(holder, counts)
		local lots = fixtureLots()
		assert(counts.lots == #lots, ("built %d of %d lots"):format(counts.lots, #lots))
		assert(counts.missing == 0, counts.missing .. " KitMissing fallbacks")
		local seen = {}
		local meshParts = 0
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("LotId") ~= nil then
				local id = d:GetAttribute("LotId")
				assert(not seen[id], "two buildings on lot " .. tostring(id))
				seen[id] = true
				assert(d:FindFirstChildWhichIsA("MeshPart", true), "lot " .. tostring(id) .. " is empty")
			end
			assert(d:GetAttribute("KitMissing") == nil, "KitMissing: " .. d.Name)
			if d:IsA("MeshPart") then
				meshParts += 1
			elseif d:IsA("BasePart") then
				assert(d:GetAttribute("V3Exempt") ~= nil, "untagged primitive " .. d:GetFullName())
			end
		end
		for _, lot in lots do
			assert(seen[lot.id], "no building on lot " .. lot.id)
		end
		assert(meshParts == counts.meshParts, ("count says %d, tree has %d"):format(counts.meshParts, meshParts))
	end)
end

function tests.houses_stay_inside_their_lot_and_face_the_street()
	if not kitInstalled() then
		return
	end
	withBuild(nil, HouseAssembler.PRESETS.lean, function(holder, _counts)
		local byId = {}
		for _, lot in fixtureLots() do
			byId[lot.id] = lot
		end
		for _, d in holder:GetDescendants() do
			local id = d:IsA("Model") and d:GetAttribute("LotId")
			if id then
				local lot = byId[id]
				local lotCF = HouseAssembler.lotFrame(lot)
				local doors = 0
				for _, part in d:GetDescendants() do
					if part:IsA("MeshPart") then
						local role = part:GetAttribute("Role")
						local p = lotCF:PointToObjectSpace(part.Position)
						if role == "door" then
							doors += 1
							assert(p.Z < -lot.size.Z / 2 + 1.5, id .. ": a door is not on the street side")
						end
						if role ~= "garden" and role ~= "yard" then
							assert(math.abs(p.X) <= lot.size.X / 2 + 1.5, id .. ": " .. part.Name .. " is outside the lot along the street")
							assert(p.Z >= -lot.size.Z / 2 - 2 and p.Z <= lot.size.Z / 2 + 0.5, id .. ": " .. part.Name .. " is outside the lot depth")
						end
					end
				end
				local prefabOnly = d:FindFirstChild("MEH__House_02_VAR1__ts1") or d:FindFirstChild("MEH__House_02_VAR1__ts3")
				assert(doors == lot.units or prefabOnly, ("%s: %d doors for %d units"):format(id, doors, lot.units))
			end
		end
	end)
end

function tests.district_filter_builds_only_that_district()
	if not kitInstalled() then
		return
	end
	withBuild({ district = "Mapleford" }, HouseAssembler.PRESETS.lean, function(holder, counts)
		assert(counts.districts == 1 and #holder:GetChildren() == 1, "filter let other districts through")
		assert(holder:GetChildren()[1].Name == "Housing_Mapleford")
		assert(counts.lots > 0)
	end)
end

function tests.build_is_deterministic()
	if not kitInstalled() then
		return
	end
	local function signature(): string
		local out = ""
		withBuild({ district = "Mapleford" }, nil, function(holder, counts)
			local names = {}
			for _, d in holder:GetDescendants() do
				if d:IsA("MeshPart") then
					table.insert(names, ("%s@%d,%d"):format(d.Name, math.floor(d.Position.X + 0.5), math.floor(d.Position.Z + 0.5)))
				end
			end
			table.sort(names)
			out = counts.meshParts .. ":" .. table.concat(names, ";")
		end)
		return out
	end
	assert(signature() == signature(), "two builds of the same lots differ")
end

-- Section 9 allowances (Lane P, 2026-09-20): terraced 10 house MeshParts a unit averaged over the
-- row; boundaries 11 a unit in Tier A and 4 in Tier B; the whole town 24,000 + 13,500.
local function townUnits(): { [string]: number }
	local units = {}
	for _, lot in TownFrontage.generate() do
		if TownFrontage.HOMES[lot.use] then
			units[lot.use] = (units[lot.use] or 0) + lot.units
		end
	end
	return units
end

local function buildUse(use: string, detail): { [string]: number }
	local lots = {}
	for _, lot in fixtureLots() do
		if lot.use == use then
			table.insert(lots, lot)
		end
	end
	local holder = Instance.new("Model")
	local counts = HouseAssembler.buildLots(holder, CFrame.new(0, 0, 0), lots, nil, detail)
	holder:Destroy()
	return counts
end

function tests.terraced_units_meet_the_per_unit_allowance()
	if not kitInstalled() then
		return
	end
	local counts = buildUse("terraced row", HouseAssembler.PRESETS.tierA)
	local perUnit = counts.houseParts / counts.units
	assert(perUnit <= 10, ("terraced house costs %.1f MeshParts a unit, allowance 10"):format(perUnit))
end

function tests.boundaries_meet_the_tier_allowances()
	if not kitInstalled() then
		return
	end
	for _, use in { "terraced row", "semis", "detached house" } do
		local a = buildUse(use, HouseAssembler.PRESETS.tierA)
		local b = buildUse(use, HouseAssembler.PRESETS.tierB)
		assert(a.boundaryParts / a.units <= 11, ("%s Tier A boundaries cost %.1f a unit, allowance 11"):format(use, a.boundaryParts / a.units))
		assert(b.boundaryParts / b.units <= 4, ("%s Tier B boundaries cost %.1f a unit, allowance 4"):format(use, b.boundaryParts / b.units))
	end
end

function tests.town_projection_is_inside_both_budgets()
	if not kitInstalled() then
		return
	end
	-- Projected at the Tier A rate for 17% of units and the Tier B rate for 83% (Lane P's split).
	local houses, boundaries = 0, 0
	for use, unitsInTown in townUnits() do
		local a = buildUse(use, HouseAssembler.PRESETS.tierA)
		local b = buildUse(use, HouseAssembler.PRESETS.tierB)
		houses += (0.17 * a.houseParts / a.units + 0.83 * b.houseParts / b.units) * unitsInTown
		boundaries += (0.17 * a.boundaryParts / a.units + 0.83 * b.boundaryParts / b.units) * unitsInTown
	end
	assert(houses <= HouseAssembler.PART_BUDGET, ("houses project to %d MeshParts, budget %d"):format(houses, HouseAssembler.PART_BUDGET))
	assert(boundaries <= HouseAssembler.BOUNDARY_BUDGET, ("boundaries project to %d MeshParts, budget %d"):format(boundaries, HouseAssembler.BOUNDARY_BUDGET))
end

function tests.presets_get_cheaper_in_order()
	if not kitInstalled() then
		return
	end
	local function parts(detail): number
		local n = 0
		withBuild({ district = "Station" }, detail, function(_holder, counts)
			n = counts.meshParts
		end)
		return n
	end
	local a, b, lean = parts(HouseAssembler.PRESETS.tierA), parts(HouseAssembler.PRESETS.tierB), parts(HouseAssembler.PRESETS.lean)
	assert(a > b and b > lean, ("presets out of order: %d %d %d"):format(a, b, lean))
end

function tests.tiers_follow_section_9()
	assert(HouseAssembler.tierFor(Vector3.new(0, 0, 0)) == "A", "Market Square is Tier A")
	assert(HouseAssembler.tierFor(Vector3.new(-900, 0, -350)) == "A", "station is Tier A")
	assert(HouseAssembler.tierFor(Vector3.new(1050, 0, 1250 - 400)) == "A", "400 studs from Plot 1 is Tier A")
	assert(HouseAssembler.tierFor(Vector3.new(-2291, 0, -691)) == "B" or HouseAssembler.tierFor(Vector3.new(600, 0, 600)) == "B", "open town is Tier B")
end

function tests.lots_are_atomic_and_districts_are_not()
	if not kitInstalled() then
		return
	end
	withBuild({ district = "Mapleford" }, nil, function(holder, _counts)
		local district = holder:GetChildren()[1] :: Model
		assert(district.ModelStreamingMode == Enum.ModelStreamingMode.Default, "district must not be Atomic (section 9 rule 1)")
		local boundaries = district:FindFirstChild("Boundaries") :: Model
		assert(boundaries and boundaries.ModelStreamingMode == Enum.ModelStreamingMode.Default)
		for _, child in district:GetChildren() do
			if child:GetAttribute("LotId") ~= nil then
				assert((child :: Model).ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "each lot is one Atomic model")
				for _, part in child:GetChildren() do
					local role = part:GetAttribute("Role")
					assert(role ~= "garden" and role ~= "yard", "boundaries belong in the Boundaries model")
				end
			end
		end
	end)
	local _ = HouseRecipes
end

return tests
