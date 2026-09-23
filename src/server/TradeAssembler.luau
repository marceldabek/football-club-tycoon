--!strict
-- Rivermere v3, Lane C: builds commercial, industrial and civic buildings from TradeRecipes.
-- Every visible object is a kit clone placed through KitPlacer. The only primitives in the output
-- are inside the Creator Store `ChurchSpire` keeper (V3Exempt EC7) and the dark core inside a
-- corner shop's body (EH1, as in HouseAssembler).
-- Contract: docs/TOWN_V3_BUILD.md section 4.3, streaming and budget rules from section 9.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local TradeRecipes = require(Shared:WaitForChild("TradeRecipes"))
local KitPlacer = require(Server:WaitForChild("KitPlacer"))
local V3Perf = require(Server:WaitForChild("V3Perf"))
local PubDressing = require(Server:WaitForChild("PubDressing"))
local FrontPaths = require(Shared:WaitForChild("FrontPaths"))
local TownFrontage = require(Shared:WaitForChild("TownFrontage"))

local TradeAssembler = {}

TradeAssembler.PART_BUDGET = 4000 -- MeshParts, whole town (section 9, published by Lane P)

-- #39a: industrial lots are mostly hardstanding in real life, not lawn. A plain tarmac slab
-- under the whole lot (same primitive-Part pattern as the EH1 core) so the yard reads as a
-- yard instead of grass showing through around the shed and its scattered props.
local YARD_GROUND_USES = { workshop = true, ["trade counter"] = true, warehouse = true, ["builders yard"] = true }
local YARD_GROUND_COLOR = Color3.fromRGB(90, 90, 94)
local YARD_GROUND_INSET = 1.5

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

-- Merged house unit meshes (HOUSE__<unit>__masonry / __roof / __trim, see Shared/HouseUnits) wear
-- the tileable brick or slate from Kit.Appearances, or the trim sheet.
local TRIM_NAMES = { "ts1", "ts3" }
local function unitLook(kit: string, trim: number): SurfaceAppearance?
	local layer = string.match(kit, "__(%a+)$")
	local prefix = if layer == "masonry" then "HouseBrick_" elseif layer == "roof" then "HouseSlate_" else nil
	if not prefix then
		return trimSheet(trim) or trimSheet(1)
	end
	local found = KitPlacer.find(prefix .. TRIM_NAMES[trim])
	return if found and found:IsA("SurfaceAppearance") then found else nil
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

-- #31: what joins a trade lot's front to the pavement across its front garden and the street's
-- verge (Shared/FrontPaths): a path from a block of flats' door, a paved forecourt the width of
-- a corner shop, a vehicle crossing into an industrial yard. Built as its own model beside the
-- lot (it lies outside the lot's box), from the lot's own front edge outwards.
local FRONT_FORECOURT = { ["corner shop"] = true }
local FRONT_CROSSING = { workshop = 14, ["trade counter"] = 14, warehouse = 20 }
local FLATS_PATH_WIDTH = 3.4
local FLATS_SETBACK = 4 -- TradeRecipes: a block of flats stands this far behind its lot's front
local function frontApron(parent: Instance, frame: CFrame, lot: TradeRecipes.Lot): Model?
	local frontage = TownFrontage.TYPES[lot.use]
	if not frontage or lot.street == "" then
		return nil
	end
	local edge = lot.centre + lot.front * (lot.size.Z / 2 + frontage.garden)
	local reach = frontage.garden + FrontPaths.verge(lot.street, lot.closesStreet, edge, lot.front)
	if reach <= 0.2 then
		return nil
	end
	local z0 = -lot.size.Z / 2 - reach
	local z1, width
	if lot.use == "flats" then
		z1, width = -lot.size.Z / 2 + FLATS_SETBACK, FLATS_PATH_WIDTH
	elseif FRONT_FORECOURT[lot.use] then
		z1, width = -lot.size.Z / 2 + 0.3, lot.size.X
	elseif FRONT_CROSSING[lot.use] then
		z1, width = -lot.size.Z / 2 + 0.3, FRONT_CROSSING[lot.use]
	else
		return nil
	end
	local model = Instance.new("Model")
	model.Name = lot.id .. "|Front"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local slab = Instance.new("Part")
	slab.Name = if lot.use == "flats" then "FrontPath" else "FrontApron"
	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.CastShadow = false
	slab.Material = if FRONT_CROSSING[lot.use] then Enum.Material.Asphalt else Enum.Material.Concrete
	slab.Color = if FRONT_CROSSING[lot.use] then Color3.fromRGB(90, 90, 94) else FrontPaths.COLOR
	slab.Size = Vector3.new(width, FrontPaths.THICKNESS, z1 - z0)
	slab.CFrame = frame * CFrame.new(0, FrontPaths.TOP - FrontPaths.THICKNESS / 2, (z0 + z1) / 2)
	slab:SetAttribute("V3Exempt", "EC2")
	slab.Parent = model
	model.Parent = parent
	return model
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

	if YARD_GROUND_USES[lot.use] then
		local ground = Instance.new("Part")
		ground.Name = "YardGround"
		ground.Anchored = true
		ground.CanCollide = false
		ground.CanQuery = false
		ground.CanTouch = false
		ground.CastShadow = false
		ground.Material = Enum.Material.Asphalt
		ground.Color = YARD_GROUND_COLOR
		-- top at 0.3, matching TownBuilder's flat-district-piece convention (car park, lawns)
		ground.Size = Vector3.new(math.max(lot.size.X - YARD_GROUND_INSET * 2, 1), 0.3, math.max(lot.size.Z - YARD_GROUND_INSET * 2, 1))
		ground.CFrame = frame * CFrame.new(0, 0.15, 0)
		ground:SetAttribute("V3Exempt", "EC2")
		ground.Parent = model
	end
	local pieces = recipe.pieces
	if recipe.fallback then
		for _, piece in pieces do
			if not KitPlacer.find(piece.kit) or not unitLook(piece.kit, trim) then
				pieces = recipe.fallback -- a place without the merged house units
				break
			end
		end
	end
	local cores = table.clone(recipe.cores or {})
	if recipe.core then
		table.insert(cores, recipe.core)
	end
	for _, box in (if pieces == recipe.pieces then cores else {}) do
		-- Same guard as HouseAssembler.putCore (register row EH1): kit walls are single-sided.
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Anchored = true
		core.CanCollide = false
		core.CanQuery = false
		core.CanTouch = false
		core.CastShadow = false
		core.Material = Enum.Material.SmoothPlastic
		core.Color = Color3.fromRGB(24, 24, 28)
		core.Size = box.size
		core.CFrame = frame * CFrame.new(box.pos + Vector3.new(0, box.size.Y / 2, 0))
		core:SetAttribute("V3Exempt", "EH1")
		core.Parent = model
	end
	for _, piece in pieces do
		local target = frame * CFrame.new(piece.pos) * CFrame.Angles(0, math.rad(piece.yaw), 0)
		-- a recipe's scale is relative to the kit piece as stored; KitPlacer's is absolute
		-- (Model:ScaleTo), and a few kit models are stored pre-scaled (the forklift at 0.342)
		local scale = piece.scale
		local template = if scale then KitPlacer.find(piece.kit) else nil
		if scale and template and template:IsA("Model") then
			scale *= template:GetScale()
		end
		local placed = KitPlacer.place(piece.kit, target, model, { scale = scale })
		if piece.fit and not placed:GetAttribute("KitMissing") then
			fitTo(placed, target, piece.fit)
		end
		if string.sub(piece.kit, 1, 5) == "MEH__" then
			applyTrim(placed, piece.trim or trim)
		elseif string.sub(piece.kit, 1, 7) == "HOUSE__" then
			local look = unitLook(piece.kit, trim)
			for _, d in placed:GetDescendants() do
				if look and d:IsA("MeshPart") and not d:FindFirstChildOfClass("SurfaceAppearance") then
					look:Clone().Parent = d
				end
			end
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
	-- #16: pubs get the front TownLife hangs matchday drinkers on; a Supporters' Bar (lot.sign)
	-- also gets its forecourt, path and hanging sign, as a model beside the lot
	if lot.use == "pub" or lot.use == "pub and cafes" then
		PubDressing.frontMarker(model, frame, pieces)
	end
	model.Parent = parent
	if lot.sign then
		PubDressing.forecourt(parent, origin, frame, lot, pieces)
	end
	frontApron(parent, frame, lot)
	return model
end

-- #39a: an industrial estate is hardstanding, not lawn. The YardGround slab only covers a lot's
-- own box, and the grass between the units, their front gardens and the backs stayed green, so
-- the terrain round every industrial lot is repainted concrete (no parts: the terrain voxels
-- change material, nothing is added). From each lot the paving runs sideways and back until it
-- meets a street's corridor (road plus pavement), a lot that is not industrial, or the river,
-- so a block between estate roads ends up paved kerb to kerb. Runs in the live town only
-- (Main), never in tests: it edits workspace.Terrain.
TradeAssembler.YARD_PAVE_FRONT = 2 -- past the front garden, under the street's verge
TradeAssembler.YARD_PAVE_MAX = 320 -- furthest the paving looks for a street from a lot
TradeAssembler.YARD_PAVE_OPEN = 24 -- how far it runs where no street closes the block (the estate's edge)
TradeAssembler.YARD_PAVE_STEP = 4
TradeAssembler.YARD_RIVER_CLEAR = 30 -- the river bank stays green

-- Pure: how far from `from` (town coordinates) the paving may run along `dir`: up to a street
-- corridor or a non-industrial lot (grown by 4) that closes the block; only YARD_PAVE_OPEN
-- where nothing does (the estate's outer edge, or the river bank).
function TradeAssembler.paveReach(from: Vector3, dir: Vector3, roads: { any }, others: { any }, layout: any): number
	local step = TradeAssembler.YARD_PAVE_STEP
	local t = 0
	while t < TradeAssembler.YARD_PAVE_MAX do
		local p = from + dir * (t + step)
		for _, road in roads do
			if layout.distanceToPolyline(p, road.points) < road.width / 2 + layout.PAVEMENT_WIDTH then
				return t
			end
		end
		for _, other in others do
			local l = TownFrontage.lotCFrame(other):PointToObjectSpace(Vector3.new(p.X, other.centre.Y, p.Z))
			if math.abs(l.X) <= other.size.X / 2 + 4 and math.abs(l.Z) <= other.size.Z / 2 + 4 then
				return t
			end
		end
		if layout.distanceToPolyline(p, layout.RIVER.points) < layout.RIVER.width / 2 + TradeAssembler.YARD_RIVER_CLEAR then
			break
		end
		t += step
	end
	return math.min(t, TradeAssembler.YARD_PAVE_OPEN)
end

function TradeAssembler.paveYards(origin: CFrame): number
	local layout = require(Shared:WaitForChild("TownLayout"))
	local terrain = workspace.Terrain
	local yards: { TradeRecipes.Lot } = {}
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, lot in TradeRecipes.lots(TownFrontage, layout) do
		if YARD_GROUND_USES[lot.use] then
			table.insert(yards, lot)
			local r = math.max(lot.size.X, lot.size.Z)
			lo = lo:Min(lot.centre - Vector3.new(r, 0, r))
			hi = hi:Max(lot.centre + Vector3.new(r, 0, r))
		end
	end
	-- only what could stop the paving: roads and non-industrial lots near the estate
	local reach = TradeAssembler.YARD_PAVE_MAX + 60
	local function near(p: Vector3, pad: number): boolean
		return p.X > lo.X - reach - pad and p.X < hi.X + reach + pad and p.Z > lo.Z - reach - pad and p.Z < hi.Z + reach + pad
	end
	local roads = {}
	for _, road in layout.ROADS do
		for _, q in road.points do
			if near(q, 400) then
				table.insert(roads, road)
				break
			end
		end
	end
	local others = {}
	for _, lot in TownFrontage.generate() do
		if not YARD_GROUND_USES[lot.use] and near(lot.centre, 0) then
			table.insert(others, lot)
		end
	end
	for _, lot in yards do
		local frontage = TownFrontage.TYPES[lot.use]
		local frame = TradeAssembler.lotFrame(CFrame.identity, lot)
		local hx, hz = lot.size.X / 2, lot.size.Z / 2
		local left = TradeAssembler.paveReach(frame * Vector3.new(-hx, 0, 0), -frame.XVector, roads, others, layout)
		local right = TradeAssembler.paveReach(frame * Vector3.new(hx, 0, 0), frame.XVector, roads, others, layout)
		local back = TradeAssembler.paveReach(frame * Vector3.new(0, 0, hz), frame.ZVector, roads, others, layout)
		local z0 = -hz - (if frontage then frontage.garden else 0) - TradeAssembler.YARD_PAVE_FRONT
		local x0, x1, z1 = -hx - left, hx + right, hz + back
		local a, b = Vector3.new(math.huge, -32, math.huge), Vector3.new(-math.huge, 8, -math.huge)
		for _, corner in { Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1) } do
			local p = origin * (frame * corner)
			a = Vector3.new(math.min(a.X, p.X), a.Y, math.min(a.Z, p.Z))
			b = Vector3.new(math.max(b.X, p.X), b.Y, math.max(b.Z, p.Z))
		end
		terrain:ReplaceMaterial(Region3.new(a, b):ExpandToGrid(4), 4, Enum.Material.LeafyGrass, Enum.Material.Concrete)
	end
	return #yards
end

-- Lane I: specials another module owns in the live town, so nothing is built twice. The church is
-- SquareDresser's (same ChurchSpire keeper, plus the churchyard round it). buildLot still builds
-- one on request, for the sandbox and the tests.
TradeAssembler.OWNED_ELSEWHERE = { church = "SquareDresser" } :: { [string]: string }

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
		if TradeAssembler.OWNED_ELSEWHERE[lot.use] then
			continue
		end
		local group = districts[lot.district]
		if not group then
			group = Instance.new("Model")
			group.Name = "Trade_" .. lot.district
			group.ModelStreamingMode = Enum.ModelStreamingMode.Default
			-- Lane I (#27): whole-block grouping model gets a low-detail stand-in
			-- (best-effort, see V3Perf).
			V3Perf.trySetStreamingMesh(group)
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
