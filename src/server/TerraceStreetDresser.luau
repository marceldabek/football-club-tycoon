--!strict
-- Terraced street dressing from RiveremereWestdale.png (backlog X11). Runs after
-- StreetDresser (it reads the rows and lamps StreetDresser placed) and adds:
--   Trees     street trees in the kerb side of the pavement: a small square
--             tree pit, a trunk and 1-2 canopy balls, clear of lamps, bins,
--             junction mouths and bus stops
--   Gardens   a low brick front garden wall between the terrace front and the
--             pavement, with black railings or a hedge behind it, gaps at the
--             front doors
--   Signs     UK street name plates (black on white, district line underneath)
--             on two short posts at junction corners
--   Cars      parked kit cars (KitPlacer, grey block fallback) at the kerb,
--             irregular gaps, never across a junction mouth
-- Club banners on the lamp posts are client-side (TownLife), not here.
--
-- Order and budget: the Mill Street kit showpiece (StreetDresser.DRESSED,
-- x 0..400) gets FULL detail first. Then the LIGHT streets that front
-- TerraceBuilder rows, nearest the market square first (PRIORITY_STREETS
-- last, from their own reserve), each built into its
-- own model and dropped again if it would push the total past PART_BUDGET.
--   FULL  tree 5 parts, railing segment ~3 + 1 bar per 2 studs, hedge
--         segment 3, 2 piers per gate, sign 3, kit cars on the kerb
--         StreetDresser leaves empty
--   LIGHT tree 3 parts, 2 parts per house frontage, sign 3, sparse cars on
--         both kerbs
--
-- Heights (TownBuilder.Y): carriageways 0.19..0.234, pavement top 0.45,
-- ground 0. Tree pits top out at 0.51 (0.06 over the pavement). Walls start
-- 0.15 behind the pavement's back edge and 0.2 below ground. Every stacked
-- piece is sunk >= 0.05 into the one below, so no two faces share a plane.
--
-- Quality: tree models, the railing bars/rails and hedges are Decor (hidden on
-- Low); kit cars are already decor via Quality.DECOR_KITS. Walls, piers and
-- street signs stay visible.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)
local StreetDresser = require(script.Parent.StreetDresser)
local TerraceBuilder = require(script.Parent.TerraceBuilder)

local TerraceStreetDresser = {}

TerraceStreetDresser.PART_BUDGET = 1240 -- TEMP; +40 for the third canopy lobe on full-detail trees (X48)
-- X59 (TEMP): light streets dressed after the rest from their own reserve, so the
-- Westdale district (RiveremereWestdale.png) isn't left bare by the budget and
-- the streets nearer the square keep the dressing they had
-- v3 (Lane I stage 1): disabled rather than deleted, because the garden / car
-- maths is shared with tests, CentreTreeDresser and SignDresser. Stage 2 removes
-- the code. Front gardens are HouseAssembler's Boundaries; parked cars are
-- StreetFurniture's. Street trees and name plates are still built here.
TerraceStreetDresser.V3_HOUSING_RETIRED = true
TerraceStreetDresser.V3_PARKED_CARS_RETIRED = true
TerraceStreetDresser.PRIORITY_STREETS = { "Weir Road" }
TerraceStreetDresser.PRIORITY_RESERVE = 260
TerraceStreetDresser.TREE_INSET = 2.2 -- trunk centre from the kerb edge (walkers use pavement centre, +4)
TerraceStreetDresser.LAMP_CLEAR = 8 -- XZ distance a tree keeps from a lamp post (and its bin, 3 along)
TerraceStreetDresser.JUNCTION_CLEAR = 10 -- past the crossing road's pavement edge
TerraceStreetDresser.BUS_STOP_CLEAR = 14
TerraceStreetDresser.MIN_GAP = 1.4 -- front garden depth needed for a wall
TerraceStreetDresser.HEDGE_GAP = 3 -- ... and for a hedge behind it
TerraceStreetDresser.MAX_GAP = 12
TerraceStreetDresser.GATE_WIDTH = 4 -- 2.6 clear between full-detail piers
TerraceStreetDresser.SIGN_BACK = 0.6 -- plate plane from the pavement's back edge
TerraceStreetDresser.SIGN_GAP = 1 -- plate end from the crossing road's pavement edge

local PAVEMENT_WIDTH = TownLayout.PAVEMENT_WIDTH
local PAVEMENT_TOP = 0.45
-- VanWhite is 71 parts against the one-mesh hatchback's 1, and six vans were 426 of the
-- showpiece's 1,013 parts (X35): vans are 1 in 6 here, not StreetDresser's 1 in 3
local CAR_KITS = { "HatchbackOrange", "HatchbackNavy", "HatchbackRed", "HatchbackSilver", "HatchbackOrange", "VanWhite" } -- X45: generated hatchbacks for colour
local CAR_KERB_OFFSET = 4.2 -- StreetDresser's
local CAR_HALF = 6.5
local WALL_SETBACK = 0.15
local WALL_T = 0.8
local COPING_T = 1.0
local HEDGE_T = 1.6
local PIER = 1.4
local MIN_SEGMENT = 1.5
local MIN_STREET_PARTS = 60 -- stop trying light streets once less than this is left
local KIT_HOUSES = 8 -- TerraceRowVictorian: 128 long, two-up two-down; ASSUMED mirrored pairs (doors side by side)
local AREAS = { "Town Centre", "Northfields", "Westdale", "Riverside", "Riverside Park", "Station", "Industrial Estate" }

local BRICK = Color3.fromRGB(146, 72, 54)
local COPING = Color3.fromRGB(198, 188, 168)
local IRON = Color3.fromRGB(22, 22, 24)
local HEDGE = Color3.fromRGB(58, 100, 48)
local TRUNK = Color3.fromRGB(92, 72, 54)
local LEAVES = { Color3.fromRGB(88, 130, 58), Color3.fromRGB(74, 118, 52), Color3.fromRGB(104, 142, 66) }
local PIT = Color3.fromRGB(84, 66, 50)
local SIGN_WHITE = Color3.fromRGB(246, 246, 242)
local SIGN_BLACK = Color3.fromRGB(20, 20, 22)

export type Spot = { position: Vector3, direction: Vector3, side: number }
export type Junction = { point: Vector3, other: TownLayout.Road, dirs: { Vector3 } }
export type Frontage = { cframe: CFrame, gap: number, flipped: boolean }
export type Segment = { z0: number, z1: number }

-- ------------------------------------------------------------ pure helpers

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inRange(x: number, range: { number }?): boolean
	return range == nil or (x >= range[1] and x <= range[2])
end

local function pavementReach(road: TownLayout.Road): number
	return road.width / 2 + (if road.kind == "lane" then 0 else PAVEMENT_WIDTH)
end

local function rightOf(dir: Vector3): Vector3
	return Vector3.new(-dir.Z, 0, dir.X)
end

-- True when p is within `clear` studs of another road's pavement edge (a
-- lane's carriageway edge) or of a roundabout's.
local function nearOtherRoad(p: Vector3, road: TownLayout.Road, roads: { TownLayout.Road }, clear: number): boolean
	for _, other in roads do
		if other ~= road and other.name ~= road.name then
			if TownLayout.distanceToPolyline(p, other.points) < pavementReach(other) + clear then
				return true
			end
		end
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		if (flat(p) - flat(rb.centre)).Magnitude < rb.radius + PAVEMENT_WIDTH + clear then
			return true
		end
	end
	return false
end

local function nearBusStop(p: Vector3, clear: number): boolean
	for _, stop in TownLayout.BUS_STOPS do
		if (flat(p) - flat(stop.position)).Magnitude < clear then
			return true
		end
	end
	return false
end

-- Pure: street tree spots on both pavements. Stations every spacing / 2,
-- alternating sides, so each side has a tree every `spacing`. A spot is
-- dropped outside the X range, within LAMP_CLEAR of an `avoid` point, near
-- another road's mouth (JUNCTION_CLEAR past its pavement), near a bus stop,
-- or when `blocked(position)` says so.
function TerraceStreetDresser.treeSpots(
	road: TownLayout.Road,
	spacing: number,
	range: { number }?,
	avoid: { Vector3 },
	roads: { TownLayout.Road },
	blocked: ((Vector3) -> boolean)?
): { Spot }
	local out: { Spot } = {}
	local lateral = road.width / 2 + TerraceStreetDresser.TREE_INSET
	for i, st in StreetDresser.stations(road.points, spacing / 2) do
		local side = if i % 2 == 0 then -1 else 1
		local p = st.position + rightOf(st.direction) * side * lateral
		if not inRange(p.X, range) then
			continue
		end
		local clash = false
		for _, a in avoid do
			if (flat(a) - p).Magnitude < TerraceStreetDresser.LAMP_CLEAR then
				clash = true
				break
			end
		end
		if clash or nearOtherRoad(p, road, roads, TerraceStreetDresser.JUNCTION_CLEAR) or nearBusStop(p, TerraceStreetDresser.BUS_STOP_CLEAR) then
			continue
		end
		if blocked and blocked(p) then
			continue
		end
		table.insert(out, { position = p, direction = st.direction, side = side })
	end
	return out
end

-- Pure: parked car centres on one kerb (side +1 = right of the polyline
-- direction). Gaps are rng-drawn in [minGap, maxGap] and each slot is left
-- empty with probability `skip`. No car overlaps a junction mouth, a bus stop
-- or a polyline end, and every car lies inside the X range.
function TerraceStreetDresser.carSpots(
	road: TownLayout.Road,
	side: number,
	range: { number }?,
	roads: { TownLayout.Road },
	rng: Random,
	minGap: number,
	maxGap: number,
	skip: number
): { Spot }
	local out: { Spot } = {}
	local lateral = side * (road.width / 2 - CAR_KERB_OFFSET)
	for i = 1, #road.points - 1 do
		local a, b = flat(road.points[i]), flat(road.points[i + 1])
		local length = (b - a).Magnitude
		if length < 2 * CAR_HALF then
			continue
		end
		local dir = (b - a) / length
		local s = CAR_HALF + rng:NextNumber(0, maxGap)
		while s <= length - CAR_HALF do
			local centre = a + dir * s
			local p = centre + rightOf(dir) * lateral
			local ok = rng:NextNumber() >= skip
			if ok then
				for _, e in { -CAR_HALF, CAR_HALF } do
					local q = centre + dir * e
					if not inRange(q.X, range) or nearOtherRoad(q, road, roads, 1) or nearBusStop(q, TerraceStreetDresser.BUS_STOP_CLEAR) then
						ok = false
					end
				end
			end
			if ok then
				table.insert(out, { position = p, direction = dir, side = side })
			end
			s += 2 * CAR_HALF + rng:NextNumber(minGap, maxGap)
		end
	end
	return out
end

-- Pure: where `road` meets other roads. A junction is a proper crossing of two
-- segments, or an end of one road lying on the other. `dirs` are the unit
-- directions along `road` that leave the junction and stay on it.
function TerraceStreetDresser.junctions(road: TownLayout.Road, roads: { TownLayout.Road }): { Junction }
	local out: { Junction } = {}
	local function add(p: Vector3, other: TownLayout.Road)
		p = flat(p)
		for _, j in out do
			if j.other == other and (j.point - p).Magnitude < 5 then
				return
			end
		end
		local dirs: { Vector3 } = {}
		local probe = pavementReach(other) + 6
		for i = 1, #road.points - 1 do
			local a, b = flat(road.points[i]), flat(road.points[i + 1])
			if (b - a).Magnitude < 1e-6 or TownLayout.segmentDistance(p, a, b) > 1 then
				continue
			end
			local d = (b - a).Unit
			for _, cand in { d, -d } do
				if TownLayout.distanceToPolyline(p + cand * probe, road.points) < 1 then
					local dup = false
					for _, e in dirs do
						if (e - cand).Magnitude < 1e-3 then
							dup = true
						end
					end
					if not dup then
						table.insert(dirs, cand)
					end
				end
			end
		end
		if #dirs > 0 then
			table.insert(out, { point = p, other = other, dirs = dirs })
		end
	end
	for _, other in roads do
		if other == road or other.name == road.name then
			continue
		end
		-- ends of either road lying on the other
		for _, e in { road.points[1], road.points[#road.points] } do
			if TownLayout.distanceToPolyline(e, other.points) <= other.width / 2 + 1 then
				add(e, other)
			end
		end
		for _, e in { other.points[1], other.points[#other.points] } do
			if TownLayout.distanceToPolyline(e, road.points) <= road.width / 2 + 1 then
				-- project onto the road's centreline
				local best, bestP = math.huge, e
				for i = 1, #road.points - 1 do
					local a, b = flat(road.points[i]), flat(road.points[i + 1])
					local ab = b - a
					local t = if ab.Magnitude > 1e-6 then math.clamp((flat(e) - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
					local q = a + ab * t
					if (q - flat(e)).Magnitude < best then
						best, bestP = (q - flat(e)).Magnitude, q
					end
				end
				add(bestP, other)
			end
		end
		-- proper crossings
		for i = 1, #road.points - 1 do
			local a, b = flat(road.points[i]), flat(road.points[i + 1])
			for k = 1, #other.points - 1 do
				local c, d = flat(other.points[k]), flat(other.points[k + 1])
				local r, s = b - a, d - c
				local denom = r.X * s.Z - r.Z * s.X
				if math.abs(denom) < 1e-9 then
					continue
				end
				local qp = c - a
				local t = (qp.X * s.Z - qp.Z * s.X) / denom
				local u = (qp.X * r.Z - qp.Z * r.X) / denom
				if t > 0 and t < 1 and u > 0 and u < 1 then
					add(a + r * t, other)
				end
			end
		end
	end
	return out
end

-- Pure: plate width for a name (studs).
function TerraceStreetDresser.plateWidth(name: string): number
	return math.clamp(1.6 + 0.55 * #name, 5, 10)
end

-- Pure: sign placements for `road` at its junction corners: at the back of the
-- road's pavement, just past the crossing road's pavement, on the side(s) where
-- the crossing road's mouth is. Plate CFrame: local X along the street, Front
-- (LookVector) facing the carriageway, Y = 0.
function TerraceStreetDresser.signSpots(road: TownLayout.Road, roads: { TownLayout.Road }): { CFrame }
	local out: { CFrame } = {}
	local w = TerraceStreetDresser.plateWidth(road.name:upper())
	local lateral = road.width / 2 + PAVEMENT_WIDTH - TerraceStreetDresser.SIGN_BACK
	for _, j in TerraceStreetDresser.junctions(road, roads) do
		local reach = pavementReach(j.other)
		local along = reach + TerraceStreetDresser.SIGN_GAP + w / 2
		for _, d in j.dirs do
			for _, side in { -1, 1 } do
				local right = rightOf(d)
				local p = j.point + d * along + right * side * lateral
				if TownLayout.distanceToPolyline(p, j.other.points) > along + 3 then
					continue -- the far side of a T: no mouth here
				end
				if math.abs(TownLayout.distanceToPolyline(p, road.points) - lateral) > 0.5 then
					continue -- past the road's end or round a bend
				end
				if nearOtherRoad(p, road, roads, 0.5) then
					continue
				end
				table.insert(out, CFrame.lookAt(p, p - right * side))
			end
		end
	end
	return out
end

-- Pure: split a frontage [-length/2, length/2] into wall segments with a
-- gate of `gateWidth` centred on each gate z. Pieces shorter than MIN_SEGMENT
-- are dropped.
function TerraceStreetDresser.gateSegments(length: number, gates: { number }, gateWidth: number): { Segment }
	local sorted = table.clone(gates)
	table.sort(sorted)
	local out: { Segment } = {}
	local z = -length / 2
	for _, g in sorted do
		local z1 = math.min(g - gateWidth / 2, length / 2)
		if z1 - z >= MIN_SEGMENT then
			table.insert(out, { z0 = z, z1 = z1 })
		end
		z = math.max(z, g + gateWidth / 2)
	end
	if length / 2 - z >= MIN_SEGMENT then
		table.insert(out, { z0 = z, z1 = length / 2 })
	end
	return out
end

-- Pure: front door z offsets along a TerraceBuilder row (row frame). The
-- facade tile is one house bay on the Left (-X) face, U running along +Z; the
-- door is drawn at u 40..126 of 512 (tools/kit/make_facades.py), mirrored on
-- terrace_front_b.
function TerraceStreetDresser.lightDoorZs(length: number, facade: string?): { number }
	local houses = TerraceBuilder.houseCount(length)
	local w = length / houses
	local u = if facade == "front_b" then 1 - 83 / 512 else 83 / 512
	local out: { number } = {}
	for k = 0, houses - 1 do
		table.insert(out, -length / 2 + (k + u) * w)
	end
	return out
end

-- Pure: gate z offsets for a kit TerraceRowVictorian row (row frame). Door
-- positions are not measured: ASSUMED 8 mirrored houses with paired doors on
-- every other party wall. Symmetric, so it does not matter which side faces.
function TerraceStreetDresser.kitGateZs(length: number): { number }
	local out: { number } = {}
	for k = 1, KIT_HOUSES - 1, 2 do
		table.insert(out, -length / 2 + length * k / KIT_HOUSES)
	end
	return out
end

-- Pure: the front garden between a row (frame at the block centre, running
-- along local Z) and `road`. Tries the row's local -X as the front and, if
-- that faces away from the road, turns the frame 180 degrees. Nil unless both
-- ends of the front sit the same distance from the road (so the whole row
-- fronts it) and the gap to the pavement's back edge is in [MIN_GAP, MAX_GAP].
function TerraceStreetDresser.frontage(frame: CFrame, length: number, depth: number, road: TownLayout.Road): Frontage?
	local reach = pavementReach(road)
	local function dist(cf: CFrame, x: number, z: number): number
		return TownLayout.distanceToPolyline(cf:PointToWorldSpace(Vector3.new(x, 0, z)), road.points)
	end
	local cf = frame
	local flipped = false
	if dist(cf, -depth / 2 - 1, 0) > dist(cf, -depth / 2, 0) then
		cf *= CFrame.Angles(0, math.pi, 0)
		flipped = true
	end
	local g0 = dist(cf, -depth / 2, 0) - reach
	local g1 = dist(cf, -depth / 2, -length / 2) - reach
	local g2 = dist(cf, -depth / 2, length / 2) - reach
	if math.abs(g1 - g0) > 0.5 or math.abs(g2 - g0) > 0.5 then
		return nil
	end
	if g0 < TerraceStreetDresser.MIN_GAP or g0 > TerraceStreetDresser.MAX_GAP then
		return nil
	end
	return { cframe = cf, gap = g0, flipped = flipped }
end

-- Pure: the named town area nearest p (for the sign's district line).
function TerraceStreetDresser.areaName(p: Vector3): string
	local best, name = math.huge, "Rivermere"
	for _, district in TownLayout.DISTRICTS do
		if not table.find(AREAS, district.name) then
			continue
		end
		for _, block in district.blocks do
			local d = StreetDresser.distanceToBlock(p, block)
			if d < best then
				best, name = d, district.name
			end
		end
	end
	return name
end

-- Pure: the X ranges left of and right of `cut`.
local function rangeMinus(cut: { number }): { { number } }
	return { { -math.huge, cut[1] }, { cut[2], math.huge } }
end

-- Pure: distance from p to the part of a polyline inside an X range.
function TerraceStreetDresser.distanceInRange(p: Vector3, points: { Vector3 }, range: { number }?): number
	if not range then
		return TownLayout.distanceToPolyline(p, points)
	end
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local lo, hi = math.max(range[1], math.min(a.X, b.X)), math.min(range[2], math.max(a.X, b.X))
		if lo > hi then
			continue
		end
		if math.abs(b.X - a.X) < 1e-6 then
			best = math.min(best, TownLayout.segmentDistance(p, a, b))
		else
			local ta, tb = (lo - a.X) / (b.X - a.X), (hi - a.X) / (b.X - a.X)
			best = math.min(best, TownLayout.segmentDistance(p, a:Lerp(b, ta), a:Lerp(b, tb)))
		end
	end
	return best
end

-- ------------------------------------------------------------- instances

local partCount = 0

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
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
	return p
end

local function countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function tree(parent: Instance, spot: Spot, full: boolean, rng: Random): Model
	local m = Instance.new("Model")
	m.Name = "StreetTree"
	m:SetAttribute("Decor", true)
	m.Parent = parent
	local base = CFrame.new(spot.position.X, 0, spot.position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	-- pit 0.31..0.51: pokes 0.06 above the pavement top
	part(m, "TreePit", Vector3.new(2.4, 0.2, 2.4), base * CFrame.new(0, 0.41, 0), PIT, Enum.Material.Ground, false).CastShadow = false
	local h = rng:NextNumber(10, 12)
	local trunk = part(m, "Trunk", Vector3.new(0.7, h - 0.35, 0.7), base * CFrame.new(0, 0.35 + (h - 0.35) / 2, 0), TRUNK, Enum.Material.Wood, true)
	m.PrimaryPart = trunk
	local leaves = LEAVES[rng:NextInteger(1, #LEAVES)]
	local d1 = rng:NextNumber(7, 8)
	local crown = part(m, "Canopy", Vector3.one * d1, base * CFrame.new(0, h + d1 / 2 - 1.5, 0), leaves, Enum.Material.Grass, false)
	crown.Shape = Enum.PartType.Ball
	if full then
		-- X48: two offset lobes (one high, one low on the other side) instead of a
		-- ball stacked on a ball, so the crown reads leafy rather than lollipop
		local d2 = d1 * 0.7
		local lift = leaves:Lerp(Color3.new(1, 1, 0.8), 0.08)
		local top = part(m, "CanopyTop", Vector3.one * d2, base * CFrame.new(d1 * 0.3, h + d1 - 1.6, rng:NextNumber(-0.8, 0.8)), lift, Enum.Material.Grass, false)
		top.Shape = Enum.PartType.Ball
		top.CastShadow = false
		local d3 = d1 * 0.62
		local side = part(m, "CanopySide", Vector3.one * d3, base * CFrame.new(-d1 * 0.38, h + d1 * 0.35 - 1.2, rng:NextNumber(-0.8, 0.8)), leaves:Lerp(Color3.new(0, 0, 0), 0.06), Enum.Material.Grass, false)
		side.Shape = Enum.PartType.Ball
		side.CastShadow = false
	end
	return m
end

-- X74: a light street tree (pit, trunk, one crown; Decor) at a kerb spot, for
-- other dressers (EstateDresser's semis streets).
function TerraceStreetDresser.lightTree(parent: Instance, position: Vector3, rng: Random): Model
	return tree(parent, { position = position, direction = Vector3.new(0, 0, -1), side = 1 }, false, rng)
end

local function surfaceText(parent: Instance, text: string, font: Enum.Font, pos: UDim2, size: UDim2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = font
	label.Text = text
	label.TextColor3 = SIGN_BLACK
	label.TextScaled = true
	label.Parent = parent
end

local function sign(parent: Instance, cf: CFrame, roadName: string)
	local name = roadName:upper()
	local w = TerraceStreetDresser.plateWidth(name)
	local m = Instance.new("Model")
	m.Name = "StreetSign"
	m:SetAttribute("Road", roadName)
	m.Parent = parent
	local base = cf + Vector3.new(0, PAVEMENT_TOP, 0)
	-- plate: 0.2 thick, y 1.4..3.4 above the pavement; posts behind it, 0.05 into its back
	local plate = part(m, "Plate", Vector3.new(w, 2, 0.2), base * CFrame.new(0, 2.4, 0), SIGN_WHITE, Enum.Material.SmoothPlastic, true)
	m.PrimaryPart = plate
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		part(m, "Post", Vector3.new(0.3, 3.4, 0.3), base * CFrame.new(x, 3.4 / 2 - 0.2, 0.2), SIGN_BLACK, Enum.Material.Metal, true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = plate
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = SIGN_WHITE
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -12, 1, -12)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = SIGN_BLACK
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	surfaceText(frame, name, Enum.Font.GothamBold, UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.56))
	surfaceText(frame, TerraceStreetDresser.areaName(cf.Position), Enum.Font.Gotham, UDim2.fromScale(0.2, 0.66), UDim2.fromScale(0.6, 0.26))
end
-- X341: SignDresser plates the roads this pass never reaches, with the same
-- sign, so the town has one kind of street name plate.
TerraceStreetDresser.streetSign = sign

-- A garden wall segment in the wall frame (local -X toward the road, the wall's
-- road face at local x = wx - WALL_T / 2). kind: "railing" | "hedge" | "wall".
local function wallSegment(parent: Instance, frame: CFrame, wx: number, seg: Segment, kind: string, gap: number, piers: boolean)
	local len = seg.z1 - seg.z0
	local zc = (seg.z0 + seg.z1) / 2
	local wallTop = if kind == "railing" then 1.3 else 0.9
	part(parent, "GardenWall", Vector3.new(WALL_T, wallTop + 0.2, len), frame * CFrame.new(wx, (wallTop - 0.2) / 2, zc), BRICK, Enum.Material.Brick, true)
	-- coping sunk 0.05 into the wall top, 0.05 longer at each end
	local copingY = wallTop - 0.05 + 0.125
	if kind ~= "hedge" or piers then
		part(parent, "Coping", Vector3.new(COPING_T, 0.25, len + 0.1), frame * CFrame.new(wx, copingY, zc), COPING, Enum.Material.Limestone, false).CastShadow = false
	end
	if kind == "railing" then
		local r = Instance.new("Model")
		r.Name = "Railing"
		r:SetAttribute("Decor", true)
		r.Parent = parent
		local railY = 3.2
		part(r, "Rail", Vector3.new(0.25, 0.25, len - 0.4), frame * CFrame.new(wx, railY, zc), IRON, Enum.Material.Metal, false).CastShadow = false
		local bars = math.max(1, math.floor((len - 1) / 2))
		local barBottom = wallTop + 0.1 -- inside the coping (top at wallTop + 0.2)
		local barTop = railY + 0.05
		for k = 1, bars do
			local z = seg.z0 + len * k / (bars + 1)
			part(r, "Bar", Vector3.new(0.16, barTop - barBottom, 0.16), frame * CFrame.new(wx, (barTop + barBottom) / 2, z), IRON, Enum.Material.Metal, false).CastShadow = false
		end
	elseif kind == "hedge" and gap >= TerraceStreetDresser.HEDGE_GAP then
		-- behind the wall (garden side = +X), 0.05 clear of it, ends 0.3 short
		local hx = wx + WALL_T / 2 + 0.05 + HEDGE_T / 2
		part(parent, "Hedge", Vector3.new(HEDGE_T, 3.4, math.max(0.5, len - 0.6)), frame * CFrame.new(hx, 1.6, zc), HEDGE, Enum.Material.Grass, true)
	end
	if piers then
		-- railing piers rise past the top rail so its ends die into them
		local pierTop = if kind == "railing" then 3.5 else 2.4
		for _, z in { seg.z0, seg.z1 } do
			part(parent, "Pier", Vector3.new(PIER, pierTop + 0.2, PIER), frame * CFrame.new(wx, (pierTop - 0.2) / 2, z), BRICK, Enum.Material.Brick, true)
		end
	end
end

type RowFront = { frontage: Frontage, length: number, depth: number, kit: boolean, facade: string? }

local function garden(parent: Instance, front: RowFront, full: boolean, rng: Random)
	local fr = front.frontage
	-- road face of the wall WALL_SETBACK behind the pavement's back edge
	local wx = -(front.depth / 2 + fr.gap) + WALL_SETBACK + WALL_T / 2
	local gates: { number }
	if front.kit then
		gates = TerraceStreetDresser.kitGateZs(front.length)
	elseif fr.flipped then
		gates = {} -- the row's back faces this street (its doors face another): a solid rear wall
	else
		gates = TerraceStreetDresser.lightDoorZs(front.length, front.facade)
	end
	local m = Instance.new("Model")
	m.Name = "FrontGarden"
	m.Parent = parent
	for _, seg in TerraceStreetDresser.gateSegments(front.length, gates, TerraceStreetDresser.GATE_WIDTH) do
		local kind: string
		if fr.gap < TerraceStreetDresser.HEDGE_GAP then
			kind = if full then "railing" else "wall"
		elseif full then
			kind = if rng:NextNumber() < 0.55 then "railing" else "hedge"
		else
			kind = "hedge"
		end
		-- piers at both ends of every full-detail segment (gate sides and row ends)
		wallSegment(m, fr.cframe, wx, seg, kind, fr.gap, full)
	end
end

local function car(parent: Instance, spot: Spot, rng: Random)
	local pos = spot.position + Vector3.new(0, 0.25, 0)
	local facing = if rng:NextNumber() < 0.8 then spot.direction else -spot.direction
	KitPlacer.place(CAR_KITS[rng:NextInteger(1, #CAR_KITS)], CFrame.lookAt(pos, pos + facing), parent, {
		fallbackSize = Vector3.new(6, 5, 12),
		fallbackColor = Color3.fromRGB(90, 100, 120),
		yawJitter = math.rad(2),
		rng = rng,
	})
end

type Entry = { road: TownLayout.Road, range: { number }?, full: boolean, fronts: { RowFront } }

-- Terraced-row fronts along a street (X range on the block centre).
local function frontsFor(road: TownLayout.Road, range: { number }?, facades: { [string]: string }): { RowFront }
	local out: { RowFront } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use ~= "terraced row" or not inRange(block.centre.X, range) then
				continue
			end
			local length = math.max(block.size.X, block.size.Z)
			local depth = math.min(block.size.X, block.size.Z)
			-- cheap distance check first: lightRowPlacement measures every road
			if TownLayout.distanceToPolyline(Vector3.new(block.centre.X, 0, block.centre.Z), road.points) > pavementReach(road) + depth / 2 + TerraceStreetDresser.MAX_GAP + 1 then
				continue
			end
			local kit = StreetDresser.isKitRow(district.name, block)
			local frame = if kit then (StreetDresser.rowPlacement(block)) else StreetDresser.lightRowPlacement(block)
			local fr = TerraceStreetDresser.frontage(frame, length, depth, road)
			if fr then
				local key = ("%d,%d"):format(math.round(block.centre.X), math.round(block.centre.Z))
				table.insert(out, { frontage = fr, length = length, depth = depth, kit = kit, facade = facades[key] })
			end
		end
	end
	return out
end

-- True when a tree pit here would sit on or right against a layout block.
local function onBlock(p: Vector3): boolean
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			local r = math.max(block.size.X, block.size.Z) / 2 + 2
			if math.abs(block.centre.X - p.X) < r and math.abs(block.centre.Z - p.Z) < r and StreetDresser.distanceToBlock(p, block) < 2 then
				return true
			end
		end
	end
	return false
end

local function dressEntry(entry: Entry, parent: Instance, roads: { TownLayout.Road }, isKitStreet: boolean, rng: Random)
	local road, full = entry.road, entry.full
	local lamps = StreetDresser.lampPositions(road)
	for _, cf in TerraceStreetDresser.signSpots(road, roads) do
		if inRange(cf.Position.X, entry.range) then
			sign(parent, cf, road.name)
		end
	end
	if not TerraceStreetDresser.V3_HOUSING_RETIRED then
		for _, front in entry.fronts do
			garden(parent, front, full, rng)
		end
	end
	for _, spot in TerraceStreetDresser.treeSpots(road, if full then 40 else 56, entry.range, lamps, roads, onBlock) do
		tree(parent, spot, full, rng)
	end
	if TerraceStreetDresser.V3_PARKED_CARS_RETIRED then
		return
	end
	-- StreetDresser parks the showpiece's cars on the right-hand kerb (+1)
	local sides = if full and isKitStreet then { -1 } else { -1, 1 }
	for _, side in sides do
		local spots = if full
			then TerraceStreetDresser.carSpots(road, side, entry.range, roads, rng, 3, 22, 0.25)
			else TerraceStreetDresser.carSpots(road, side, entry.range, roads, rng, 10, 60, 0.45)
		for _, spot in spots do
			car(parent, spot, rng)
		end
	end
end

-- Returns a summary line for the log.
function TerraceStreetDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "terrace streets: no town"
	end
	local old = town:FindFirstChild("TerraceStreets")
	if old then
		old:Destroy()
	end
	partCount = 0
	local root = Instance.new("Folder")
	root.Name = "TerraceStreets"

	-- facade keys of StreetDresser's TerraceBuilder rows, by block centre
	local facades: { [string]: string } = {}
	local dressing = town:FindFirstChild("Dressing")
	if dressing then
		for _, d in dressing:GetDescendants() do
			if d:IsA("Model") and d.Name == "TerraceRow" and d.PrimaryPart then
				local facade = d:GetAttribute("Facade")
				local p = (d.PrimaryPart :: BasePart).Position
				if type(facade) == "string" then
					facades[("%d,%d"):format(math.round(p.X), math.round(p.Z))] = facade
				end
			end
		end
	end

	local roads = TownLayout.ROADS
	local kitNames: { [string]: boolean } = {}
	local kitRanges: { [string]: { number } } = {}
	local entries: { Entry } = {}
	for _, spec in StreetDresser.DRESSED do
		for _, name in spec.streets do
			for _, road in roads do
				if road.name == name then
					kitNames[name] = true
					if spec.xRange then
						kitRanges[name] = spec.xRange
					end
					table.insert(entries, { road = road, range = spec.xRange, full = true, fronts = frontsFor(road, spec.xRange, facades) })
				end
			end
		end
	end
	local light: { { entry: Entry, distance: number } } = {}
	local centre = TownLayout.SQUARE.centre
	local function consider(road: TownLayout.Road, range: { number }?)
		local fronts = frontsFor(road, range, facades)
		if #fronts > 0 then
			table.insert(light, {
				entry = { road = road, range = range, full = false, fronts = fronts },
				distance = TerraceStreetDresser.distanceInRange(centre, road.points, range),
			})
		end
	end
	for _, road in roads do
		if road.kind ~= "residential" then
			continue
		end
		if not kitNames[road.name] then
			consider(road, nil)
		elseif kitRanges[road.name] then
			-- the kit street beyond its showpiece stretch
			for _, range in rangeMinus(kitRanges[road.name]) do
				consider(road, range)
			end
		end
	end
	table.sort(light, function(a, b)
		return a.distance < b.distance
	end)

	local rng = Random.new(1911)
	local full, streets, skipped = 0, 0, 0
	local parked: { string } = {}
	for _, entry in entries do
		local m = Instance.new("Model")
		m.Name = entry.road.name
		m.Parent = root
		table.insert(parked, entry.road.name)
		dressEntry(entry, m, roads, true, rng)
		local n = countParts(m)
		partCount += n
		full += n
	end
	local function dressLight(priority: boolean, budget: number)
		for _, item in light do
			local e = item.entry
			if (table.find(TerraceStreetDresser.PRIORITY_STREETS, e.road.name) ~= nil) ~= priority then
				continue
			end
			if budget - partCount < MIN_STREET_PARTS then
				break
			end
			local m = Instance.new("Model")
			m.Name = e.road.name .. (if e.range then " (light)" else "")
			dressEntry(e, m, roads, false, rng)
			local n = countParts(m)
			if partCount + n > budget then
				m:Destroy()
				skipped += 1
				continue -- a shorter street further out may still fit
			end
			m.Parent = root
			partCount += n
			streets += 1
			table.insert(parked, e.road.name)
		end
	end
	dressLight(false, TerraceStreetDresser.PART_BUDGET)
	dressLight(true, math.max(partCount, TerraceStreetDresser.PART_BUDGET) + TerraceStreetDresser.PRIORITY_RESERVE)
	-- X36: client Traffic keeps off streets with cars parked on both kerbs
	-- v3: this dresser parks nothing now; StreetFurniture publishes the real list
	root:SetAttribute("ParkedStreets", if TerraceStreetDresser.V3_PARKED_CARS_RETIRED then "" else table.concat(parked, "|"))
	root.Parent = town
	return ("terrace streets: %d parts (showpiece %d), %d light streets, %d over budget"):format(partCount, full, streets, skipped)
end

return TerraceStreetDresser
