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

local function buildFingerPost(parent: Instance, at: Vector3)
	local m = Instance.new("Model")
	m.Name = "FingerPost"
	m.Parent = parent
	part({
		Name = "Post",
		Size = Vector3.new(0.5, 11, 0.5),
		CFrame = CFrame.new(at.X, TOP + 5.5 - 0.05, at.Z),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Finial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = CFrame.new(at.X, TOP + 11.2, at.Z),
		Color = IRON,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	local length = 6
	for i, name in FINGER_DESTINATIONS do
		local target = SquareDresser.destination(name)
		if not target then
			continue
		end
		local y = TOP + 10 - (i - 1) * 1.15
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
	part({
		Name = "Flowers",
		Size = Vector3.new(8.6, 1.2, 3.6),
		CFrame = f * CFrame.new(0, 3.3, 0),
		Color = FLOWERS[rng:NextInteger(1, #FLOWERS)],
		Material = Enum.Material.LeafyGrass,
		CastShadow = false,
		Parent = m,
	})
end

local function buildStall(parent: Instance, cf: CFrame, colour: Color3)
	local m = Instance.new("Model")
	m.Name = "MarketStall"
	m.Parent = parent
	-- local -Z faces the centre of the square (the shoppers' side)
	local f = cf * CFrame.new(0, TOP, 0)
	slab(m, f, "Counter", -5, 5, 0, 3.2, -2, 1, Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
	slab(m, f, "Goods", -4.5, 4.5, 3.2, 3.8, -1.8, 0.6, Color3.fromRGB(210, 150, 60), Enum.Material.SmoothPlastic)
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
		buildStall(square, cf, STALL_COLOURS[(i - 1) % #STALL_COLOURS + 1])
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

	buildFingerPost(square, SquareDresser.ring(centre, FINGER_RING, 1, 0)[1].Position)

	for _, cf in SquareDresser.ring(centre, BOLLARD_RING - 3, 4, math.pi / 4) do
		KitPlacer.place("LampVictorian", cf * CFrame.new(0, TOP, 0), square, {
			fallbackSize = Vector3.new(0.8, 16, 0.8),
			fallbackColor = IRON,
		})
	end

	square.Parent = town
	local baskets = dressLampBaskets(town, square, centre, rng)
	local parts = 0
	for _, d in square:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local churchParts = dressChurch(town)
	return ("square: %d parts (%d lamp baskets), church: %d parts"):format(parts, baskets, churchParts)
end

return SquareDresser
