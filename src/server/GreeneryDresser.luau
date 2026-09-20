--!strict
-- Trees and shrubs on the open grass of the housing districts (backlog X116,
-- RivermereNorthfields.png / RiveremereWestdale.png: leafy streets, trees
-- behind and between the houses). The terraced and semis districts left wide
-- bare lawns between rows. Runs last, after every other dresser.
--
-- Candidate spots are a jittered grid over each district's block area. A spot
-- is kept only if it is well off every road and pavement, the buildings, the
-- river, the railway, bus stops, roundabouts and the club plots (all pure,
-- tested). At build time a spot is also skipped if anything already stands
-- there. Most spots get a tree (trunk and one or two crown balls), the rest a
-- pair of shrubs. All of it is Decor (hidden on Low).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)
local StreetDresser = require(script.Parent.StreetDresser)

local GreeneryDresser = {}

GreeneryDresser.DISTRICT_KINDS = { terraced = true, estate = true }
GreeneryDresser.STEP = 26
GreeneryDresser.KEEP = 0.55 -- share of clear grid spots that get something (TEMP)
GreeneryDresser.MAX_PER_DISTRICT = 120 -- TEMP part-budget cap, thinned evenly across the district
-- v3 Lane I stage 2: halved. With lots as the district area all 7 housing districts
-- fill their share, and 520 spots came to 1,188 primitive parts (it was 448 in v1).
-- These stay primitives only until the town has a tree asset (register row EI1).
GreeneryDresser.MAX = 260 -- TEMP overall cap
GreeneryDresser.ROAD_CLEAR = 5 -- past the pavement's outer edge
GreeneryDresser.BLOCK_CLEAR = 10
GreeneryDresser.RIVER_CLEAR = 15
GreeneryDresser.RAIL_CLEAR = 12
GreeneryDresser.STOP_CLEAR = 15
GreeneryDresser.LOT_CLEAR = 3 -- v3: past a TownFrontage lot's edge (house, gardens and walls)
local SEED = 777

-- v3: the houses are TownFrontage lots, not DISTRICTS blocks. A coarse grid of the
-- lots, built once, so `clear` does not walk all ~870 for every candidate spot.
local LOT_CELL = 120
local lotGrid: { [string]: { TownFrontage.Lot } }? = nil

local function lotsNear(p: Vector3): { TownFrontage.Lot }
	local grid = lotGrid
	if grid == nil then
		grid = {}
		for _, lot in TownFrontage.generate() do
			local reach = math.max(lot.size.X, lot.size.Z)
			local x0 = math.floor((lot.centre.X - reach) / LOT_CELL)
			local x1 = math.floor((lot.centre.X + reach) / LOT_CELL)
			local z0 = math.floor((lot.centre.Z - reach) / LOT_CELL)
			local z1 = math.floor((lot.centre.Z + reach) / LOT_CELL)
			for gx = x0, x1 do
				for gz = z0, z1 do
					local key = gx .. ":" .. gz
					local cell = grid[key]
					if not cell then
						cell = {}
						grid[key] = cell
					end
					table.insert(cell, lot)
				end
			end
		end
		lotGrid = grid
	end
	return grid[math.floor(p.X / LOT_CELL) .. ":" .. math.floor(p.Z / LOT_CELL)] or {}
end

-- Pure: is p inside (or within `grow` of) this lot's rectangle?
function GreeneryDresser.inLot(p: Vector3, lot: TownFrontage.Lot, grow: number): boolean
	local l = TownFrontage.lotCFrame(lot):PointToObjectSpace(Vector3.new(p.X, lot.centre.Y, p.Z))
	return math.abs(l.X) <= lot.size.X / 2 + grow and math.abs(l.Z) <= lot.size.Z / 2 + grow
end

local LEAVES = { Color3.fromRGB(74, 118, 54), Color3.fromRGB(86, 130, 60), Color3.fromRGB(64, 104, 50) }
local TRUNK = Color3.fromRGB(92, 70, 52)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Pure: is this ground point clear of everything built?
function GreeneryDresser.clear(p: Vector3): boolean
	for _, road in TownLayout.ROADS do
		local reach = road.width / 2 + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH) + GreeneryDresser.ROAD_CLEAR
		if TownLayout.distanceToPolyline(p, road.points) < reach then
			return false
		end
	end
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if StreetDresser.distanceToBlock(p, block) < GreeneryDresser.BLOCK_CLEAR then
				return false
			end
		end
	end
	for _, lot in lotsNear(p) do
		if GreeneryDresser.inLot(p, lot, GreeneryDresser.LOT_CLEAR) then
			return false
		end
	end
	if TownLayout.distanceToPolyline(p, TownLayout.RIVER.points) < TownLayout.RIVER.width / 2 + GreeneryDresser.RIVER_CLEAR then
		return false
	end
	if TownLayout.distanceToPolyline(p, TownLayout.RAIL.points) < TownLayout.RAIL.width / 2 + GreeneryDresser.RAIL_CLEAR then
		return false
	end
	for _, stop in TownLayout.BUS_STOPS do
		if (flat(stop.position) - flat(p)).Magnitude < GreeneryDresser.STOP_CLEAR then
			return false
		end
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		if (flat(rb.centre) - flat(p)).Magnitude < rb.radius + TownLayout.PAVEMENT_WIDTH + GreeneryDresser.ROAD_CLEAR then
			return false
		end
	end
	for i = 1, #TownLayout.PLOTS do
		if TownLayout.pointInPlot(p, i) then
			return false
		end
	end
	return true
end

-- Pure: the spots, in a stable order (seeded), at most MAX.
function GreeneryDresser.spots(): { Vector3 }
	local rng = Random.new(SEED)
	local out: { Vector3 } = {}
	local lotsByDistrict = TownFrontage.lotsByDistrict()
	local eligible = 0
	for _, district in TownLayout.DISTRICTS do
		if GreeneryDresser.DISTRICT_KINDS[district.kind] then
			eligible += 1
		end
	end
	local share = math.floor(GreeneryDresser.MAX / math.max(eligible, 1))
	for _, district in TownLayout.DISTRICTS do
		if not GreeneryDresser.DISTRICT_KINDS[district.kind] then
			continue
		end
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		-- v3: the district's area is its generated lots (DISTRICTS only keeps the specials)
		for _, lot in lotsByDistrict[district.name] or {} do
			local r = math.max(lot.size.X, lot.size.Z) / 2
			minX, maxX = math.min(minX, lot.centre.X - r), math.max(maxX, lot.centre.X + r)
			minZ, maxZ = math.min(minZ, lot.centre.Z - r), math.max(maxZ, lot.centre.Z + r)
		end
		for _, b in district.blocks do
			local r = math.max(b.size.X, b.size.Z) / 2
			minX, maxX = math.min(minX, b.centre.X - r), math.max(maxX, b.centre.X + r)
			minZ, maxZ = math.min(minZ, b.centre.Z - r), math.max(maxZ, b.centre.Z + r)
		end
		local step = GreeneryDresser.STEP
		local found: { Vector3 } = {}
		for x = minX, maxX, step do
			for z = minZ, maxZ, step do
				local p = Vector3.new(x + rng:NextNumber(-step / 3, step / 3), 0, z + rng:NextNumber(-step / 3, step / 3))
				local keep = rng:NextNumber() < GreeneryDresser.KEEP
				if keep and GreeneryDresser.clear(p) then
					table.insert(found, p)
				end
			end
		end
		-- thin evenly rather than stopping part-way across the district
		-- X117: big districts (Northfields) get a bigger share, up to double the cap
		local cap = math.clamp(math.floor(#found * 0.5), GreeneryDresser.MAX_PER_DISTRICT, GreeneryDresser.MAX_PER_DISTRICT * 2)
		-- v3: seven housing districts share MAX evenly, or the last ones listed get nothing
		local take = math.min(#found, cap, share)
		for k = 1, take do
			if #out >= GreeneryDresser.MAX then
				break
			end
			table.insert(out, found[math.floor((k - 1) * #found / take) + 1])
		end
	end
	return out
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, ball: boolean, collide: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if ball then
		p.Shape = Enum.PartType.Ball
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function occupied(p: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return #workspace:GetPartBoundsInBox(CFrame.new(p.X, 9, p.Z), Vector3.new(8, 16, 8), params) > 0
end

function GreeneryDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "greenery: no town"
	end
	local old = town:FindFirstChild("Greenery")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Greenery"
	root:SetAttribute("Decor", true)
	root.Parent = town
	local rng = Random.new(SEED + 1)
	local trees, shrubs, taken, parts = 0, 0, 0, 0
	for _, p in GreeneryDresser.spots() do
		if occupied(p, { root }) then
			taken += 1
			continue
		end
		local leaves = LEAVES[rng:NextInteger(1, #LEAVES)]
		local m = Instance.new("Model")
		if rng:NextNumber() < 0.7 then
			m.Name = "GreenTree"
			local h = rng:NextNumber(9, 13)
			part(m, "Trunk", Vector3.new(0.8, h, 0.8), CFrame.new(p.X, h / 2 - 0.2, p.Z), TRUNK, Enum.Material.Wood, false, true)
			local d = rng:NextNumber(7, 9.5)
			part(m, "Canopy", Vector3.one * d, CFrame.new(p.X, h + d / 2 - 2, p.Z), leaves, Enum.Material.Grass, true, false)
			parts += 2
			if rng:NextNumber() < 0.5 then
				local d2 = d * 0.7
				part(m, "CanopyTop", Vector3.one * d2, CFrame.new(p.X + d * 0.3, h + d - 2.2, p.Z + rng:NextNumber(-1, 1)), leaves:Lerp(Color3.new(1, 1, 0.8), 0.08), Enum.Material.Grass, true, false)
				parts += 1
			end
			trees += 1
		else
			m.Name = "Shrubs"
			for k = 1, 2 do
				local d = rng:NextNumber(2.6, 3.8)
				local off = Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)) * (k - 1.5) * 2
				part(m, "Shrub", Vector3.one * d, CFrame.new(p.X + off.X, d * 0.35, p.Z + off.Z), leaves:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.LeafyGrass, true, false)
			end
			parts += 2
			shrubs += 1
		end
		m.Parent = root
	end
	return ("greenery: %d trees, %d shrub clumps, %d spots taken, %d parts"):format(trees, shrubs, taken, parts)
end

return GreeneryDresser
