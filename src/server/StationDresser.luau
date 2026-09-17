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
	for _, x in { -halfLen + 0.3, halfLen - 0.3 } do
		slab(parent, p, "EndRail", x - 0.15, x + 0.15, top + 3.3, top + 3.6, 0.3, depth - 0.3, IRON, Enum.Material.Metal)
		slab(parent, p, "EndRailMid", x - 0.1, x + 0.1, top + 1.6, top + 1.8, 0.3, depth - 0.3, IRON, Enum.Material.Metal)
		for _, z in { 0.6, depth / 2, depth - 0.6 } do
			slab(parent, p, "EndRailPost", x - 0.15, x + 0.15, top, top + 3.3, z - 0.15, z + 0.15, IRON, Enum.Material.Metal)
		end
	end
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
					d.Color = SLATE
					d.Material = Enum.Material.Slate
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
			slab(m, f, "Window", x - 3.5, x + 3.5, 3, 10.5, 0, 0.3, Color3.fromRGB(45, 55, 65), Enum.Material.Glass)
			slab(m, f, "Lintel", x - 4.2, x + 4.2, 10.5, 11.5, 0, 0.6, Color3.fromRGB(215, 205, 185), Enum.Material.Limestone)
		end
		if math.abs(x) > 30 then
			slab(m, f, "UpperWindow", x - 3, x + 3, 16.5, 21, 0, 0.3, Color3.fromRGB(45, 55, 65), Enum.Material.Glass)
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
