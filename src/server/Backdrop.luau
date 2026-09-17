--!strict
-- Town backdrop (backlog E9.2 / X8): the world shouldn't end at a cliff edge
-- past Rivermere's flat core. Scenery.setupTown fills a flat 5600 x 4400
-- grass block (half-extents 2800 x 2200) and TownBuilder carves the River
-- Lune and roads into it; this module extends the grass out to a wider ring,
-- scatters rolling hills and tree belts round that ring, continues the river
-- channel out to the ring edge, lays a patchwork of fields with hedgerows in
-- the band just past the town extent, and drops five distant wind turbines.
--
-- Nothing here is read by gameplay: it's pure dressing built once alongside
-- Scenery.setupTown() and TownBuilder.build(). It stays well clear of
-- Workspace.VerticalSlice (docs/SLICE_PLAN.md), the style-reference club
-- block at x 2880..3400, z 1820..2180.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownBuilder = require(script.Parent.TownBuilder)

local Backdrop = {}

local GROUND_Y = 0

-- Core fill from Scenery.setupTown (FillBlock 5600 x 4400 centred on the
-- origin): half-extents of the ground that already exists.
local CORE_MAX_X = 2800
local CORE_MAX_Z = 2200

-- Outer ring: how far this module's terrain reaches.
local RING_MAX_X = 4200
local RING_MAX_Z = 3600

-- Workspace.VerticalSlice (docs/SLICE_PLAN.md, HARD RULE): never build inside
-- this box, and keep the required 60-stud clear margin around it.
local VS_MIN_X, VS_MAX_X = 2880, 3400
local VS_MIN_Z, VS_MAX_Z = 1820, 2180
local VS_CLEARANCE = 60

local PLOT_CLEARANCE = 40
local ROAD_CLEARANCE = 20
local RIVER_CLEARANCE = 80
local EXTENT_EDGE_BAND = 150 -- fields/trees may sit this close inside the town extent

local FIELD_BAND = 600 -- how far past the extent the field patchwork reaches
local FIELD_PART_BUDGET = 180 -- fields + hedges together

local HILL_COUNT = 18
local HILL_MIN_DIST = 3000
local TREE_MAX = 150
local TURBINE_COUNT = 5

-- ------------------------------------------------------------- part helper

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	if props.Shape ~= nil then
		(p :: any).Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- ----------------------------------------------------------------- geometry

-- 2D (XZ) distance from p to the axis-aligned box [minX,maxX] x [minZ,maxZ]; 0 if inside.
local function boxDistance2D(p: Vector3, minX: number, maxX: number, minZ: number, maxZ: number): number
	local dx = math.max(minX - p.X, 0, p.X - maxX)
	local dz = math.max(minZ - p.Z, 0, p.Z - maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- Where a ray from `origin` along XZ-unit `dir` crosses the outer ring box.
local function ringEdgePoint(origin: Vector3, dir: Vector3): Vector3
	local tx = math.huge
	if dir.X > 1e-6 then
		tx = (RING_MAX_X - origin.X) / dir.X
	elseif dir.X < -1e-6 then
		tx = (-RING_MAX_X - origin.X) / dir.X
	end
	local tz = math.huge
	if dir.Z > 1e-6 then
		tz = (RING_MAX_Z - origin.Z) / dir.Z
	elseif dir.Z < -1e-6 then
		tz = (-RING_MAX_Z - origin.Z) / dir.Z
	end
	local t = math.min(tx, tz)
	return origin + dir * t
end

-- Unit XZ direction from b to a, i.e. continuing past a away from b.
local function riverEndDir(a: Vector3, b: Vector3): Vector3
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Unit
end

-- TownLayout.RIVER's points with both ends continued out to the ring edge, so
-- isClear and the terrain carve agree on where the channel actually reaches.
local function extendedRiverPoints(): { Vector3 }
	local points = TownLayout.RIVER.points
	local n = #points
	local startDir = riverEndDir(points[1], points[2])
	local endDir = riverEndDir(points[n], points[n - 1])
	local out = table.create(n + 2)
	table.insert(out, ringEdgePoint(points[1], startDir))
	for _, p in points do
		table.insert(out, p)
	end
	table.insert(out, ringEdgePoint(points[n], endDir))
	return out
end

-- --------------------------------------------------------------- isClear

-- True if a circle of `radius` centred at `p` (XZ only) avoids every plot,
-- every road, the (ring-extended) river, Workspace.VerticalSlice, and — when
-- `p` sits inside the town extent — is within EXTENT_EDGE_BAND of its
-- boundary (fields/trees may fringe the town but not sit deep inside it).
-- Pure: only reads TownLayout data and does Vector3/CFrame maths, no
-- workspace access, so it's safe to unit test without building anything.
function Backdrop.isClear(p: Vector3, radius: number): boolean
	for i = 1, #TownLayout.PLOTS do
		local cf = TownLayout.plotCFrame(i)
		local localP = cf:PointToObjectSpace(Vector3.new(p.X, cf.Position.Y, p.Z))
		local h = TownLayout.PLOT_SIZE / 2
		local dx = math.max(math.abs(localP.X) - h, 0)
		local dz = math.max(math.abs(localP.Z) - h, 0)
		if math.sqrt(dx * dx + dz * dz) < radius + PLOT_CLEARANCE then
			return false
		end
	end

	for _, road in TownLayout.ROADS do
		if TownLayout.distanceToPolyline(p, road.points) < radius + road.width / 2 + ROAD_CLEARANCE then
			return false
		end
	end

	if TownLayout.distanceToPolyline(p, extendedRiverPoints()) < radius + RIVER_CLEARANCE then
		return false
	end

	if boxDistance2D(p, VS_MIN_X, VS_MAX_X, VS_MIN_Z, VS_MAX_Z) < radius + VS_CLEARANCE then
		return false
	end

	local ext = TownLayout.EXTENT
	local insideExtent = p.X >= ext.minX and p.X <= ext.maxX and p.Z >= ext.minZ and p.Z <= ext.maxZ
	if insideExtent then
		local edgeDist = math.min(p.X - ext.minX, ext.maxX - p.X, p.Z - ext.minZ, ext.maxZ - p.Z)
		if edgeDist > EXTENT_EDGE_BAND then
			return false
		end
	end

	return true
end

-- ------------------------------------------------------------------ terrain

-- Grass ring beyond the core fill: north/south strips run the full extended
-- width (covering the corners), east/west strips fill only the gap between
-- them, so nothing overlaps and the existing core is never refilled.
local function buildTerrainRing()
	local terrain = workspace.Terrain
	local y = GROUND_Y - 10
	local sizeY = 16
	local function strip(minX: number, maxX: number, minZ: number, maxZ: number)
		local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
		terrain:FillBlock(CFrame.new(cx, y, cz), Vector3.new(maxX - minX, sizeY, maxZ - minZ), Enum.Material.LeafyGrass)
	end
	strip(-RING_MAX_X, RING_MAX_X, CORE_MAX_Z, RING_MAX_Z)
	strip(-RING_MAX_X, RING_MAX_X, -RING_MAX_Z, -CORE_MAX_Z)
	strip(CORE_MAX_X, RING_MAX_X, -CORE_MAX_Z, CORE_MAX_Z)
	strip(-RING_MAX_X, -CORE_MAX_X, -CORE_MAX_Z, CORE_MAX_Z)
end

-- The same three-phase carve TownBuilder.buildRiver uses (Mud banks, an Air
-- channel, then Water), exposed here as a local helper over an arbitrary
-- a -> b span so the ring extension matches the town reach exactly.
local RIVER_BANK = 12
local function carveRiverPhases(a: Vector3, b: Vector3)
	local terrain = workspace.Terrain
	local Y = TownBuilder.Y
	local width = TownLayout.RIVER.width
	local phases = {
		{ material = Enum.Material.Mud, width = width + RIVER_BANK * 2, bottom = Y.MUD_BOTTOM, top = Y.MUD_TOP },
		{ material = Enum.Material.Air, width = width, bottom = Y.RIVER_BED, top = Y.RIVER_AIR_TOP },
		{ material = Enum.Material.Water, width = width, bottom = Y.RIVER_BED, top = Y.WATER_TOP },
	}
	for _, phase in phases do
		local height = phase.top - phase.bottom
		local cy = (phase.top + phase.bottom) / 2
		local cf, length = TownBuilder.segmentCFrame(a, b, cy)
		if length > 0 then
			terrain:FillBlock(cf, Vector3.new(phase.width, height, length), phase.material)
		end
	end
end

-- Continues the river's first and last segment direction out to the ring
-- edge, so the channel TownBuilder already extended 400 studs doesn't just
-- dead-end in the middle of the new ring.
local function buildRiverExtension()
	local points = TownLayout.RIVER.points
	local n = #points
	local startDir = riverEndDir(points[1], points[2])
	local endDir = riverEndDir(points[n], points[n - 1])
	carveRiverPhases(points[1], ringEdgePoint(points[1], startDir))
	carveRiverPhases(points[n], ringEdgePoint(points[n], endDir))
end

export type Hill = { centre: Vector3, radius: number }

-- Rolling hills scattered round the outer ring, clear of VerticalSlice.
-- Returns the placed hills (ground-level centre + radius) so buildTrees can
-- scatter a few trees on their slopes afterwards.
local function buildHills(): { Hill }
	local terrain = workspace.Terrain
	local rng = Random.new(1884)
	local hills: { Hill } = {}
	local attempts = 0
	while #hills < HILL_COUNT and attempts < HILL_COUNT * 50 do
		attempts += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(HILL_MIN_DIST, math.min(RING_MAX_X, RING_MAX_Z) - 300)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist
		if math.abs(x) > RING_MAX_X - 150 or math.abs(z) > RING_MAX_Z - 150 then
			continue
		end
		if boxDistance2D(Vector3.new(x, 0, z), VS_MIN_X, VS_MAX_X, VS_MIN_Z, VS_MAX_Z) < 400 then
			continue
		end
		local radius = rng:NextNumber(250, 450)
		local peak = rng:NextNumber(40, 160)
		local centre = Vector3.new(x, GROUND_Y - radius + peak, z)
		terrain:FillBall(centre, radius, Enum.Material.LeafyGrass)
		if rng:NextNumber() < 0.35 then
			terrain:FillBall(centre + Vector3.new(0, 4, 0), radius * 0.4, Enum.Material.Rock)
			terrain:FillBall(centre, radius * 0.39, Enum.Material.LeafyGrass)
		end
		table.insert(hills, { centre = Vector3.new(x, GROUND_Y, z), radius = radius })
	end
	return hills
end

-- ------------------------------------------------------------------- fields

local FIELD_COLOURS = {
	Color3.fromRGB(96, 150, 70),
	Color3.fromRGB(120, 168, 72),
	Color3.fromRGB(150, 168, 90),
	Color3.fromRGB(198, 186, 110),
}
local HEDGE_COLOUR = Color3.fromRGB(42, 82, 40)

-- One flat field Part plus one hedge Part along its town-facing edge, tiled
-- along the band strips between the town extent and FIELD_BAND studs beyond
-- it. Skips any tile isClear rejects (river crossing, too near a plot/road,
-- or Workspace.VerticalSlice) rather than trying to route round it.
local function buildFields(parent: Instance): number
	local rng = Random.new(2604)
	local fieldsModel = Instance.new("Model")
	fieldsModel.Name = "Fields"
	fieldsModel.Parent = parent

	local ext = TownLayout.EXTENT
	local strips = {
		{ minX = ext.minX - FIELD_BAND, maxX = ext.maxX + FIELD_BAND, minZ = ext.maxZ, maxZ = ext.maxZ + FIELD_BAND, alongX = true },
		{ minX = ext.minX - FIELD_BAND, maxX = ext.maxX + FIELD_BAND, minZ = ext.minZ - FIELD_BAND, maxZ = ext.minZ, alongX = true },
		{ minX = ext.maxX, maxX = ext.maxX + FIELD_BAND, minZ = ext.minZ, maxZ = ext.maxZ, alongX = false },
		{ minX = ext.minX - FIELD_BAND, maxX = ext.minX, minZ = ext.minZ, maxZ = ext.maxZ, alongX = false },
	}

	local partsUsed = 0
	for _, strip in strips do
		local depth = if strip.alongX then strip.maxZ - strip.minZ else strip.maxX - strip.minX
		local length = if strip.alongX then strip.maxX - strip.minX else strip.maxZ - strip.minZ
		local pos = 0
		while pos < length and partsUsed <= FIELD_PART_BUDGET - 2 do
			local len = math.min(rng:NextNumber(200, 320), length - pos)
			if len < 60 then
				break
			end
			local thick = rng:NextNumber(depth * 0.5, depth * 0.85)

			local cx, cz, sx, sz = 0, 0, 0, 0
			if strip.alongX then
				cx = strip.minX + pos + len / 2
				cz = (strip.minZ + strip.maxZ) / 2
				sx, sz = len, thick
			else
				cz = strip.minZ + pos + len / 2
				cx = (strip.minX + strip.maxX) / 2
				sx, sz = thick, len
			end
			pos += len + rng:NextNumber(20, 40)

			local centre = Vector3.new(cx, 0, cz)
			local radius = math.sqrt((sx / 2) ^ 2 + (sz / 2) ^ 2)
			if Backdrop.isClear(centre, radius) then
				part({
					Name = "Field",
					Size = Vector3.new(sx, 0.2, sz),
					CFrame = CFrame.new(cx, 0.15, cz),
					Color = FIELD_COLOURS[rng:NextInteger(1, #FIELD_COLOURS)],
					Material = Enum.Material.SmoothPlastic,
					CastShadow = false,
					Parent = fieldsModel,
				})
				partsUsed += 1

				local hedgeSize, hedgeCFrame = Vector3.new(), CFrame.new()
				if strip.alongX then
					local edgeZ = if strip.minZ < 0 then cz + sz / 2 else cz - sz / 2
					hedgeSize = Vector3.new(sx, 4, 3)
					hedgeCFrame = CFrame.new(cx, 2, edgeZ)
				else
					local edgeX = if strip.minX < 0 then cx + sx / 2 else cx - sx / 2
					hedgeSize = Vector3.new(3, 4, sz)
					hedgeCFrame = CFrame.new(edgeX, 2, cz)
				end
				part({
					Name = "Hedge",
					Size = hedgeSize,
					CFrame = hedgeCFrame,
					Color = HEDGE_COLOUR,
					Material = Enum.Material.Grass,
					CastShadow = false,
					Parent = fieldsModel,
				})
				partsUsed += 1
			end
		end
	end
	return partsUsed
end

-- -------------------------------------------------------------------- trees

local function treePart(parent: Instance, pos: Vector3, rng: Random)
	local scale = rng:NextNumber(0.7, 1.3)
	local trunkH = 8 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH, 1.2 * scale, 1.2 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(90, 68, 45),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local green = Color3.fromRGB(60 + rng:NextInteger(-10, 15), 115 + rng:NextInteger(-15, 20), 50 + rng:NextInteger(-10, 10))
	part({
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (9 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH + 2.5 * scale, 0)),
		Color = green,
		Material = Enum.Material.Grass,
		CastShadow = false,
		Parent = parent,
	})
	part({
		Name = "CanopyTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (6 * scale),
		CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), trunkH + 6 * scale, rng:NextNumber(-2, 2))),
		Color = green:Lerp(Color3.new(1, 1, 1), 0.1),
		Material = Enum.Material.Grass,
		CastShadow = false,
		Parent = parent,
	})
end

-- Low-poly tree clumps along the town extent edge and on the hill slopes
-- buildHills placed, capped at TREE_MAX (each tree is 3 parts: trunk + 2
-- crowns). Individual trees still go through isClear so a clump doesn't drop
-- a tree on a road or inside a plot.
local function buildTrees(parent: Instance, hills: { Hill }): number
	local rng = Random.new(4471)
	local treesModel = Instance.new("Model")
	treesModel.Name = "Trees"
	treesModel.Parent = parent
	local count = 0

	local function tryPlace(x: number, z: number)
		if count >= TREE_MAX then
			return
		end
		local p = Vector3.new(x, GROUND_Y, z)
		if Backdrop.isClear(p, 6) then
			treePart(treesModel, p, rng)
			count += 1
		end
	end

	local ext = TownLayout.EXTENT
	for _ = 1, 24 do
		if count >= TREE_MAX then
			break
		end
		local side = rng:NextInteger(1, 4)
		local cx, cz = 0, 0
		if side == 1 then
			cx, cz = rng:NextNumber(ext.minX, ext.maxX), ext.maxZ + rng:NextNumber(20, 140)
		elseif side == 2 then
			cx, cz = rng:NextNumber(ext.minX, ext.maxX), ext.minZ - rng:NextNumber(20, 140)
		elseif side == 3 then
			cx, cz = ext.maxX + rng:NextNumber(20, 140), rng:NextNumber(ext.minZ, ext.maxZ)
		else
			cx, cz = ext.minX - rng:NextNumber(20, 140), rng:NextNumber(ext.minZ, ext.maxZ)
		end
		for _ = 1, rng:NextInteger(3, 6) do
			tryPlace(cx + rng:NextNumber(-40, 40), cz + rng:NextNumber(-40, 40))
		end
	end

	for _, hill in hills do
		if count >= TREE_MAX then
			break
		end
		for _ = 1, rng:NextInteger(2, 5) do
			local angle = rng:NextNumber(0, math.pi * 2)
			local r = hill.radius * rng:NextNumber(0.6, 0.95)
			tryPlace(hill.centre.X + math.cos(angle) * r, hill.centre.Z + math.sin(angle) * r)
		end
	end

	return count
end

-- ----------------------------------------------------------------- turbines

-- Five turbines on their own small terrain mounds, far out on the north /
-- north-east arc (angle measured from +X towards +Z, so -90 deg is due
-- north). No scripts: a client can read the Spin attribute later.
local function buildTurbines(parent: Instance): number
	local rng = Random.new(9001)
	local terrain = workspace.Terrain
	local turbinesModel = Instance.new("Model")
	turbinesModel.Name = "Turbines"
	turbinesModel.Parent = parent

	for i = 1, TURBINE_COUNT do
		local t = (i - 1) / math.max(TURBINE_COUNT - 1, 1)
		local angleDeg = -110 + t * 75 + rng:NextNumber(-6, 6)
		local angle = math.rad(angleDeg)
		local dist = rng:NextNumber(3400, 4100)
		local x, z = math.cos(angle) * dist, math.sin(angle) * dist

		local moundRadius = 180
		local moundPeak = rng:NextNumber(50, 90)
		terrain:FillBall(Vector3.new(x, moundPeak - moundRadius, z), moundRadius, Enum.Material.LeafyGrass)
		local base = Vector3.new(x, moundPeak, z)

		local turbine = Instance.new("Model")
		turbine.Name = "WindTurbine"
		turbine:SetAttribute("Spin", true)
		-- landmark seen from across town: never stream out (a few parts each)
		turbine.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

		local towerH = 120
		part({
			Name = "Tower",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(towerH, 4, 4),
			CFrame = CFrame.new(base + Vector3.new(0, towerH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromRGB(232, 232, 232),
			Material = Enum.Material.SmoothPlastic,
			Parent = turbine,
		})
		local nacellePos = base + Vector3.new(0, towerH + 3, 0)
		part({
			Name = "Nacelle",
			Size = Vector3.new(14, 6, 6),
			CFrame = CFrame.new(nacellePos),
			Color = Color3.fromRGB(210, 210, 210),
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
			Parent = turbine,
		})
		local hubCFrame = CFrame.new(nacellePos + Vector3.new(8, 0, 0))
		for b = 1, 3 do
			local bladeCF = hubCFrame * CFrame.Angles(0, 0, math.rad(120 * (b - 1))) * CFrame.new(0, 30, 0)
			part({
				Name = "Blade",
				Size = Vector3.new(2, 60, 1),
				CFrame = bladeCF,
				Color = Color3.fromRGB(240, 240, 240),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
				Parent = turbine,
			})
		end
		turbine.Parent = turbinesModel
	end
	return TURBINE_COUNT
end

-- ---------------------------------------------------------------------- API

function Backdrop.build(): Folder
	local existing = workspace:FindFirstChild("Backdrop")
	if existing then
		existing:Destroy()
	end

	buildTerrainRing() -- terrain edits are idempotent, like TownBuilder.buildRiver
	buildRiverExtension()

	local backdrop = Instance.new("Folder")
	backdrop.Name = "Backdrop"
	local hills = buildHills()
	buildFields(backdrop)
	buildTrees(backdrop, hills)
	buildTurbines(backdrop)
	backdrop.Parent = workspace
	return backdrop
end

return Backdrop
