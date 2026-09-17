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
local SquareDresser = require(script.Parent.SquareDresser)

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

local WINDOW_GLASS = Color3.fromRGB(58, 74, 90)
local FORECOURT_MAX = 70 -- no road within this of the front wall: keep the grass (X50)
local SASH_WHITE = Color3.fromRGB(236, 234, 226)
local MARKING_YELLOW = Color3.fromRGB(236, 196, 40)

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

-- Pure (X50): how far out from the front wall (local z) a paving strip at
-- local x should run so it meets the pavement of the nearest road instead of
-- leaving grass. Starts at z0, steps out to zMax; returns z0 when a road
-- pavement is already there, zMax when no road comes near.
-- `verge` (default PAVEMENT_WIDTH) is how far past the carriageway edge counts
-- as reached; 0 reaches the carriageway itself (X51, where no pavement got laid).
function StationDresser.forecourtReach(front: CFrame, x: number, z0: number, zMax: number, step: number, verge: number?): number
	local z = z0
	local extra = verge or TownLayout.PAVEMENT_WIDTH
	while z < zMax do
		local p = front * Vector3.new(x, 0, z)
		for _, road in TownLayout.ROADS do
			if TownLayout.distanceToPolyline(p, road.points) <= road.width / 2 + extra then
				return z
			end
		end
		z += step
	end
	return zMax
end

-- Pure (X51): TownLayout.STATION_LAYBY in the front frame `f`: local x range
-- along the frontage and local z range out from the front wall.
function StationDresser.laybyLocal(f: CFrame): { x0: number, x1: number, z0: number, z1: number }
	local layby = TownLayout.STATION_LAYBY
	local a, b = f:PointToObjectSpace(layby.from), f:PointToObjectSpace(layby.to)
	local z = (a.Z + b.Z) / 2
	return { x0 = math.min(a.X, b.X), x1 = math.max(a.X, b.X), z0 = z - layby.width / 2, z1 = z + layby.width / 2 }
end

-- Pure (X72): the painted bus stop bay in front of the Station bus stop, in the
-- front frame: 30 long centred on the stop, 4.8 wide on the carriageway just
-- inside the kerb (the lay-by's outer edge line, which is the kerb line).
function StationDresser.busBay(f: CFrame): { x0: number, x1: number, z0: number, z1: number }?
	for _, stop in TownLayout.BUS_STOPS do
		if stop.name == "Station" then
			local p = f:PointToObjectSpace(stop.position)
			local kerb = StationDresser.laybyLocal(f).z1
			return { x0 = p.X - 15, x1 = p.X + 15, z0 = kerb + 0.6, z1 = kerb + 5.4 }
		end
	end
	return nil
end

-- Pure (X73): double-yellow-line runs along Station Road's straight past the
-- station, in the front frame. Each run is { x0, x1, kerb (local z of the kerb
-- line), inward (+1 / -1 towards the road centre) }. The station-side kerb is
-- the lay-by's outer edge; runs there skip the lay-by and the bus bay. Runs
-- shorter than 2 are dropped.
export type LineRun = { x0: number, x1: number, kerb: number, inward: number }
function StationDresser.yellowLineRuns(f: CFrame, layby: { x0: number, x1: number, z0: number, z1: number }, bay: { x0: number, x1: number, z0: number, z1: number }?): { LineRun }
	local road
	for _, r in TownLayout.ROADS do
		if r.name == "Station Road" then
			road = r
		end
	end
	if not road or #road.points < 2 then
		return {}
	end
	-- the straight is the last segment
	local a = f:PointToObjectSpace(road.points[#road.points - 1])
	local b = f:PointToObjectSpace(road.points[#road.points])
	local x0, x1 = math.min(a.X, b.X), math.max(a.X, b.X)
	local nearKerb = layby.z1
	local farKerb = layby.z1 + road.width
	local runs: { LineRun } = { { x0 = x0, x1 = x1, kerb = farKerb, inward = -1 } }
	local gaps = { { layby.x0, layby.x1 } }
	if bay then
		table.insert(gaps, { bay.x0, bay.x1 })
	end
	table.sort(gaps, function(p, q)
		return p[1] < q[1]
	end)
	local cursor = x0
	for _, gap in gaps do
		if gap[1] - cursor >= 2 then
			table.insert(runs, { x0 = cursor, x1 = math.min(gap[1], x1), kerb = nearKerb, inward = 1 })
		end
		cursor = math.max(cursor, gap[2])
	end
	if x1 - cursor >= 2 then
		table.insert(runs, { x0 = cursor, x1 = x1, kerb = nearKerb, inward = 1 })
	end
	return runs
end

-- X83: the station car park (a plain greybox slab). Pure: bay centres as
-- CFrames looking out of the bay (nose-in cars face the other way): a row
-- along the far (-Z) edge and one along the near (+Z) edge, BAY_W wide and
-- BAY_D deep, skipping near-row bays within `entryClear` of the +X edge where
-- Station Road comes in.
local BAY_W, BAY_D = 11, 20
function StationDresser.carParkBays(block: TownLayout.Box, entryClear: number): { CFrame }
	local out = {}
	local c, s = block.centre, block.size
	local count = math.floor((s.X - 2) / BAY_W)
	local x0 = c.X - count * BAY_W / 2
	for row = 0, 1 do
		local z = if row == 0 then c.Z - s.Z / 2 + 0.5 + BAY_D / 2 else c.Z + s.Z / 2 - 0.5 - BAY_D / 2
		local outward = if row == 0 then 1 else -1 -- towards the aisle
		for k = 0, count - 1 do
			local x = x0 + (k + 0.5) * BAY_W
			if row == 1 and x + BAY_W / 2 > c.X + s.X / 2 - entryClear then
				continue
			end
			local at = Vector3.new(x, 0, z)
			table.insert(out, CFrame.lookAt(at, at + Vector3.new(0, 0, outward)))
		end
	end
	return out
end

-- True if a TownBuilder pavement part covers this ground point.
local function pavementAt(p: Vector3): boolean
	for _, hit in workspace:GetPartBoundsInBox(CFrame.new(p.X, 0.2, p.Z), Vector3.new(0.5, 0.4, 0.5)) do
		if hit.Name == "Pavement" then
			return true
		end
	end
	return false
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
	StationDresser.farPlatform(parent, p, top, depth, halfLen)
	for _, x in { -halfLen + 0.3, halfLen - 0.3 } do
		slab(parent, p, "EndRail", x - 0.15, x + 0.15, top + 3.3, top + 3.6, 0.3, depth - 0.3, IRON, Enum.Material.Metal)
		slab(parent, p, "EndRailMid", x - 0.1, x + 0.1, top + 1.6, top + 1.8, 0.3, depth - 0.3, IRON, Enum.Material.Metal)
		for _, z in { 0.6, depth / 2, depth - 0.6 } do
			slab(parent, p, "EndRailPost", x - 0.15, x + 0.15, top, top + 3.3, z - 0.15, z + 0.15, IRON, Enum.Material.Metal)
		end
	end
end

-- X81: platform 2 across the line, where the footbridge's far stair tower
-- stood in grass. Pure extents in the platform frame: z from just past the
-- rail bed out FAR_PLATFORM_DEPTH (the far tower, at depth + railWidth + 6..13,
-- stands on it).
local FAR_PLATFORM_DEPTH = 16
function StationDresser.farPlatformZ(depth: number, railWidth: number): (number, number)
	local z0 = depth + railWidth + 0.5
	return z0, z0 + FAR_PLATFORM_DEPTH
end

function StationDresser.farPlatform(parent: Instance, p: CFrame, top: number, depth: number, halfLen: number)
	local z0, z1 = StationDresser.farPlatformZ(depth, TownLayout.RAIL.width)
	slab(parent, p, "FarPlatform", -halfLen, halfLen, 0, top, z0, z1, Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
	slab(parent, p, "EdgeLine", -halfLen, halfLen, top - 0.1, top + 0.06, z0 + 2.4, z0 + 3, Color3.fromRGB(240, 200, 30), Enum.Material.SmoothPlastic)
	-- black railing along the back edge
	for _, y in { 1.6, 3.3 } do
		slab(parent, p, "BackRail", -halfLen, halfLen, top + y, top + y + 0.25, z1 - 0.45, z1 - 0.2, IRON, Enum.Material.Metal).CastShadow = false
	end
	local posts = math.floor(halfLen * 2 / 16)
	for k = 0, posts do
		local x = -halfLen + 0.3 + k * (halfLen * 2 - 0.6) / posts
		slab(parent, p, "BackRailPost", x - 0.15, x + 0.15, top, top + 3.6, z1 - 0.5, z1 - 0.15, IRON, Enum.Material.Metal).CastShadow = false
	end
	-- a glazed waiting shelter and benches, clear of the far stair tower (x 68.5..75.5)
	local sx = -30
	slab(parent, p, "ShelterBack", sx - 8, sx + 8, top, top + 7, z1 - 3, z1 - 2.6, GLASS, Enum.Material.Glass).Transparency = 0.4
	slab(parent, p, "ShelterRoof", sx - 8.5, sx + 8.5, top + 7, top + 7.5, z1 - 8, z1 - 2.4, NAVY, Enum.Material.Metal)
	for _, dx in { -8, 8 } do
		slab(parent, p, "ShelterPost", sx + dx - 0.2, sx + dx + 0.2, top, top + 7, z1 - 7.8, z1 - 7.4, NAVY, Enum.Material.Metal)
	end
	for _, x in { sx - 3.5, sx + 3.5, 30 } do
		KitPlacer.place("UKSP__ParkBenches__ParkBench01", p * CFrame.new(x, top, z1 - 4.5) * CFrame.Angles(0, math.pi, 0), parent, { fallbackSize = Vector3.new(6, 3, 2), fallbackColor = Color3.fromRGB(120, 80, 50) })
	end
	for _, x in { -104, 104 } do
		for _, dx in { -4.5, 4.5 } do
			slab(parent, p, "BoardPost", x + dx - 0.3, x + dx + 0.3, top, top + 9, z1 - 6.3, z1 - 5.7, IRON, Enum.Material.Metal)
		end
		local board = slab(parent, p, "NameBoard", x - 6, x + 6, top + 6, top + 8.5, z1 - 6.25, z1 - 5.75, NAVY, Enum.Material.SmoothPlastic)
		sign(board, Enum.NormalId.Back, "RIVERMERE", Color3.new(1, 1, 1))
		sign(board, Enum.NormalId.Front, "RIVERMERE", Color3.new(1, 1, 1))
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
	local layby = StationDresser.laybyLocal(f)
	slab(m, f, "Forecourt", -halfLen, halfLen, 0, 0.3, 0, 22, PAVING, Enum.Material.Pavement)
	-- X50: pave on to the road's pavement in 8-stud strips instead of leaving a
	-- grass verge (RivermereStation.png is paved to the kerb); strips run 1 stud
	-- under the pavement edge (its top is 0.45, ours 0.3) and skip the drop-off lane
	for x = -halfLen, halfLen - 8, 8 do
		local dropOff = x + 8 > layby.x0 and x < layby.x1
		local z0 = if dropOff then layby.z1 else 22
		local reach = StationDresser.forecourtReach(f, x + 4, z0, FORECOURT_MAX, 1)
		if reach < FORECOURT_MAX then
			local to = if reach > z0 + 0.5 then reach + 1 else z0
			if not dropOff and not pavementAt(f * Vector3.new(x + 4, 0, reach + 2)) then
				-- X51: TownBuilder left the pavement out here (a bend joint): pave on
				-- to the carriageway edge instead of leaving grass
				local kerb = StationDresser.forecourtReach(f, x + 4, z0, FORECOURT_MAX, 0.5, 0)
				if kerb < FORECOURT_MAX then
					to = math.max(to, kerb)
				end
			end
			if to > z0 + 0.5 then
				slab(m, f, "ForecourtVerge", x, x + 8, 0.02, 0.3, z0 - 0.05, to, PAVING, Enum.Material.Pavement)
			end
		end
	end

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
	local hatch = slab(m, f, "Hatch", -halfLen + 16, -halfLen + 30, 3, 7.5, 9, 9.1, Color3.fromRGB(230, 220, 190), Enum.Material.SmoothPlastic)
	-- X73: the serving hatch reads as a blank panel; show what's on sale
	sign(hatch, Enum.NormalId.Back, "PAPERS · MAGAZINES\nDRINKS · SNACKS", Color3.fromRGB(30, 80, 60), Color3.fromRGB(236, 228, 200), Enum.Font.GothamBold)
	-- X73: a hanging flower basket off the wall beside the kiosk sign (RivermereStation.png)
	slab(m, f, "BasketBracket", -halfLen + 35.8, -halfLen + 36.2, 11.4, 11.7, 0, 3.4, IRON, Enum.Material.Metal).CastShadow = false
	part({
		Name = "HangingBasket",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = f * CFrame.new(-halfLen + 36, 10.1, 3.2),
		Color = Color3.fromRGB(214, 80, 130),
		Material = Enum.Material.LeafyGrass,
		CastShadow = false,
		Parent = m,
	})

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
		-- X70: a planted bed, not a Ball (its diameter is the smallest axis: it showed as a 2.6 ball)
		part({ Name = "Flowers", Size = Vector3.new(5.6, 1.2, 3.6), CFrame = f * CFrame.new(x, 3.5, 14), Color = Color3.fromRGB(220, 90, 140), Material = Enum.Material.LeafyGrass, CastShadow = false, Parent = m })
	end
	KitPlacer.place("UKSP__ParkBenches__ParkBench01", f * CFrame.new(64, 0.3, 14), m, { fallbackSize = Vector3.new(6, 3, 2), fallbackColor = Color3.fromRGB(120, 80, 50) })
	KitPlacer.place("UKSP__LitterBin__LitterBin", f * CFrame.new(38, 0.3, 14), m, { fallbackSize = Vector3.new(2, 3.5, 2), fallbackColor = IRON })

	-- window rows along the brick front: tall ground-floor windows with stone
	-- lintels (skipping the entrance, board and kiosk) and a shorter upper row
	for x = -halfLen + 10, halfLen - 10, 16 do
		local clearOfEntrance = math.abs(x) > 34 and not (x > 26 and x < 46)
		if clearOfEntrance and x > -halfLen + 38 then
			slab(m, f, "Window", x - 3.5, x + 3.5, 3, 10.5, 0, 0.3, WINDOW_GLASS, Enum.Material.Glass)
			slab(m, f, "Lintel", x - 4.2, x + 4.2, 10.5, 11.5, 0, 0.6, Color3.fromRGB(215, 205, 185), Enum.Material.Limestone)
			-- X49: white glazing bars and a stone sill, so the windows read as
			-- sashes (RivermereStation.png) rather than dark blank panels
			slab(m, f, "Sill", x - 4, x + 4, 2.6, 3.05, 0, 0.7, Color3.fromRGB(215, 205, 185), Enum.Material.Limestone)
			glazingBars(m, f, x, 3.5, 3, 10.5)
		end
		if math.abs(x) > 30 then
			slab(m, f, "UpperWindow", x - 3, x + 3, 16.5, 21, 0, 0.3, WINDOW_GLASS, Enum.Material.Glass)
			glazingBars(m, f, x, 3, 16.5, 21)
		end
	end

	-- drop-off lane and taxi rank: X51 the lay-by (TownLayout.STATION_LAYBY) cut
	-- into Station Road's pavement, so it opens straight onto the carriageway;
	-- its tarmac tucks 0.2 over the carriageway edge (0.25 top vs the road's 0.22)
	local laneMid = (layby.z0 + layby.z1) / 2
	slab(m, f, "DropOff", layby.x0, layby.x1, 0, 0.25, layby.z0, layby.z1 + 0.2, Color3.fromRGB(70, 72, 76), Enum.Material.Asphalt)
	for _, x in { layby.x0 + 30, layby.x0 + 46 } do
		buildTaxi(m, f * CFrame.new(x, 0.25, laneMid) * CFrame.Angles(0, math.pi / 2, 0))
	end
	-- X50: yellow rank markings like RivermereStation.png: an edge line along the
	-- lane and TAXIS painted on the free bay (a clear plate 0.02 above the tarmac)
	slab(m, f, "RankLine", layby.x0, layby.x1 - 10, 0.23, 0.28, layby.z1 - 0.5, layby.z1 - 0.1, MARKING_YELLOW, Enum.Material.SmoothPlastic).CastShadow = false
	local word = slab(m, f, "TaxiMarking", layby.x0 + 56, layby.x0 + 72, 0.25, 0.27, layby.z0 + 0.5, layby.z1 - 0.7, MARKING_YELLOW)
	word.Transparency = 1
	word.CastShadow = false
	sign(word, Enum.NormalId.Top, "TAXIS", MARKING_YELLOW, nil, Enum.Font.GothamBlack)

	-- X72: a yellow bus stop bay with BUS STOP painted in it, like RivermereStation.png
	local bay = StationDresser.busBay(f)
	if bay then
		local y0, y1 = 0.225, 0.25 -- on the carriageway top (0.22)
		for _, z in { bay.z0, bay.z1 } do
			slab(m, f, "BayLine", bay.x0, bay.x1, y0, y1, z - 0.2, z + 0.2, MARKING_YELLOW, Enum.Material.SmoothPlastic).CastShadow = false
		end
		for _, x in { bay.x0, bay.x1 } do
			slab(m, f, "BayLine", x - 0.2, x + 0.2, y0, y1, bay.z0 + 0.2, bay.z1 - 0.2, MARKING_YELLOW, Enum.Material.SmoothPlastic).CastShadow = false
		end
		local busWord = slab(m, f, "BusStopMarking", (bay.x0 + bay.x1) / 2 - 8, (bay.x0 + bay.x1) / 2 + 8, y0, y1 + 0.01, bay.z0 + 0.6, bay.z1 - 0.6, MARKING_YELLOW)
		busWord.Transparency = 1
		busWord.CastShadow = false
		sign(busWord, Enum.NormalId.Top, "BUS STOP", MARKING_YELLOW, nil, Enum.Font.GothamBlack)
	end

	-- X73: double yellow lines inside both kerbs of the straight past the station,
	-- broken for the bus bay and the lay-by mouth (RivermereStation.png)
	for _, run in StationDresser.yellowLineRuns(f, layby, bay) do
		for _, offset in { 0.35, 0.85 } do
			local z = run.kerb + run.inward * offset
			slab(m, f, "YellowLine", run.x0, run.x1, 0.225, 0.25, z - 0.12, z + 0.12, MARKING_YELLOW, Enum.Material.SmoothPlastic).CastShadow = false
		end
	end

	-- X73: a finger post on the pavement between the stop and the taxi rank
	local carPark: Vector3? = nil
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use == "station car park" then
				carPark = block.centre
				-- X83: bay lines, some parked cars and a P sign on the greybox slab (top 0.3)
				local rng = Random.new(707)
				for _, bay in StationDresser.carParkBays(block, 30) do
					for _, dx in { -BAY_W / 2, BAY_W / 2 } do
						local line = part({ Name = "BayLine", Size = Vector3.new(0.35, 0.04, BAY_D - 2), CFrame = bay * CFrame.new(dx, 0.33, 0), Color = Color3.fromRGB(235, 235, 230), Parent = m })
						line.CastShadow = false
					end
					if rng:NextNumber() < 0.55 then
						-- nose in: the kit car's long axis runs along its Z, facing away from the aisle.
						-- X45 (TEMP, question 10): every other car repainted a dark colour
						local tints = { Color3.fromRGB(34, 52, 96), Color3.fromRGB(118, 30, 34), Color3.fromRGB(64, 68, 74) }
						local tint = if rng:NextNumber() < 0.5 then tints[rng:NextInteger(1, #tints)] else nil
						KitPlacer.place("HatchbackOrange", bay * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, math.pi, 0), m, { fallbackSize = Vector3.new(6, 4, 12), fallbackColor = Color3.fromRGB(150, 152, 156), tint = tint })
					end
				end
				local signAt = Vector3.new(block.centre.X + block.size.X / 2 - 4, 0, block.centre.Z - block.size.Z / 2 - 3)
				part({ Name = "ParkingSignPost", Size = Vector3.new(0.4, 8, 0.4), CFrame = CFrame.new(signAt + Vector3.new(0, 4, 0)), Color = IRON, Material = Enum.Material.Metal, Parent = m })
				local plate = part({ Name = "ParkingSign", Size = Vector3.new(3.2, 3.2, 0.2), CFrame = CFrame.new(signAt + Vector3.new(0, 8.4, 0.3)), Color = Color3.fromRGB(28, 70, 150), Parent = m })
				sign(plate, Enum.NormalId.Back, "P", Color3.new(1, 1, 1), nil, Enum.Font.GothamBlack)
				sign(plate, Enum.NormalId.Front, "P", Color3.new(1, 1, 1), nil, Enum.Font.GothamBlack)
			end
		end
	end
	local destinations: { SquareDresser.FingerDestination } = { "Town Centre", "Industrial Estate", "Riverside" }
	if carPark then
		table.insert(destinations, 2, { name = "Car Park", position = carPark })
	end
	SquareDresser.fingerPost(m, f * Vector3.new(layby.x0 - 10, 0, (layby.z0 + layby.z1) / 2), 0.45, destinations)

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
