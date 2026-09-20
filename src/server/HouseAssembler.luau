--!strict
-- Rivermere v3, Lane H. Builds every house in town from the Modular English Housing kit, one
-- building per TownFrontage lot, plus front garden boundaries and back-yard fences and bins.
-- Recipes and selection are pure data in ReplicatedStorage.Shared.HouseRecipes; this module only
-- turns them into kit meshes through KitPlacer. No primitives are created here.
--
-- Lot frame: local -Z points at the street (Lot.front), local +X runs along it. The body's front
-- wall sits on the lot's front edge, the garden lies between that edge and the pavement, and
-- whatever depth is left behind the body is the back yard.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HouseRecipes = require(ReplicatedStorage.Shared.HouseRecipes)
local KitPlacer = require(ServerScriptService.Server.KitPlacer)

local HouseAssembler = {}

HouseAssembler.PART_BUDGET = 9000 -- TEMP, docs/TOWN_V3_BUILD.md section 9

export type Detail = {
	tier: number, -- 1 = shell only, 2 = + chimneys and door canopies
	roofSpan: "unit" | "row", -- "row": two stretched roof slopes per ROW instead of per unit
	backSpan: "unit" | "row", -- "row": one stretched back wall per ROW
	cornerEnds: boolean, -- windowed gable ends on corner lots (5 parts an end instead of 2)
	gardens: "all" | "corner" | "none", -- front garden walls
	yards: "all" | "corner" | "none", -- back fences and bins
	flatten: boolean, -- drop KitPlacer's wrapper Models, keep only the MeshParts
}

-- Every budget lever is one field here. Lane P: switch DETAIL to a leaner preset, or change one
-- field, and the [FCT] line reports the new count. Measured per-unit costs are in
-- docs/TOWN_V3_HANDOFFS.md (Lane H).
HouseAssembler.PRESETS = {
	full = { tier = 2, roofSpan = "unit", backSpan = "unit", cornerEnds = true, gardens = "all", yards = "all", flatten = true },
	street = { tier = 2, roofSpan = "unit", backSpan = "row", cornerEnds = true, gardens = "all", yards = "none", flatten = true },
	lean = { tier = 1, roofSpan = "row", backSpan = "row", cornerEnds = false, gardens = "none", yards = "none", flatten = true },
} :: { [string]: Detail }
HouseAssembler.DETAIL = HouseAssembler.PRESETS.street

-- "district" follows the section 4.3 contract (one Atomic model per district). "lot" makes each
-- lot its own Atomic model so streaming can work at street scale.
HouseAssembler.STREAM_GROUP = "district"

local GARDEN_DEPTH: { [string]: number } = { ["terraced row"] = 6, ["semis"] = 8, ["detached house"] = 10 }
local TRIM_SOURCE = "MEH__House_02_VAR1__"
local MAX_STRETCH = 1.8

export type Lot = {
	id: string,
	use: string,
	district: string,
	street: string,
	centre: Vector3,
	size: Vector3,
	yaw: number,
	front: Vector3,
	units: number,
	unitWidth: number,
	closesStreet: boolean,
	corner: boolean,
}

type Ctx = {
	detail: Detail,
	parent: Instance,
	trims: { [string]: SurfaceAppearance },
	counts: { [string]: number },
}

local function trimAppearance(ctx: Ctx, trim: string): SurfaceAppearance?
	local cached = ctx.trims[trim]
	if cached then
		return cached
	end
	local template = KitPlacer.find(TRIM_SOURCE .. trim)
	local sa = template and template:FindFirstChildWhichIsA("SurfaceAppearance", true)
	if sa then
		ctx.trims[trim] = sa
	end
	return sa
end

-- Places one kit asset with its bounding-box bottom centre at `cf`. Returns the MeshParts.
local function put(ctx: Ctx, name: string, cf: CFrame, scale: number, stretchX: number?, trim: string?, role: string): { MeshPart }
	local model = KitPlacer.place(name, cf, ctx.parent, { scale = scale })
	local parts: { MeshPart } = {}
	if model:GetAttribute("KitMissing") ~= nil then
		ctx.counts.missing += 1
		return parts
	end
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
		end
	end
	local sa = if trim then trimAppearance(ctx, trim) else nil
	if stretchX and stretchX ~= 1 then
		-- Non-uniform stretch along the placement's X axis, about the placement centre. Each part
		-- grows along whichever of its own axes lies on that line (kit parts are axis-aligned).
		local axis = cf.RightVector
		for _, part in parts do
			local rel = cf:PointToObjectSpace(part.Position)
			local rotation = part.CFrame.Rotation
			local ax = math.abs(rotation.RightVector:Dot(axis))
			local ay = math.abs(rotation.UpVector:Dot(axis))
			local az = math.abs(rotation.LookVector:Dot(axis))
			local size = part.Size
			if ax >= ay and ax >= az then
				size = Vector3.new(size.X * stretchX, size.Y, size.Z)
			elseif ay >= az then
				size = Vector3.new(size.X, size.Y * stretchX, size.Z)
			else
				size = Vector3.new(size.X, size.Y, size.Z * stretchX)
			end
			part.Size = size
			part.CFrame = CFrame.new(cf:PointToWorldSpace(Vector3.new(rel.X * stretchX, rel.Y, rel.Z))) * rotation
		end
	end
	for _, part in parts do
		if sa then
			-- The modular pieces were uploaded without textures; they share the prefab trim sheet.
			local old = part:FindFirstChildOfClass("SurfaceAppearance")
			if old then
				old:Destroy()
			end
			sa:Clone().Parent = part
		end
		part.CastShadow = (role ~= "door" and role ~= "canopy" and role ~= "garden" and role ~= "yard")
		part:SetAttribute("Kit", name)
		part:SetAttribute("Role", role)
	end
	if ctx.detail.flatten then
		for _, part in parts do
			part.Name = name
			part.Parent = ctx.parent
		end
		model:Destroy()
	end
	ctx.counts.meshParts += #parts
	return parts
end

local function putPiece(ctx: Ctx, unitCF: CFrame, s: number, p: HouseRecipes.Piece, trim: string, prefab: boolean?)
	local cf = unitCF * CFrame.new(p.offset * s) * CFrame.Angles(0, math.rad(p.yaw), 0)
	if prefab then
		put(ctx, "MEH__" .. p.piece .. "__" .. trim, cf, s, nil, nil, p.role)
	else
		put(ctx, "MEH__" .. p.piece .. "__ts1", cf, s * (p.scale or 1), p.stretchX, trim, p.role)
	end
end

-- A straight boundary from x0 to x1 (lot-local) at depth z, facing the street.
local function boundaryRun(ctx: Ctx, lotCF: CFrame, x0: number, x1: number, z: number, style: HouseRecipes.GardenStyle, role: string)
	local length = x1 - x0
	if length < 1.5 then
		return
	end
	-- One piece per run wherever a stretch of up to MAX_STRETCH covers it: a house frontage is
	-- two runs either side of the gate, so a garden costs 2 pieces instead of 4-6.
	local native = style.length * (style.scale or 1)
	local n = math.max(1, math.ceil(length / (native * MAX_STRETCH)))
	local each = length / n
	for i = 1, n do
		local cf = lotCF * CFrame.new(x0 + each * (i - 0.5), 0, z)
		put(ctx, style.piece, cf, style.scale or 1, each / native, nil, role)
	end
end

local function wants(mode: string, lot: Lot): boolean
	return mode == "all" or (mode == "corner" and (lot.corner or lot.closesStreet))
end

local function buildLot(ctx: Ctx, lot: Lot, origin: CFrame)
	local detail = ctx.detail
	local lotCF = origin * CFrame.lookAt(lot.centre, lot.centre + lot.front)
	local width = lot.size.X / lot.units
	local depth = lot.size.Z
	local plans = HouseRecipes.planLot(lot.use, lot.id, lot.units)
	local trim = HouseRecipes.trimFor(lot.id)
	local isRow = HouseRecipes.USE_KIND[lot.use] ~= "detached"

	local rowScale = 1
	for i, plan in plans do
		local recipe = plan.recipe
		local s = HouseRecipes.scaleFor(recipe, width, depth)
		rowScale = s
		local x = -lot.size.X / 2 + width * (i - 0.5)
		local z = -depth / 2 + recipe.body.Z * s / 2
		local unitCF = lotCF * CFrame.new(x, 0, z)

		for _, p in HouseRecipes.pieces(recipe, plan.mirrored) do
			local skip = p.tier > detail.tier
				or (isRow and p.role == "roof" and detail.roofSpan == "row")
				or (isRow and p.role == "back" and detail.backSpan == "row")
			if not skip then
				putPiece(ctx, unitCF, s, p, trim, recipe.prefab)
			end
		end

		if not recipe.ends then
			if i == 1 then
				for _, p in HouseRecipes.endCap(-1, lot.corner and detail.cornerEnds) do
					putPiece(ctx, unitCF, s, p, trim)
				end
			end
			if i == #plans then
				for _, p in HouseRecipes.endCap(1, lot.corner and detail.cornerEnds) do
					putPiece(ctx, unitCF, s, p, trim)
				end
			end
		end

		if wants(detail.gardens, lot) then
			local styleIndex = if isRow and lot.use == "terraced row" then 0 else math.floor((i - 1) / 2) + 1
			local style = HouseRecipes.gardenStyleFor(lot.id, styleIndex)
			local gz = -depth / 2 - (GARDEN_DEPTH[lot.use] or 6) + 0.6
			local gate = x + recipe.doorX * s * (if plan.mirrored then -1 else 1)
			local half = HouseRecipes.GATE_GAP / 2
			boundaryRun(ctx, lotCF, x - width / 2, gate - half, gz, style, "garden")
			boundaryRun(ctx, lotCF, gate + half, x + width / 2, gz, style, "garden")
		end

		if wants(detail.yards, lot) then
			local fences = HouseRecipes.BACK_FENCES
			local h = HouseRecipes.hash(lot.id .. "#yard" .. tostring(i))
			local fence: HouseRecipes.GardenStyle = { id = "back", piece = fences[h % #fences + 1], length = 10, parts = 1 }
			boundaryRun(ctx, lotCF * CFrame.Angles(0, math.pi, 0), -x - width / 2, -x + width / 2, -depth / 2 + 0.3, fence, "yard")
			local pick = h % 3
			if pick < 2 then
				local clutter = HouseRecipes.BACK_CLUTTER
				local name = if pick == 0 then clutter[1] else clutter[2 + (h % (#clutter - 1))]
				local spot = lotCF * CFrame.new(x + width * 0.3, 0, depth / 2 - 2.2) * CFrame.Angles(0, (h % 360) * math.pi / 180, 0)
				put(ctx, name, spot, 1, nil, nil, "yard")
				if pick == 0 then
					put(ctx, "UKSP__TrachCan__TrashcanLid", spot * CFrame.new(0, 2.75, 0), 1, nil, nil, "yard")
				end
			end
		end
	end

	-- Row-spanning back wall and roof: the cheap tier. Stretched along the whole row.
	if isRow then
		local s = rowScale
		local M = HouseRecipes.MODULE
		local z = -depth / 2 + M * s
		local rowCF = lotCF * CFrame.new(0, 0, z)
		local spanFix = width / (2 * M * s) -- units are laid out on `width`, bodies are 16.5 * s wide
		if detail.backSpan == "row" then
			put(ctx, "MEH__Wall_A__ts1", rowCF * CFrame.new(0, 0, M * s) * CFrame.Angles(0, math.pi, 0), 2 * s, lot.units * spanFix, trim, "back")
		end
		if detail.roofSpan == "row" then
			local rz = (M / 2 + 0.17) * s
			put(ctx, "MEH__Roof_A__ts1", rowCF * CFrame.new(0, 2 * M * s, -rz), s, 2 * lot.units * spanFix, trim, "roof")
			put(ctx, "MEH__Roof_A__ts1", rowCF * CFrame.new(0, 2 * M * s, rz) * CFrame.Angles(0, math.pi, 0), s, 2 * lot.units * spanFix, trim, "roof")
		end
	end
end

-- Builds the given lots. Exposed so tests and the sandbox can build from a fixture while
-- TownFrontage is still a stub.
function HouseAssembler.buildLots(parent: Instance, origin: CFrame, lots: { Lot }, filter: { district: string? }?, detail: Detail?): { [string]: number }
	local counts = { lots = 0, units = 0, meshParts = 0, missing = 0, districts = 0 }
	local districtModels: { [string]: Model } = {}
	local wantDistrict = filter and filter.district
	local useDetail = detail or HouseAssembler.DETAIL

	for _, lot in lots do
		if HouseRecipes.USE_KIND[lot.use] == nil or lot.units < 1 then
			continue
		end
		if wantDistrict and lot.district ~= wantDistrict then
			continue
		end
		local districtModel = districtModels[lot.district]
		if not districtModel then
			districtModel = Instance.new("Model")
			districtModel.Name = "Housing_" .. lot.district
			if HouseAssembler.STREAM_GROUP == "district" then
				districtModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			end
			districtModel.Parent = parent
			districtModels[lot.district] = districtModel
			counts.districts += 1
		end

		local lotModel = Instance.new("Model")
		lotModel.Name = "Lot_" .. lot.street
		lotModel:SetAttribute("LotId", lot.id)
		lotModel:SetAttribute("Use", lot.use)
		lotModel:SetAttribute("Units", lot.units)
		if HouseAssembler.STREAM_GROUP == "lot" then
			lotModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		end
		lotModel.Parent = districtModel

		local ctx: Ctx = { detail = useDetail, parent = lotModel, trims = {}, counts = counts }
		buildLot(ctx, lot, origin)
		counts.lots += 1
		counts.units += lot.units
	end

	print(("[FCT] Housing: %d lots, %d units, %d MeshParts (budget %d), %d KitMissing, %d districts"):format(
		counts.lots, counts.units, counts.meshParts, HouseAssembler.PART_BUDGET, counts.missing, counts.districts))
	return counts
end

-- Section 4.3 contract.
function HouseAssembler.build(parent: Instance, origin: CFrame, filter: { district: string? }?): { [string]: number }
	local frontage = require(ReplicatedStorage.Shared.TownFrontage) :: any
	if type(frontage) ~= "table" or type(frontage.generate) ~= "function" then
		warn("[FCT] Housing: TownFrontage.generate() has not landed yet, nothing built")
		return { lots = 0, units = 0, meshParts = 0, missing = 0, districts = 0 }
	end
	return HouseAssembler.buildLots(parent, origin, frontage.generate(), filter, nil)
end

return HouseAssembler
