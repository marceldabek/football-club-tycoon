--!strict
-- Rivermere v3, Lane C: builds commercial, industrial and civic buildings from TradeRecipes.
-- Every visible object is a kit clone placed through KitPlacer. No Parts are created here; the only
-- primitives in the output are inside the Creator Store `ChurchSpire` keeper, tagged V3Exempt EC7.
-- Contract: docs/TOWN_V3_BUILD.md section 4.3, streaming and budget rules from section 9.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local TradeRecipes = require(Shared:WaitForChild("TradeRecipes"))
local KitPlacer = require(Server:WaitForChild("KitPlacer"))
local V3Perf = require(Server:WaitForChild("V3Perf"))

local TradeAssembler = {}

TradeAssembler.PART_BUDGET = 4000 -- MeshParts, whole town (section 9, published by Lane P)

-- The 67 MEH modular pieces were uploaded without their trim-sheet SurfaceAppearance (Question P3).
-- The prefab houses carry the same trim sheet, and the modular UVs match it (checked in Studio), so
-- until the pieces are re-exported the sheet is borrowed from a prefab. Harmless once they are
-- fixed: a MeshPart that already has a SurfaceAppearance is left alone.
local TRIM_SOURCES = { "MEH__House_01_VAR01__ts1", "MEH__House_01_VAR01__ts3" }
local trimCache: { [number]: SurfaceAppearance? } = {}
local function trimSheet(index: number): SurfaceAppearance?
	if trimCache[index] == nil then
		local template = KitPlacer.find(TRIM_SOURCES[index])
		local found = template and template:FindFirstChildWhichIsA("SurfaceAppearance", true)
		trimCache[index] = (found :: SurfaceAppearance?) or nil
	end
	return trimCache[index]
end

local function applyTrim(model: Model, index: number)
	local sheet = trimSheet(index) or trimSheet(1)
	if not sheet then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d.TextureID == "" and not d:FindFirstChildOfClass("SurfaceAppearance") then
			sheet:Clone().Parent = d
		end
	end
end

-- Stretches a one-mesh kit piece to `box` (width, height, depth in the target frame) and puts its
-- bottom centre on `target`. Used for roofs and cladding only, where stretch does not show.
local function fitTo(model: Model, target: CFrame, box: Vector3)
	local part = model:FindFirstChildWhichIsA("MeshPart", true)
	if not part then
		return
	end
	local rel = target:ToObjectSpace(part.CFrame)
	local sizes = {}
	for i, v in { rel.XVector, rel.YVector, rel.ZVector } do
		local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
		if ax >= ay and ax >= az then
			sizes[i] = box.X
		elseif ay >= az then
			sizes[i] = box.Y
		else
			sizes[i] = box.Z
		end
	end
	part.Size = Vector3.new(sizes[1], sizes[2], sizes[3])
	part.CFrame = target * CFrame.new(0, box.Y / 2, 0) * rel.Rotation
end

local PROP_PREFIXES = { "UKSP__Skips", "UKSP__dumpster", "UKSP__WoodPallets", "UKSP__boxes", "UKSP__ConcreteBarriers", "UKSP__PicnicBenches", "ForkliftYellow", "PH__" }
local function kindOf(kit: string): "structure" | "prop"
	for _, p in PROP_PREFIXES do
		if string.sub(kit, 1, #p) == p then
			return "prop"
		end
	end
	return "structure"
end

-- Lot frame: +X along the street, -Z towards the street (see TradeRecipes).
function TradeAssembler.lotFrame(origin: CFrame, lot: TradeRecipes.Lot): CFrame
	local front = Vector3.new(lot.front.X, 0, lot.front.Z).Unit
	local back = -front
	local up = Vector3.yAxis
	return origin * CFrame.fromMatrix(lot.centre, up:Cross(back), up, back)
end

function TradeAssembler.buildLot(parent: Instance, origin: CFrame, lot: TradeRecipes.Lot): Model
	local recipe = TradeRecipes.recipeFor(lot)
	local model = Instance.new("Model")
	model.Name = lot.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("LotUse", lot.use)
	model:SetAttribute("Recipe", recipe.kind)
	if recipe.gap then
		model:SetAttribute("Gap", recipe.gap)
	end
	local frame = TradeAssembler.lotFrame(origin, lot)
	local trim = if TradeRecipes.seedOf(lot.id) % 3 == 0 then 2 else 1
	for _, piece in recipe.pieces do
		local target = frame * CFrame.new(piece.pos) * CFrame.Angles(0, math.rad(piece.yaw), 0)
		local placed = KitPlacer.place(piece.kit, target, model, { scale = piece.scale })
		if piece.fit and not placed:GetAttribute("KitMissing") then
			fitTo(placed, target, piece.fit)
		end
		if string.sub(piece.kit, 1, 5) == "MEH__" then
			applyTrim(placed, trim)
		end
		V3Perf.applyDefaults(placed, kindOf(piece.kit))
		if recipe.gap == "EC7" then
			for _, d in placed:GetDescendants() do
				if d:IsA("BasePart") and not d:IsA("MeshPart") then
					d:SetAttribute("V3Exempt", "EC7")
				end
			end
		end
	end
	model.Parent = parent
	return model
end

function TradeAssembler.build(parent: Instance, origin: CFrame, filter: { district: string? }?): { [string]: number }
	-- TownFrontage / TownLayout are read when they hold v3 data; TradeRecipes falls back to its
	-- fixture for whichever is missing or still a stub.
	local function optional(name: string): any
		local module = Shared:FindFirstChild(name)
		if module then
			local ok, result = pcall(require, module)
			if ok then
				return result
			end
		end
		return nil
	end
	local wanted = filter and filter.district
	local districts: { [string]: Model } = {}
	local lots = 0
	for _, lot in TradeRecipes.lots(optional("TownFrontage"), optional("TownLayout")) do
		if wanted and lot.district ~= wanted then
			continue
		end
		local group = districts[lot.district]
		if not group then
			group = Instance.new("Model")
			group.Name = "Trade_" .. lot.district
			group.ModelStreamingMode = Enum.ModelStreamingMode.Default
			group.Parent = parent
			districts[lot.district] = group
		end
		TradeAssembler.buildLot(group, origin, lot)
		lots += 1
	end
	local counts = V3Perf.count(parent)
	print("[FCT] Trade: " .. lots .. " lots, " .. V3Perf.format(counts))
	return { lots = lots, meshParts = counts.meshParts, parts = counts.parts or 0, models = counts.models }
end

return TradeAssembler
