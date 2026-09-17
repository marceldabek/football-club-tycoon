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
--   Moorings    wooden pontoons out on the water + simple boats (the marina reach)
-- Budget: roughly 6 parts per 10 studs of promenade + 8 parts a boat.
--
-- The TownLayout "marina" block interrupts the promenade (isClear treats it
-- like any other block); MarinaDresser builds the marina quay in that gap
-- (RiverDresser.marinaSpan) and the river moorings here stay clear of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)

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
local TIMBER = Color3.fromRGB(120, 92, 64)
local BOAT_HULLS = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(30, 50, 100), Color3.fromRGB(180, 40, 40) }

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
-- the kit LampVictorian is 36. Ground at `cf`.
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

-- A simple moored boat, 5 parts, centred on `cf` with the bow towards its -Z
-- (LookVector). Hull length 16..24 plus a 5-stud bow; width 6.
function RiverDresser.buildBoat(parent: Instance, cf: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Boat"
	m.Parent = parent
	local hull = BOAT_HULLS[rng:NextInteger(1, #BOAT_HULLS)]
	local length = rng:NextNumber(16, 24)
	-- hull body + a wedge bow, cabin, windscreen, cover
	part({ Name = "Hull", Size = Vector3.new(6, 2.4, length), CFrame = cf * CFrame.new(0, 0.2, 0), Color = hull, Parent = m })
	part({
		Name = "Bow",
		Size = Vector3.new(6, 2.4, 5),
		CFrame = cf * CFrame.new(0, 0.2, -length / 2 - 2.5), -- full height at local +Z meets the hull (X32)
		Color = hull,
		Parent = m,
	}, "WedgePart")
	part({ Name = "Cabin", Size = Vector3.new(4.6, 2.2, length * 0.35), CFrame = cf * CFrame.new(0, 2.5, -length * 0.1), Color = Color3.fromRGB(240, 240, 235), Parent = m })
	part({ Name = "Glass", Size = Vector3.new(4.2, 1.2, 0.2), CFrame = cf * CFrame.new(0, 2.9, -length * 0.1 - length * 0.175 - 0.1), Color = Color3.fromRGB(40, 60, 80), Material = Enum.Material.Glass, Parent = m })
	part({ Name = "Cover", Size = Vector3.new(5.4, 0.4, length * 0.3), CFrame = cf * CFrame.new(0, 1.6, length * 0.3), Color = Color3.fromRGB(30, 40, 60), Material = Enum.Material.Fabric, Parent = m })
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
			local planter = along + run.normal * (QUAY_W + 2.5) + dir * 7
			part({ Name = "Planter", Size = Vector3.new(4, 2.4, 4), CFrame = CFrame.new(planter.X, PROM_TOP + 1.2, planter.Z), Color = STONE, Material = Enum.Material.Limestone, Parent = furniture })
			-- X65: a planted top sunk 0.2 into the planter (a ball read as a pink rock)
			part({
				Name = "Flowers",
				Size = Vector3.new(3.6, 1.1, 3.6),
				CFrame = CFrame.new(planter.X, PROM_TOP + 2.4 - 0.2 + 0.55, planter.Z),
				Color = Color3.fromRGB(214, 70, 110):Lerp(Color3.fromRGB(240, 190, 60), rng:NextNumber()),
				Material = Enum.Material.LeafyGrass,
				CastShadow = false,
				Parent = furniture,
			})
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
		local boat = mid - run.normal * 14
		RiverDresser.buildBoat(moorings, CFrame.lookAt(Vector3.new(boat.X, -2.2, boat.Z), Vector3.new(boat.X, -2.2, boat.Z) + dir * (if rng:NextNumber() < 0.5 then 1 else -1)), rng)
	end

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
