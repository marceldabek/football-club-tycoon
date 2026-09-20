--!strict
-- Rivermere Marina and the riverside gardens (backlog X18). Runs after
-- RiverDresser. References: assets/references/RivermereRiverside.png (a
-- paved stone quay with black railings, boats moored at timber pontoons right
-- off the quay, benches and black lamps) and RivermereAIMap.png (Riverside:
-- pontoons jutting out into the river off a paved waterfront, small green
-- gardens between the flats and the water).
--
-- Why a paved quay rather than a recessed basin: both references show boats
-- moored in the river itself off a railed stone quay, not an enclosed dock.
-- A basin would also need a terrain carve behind the promenade (terrain
-- renders ~2 studs above its voxels, so a sunken part-built basin edge is
-- hard to get clean without Studio to check it).
--
-- workspace.Town.Marina
--   Quay      stone quay wall, wide flagstone apron, back kerb, railings with
--             two gangway gaps, harbour kiosk + sign, benches, lamps
--   Pontoons  a walkway pontoon along the quay, gangways down to it, finger
--             pontoons out into the river with mooring piles
--   Boats     one Boat model per occupied berth (RiverDresser.buildBoat)
--   Gardens   between the promenade and the riverside flats: low hedges along
--             the promenade, gravel cross paths with benches, cheap trees
--
-- The quay fills exactly the promenade gap RiverDresser leaves at the marina
-- block (RiverDresser.marinaSpan), ending 0.03 short of the neighbouring
-- promenade strips (which overhang their runs by 0.025) so no faces overlap.
-- The greybox "marina" slab is destroyed.
--
-- Y levels: quay wall -4..0.6, apron -0.5..0.35 (same as the promenade),
-- kerb -0.5..0.6, walkway pontoon -2.0..-1.2, fingers -2.05..-1.25 (water
-- renders at about -2), gravel paths -0.25..0.12 on the terrain (surface 0),
-- hedges -0.3..2.6/2.7.
--
-- Budget: TOTAL_PART_BUDGET for the whole Marina model. Quay + pontoons +
-- boats come to about 95 parts; gardens get the rest, capped at
-- GARDEN_PART_BUDGET, and stop placing cells (west to east) once it is spent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RiverDresser = require(script.Parent.RiverDresser)
local KitPlacer = require(script.Parent.KitPlacer)
local V3Perf = require(script.Parent.V3Perf)

-- v3 Lane I stage 2: the kit street light replaces TerraceBuilder's 6-part primitive
-- lamp. `cframe` keeps the old convention (lantern toward local -Z); the kit lamp's
-- arm overhangs along its RightVector, hence the quarter turn.
local KIT_LAMP = "UKSP__StreetLights__StreetLight01"
local function kitLamp(cframe: CFrame, parent: Instance): Model
	local lamp = KitPlacer.place(KIT_LAMP, cframe * CFrame.Angles(0, math.pi / 2, 0), parent, {
		fallbackSize = Vector3.new(1, 14, 1),
	})
	lamp.Name = "ParkLamp"
	V3Perf.applyDefaults(lamp, "prop")
	return lamp
end

local MarinaDresser = {}

local QUAY_W = RiverDresser.QUAY_W
local PROM_IN = RiverDresser.QUAY_W + RiverDresser.PROM_W -- landward edge of the promenade
local QUAY_TOP = RiverDresser.QUAY_TOP
local PROM_TOP = RiverDresser.PROM_TOP
local RAIL_H = RiverDresser.RAIL_H

local END_GAP = 0.03 -- quay pieces stop this short of the span ends
MarinaDresser.APRON_OUT = 34.5 -- landward edge of the marina apron
MarinaDresser.KERB_OUT = MarinaDresser.APRON_OUT + 0.8
local APRON_OUT = MarinaDresser.APRON_OUT
local KERB_OUT = MarinaDresser.KERB_OUT

local GANGWAY_HALF_GAP = 2.2 -- railing gap half-width at each gangway
local POST_STEP = 8
local WALKWAY_T0, WALKWAY_T1 = -8, -4 -- lateral (negative = out over the water)
local WALKWAY_TOP = -1.2
local FINGER_OUT = -26
local FINGER_SPACING = 16
local FINGER_W = 2.4
local BOAT_T = -21 -- hull centre: stern clears the walkway for the longest (24) hull
local BERTH_FILL = 0.75

local GARDEN_CELL = 30
local GARDEN_GAP = 2 -- grass between the promenade (or kerb) and the hedge
local GARDEN_DEPTH_MAX = 36
local GARDEN_DEPTH_MIN = 10
local GARDEN_PROBE = 2
local GARDEN_PATH_EVERY = 3
MarinaDresser.GARDEN_PART_BUDGET = 230
MarinaDresser.TOTAL_PART_BUDGET = 350
MarinaDresser.TREE_RADIUS = 5.5

local STONE = RiverDresser.STONE
local IRON = RiverDresser.IRON
local TIMBER = RiverDresser.TIMBER
local FLAGSTONE = Color3.fromRGB(212, 198, 172)
local GRAVEL = Color3.fromRGB(186, 172, 148)
local HEDGE = Color3.fromRGB(58, 98, 50)
local TRUNK = Color3.fromRGB(96, 72, 50)
local RENDER = Color3.fromRGB(236, 232, 222)
local NAVY = Color3.fromRGB(28, 40, 70)
local CREAM = Color3.fromRGB(240, 230, 200)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape ~= nil then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function countParts(root: Instance): number
	local n = if root:IsA("BasePart") then 1 else 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- ------------------------------------------------------------------ frames

-- A straight bank frame: s along the bank (a -> b), t towards the land.
export type Frame = { origin: Vector3, along: Vector3, inward: Vector3, length: number }

function MarinaDresser.spanFrame(span: RiverDresser.Run): Frame
	local flat = Vector3.new(span.b.X - span.a.X, 0, span.b.Z - span.a.Z)
	return {
		origin = Vector3.new(span.a.X, 0, span.a.Z),
		along = flat.Unit,
		inward = span.normal,
		length = flat.Magnitude,
	}
end

local function at(f: Frame, s: number, t: number, y: number?): Vector3
	local p = f.origin + f.along * s + f.inward * t
	return Vector3.new(p.X, y or 0, p.Z)
end

-- Box spanning s0..s1 along, t0..t1 inward, y0..y1.
local function box(f: Frame, parent: Instance, name: string, s0: number, s1: number, t0: number, t1: number, y0: number, y1: number, colour: Color3, material: Enum.Material): Part
	local c = at(f, (s0 + s1) / 2, (t0 + t1) / 2, (y0 + y1) / 2)
	return part({
		Name = name,
		Size = Vector3.new(t1 - t0, y1 - y0, s1 - s0),
		CFrame = CFrame.lookAt(c, c + f.along),
		Color = colour,
		Material = material,
		CastShadow = false,
		Parent = parent,
	})
end

-- Pure: the s positions of the gangways on a span of `length`.
function MarinaDresser.gangways(length: number): { number }
	return { length / 3, length * 2 / 3 }
end

-- Pure: finger pontoon s positions, FINGER_SPACING apart, 6 in from each end.
function MarinaDresser.fingers(length: number): { number }
	local out: { number } = {}
	local s = 6
	while s <= length - 6 do
		table.insert(out, s)
		s += FINGER_SPACING
	end
	return out
end

-- Pure: [s0, s1] rail pieces left after cutting the gangway gaps.
function MarinaDresser.railPieces(length: number): { { number } }
	local pieces: { { number } } = {}
	local s = END_GAP
	for _, g in MarinaDresser.gangways(length) do
		table.insert(pieces, { s, g - GANGWAY_HALF_GAP })
		s = g + GANGWAY_HALF_GAP
	end
	table.insert(pieces, { s, length - END_GAP })
	return pieces
end

-- Pure: is `p` (radius r) on the marina apron / kerb or the water in front of it?
function MarinaDresser.onMarina(p: Vector3, radius: number, span: RiverDresser.Run?): boolean
	if span == nil then
		return false
	end
	local f = MarinaDresser.spanFrame(span)
	local rel = Vector3.new(p.X - f.origin.X, 0, p.Z - f.origin.Z)
	local s, t = rel:Dot(f.along), rel:Dot(f.inward)
	return s > -radius and s < f.length + radius and t < KERB_OUT + 1 + radius
end

-- Pure: can a garden piece of `radius` stand at p? Clear of roads, bridges and
-- buildings (RiverDresser.isClear, the marina block ignored because its slab
-- is gone), behind the promenade and off the marina quay.
function MarinaDresser.gardenClear(p: Vector3, radius: number, span: RiverDresser.Run?): boolean
	if not RiverDresser.isClear(p, radius, RiverDresser.MARINA_USE) then
		return false
	end
	if TownLayout.distanceToPolyline(p, TownLayout.RIVER.points) < RiverDresser.EDGE + PROM_IN + 1 + radius then
		return false
	end
	return not MarinaDresser.onMarina(p, radius, span)
end

export type Cell = { frame: Frame, start: number, depth: number, index: number }

-- Pure: garden cells along the promenade. Each cell is GARDEN_CELL long,
-- centred on frame.origin (so s runs -length/2 .. length/2); the garden
-- band runs from t = start to start + depth. Cells need promenade in front
-- of them (the same probe RiverDresser uses) and at least GARDEN_DEPTH_MIN
-- of clear ground at three points along the cell. Behind the marina the band
-- starts behind the quay kerb.
function MarinaDresser.gardenCells(span: RiverDresser.Run?): { Cell }
	local cells: { Cell } = {}
	local runs = RiverDresser.bankRuns(RiverDresser.PROMENADE_X0, RiverDresser.PROMENADE_X1, GARDEN_CELL)
	for _, run in runs do
		local flat = Vector3.new(run.b.X - run.a.X, 0, run.b.Z - run.a.Z)
		local length = flat.Magnitude
		if length < 12 then
			continue
		end
		local mid = (run.a + run.b) / 2
		local f: Frame = { origin = Vector3.new(mid.X, 0, mid.Z), along = flat.Unit, inward = run.normal, length = length }
		local half = length / 2 - 3
		local samples = { -half, 0, half }
		local fronted = true
		local behindMarina = false
		for _, s in samples do
			local edge = at(f, s, 0)
			if not RiverDresser.isClear(edge + f.inward * (QUAY_W + RiverDresser.PROM_W / 2)) then
				fronted = false
			end
			if MarinaDresser.onMarina(edge + f.inward * 2, 0, span) then
				behindMarina = true
			end
		end
		if behindMarina then
			fronted = true -- the marina quay stands in for the promenade
		end
		if not fronted then
			continue
		end
		local start = (if behindMarina then KERB_OUT else PROM_IN) + GARDEN_GAP
		local depth = 0
		while depth + GARDEN_PROBE <= GARDEN_DEPTH_MAX do
			local ok = true
			for _, s in samples do
				if not MarinaDresser.gardenClear(at(f, s, start + depth + GARDEN_PROBE), 0.5, span) then
					ok = false
					break
				end
			end
			if not ok then
				break
			end
			depth += GARDEN_PROBE
		end
		if depth >= GARDEN_DEPTH_MIN then
			table.insert(cells, { frame = f, start = start, depth = depth, index = #cells + 1 })
		end
	end
	return cells
end

-- -------------------------------------------------------------------- quay

local function buildQuay(parent: Instance, f: Frame): number
	local L = f.length
	local s0, s1 = END_GAP, L - END_GAP
	box(f, parent, "QuayWall", s0, s1, 0, QUAY_W, -4, QUAY_TOP, STONE, Enum.Material.Cobblestone)
	box(f, parent, "Apron", s0, s1, QUAY_W, APRON_OUT, -0.5, PROM_TOP, FLAGSTONE, Enum.Material.Pavement)
	box(f, parent, "QuayKerb", s0, s1, APRON_OUT, KERB_OUT, -0.5, QUAY_TOP, STONE, Enum.Material.Limestone)
	local count = 3

	-- railings: top rail pieces between the gangway gaps, posts every POST_STEP,
	-- a post each side of every gap
	for _, piece in MarinaDresser.railPieces(L) do
		box(f, parent, "Rail", piece[1], piece[2], 0.775, 1.025, QUAY_TOP + RAIL_H - 0.25, QUAY_TOP + RAIL_H, IRON, Enum.Material.Metal)
		count += 1
	end
	local postAt: { number } = {}
	local s = 4
	while s <= L - 4 do
		local nearGap = false
		for _, g in MarinaDresser.gangways(L) do
			if math.abs(s - g) < GANGWAY_HALF_GAP + 1.5 then
				nearGap = true
			end
		end
		if not nearGap then
			table.insert(postAt, s)
		end
		s += POST_STEP
	end
	for _, g in MarinaDresser.gangways(L) do
		-- the post wraps the rail's cut end (no end face flush with a post face)
		table.insert(postAt, g - GANGWAY_HALF_GAP + 0.075)
		table.insert(postAt, g + GANGWAY_HALF_GAP - 0.075)
	end
	for _, ps in postAt do
		box(f, parent, "Post", ps - 0.175, ps + 0.175, 0.725, 1.075, QUAY_TOP - 0.1, QUAY_TOP + RAIL_H - 0.1, IRON, Enum.Material.Metal)
		count += 1
	end

	-- harbour kiosk near the downstream end, sign facing the water
	local ks = math.max(L - 16, L * 0.5)
	box(f, parent, "KioskBody", ks - 5, ks + 5, 22, 30, -0.2, 8.1, RENDER, Enum.Material.Plaster)
	box(f, parent, "KioskRoof", ks - 5.6, ks + 5.6, 21.4, 30.6, 8, 8.6, NAVY, Enum.Material.SmoothPlastic)
	local board = box(f, parent, "MarinaSign", ks - 4, ks + 4, 21.75, 21.95, 5.4, 7.2, NAVY, Enum.Material.SmoothPlastic)
	-- box() frames look along the bank, so the board's +X (Right) face looks at the water
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
	label.BackgroundTransparency = 1
	label.TextColor3 = CREAM
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.Text = "RIVERMERE MARINA"
	label.Parent = gui
	count += 3

	-- benches facing the water and lamps by the rail, between the gangways
	local gangways = MarinaDresser.gangways(L)
	for _, bs in { L / 6, (gangways[1] + gangways[2]) / 2 } do
		local seat = at(f, bs, 16, PROM_TOP)
		KitPlacer.place("UKSP__ParkBenches__ParkBench01", CFrame.lookAt(seat, seat - f.inward), parent, {
			fallbackSize = Vector3.new(6, 3, 2),
			fallbackColor = TIMBER,
			fallbackMaterial = Enum.Material.Wood,
		})
		local lamp = at(f, bs + 8, QUAY_W + 1.2, PROM_TOP)
		kitLamp(CFrame.lookAt(lamp, lamp - f.inward), parent)
	end
	return count
end

-- ---------------------------------------------------------------- pontoons

local function buildPontoons(parent: Instance, boats: Instance, f: Frame, rng: Random): number
	local L = f.length
	box(f, parent, "Pontoon", END_GAP, L - END_GAP, WALKWAY_T0, WALKWAY_T1, WALKWAY_TOP - 0.8, WALKWAY_TOP, TIMBER, Enum.Material.WoodPlanks)
	local count = 1

	-- gangway ramps: quay top (just onto the wall) down to the walkway deck
	for _, g in MarinaDresser.gangways(L) do
		local top = at(f, g, 0.5, QUAY_TOP)
		local bottom = at(f, g, WALKWAY_T1 - 0.4, WALKWAY_TOP)
		local length = (top - bottom).Magnitude
		local cf = CFrame.lookAt((top + bottom) / 2, bottom) * CFrame.new(0, -0.15, 0)
		part({ Name = "Gangway", Size = Vector3.new(3, 0.3, length), CFrame = cf, Color = TIMBER, Material = Enum.Material.WoodPlanks, CastShadow = false, Parent = parent })
		for _, side in { -1.6, 1.6 } do
			part({ Name = "GangwayRail", Size = Vector3.new(0.2, 0.2, length), CFrame = cf * CFrame.new(side, 2.6, 0), Color = IRON, Material = Enum.Material.Metal, CastShadow = false, Parent = parent })
		end
		count += 3
	end

	-- finger pontoons out into the river, a pile at each end, boats between
	local fingers = MarinaDresser.fingers(L)
	for i, fs in fingers do
		box(f, parent, "FingerPontoon", fs - FINGER_W / 2, fs + FINGER_W / 2, FINGER_OUT, WALKWAY_T0 + 0.1, WALKWAY_TOP - 0.85, WALKWAY_TOP - 0.05, TIMBER, Enum.Material.WoodPlanks)
		local pile = at(f, fs + FINGER_W / 2 + 0.7, FINGER_OUT + 0.8, -2.75)
		part({
			Name = "Pile",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10.5, 1.1, 1.1),
			CFrame = CFrame.new(pile) * CFrame.Angles(0, 0, math.pi / 2),
			Color = TIMBER:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		count += 2
		local nextFinger = fingers[i + 1]
		if nextFinger ~= nil and rng:NextNumber() < BERTH_FILL then
			local c = at(f, (fs + nextFinger) / 2, BOAT_T, -2.2)
			RiverDresser.buildBoat(boats, CFrame.lookAt(c, c - f.inward), rng)
			count += 5
		end
	end
	return count
end

-- ----------------------------------------------------------------- gardens

-- Cheap tree: trunk + one crown, sometimes a second (hidden on Low quality).
local function tree(parent: Instance, p: Vector3, rng: Random): number
	local scale = rng:NextNumber(0.75, 1.1)
	local trunkH = 7 * scale
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH + 0.3, 0.9 * scale, 0.9 * scale),
		CFrame = CFrame.new(p.X, (trunkH - 0.3) / 2, p.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = TRUNK,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local green = Color3.fromRGB(64 + rng:NextInteger(-10, 18), 118 + rng:NextInteger(-15, 22), 52 + rng:NextInteger(-10, 10))
	part({
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (9 * scale),
		CFrame = CFrame.new(p.X, trunkH + 2 * scale, p.Z),
		Color = green,
		Material = Enum.Material.LeafyGrass,
		Parent = parent,
	})
	if rng:NextNumber() < 0.5 then
		local a = rng:NextNumber(0, math.pi * 2)
		part({
			Name = "CanopyTop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (6 * scale),
			CFrame = CFrame.new(p.X + math.cos(a) * 2 * scale, trunkH + 5 * scale, p.Z + math.sin(a) * 2 * scale),
			Color = green:Lerp(Color3.fromRGB(150, 180, 90), 0.2),
			Material = Enum.Material.LeafyGrass,
			CastShadow = false,
			Parent = parent,
		})
		return 3
	end
	return 2
end

local MIN_TREE_SPACING = 8

local function buildGardens(parent: Instance, span: RiverDresser.Run?, rng: Random, budget: number): number
	local used = 0
	local trees: { Vector3 } = {}
	local function plant(p: Vector3)
		if not MarinaDresser.gardenClear(p, MarinaDresser.TREE_RADIUS, span) then
			return
		end
		for _, q in trees do
			if (Vector3.new(p.X - q.X, 0, p.Z - q.Z)).Magnitude < MIN_TREE_SPACING then
				return
			end
		end
		table.insert(trees, p)
		used += tree(parent, p, rng)
	end
	for _, cell in MarinaDresser.gardenCells(span) do
		if used > budget - 8 then
			break
		end
		local f = cell.frame
		local h = f.length / 2
		local t0 = cell.start
		local hasPath = cell.index % GARDEN_PATH_EVERY == 1

		-- low hedge along the promenade side, split round the path
		local hedgeRuns = if hasPath then { { -h + 1, -2.6 }, { 2.6, h - 1 } } else { { -h + 1, h - 1 } }
		for _, r in hedgeRuns do
			-- alternate heights so hedges meeting at a bend never share a top plane
			box(f, parent, "Hedge", r[1], r[2], t0, t0 + 1.6, -0.3, 2.6 + (cell.index % 2) * 0.1, HEDGE, Enum.Material.Grass)
			used += 1
		end

		if hasPath then
			-- gravel path from under the promenade / kerb back to the far side
			box(f, parent, "GardenPath", -2, 2, t0 - GARDEN_GAP - 1, t0 + cell.depth, -0.25, 0.12, GRAVEL, Enum.Material.Pebble)
			used += 1
			if cell.depth >= 12 then
				local seat = at(f, 3.8, t0 + cell.depth / 2, 0)
				if MarinaDresser.gardenClear(seat, 3, span) then
					local bench = KitPlacer.place("UKSP__ParkBenches__ParkBench01", CFrame.lookAt(seat, seat - f.along), parent, {
						fallbackSize = Vector3.new(6, 3, 2),
						fallbackColor = TIMBER,
						fallbackMaterial = Enum.Material.Wood,
					})
					used += countParts(bench)
				end
			end
			if cell.depth >= 12 then
				plant(at(f, -h * 0.55, t0 + math.min(cell.depth - 4, 8), 0))
			end
		else
			plant(at(f, -h * 0.45 + rng:NextNumber(-2, 2), t0 + 5 + rng:NextNumber(0, math.max(0, math.min(cell.depth, 14) - 6)), 0))
			if cell.depth >= 24 and rng:NextNumber() < 0.6 then
				plant(at(f, h * 0.45 + rng:NextNumber(-2, 2), t0 + cell.depth - 6 - rng:NextNumber(0, 4), 0))
			end
		end
	end
	return used
end

-- ---------------------------------------------------------------------- API

local function removeGreyboxMarina(town: Instance)
	local districts = town:FindFirstChild("Districts")
	if not districts then
		return
	end
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use ~= RiverDresser.MARINA_USE then
				continue
			end
			local folder = districts:FindFirstChild(district.name)
			if not folder then
				continue
			end
			for _, d in folder:GetChildren() do
				if d:IsA("BasePart") and d.Name == block.use then
					if math.abs(d.Position.X - block.centre.X) < 0.5 and math.abs(d.Position.Z - block.centre.Z) < 0.5 then
						d:Destroy()
					end
				end
			end
		end
	end
end

function MarinaDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "marina: no town"
	end
	local old = town:FindFirstChild("Marina")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "Marina"
	local rng = Random.new(1884)

	local span = RiverDresser.marinaSpan()
	local quayParts, gardenParts = 0, 0
	if span ~= nil then
		local f = MarinaDresser.spanFrame(span)
		local quay = model("Quay", root)
		buildQuay(quay, f)
		buildPontoons(model("Pontoons", root), model("Boats", root), f, rng)
		removeGreyboxMarina(town)
		quayParts = countParts(root)
	end
	local gardens = model("Gardens", root)
	buildGardens(gardens, span, rng, math.min(MarinaDresser.GARDEN_PART_BUDGET, MarinaDresser.TOTAL_PART_BUDGET - quayParts))
	gardenParts = countParts(gardens)

	root.Parent = town
	return ("marina: %d parts (quay/pontoons/boats %d, gardens %d)%s"):format(
		quayParts + gardenParts,
		quayParts,
		gardenParts,
		if span == nil then ", no marina span" else ""
	)
end

return MarinaDresser
