--!strict
-- #16: what makes a prefab house read as a pub, and the Supporters' Bar's forecourt.
--
-- Every pub lot gets an invisible `ShopfrontPub` marker along its building front. TownLife
-- (G2.1) looks for exactly that (a part named Shopfront* with Front = "shop_front_pub") to
-- put matchday drinkers in the club's colours outside the pubs nearest the player's plot,
-- on that player's screen only (CLAUDE.md s27). v3 retired ShopBuilder's shopfront parts,
-- so until now no pub had one and the drinkers never appeared.
--
-- A lot with a `sign` (TownLayout Box.sign: the four Supporters' Bars, one across the street
-- from each plot's pedestrian gate) also gets a forecourt, built as its own model next to
-- the lot so the lot keeps to its box: a paved terrace along the front, a path out to the
-- pavement, picnic benches, and a hanging pub sign on a post by the pavement.
--
-- Primitives carry V3Exempt "EC3" (the pub stand-in's register row).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local PedestrianMath = require(ReplicatedStorage.Shared.PedestrianMath)
local RoadPaths = require(ReplicatedStorage.Shared.RoadPaths)
local TradeRecipes = require(ReplicatedStorage.Shared.TradeRecipes)
local KitPlacer = require(ServerScriptService.Server.KitPlacer)
local V3Perf = require(ServerScriptService.Server.V3Perf)

local PubDressing = {}

PubDressing.FRONT_KEY = "shop_front_pub" -- TownLife's pub-front key
PubDressing.MARKER_HEIGHT = 8
PubDressing.TERRACE_DEPTH = 10 -- paved strip in front of the building (drinkers stand 6.4 out)
PubDressing.TERRACE_TOP = 0.4 -- the forecourt paving height TownLifeMath assumes
PubDressing.PATH_WIDTH = 5
PubDressing.UNDER_PORCH = 4 -- the terrace runs this far back under the building front
PubDressing.BENCH_SPACING = 6
PubDressing.MAX_GAP = 80 -- no forecourt when the pavement is further than this
PubDressing.SIGN_NAVY = Color3.fromRGB(22, 36, 62)
PubDressing.SIGN_GOLD = Color3.fromRGB(236, 206, 124)
local PAVING = Color3.fromRGB(168, 162, 152)
local POST = Color3.fromRGB(30, 30, 32)
local RAY_STEP = 0.5

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("V3Exempt", "EC3")
	p.Parent = parent
	return p
end

-- Pure: the building front of a pub recipe in the lot frame (-Z = street): the frontmost face
-- of its prefab houses and their X extent. nil when the recipe has no prefab.
function PubDressing.frontOf(pieces: { TradeRecipes.Piece }): (number?, number, number)
	local zFront: number? = nil
	local x0, x1 = math.huge, -math.huge
	for _, piece in pieces do
		if string.sub(piece.kit, 1, 11) == "MEH__House_" then
			local s = TradeRecipes.SIZES[piece.kit]
			if s then
				local z = piece.pos.Z - s.Z / 2
				zFront = if zFront then math.min(zFront, z) else z
				x0 = math.min(x0, piece.pos.X - s.X / 2)
				x1 = math.max(x1, piece.pos.X + s.X / 2)
			end
		end
	end
	return zFront, x0, x1
end

-- Where the paving ends on a road: the walked streets carry PavingStrips out to
-- pavementOuter; the rest only the kit's own paving.
local function pavingReach(road: TownLayout.Road): number
	if PedestrianMath.isWalkableKind(road.kind) then
		return RoadTiles.pavementOuter(road.kind)
	end
	return RoadTiles.KIT_PAVING_OUTER * (RoadTiles.SCALE[road.kind] or RoadTiles.STREET_SCALE)
end

-- Pure: how far `origin` is from the nearest paving's outer edge, walking along `dir`
-- (XZ). nil when no road is within `maxT`.
function PubDressing.gapToPaving(origin: Vector3, dir: Vector3, roads: { TownLayout.Road }, maxT: number): number?
	local function inside(t: number): boolean
		local p = origin + dir * t
		for _, road in roads do
			if road.kind ~= "alley" and TownLayout.distanceToPolyline(p, road.points) <= pavingReach(road) then
				return true
			end
		end
		return false
	end
	local t = 0
	while t <= maxT do
		if inside(t) then
			return t
		end
		t += RAY_STEP
	end
	return nil
end

-- The invisible front TownLife reads: its local -X points out of the building (drinkers
-- stand that way), local Z runs along the front.
function PubDressing.frontMarker(model: Model, frame: CFrame, pieces: { TradeRecipes.Piece }): BasePart?
	local zFront, x0, x1 = PubDressing.frontOf(pieces)
	if not zFront then
		return nil
	end
	local h = PubDressing.MARKER_HEIGHT
	local centre = frame * Vector3.new((x0 + x1) / 2, h / 2, zFront + 0.5)
	local marker = part(model, "ShopfrontPub", Vector3.new(1, h, x1 - x0), CFrame.fromMatrix(centre, frame.ZVector, frame.YVector), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, false)
	marker.Transparency = 1
	marker.CanQuery = false
	marker:SetAttribute("Front", PubDressing.FRONT_KEY)
	return marker
end

local function signFace(board: BasePart, face: Enum.NormalId, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.9
	gui.MaxDistance = 250
	gui.Parent = board
	local stroke = Instance.new("Frame")
	stroke.BackgroundTransparency = 1
	stroke.Size = UDim2.new(1, -16, 1, -16)
	stroke.Position = UDim2.fromOffset(8, 8)
	stroke.Parent = gui
	local line = Instance.new("UIStroke")
	line.Color = Color3.fromRGB(214, 180, 96)
	line.Thickness = 4
	line.Parent = stroke
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.8, 0.8)
	label.Position = UDim2.fromScale(0.1, 0.1)
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = PubDressing.SIGN_GOLD
	label.Text = text
	label.Parent = gui
end

-- A chalk A-board: two slate leaves leaning together, the chalk text on the street side.
local function aBoard(parent: Instance, base: CFrame, text: string)
	local w, h, lean = 2.2, 3, math.rad(12)
	for _, sgn in { 1, -1 } do
		local leaf = part(parent, "ABoard", Vector3.new(w, h, 0.12), base * CFrame.new(0, h / 2 * math.cos(lean), sgn * h / 2 * math.sin(lean)) * CFrame.Angles(-sgn * lean, 0, 0), Color3.fromRGB(34, 36, 38), Enum.Material.Slate, false)
		if sgn < 0 then
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			gui.MaxDistance = 120
			gui.Parent = leaf
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.84, 0.8)
			label.Position = UDim2.fromScale(0.08, 0.1)
			label.Font = Enum.Font.PermanentMarker
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(240, 236, 220)
			label.Text = text
			label.Parent = gui
		end
	end
end

-- A hanging pub sign on a post: `base` is the foot of the post, its X runs along the street
-- (the board hangs across it, so both faces read from the pavement).
local function hangingSign(parent: Instance, base: CFrame, text: string)
	local postH, armL = 13, 5.4
	part(parent, "SignPost", Vector3.new(0.6, postH, 0.6), base * CFrame.new(0, postH / 2, 0), POST, Enum.Material.Wood, true)
	part(parent, "SignArm", Vector3.new(0.3, 0.3, armL), base * CFrame.new(0, postH - 0.6, -armL / 2 + 0.3), POST, Enum.Material.Metal, false)
	local w, h = 4.6, 5.4
	local board = part(parent, "PubSign", Vector3.new(0.2, h, w), base * CFrame.new(0, postH - 1.1 - h / 2, -armL / 2 - 0.2), PubDressing.SIGN_NAVY, Enum.Material.SmoothPlastic, false)
	signFace(board, Enum.NormalId.Left, text)
	signFace(board, Enum.NormalId.Right, text)
end

-- The Supporters' Bar forecourt. `frame` is the lot frame (-Z = street, see
-- TradeAssembler.lotFrame), `origin` the town origin the lot was built at.
function PubDressing.forecourt(parent: Instance, origin: CFrame, frame: CFrame, lot: TradeRecipes.Lot, pieces: { TradeRecipes.Piece }): Model?
	local zFront, x0, x1 = PubDressing.frontOf(pieces)
	if not zFront or not lot.sign then
		return nil
	end
	-- the lot's front edge, and the grass from there out to the paving, in town coordinates
	-- (against the filleted roads: the kit bends pull a corner's paving in)
	local edgeLocal = frame * Vector3.new(0, 0, -lot.size.Z / 2)
	local edgeTown = origin:PointToObjectSpace(edgeLocal)
	local outTown = origin:VectorToObjectSpace(-frame.ZVector)
	local gap = PubDressing.gapToPaving(Vector3.new(edgeTown.X, 0, edgeTown.Z), Vector3.new(outTown.X, 0, outTown.Z).Unit, RoadPaths.townRoads(), PubDressing.MAX_GAP)
	if not gap then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = lot.id .. "|Forecourt"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Sign", lot.sign)

	local halfW = lot.size.X / 2
	local top = PubDressing.TERRACE_TOP
	local T = 0.3
	-- terrace: the whole lot width, from the building front out TERRACE_DEPTH, and back under
	-- the porch (a prefab's porch and bay stand proud of its wall)
	local tz0, tz1 = zFront - PubDressing.TERRACE_DEPTH, zFront + PubDressing.UNDER_PORCH
	part(model, "Terrace", Vector3.new(lot.size.X - 2, T, tz1 - tz0), frame * CFrame.new(0, top - T / 2, (tz0 + tz1) / 2), PAVING, Enum.Material.Pavement, true)
	-- path: from the terrace out to the paving, lined up with the middle of the building
	local pathX = math.clamp((x0 + x1) / 2, -halfW + PubDressing.PATH_WIDTH, halfW - PubDressing.PATH_WIDTH)
	local pz1 = tz0 + 0.2
	local pz0 = -lot.size.Z / 2 - gap - 0.5 -- tucks under the paving's edge
	if pz1 - pz0 > 0.5 then
		part(model, "Path", Vector3.new(PubDressing.PATH_WIDTH, T, pz1 - pz0), frame * CFrame.new(pathX, top - T / 2 - 0.02, (pz0 + pz1) / 2), PAVING, Enum.Material.Pavement, true)
	end
	-- a beer garden: picnic benches in a row on the terrace beside the building, on whichever
	-- side has room (the matchday drinkers stand in front of the building itself)
	local rightRoom, leftRoom = halfW - 1 - x1, x0 + halfW - 1
	local side = if rightRoom >= leftRoom then 1 else -1
	local room = math.max(rightRoom, leftRoom)
	local benchKits = { "UKSP__PicnicBenches__BenchNew", "UKSP__PicnicBenches__BenchOld" }
	local rng = Random.new(TradeRecipes.seedOf(lot.id .. "#garden"))
	local benches = math.min(math.floor(room / PubDressing.BENCH_SPACING), 3)
	for i = 1, benches do
		local along = (i - 0.5) * room / benches
		local x = if side > 0 then x1 + along else x0 - along
		local z = zFront - PubDressing.TERRACE_DEPTH / 2 + rng:NextNumber(-1, 1)
		local placed = KitPlacer.place(benchKits[(i - 1) % #benchKits + 1], frame * CFrame.new(x, top, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-10, 10)), 0), model)
		V3Perf.applyDefaults(placed, "prop")
	end
	-- the sign and a chalk A-board stand either side of the path by the pavement, clear of the
	-- drinkers on the terrace
	local signZ = -lot.size.Z / 2 - gap + 2.5
	aBoard(model, frame * CFrame.new(pathX - side * (PubDressing.PATH_WIDTH / 2 + 1.6), top - 0.3, signZ + 0.5), "MATCHDAY\nHOME FANS\nWELCOME")
	if signZ < tz0 - 1 then
		hangingSign(model, frame * CFrame.new(pathX + side * (PubDressing.PATH_WIDTH / 2 + 2), 0, signZ) * CFrame.Angles(0, math.rad(90), 0), lot.sign)
	end
	model.Parent = parent
	return model
end

return PubDressing
