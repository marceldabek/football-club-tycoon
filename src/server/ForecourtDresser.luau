--!strict
-- Paves the grass left between building fronts and the pavement, and dresses
-- the high street (backlog X22 + X23 + X17). Runs after ShopDresser and
-- EstateDresser; output goes to workspace.Town.Forecourts:
--   Shops    one paving slab per shop row forecourt (front of the building out
--            to the pavement), bracket flower baskets between the shopfronts,
--            chalk A-boards, and a table + two chairs outside cafes and pubs
--   Semis    a short front path per house, pavement -> front door
--   Square   the pedestrian zone between the market square circle and the
--            surrounding shop blocks, plus a few trees in stone planters
--
-- Reference: assets/references/RivermereCenter.png (buff flagstone paving
-- right up to the shopfronts, a chalk A-board and cafe tables outside The
-- Daily Bean, hanging baskets on the pub and shop fronts, trees in planters
-- on the paved zone round the clock tower).
--
-- Y levels (TownBuilder.Y): roads 0.19..0.234, square 0.25, flat district
-- pieces 0.30, pavement 0.45. Everything here differs from those by >= 0.05:
--   0.40  forecourt paving and semis paths (just under the pavement top, so
--         the kerb wins where a slab tucks TUCK studs under the pavement)
--   0.14  square pedestrian zone: below the carriageways and the square disc,
--         so both sit on top of it and the zone's inner edge hides under the
--         square's round rim (no staircase against the circle)
--
-- Part budget (all three items <= 700): paving ~1 per shop row, 1 per semi
-- house, ~50 zone slabs; planters 3 each; baskets 2; A-boards 2; cafe sets 10.
-- Estimated from the layout: 69 forecourts + 58 paths + 51 zone slabs + 24
-- planter parts + <= 152 basket + <= 80 A-board + <= 160 cafe parts ~= 594.
-- (Baskets: one per join between shopfronts, about as many as the old one
-- per other bay on the 2-4 bay rows; the budget check still caps them.)
-- Props stop being placed once PART_BUDGET is reached.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownBuilder = require(script.Parent.TownBuilder)
local ShopDresser = require(script.Parent.ShopDresser)
local ShopBuilder = require(script.Parent.ShopBuilder)
local EstateDresser = require(script.Parent.EstateDresser)
local EstateBuilder = require(script.Parent.EstateBuilder)

local ForecourtDresser = {}

ForecourtDresser.MIN_GAP = 1
ForecourtDresser.MAX_GAP = 40
ForecourtDresser.TUCK = 1 -- the slab runs this far under the pavement
ForecourtDresser.PAVE_TOP = 0.40
ForecourtDresser.ZONE_TOP = 0.14
ForecourtDresser.PART_BUDGET = 700

local CARRIAGEWAY_MARGIN = 0.5
local RAY_STEP = 0.25
local SAMPLE_SPACING = 5
local PATH_WIDTH = 3
local ZONE_HALF = 110 -- the zone is a square of this half size round the market square, minus carriageways
local ZONE_CELL = 4
local ZONE_INNER = 6 -- cells whose centre is this far inside the square rim are left to the square disc
local FACADE_T = 0.2 -- ShopBuilder's facade parts stand this far proud of the body
local BUS_STOP_CLEAR = 8
local PLANTER_MAX = 8
local PLANTER_SPACING = 22

local PAVING = Color3.fromRGB(200, 188, 166)
local ZONE_PAVING = Color3.fromRGB(192, 182, 162)
local PATH = Color3.fromRGB(178, 170, 156)
local STONE = Color3.fromRGB(206, 196, 176)
local IRON = Color3.fromRGB(24, 24, 26)
local WOOD = Color3.fromRGB(120, 84, 54)
local CHALK = Color3.fromRGB(34, 38, 36)
local TRUNK = Color3.fromRGB(96, 74, 54)
local LEAVES = Color3.fromRGB(86, 132, 62)
local FLOWERS = {
	Color3.fromRGB(214, 60, 120),
	Color3.fromRGB(170, 80, 200),
	Color3.fromRGB(240, 90, 70),
	Color3.fromRGB(245, 240, 240),
}

-- A-board text per shopfront texture key (ShopBuilder.SHOP_FRONTS etc.)
ForecourtDresser.BOARD_TEXT = {
	shop_front_cafe = "COFFEE",
	shop_front_bakery = "FRESH BREAD",
	shop_front_deli = "LUNCH",
	shop_front_pub = "REAL ALE",
	shop_front_butcher = "LOCAL MEAT",
	shop_front_barber = "WALK INS",
	shop_front_charity = "OPEN",
	shop_front_newsagent = "OPEN",
	shop_front_pharmacy = "OPEN",
	shop_front_estate = "OPEN",
	shop_front_corner = "OPEN",
	shop_front_corner2 = "OPEN",
	shop_front_supermarket = "OFFERS",
} :: { [string]: string }

-- fronts that always get a board (the rest roll BOARD_CHANCE) and cafe seating
local ALWAYS_BOARD: { [string]: boolean } = { shop_front_cafe = true, shop_front_bakery = true, shop_front_deli = true, shop_front_pub = true }
local SEATING: { [string]: boolean } = { shop_front_cafe = true, shop_front_pub = true }
local BOARD_CHANCE = 0.35
local SET_MAX = 16 -- "the occasional" table: at most one per row, this many in town
local BOARD_MAX = 40

-- hanging baskets (X26): bracket just under the fascia top, never this close to a row end
local BASKET_END_CLEAR = 2
local BASKET_BRACKET_Y = ShopBuilder.GROUND_FLOOR - 0.6

export type Forecourt = {
	cframe: CFrame, -- centre of the rectangle at the frame's Y, same rotation as the building frame
	depth: number, -- along local X, front of the building -> just under the pavement
	length: number, -- along local Z
	gap: number, -- clear grass between the front and the nearest pavement edge
}
export type Span = { x0: number, x1: number, z0: number, z1: number }

-- ------------------------------------------------------------ pure helpers

local function pavementReach(road: TownLayout.Road): number
	return road.width / 2 + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH)
end

local function carriagewayReach(road: TownLayout.Road): number
	return road.width / 2
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- First t in [0, maxT] where origin + dir * t comes within reach(road) of a
-- road centreline, or nil.
local function firstHit(origin: Vector3, dir: Vector3, roads: { TownLayout.Road }, reach: (TownLayout.Road) -> number, maxT: number): number?
	local function inside(t: number): boolean
		local p = origin + dir * t
		for _, road in roads do
			if TownLayout.distanceToPolyline(p, road.points) <= reach(road) then
				return true
			end
		end
		return false
	end
	if inside(0) then
		return 0
	end
	local t = RAY_STEP
	while t <= maxT + 1e-6 do
		if inside(t) then
			local lo, hi = t - RAY_STEP, t
			for _ = 1, 10 do
				local mid = (lo + hi) / 2
				if inside(mid) then
					hi = mid
				else
					lo = mid
				end
			end
			return hi
		end
		t += RAY_STEP
	end
	return nil
end

-- Pure: the forecourt in front of a building whose frame follows the
-- ShopBuilder / EstateBuilder convention (front = local -X, frontage `length`
-- along local Z, `depth` along local X, frame at the block centre). Rays are
-- cast out of the front every ~5 studs; the gap is the shortest distance to a
-- pavement's outer edge (a lane's carriageway edge: lanes have no pavement).
-- The slab then runs TUCK further, but always stops CARRIAGEWAY_MARGIN short
-- of any carriageway. Nil when the gap is < MIN_GAP or > MAX_GAP.
function ForecourtDresser.forecourt(frame: CFrame, length: number, depth: number, roads: { TownLayout.Road }): Forecourt?
	local n = flat(frame:VectorToWorldSpace(Vector3.new(-1, 0, 0)))
	if n.Magnitude < 1e-6 then
		return nil
	end
	n = n.Unit
	local frontCentre = flat(frame:PointToWorldSpace(Vector3.new(-depth / 2, 0, 0)))
	local near: { TownLayout.Road } = {}
	for _, road in roads do
		local reach = length / 2 + ForecourtDresser.MAX_GAP + ForecourtDresser.TUCK + pavementReach(road) + 2
		if TownLayout.distanceToPolyline(frontCentre, road.points) <= reach then
			table.insert(near, road)
		end
	end
	if #near == 0 then
		return nil
	end
	local samples = math.max(3, math.ceil(length / SAMPLE_SPACING) + 1)
	local gap, limit = math.huge, math.huge
	local carriageMax = ForecourtDresser.MAX_GAP + TownLayout.PAVEMENT_WIDTH + ForecourtDresser.TUCK + 2
	for i = 0, samples - 1 do
		local z = -length / 2 + length * i / (samples - 1)
		local origin = flat(frame:PointToWorldSpace(Vector3.new(-depth / 2, 0, z)))
		local g = firstHit(origin, n, near, pavementReach, ForecourtDresser.MAX_GAP + 1)
		if g then
			gap = math.min(gap, g)
		end
		local c = firstHit(origin, n, near, carriagewayReach, carriageMax)
		if c then
			limit = math.min(limit, c)
		end
	end
	if gap < ForecourtDresser.MIN_GAP or gap > ForecourtDresser.MAX_GAP then
		return nil -- also covers "no pavement within reach" (gap stays huge)
	end
	local d = math.min(gap + ForecourtDresser.TUCK, limit - CARRIAGEWAY_MARGIN)
	if d < ForecourtDresser.MIN_GAP then
		return nil
	end
	return {
		cframe = frame * CFrame.new(-depth / 2 - d / 2, 0, 0),
		depth = d,
		length = length,
		gap = gap,
	}
end

-- Pure: a shop / flats / civic block's forecourt using ShopDresser's placement.
-- Also returns that placement (frame, length, depth).
function ForecourtDresser.shopForecourt(block: TownLayout.Box, roads: { TownLayout.Road }): (Forecourt?, CFrame, number, number)
	local cf, length, depth = ShopDresser.placement(block, roads)
	return ForecourtDresser.forecourt(cf, length, depth, roads), cf, length, depth
end

-- Pure: XZ rectangle (TownBuilder.Rect) covered by a forecourt.
function ForecourtDresser.rectOf(fc: Forecourt): TownBuilder.Rect
	local p = fc.cframe.Position
	local look = fc.cframe.LookVector -- local -Z, i.e. along the frontage
	return TownBuilder.rect(p.X, p.Z, look.X, look.Z, fc.length / 2, fc.depth / 2)
end

-- Pure: axis-aligned slabs paving the square's surroundings: cells of a
-- (2 * half)-wide square round `centre`, minus cells well inside the square
-- disc and cells touching any carriageway, roundabout or bend joint, merged
-- into rows and then into rectangles. World XZ extents.
function ForecourtDresser.zoneSpans(centre: Vector3, radius: number, half: number, cell: number, roads: { TownLayout.Road }, roundabouts: { TownLayout.Roundabout }?): { Span }
	local rects: { TownBuilder.Rect } = {}
	local circles: { { number } } = {}
	for _, road in roads do
		if TownLayout.distanceToPolyline(centre, road.points) > half * 1.5 + road.width then
			continue
		end
		for i = 1, #road.points - 1 do
			local r = TownBuilder.segmentRect(road.points[i], road.points[i + 1], road.width / 2)
			if r then
				table.insert(rects, r)
			end
		end
		for i = 2, #road.points - 1 do
			table.insert(circles, { road.points[i].X, road.points[i].Z, road.width / 2 })
		end
	end
	if roundabouts then
		for _, rb in roundabouts do
			table.insert(circles, { rb.centre.X, rb.centre.Z, rb.radius })
		end
	end

	local count = math.ceil(2 * half / cell)
	local x0, z0 = centre.X - half, centre.Z - half
	local inner = radius - ZONE_INNER
	local function free(ix: number, iz: number): boolean
		local cx, cz = x0 + (ix - 0.5) * cell, z0 + (iz - 0.5) * cell
		local dx, dz = cx - centre.X, cz - centre.Z
		if dx * dx + dz * dz < inner * inner then
			return false
		end
		local r = TownBuilder.rect(cx, cz, 1, 0, cell / 2, cell / 2)
		for _, q in rects do
			if TownBuilder.rectsOverlap(r, q) then
				return false
			end
		end
		for _, c in circles do
			if TownBuilder.circleOverlapsRect(c[1], c[2], c[3], r) then
				return false
			end
		end
		return true
	end

	type Open = { i0: number, i1: number, j0: number, j1: number }
	local all: { Open } = {}
	local open: { [string]: Open } = {}
	for iz = 1, count do
		local nextOpen: { [string]: Open } = {}
		local runStart: number? = nil
		for ix = 1, count + 1 do
			local isFree = ix <= count and free(ix, iz)
			if isFree and runStart == nil then
				runStart = ix
			elseif not isFree and runStart ~= nil then
				local key = runStart .. ":" .. (ix - 1)
				local o = open[key]
				if o then
					o.j1 = iz
				else
					o = { i0 = runStart, i1 = ix - 1, j0 = iz, j1 = iz }
					table.insert(all, o)
				end
				nextOpen[key] = o
				runStart = nil
			end
		end
		open = nextOpen
	end
	local out: { Span } = {}
	for _, o in all do
		table.insert(out, {
			x0 = x0 + (o.i0 - 1) * cell,
			x1 = x0 + o.i1 * cell,
			z0 = z0 + (o.j0 - 1) * cell,
			z1 = z0 + o.j1 * cell,
		})
	end
	return out
end

-- Pure: local Z of each hanging basket on a shop row's front: one centred on
-- each join between neighbouring shopfronts (between their fascia signs),
-- none within BASKET_END_CLEAR of either end of a row `length` long. `bays`
-- are the row's shopfronts in any order (centre z, width along local Z).
function ForecourtDresser.basketZs(bays: { Bay }, length: number): { number }
	local sorted = table.clone(bays)
	table.sort(sorted, function(a: Bay, b: Bay): boolean
		return a.z < b.z
	end)
	local out: { number } = {}
	local limit = length / 2 - BASKET_END_CLEAR
	for i = 1, #sorted - 1 do
		local a, b = sorted[i], sorted[i + 1]
		local z = ((a.z + a.width / 2) + (b.z - b.width / 2)) / 2
		if math.abs(z) <= limit then
			table.insert(out, z)
		end
	end
	return out
end

-- ---------------------------------------------------------------- instances

local partCount = 0

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	partCount += 1
	return p
end

local function room(n: number): boolean
	return partCount + n <= ForecourtDresser.PART_BUDGET
end

local function slab(parent: Instance, name: string, fc: Forecourt, top: number, color: Color3)
	part(parent, name, Vector3.new(fc.depth, top, fc.length), fc.cframe * CFrame.new(0, top / 2, 0), color, Enum.Material.Pavement, true).CastShadow = false
end

local function blockRect(block: TownLayout.Box): TownBuilder.Rect
	local right = CFrame.Angles(0, math.rad(block.yaw), 0).RightVector
	return TownBuilder.rect(block.centre.X, block.centre.Z, right.X, right.Z, block.size.X / 2, block.size.Z / 2)
end

type BlockRect = { block: TownLayout.Box, rect: TownBuilder.Rect }

local function allBlockRects(): { BlockRect }
	local out: { BlockRect } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(out, { block = block, rect = blockRect(block) })
		end
	end
	return out
end

local function hitsBlock(r: TownBuilder.Rect, blocks: { BlockRect }, own: TownLayout.Box?): boolean
	for _, b in blocks do
		if b.block ~= own and TownBuilder.rectsOverlap(r, b.rect) then
			return true
		end
	end
	return false
end

local function hitsAny(r: TownBuilder.Rect, rects: { TownBuilder.Rect }): boolean
	for _, q in rects do
		if TownBuilder.rectsOverlap(r, q) then
			return true
		end
	end
	return false
end

-- Roundabouts and the market square disc: slabs at PAVE_TOP must not lie over them.
local function hitsCircles(r: TownBuilder.Rect): boolean
	local sq = TownLayout.SQUARE
	if TownBuilder.circleOverlapsRect(sq.centre.X, sq.centre.Z, sq.radius, r) then
		return true
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		if TownBuilder.circleOverlapsRect(rb.centre.X, rb.centre.Z, rb.radius, r) then
			return true
		end
	end
	return false
end

local function nearBusStop(p: Vector3): boolean
	for _, stop in TownLayout.BUS_STOPS do
		local dx, dz = p.X - stop.position.X, p.Z - stop.position.Z
		if dx * dx + dz * dz < BUS_STOP_CLEAR * BUS_STOP_CLEAR then
			return true
		end
	end
	return false
end

local function clearOfRoads(p: Vector3, radius: number): boolean
	for _, road in TownLayout.ROADS do
		if TownLayout.distanceToPolyline(p, road.points) < pavementReach(road) + radius then
			return false
		end
	end
	return true
end

-- Built models whose PrimaryPart sits at this XZ (ShopDresser / EstateDresser output).
local function modelsByName(root: Instance?, name: string): { Model }
	local out: { Model } = {}
	if not root then
		return out
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d.Name == name and d.PrimaryPart then
			table.insert(out, d)
		end
	end
	return out
end

local function modelAt(models: { Model }, p: Vector3): Model?
	for _, m in models do
		local q = (m.PrimaryPart :: BasePart).Position
		if math.abs(q.X - p.X) <= 0.5 and math.abs(q.Z - p.Z) <= 0.5 then
			return m
		end
	end
	return nil
end

export type Bay = { z: number, width: number, key: string? }

-- Shopfront bays of a row, in the placement frame. Read from the built
-- ShopRow when there is one (its Shopfront parts carry the Front key), else
-- recomputed from ShopBuilder.bays without keys.
local function baysFor(row: Model?, frame: CFrame, length: number, use: string): { Bay }
	local out: { Bay } = {}
	if row then
		for _, p in row:GetChildren() do
			if p:IsA("BasePart") and p.Name:match("^Shopfront") then
				local key = p:GetAttribute("Front")
				table.insert(out, {
					z = frame:PointToObjectSpace(p.Position).Z,
					width = p.Size.Z,
					key = if type(key) == "string" then key else nil,
				})
			end
		end
		table.sort(out, function(a: Bay, b: Bay): boolean
			return a.z < b.z
		end)
		if #out > 0 then
			return out
		end
	end
	for _, bay in ShopBuilder.bays(length, use) do
		table.insert(out, { z = bay.centre, width = bay.width, key = if bay.wide then "shop_front_supermarket" else nil })
	end
	return out
end

-- A short iron bracket out of the facade with a small flower ball hanging
-- under its tip. The bracket's back end sinks 0.05 into the facade part.
local function basket(parent: Instance, frame: CFrame, frontX: number, z: number, rng: Random)
	local x = frontX - FACADE_T -- the facade parts' outer face
	local reach = 1.2
	part(parent, "BasketBracket", Vector3.new(reach + 0.05, 0.2, 0.2), frame * CFrame.new(x - reach / 2 + 0.025, BASKET_BRACKET_Y, z), IRON, Enum.Material.Metal, false).CastShadow = false
	local flowers = part(parent, "HangingBasket", Vector3.new(1.4, 1.4, 1.4), frame * CFrame.new(x - 0.95, BASKET_BRACKET_Y - 0.75, z), FLOWERS[rng:NextInteger(1, #FLOWERS)], Enum.Material.Grass, false);
	(flowers :: any).Shape = Enum.PartType.Ball
	flowers.CastShadow = false
end

-- Two chalkboards leaning into an A; the faces look along local -X / +X of `base`.
local function aBoard(parent: Instance, base: CFrame, text: string)
	local m = Instance.new("Model")
	m.Name = "ABoard"
	m.Parent = parent
	local tilt = math.rad(12)
	local h = 3
	for _, side in { -1, 1 } do
		local cf = base * CFrame.new(side * (h / 2) * math.sin(tilt), (h / 2) * math.cos(tilt), 0) * CFrame.Angles(0, 0, side * tilt)
		local board = part(m, "Board", Vector3.new(0.15, h, 2), cf, WOOD, Enum.Material.Wood, false)
		local gui = Instance.new("SurfaceGui")
		gui.Face = if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.86, 0.9)
		label.Position = UDim2.fromScale(0.07, 0.05)
		label.BackgroundColor3 = CHALK
		label.BorderSizePixel = 0
		label.TextColor3 = Color3.fromRGB(244, 240, 228)
		label.Font = Enum.Font.PatrickHand
		label.TextScaled = true
		label.TextWrapped = true
		label.Text = text
		label.Parent = gui
	end
end

-- A round table between two chairs along local Z. Each chair (4 parts): a
-- thin seat, a back on the side away from the table (so it faces the table)
-- and two slim side leg frames. Sizes keep every face off its neighbours'
-- planes: legs sit inside the seat outline and sink 0.05 into it and the
-- ground, the back is narrower than the seat and pokes 0.03 past its edge.
local CAFE_SET_PARTS = 10
local function cafeSet(parent: Instance, base: CFrame)
	local m = Instance.new("Model")
	m.Name = "CafeSet"
	m.Parent = parent
	local top = part(m, "TableTop", Vector3.new(0.2, 2.6, 2.6), base * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, true);
	(top :: any).Shape = Enum.PartType.Cylinder
	part(m, "TableLeg", Vector3.new(0.3, 2.4, 0.3), base * CFrame.new(0, 1.2, 0), IRON, Enum.Material.Metal, true)
	for _, side in { -1, 1 } do
		local z = side * 2.2
		part(m, "Seat", Vector3.new(1.5, 0.2, 1.5), base * CFrame.new(0, 1.5, z), WOOD, Enum.Material.WoodPlanks, true) -- y 1.4..1.6
		part(m, "ChairBack", Vector3.new(1.4, 1.7, 0.2), base * CFrame.new(0, 2.3, z + side * 0.68), WOOD, Enum.Material.WoodPlanks, false) -- y 1.45..3.15
		for _, lx in { -0.6, 0.6 } do
			part(m, "ChairLeg", Vector3.new(0.15, 1.5, 1.3), base * CFrame.new(lx, 0.7, z), IRON, Enum.Material.Metal, false) -- y -0.05..1.45
		end
	end
end

local function planterTree(parent: Instance, p: Vector3)
	local m = Instance.new("Model")
	m.Name = "PlanterTree"
	m.Parent = parent
	local base = CFrame.new(p.X, 0, p.Z)
	part(m, "Planter", Vector3.new(5, 2.2, 5), base * CFrame.new(0, 1.1, 0), STONE, Enum.Material.Limestone, true)
	part(m, "Trunk", Vector3.new(0.9, 9, 0.9), base * CFrame.new(0, 2.2 + 4.5, 0), TRUNK, Enum.Material.Wood, true)
	local crown = part(m, "Crown", Vector3.new(9, 8, 9), base * CFrame.new(0, 14, 0), LEAVES, Enum.Material.Grass, false);
	(crown :: any).Shape = Enum.PartType.Ball
end

-- -------------------------------------------------------------------- build

type ShopRecord = { block: TownLayout.Box, frame: CFrame, length: number, depth: number, fc: Forecourt }

-- Returns a summary line for the server log.
function ForecourtDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "forecourts: no town"
	end
	local old = town:FindFirstChild("Forecourts")
	if old then
		old:Destroy()
	end
	partCount = 0
	local folder = Instance.new("Folder")
	folder.Name = "Forecourts"
	local shopsModel = Instance.new("Model")
	shopsModel.Name = "Shops"
	shopsModel.Parent = folder
	local semisModel = Instance.new("Model")
	semisModel.Name = "Semis"
	semisModel.Parent = folder
	local squareModel = Instance.new("Model")
	squareModel.Name = "Square"
	squareModel.Parent = folder

	local roads = TownLayout.ROADS
	local blocks = allBlockRects()
	local paved: { TownBuilder.Rect } = {} -- every slab at PAVE_TOP, so none overlap
	local rng = Random.new(2223)

	-- X22: shop row forecourts
	local shops: { ShopRecord } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if not ShopDresser.SHOP_USES[block.use] then
				continue
			end
			local fc, frame, length, depth = ForecourtDresser.shopForecourt(block, roads)
			if not fc then
				continue
			end
			local r = ForecourtDresser.rectOf(fc)
			if hitsBlock(r, blocks, block) or hitsAny(r, paved) or hitsCircles(r) then
				continue
			end
			slab(shopsModel, "Forecourt", fc, ForecourtDresser.PAVE_TOP, PAVING)
			table.insert(paved, r)
			table.insert(shops, { block = block, frame = frame, length = length, depth = depth, fc = fc })
		end
	end

	-- X22: semis front paths, one per house, lined up on its front door
	local semiModels = modelsByName(town:FindFirstChild("Estates"), "SemiPair")
	local paths = 0
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use ~= "semis" then
				continue
			end
			local cf, width, depth = EstateDresser.placement(block, roads)
			local n = EstateBuilder.pairCount(width)
			local step = width / n
			for i = 1, n do
				local pairFrame = cf * CFrame.new(0, 0, -width / 2 + (i - 0.5) * step)
				local pairModel = modelAt(semiModels, pairFrame.Position)
				local front = if pairModel then pairModel:GetAttribute("Front") else nil
				local frontName: string? = if type(front) == "string" then front else nil
				for house = 0, 1 do
					-- same door positions as the gate gaps EstateBuilder cuts in the garden wall
					local doorZ = EstateBuilder.doorZ(step, frontName, house)
					local fc = ForecourtDresser.forecourt(pairFrame * CFrame.new(0, 0, doorZ), PATH_WIDTH, depth, roads)
					if not fc then
						continue
					end
					local r = ForecourtDresser.rectOf(fc)
					if hitsBlock(r, blocks, block) or hitsAny(r, paved) or hitsCircles(r) then
						continue
					end
					slab(semisModel, "FrontPath", fc, ForecourtDresser.PAVE_TOP, PATH)
					table.insert(paved, r)
					paths += 1
				end
			end
		end
	end

	-- X17: square pedestrian zone
	local square = TownLayout.SQUARE
	local spans = ForecourtDresser.zoneSpans(square.centre, square.radius, ZONE_HALF, ZONE_CELL, roads, TownLayout.ROUNDABOUTS)
	for _, s in spans do
		local w, l = s.x1 - s.x0, s.z1 - s.z0
		local top = ForecourtDresser.ZONE_TOP
		local p = part(squareModel, "Zone", Vector3.new(w, top, l), CFrame.new((s.x0 + s.x1) / 2, top / 2, (s.z0 + s.z1) / 2), ZONE_PAVING, Enum.Material.Pavement, true)
		p.CastShadow = false
	end

	-- X17: trees in planters on the zone, clear of roads, buildings, forecourts and bus stops
	local planters: { Vector3 } = {}
	for _, ringRadius in { 72, 88, 102 } do
		for k = 0, 23 do
			if #planters >= PLANTER_MAX or not room(3) then
				break
			end
			local a = (k + 0.5) / 24 * math.pi * 2
			local p = square.centre + Vector3.new(math.cos(a) * ringRadius, 0, math.sin(a) * ringRadius)
			local r = TownBuilder.rect(p.X, p.Z, 1, 0, 3.5, 3.5)
			local spaced = true
			for _, q in planters do
				if (q - p).Magnitude < PLANTER_SPACING then
					spaced = false
					break
				end
			end
			if spaced and clearOfRoads(p, 4) and not nearBusStop(p) and not hitsBlock(r, blocks, nil) and not hitsAny(r, paved) then
				planterTree(squareModel, p)
				table.insert(planters, p)
			end
		end
	end

	-- X23: cafe seating, A-boards, hanging baskets
	local rows = modelsByName(town:FindFirstChild("Shops"), "ShopRow")
	local sets, boards, baskets = 0, 0, 0
	for _, rec in shops do
		local row = modelAt(rows, rec.frame.Position)
		local bays = baysFor(row, rec.frame, rec.length, rec.block.use)
		local frontX = -rec.depth / 2
		local g = rec.fc.gap
		local rowHasSet = false
		for _, bay in bays do
			local key = bay.key or (if rec.block.use == "pub" or rec.block.use == "pub and cafes" then "shop_front_pub" else nil)
			if key and SEATING[key] and not rowHasSet and sets < SET_MAX and g >= 5 and room(CAFE_SET_PARTS) then
				local x = frontX - math.min(g / 2, 3.5)
				local z = bay.z + bay.width * 0.18
				local p = rec.frame * Vector3.new(x, 0, z)
				if bay.width >= 10 and clearOfRoads(p, 3) and not nearBusStop(p) then
					cafeSet(shopsModel, rec.frame * CFrame.new(x, ForecourtDresser.PAVE_TOP, z))
					sets += 1
					rowHasSet = true
				end
			end
			local text = key and ForecourtDresser.BOARD_TEXT[key]
			if text and boards < BOARD_MAX and g >= 3 and room(2) and (ALWAYS_BOARD[key :: string] or rng:NextNumber() < BOARD_CHANCE) then
				local x = frontX - math.clamp(g - 1.5, 1.5, 4)
				local z = bay.z - bay.width * 0.25
				local p = rec.frame * Vector3.new(x, 0, z)
				if clearOfRoads(p, 1.5) and not nearBusStop(p) then
					aBoard(shopsModel, rec.frame * CFrame.new(x, ForecourtDresser.PAVE_TOP, z), text)
					boards += 1
				end
			end
		end
		if g >= 2 then
			for _, z in ForecourtDresser.basketZs(bays, rec.length) do
				if not room(2) then
					break
				end
				basket(shopsModel, rec.frame, frontX, z, rng)
				baskets += 1
			end
		end
	end

	folder.Parent = town
	return ("forecourts: %d shop forecourts, %d semi paths, %d zone slabs, %d planters, %d cafe sets, %d A-boards, %d baskets, %d parts"):format(
		#shops,
		paths,
		#spans,
		#planters,
		sets,
		boards,
		baskets,
		partCount
	)
end

return ForecourtDresser
