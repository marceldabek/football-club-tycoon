--!strict
-- Rivermere Station frontage (backlog E7.1). Reference:
-- assets/references/RivermereStation.png — a red-brick station with a navy
-- entrance canopy carrying the station name and the double-arrow rail sign,
-- glazed doors, a "Next Trains" board, a newsagent kiosk, black bollards,
-- planters and a bench along the forecourt, taxis waiting at the kerb; the
-- platform behind has a canopy and black railings.
--
-- TownBuilder builds the greybox station (workspace.Town.Rail["Rivermere
-- Station"]: building, roof, platform, canopy) from TownLayout.RAIL.station;
-- the platform is on the rail side (-Z for the current layout), so the street
-- front is the other long side. This module re-skins the building and adds
-- the frontage under workspace.Town.StationFront (~120 parts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)

local StationDresser = {}

local BRICK = Color3.fromRGB(150, 72, 54)
local SLATE = Color3.fromRGB(70, 74, 82)
local NAVY = Color3.fromRGB(24, 40, 78)
local IRON = Color3.fromRGB(22, 22, 24)
local GLASS = Color3.fromRGB(150, 185, 205)
local PAVING = Color3.fromRGB(200, 188, 168)
local TAXI_BLACK = Color3.fromRGB(28, 30, 34)

local function part(props: { [string]: any }, className: string?): BasePart
	local p = (Instance.new :: any)(className or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
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

-- A box from extents in `frame` (x along the frontage, y up, z out from the front wall).
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

local GLASS = Color3.fromRGB(58, 74, 90)
local SASH_WHITE = Color3.fromRGB(236, 234, 226)

-- A vertical mullion and a horizontal transom across a window centred on x
-- (half width hw, from y0 to y1), standing 0.1 proud of the glass (X49).
local function glazingBars(parent: Instance, frame: CFrame, x: number, hw: number, y0: number, y1: number)
	local yMid = y0 + (y1 - y0) * 0.55
	slab(parent, frame, "Mullion", x - 0.12, x + 0.12, y0 + 0.05, y1 - 0.05, 0.25, 0.4, SASH_WHITE) -- ends short of the glass edges: no shared planes
	slab(parent, frame, "Transom", x - hw, x + hw, yMid - 0.12, yMid + 0.12, 0.3, 0.42, SASH_WHITE)
end

local function sign(target: BasePart, face: Enum.NormalId, text: string, colour: Color3, background: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.6
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new()
	label.TextColor3 = colour
	label.Font = font or Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.03, 0)
	pad.PaddingRight = UDim.new(0.03, 0)
	pad.Parent = label
end

-- Pure: the frame on the station's street front: origin at ground level in the
-- middle of the front wall, +Z pointing out towards the street, +X along it.
-- The front is the long side facing away from the railway.
function StationDresser.frontFrame(): CFrame
	local station = TownLayout.RAIL.station
	local base = CFrame.new(station.centre.X, 0, station.centre.Z) * CFrame.Angles(0, math.rad(station.yaw), 0)
	local half = station.size.Z / 2
	local minus = TownLayout.distanceToPolyline(base * Vector3.new(0, 0, -half), TownLayout.RAIL.points)
	local plus = TownLayout.distanceToPolyline(base * Vector3.new(0, 0, half), TownLayout.RAIL.points)
	if minus <= plus then
		-- rail behind (-Z): the front is +Z
		return base * CFrame.new(0, 0, half)
	end
	return base * CFrame.new(0, 0, -half) * CFrame.Angles(0, math.pi, 0)
end

local function buildTaxi(parent: Instance, cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Taxi"
	m.Parent = parent
	part({ Name = "Body", Size = Vector3.new(6, 2.4, 13), CFrame = cf * CFrame.new(0, 2, 0), Color = TAXI_BLACK, Material = Enum.Material.SmoothPlastic, Parent = m })
	part({ Name = "Cabin", Size = Vector3.new(5.4, 2, 7), CFrame = cf * CFrame.new(0, 4.2, 0.6), Color = Color3.fromRGB(40, 50, 60), Material = Enum.Material.Glass, Parent = m })
	local roof = part({ Name = "TaxiSign", Size = Vector3.new(2.4, 0.7, 1), CFrame = cf * CFrame.new(0, 5.55, 0.6), Color = Color3.fromRGB(250, 200, 30), Parent = m })
	sign(roof, Enum.NormalId.Back, "TAXI", Color3.fromRGB(20, 20, 20))
	for _, x in { -2.9, 2.9 } do
		for _, z in { -4, 4 } do
			local wheel = part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 2.2, 2.2), CFrame = cf * CFrame.new(x, 1.1, z), Color = Color3.fromRGB(20, 20, 20), Parent = m })
			wheel.CastShadow = false
		end
	end
end

-- Pure: the frame on the platform side: origin at ground level in the middle
-- of the rear wall, +Z towards the rails.
function StationDresser.platformFrame(front: CFrame, stationSize: Vector3): CFrame
	return front * CFrame.new(0, 0, -stationSize.Z) * CFrame.Angles(0, math.pi, 0)
end

-- Yellow edge line, benches, bin, running-in boards and end railings (~25 parts).
function StationDresser.dressPlatform(parent: Instance, front: CFrame, stationSize: Vector3, platformSize: Vector3)
	local p = StationDresser.platformFrame(front, stationSize)
	local top = platformSize.Y
	local depth = platformSize.Z
	local halfLen = platformSize.X / 2
	slab(parent, p, "EdgeLine", -halfLen, halfLen, top - 0.1, top + 0.06, depth - 3, depth - 2.4, Color3.fromRGB(240, 200, 30), Enum.Material.SmoothPlastic)
	for _, x in { -63, -21, 21, 63 } do
		KitPlacer.place("UKSP__ParkBenches__ParkBench01", p * CFrame.new(x, top, 2.5), parent, { fallbackSize = Vector3.new(6, 3, 2), fallbackColor = Color3.fromRGB(120, 80, 50) })
	end
	KitPlacer.place("UKSP__LitterBin__LitterBin", p * CFrame.new(-40, top, 1.8), parent, { fallbackSize = Vector3.new(2, 3.5, 2), fallbackColor = IRON })
	local boardZ = math.max(depth / 2, 3)
	for _, x in { -104, 104 } do
		for _, dx in { -4.5, 4.5 } do
			slab(parent, p, "BoardPost", x + dx - 0.3, x + dx + 0.3, top, top + 9, boardZ - 0.3, boardZ + 0.3, IRON, Enum.Material.Metal)
		end
		local board = slab(parent, p, "NameBoard", x - 6, x + 6, top + 6, top + 8.5, boardZ - 0.25, boardZ + 0.25, NAVY, Enum.Material.SmoothPlastic)
		sign(board, Enum.NormalId.Back, "RIVERMERE", Color3.new(1, 1, 1))
		sign(board, Enum.NormalId.Front, "RIVERMERE", Color3.new(1, 1, 1))
	end
	StationDresser.footbridge(parent, p, top, depth)
	for _, x in { -halfLen + 0.3, halfLen - 0.3 } do
		slab(parent, p, "EndRail", x - 0.15, x + 0.15, top + 3.3, top + 3.6, 0.3, depth - 0.3, IRON, Enum.Material.Metal)
		slab(parent, p, "EndRailMid", x - 0.1, x + 0.1, top + 1.6, top + 1.8, 0.3, depth - 0.3, IRON, Enum.Material.Metal)
		for _, z in { 0.6, depth / 2, depth - 0.6 } do
			slab(parent, p, "EndRailPost", x - 0.15, x + 0.15, top, top + 3.3, z - 0.15, z + 0.15, IRON, Enum.Material.Metal)
		end
	end
end

-- Pure: the footbridge's local x and z extents in the platform frame: a stair
-- tower on the platform, a covered span over the tracks and a tower beyond them.
function StationDresser.footbridgeExtents(depth: number, railWidth: number): (number, number, number, number, number)
	local x = 72 -- between the canopy posts and clear of the benches
	local nearZ0, nearZ1 = 1, 8
	local farZ0 = depth + railWidth + 6
	return x, nearZ0, nearZ1, farZ0, farZ0 + 7
end

-- Brick stair towers and a navy covered span over the line (~9 parts).
function StationDresser.footbridge(parent: Instance, p: CFrame, top: number, depth: number)
	local x, nz0, nz1, fz0, fz1 = StationDresser.footbridgeExtents(depth, TownLayout.RAIL.width)
	local deckY = 16
	local roofY = 22
	slab(parent, p, "StairTower", x - 3.5, x + 3.5, top, roofY, nz0, nz1, BRICK, Enum.Material.Brick)
	slab(parent, p, "StairTower", x - 3.5, x + 3.5, 0, roofY, fz0, fz1, BRICK, Enum.Material.Brick)
	slab(parent, p, "TowerRoof", x - 4, x + 4, roofY, roofY + 0.6, nz0 - 0.5, nz1 + 0.5, SLATE, Enum.Material.Slate)
	slab(parent, p, "TowerRoof", x - 4, x + 4, roofY, roofY + 0.6, fz0 - 0.5, fz1 + 0.5, SLATE, Enum.Material.Slate)
	slab(parent, p, "BridgeDeck", x - 2.5, x + 2.5, deckY, deckY + 1, nz1, fz0, NAVY, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		slab(parent, p, "BridgeSide", x + side * 2.5 - 0.15, x + side * 2.5 + 0.15, deckY + 1, deckY + 2.2, nz1, fz0, NAVY, Enum.Material.Metal)
		local glass = slab(parent, p, "BridgeGlass", x + side * 2.5 - 0.1, x + side * 2.5 + 0.1, deckY + 2.2, roofY - 0.5, nz1, fz0, GLASS, Enum.Material.Glass)
		glass.Transparency = 0.5
		glass.CastShadow = false
	end
	slab(parent, p, "BridgeRoof", x - 2.9, x + 2.9, roofY - 0.5, roofY - 0.1, nz1, fz0, NAVY, Enum.Material.Metal)
end

-- Pure: a roof slope as a WedgePart in the front frame. The wedge is full
-- height (`rise`) at the ridge line z = ridgeZ and thins to nothing at the
-- eave line z = eaveZ, sitting on y = eaveY, `length` long along x.
-- WedgePart: full height at local +Z, slope on the Top face falling towards
-- local -Z. So local Z points from the eave towards the ridge: Z = (0, 0, k)
-- with k = sign(ridgeZ - eaveZ); Y = up; X = Y x Z = (0,1,0) x (0,0,k) = (k,0,0).
function StationDresser.roofWedge(ridgeZ: number, eaveZ: number, eaveY: number, rise: number, length: number): (CFrame, Vector3)
	local k = if ridgeZ >= eaveZ then 1 else -1
	local pos = Vector3.new(0, eaveY + rise / 2, (ridgeZ + eaveZ) / 2)
	local cf = CFrame.fromMatrix(pos, Vector3.new(k, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, k))
	return cf, Vector3.new(length, rise, math.abs(ridgeZ - eaveZ))
end

-- Pure: one half of a front-facing triangle (gable / pediment / cross roof)
-- in the front frame: apex at (0, baseY + rise), low corner at
-- (side * halfWidth, baseY), extruded from z0 to z1. `side` is -1 or +1.
-- Local Z runs from the low corner to the tall edge at x = 0: Z = (-side, 0, 0);
-- Y = up; X = Y x Z = (0,1,0) x (-side,0,0) = (0, 0, side), the extrusion.
function StationDresser.gableWedge(side: number, halfWidth: number, rise: number, baseY: number, z0: number, z1: number): (CFrame, Vector3)
	local pos = Vector3.new(side * halfWidth / 2, baseY + rise / 2, (z0 + z1) / 2)
	local cf = CFrame.fromMatrix(pos, Vector3.new(0, 0, side), Vector3.new(0, 1, 0), Vector3.new(-side, 0, 0))
	return cf, Vector3.new(z1 - z0, rise, halfWidth)
end

local function clockFace(target: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	gui.Parent = target
	for i, numeral in { "XII", "III", "VI", "IX" } do
		local angle = math.rad((i - 1) * 90)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5 + 0.36 * math.sin(angle), 0.5 - 0.36 * math.cos(angle))
		label.Size = UDim2.fromScale(0.2, 0.14)
		label.BackgroundTransparency = 1
		label.TextColor3 = IRON
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.Text = numeral
		label.Parent = gui
	end
	-- hands: a full-size holder rotates about the dial centre (GuiObject.Rotation
	-- turns about the object's own centre), the hand runs up from the centre
	for _, hand in { { rotation = 85, length = 0.22, width = 0.05 }, { rotation = 300, length = 0.33, width = 0.03 } } do
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Rotation = hand.rotation
		holder.Parent = gui
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(hand.width, hand.length)
		bar.BackgroundColor3 = IRON
		bar.BorderSizePixel = 0
		bar.Parent = holder
	end
end

-- Pitched slate roof, front gable over the entrance canopy with stone coping
-- and a clock (X21, 12 parts). Heights come from the greybox: the building box
-- is 0..size.Y-1 and its flat roof slab (hidden by build) sat on top.
-- Front frame: building occupies z in [-size.Z, 0]; entrance canopy is y 12..15.5.
function StationDresser.roof(parent: Instance, f: CFrame, size: Vector3)
	local eaveY = size.Y - 1
	local halfLen = size.X / 2
	local ridgeZ = -size.Z / 2
	local overhang = 1.5
	local rise = 10.5
	for _, eaveZ in { overhang, -size.Z - overhang } do
		local cf, s = StationDresser.roofWedge(ridgeZ, eaveZ, eaveY, rise, size.X + 2)
		part({ Name = "RoofSlope", Size = s, CFrame = f * cf, Color = SLATE, Material = Enum.Material.Slate, Parent = parent }, "WedgePart")
	end

	-- gable: brick wall from the canopy top to just above the eave, a brick
	-- pediment triangle above, projecting 2.5 from the front wall
	local GABLE_HALF, GABLE_BASE, GABLE_RISE, GABLE_DEPTH = 22, eaveY + 0.3, 9.5, 2.5
	slab(parent, f, "GableWall", -GABLE_HALF, GABLE_HALF, 15.5, GABLE_BASE, 0, GABLE_DEPTH, BRICK, Enum.Material.Brick)
	-- cross roof behind the pediment: same pitch, 1 stud wider each side so its
	-- slopes sit ~0.48 above the pediment's (no shared planes); base 0.05 higher
	local crossHalf = GABLE_HALF + 1
	local crossRise = GABLE_RISE * crossHalf / GABLE_HALF
	for _, side in { -1, 1 } do
		local cf, s = StationDresser.gableWedge(side, GABLE_HALF, GABLE_RISE, GABLE_BASE, 0, GABLE_DEPTH)
		part({ Name = "Pediment", Size = s, CFrame = f * cf, Color = BRICK, Material = Enum.Material.Brick, Parent = parent }, "WedgePart")
		local ccf, cs = StationDresser.gableWedge(side, crossHalf, crossRise, GABLE_BASE + 0.05, ridgeZ + 0.2, 0.6)
		part({ Name = "CrossRoof", Size = cs, CFrame = f * ccf, Color = SLATE, Material = Enum.Material.Slate, Parent = parent }, "WedgePart")
		-- coping along the pediment slope, covering the cross roof's front edge;
		-- the two copings take slightly different depths so they never share a face
		local theta = math.atan2(GABLE_RISE, GABLE_HALF)
		local thick = 0.6
		local z0 = if side < 0 then 0.6 else 0.65
		local z1 = if side < 0 then GABLE_DEPTH + 0.3 else GABLE_DEPTH + 0.35
		local normal = Vector3.new(side * math.sin(theta), math.cos(theta), 0)
		local mid = Vector3.new(side * GABLE_HALF / 2, GABLE_BASE + GABLE_RISE / 2, (z0 + z1) / 2) + normal * (thick / 2)
		part({
			Name = "Coping",
			Size = Vector3.new(math.sqrt(GABLE_HALF ^ 2 + GABLE_RISE ^ 2) + 0.8, thick, z1 - z0),
			CFrame = f * CFrame.new(mid) * CFrame.Angles(0, 0, -side * theta),
			Color = Color3.fromRGB(215, 205, 185),
			Material = Enum.Material.Limestone,
			Parent = parent,
		})
	end
	slab(parent, f, "GableBand", -GABLE_HALF - 0.5, GABLE_HALF + 0.5, eaveY, eaveY + 0.6, GABLE_DEPTH, GABLE_DEPTH + 0.4, Color3.fromRGB(215, 205, 185), Enum.Material.Limestone)

	-- clock: stone rim and a white dial. Cylinders run along local X; turning
	-- +90 degrees about Y sends local +X to -Z (into the wall), so the dial's
	-- outward face is Left (-X).
	local clockY = GABLE_BASE + 3.6
	local turn = CFrame.Angles(0, math.pi / 2, 0)
	part({ Name = "ClockRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6, 6), CFrame = f * CFrame.new(0, clockY, GABLE_DEPTH + 0.1) * turn, Color = Color3.fromRGB(215, 205, 185), Material = Enum.Material.Limestone, Parent = parent })
	local dial = part({ Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 5.2, 5.2), CFrame = f * CFrame.new(0, clockY, GABLE_DEPTH + 0.2) * turn, Color = Color3.fromRGB(245, 242, 232), Parent = parent })
	clockFace(dial, Enum.NormalId.Left)
end

function StationDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "station: no town"
	end
	local station = TownLayout.RAIL.station
	local rail = town:FindFirstChild("Rail")
	local greybox = rail and rail:FindFirstChild(station.name)
	if greybox then
		-- re-skin the greybox shell rather than rebuilding it
		for _, d in greybox:GetChildren() do
			if d:IsA("BasePart") then
				if d.Name == "Station Building" then
					d.Color = BRICK
					d.Material = Enum.Material.Brick
				elseif d.Name == "Station Building roof" then
					-- replaced by the pitched roof (X21)
					d.Color = SLATE
					d.Material = Enum.Material.Slate
					d.Transparency = 1
					d.CanCollide = false
					d.CanQuery = false
					d.CastShadow = false
				elseif d.Name == "Canopy" or d.Name == "Canopy Post" then
					d.Color = NAVY
				end
			end
		end
	end
	local old = town:FindFirstChild("StationFront")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "StationFront"
	local f = StationDresser.frontFrame()
	local halfLen = station.size.X / 2

	-- pitched roof, front gable and clock over the greybox shell (X21)
	if greybox then
		StationDresser.roof(m, f, station.size)
	end

	-- forecourt paving in front of the building
	slab(m, f, "Forecourt", -halfLen, halfLen, 0, 0.3, 0, 22, PAVING, Enum.Material.Pavement)

	-- entrance: glazed doors and windows set into the wall, navy canopy with the name
	slab(m, f, "Entrance", -22, 22, 0.3, 12, -0.4, 0.1, GLASS, Enum.Material.Glass).Reflectance = 0.15
	for _, x in { -22.5, -11, 0, 11, 22.5 } do
		slab(m, f, "Mullion", x - 0.5, x + 0.5, 0.3, 12, 0.1, 0.5, NAVY, Enum.Material.Metal)
	end
	local canopy = slab(m, f, "Canopy", -28, 28, 12, 15.5, 0.1, 8, NAVY, Enum.Material.Metal)
	sign(canopy, Enum.NormalId.Back, "⇄  RIVERMERE STATION", Color3.new(1, 1, 1))
	for _, x in { -27, 27 } do
		slab(m, f, "CanopyPost", x - 0.4, x + 0.4, 0.3, 12, 7, 7.8, IRON, Enum.Material.Metal)
	end

	-- departures board beside the entrance
	slab(m, f, "BoardPost", 33.6, 34.4, 0.3, 9, 3, 3.8, IRON, Enum.Material.Metal)
	local board = slab(m, f, "Departures", 30, 42, 9, 15, 3, 3.8, Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic)
	sign(board, Enum.NormalId.Back, "Next Trains\nHollingford   2 min\nMapleford   17 min\nGreenbridge   29 min", Color3.fromRGB(255, 170, 30), Color3.fromRGB(15, 15, 18), Enum.Font.Code)

	-- newsagent kiosk at the west end of the frontage
	slab(m, f, "Kiosk", -halfLen + 12, -halfLen + 34, 0.3, 10, 0.1, 9, Color3.fromRGB(30, 80, 60), Enum.Material.SmoothPlastic)
	local kioskSign = slab(m, f, "KioskSign", -halfLen + 12, -halfLen + 34, 10, 12.5, 8.6, 9.2, Color3.fromRGB(30, 80, 60), Enum.Material.SmoothPlastic)
	sign(kioskSign, Enum.NormalId.Back, "ONTRACK  NEWS · DRINKS · SNACKS", Color3.new(1, 1, 1))
	slab(m, f, "Hatch", -halfLen + 16, -halfLen + 30, 3, 7.5, 9, 9.1, Color3.fromRGB(230, 220, 190), Enum.Material.SmoothPlastic)

	-- bollards along the kerb, planters and a bench, a bin
	for x = -halfLen + 40, halfLen - 6, 12 do
		part({
			Name = "Bollard",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.2, 1, 1),
			CFrame = f * CFrame.new(x, 1.9, 21) * CFrame.Angles(0, 0, math.pi / 2),
			Color = IRON,
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end
	for _, x in { -36, 50, 80 } do
		slab(m, f, "Planter", x - 3, x + 3, 0.3, 3, 12, 16, Color3.fromRGB(60, 64, 70), Enum.Material.Concrete)
		part({ Name = "Flowers", Shape = Enum.PartType.Ball, Size = Vector3.new(6.4, 2.6, 4.4), CFrame = f * CFrame.new(x, 3.8, 14), Color = Color3.fromRGB(220, 90, 140), Material = Enum.Material.Grass, CastShadow = false, Parent = m })
	end
	KitPlacer.place("UKSP__ParkBenches__ParkBench01", f * CFrame.new(64, 0.3, 14), m, { fallbackSize = Vector3.new(6, 3, 2), fallbackColor = Color3.fromRGB(120, 80, 50) })
	KitPlacer.place("UKSP__LitterBin__LitterBin", f * CFrame.new(38, 0.3, 14), m, { fallbackSize = Vector3.new(2, 3.5, 2), fallbackColor = IRON })

	-- window rows along the brick front: tall ground-floor windows with stone
	-- lintels (skipping the entrance, board and kiosk) and a shorter upper row
	for x = -halfLen + 10, halfLen - 10, 16 do
		local clearOfEntrance = math.abs(x) > 34 and not (x > 26 and x < 46)
		if clearOfEntrance and x > -halfLen + 38 then
			slab(m, f, "Window", x - 3.5, x + 3.5, 3, 10.5, 0, 0.3, GLASS, Enum.Material.Glass)
			slab(m, f, "Lintel", x - 4.2, x + 4.2, 10.5, 11.5, 0, 0.6, Color3.fromRGB(215, 205, 185), Enum.Material.Limestone)
			-- X49: white glazing bars and a stone sill, so the windows read as
			-- sashes (RivermereStation.png) rather than dark blank panels
			slab(m, f, "Sill", x - 4, x + 4, 2.6, 3.05, 0, 0.7, Color3.fromRGB(215, 205, 185), Enum.Material.Limestone)
			glazingBars(m, f, x, 3.5, 3, 10.5)
		end
		if math.abs(x) > 30 then
			slab(m, f, "UpperWindow", x - 3, x + 3, 16.5, 21, 0, 0.3, GLASS, Enum.Material.Glass)
			glazingBars(m, f, x, 3, 16.5, 21)
		end
	end

	-- drop-off lane and taxi rank at the kerb beyond the forecourt
	slab(m, f, "DropOff", -90, -14, 0, 0.25, 22, 38, Color3.fromRGB(70, 72, 76), Enum.Material.Asphalt)
	for _, x in { -60, -44 } do
		buildTaxi(m, f * CFrame.new(x, 0.25, 30) * CFrame.Angles(0, math.pi / 2, 0))
	end

	-- platform side (X20): read the greybox platform so its depth stays TownBuilder's call
	local platform = greybox and greybox:FindFirstChild("Platform")
	if platform and platform:IsA("BasePart") then
		StationDresser.dressPlatform(m, f, station.size, platform.Size)
	end

	m.Parent = town
	local parts = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("station: %d parts"):format(parts)
end

return StationDresser
