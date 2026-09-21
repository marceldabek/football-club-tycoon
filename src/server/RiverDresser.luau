--!strict
-- The River Lune waterfront (backlog E6.1). Reference:
-- assets/references/RivermereRiverside.png — a paved promenade on a stone quay
-- along the north bank, black railings at the water's edge, bollards, planters
-- of flowers, benches and lamps, and small boats moored at pontoons.
--
-- TownBuilder carves the river into terrain: water width 90 (surface renders
-- at about y -2), 12-stud mud banks each side. This module walks the north
-- bank from PROMENADE_X0 to PROMENADE_X1, skipping road bridge ends, and
-- builds under workspace.Town.Riverside:
--   Quay        stone kerb/wall pieces on the water's edge, top at y 0.6
--   Promenade   paving strips behind the quay, top at y 0.35
--   Railings    black top rail + posts along the quay
--   Furniture   benches, planters, lamps every FURNITURE_SPACING
--   Moorings    wooden pontoons out on the water + kit boats (the marina reach)
-- Budget: roughly 6 parts per 10 studs of promenade + 1-2 MeshParts a boat.
--
-- The TownLayout "marina" block interrupts the promenade (isClear treats it
-- like any other block); MarinaDresser builds the marina quay in that gap
-- (RiverDresser.marinaSpan) and the river moorings here stay clear of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)
local V3Perf = require(script.Parent.V3Perf)
local Planting = require(script.Parent.Planting)
local ForecourtDresser = require(script.Parent.ForecourtDresser)

local RiverDresser = {}

local PROMENADE_X0, PROMENADE_X1 = -220, 1200
local EDGE = TownLayout.RIVER.width / 2 -- water's edge from the centreline
local QUAY_W = 2.5
local PROM_W = 12
local QUAY_TOP = 0.6
local PROM_TOP = 0.35
local RUN_STEP = 10
local RAIL_H = 3.4
local POST_STEP = 8
local FURNITURE_SPACING = 64
local BRIDGE_CLEAR = 30 -- no promenade this close to a bridge centreline (the deck lands there)
local BLOCK_CLEAR = 3 -- promenade stops short of buildings and roads

local STONE = Color3.fromRGB(196, 184, 160)
local PAVING = Color3.fromRGB(206, 192, 170)
local IRON = Color3.fromRGB(22, 22, 24)
local TownCrest = require(game:GetService("ReplicatedStorage").Shared.TownCrest)
local SquareDresser = require(script.Parent.SquareDresser)

local TIMBER = Color3.fromRGB(120, 92, 64)

local MARINA_X0, MARINA_X1 = 780, 1120 -- moorings along this reach of the north bank
local MARINA_USE = "marina"
local MOORING_MARINA_CLEAR = 30 -- no river moorings this close (along x) to the marina quay

-- shared with MarinaDresser
RiverDresser.PROMENADE_X0 = PROMENADE_X0
RiverDresser.PROMENADE_X1 = PROMENADE_X1
RiverDresser.EDGE = EDGE
RiverDresser.QUAY_W = QUAY_W
RiverDresser.PROM_W = PROM_W
RiverDresser.QUAY_TOP = QUAY_TOP
RiverDresser.PROM_TOP = PROM_TOP
RiverDresser.RAIL_H = RAIL_H
RiverDresser.RUN_STEP = RUN_STEP
RiverDresser.MARINA_USE = MARINA_USE
RiverDresser.STONE = STONE
RiverDresser.PAVING = PAVING
RiverDresser.IRON = IRON
RiverDresser.TIMBER = TIMBER

local function part(props: { [string]: any }, className: string?): BasePart
	local p = (Instance.new :: any)(className or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Pure: the north-bank edge as a list of short straight runs
-- { a, b, normal } where normal points from the water towards the land.
-- North is -Z; the river runs west to east, so the land normal is the
-- segment's left-hand perpendicular (-dz, dx) flipped to point to -Z.
export type Run = { a: Vector3, b: Vector3, normal: Vector3 }

function RiverDresser.bankRuns(x0: number, x1: number, step: number): { Run }
	local points = TownLayout.RIVER.points
	local out: { Run } = {}
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		local flat = Vector3.new(q.X - p.X, 0, q.Z - p.Z)
		local length = flat.Magnitude
		if length < 1e-6 then
			continue
		end
		local dir = flat / length
		local normal = Vector3.new(dir.Z, 0, -dir.X) -- left of downstream
		if normal.Z > 0 then
			normal = -normal
		end
		local n = math.max(1, math.ceil(length / step))
		for k = 0, n - 1 do
			local a = p:Lerp(q, k / n) + normal * EDGE
			local b = p:Lerp(q, (k + 1) / n) + normal * EDGE
			local midX = (a.X + b.X) / 2
			if midX >= x0 and midX <= x1 then
				table.insert(out, { a = Vector3.new(a.X, 0, a.Z), b = Vector3.new(b.X, 0, b.Z), normal = normal })
			end
		end
	end
	return out
end

-- Pure: is a point on the promenade clear of bridges, roads and buildings?
-- `radius` (default 0) widens every clearance, for things with a footprint
-- (a tree crown); blocks whose use is `skipUse` are ignored.
function RiverDresser.isClear(p: Vector3, radius: number?, skipUse: string?): boolean
	local r = radius or 0
	for _, bridge in TownLayout.BRIDGES do
		if TownLayout.segmentDistance(p, bridge.from, bridge.to) < bridge.width / 2 + BRIDGE_CLEAR + r then
			return false
		end
	end
	for _, road in TownLayout.ROADS do
		if TownLayout.distanceToPolyline(p, road.points) < road.width / 2 + TownLayout.PAVEMENT_WIDTH + BLOCK_CLEAR + r then
			return false
		end
	end
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if skipUse ~= nil and block.use == skipUse then
				continue
			end
			local c, s = block.centre, block.size
			if math.abs(p.X - c.X) < s.X / 2 + BLOCK_CLEAR + r and math.abs(p.Z - c.Z) < s.Z / 2 + BLOCK_CLEAR + r then
				return false
			end
		end
	end
	return true
end

-- The point RiverDresser.build tests to decide whether a run gets promenade.
function RiverDresser.promenadeProbe(run: Run): Vector3
	return (run.a + run.b) / 2 + run.normal * (QUAY_W + PROM_W / 2)
end

-- Pure: the stretch of north bank where the promenade stops only because of
-- the marina block, merged into one straight run (a -> b along the bank,
-- normal towards the land). nil when the layout has no marina on the bank.
-- Only the first contiguous group of such runs on one straight river segment
-- is used.
function RiverDresser.marinaSpan(): Run?
	local first: Run? = nil
	local last: Run? = nil
	for _, run in RiverDresser.bankRuns(PROMENADE_X0, PROMENADE_X1, RUN_STEP) do
		local probe = RiverDresser.promenadeProbe(run)
		local marinaOnly = not RiverDresser.isClear(probe) and RiverDresser.isClear(probe, 0, MARINA_USE)
		if marinaOnly then
			if first == nil then
				first = run
				last = run
			elseif last ~= nil and (last.b - run.a).Magnitude < 0.01 and (last.normal - run.normal).Magnitude < 1e-4 then
				last = run
			else
				break
			end
		elseif first ~= nil then
			break
		end
	end
	if first == nil or last == nil then
		return nil
	end
	return { a = first.a, b = last.b, normal = first.normal }
end

-- A straight piece of `width` x `height` running a -> b, offset `lateral`
-- towards the land, with its top at `top`.
local function strip(parent: Instance, name: string, run: Run, lateral: number, width: number, bottom: number, top: number, colour: Color3, material: Enum.Material)
	local a = run.a + run.normal * lateral
	local b = run.b + run.normal * lateral
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	part({
		Name = name,
		Size = Vector3.new(width, top - bottom, length + 0.05),
		CFrame = CFrame.lookAt(Vector3.new(mid.X, (top + bottom) / 2, mid.Z), Vector3.new(b.X, (top + bottom) / 2, b.Z)),
		Color = colour,
		Material = material,
		CastShadow = false,
		Parent = parent,
	})
end

-- X65: the river's Mud bank voxels (4-stud grid, filled to y -2) render up to
-- ~1.4 where the channel carve leaves them at occupancy 0.7, poking through
-- the promenade paving (top 0.35). Emptying the top 1.8 studs of the ground
-- layer under the quay and promenade (plus 1.5 each side) drops that surface
-- to about -1.6, under the paving.
local function clearBank(run: Run)
	local lateral = (QUAY_W + PROM_W) / 2
	local a = run.a + run.normal * lateral
	local b = run.b + run.normal * lateral
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	if length < 1e-3 then
		return
	end
	local cf = CFrame.lookAt(Vector3.new(mid.X, -0.9, mid.Z), Vector3.new(b.X, -0.9, b.Z))
	workspace.Terrain:FillBlock(cf, Vector3.new(QUAY_W + PROM_W + 3, 1.8, length + 0.5), Enum.Material.Air)
end

-- X66: a black heritage lamp like RivermereRiverside.png: lantern on top of
-- the post with a cap and finial, and (when `basket`) a hanging flower basket
-- on a bracket towards local -Z (the promenade). 7 parts, 9 with the basket;
-- the kit LampVictorian is 36; without a basket, a navy banner on an arm (+2).
-- Ground at `cf`.
local BASKET_FLOWERS = { Color3.fromRGB(214, 80, 130), Color3.fromRGB(150, 110, 190), Color3.fromRGB(230, 120, 70) }
function RiverDresser.heritageLamp(cf: CFrame, parent: Instance, basket: boolean, rng: Random): Model
	local m = Instance.new("Model")
	m.Name = "HeritageLamp"
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y
	part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 1.3, 1.3), CFrame = cf * CFrame.new(0, 0.8, 0) * upright, Color = IRON, Parent = m })
	local post = part({ Name = "Post", Shape = Enum.PartType.Cylinder, Size = Vector3.new(11, 0.45, 0.45), CFrame = cf * CFrame.new(0, 6.7, 0) * upright, Color = IRON, Parent = m })
	m.PrimaryPart = post
	-- collar 12.0 .. 12.4 over the post top (12.2); lantern 12.35 .. 14.15 sits 0.05 into it
	part({ Name = "Collar", Size = Vector3.new(0.8, 0.4, 0.8), CFrame = cf * CFrame.new(0, 12.2, 0), Color = IRON, CastShadow = false, Parent = m })
	part({ Name = "Lantern", Size = Vector3.new(1.3, 1.8, 1.3), CFrame = cf * CFrame.new(0, 13.25, 0), Color = IRON, CastShadow = false, Parent = m })
	part({ Name = "Glass", Size = Vector3.new(1.38, 1.2, 1.38), CFrame = cf * CFrame.new(0, 13.25, 0), Color = Color3.fromRGB(255, 226, 160), Material = Enum.Material.Neon, CastShadow = false, Parent = m })
	part({ Name = "Cap", Size = Vector3.new(1.7, 0.3, 1.7), CFrame = cf * CFrame.new(0, 14.25, 0), Color = IRON, CastShadow = false, Parent = m })
	part({ Name = "Finial", Size = Vector3.new(0.3, 0.6, 0.3), CFrame = cf * CFrame.new(0, 14.65, 0), Color = IRON, CastShadow = false, Parent = m })
	if not basket then
		-- X66: a navy town banner on the lamps without a basket, over the river side
		part({ Name = "BannerArm", Size = Vector3.new(0.25, 0.25, 2.6), CFrame = cf * CFrame.new(0, 11.4, 1.25), Color = IRON, CastShadow = false, Parent = m })
		local banner = part({ Name = "Banner", Size = Vector3.new(0.12, 4.6, 2.2), CFrame = cf * CFrame.new(0, 11.4 - 0.15 - 2.3, 1.5), Color = Color3.fromRGB(24, 38, 72), Material = Enum.Material.Fabric, CastShadow = false, Parent = m })
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			gui.LightInfluence = 0.8
			gui.Parent = banner
			-- X254: the town crest above the wording, as on the reference banners
			local ink = Color3.fromRGB(240, 236, 224)
			TownCrest.draw(gui, ink, UDim2.fromScale(1, 0.24), UDim2.fromScale(0.5, 0.06), Vector2.new(0.5, 0))
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.9, 0.62)
			label.Position = UDim2.fromScale(0.05, 0.33)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = ink
			label.Text = "RIVERMERE\n\nRIVER\nPEOPLE\nPLACES\nTOGETHER"
			label.Parent = gui
		end
	end
	if basket then
		-- bracket 10.35 .. 10.65 from inside the post out to over the basket
		part({ Name = "Bracket", Size = Vector3.new(0.25, 0.3, 2.2), CFrame = cf * CFrame.new(0, 10.5, -1.05), Color = IRON, CastShadow = false, Parent = m })
		part({
			Name = "Basket",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.9, 1.9, 1.9),
			CFrame = cf * CFrame.new(0, 9.5, -2),
			Color = BASKET_FLOWERS[rng:NextInteger(1, #BASKET_FLOWERS)],
			Material = Enum.Material.LeafyGrass,
			CastShadow = false,
			Parent = m,
		})
	end
	m.Parent = parent
	return m
end

-- A moored boat: one kit model from ServerStorage.Kit.Boats (free Creator Store
-- meshes, see docs/FREE_ASSETS.md section 16), centred on `cf` with the bow
-- towards its -Z (LookVector). Every template's pivot is its waterline, plan
-- centre, bow to -Z. At most 7.3 studs wide, so a 12-stud berth still fits.
-- A missing template gets KitPlacer's grey KitMissing block, never primitives.
RiverDresser.MOTOR_BOATS = { "BoatCruiser", "BoatCruiser", "BoatLaunch", "BoatDayBoat", "BoatRowing" }
RiverDresser.SAIL_BOAT = "BoatSailYacht"
-- the rendered water surface, below a berth `cf` (whose Y is the old hull centre)
local BOAT_WATERLINE = -0.9

function RiverDresser.buildBoat(parent: Instance, cf: CFrame, rng: Random): Model
	-- two rng draws, as the primitive boats made, so nothing placed after a boat moves
	local pick = rng:NextInteger(1, #RiverDresser.MOTOR_BOATS)
	local scale = rng:NextNumber(0.94, 1.06)
	-- X143: about half are sailing boats. Picked from the berth position rather
	-- than `rng`, so the share holds whatever else draws from the stream.
	local kind = if RiverDresser.hasMast(cf.Position) then RiverDresser.SAIL_BOAT else RiverDresser.MOTOR_BOATS[pick]
	local template = KitPlacer.find(kind)
	if not (template and template:IsA("Model")) then
		local missing = KitPlacer.place(kind, cf * CFrame.new(0, BOAT_WATERLINE, 0), parent, { fallbackSize = Vector3.new(6, 2.4, 20) })
		missing.Name = "Boat"
		return missing
	end
	local m = template:Clone() :: Model
	m.Name = "Boat" -- Quality hides whole models by this name
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(cf * CFrame.new(0, BOAT_WATERLINE, 0))
	m:SetAttribute("Kit", kind)
	V3Perf.applyDefaults(m, "decor")
	m.Parent = parent
	return m
end

-- X143: deterministic 1-in-2 pick from a boat's berth position (a 7-stud checkerboard)
function RiverDresser.hasMast(p: Vector3): boolean
	return (math.floor(p.X / 7) + math.floor(p.Z / 7)) % 2 == 0
end

-- X67: a single-storey café pavilion facing the river from the grass behind the
-- promenade, like the pub and deli frontages in RivermereRiverside.png. TEMP
-- site found by probing the promenade's back edge for 30 x 16 of clear grass
-- (07:43): just west of the Lune Bridge, in front of the riverside flats.
RiverDresser.CAFE_SITE = Vector3.new(55, 0, 351)
RiverDresser.CAFE_FACING = Vector3.new(0, 0, 1) -- towards the river
local CAFE_W, CAFE_D, CAFE_H = 24, 11, 9
local CAFE_BRICK = Color3.fromRGB(150, 76, 56)
local CAFE_NAVY = Color3.fromRGB(24, 40, 78)

function RiverDresser.cafePavilion(parent: Instance, site: Vector3, facing: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "RiversideCafe"
	-- local -Z is the glazed front, facing the river
	local cf = CFrame.lookAt(site, site + facing)
	local function box(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material): BasePart
		return part({ Name = name, Size = size, CFrame = cf * offset, Color = colour, Material = material, Parent = m })
	end
	box("Body", Vector3.new(CAFE_W, CAFE_H, CAFE_D), CFrame.new(0, CAFE_H / 2, 0), CAFE_BRICK, Enum.Material.Brick)
	box("Roof", Vector3.new(CAFE_W + 1.2, 0.6, CAFE_D + 1.2), CFrame.new(0, CAFE_H + 0.3, 0), Color3.fromRGB(70, 74, 82), Enum.Material.Slate)
	-- glazed shopfront 0.1 proud of the brick, with a door gap line in the middle
	local glass = box("Shopfront", Vector3.new(CAFE_W - 4, 5.2, 0.2), CFrame.new(0, 3.4, -CAFE_D / 2 - 0.1), Color3.fromRGB(58, 74, 90), Enum.Material.Glass)
	glass.Reflectance = 0.1
	box("Mullion", Vector3.new(0.3, 5.2, 0.3), CFrame.new(0, 3.4, -CAFE_D / 2 - 0.25), IRON, Enum.Material.Metal)
	local fascia = box("Fascia", Vector3.new(CAFE_W, 1.8, 0.4), CFrame.new(0, 6.9, -CAFE_D / 2 - 0.2), CAFE_NAVY, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.7
	gui.Parent = fascia
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Font = Enum.Font.Merriweather
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(236, 214, 150)
	label.Text = "THE LUNE CAFÉ"
	label.Parent = gui
	-- a navy canopy over the front, standing off the fascia
	box("Canopy", Vector3.new(CAFE_W - 2, 0.3, 3), CFrame.new(0, 5.95, -CAFE_D / 2 - 1.6) * CFrame.Angles(math.rad(-8), 0, 0), CAFE_NAVY, Enum.Material.Fabric).CastShadow = false
	-- two café tables and an A-board on the promenade in front
	for _, x in { -6, 6 } do
		local at = cf * CFrame.new(x, PROM_TOP, -CAFE_D / 2 - 9)
		ForecourtDresser.cafeSet(m, at * CFrame.Angles(0, math.pi / 2, 0))
	end
	ForecourtDresser.aBoard(m, cf * CFrame.new(CAFE_W / 2 - 1, PROM_TOP, -CAFE_D / 2 - 5), "Coffee\nCake\nRiver Views")
	m.Parent = parent
	return m
end

function RiverDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "riverside: no town"
	end
	local old = town:FindFirstChild("Riverside")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "Riverside"
	local quay = Instance.new("Model")
	quay.Name = "Quay"
	quay.Parent = root
	local furniture = Instance.new("Model")
	furniture.Name = "Furniture"
	furniture.Parent = root
	local moorings = Instance.new("Model")
	moorings.Name = "Moorings"
	moorings.Parent = root
	local rng = Random.new(1884)

	local travelled = 0
	local lampCount = 0
	local lampRng = Random.new(1885) -- own stream so the boats keep their looks
	local nextPost = 0
	local nextFurniture = FURNITURE_SPACING / 2
	local runs = RiverDresser.bankRuns(PROMENADE_X0, PROMENADE_X1, RUN_STEP)
	for _, run in runs do
		local length = (run.b - run.a).Magnitude
		if not RiverDresser.isClear(RiverDresser.promenadeProbe(run)) then
			travelled += length
			nextPost = travelled
			continue
		end
		-- quay wall face down into the water, stone kerb on top, paving behind
		strip(quay, "QuayWall", run, QUAY_W / 2, QUAY_W, -4, QUAY_TOP, STONE, Enum.Material.Cobblestone)
		strip(quay, "Promenade", run, QUAY_W + PROM_W / 2, PROM_W, -0.5, PROM_TOP, PAVING, Enum.Material.Pavement)
		clearBank(run)
		strip(quay, "Rail", run, 0.9, 0.25, QUAY_TOP + RAIL_H - 0.25, QUAY_TOP + RAIL_H, IRON, Enum.Material.Metal)
		travelled += length
		while nextPost <= travelled do
			local t = 1 - (travelled - nextPost) / length
			local p = run.a:Lerp(run.b, math.clamp(t, 0, 1)) + run.normal * 0.9
			part({
				Name = "Post",
				Size = Vector3.new(0.35, RAIL_H, 0.35),
				CFrame = CFrame.new(p.X, QUAY_TOP + RAIL_H / 2, p.Z),
				Color = IRON,
				Material = Enum.Material.Metal,
				CastShadow = false,
				Parent = quay,
			})
			nextPost += POST_STEP
		end
		while nextFurniture <= travelled do
			local t = 1 - (travelled - nextFurniture) / length
			local along = run.a:Lerp(run.b, math.clamp(t, 0, 1))
			local dir = (run.b - run.a).Unit
			local seat = along + run.normal * (QUAY_W + 2.2)
			-- bench facing the water, a planter and a lamp either side
			KitPlacer.place("UKSP__ParkBenches__ParkBench01", CFrame.lookAt(Vector3.new(seat.X, PROM_TOP, seat.Z), Vector3.new(seat.X, PROM_TOP, seat.Z) - run.normal), furniture, {
				fallbackSize = Vector3.new(6, 3, 2),
				fallbackColor = TIMBER,
				fallbackMaterial = Enum.Material.Wood,
			})
			-- a litter bin beside the bench, on the lamp side (RivermereRiverside.png)
			local bin = along + run.normal * (QUAY_W + 2.2) - dir * 4.5
			KitPlacer.place("UKSP__LitterBin__LitterBin", CFrame.lookAt(Vector3.new(bin.X, PROM_TOP, bin.Z), Vector3.new(bin.X, PROM_TOP, bin.Z) - run.normal), furniture, {
				fallbackSize = Vector3.new(2, 3.5, 2),
				fallbackColor = IRON,
			})
			local planter = along + run.normal * (QUAY_W + 2.5) + dir * 7
			part({ Name = "Planter", Size = Vector3.new(4, 2.4, 4), CFrame = CFrame.new(planter.X, PROM_TOP + 1.2, planter.Z), Color = STONE, Material = Enum.Material.Limestone, Parent = furniture })
			-- X65: a planted top sunk 0.2 into the planter (a ball read as a pink rock)
			-- X130: a leafy bed with round flower heads, sunk 0.3 into the planter
			Planting.bloom(furniture, CFrame.new(planter.X, PROM_TOP + 2.4 + 0.4, planter.Z), 3.6, 3.6, Color3.fromRGB(214, 70, 110):Lerp(Color3.fromRGB(240, 190, 60), rng:NextNumber()), rng)
			local lamp = along + run.normal * (QUAY_W + 1.2) - dir * 8
			lampCount += 1
			RiverDresser.heritageLamp(CFrame.lookAt(Vector3.new(lamp.X, PROM_TOP, lamp.Z), Vector3.new(lamp.X, PROM_TOP, lamp.Z) + run.normal), furniture, lampCount % 2 == 1, lampRng)
			nextFurniture += FURNITURE_SPACING
		end
	end

	-- moorings: pontoons parallel to the bank a little way out, boats alongside
	-- (MarinaDresser has the finger pontoons off the marina quay itself)
	local span = RiverDresser.marinaSpan()
	for _, run in RiverDresser.bankRuns(MARINA_X0, MARINA_X1, 30) do
		local mid = (run.a + run.b) / 2
		if rng:NextNumber() < 0.25 then
			continue
		end
		if span ~= nil then
			local x0, x1 = math.min(span.a.X, span.b.X), math.max(span.a.X, span.b.X)
			if mid.X > x0 - MOORING_MARINA_CLEAR and mid.X < x1 + MOORING_MARINA_CLEAR then
				continue
			end
		end
		local dir = (run.b - run.a).Unit
		local deck = mid - run.normal * 7
		part({
			Name = "Pontoon",
			Size = Vector3.new(5, 0.8, 26),
			CFrame = CFrame.lookAt(Vector3.new(deck.X, -1.6, deck.Z), Vector3.new(deck.X, -1.6, deck.Z) + dir),
			Color = TIMBER,
			Material = Enum.Material.WoodPlanks,
			Parent = moorings,
		})
		-- X246: tall timber mooring posts with pale caps at both ends of the
		-- pontoon, on the boat side (RivermereRiverside.png), 4 parts a pontoon
		for _, along in { -12, 12 } do
			-- 3.05 out: the post's inner face (0.9 wide) clears the 5-wide deck edge
			local at = deck + dir * along - run.normal * 3.05
			part({
				Name = "MooringPost",
				Size = Vector3.new(0.9, 7, 0.9),
				CFrame = CFrame.new(at.X, -0.8, at.Z),
				Color = Color3.fromRGB(62, 48, 36),
				Material = Enum.Material.Wood,
				Parent = moorings,
			})
			part({
				Name = "MooringCap",
				Size = Vector3.new(1.1, 0.3, 1.1),
				CFrame = CFrame.new(at.X, 2.85, at.Z),
				Color = Color3.fromRGB(214, 206, 188),
				Material = Enum.Material.SmoothPlastic,
				Parent = moorings,
			})
		end
		-- a kayak pulled up on the pontoon deck (top at -1.2; the kit pivot is 0.3
		-- above the kayak's underside). No rng: the boats keep their stream.
		local kayak = KitPlacer.find("BoatKayak")
		if kayak and kayak:IsA("Model") then
			local k = kayak:Clone()
			k.Name = "Boat" -- Quality hides whole models by this name
			local at = deck + dir * 6 + run.normal * 0.8
			k:PivotTo(CFrame.lookAt(Vector3.new(at.X, -0.9, at.Z), Vector3.new(at.X, -0.9, at.Z) + dir))
			k:SetAttribute("Kit", "BoatKayak")
			V3Perf.applyDefaults(k, "decor")
			k.Parent = moorings
		end
		local boat = mid - run.normal * 14
		RiverDresser.buildBoat(moorings, CFrame.lookAt(Vector3.new(boat.X, -2.2, boat.Z), Vector3.new(boat.X, -2.2, boat.Z) + dir * (if rng:NextNumber() < 0.5 then 1 else -1)), rng)
	end

	RiverDresser.cafePavilion(furniture, RiverDresser.CAFE_SITE, RiverDresser.CAFE_FACING)

	-- X267: a finger post on the promenade, as on RivermereRiverside.png. The
	-- town had exactly one, in the market square, and none of its blades pointed
	-- at a club ground. 10 parts (post, finial, 4 blades, 4 tips).
	SquareDresser.fingerPost(furniture, Vector3.new(RiverDresser.CAFE_SITE.X - 26, 0, RiverDresser.CAFE_SITE.Z - 4), PROM_TOP, {
		"Town Centre",
		"Station",
		"Riverside Park",
		{ name = "Club Grounds", position = SquareDresser.destination("Plot 1") or Vector3.new(992, 0, 840) },
	})

	root.Parent = town
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("riverside: %d parts"):format(parts)
end

return RiverDresser
