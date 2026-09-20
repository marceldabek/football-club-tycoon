--!strict
-- Builds real kit clones into a scratch folder far from everything, checks them, destroys them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TradeRecipes = require(ReplicatedStorage.Shared.TradeRecipes)
local TradeAssembler = require(ServerScriptService.Server.TradeAssembler)
local V3Perf = require(ServerScriptService.Server.V3Perf)

local T = {}

local ORIGIN = CFrame.new(-6000, -2000, 0)

local function scratch(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TradeAssemblerTestScratch"
	folder.Parent = workspace
	return folder
end

local function firstOf(use: string): TradeRecipes.Lot
	for _, lot in TradeRecipes.lots(nil) do
		if lot.use == use then
			return lot
		end
	end
	error("no lot with use " .. use)
end

local SAMPLE_USES = { "shops with flats", "shops", "corner shop", "flats", "workshop", "warehouse", "pub", "town hall", "church" }

local function withSamples(check: (Folder, { Model }) -> ())
	local folder = scratch()
	local ok, err = pcall(function()
		local built = {}
		for _, use in SAMPLE_USES do
			table.insert(built, TradeAssembler.buildLot(folder, ORIGIN, firstOf(use)))
		end
		check(folder, built)
	end)
	folder:Destroy()
	assert(ok, err)
end

function T.noKitMissingInOutput()
	withSamples(function(folder)
		local counts = V3Perf.count(folder)
		assert(counts.kitMissing == 0, counts.kitMissing .. " KitMissing fallbacks")
		for _, d in folder:GetDescendants() do
			assert(d:GetAttribute("KitMissing") == nil, "KitMissing: " .. tostring(d:GetAttribute("KitMissing")))
		end
	end)
end

function T.everyPrimitiveIsExemptWithARegisterId()
	withSamples(function(folder)
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and not d:IsA("MeshPart") then
				local id = d:GetAttribute("V3Exempt")
				assert(type(id) == "string" and string.match(id, "^E"), "untagged primitive " .. d:GetFullName())
			end
		end
	end)
end

function T.modularPiecesAreTextured()
	withSamples(function(folder)
		for _, d in folder:GetDescendants() do
			if d:IsA("MeshPart") and string.sub((d.Parent :: Instance).Name, 1, 5) == "MEH__" then
				assert(d:FindFirstChildOfClass("SurfaceAppearance") or d.TextureID ~= "", d:GetFullName() .. " is untextured")
			end
		end
	end)
end

function T.builtLotStaysInsideItsLotBox()
	withSamples(function(_, built)
		for i, model in built do
			local lot = firstOf(SAMPLE_USES[i])
			local frame = TradeAssembler.lotFrame(ORIGIN, lot)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local p = frame:PointToObjectSpace(d.Position)
					assert(math.abs(p.X) <= lot.size.X / 2 + 1 and math.abs(p.Z) <= lot.size.Z / 2 + 1, ("%s: %s centre is outside the lot"):format(lot.id, d.Name))
				end
			end
		end
	end)
end

function T.lotsAreAtomicModelsNamedByLotId()
	withSamples(function(_, built)
		for i, model in built do
			assert(model.Name == firstOf(SAMPLE_USES[i]).id, "lot model is not named by Lot.id")
			assert(model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "lot model must stream atomically")
		end
	end)
end

function T.shopfrontFacesItsStreet()
	withSamples(function(_, built)
		local lot = firstOf("shops with flats")
		local bay: BasePart? = nil
		for _, d in built[1]:GetDescendants() do
			if d:IsA("MeshPart") and string.find((d.Parent :: Instance).Name, "WindowCentre_A", 1, true) then
				bay = d
				break
			end
		end
		assert(bay, "parade has no ground-floor bay")
		local toBay = (bay :: BasePart).Position - (ORIGIN * lot.centre)
		assert(toBay:Dot(lot.front) > 0, "the shop bay is on the side away from Lot.front")
	end)
end

function T.districtFilterBuildsOnlyThatDistrictWithinBudget()
	local folder = scratch()
	local ok, err = pcall(function()
		local result = TradeAssembler.build(folder, ORIGIN, { district = "Industrial Estate" })
		assert(result.lots > 0, "filter built nothing")
		for _, group in folder:GetChildren() do
			assert(group.Name == "Trade_Industrial Estate", "unexpected district " .. group.Name)
			assert((group :: Model).ModelStreamingMode == Enum.ModelStreamingMode.Default, "district group must not be Atomic")
		end
		assert(V3Perf.withinBudget(V3Perf.count(folder), TradeAssembler.PART_BUDGET), "over budget")
	end)
	folder:Destroy()
	assert(ok, err)
end

return T
