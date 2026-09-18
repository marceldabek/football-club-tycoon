--!strict
-- Rivermere market square (backlog E1.1). Reference: assets/references/
-- RivermereCenter.png — a stone clock tower in the middle, stone planters full
-- of flowers, black bollards and lamp posts, wooden benches, and (from
-- RivermereAImap.png) a ring of white market stalls round the square.
--
-- Built on top of TownBuilder's paved disc (TownLayout.SQUARE, top at y 0.25)
-- into workspace.Town.Square. Mostly primitives, kit where it is cheap:
--   ClockTower  ~14 parts, centre       Stalls  10 x 7 parts on a ring
--   Planters    6 x 3 parts             Benches 6 kit benches (1 mesh each)
--   Bollards    24 x 1 part on the rim  Lamps   4 kit lamps
--   FingerPost  post + finial + 2 parts per blade, pointing at real places (X46)
-- Layout (radius from the square centre; the square is 60):
--   0..7 tower base   14..20 planters + benches   38..48 stalls   51 finger post
--   57 bollards

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)
local Planting = require(script.Parent.Planting)

local SquareDresser = {}

local TOP = 0.25 -- TownBuilder.Y.SQUARE
local STONE = Color3.fromRGB(206, 196, 176)
local STONE_DARK = Color3.fromRGB(170, 160, 142)
local IRON = Color3.fromRGB(24, 24, 26)
local SOIL = Color3.fromRGB(80, 58, 40)
local FLOWERS = {
	Color3.fromRGB(214, 60, 90),
	Color3.fromRGB(240, 170, 50),
	Color3.fromRGB(160, 80, 200),
	Color3.fromRGB(245, 245, 245),
}
local STALL_COLOURS = { Color3.fromRGB(30, 60, 120), Color3.fromRGB(180, 40, 40), Color3.fromRGB(40, 110, 60) }

local STALL_COUNT = 10
local STALL_RING = 43
local PLANTER_RING = 17
local BOLLARD_RING = 57
local BOLLARD_COUNT = 24

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
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

-- A box from extents in a local frame (x across, y up, z along).
local function slab(parent: Instance, frame: CFrame, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, colour: Color3, material: Enum.Material?): BasePart
	return part({
		Name = name,
		Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Color = colour,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- Pure: `count` CFrames evenly round a circle of `radius`, each facing the
-- centre, starting at angle `offset` (radians).
function SquareDresser.ring(centre: Vector3, radius: number, count: number, offset: number?): { CFrame }
	local out = {}
	for i = 0, count - 1 do
		local a = (offset or 0) + i / count * math.pi * 2
		local pos = centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		table.insert(out, CFrame.lookAt(pos, Vector3.new(centre.X, pos.Y, centre.Z)))
	end
	return out
end

-- The finger post (X46) stands between two stalls at angle 0 and points at
-- these (a bus stop or landmark name from TownLayout); blades step down the post.
-- X112: a red K6 phone box on the square (free Creator Store model, MANIFEST),
-- between the stalls at 54 and 90 degrees and inside the bollards, clear of
-- Bridge Street's mouth at 90 degrees. Scaled from 11.4 to about 7 studs tall.
SquareDresser.PHONE_BOX_RING = 50
SquareDresser.PHONE_BOX_ANGLE = math.rad(72)
local PHONE_BOX_SCALE = 0.62

local FINGER_RING = 51
local FINGER_DESTINATIONS = { "Station", "Riverside", "Lune Bridge", "Church Spire" }
local SIGN_WHITE = Color3.fromRGB(242, 242, 236)

-- Where a finger post destination is: a bus stop or landmark position, or nil.
function SquareDresser.destination(name: string): Vector3?
	for _, stop in TownLayout.BUS_STOPS do
		if stop.name == name then
			return stop.position
		end
	end
	for _, landmark in TownLayout.LANDMARKS do
		if landmark.name == name then
			return landmark.position
		end
	end
	return nil
end

-- Pure: a blade `length` long at height `y`, starting at the post (`from`) and
-- pointing flat at `to`. The CFrame is the blade centre, LookVector along it.
function SquareDresser.bladeFrame(from: Vector3, to: Vector3, y: number, length: number): CFrame
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dir = if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(0, 0, -1)
	local centre = Vector3.new(from.X, y, from.Z) + dir * (length / 2 + 0.2)
	return CFrame.lookAt(centre, centre + dir)
end

local function bladeLabel(blade: BasePart, face: Enum.NormalId, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = blade
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(20, 20, 24)
	label.Text = text
	label.Parent = gui
end

-- A finger post at `at` standing on `groundY` (default the square's paving).
-- `destinations` (default the square's) are names SquareDresser.destination
-- resolves, or { name, position } pairs for places that aren't a stop or
-- landmark; unresolved names are skipped. X73 uses it at the station too.
export type FingerDestination = string | { name: string, position: Vector3 }
function SquareDresser.fingerPost(parent: Instance, at: Vector3, groundY: number?, destinations: { FingerDestination }?)
	local ground = groundY or TOP
	local m = Instance.new("Model")
	m.Name = "FingerPost"
	m.Parent = parent
	part({
		Name = "Post",
		Size = Vector3.new(0.5, 11, 0.5),
		CFrame = CFrame.new(at.X, ground + 5.5 - 0.05, at.Z),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Finial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = CFrame.new(at.X, ground + 11.2, at.Z),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	local length = 6
	local row = 0
	for _, entry in destinations or FINGER_DESTINATIONS do
		local name: string, target: Vector3?
		if type(entry) == "string" then
			name, target = entry, SquareDresser.destination(entry)
		else
			name, target = entry.name, entry.position
		end
		if not target then
			continue
		end
		row += 1
		local y = ground + 10 - (row - 1) * 1.15
		local cf = SquareDresser.bladeFrame(at, target, y, length)
		local blade = part({
			Name = "Blade",
			Size = Vector3.new(0.2, 0.9, length),
			CFrame = cf,
			Color = SIGN_WHITE,
			Parent = m,
		})
		-- the blade reads from both sides; the pointed tip shows the way
		bladeLabel(blade, Enum.NormalId.Left, name)
		bladeLabel(blade, Enum.NormalId.Right, name)
		local tip = Instance.new("WedgePart")
		tip.Name = "Tip"
		tip.Anchored = true
		tip.Size = Vector3.new(0.2, 0.9, 0.8)
		-- a wedge is full height at its local +Z (towards the blade here) and
		-- slopes down to its -Z edge, which points onwards
		tip.CFrame = cf * CFrame.new(0, 0, -length / 2 - 0.4)
		tip.Color = SIGN_WHITE
		tip.Material = Enum.Material.SmoothPlastic
		tip.Parent = m
	end
end

-- X47: hanging flower baskets on the lamp posts round the town centre, like
-- RivermereCenter.png. Lamps are StreetDresser's TerraceLamp models (arm on
-- local -Z, so the basket hangs off +Z) and the kit lamps (arms across X, basket on +Z).
local BASKET_RADIUS = 420 -- TEMP: studs from the square centre (reaches the Mill Street lamps)
local BASKET_MAX = 30
local BASKET_Y = 9.4

-- Pure: which lamps get a basket: the nearest `max` within `radius` of `centre`.
function SquareDresser.basketLamps(centre: Vector3, positions: { Vector3 }, radius: number, max: number): { number }
	local picks = {}
	for i, p in positions do
		local d = Vector3.new(p.X - centre.X, 0, p.Z - centre.Z).Magnitude
		if d <= radius then
			table.insert(picks, { index = i, distance = d })
		end
	end
	table.sort(picks, function(a, b)
		return a.distance < b.distance
	end)
	local out = {}
	for k = 1, math.min(max, #picks) do
		table.insert(out, picks[k].index)
	end
	return out
end

local function hangBasket(parent: Instance, post: CFrame, colour: Color3)
	local m = Instance.new("Model")
	m.Name = "LampBasket"
	m:SetAttribute("Decor", true)
	m.Parent = parent
	part({
		Name = "Bracket",
		Size = Vector3.new(0.2, 0.2, 1.5),
		CFrame = post * CFrame.new(0, BASKET_Y + 1.1, 0.85),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Basket",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = post * CFrame.new(0, BASKET_Y, 1.45),
		Color = colour,
		Material = Enum.Material.Grass,
		CastShadow = false,
		Parent = m,
	})
end

local function dressLampBaskets(town: Instance, square: Instance, centre: Vector3, rng: Random): number
	local posts: { CFrame } = {}
	for _, d in town:GetDescendants() do
		if d:IsA("Model") then
			if d.Name == "TerraceLamp" and d.PrimaryPart then
				local pivot = d.PrimaryPart.CFrame * CFrame.Angles(0, 0, -math.pi / 2) -- undo the upright cylinder turn
				local p = pivot.Position
				table.insert(posts, CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, 0, p.Z) + Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)))
			elseif d:GetAttribute("Kit") == "LampVictorian" then
				local cf = d:GetBoundingBox()
				table.insert(posts, CFrame.new(cf.X, TOP, cf.Z))
			end
		end
	end
	local positions = {}
	for _, post in posts do
		table.insert(positions, post.Position)
	end
	local count = 0
	for _, index in SquareDresser.basketLamps(centre, positions, BASKET_RADIUS, BASKET_MAX) do
		local post = posts[index]
		-- terrace lamps stand on the pavement (their CFrame is at ground level)
		hangBasket(square, post, FLOWERS[rng:NextInteger(1, #FLOWERS)])
		count += 1
	end
	return count
end

local function clockFace(target: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = target
	-- X68: a round dial with XII / III / VI / IX and two hands (it was one
	-- TextLabel reading "XII · 3 ·", which scaled into a garbled "XI 3"). The
	-- hands show the same time as the station clock.
	local ink = Color3.fromRGB(20, 20, 20)
	local dial = Instance.new("Frame")
	dial.AnchorPoint = Vector2.new(0.5, 0.5)
	dial.Position = UDim2.fromScale(0.5, 0.5)
	dial.Size = UDim2.fromScale(0.86, 0.86)
	dial.BackgroundColor3 = Color3.fromRGB(245, 242, 232)
	dial.BorderSizePixel = 0
	dial.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = dial
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dial
	local rim = Instance.new("UIStroke")
	rim.Color = ink
	rim.Thickness = 4
	rim.Parent = dial
	for i, numeral in { "XII", "III", "VI", "IX" } do
		local angle = math.rad((i - 1) * 90)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5 + 0.36 * math.sin(angle), 0.5 - 0.36 * math.cos(angle))
		label.Size = UDim2.fromScale(0.22, 0.16)
		label.BackgroundTransparency = 1
		label.TextColor3 = ink
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.Text = numeral
		label.Parent = dial
	end
	-- a full-size holder rotates about the dial centre; the hand runs up from it
	for _, hand in { { rotation = 85, length = 0.22, width = 0.05 }, { rotation = 300, length = 0.33, width = 0.03 } } do
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Rotation = hand.rotation
		holder.Parent = dial
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(hand.width, hand.length)
		bar.BackgroundColor3 = ink
		bar.BorderSizePixel = 0
		bar.Parent = holder
	end
end

local function buildClockTower(parent: Instance, centre: Vector3)
	local m = Instance.new("Model")
	m.Name = "ClockTower"
	m.Parent = parent
	local f = CFrame.new(centre.X, TOP, centre.Z)
	-- stepped plinth, shaft, clock stage, cornice, cupola and weather vane
	slab(m, f, "Step", -7, 7, 0, 1, -7, 7, STONE_DARK, Enum.Material.Slate)
	slab(m, f, "Plinth", -5, 5, 1, 4, -5, 5, STONE, Enum.Material.Limestone)
	slab(m, f, "Shaft", -3.5, 3.5, 4, 26, -3.5, 3.5, STONE, Enum.Material.Limestone)
	local stage = slab(m, f, "ClockStage", -4.2, 4.2, 26, 34, -4.2, 4.2, STONE, Enum.Material.Limestone)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		clockFace(stage, face)
	end
	slab(m, f, "Cornice", -5, 5, 34, 35.2, -5, 5, STONE_DARK, Enum.Material.Slate)
	slab(m, f, "Belfry", -3, 3, 35.2, 40, -3, 3, STONE, Enum.Material.Limestone)
	part({
		Name = "Cupola",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6.4, 6.4, 6.4),
		CFrame = f * CFrame.new(0, 41, 0),
		Color = Color3.fromRGB(70, 110, 100),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	slab(m, f, "VaneRod", -0.15, 0.15, 44.2, 48, -0.15, 0.15, IRON, Enum.Material.Metal)
	slab(m, f, "VaneArrow", -2, 2, 46.5, 46.8, -0.1, 0.1, IRON, Enum.Material.Metal)
end

local function buildPlanter(parent: Instance, cf: CFrame, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Planter"
	m.Parent = parent
	local f = cf * CFrame.new(0, TOP, 0)
	slab(m, f, "Box", -5, 5, 0, 2.6, -2.5, 2.5, STONE, Enum.Material.Limestone)
	slab(m, f, "Soil", -4.4, 4.4, 2.6, 2.8, -1.9, 1.9, SOIL, Enum.Material.Ground)
	-- X69: a planted bed over the soil (a Ball's diameter is its smallest axis,
	-- so the old 8.4 x 2.6 x 3.8 ball rendered as one 2.6 ball in bare soil)
	-- X130: a leafy bed with round flower heads (RivermereStation.png planters)
	Planting.bloom(m, f * CFrame.new(0, 3.3, 0), 8.6, 3.6, FLOWERS[rng:NextInteger(1, #FLOWERS)], rng)
end

-- X138 (RivermereCenter.png market): three produce crates on each counter,
-- each heaped with round fruit or veg, a different mix per stall
local PRODUCE = {
	{ Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 150, 40), Color3.fromRGB(110, 170, 60) }, -- apples, oranges, greens
	{ Color3.fromRGB(230, 200, 60), Color3.fromRGB(120, 60, 110), Color3.fromRGB(180, 40, 60) }, -- lemons, plums, tomatoes
	{ Color3.fromRGB(170, 120, 70), Color3.fromRGB(90, 150, 60), Color3.fromRGB(240, 220, 200) }, -- potatoes, cabbage, onions
}

local function buildStall(parent: Instance, cf: CFrame, colour: Color3, index: number)
	local m = Instance.new("Model")
	m.Name = "MarketStall"
	m.Parent = parent
	-- local -Z faces the centre of the square (the shoppers' side)
	local f = cf * CFrame.new(0, TOP, 0)
	slab(m, f, "Counter", -5, 5, 0, 3.2, -2, 1, Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
	local mix = PRODUCE[(index - 1) % #PRODUCE + 1]
	for c = 1, 3 do
		local cx = -3 + (c - 1) * 3
		slab(m, f, "Crate", cx - 1.3, cx + 1.3, 3.2, 3.8, -1.7, 0.5, Color3.fromRGB(176, 136, 90), Enum.Material.WoodPlanks)
		-- produce balls sit in the crate, tops just proud of its rim
		for k = 0, 3 do
			local px = cx - 0.6 + (k % 2) * 1.2
			local pz = -1.15 + math.floor(k / 2) * 1.1
			part({
				Name = "Goods",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.1,
				CFrame = f * CFrame.new(px, 3.75, pz),
				Color = mix[c],
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
				Parent = m,
			})
		end
	end
	for _, x in { -4.8, 4.8 } do
		slab(m, f, "Pole", x - 0.15, x + 0.15, 0, 8, 1.6, 1.9, Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
	end
	-- canopy: a white sheet with a coloured valance at the front
	slab(m, f, "Canopy", -5.6, 5.6, 8, 8.4, -3.2, 2.4, Color3.fromRGB(245, 245, 240), Enum.Material.Fabric)
	slab(m, f, "Valance", -5.6, 5.6, 7.2, 8, -3.2, -2.9, colour, Enum.Material.Fabric)
end

-- The church (backlog E9.1): the kit church with its broach spire replaces
-- TownBuilder's greybox nave and tiered spire. Scaled so the spire tip sits
-- at the landmark height; turned so the nave runs along the layout block.
local CHURCH_KIT = "ChurchSpire" -- 163 x 202 x 77, nave along its local X (MANIFEST)
local CHURCH_KIT_HEIGHT = 202

-- X319: the church is one of the three landmarks every sightline in town was
-- planned around (E9.1, Q5), and it stood on plain mown grass - no wall, no
-- path, no graves - so the closer you walked the less it read as a church.
-- A churchyard round it: a low stone wall with a lychgate on the road side, a
-- flagged path to the door, headstones on the grass, a noticeboard and two
-- yews. The kit church is 105 studs along the street and 50 deep, and the
-- terraced rows either side come within about four studs of its gables, so the
-- yard is walled along its two long sides only and measured off the building
-- rather than off the layout block.
local YARD_MARGIN = 18
local YARD_WALL_H = 2.4
local YARD_WALL_T = 1.2
local GATE_GAP = 12
local GRAVE_STONE = Color3.fromRGB(176, 172, 160)
local YEW = Color3.fromRGB(38, 72, 46)
-- The kit church model carries the parish name ("St. Peter's"); the fallback is
-- only for a greybox church that has none.
local PARISH_FALLBACK = "THE PARISH CHURCH"

local function parishName(town: Instance): string
	local church = town:FindFirstChild("Church")
	for _, d in (church and church:GetChildren() or {}) do
		if d:IsA("Model") and d.Name:find("%a") and d.Name ~= "Church" then
			return string.upper(d.Name)
		end
	end
	return PARISH_FALLBACK
end

-- The church's footprint in world axes. The kit is placed with a yaw, so its
-- model bounding box is in the building's own frame (105 along the nave, 50
-- across) and says nothing about which way that is on the map.
local function worldFootprint(model: Instance): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, 0, math.huge)
	local maxV = Vector3.new(-math.huge, 0, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local s = p.Size / 2
			local cf = p.CFrame
			local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
			local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
			minV = Vector3.new(math.min(minV.X, p.Position.X - ex), 0, math.min(minV.Z, p.Position.Z - ez))
			maxV = Vector3.new(math.max(maxV.X, p.Position.X + ex), 0, math.max(maxV.Z, p.Position.Z + ez))
		end
	end
	return minV, maxV
end

-- Which way the nearest road lies, as a unit axis: the lychgate goes there.
-- Only sides that got a wall are candidates (`room` is keyed by wall name).
local function wallOf(out: Vector3): string
	if out.X < -0.5 then
		return "WallW"
	elseif out.X > 0.5 then
		return "WallE"
	elseif out.Z < -0.5 then
		return "WallN"
	end
	return "WallS"
end

local SIDE_AXES = {
	Vector3.new(-1, 0, 0),
	Vector3.new(1, 0, 0),
	Vector3.new(0, 0, -1),
	Vector3.new(0, 0, 1),
}

local function roadSide(centre: Vector3, hx: number, hz: number, room: { [string]: number }): Vector3
	local best, bestD = nil, math.huge
	for _, axis in SIDE_AXES do
		if room[wallOf(axis)] then
			local edge = centre + Vector3.new(axis.X * hx, 0, axis.Z * hz)
			for _, road in TownLayout.ROADS do
				local d = TownLayout.distanceToPolyline(edge, road.points)
				if d < bestD then
					bestD, best = d, axis
				end
			end
		end
	end
	return best or Vector3.new(0, 0, 1)
end

-- Probe band: from just above the kerb to head height, so the grass, the
-- pavement and the road do not count but buildings, trees and lamps do.
local PROBE_Y0, PROBE_Y1 = 0.6, 5.2

local function probeClear(at: Vector3, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.MaxParts = 4
	return #workspace:GetPartBoundsInBox(CFrame.new(at + Vector3.new(0, (PROBE_Y0 + PROBE_Y1) / 2, 0)), size, params) == 0
end

-- The furthest clear line for one side's wall, walking outward from the
-- building, or nil when that side has no room at all - the church is hemmed in
-- by terraced rows and two of its four sides usually are. `out` points from the
-- church towards the side being measured.
local function fitSide(centre: Vector3, out: Vector3, least: number, want: number, across: number, ignore: { Instance }): number?
	local size = Vector3.new(
		if math.abs(out.X) > 0.5 then 3 else across * 2,
		PROBE_Y1 - PROBE_Y0,
		if math.abs(out.X) > 0.5 then across * 2 else 3
	)
	local best: number? = nil
	for half = least, want, 2 do
		if probeClear(centre + out * half, size, ignore) then
			best = half
		elseif best then
			break -- past the last clear line: the terrace starts here
		end
	end
	return best
end

local function headstone(parent: Instance, at: Vector3, rng: Random)
	local w = rng:NextNumber(1.6, 2.4)
	local h = rng:NextNumber(2.2, 3.6)
	local stone = part({
		Name = "Headstone",
		Size = Vector3.new(w, h, 0.4),
		CFrame = CFrame.new(at + Vector3.new(0, h / 2 - 0.15, 0))
			* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.06, 0.06)),
		Color = GRAVE_STONE:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.18)),
		Material = Enum.Material.Limestone,
		Parent = parent,
	})
	stone.CanCollide = false
	return stone
end

local function yew(parent: Instance, at: Vector3, rng: Random)
	local h = rng:NextNumber(7, 9)
	part({
		Name = "YewTrunk",
		Size = Vector3.new(1.4, h, 1.4),
		CFrame = CFrame.new(at + Vector3.new(0, h / 2 - 0.2, 0)),
		Color = Color3.fromRGB(72, 56, 42),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local d = rng:NextNumber(7, 9)
	local canopy = part({
		Name = "YewCanopy",
		Size = Vector3.new(d, d * 0.9, d),
		CFrame = CFrame.new(at + Vector3.new(0, h + d * 0.35, 0)),
		Color = YEW,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	canopy.CanCollide = false
end

local function dressChurchyard(town: Instance, church: Instance?, block: any): number
	local yard = Instance.new("Model")
	yard.Name = "Churchyard"
	yard:SetAttribute("Decor", true)
	local rng = Random.new(1642)

	local centre, halfX, halfZ
	if church then
		local minV, maxV = worldFootprint(church)
		centre = Vector3.new((minV.X + maxV.X) / 2, 0, (minV.Z + maxV.Z) / 2)
		halfX, halfZ = (maxV.X - minV.X) / 2, (maxV.Z - minV.Z) / 2
	else
		centre = Vector3.new(block.centre.X, 0, block.centre.Z)
		halfX, halfZ = block.size.X / 2, block.size.Z / 2
	end

	local ignore: { Instance } = { yard }
	-- Each side is measured on its own: a wall goes up only where there is
	-- grass for it, and the gate goes on whichever walled side faces a road.
	local AXES = {
		{ name = "WallW", out = Vector3.new(-1, 0, 0) },
		{ name = "WallE", out = Vector3.new(1, 0, 0) },
		{ name = "WallN", out = Vector3.new(0, 0, -1) },
		{ name = "WallS", out = Vector3.new(0, 0, 1) },
	}
	local room: { [string]: number } = {}
	for _, side in AXES do
		local half = if math.abs(side.out.X) > 0.5 then halfX else halfZ
		local across = if math.abs(side.out.X) > 0.5 then halfZ else halfX
		local fit = fitSide(centre, side.out, half + 4, half + YARD_MARGIN, across + 2, ignore)
		if fit then
			room[side.name] = fit
		end
	end
	if not next(room) then
		yard:Destroy()
		return 0
	end
	-- the rectangle the graves and the path live in: the nearest wall each way,
	-- falling back to a few studs of grass where there is no wall
	local hx = math.min(room.WallW or (halfX + 4), room.WallE or (halfX + 4))
	local hz = math.min(room.WallN or (halfZ + 4), room.WallS or (halfZ + 4))
	local gate = roadSide(centre, hx, hz, room)
	local along = Vector3.new(-gate.Z, 0, gate.X)
	local inward = -gate

	local function wall(name: string, from: Vector3, to: Vector3)
		local span = to - from
		if span.Magnitude < 2 then
			return
		end
		part({
			Name = name,
			Size = Vector3.new(math.max(math.abs(span.X), YARD_WALL_T), YARD_WALL_H, math.max(math.abs(span.Z), YARD_WALL_T)),
			CFrame = CFrame.new((from.X + to.X) / 2, YARD_WALL_H / 2, (from.Z + to.Z) / 2),
			Color = STONE_DARK,
			Material = Enum.Material.Cobblestone,
			Parent = yard,
		})
	end
	local gateCentre = centre + gate * (room[wallOf(gate)] or hz)
	for _, side in AXES do
		local at = room[side.name]
		if not at then
			continue -- no room on that side; the gable nearly touches the terrace
		end
		-- the wall runs the length of the yard across its own axis
		local run = if math.abs(side.out.X) > 0.5 then hz else hx
		local across = Vector3.new(-side.out.Z, 0, side.out.X)
		local a = centre + side.out * at - across * run
		local b = centre + side.out * at + across * run
		if wallOf(side.out) == wallOf(gate) then
			-- review of X319: `across` is the same vector as `along` on this
			-- side, so these two ends were swapped - the pair covered the whole
			-- frontage twice over and bricked the gateway up
			wall(side.name .. "A", a, gateCentre - along * (GATE_GAP / 2))
			wall(side.name .. "B", gateCentre + along * (GATE_GAP / 2), b)
		else
			wall(side.name, a, b)
		end
	end

	-- the lychgate over the gap
	local postY = 5.2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local at = gateCentre + along * (sx * (GATE_GAP / 2 - 0.6)) + inward * (sz * 2.4)
			part({
				Name = "GatePost",
				Size = Vector3.new(0.9, postY, 0.9),
				CFrame = CFrame.new(at.X, postY / 2, at.Z),
				Color = Color3.fromRGB(96, 70, 48),
				Material = Enum.Material.Wood,
				Parent = yard,
			})
		end
	end
	part({
		Name = "GateLintel",
		Size = Vector3.new(math.max(math.abs(along.X) * GATE_GAP, 1.2), 0.8, math.max(math.abs(along.Z) * GATE_GAP, 1.2)),
		CFrame = CFrame.new(gateCentre.X, postY + 0.4, gateCentre.Z),
		Color = Color3.fromRGB(96, 70, 48),
		Material = Enum.Material.Wood,
		Parent = yard,
	})
	for _, sz in { -1, 1 } do
		local roof = part({
			Name = "GateRoof",
			Size = Vector3.new(
				if math.abs(along.X) > 0.5 then GATE_GAP + 3 else 6,
				0.4,
				if math.abs(along.X) > 0.5 then 6 else GATE_GAP + 3
			),
			-- pitched, not a table top: the halves meet over the ridge and fall
			-- away either side
			CFrame = CFrame.new(gateCentre + inward * (sz * 2.5) + Vector3.new(0, postY + 1.9, 0))
				* CFrame.fromAxisAngle(along, sz * 0.62),
			Color = Color3.fromRGB(78, 64, 58),
			Material = Enum.Material.Slate,
			Parent = yard,
		})
		roof.CanCollide = false
	end

	-- the flagged path from the gate to the church wall
	local reach = (room[wallOf(gate)] or hz) - (if math.abs(gate.X) > 0.5 then halfX else halfZ)
	local pathMid = gateCentre + inward * (reach / 2)
	part({
		Name = "Path",
		Size = Vector3.new(if math.abs(gate.X) > 0.5 then reach else 6, 0.2, if math.abs(gate.X) > 0.5 then 6 else reach),
		CFrame = CFrame.new(pathMid.X, 0.1, pathMid.Z),
		Color = Color3.fromRGB(186, 180, 168),
		Material = Enum.Material.Slate,
		Parent = yard,
	})

	-- headstones on whatever grass is left, each one probed: the first version
	-- buried one inside a terraced house and another in a tree
	local placed = 0
	for _ = 1, 120 do
		if placed >= 14 then
			break
		end
		local x = rng:NextNumber(-hx + 4, hx - 4)
		local z = rng:NextNumber(-hz + 4, hz - 4)
		local onPath = math.abs(if math.abs(gate.X) > 0.5 then z else x) < 6
		local at = Vector3.new(centre.X + x, 0, centre.Z + z)
		if not onPath and probeClear(at, Vector3.new(4, PROBE_Y1 - PROBE_Y0, 4), { yard }) then
			headstone(yard, at, rng)
			placed += 1
		end
	end

	-- the noticeboard, just inside the gate
	local boardAt = gateCentre + inward * 5 + along * 8
	part({
		Name = "NoticePost",
		Size = Vector3.new(0.5, 4.4, 0.5),
		CFrame = CFrame.new(boardAt.X, 2.2, boardAt.Z),
		Color = Color3.fromRGB(42, 46, 44),
		Material = Enum.Material.Wood,
		Parent = yard,
	})
	local board = part({
		Name = "Notice",
		Size = Vector3.new(math.max(math.abs(along.X) * 7, 0.3), 4, math.max(math.abs(along.Z) * 7, 0.3)),
		CFrame = CFrame.new(boardAt.X, 5.4, boardAt.Z),
		Color = Color3.fromRGB(28, 44, 36),
		Material = Enum.Material.SmoothPlastic,
		Parent = yard,
	})
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Notice"
	gui.Face = if math.abs(along.X) > 0.5
		then (if gate.Z > 0 then Enum.NormalId.Front else Enum.NormalId.Back)
		else (if gate.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 34
	gui.LightInfluence = 0.5
	gui.MaxDistance = 140
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, 0.4)
	title.Position = UDim2.fromScale(0.05, 0.1)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(236, 236, 228)
	title.Text = parishName(town)
	title.Parent = gui
	local when = Instance.new("TextLabel")
	when.BackgroundTransparency = 1
	when.Size = UDim2.fromScale(0.9, 0.3)
	when.Position = UDim2.fromScale(0.05, 0.55)
	when.Font = Enum.Font.Gotham
	when.TextScaled = true
	when.TextColor3 = Color3.fromRGB(206, 214, 204)
	when.Text = "SUNDAY 9.30"
	when.Parent = gui

	-- a yew in each far corner, where there is room for one
	for _, sx in { -1, 1 } do
		local at = centre - gate * (hz * math.abs(gate.Z) + hx * math.abs(gate.X) - 7) + along * (sx * (math.abs(along.X) * hx + math.abs(along.Z) * hz - 7))
		if probeClear(at, Vector3.new(8, PROBE_Y1 - PROBE_Y0, 8), { yard }) then
			yew(yard, Vector3.new(at.X, 0, at.Z), rng)
		end
	end

	-- a bench inside the gate, facing the path
	KitPlacer.place("UKSP__ParkBenches__ParkBench01", CFrame.new(gateCentre + inward * 6 - along * 8) * CFrame.Angles(0, math.atan2(-along.X, -along.Z), 0), yard, {
		fallbackSize = Vector3.new(6, 3, 2),
		fallbackColor = Color3.fromRGB(120, 80, 50),
		fallbackMaterial = Enum.Material.Wood,
	})

	local parts = 0
	for _, d in yard:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	yard.Parent = town
	return parts
end

-- X319: the yard stands whether or not the kit church is there, so the greybox
-- nave gets one too.
local function buildChurchyard(town: Instance): number
	local block = nil
	for _, district in TownLayout.DISTRICTS do
		for _, b in district.blocks do
			if b.use == "church" then
				block = b
			end
		end
	end
	if not block then
		return 0
	end
	local old = town:FindFirstChild("Churchyard")
	if old then
		old:Destroy()
	end
	return dressChurchyard(town, town:FindFirstChild("Church"), block)
end

local function dressChurch(town: Instance): number
	local landmark = nil
	for _, l in TownLayout.LANDMARKS do
		if l.name:find("Church") then
			landmark = l
		end
	end
	if not landmark or not KitPlacer.find(CHURCH_KIT) then
		return 0 -- keep the greybox church
	end
	local block = nil
	for _, district in TownLayout.DISTRICTS do
		for _, b in district.blocks do
			if b.use == "church" then
				block = b
			end
		end
	end
	local landmarks = town:FindFirstChild("Landmarks")
	local spire = landmarks and landmarks:FindFirstChild(landmark.name)
	if spire then
		spire:Destroy()
	end
	local centre = if block then Vector3.new(block.centre.X, 0, block.centre.Z) else Vector3.new(landmark.position.X, 0, landmark.position.Z)
	local districts = town:FindFirstChild("Districts")
	if districts and block then
		for _, d in districts:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "church" or d.Name == "church roof") then
				local p = d.Position
				if math.abs(p.X - centre.X) < 0.5 and math.abs(p.Z - centre.Z) < 0.5 then
					d:Destroy()
				end
			end
		end
	end
	-- nave (kit local X) along the block's long side
	local yaw = if block and block.size.Z > block.size.X then math.pi / 2 else 0
	local model = KitPlacer.place(CHURCH_KIT, CFrame.new(centre) * CFrame.Angles(0, yaw, 0), town, {
		scale = landmark.height / CHURCH_KIT_HEIGHT,
	})
	model.Name = "Church"
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return parts
end


-- Returns a summary line for the server log.
function SquareDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "square: no town"
	end
	local old = town:FindFirstChild("Square")
	if old then
		old:Destroy()
	end
	local square = Instance.new("Model")
	square.Name = "Square"
	local centre = TownLayout.SQUARE.centre
	local rng = Random.new(1884)

	buildClockTower(square, centre)

	local planters = SquareDresser.ring(centre, PLANTER_RING, 6, math.pi / 6)
	for _, cf in planters do
		buildPlanter(square, cf, rng)
	end
	-- benches between the planters, backs to the tower
	for _, cf in SquareDresser.ring(centre, PLANTER_RING + 1, 6, 0) do
		KitPlacer.place("UKSP__ParkBenches__ParkBench01", cf * CFrame.new(0, TOP, 0) * CFrame.Angles(0, math.pi, 0), square, {
			fallbackSize = Vector3.new(6, 3, 2),
			fallbackColor = Color3.fromRGB(120, 80, 50),
			fallbackMaterial = Enum.Material.Wood,
		})
	end

	for i, cf in SquareDresser.ring(centre, STALL_RING, STALL_COUNT, math.pi / STALL_COUNT) do
		buildStall(square, cf, STALL_COLOURS[(i - 1) % #STALL_COLOURS + 1], i)
	end

	for _, cf in SquareDresser.ring(centre, BOLLARD_RING, BOLLARD_COUNT, 0) do
		part({
			Name = "Bollard",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 1, 1),
			CFrame = cf * CFrame.new(0, TOP + 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = IRON,
			Material = Enum.Material.Metal,
			Parent = square,
		})
	end

	-- X267: the square's post now points at the club grounds too (the blades
	-- were all landmarks, so nothing in town pointed a visitor at a ground)
	local groundsAt = SquareDresser.destination("Plot 1")
	local squareBlades: { FingerDestination } = { "Station", "Riverside", "Lune Bridge" }
	if groundsAt then
		table.insert(squareBlades, { name = "Club Grounds", position = groundsAt })
	else
		table.insert(squareBlades, "Church Spire")
	end
	SquareDresser.fingerPost(square, SquareDresser.ring(centre, FINGER_RING, 1, 0)[1].Position, nil, squareBlades)

	for _, cf in SquareDresser.ring(centre, BOLLARD_RING - 3, 4, math.pi / 4) do
		KitPlacer.place("LampVictorian", cf * CFrame.new(0, TOP, 0), square, {
			fallbackSize = Vector3.new(0.8, 16, 0.8),
			fallbackColor = IRON,
		})
	end

	local phone = SquareDresser.ring(centre, SquareDresser.PHONE_BOX_RING, 1, SquareDresser.PHONE_BOX_ANGLE)[1]
	KitPlacer.place("PhoneBoxK6", phone * CFrame.new(0, TOP, 0), square, {
		scale = PHONE_BOX_SCALE,
		fallbackSize = Vector3.new(3, 7, 3),
		fallbackColor = Color3.fromRGB(190, 20, 24),
	})

	square.Parent = town
	local baskets = dressLampBaskets(town, square, centre, rng)
	local parts = 0
	for _, d in square:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local churchParts = dressChurch(town)
	local yardParts = buildChurchyard(town) -- X319
	return ("square: %d parts (%d lamp baskets), church: %d parts, churchyard: %d parts"):format(parts, baskets, churchParts, yardParts)
end

return SquareDresser
