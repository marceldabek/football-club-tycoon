--!strict
-- Town backdrop (backlog E9.2 / X8): the world shouldn't end at a cliff edge
-- past Rivermere's flat core. Scenery.setupTown fills a flat 5600 x 4400
-- grass block (half-extents 2800 x 2200) and TownBuilder carves the River
-- Lune and roads into it; this module extends the grass out to a wider ring,
-- scatters rolling hills and tree belts round that ring, continues the river
-- channel out to the ring edge, lays a patchwork of dry-stone-walled fields in
-- the band just past the town extent, and drops five distant wind turbines.
--
-- Nothing here is read by gameplay: it's pure dressing built once alongside
-- Scenery.setupTown() and TownBuilder.build(). It stays well clear of
-- Workspace.VerticalSlice (docs/SLICE_PLAN.md), the style-reference club
-- block at x 2880..3400, z 1820..2180.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownBuilder = require(script.Parent.TownBuilder)
local TreeKit = require(script.Parent.TreeKit)

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
-- X16: fields + walls together (5 parts a field: slab + four walls). The
-- old cap was 180 at 2 parts a field; this cap plus HEDGEROW_TREE_BUDGET keeps
-- the increase at or under 400 parts.
local FIELD_PART_BUDGET = 360
local HEDGEROW_TREE_BUDGET = 220

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
-- `plotClearance` overrides PLOT_CLEARANCE (the near fields sit closer).
-- Pure: only reads TownLayout data and does Vector3/CFrame maths, no
-- workspace access, so it's safe to unit test without building anything.
function Backdrop.isClear(p: Vector3, radius: number, plotClearance: number?): boolean
	for i = 1, #TownLayout.PLOTS do
		local cf = TownLayout.plotCFrame(i)
		local localP = cf:PointToObjectSpace(Vector3.new(p.X, cf.Position.Y, p.Z))
		local h = TownLayout.PLOT_SIZE / 2
		local dx = math.max(math.abs(localP.X) - h, 0)
		local dz = math.max(math.abs(localP.Z) - h, 0)
		if math.sqrt(dx * dx + dz * dz) < radius + (plotClearance or PLOT_CLEARANCE) then
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

-- Real terrain-like materials (no Texture instances): pasture greens on
-- Grass / LeafyGrass, stubble and ploughed earth on Ground.
export type FieldStyle = { colour: Color3, material: Enum.Material }
Backdrop.FIELD_STYLES = {
	{ colour = Color3.fromRGB(92, 142, 66), material = Enum.Material.Grass },
	{ colour = Color3.fromRGB(112, 158, 70), material = Enum.Material.LeafyGrass },
	{ colour = Color3.fromRGB(130, 166, 84), material = Enum.Material.Grass },
	{ colour = Color3.fromRGB(82, 126, 58), material = Enum.Material.LeafyGrass },
	{ colour = Color3.fromRGB(104, 150, 62), material = Enum.Material.Grass },
	{ colour = Color3.fromRGB(176, 164, 100), material = Enum.Material.Ground },
	{ colour = Color3.fromRGB(128, 104, 74), material = Enum.Material.Ground },
} :: { FieldStyle }
-- Field boundaries are dry stone walls (Marcel, 2026-09-21), not hedges. The
-- stones come from the "DryStoneWall" MaterialVariant in MaterialService (it
-- lives in the place file); without it the part shows plain Cobblestone.
-- The variant's texture is dark, so the tint stays near white (StudsPerTile 7).
local WALL_COLOUR = Color3.fromRGB(240, 236, 224)
local WALL_VARIANT = "DryStoneWall"
local HEDGE_THICKNESS = 2.4
local HEDGE_MIN_H, HEDGE_MAX_H = 4.2, 5.2

export type HedgeBox = { centre: Vector3, size: Vector3, side: string }

-- Pure: the four hedge footprints ringing a field of size sx x sz centred on
-- (cx, cz), each straddling its field edge. North/south ("+Z"/"-Z") hedges
-- run the full width plus the corners; east/west ("+X"/"-X") ones fill the
-- gap between them and poke `overlap` into each so their end faces are never
-- flush with a north/south hedge's side face. size.Y is 0 (the builder picks
-- the height).
function Backdrop.hedgeBoxes(cx: number, cz: number, sx: number, sz: number, thickness: number, overlap: number): { HedgeBox }
	local out: { HedgeBox } = {}
	for _, dir in { 1, -1 } do
		table.insert(out, {
			centre = Vector3.new(cx, 0, cz + dir * sz / 2),
			size = Vector3.new(sx + thickness, 0, thickness),
			side = if dir > 0 then "+Z" else "-Z",
		})
	end
	for _, dir in { 1, -1 } do
		table.insert(out, {
			centre = Vector3.new(cx + dir * sx / 2, 0, cz),
			size = Vector3.new(thickness, 0, math.max(sz - thickness + overlap * 2, 0.2)),
			side = if dir > 0 then "+X" else "-X",
		})
	end
	return out
end

-- Cheap hedgerow tree: trunk + one crown, sometimes a second. 2 or 3 parts.
local function hedgerowTree(parent: Instance, pos: Vector3, rng: Random): number
	local scale = rng:NextNumber(0.8, 1.4)
	local trunkH = 7 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH + 0.5, 1.1 * scale, 1.1 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, (trunkH - 0.5) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(88, 66, 44),
		Material = Enum.Material.Wood,
		CastShadow = false,
		Parent = parent,
	})
	local green = Color3.fromRGB(54 + rng:NextInteger(-8, 16), 100 + rng:NextInteger(-15, 25), 44 + rng:NextInteger(-8, 10))
	part({
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (10 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH + 2.5 * scale, 0)),
		Color = green,
		Material = Enum.Material.LeafyGrass,
		Parent = parent,
	})
	if rng:NextNumber() < 0.5 then
		local a = rng:NextNumber(0, math.pi * 2)
		part({
			Name = "CanopyTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (6.5 * scale),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 2.5 * scale, trunkH + 6 * scale, math.sin(a) * 2.5 * scale)),
			Color = green:Lerp(Color3.fromRGB(140, 170, 80), 0.15),
			Material = Enum.Material.LeafyGrass,
			CastShadow = false,
			Parent = parent,
		})
		return 3
	end
	return 2
end

-- One field slab ringed by its four dry stone walls (5 parts). Returns the
-- wall footprints so callers can stand trees along them.
local function walledField(parent: Instance, cx: number, cz: number, sx: number, sz: number, style: FieldStyle, styleRng: Random): { HedgeBox }
	local tint = styleRng:NextNumber(-0.06, 0.06)
	part({
		Name = "Field",
		Size = Vector3.new(sx, 0.2, sz),
		CFrame = CFrame.new(cx, 0.15, cz),
		Color = if tint > 0 then style.colour:Lerp(Color3.new(1, 1, 0.8), tint) else style.colour:Lerp(Color3.new(0, 0, 0), -tint),
		Material = style.material,
		CastShadow = false,
		Parent = parent,
	})

	-- east/west walls a little taller and deeper than north/south, so no two
	-- meeting walls share a top or bottom plane
	local baseH = styleRng:NextNumber(HEDGE_MIN_H, HEDGE_MAX_H - 0.3)
	local hedges = Backdrop.hedgeBoxes(cx, cz, sx, sz, HEDGE_THICKNESS, 0.1)
	for _, hedge in hedges do
		local eastWest = hedge.side == "+X" or hedge.side == "-X"
		local bottom = if eastWest then -0.6 else -0.5
		local top = if eastWest then baseH + 0.3 else baseH
		part({
			Name = "FieldWall",
			Size = Vector3.new(hedge.size.X, top - bottom, hedge.size.Z),
			CFrame = CFrame.new(hedge.centre.X, (top + bottom) / 2, hedge.centre.Z),
			Color = WALL_COLOUR:Lerp(Color3.fromRGB(212, 204, 186), styleRng:NextNumber(0, 0.5)),
			Material = Enum.Material.Cobblestone,
			MaterialVariant = WALL_VARIANT,
			CastShadow = false,
			Parent = parent,
		})
	end
	return hedges
end

-- One flat field Part ringed by four hedges, tiled along the band strips
-- between the town extent and FIELD_BAND studs beyond it, with clumps of
-- trees along the hedgerows. Skips any tile isClear rejects (river crossing,
-- too near a plot/road, or Workspace.VerticalSlice) rather than trying to
-- route round it. `rng` keeps the original field layout draws; tints, hedge
-- heights and trees come from a second generator so the layout is unchanged.
local function buildFields(parent: Instance): number
	local rng = Random.new(2604)
	local styleRng = Random.new(2605)
	local fieldsModel = Instance.new("Model")
	fieldsModel.Name = "Fields"
	fieldsModel.Parent = parent
	local hedgerowModel = Instance.new("Model")
	hedgerowModel.Name = "HedgerowTrees"
	hedgerowModel.Parent = parent
	local treeParts = 0

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
		while pos < length and partsUsed <= FIELD_PART_BUDGET - 5 do
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
				local style = Backdrop.FIELD_STYLES[rng:NextInteger(1, #Backdrop.FIELD_STYLES)]
				local hedges = walledField(fieldsModel, cx, cz, sx, sz, style, styleRng)
				partsUsed += 5

				-- one to three tree clumps along random hedgerows
				for _ = 1, styleRng:NextInteger(1, 3) do
					if treeParts > HEDGEROW_TREE_BUDGET - 3 then
						break
					end
					local hedge = hedges[styleRng:NextInteger(1, #hedges)]
					local longX = hedge.size.X > hedge.size.Z
					local run = if longX then hedge.size.X else hedge.size.Z
					local along = styleRng:NextNumber(-0.4, 0.4) * run
					for _ = 1, styleRng:NextInteger(2, 3) do
						if treeParts > HEDGEROW_TREE_BUDGET - 3 then
							break
						end
						local offA = along + styleRng:NextNumber(-12, 12)
						local offB = styleRng:NextNumber(-2.5, 2.5)
						local p = if longX
							then Vector3.new(hedge.centre.X + offA, GROUND_Y, hedge.centre.Z + offB)
							else Vector3.new(hedge.centre.X + offB, GROUND_Y, hedge.centre.Z + offA)
						if Backdrop.isClear(p, 6) then
							treeParts += hedgerowTree(hedgerowModel, p, styleRng)
						end
					end
				end
			end
		end
	end
	return partsUsed + treeParts
end

-- ------------------------------------------------------------- near fields

-- Marcel, 2026-09-21: the patchwork starts too far behind Plot 1, so a row of
-- smaller walled fields fills the grass between the plot's back fence and the
-- far fields, with a few trees in the lanes between them. Plot 1 backs onto
-- the south edge of the extent (yaw 270, entrance north), so "behind" is +Z.
local NEAR_PLOT = 1
local NEAR_PLOT_GAP = 14 -- plot boundary to the first wall
-- The far south fields' nearest possible wall face is ext.maxZ + 43.8 (strip
-- centre 300 out, at most 0.85 x 600 deep); stop short of it.
local NEAR_BACK_PAST_EXTENT = 36
local NEAR_HALF_RUN = 800 -- how far the row runs either side of the plot centre
local NEAR_ROAD_CLEARANCE = 55 -- pavement + a house + its back garden
local NEAR_TREE_BUDGET = 22

export type FieldRect = { cx: number, cz: number, sx: number, sz: number }

-- A rectangle is clear when points every ~40 studs round its edge (and its
-- centre) avoid the plots, the river and VerticalSlice, and keep a house's
-- depth away from every road.
local function nearRectClear(rect: FieldRect): boolean
	local function pointClear(x: number, z: number): boolean
		local p = Vector3.new(x, 0, z)
		if not Backdrop.isClear(p, 0, NEAR_PLOT_GAP - 2) then
			return false
		end
		for _, road in TownLayout.ROADS do
			if TownLayout.distanceToPolyline(p, road.points) < road.width / 2 + NEAR_ROAD_CLEARANCE then
				return false
			end
		end
		return true
	end
	if not pointClear(rect.cx, rect.cz) then
		return false
	end
	local nx, nz = math.max(math.ceil(rect.sx / 40), 1), math.max(math.ceil(rect.sz / 40), 1)
	for i = 0, nx do
		local x = rect.cx - rect.sx / 2 + rect.sx * i / nx
		if not (pointClear(x, rect.cz - rect.sz / 2) and pointClear(x, rect.cz + rect.sz / 2)) then
			return false
		end
	end
	for j = 0, nz do
		local z = rect.cz - rect.sz / 2 + rect.sz * j / nz
		if not (pointClear(rect.cx - rect.sx / 2, z) and pointClear(rect.cx + rect.sx / 2, z)) then
			return false
		end
	end
	return true
end

-- Pure: the row of field rectangles behind NEAR_PLOT, west to east, with a
-- lane of 16..28 studs between neighbours. A slot that isn't clear is stepped
-- past 40 studs at a time rather than dropping the whole field.
function Backdrop.nearFieldRects(): { FieldRect }
	local rng = Random.new(2611)
	local plot = TownLayout.PLOTS[NEAR_PLOT]
	local minZ = plot.centre.Z + TownLayout.PLOT_SIZE / 2 + NEAR_PLOT_GAP
	local maxZ = TownLayout.EXTENT.maxZ + NEAR_BACK_PAST_EXTENT
	local out: { FieldRect } = {}
	local x = plot.centre.X - NEAR_HALF_RUN
	local endX = plot.centre.X + NEAR_HALF_RUN
	while x < endX - 90 do
		local sx = math.min(rng:NextNumber(130, 210), endX - x)
		local front = minZ + rng:NextNumber(0, 18) -- a ragged front line, one straight back line
		local rect = { cx = x + sx / 2, cz = (front + maxZ) / 2, sx = sx, sz = maxZ - front }
		if nearRectClear(rect) then
			table.insert(out, rect)
			x += sx + rng:NextNumber(16, 28)
		else
			x += 40
		end
	end
	return out
end

local function nearTree(parent: Instance, pos: Vector3, rng: Random): number
	local oak = TreeKit.tree(parent, pos, { height = rng:NextNumber(20, 30), rng = rng, name = "FieldTree" })
	if oak then
		return 1
	end
	hedgerowTree(parent, pos, rng)
	return 1
end

local function buildNearFields(parent: Instance): number
	local rng = Random.new(2612)
	local model = Instance.new("Model")
	model.Name = "NearFields"
	model.Parent = parent
	local treesModel = Instance.new("Model")
	treesModel.Name = "NearFieldTrees"
	treesModel.Parent = parent

	local rects = Backdrop.nearFieldRects()
	local trees = 0
	local function tryTree(x: number, z: number)
		local p = Vector3.new(x, GROUND_Y, z)
		if trees < NEAR_TREE_BUDGET and Backdrop.isClear(p, 4, NEAR_PLOT_GAP - 8) then
			trees += nearTree(treesModel, p, rng)
		end
	end

	for i, rect in rects do
		local style = Backdrop.FIELD_STYLES[rng:NextInteger(1, #Backdrop.FIELD_STYLES)]
		walledField(model, rect.cx, rect.cz, rect.sx, rect.sz, style, rng)

		-- trees in the lane between this field and the next one along
		local nextRect = rects[i + 1]
		if nextRect then
			local laneMin = rect.cx + rect.sx / 2
			local laneMax = nextRect.cx - nextRect.sx / 2
			if laneMax - laneMin < 60 then -- a real lane, not a stepped-over gap
				local laneX = (laneMin + laneMax) / 2
				for _ = 1, rng:NextInteger(1, 3) do
					tryTree(laneX + rng:NextNumber(-3, 3), rect.cz + rng:NextNumber(-0.45, 0.45) * rect.sz)
				end
			end
		end
		-- and now and then one in the lane along the back, before the far fields
		if rng:NextNumber() < 0.5 then
			tryTree(rect.cx + rng:NextNumber(-0.4, 0.4) * rect.sx, rect.cz + rect.sz / 2 + rng:NextNumber(7, 12))
		end
	end
	return #rects
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
	buildNearFields(backdrop)
	buildTrees(backdrop, hills)
	buildTurbines(backdrop)
	backdrop.Parent = workspace
	return backdrop
end

return Backdrop
