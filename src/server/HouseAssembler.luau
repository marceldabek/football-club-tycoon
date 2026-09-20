--!strict
-- Rivermere v3, Lane H. Builds every house in town from the Modular English Housing kit, one
-- building per TownFrontage lot, plus front garden boundaries and back-yard fences and bins.
-- Recipes and selection are pure data in ReplicatedStorage.Shared.HouseRecipes; this module only
-- turns them into kit meshes through KitPlacer. No primitives are created here.
--
-- Lot frame: local -Z points at the street (Lot.front), local +X runs along it. The body's front
-- wall sits on the lot's front edge, the garden lies between that edge and the pavement, and
-- whatever depth is left behind the body is the back yard.
--
-- Output (docs/TOWN_V3_BUILD.md section 9 rules):
--   parent / Housing_<district>      Model, streaming Default (grouping only)
--     Lot_<street>                   Model, Atomic, attribute LotId: ONE per lot, the building
--     Boundaries                     Model, Default
--       Boundary_<street>            Model, Default, attribute BoundaryLotId: walls, fences, bins

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HouseRecipes = require(ReplicatedStorage.Shared.HouseRecipes)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local BackYards = require(ReplicatedStorage.Shared.BackYards)
local KitPlacer = require(ServerScriptService.Server.KitPlacer)
local V3Perf = require(ServerScriptService.Server.V3Perf)

local HouseAssembler = {}

-- Section 9, published by Lane P 2026-09-20. Houses and plot boundaries are budgeted apart.
HouseAssembler.PART_BUDGET = 24000
HouseAssembler.BOUNDARY_BUDGET = 13500

export type Detail = {
	tier: number, -- 1 = shell only, 2 = + chimneys and door canopies
	roofSpan: "unit" | "row", -- "row": two stretched roof slopes per ROW instead of two per unit
	backSpan: "unit" | "row", -- "row": one stretched back wall per ROW instead of one per unit
	cornerEnds: boolean, -- windowed gable ends on corner lots (5 parts an end instead of 2)
	gardens: "all" | "corner" | "none", -- front garden walls
	gardenStyles: "all" | "light", -- "light": only 1-2 part pieces under the triangle cap
	boundaryStretch: number, -- how far one boundary piece may be stretched before a second is added
	yards: "all" | "corner" | "none", -- back fences
	bins: boolean, -- wheelie bin in one yard in three
	flatten: boolean, -- drop KitPlacer's wrapper Models, keep only the MeshParts
}

-- EVERY budget lever is one field here; the [FCT] line reports the result. Measured per-unit
-- costs for each preset are in docs/TOWN_V3_HANDOFFS.md (Lane H).
HouseAssembler.PRESETS = {
	-- Tier A: within TIER_A_RADIUS of a plot, the Market Square or the station. Slice density.
	tierA = { tier = 2, roofSpan = "unit", backSpan = "row", cornerEnds = true, gardens = "all", gardenStyles = "all", boundaryStretch = 1.8, yards = "all", bins = true, flatten = true },
	-- Tier B: the same houses under one continuous roof per row (a terrace shares its roof in
	-- real life too; saves 1.6 MeshParts a unit), boundaries held to 4 MeshParts a unit.
	tierB = { tier = 2, roofSpan = "row", backSpan = "row", cornerEnds = true, gardens = "all", gardenStyles = "light", boundaryStretch = 2.6, yards = "none", bins = false, flatten = true },
	-- Emergency brake if Lane P cuts again: 6 MeshParts a unit, no boundaries.
	lean = { tier = 1, roofSpan = "row", backSpan = "row", cornerEnds = false, gardens = "none", gardenStyles = "light", boundaryStretch = 2.6, yards = "none", bins = false, flatten = true },
} :: { [string]: Detail }
HouseAssembler.DETAIL_BY_TIER = { A = HouseAssembler.PRESETS.tierA, B = HouseAssembler.PRESETS.tierB }

-- Tier A centres (section 9): the four plots, the Market Square, the station.
HouseAssembler.TIER_A_RADIUS = 450
local tierPoints: { Vector3 } = { Vector3.new(0, 0, 0), Vector3.new(-900, 0, -350) }
for _, plot in (TownLayout :: any).PLOTS or {} do
	table.insert(tierPoints, plot.centre)
end

function HouseAssembler.tierFor(position: Vector3): string
	for _, point in tierPoints do
		local dx, dz = position.X - point.X, position.Z - point.Z
		if dx * dx + dz * dz <= HouseAssembler.TIER_A_RADIUS * HouseAssembler.TIER_A_RADIUS then
			return "A"
		end
	end
	return "B"
end

local TRIM_SOURCE = "MEH__House_02_VAR1__"
local BOUNDARY_ROLE = { garden = true, yard = true }

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
	house: Instance,
	boundary: Instance,
	counts: { [string]: number },
}

local trimCache: { [string]: SurfaceAppearance } = {}
local function trimAppearance(trim: string): SurfaceAppearance?
	local cached = trimCache[trim]
	if cached and cached.Parent then
		return cached
	end
	local template = KitPlacer.find(TRIM_SOURCE .. trim)
	local sa = template and template:FindFirstChildWhichIsA("SurfaceAppearance", true)
	if sa then
		trimCache[trim] = sa
	end
	return sa
end

-- Places one kit asset with its bounding-box bottom centre at `cf`.
local function put(ctx: Ctx, name: string, cf: CFrame, scale: number, stretchX: number?, trim: string?, role: string)
	local isBoundary = BOUNDARY_ROLE[role] == true
	local parent = if isBoundary then ctx.boundary else ctx.house
	local model = KitPlacer.place(name, cf, parent, { scale = scale })
	if model:GetAttribute("KitMissing") ~= nil then
		ctx.counts.missing += 1
		return
	end
	V3Perf.applyDefaults(model, if isBoundary then "prop" else "structure")

	local parts: { MeshPart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
		end
	end

	if stretchX and math.abs(stretchX - 1) > 1e-3 then
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

	-- The MEH modular pieces were uploaded without textures (Question P3); they share the prefab
	-- houses' trim sheet. ts1 leaves an existing SurfaceAppearance alone, so a fixed export wins;
	-- ts3 always swaps, because the second trim only exists as the prefab's SurfaceAppearance.
	local sa = if trim then trimAppearance(trim) else nil
	for _, part in parts do
		if sa then
			local old = part:FindFirstChildOfClass("SurfaceAppearance")
			if old and trim ~= "ts1" then
				old:Destroy()
				old = nil
			end
			if not old then
				sa:Clone().Parent = part
			end
		end
		if role == "door" or role == "canopy" or role == "chimney" then
			part.CastShadow = false
		end
		part:SetAttribute("Kit", name)
		part:SetAttribute("Role", role)
	end

	if ctx.detail.flatten then
		for _, part in parts do
			part.Name = name
			part.Parent = parent
		end
		model:Destroy()
	end
	if isBoundary then
		ctx.counts.boundaryParts += #parts
	else
		ctx.counts.houseParts += #parts
	end
end

local function putPiece(ctx: Ctx, unitCF: CFrame, s: number, p: HouseRecipes.Piece, trim: string, prefab: boolean?)
	local cf = unitCF * CFrame.new(p.offset * s) * CFrame.Angles(0, math.rad(p.yaw), 0)
	if prefab then
		put(ctx, "MEH__" .. p.piece .. "__" .. trim, cf, s, nil, nil, p.role)
	else
		put(ctx, "MEH__" .. p.piece .. "__ts1", cf, s * (p.scale or 1), p.stretchX, trim, p.role)
	end
end

-- A straight boundary from x0 to x1 (in `frame`) at depth z. One piece per run wherever a
-- stretch of up to detail.boundaryStretch covers it, so a frontage is 2 pieces, not 4-6.
local function boundaryRun(ctx: Ctx, frame: CFrame, x0: number, x1: number, z: number, style: HouseRecipes.GardenStyle, trim: string, role: string, maxStretch: number?)
	local length = x1 - x0
	if length < 1.5 then
		return
	end
	local native = style.length * (style.scale or 1)
	local n = math.max(1, math.ceil(length / (native * math.max(ctx.detail.boundaryStretch, maxStretch or 0))))
	local each = length / n
	for i = 1, n do
		local cf = frame * CFrame.new(x0 + each * (i - 0.5), 0, z)
		put(ctx, style.piece, cf, style.scale or 1, each / native, if style.trim then trim else nil, role)
	end
end

-- TownFrontage.lotCFrame puts local +X along the street but does not say which side the street
-- is on, so turn it until local -Z (LookVector) is Lot.front: doors always face the street.
function HouseAssembler.lotFrame(lot: Lot): CFrame
	local frame = TownFrontage.lotCFrame(lot :: any)
	if frame.LookVector:Dot(lot.front) < 0 then
		frame = frame * CFrame.Angles(0, math.pi, 0)
	end
	return frame
end

local function wants(mode: string, lot: Lot): boolean
	return mode == "all" or (mode == "corner" and (lot.corner or lot.closesStreet))
end

local function buildLot(ctx: Ctx, lot: Lot, origin: CFrame)
	local detail = ctx.detail
	local lotCF = origin * HouseAssembler.lotFrame(lot)
	local backCF = lotCF * CFrame.Angles(0, math.pi, 0)
	local width = lot.size.X / lot.units
	local depth = lot.size.Z
	local plans = HouseRecipes.planLot(lot.use, lot.id, lot.units)
	local trim = HouseRecipes.trimFor(lot.id)
	local isTerrace = lot.use == "terraced row"
	local isRow = HouseRecipes.USE_KIND[lot.use] ~= "detached"
	-- Windowed gables only where a terrace meets a junction; a semi's side faces its neighbour.
	local windowedEnds = lot.corner and detail.cornerEnds and isTerrace

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

		-- Gable ends only at the two ends of a row; party walls between units are never built.
		if not recipe.ends then
			if i == 1 then
				for _, p in HouseRecipes.endCap(-1, windowedEnds) do
					putPiece(ctx, unitCF, s, p, trim)
				end
			end
			if i == #plans then
				for _, p in HouseRecipes.endCap(1, windowedEnds) do
					putPiece(ctx, unitCF, s, p, trim)
				end
			end
		end

		if wants(detail.gardens, lot) then
			-- A terrace shares one boundary style along the row; semis and detached pick per pair.
			local styleIndex = if isTerrace then 0 else math.floor((i - 1) / 2) + 1
			local style = HouseRecipes.gardenStyleFor(lot.id, styleIndex, detail.gardenStyles == "light")
			local gardenType = TownFrontage.TYPES[lot.use]
			local gz = -depth / 2 - (if gardenType then gardenType.garden else 6) + 0.6
			local gate = x + recipe.doorX * s * (if plan.mirrored then -1 else 1)
			local half = HouseRecipes.GATE_GAP / 2
			boundaryRun(ctx, lotCF, x - width / 2, gate - half, gz, style, trim, "garden")
			boundaryRun(ctx, lotCF, gate + half, x + width / 2, gz, style, trim, "garden")
		end

		-- A terrace that backs onto a back alley gets a walled yard out to the alley's edge,
		-- in every tier that builds boundaries (the alley is bare without it): a brick wall
		-- along the alley with a wooden gate, and a fence to the neighbour. Gates alternate
		-- sides so neighbours' gates pair up. Row ends are closed after the loop.
		local unitBack = (HouseAssembler.lotFrame(lot) * CFrame.new(x, 0, depth / 2)).Position
		local yardDepth = if isTerrace and detail.gardens ~= "none"
			then BackYards.depthBehind(unitBack, lot.front, TownLayout.ROADS :: any)
			else nil
		if yardDepth then
			local partsBefore = ctx.counts.boundaryParts
			local wallZ = -depth / 2 - yardDepth
			local gateSide = if i % 2 == 1 then -1 else 1 -- in backCF's X
			local gateX = -x + gateSide * (width / 2 - BackYards.GATE_GAP / 2 - 0.4)
			local gate = BackYards.GATE
			put(ctx, gate.piece, backCF * CFrame.new(gateX, 0, wallZ), 1, nil, trim, "yard")
			if gateSide < 0 then
				boundaryRun(ctx, backCF, gateX + BackYards.GATE_GAP / 2, -x + width / 2, wallZ, BackYards.WALL :: any, trim, "yard", BackYards.WALL_MAX_STRETCH)
				boundaryRun(ctx, backCF, -x - width / 2, gateX - BackYards.GATE_GAP / 2, wallZ, BackYards.WALL :: any, trim, "yard", BackYards.WALL_MAX_STRETCH)
			else
				boundaryRun(ctx, backCF, -x - width / 2, gateX - BackYards.GATE_GAP / 2, wallZ, BackYards.WALL :: any, trim, "yard", BackYards.WALL_MAX_STRETCH)
				boundaryRun(ctx, backCF, gateX + BackYards.GATE_GAP / 2, -x + width / 2, wallZ, BackYards.WALL :: any, trim, "yard", BackYards.WALL_MAX_STRETCH)
			end
			-- side returns, running back from the lot: a party fence between neighbours,
			-- the brick wall at the two ends of the row
			local sideCF = backCF * CFrame.Angles(0, math.pi / 2, 0)
			local function side(atX: number, style)
				-- sideCF's local X is backCF's -Z (out from the back of the lot), its local Z is backCF's X
				boundaryRun(ctx, sideCF, depth / 2, depth / 2 + yardDepth, atX, style, trim, "yard")
			end
			if i == 1 then
				side(-x - width / 2, BackYards.WALL :: any)
			end
			side(-x + width / 2, if i == #plans then BackYards.WALL :: any else BackYards.PARTY_FENCE :: any)
			ctx.counts.yards += 1
			ctx.counts.yardParts += ctx.counts.boundaryParts - partsBefore
		end

		if wants(detail.yards, lot) then
			if not yardDepth then
				boundaryRun(ctx, backCF, -x - width / 2, -x + width / 2, -depth / 2 + 0.3, HouseRecipes.BACK_FENCE, trim, "yard")
			end
			local h = HouseRecipes.hash(lot.id .. "#yard" .. tostring(i))
			if detail.bins and h % 3 == 0 then
				local bin = HouseRecipes.BIN
				local spot = lotCF * CFrame.new(x + width * 0.3, 0, depth / 2 - 2.2) * CFrame.Angles(0, math.rad(h % 360), 0)
				put(ctx, bin.base, spot, 1, nil, nil, "yard")
				put(ctx, bin.lid, spot * CFrame.new(0, bin.lidHeight, 0), 1, nil, nil, "yard")
			end
		end
	end

	-- Row-spanning back wall and roof, stretched along the whole row.
	if isRow then
		local s = rowScale
		local M = HouseRecipes.MODULE
		local rowCF = lotCF * CFrame.new(0, 0, -depth / 2 + M * s)
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

local function newModel(name: string, parent: Instance, atomic: boolean): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = if atomic then Enum.ModelStreamingMode.Atomic else Enum.ModelStreamingMode.Default
	model.Parent = parent
	return model
end

-- Builds the given lots. `detail` overrides the per-tier presets (tests, reviews, Lane P trials).
function HouseAssembler.buildLots(parent: Instance, origin: CFrame, lots: { Lot }, filter: { district: string? }?, detail: Detail?): { [string]: number }
	local counts = { lots = 0, units = 0, houseParts = 0, boundaryParts = 0, meshParts = 0, missing = 0, districts = 0, tierA = 0, yards = 0, yardParts = 0 }
	local districtModels: { [string]: Model } = {}
	local boundaryModels: { [string]: Model } = {}
	local wantDistrict = filter and filter.district

	for _, lot in lots do
		if HouseRecipes.USE_KIND[lot.use] == nil or lot.units < 1 then
			continue
		end
		if wantDistrict and lot.district ~= wantDistrict then
			continue
		end
		local districtModel = districtModels[lot.district]
		if not districtModel then
			districtModel = newModel("Housing_" .. lot.district, parent, false)
			districtModels[lot.district] = districtModel
			boundaryModels[lot.district] = newModel("Boundaries", districtModel, false)
			counts.districts += 1
		end

		local tier = HouseAssembler.tierFor(lot.centre)
		local lotModel = newModel("Lot_" .. lot.street, districtModel, true)
		lotModel:SetAttribute("LotId", lot.id)
		lotModel:SetAttribute("Use", lot.use)
		lotModel:SetAttribute("Units", lot.units)
		lotModel:SetAttribute("Tier", tier)
		local boundaryModel = newModel("Boundary_" .. lot.street, boundaryModels[lot.district], false)
		boundaryModel:SetAttribute("BoundaryLotId", lot.id)

		local ctx: Ctx = {
			detail = detail or HouseAssembler.DETAIL_BY_TIER[tier],
			house = lotModel,
			boundary = boundaryModel,
			counts = counts,
		}
		buildLot(ctx, lot, origin)
		if #boundaryModel:GetChildren() == 0 then
			boundaryModel:Destroy()
		end
		counts.lots += 1
		counts.units += lot.units
		if tier == "A" then
			counts.tierA += 1
		end
	end
	counts.meshParts = counts.houseParts + counts.boundaryParts

	local perUnit = if counts.units > 0 then counts.houseParts / counts.units else 0
	local boundaryPerUnit = if counts.units > 0 then counts.boundaryParts / counts.units else 0
	print(("[FCT] Housing: %d lots (%d tier A), %d units, houses %d MeshParts (%.1f/unit, town budget %d), boundaries %d (%.1f/unit, town budget %d), %d KitMissing"):format(
		counts.lots, counts.tierA, counts.units, counts.houseParts, perUnit, HouseAssembler.PART_BUDGET,
		counts.boundaryParts, boundaryPerUnit, HouseAssembler.BOUNDARY_BUDGET, counts.missing))
	for _, districtModel in districtModels do
		print(("[FCT] Housing %s: %s"):format(districtModel.Name, V3Perf.format(V3Perf.count(districtModel))))
	end
	return counts
end

-- Section 4.3 contract.
function HouseAssembler.build(parent: Instance, origin: CFrame, filter: { district: string? }?): { [string]: number }
	local counts = HouseAssembler.buildLots(parent, origin, TownFrontage.generate() :: any, filter, nil)
	if filter == nil or filter.district == nil then
		if counts.houseParts > HouseAssembler.PART_BUDGET then
			warn(("[FCT] Housing: %d house MeshParts is over the budget of %d"):format(counts.houseParts, HouseAssembler.PART_BUDGET))
		end
		if counts.boundaryParts > HouseAssembler.BOUNDARY_BUDGET then
			warn(("[FCT] Housing: %d boundary MeshParts is over the budget of %d"):format(counts.boundaryParts, HouseAssembler.BOUNDARY_BUDGET))
		end
	end
	return counts
end

return HouseAssembler
