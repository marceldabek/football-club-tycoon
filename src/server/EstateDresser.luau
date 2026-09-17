--!strict
-- Dresses the housing-infill and industrial-estate greybox blocks TownBuilder
-- leaves behind (backlog E4.1 / E5.1): "semis", "warehouse", "workshop",
-- "trade counter" and "builders yard", wherever they occur across the
-- districts (Northfields, Riverside, Westdale housing infill; Industrial
-- Estate sheds). Runs after TownBuilder.build().
--
-- Reference: assets/references/RivermereNorthfields.png (1930s semi-detached
-- pairs) and assets/references/rivermer.industrialestate.png (metal-clad
-- sheds with yards and unit signage).
--
-- A block's front is whichever of its four sides (+X / -X / +Z / -Z, in the
-- block's own yawed frame) sits nearest a TownLayout road. EstateBuilder's
-- convention is "front faces local -X", so the chosen side is turned to face
-- local -X; the other axis becomes the frontage width EstateBuilder.pairCount
-- spaces semi pairs along (or the shed's width).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local EstateBuilder = require(script.Parent.EstateBuilder)
local TownCrest = require(game:GetService("ReplicatedStorage").Shared.TownCrest)
local KitPlacer = require(script.Parent.KitPlacer)
local TerraceStreetDresser = require(script.Parent.TerraceStreetDresser)

local EstateDresser = {}

local USES: { [string]: boolean } = {
	semis = true,
	warehouse = true,
	workshop = true,
	["trade counter"] = true,
	["builders yard"] = true,
}

-- Pure: which side ("+X" | "-X" | "+Z" | "-Z") of the block's own (yawed)
-- frame sits nearest any road in `roads`, by sampling the four side
-- midpoints. Ties keep the first side checked (order below).
function EstateDresser.frontSide(block: TownLayout.Box, roads: { TownLayout.Road }): string
	local cf = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
	local hx, hz = block.size.X / 2, block.size.Z / 2
	local sides = {
		{ name = "-X", offset = Vector3.new(-hx, 0, 0) },
		{ name = "+X", offset = Vector3.new(hx, 0, 0) },
		{ name = "-Z", offset = Vector3.new(0, 0, -hz) },
		{ name = "+Z", offset = Vector3.new(0, 0, hz) },
	}
	local bestName, bestDist = "-X", math.huge
	for _, side in sides do
		local point = cf:PointToWorldSpace(side.offset)
		local dist = math.huge
		for _, road in roads do
			dist = math.min(dist, TownLayout.distanceToPolyline(point, road.points))
		end
		if dist < bestDist then
			bestDist = dist
			bestName = side.name
		end
	end
	return bestName
end

-- Pure: CFrame (with local -X turned to face the road) plus (width along the
-- final local Z, depth along the final local X). Exported for ForecourtDresser.
function EstateDresser.placement(block: TownLayout.Box, roads: { TownLayout.Road }): (CFrame, number, number)
	local side = EstateDresser.frontSide(block, roads)
	local base = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
	if side == "-X" then
		return base, block.size.Z, block.size.X
	elseif side == "+X" then
		return base * CFrame.Angles(0, math.pi, 0), block.size.Z, block.size.X
	elseif side == "-Z" then
		return base * CFrame.Angles(0, -math.pi / 2, 0), block.size.X, block.size.Z
	else -- "+Z"
		return base * CFrame.Angles(0, math.pi / 2, 0), block.size.X, block.size.Z
	end
end

local DRIVE_INSET = 0.05 -- driveways stop this far inside the block's front and back edges

-- Pure: (house depth, house-centre offset along the placement frame's local
-- X) for a semis block `depth` deep. Shared with ForecourtDresser so the front
-- paths start at the pushed-back front doors.
function EstateDresser.pairFit(depth: number): (number, number)
	return EstateBuilder.fitPair(depth, EstateBuilder.GARDEN_REACH, EstateBuilder.MIN_HOUSE_DEPTH)
end

-- X33: driveway cars use the kit hatchback shrunk to the drive. The kit car is
-- 9.8 x 19.4, wider than a 10-stud drive, so it is scaled down; below
-- DRIVE_CAR_MIN_SCALE it would look like a toy next to the street cars, and
-- the block car stays.
local DRIVE_CAR_KIT = "HatchbackOrange"
local DRIVE_CAR_MIN_SCALE = 0.7 -- TEMP
EstateDresser.DRIVE_CAR_MIN_WIDTH = 8 -- TEMP (X44): narrower drives get no car at all
local DRIVE_TOP = 0.35 -- EstateBuilder's driveway slab top; tyres sit 0.02 above it (no shared plane)

-- Pure: scale and yaw for a kit car of `footprint` on a drive `width` across
-- (placement local Z) and `length` long (local X). The yaw turns the car's
-- long axis onto local X. nil when it would need shrinking below the minimum.
function EstateDresser.driveCarFit(footprint: Vector3, width: number, length: number): (number?, number)
	local long, wide = math.max(footprint.X, footprint.Z), math.min(footprint.X, footprint.Z)
	local yaw = if footprint.Z > footprint.X then math.rad(90) else 0
	local scale = math.min(1, (width - 1.2) / wide, (length - 2) / long)
	if scale < DRIVE_CAR_MIN_SCALE then
		return nil, yaw
	end
	return scale, yaw
end

-- Pure (X44, question 7, TEMP): whether a drive gets the primitive block car.
-- Only when it was picked for a car, the kit car didn't fit, and the drive is
-- at least DRIVE_CAR_MIN_WIDTH across; a narrower drive stays empty rather
-- than holding a toy-sized car.
function EstateDresser.wantsBlockCar(withCar: boolean, kitScale: number?, width: number): boolean
	return withCar and kitScale == nil and width >= EstateDresser.DRIVE_CAR_MIN_WIDTH
end

-- X54: an estate entrance totem ("INDUSTRIAL ESTATE / Units / Deliveries /
-- Trade Counter") on the verge by the estate's bus stop, like
-- rivermer.industrialestate.png.
local TOTEM_STOP = "Industrial Estate"
local TOTEM_NAVY = Color3.fromRGB(28, 42, 74)

local function insideBox(p: Vector3, box: TownLayout.Box, margin: number): boolean
	local lp = (CFrame.new(box.centre) * CFrame.Angles(0, math.rad(box.yaw), 0)):PointToObjectSpace(Vector3.new(p.X, box.centre.Y, p.Z))
	return math.abs(lp.X) <= box.size.X / 2 + margin and math.abs(lp.Z) <= box.size.Z / 2 + margin
end

-- Pure: a spot on grass near `stop` (not on a road or pavement, but within a
-- few studs of one, clear of every block and at least 10 from the stop), plus
-- the road point it should face. nil if nothing nearby is clear.
function EstateDresser.totemSpot(stop: Vector3, roads: { TownLayout.Road }, blocks: { TownLayout.Box }, maxRadius: number?): (Vector3?, Vector3?)
	for radius = 12, maxRadius or 48, 4 do
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			local p = stop + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			local clear, nearest, nearestPoint = true, math.huge, nil
			for _, road in roads do
				local reach = road.width / 2 + TownLayout.PAVEMENT_WIDTH
				local d = TownLayout.distanceToPolyline(p, road.points)
				if d < reach + 1.5 then
					clear = false
					break
				end
				if d - reach < nearest then
					nearest = d - reach
					nearestPoint = road.points[1]
					-- aim at the closest point on that road
					local best = math.huge
					for i = 1, #road.points - 1 do
						local a0, b0 = road.points[i], road.points[i + 1]
						local ab = Vector3.new(b0.X - a0.X, 0, b0.Z - a0.Z)
						local t = if ab.Magnitude > 0 then math.clamp(Vector3.new(p.X - a0.X, 0, p.Z - a0.Z):Dot(ab) / ab.Magnitude ^ 2, 0, 1) else 0
						local q = a0 + ab * t
						local dq = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
						if dq < best then
							best, nearestPoint = dq, Vector3.new(q.X, 0, q.Z)
						end
					end
				end
			end
			if clear and nearest <= 6 then
				for _, box in blocks do
					if insideBox(p, box, 3) then
						clear = false
						break
					end
				end
			end
			if clear and nearest <= 6 then
				return Vector3.new(p.X, 0, p.Z), nearestPoint
			end
		end
	end
	return nil, nil
end

local function buildTotem(parent: Instance, at: Vector3, facing: Vector3)
	local m = Instance.new("Model")
	m.Name = "EstateTotem"
	m.Parent = parent
	local cf = CFrame.lookAt(at, Vector3.new(facing.X, 0, facing.Z))
	local function slab(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	slab("Plinth", Vector3.new(5, 0.8, 1.8), CFrame.new(0, 0.3, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
	local panel = slab("Panel", Vector3.new(4.4, 10, 0.7), CFrame.new(0, 0.65 + 5, 0), TOTEM_NAVY, Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.9, 0.42)
		label.Position = UDim2.fromScale(0.05, 0.04)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "RIVERMERE\n\nINDUSTRIAL\nESTATE"
		label.Parent = gui
		-- one label per destination row, so each line scales on its own
		local list = Instance.new("Frame")
		list.BackgroundColor3 = Color3.fromRGB(226, 228, 232)
		list.BorderSizePixel = 0
		list.Size = UDim2.fromScale(0.9, 0.44)
		list.Position = UDim2.fromScale(0.05, 0.52)
		list.Parent = gui
		for row, text in { "Units 1 - 6  >", "Units 7 - 12  >", "Deliveries  >", "Trade Counter  >" } do
			local line = Instance.new("TextLabel")
			line.BackgroundTransparency = 1
			line.Size = UDim2.fromScale(0.9, 0.22)
			line.Position = UDim2.fromScale(0.05, 0.02 + (row - 1) * 0.245)
			line.Font = Enum.Font.GothamMedium
			line.TextScaled = true
			line.TextXAlignment = Enum.TextXAlignment.Left
			line.TextColor3 = Color3.fromRGB(24, 28, 36)
			line.Text = text
			line.Parent = list
		end
	end
end

-- X56: carved stone name signs where the housing districts meet the town,
-- like the NORTHFIELDS stone in RivermereNorthfields.png. Searched from the
-- district block nearest the market square.
local DISTRICT_SIGNS = { "Northfields", "Westdale", "Riverside" }
local SIGN_STONE = Color3.fromRGB(214, 206, 188)

local function buildDistrictSign(parent: Instance, name: string, at: Vector3, facing: Vector3)
	local m = Instance.new("Model")
	m.Name = "DistrictSign"
	m:SetAttribute("District", name)
	m.Parent = parent
	local cf = CFrame.lookAt(at, Vector3.new(facing.X, 0, facing.Z))
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Size = Vector3.new(8, 0.6, 1.6)
	base.CFrame = cf * CFrame.new(0, 0.2, 0)
	base.Color = Color3.fromRGB(150, 146, 136)
	base.Material = Enum.Material.Slate
	base.Parent = m
	local stone = Instance.new("Part")
	stone.Name = "Stone"
	stone.Anchored = true
	stone.Size = Vector3.new(7.2, 3.2, 0.9)
	stone.CFrame = cf * CFrame.new(0, 0.45 + 1.6, 0)
	stone.Color = SIGN_STONE
	stone.Material = Enum.Material.Limestone
	stone.Parent = m
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = stone
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.86, 0.46)
		label.Position = UDim2.fromScale(0.07, 0.27)
		label.Font = Enum.Font.Merriweather
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(58, 58, 54)
		label.Text = string.upper(name)
		label.Parent = gui
	end
end

-- X75: a low brick wall with a black-and-white street name plate beside the
-- district stone, like the HAYFIELD CLOSE wall in RivermereNorthfields.png.
local NAME_WALL_BRICK = Color3.fromRGB(150, 76, 56)
local NAME_WALL_OFFSET = 11

-- Pure: where the name wall stands beside a district stone at `spot` facing the
-- road point `facing`: NAME_WALL_OFFSET to one side along the verge (right
-- first), on grass clear of every road's pavement by 1.5 and of every block by
-- 2. Returns the spot and the name of the nearest road (for the plate), or nil.
function EstateDresser.nameWallSpot(spot: Vector3, facing: Vector3, roads: { TownLayout.Road }, blocks: { TownLayout.Box }): (Vector3?, string?)
	local toRoad = Vector3.new(facing.X - spot.X, 0, facing.Z - spot.Z)
	if toRoad.Magnitude < 1e-3 then
		return nil, nil
	end
	local right = Vector3.new(-toRoad.Unit.Z, 0, toRoad.Unit.X)
	for _, side in { 1, -1 } do
		local p = Vector3.new(spot.X, 0, spot.Z) + right * side * NAME_WALL_OFFSET
		local clear, nearest, nearestName = true, math.huge, nil
		for _, road in roads do
			local d = TownLayout.distanceToPolyline(p, road.points)
			if d < road.width / 2 + TownLayout.PAVEMENT_WIDTH + 1.5 then
				clear = false
				break
			end
			if d < nearest then
				nearest, nearestName = d, road.name
			end
		end
		if clear then
			for _, box in blocks do
				if insideBox(p, box, 2) then
					clear = false
					break
				end
			end
		end
		if clear and nearestName then
			return p, nearestName
		end
	end
	return nil, nil
end

local function buildNameWall(parent: Instance, at: Vector3, toRoad: Vector3, roadName: string, district: string)
	local m = Instance.new("Model")
	m.Name = "NameWall"
	m:SetAttribute("Road", roadName)
	m.Parent = parent
	-- local -Z (the plate side) faces the road, square to it like the stone
	local cf = CFrame.lookAt(at, at + Vector3.new(toRoad.X, 0, toRoad.Z))
	local function piece(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	-- wall -0.2 .. 2.6 (sunk into the ground), coping 2.55 .. 2.85 overhanging 0.15
	piece("Wall", Vector3.new(8, 2.8, 1), CFrame.new(0, 1.2, 0), NAME_WALL_BRICK, Enum.Material.Brick)
	piece("Coping", Vector3.new(8.3, 0.3, 1.3), CFrame.new(0, 2.7, 0), Color3.fromRGB(198, 188, 168), Enum.Material.Concrete)
	local plate = piece("Plate", Vector3.new(6.2, 1.5, 0.15), CFrame.new(0, 1.45, -0.55), Color3.fromRGB(246, 246, 242), Enum.Material.SmoothPlastic)
	plate.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = plate
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 20, 22)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0.05, 0.08)
	nameLabel.Size = UDim2.fromScale(0.9, 0.58)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(20, 20, 22)
	nameLabel.Text = string.upper(roadName)
	nameLabel.Parent = frame
	local areaLabel = Instance.new("TextLabel")
	areaLabel.BackgroundTransparency = 1
	areaLabel.Position = UDim2.fromScale(0.2, 0.68)
	areaLabel.Size = UDim2.fromScale(0.6, 0.24)
	areaLabel.Font = Enum.Font.Gotham
	areaLabel.TextScaled = true
	areaLabel.TextColor3 = Color3.fromRGB(20, 20, 22)
	areaLabel.Text = district
	areaLabel.Parent = frame
end

-- Pure: the block of `district` nearest `centre` (where the district meets town), or nil.
function EstateDresser.gatewayBlock(district: TownLayout.District, centre: Vector3): TownLayout.Box?
	local best, bestDistance = nil, math.huge
	for _, block in district.blocks do
		local d = Vector3.new(block.centre.X - centre.X, 0, block.centre.Z - centre.Z).Magnitude
		if d < bestDistance then
			best, bestDistance = block, d
		end
	end
	return best
end

-- X57: a railed play area (climbing tower with slide, swings, bench) on the
-- grass near a district's gateway, like the one beside the NORTHFIELDS stone
-- in RivermereNorthfields.png.
local PLAY_AREA_DISTRICTS = { "Northfields" }
local PLAY_AREA_SIDE = 28 -- TEMP studs, railings included

local function closestOnPolyline(p: Vector3, points: { Vector3 }): Vector3
	local best, bestPoint = math.huge, Vector3.new(points[1].X, 0, points[1].Z)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local t = if ab.Magnitude > 0 then math.clamp(Vector3.new(p.X - a.X, 0, p.Z - a.Z):Dot(ab) / ab.Magnitude ^ 2, 0, 1) else 0
		local q = Vector3.new(a.X, 0, a.Z) + ab * t
		local d = Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
		if d < best then
			best, bestPoint = d, q
		end
	end
	return bestPoint
end

-- Pure (X74): a street tree spot on the kerb side of the pavement in front of
-- `p` (a semis pair's centre): on the nearest non-lane road, TREE_INSET in from
-- its carriageway edge. nil near another road's pavement (a junction mouth) or a
-- roundabout, near a bus stop, or within LAMP_CLEAR of an `avoid` point.
function EstateDresser.kerbTreeSpot(p: Vector3, roads: { TownLayout.Road }, avoid: { Vector3 }): Vector3?
	local best, road = math.huge, nil
	for _, r in roads do
		local d = TownLayout.distanceToPolyline(p, r.points)
		if d < best then
			best, road = d, r
		end
	end
	if not road or road.kind == "lane" then
		return nil
	end
	local q = closestOnPolyline(p, road.points)
	local away = Vector3.new(p.X - q.X, 0, p.Z - q.Z)
	if away.Magnitude < 1e-3 then
		return nil
	end
	local spot = q + away.Unit * (road.width / 2 + TerraceStreetDresser.TREE_INSET)
	for _, other in roads do
		if other ~= road and TownLayout.distanceToPolyline(spot, other.points) < other.width / 2 + TownLayout.PAVEMENT_WIDTH + TerraceStreetDresser.JUNCTION_CLEAR then
			return nil
		end
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		if Vector3.new(spot.X - rb.centre.X, 0, spot.Z - rb.centre.Z).Magnitude < rb.radius + TownLayout.PAVEMENT_WIDTH + TerraceStreetDresser.JUNCTION_CLEAR then
			return nil
		end
	end
	for _, stop in TownLayout.BUS_STOPS do
		if Vector3.new(spot.X - stop.position.X, 0, spot.Z - stop.position.Z).Magnitude < TerraceStreetDresser.BUS_STOP_CLEAR then
			return nil
		end
	end
	for _, a in avoid do
		if Vector3.new(spot.X - a.X, 0, spot.Z - a.Z).Magnitude < TerraceStreetDresser.LAMP_CLEAR then
			return nil
		end
	end
	return Vector3.new(spot.X, 0, spot.Z)
end

-- Pure: the centre of an axis-aligned `side` square of grass near `near`
-- whose sample points (about every 4 studs) are all 2+ studs clear of road
-- and pavement and 3+ clear of every block, with an edge within 8 of a
-- pavement, and `side` or more from every `avoid` point. Also returns the
-- unit axis (+-X or +-Z) toward the nearest road, for the gate. nil if none.
function EstateDresser.playAreaSpot(near: Vector3, roads: { TownLayout.Road }, blocks: { TownLayout.Box }, side: number, maxRadius: number, avoid: { Vector3 }?): (Vector3?, Vector3?)
	local half = side / 2
	local steps = math.ceil(side / 4)
	local function sample(c: Vector3, i: number, j: number): Vector3
		return c + Vector3.new(-half + side * i / steps, 0, -half + side * j / steps)
	end
	for radius = 0, maxRadius, 4 do
		local count = if radius == 0 then 1 else 24
		for k = 0, count - 1 do
			local a = k / count * math.pi * 2
			local c = Vector3.new(near.X + math.cos(a) * radius, 0, near.Z + math.sin(a) * radius)
			local ok = true
			for _, q in avoid or {} do
				if Vector3.new(q.X - c.X, 0, q.Z - c.Z).Magnitude < side then
					ok = false
					break
				end
			end
			local minGap, gapRoad = math.huge, nil
			for _, road in roads do
				if not ok then
					break
				end
				local reach = road.width / 2 + TownLayout.PAVEMENT_WIDTH
				if TownLayout.distanceToPolyline(c, road.points) - reach > half * 1.5 + 8 then
					continue -- the whole square is well clear of this road
				end
				for i = 0, steps do
					for j = 0, steps do
						local gap = TownLayout.distanceToPolyline(sample(c, i, j), road.points) - reach
						if gap < 2 then
							ok = false
							break
						elseif gap < minGap then
							minGap, gapRoad = gap, road
						end
					end
					if not ok then
						break
					end
				end
			end
			if not ok or not gapRoad or minGap > 8 then
				continue
			end
			for _, box in blocks do
				if not ok then
					break
				end
				if Vector3.new(box.centre.X - c.X, 0, box.centre.Z - c.Z).Magnitude > half * 1.5 + box.size.Magnitude / 2 + 3 then
					continue
				end
				for i = 0, steps do
					for j = 0, steps do
						if insideBox(sample(c, i, j), box, 3) then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
				end
			end
			if ok and gapRoad then
				local q = closestOnPolyline(c, gapRoad.points)
				local dx, dz = q.X - c.X, q.Z - c.Z
				local facing = if math.abs(dx) > math.abs(dz) then Vector3.new(math.sign(dx), 0, 0) else Vector3.new(0, 0, math.sign(dz))
				return c, facing
			end
		end
	end
	return nil, nil
end

local PLAY_WOOD = Color3.fromRGB(150, 104, 62)
local PLAY_RED = Color3.fromRGB(176, 52, 44)
local PLAY_STEEL = Color3.fromRGB(196, 200, 204)
local RAIL_BLACK = Color3.fromRGB(28, 30, 32)

local function buildPlayArea(parent: Instance, centre: Vector3, facing: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "PlayArea"
	-- local -Z (the front, with the gate) faces the road
	local cf = CFrame.lookAt(centre, centre + facing)
	local function piece(name: string, size: Vector3, at: CFrame, colour: Color3, material: Enum.Material, class: string?): BasePart
		local p = Instance.new(class or "Part") :: BasePart
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = at
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local half = PLAY_AREA_SIDE / 2

	-- green wetpour just inside the railings
	piece("Surface", Vector3.new(PLAY_AREA_SIDE - 0.4, 0.3, PLAY_AREA_SIDE - 0.4), cf * CFrame.new(0, 0.15, 0), Color3.fromRGB(64, 118, 74), Enum.Material.Concrete).CastShadow = false

	-- a path from the gate out to the pavement (playAreaSpot keeps it within 8;
	-- the far end tucks under the raised pavement)
	piece("Path", Vector3.new(4, 0.3, 9), cf * CFrame.new(0, 0.15, -half - 4.6), Color3.fromRGB(170, 168, 160), Enum.Material.Pavement).CastShadow = false

	-- black railings, with a gate gap in the middle of the front
	local GATE = 2.4
	local POSTS = 12
	local sides = {
		{ frame = CFrame.new(0, 0, -half), front = true },
		{ frame = CFrame.new(0, 0, half), front = false },
		{ frame = CFrame.new(-half, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), front = false },
		{ frame = CFrame.new(half, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), front = false },
	}
	for _, info in sides do
		local frame = cf * info.frame
		for i = 0, POSTS - 1 do -- the corner post at the far end belongs to the next side
			local x = -half + PLAY_AREA_SIDE * i / POSTS
			if not (info.front and math.abs(x) < GATE) then
				piece("Post", Vector3.new(0.25, 3.2, 0.25), frame * CFrame.new(x, 1.6, 0), RAIL_BLACK, Enum.Material.Metal).CastShadow = false
			end
		end
		local spans = if info.front then { { -half, -GATE + 0.2 }, { GATE - 0.2, half } } else { { -half, half } }
		for _, span in spans do
			for _, y in { 0.6, 2.9 } do
				piece("Rail", Vector3.new(span[2] - span[1], 0.18, 0.18), frame * CFrame.new((span[1] + span[2]) / 2, y, 0), RAIL_BLACK, Enum.Material.Metal).CastShadow = false
			end
		end
	end

	-- climbing tower (back left) with a pitched roof, and a slide down to the front
	local tower = cf * CFrame.new(-7, 0, 6)
	for _, sx in { -2.7, 2.7 } do
		for _, sz in { -2.7, 2.7 } do
			piece("TowerPost", Vector3.new(0.6, 8.9, 0.6), tower * CFrame.new(sx, 4.45, sz), PLAY_WOOD, Enum.Material.Wood)
		end
	end
	piece("Deck", Vector3.new(6, 0.4, 6), tower * CFrame.new(0, 4.2, 0), PLAY_WOOD, Enum.Material.WoodPlanks)
	piece("Board", Vector3.new(0.3, 1.4, 5.4), tower * CFrame.new(-3.2, 5.2, 0), PLAY_RED, Enum.Material.SmoothPlastic)
	piece("Board", Vector3.new(5.4, 1.4, 0.3), tower * CFrame.new(0, 5.2, 3.2), PLAY_RED, Enum.Material.SmoothPlastic)
	piece("Roof", Vector3.new(6.8, 1.8, 3.4), tower * CFrame.new(0, 9.8, -1.7), PLAY_RED, Enum.Material.SmoothPlastic, "WedgePart")
	piece("Roof", Vector3.new(6.8, 1.8, 3.4), tower * CFrame.new(0, 9.8, 1.7) * CFrame.Angles(0, math.pi, 0), PLAY_RED, Enum.Material.SmoothPlastic, "WedgePart")
	local slideTop = (tower * CFrame.new(0, 4.4, -3)).Position
	local slideFoot = (tower * CFrame.new(0, 0.6, -10)).Position
	local slide = CFrame.lookAt((slideTop + slideFoot) / 2, slideTop)
	local slideLength = (slideTop - slideFoot).Magnitude
	piece("Slide", Vector3.new(2.2, 0.2, slideLength), slide, PLAY_STEEL, Enum.Material.Metal)
	for _, sx in { -1.15, 1.15 } do
		piece("SlideLip", Vector3.new(0.15, 0.6, slideLength), slide * CFrame.new(sx, 0.3, 0), PLAY_STEEL, Enum.Material.Metal)
	end

	-- swings (back right): A-frame legs, top bar, two seats on chains
	local swing = cf * CFrame.new(6, 0, 7)
	piece("SwingBar", Vector3.new(11, 0.4, 0.4), swing * CFrame.new(0, 8, 0), PLAY_RED, Enum.Material.Metal)
	for _, sx in { -5, 5 } do
		for _, sz in { -2.5, 2.5 } do
			local top, foot = (swing * CFrame.new(sx, 8, 0)).Position, (swing * CFrame.new(sx, 0, sz)).Position
			piece("SwingLeg", Vector3.new(0.35, 0.35, (top - foot).Magnitude), CFrame.lookAt((top + foot) / 2, top), PLAY_RED, Enum.Material.Metal)
		end
	end
	for _, sx in { -2.2, 2.2 } do
		piece("SwingSeat", Vector3.new(1.8, 0.2, 0.8), swing * CFrame.new(sx, 1.8, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Plastic)
		for _, cx in { -0.75, 0.75 } do
			piece("Chain", Vector3.new(0.08, 5.9, 0.08), swing * CFrame.new(sx + cx, 4.85, 0), Color3.fromRGB(150, 150, 150), Enum.Material.Metal).CastShadow = false
		end
	end

	-- a bench for the grown-ups, facing the play kit
	local bench = cf * CFrame.new(8, 0, -10)
	piece("BenchSeat", Vector3.new(4, 0.25, 1.2), bench * CFrame.new(0, 1.5, 0), PLAY_WOOD, Enum.Material.WoodPlanks)
	piece("BenchBack", Vector3.new(4, 1.2, 0.2), bench * CFrame.new(0, 2.3, -0.6), PLAY_WOOD, Enum.Material.WoodPlanks)
	for _, sx in { -1.6, 1.6 } do
		piece("BenchLeg", Vector3.new(0.3, 1.4, 1), bench * CFrame.new(sx, 0.7, 0), RAIL_BLACK, Enum.Material.Metal)
	end

	m.Parent = parent
	return m
end

-- Removes the greybox body + roof for this exact block (matched by name and
-- XZ position, since a district's greybox has many same-named siblings).
local function removeGreyboxFor(greybox: Instance?, block: TownLayout.Box)
	if not greybox then
		return
	end
	for _, p in greybox:GetChildren() do
		if p:IsA("BasePart") and (p.Name == block.use or p.Name == block.use .. " roof") then
			if math.abs(p.Position.X - block.centre.X) <= 0.5 and math.abs(p.Position.Z - block.centre.Z) <= 0.5 then
				p:Destroy()
			end
		end
	end
end

-- Returns a summary line for the server log.
-- X119 (rivermer.industrialestate.png): the estate roundabout's island is
-- planted with shrubs inside a stone kerb, with a blue keep-left sign facing
-- traffic coming in from the High Street side. TownBuilder builds the grass
-- island disc (radius 0.35 of the roundabout, top Y 0.8).
EstateDresser.PLANTED_ROUNDABOUTS = { "Foundry Way Roundabout" }
local ISLAND_SHARE, ISLAND_TOP = 0.35, 0.8

function EstateDresser.islandShrubSpots(centre: Vector3, islandRadius: number): { Vector3 }
	local out = { Vector3.new(centre.X, 0, centre.Z) }
	local ring = islandRadius * 0.55
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + 0.3
		table.insert(out, Vector3.new(centre.X + math.cos(a) * ring, 0, centre.Z + math.sin(a) * ring))
	end
	return out
end

local function plantIsland(parent: Instance, rb: TownLayout.Roundabout)
	local m = Instance.new("Model")
	m.Name = "PlantedIsland"
	m:SetAttribute("Decor", true)
	m.Parent = parent
	local r = rb.radius * ISLAND_SHARE
	local kerb = Instance.new("Part")
	kerb.Name = "IslandKerb"
	kerb.Anchored = true
	kerb.Shape = Enum.PartType.Cylinder
	kerb.Size = Vector3.new(0.35, r * 2 + 0.6, r * 2 + 0.6)
	kerb.CFrame = CFrame.new(rb.centre.X, ISLAND_TOP - 0.02 - 0.175, rb.centre.Z) * CFrame.Angles(0, 0, math.pi / 2) -- top just under the grass: only the rim shows
	kerb.Color = Color3.fromRGB(196, 192, 184)
	kerb.Material = Enum.Material.Concrete
	kerb.CastShadow = false
	kerb.Parent = m
	for i, p in EstateDresser.islandShrubSpots(rb.centre, r) do
		local d = if i == 1 then 3.4 else 2.4
		local shrub = Instance.new("Part")
		shrub.Name = "IslandShrub"
		shrub.Anchored = true
		shrub.CanCollide = false
		shrub.Shape = Enum.PartType.Ball
		shrub.Size = Vector3.one * d
		shrub.CFrame = CFrame.new(p.X, ISLAND_TOP + d * 0.3, p.Z)
		shrub.Color = if i % 2 == 0 then Color3.fromRGB(70, 112, 52) else Color3.fromRGB(58, 98, 46)
		shrub.Material = Enum.Material.LeafyGrass
		shrub.CastShadow = false
		shrub.Parent = m
	end
	-- keep-left sign at the island's edge, facing east along the High Street approach
	local signAt = Vector3.new(rb.centre.X + r - 0.8, ISLAND_TOP, rb.centre.Z + 1.2)
	local post = Instance.new("Part")
	post.Name = "KeepLeftPost"
	post.Anchored = true
	post.Size = Vector3.new(0.2, 3.4, 0.2)
	post.CFrame = CFrame.new(signAt + Vector3.new(0, 1.7, 0))
	post.Color = Color3.fromRGB(150, 152, 156)
	post.Material = Enum.Material.Metal
	post.Parent = m
	local disc = Instance.new("Part")
	disc.Name = "KeepLeft"
	disc.Anchored = true
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, 1.8, 1.8)
	disc.CFrame = CFrame.new(signAt + Vector3.new(0.15, 3.1, 0)) -- axis along +X: the faces look east / west
	disc.Color = Color3.fromRGB(26, 76, 160)
	disc.Material = Enum.Material.SmoothPlastic
	disc.Parent = m
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = disc
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.new(1, 1, 1)
	arrow.Text = "↙"
	arrow.Parent = gui
end

-- X121 (rivermer.industrialestate.png): navy RIVERMERE / BUSINESS BUILDS
-- COMMUNITIES banners on the estate's street lamps, on the post's side away
-- from the lamp arm, facing along the road. 2 parts a lamp.
-- X131: shared with StationDresser; hangs `text` banners on the given lamps.
function EstateDresser.hangLampBanners(lamps: { Instance }, parent: Instance, text: string): number
	local count = 0
	for _, lamp in lamps do
		local post, arm = lamp:FindFirstChild("Post"), lamp:FindFirstChild("Arm")
		if not (lamp:IsA("Model") and lamp.Name == "TerraceLamp" and post and arm and post:IsA("BasePart") and arm:IsA("BasePart")) then
			continue
		end
		local out = Vector3.new(arm.Position.X - post.Position.X, 0, arm.Position.Z - post.Position.Z)
		if out.Magnitude < 1e-3 then
			continue
		end
		local away = -out.Unit
		local p = post.Position
		local bracketY = p.Y + 3.6
		local bracket = Instance.new("Part")
		bracket.Name = "BannerBracket"
		bracket.Anchored = true
		bracket.Size = Vector3.new(0.12, 0.12, 1.6)
		bracket.CFrame = CFrame.lookAt(Vector3.new(p.X, bracketY, p.Z) + away * 0.95, Vector3.new(p.X, bracketY, p.Z) + away * 2)
		bracket.Color = Color3.fromRGB(24, 24, 26)
		bracket.Material = Enum.Material.Metal
		bracket.CastShadow = false
		bracket.Parent = parent
		local banner = Instance.new("Part")
		banner.Name = "EstateBanner"
		banner.Anchored = true
		banner.Size = Vector3.new(1.3, 3.8, 0.1)
		local centre = Vector3.new(p.X, bracketY - 2.05, p.Z) + away * 1.0
		-- broad faces look along the road (perpendicular to the arm)
		banner.CFrame = CFrame.lookAt(centre, centre + Vector3.new(-away.Z, 0, away.X))
		banner.Color = Color3.fromRGB(24, 40, 78)
		banner.Material = Enum.Material.Fabric
		banner.CastShadow = false
		banner.Parent = parent
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.MaxDistance = 160
			gui.Parent = banner
			-- X254: the town crest above the wording, as on the reference banners
			local ink = Color3.fromRGB(236, 232, 220)
			TownCrest.draw(gui, ink, UDim2.fromScale(1, 0.26), UDim2.fromScale(0.5, 0.05), Vector2.new(0.5, 0))
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.9, 0.58)
			label.Position = UDim2.fromScale(0.05, 0.36)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextWrapped = true
			label.TextColor3 = ink
			label.Text = text
			label.Parent = gui
		end
		count += 1
	end
	return count
end

local function lampBanners(town: Instance, parent: Instance): number
	local dressing = town:FindFirstChild("Dressing")
	local estate = dressing and dressing:FindFirstChild("Industrial Estate")
	if not estate then
		return 0
	end
	return EstateDresser.hangLampBanners(estate:GetChildren(), parent, "RIVERMERE\n\nBUSINESS\nBUILDS\nCOMMUNITIES")
end

function EstateDresser.build(): string
	EstateBuilder.beginEstate()
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "estates: no town"
	end
	local old = town:FindFirstChild("Estates")
	if old then
		old:Destroy()
	end
	local estates = Instance.new("Folder")
	estates.Name = "Estates"
	local districts = town:FindFirstChild("Districts")
	local rng = Random.new(2026)
	local driveRng = Random.new(3030) -- separate stream so the pairs' front picks are unchanged
	local bedRng = Random.new(4040) -- X57 flower beds, likewise
	local treeRng = Random.new(5050) -- X74 street trees, likewise
	-- X74: lamps and terrace street trees the semis street trees keep clear of
	local treeAvoid: { Vector3 } = {}
	for _, folderName in { "Dressing", "TerraceStreets" } do
		local folder = town:FindFirstChild(folderName)
		for _, d in if folder then folder:GetDescendants() else {} do
			if d:IsA("Model") and (d.Name == "TerraceLamp" or d.Name == "StreetTree" or d:GetAttribute("Kit") == "LampVictorian") then
				table.insert(treeAvoid, d:GetPivot().Position)
			end
		end
	end
	local treeCount = 0
	local pairCount, shedCount, driveCount, kitCars = 0, 0, 0, 0

	for _, district in TownLayout.DISTRICTS do
		local hasBlocks = false
		for _, block in district.blocks do
			if USES[block.use] then
				hasBlocks = true
				break
			end
		end
		if not hasBlocks then
			continue
		end

		local m = Instance.new("Model")
		m.Name = district.name
		m.Parent = estates
		local greybox = districts and districts:FindFirstChild(district.name)

		for _, block in district.blocks do
			if not USES[block.use] then
				continue
			end
			removeGreyboxFor(greybox, block)
			local cf, width, depth = EstateDresser.placement(block, TownLayout.ROADS)

			if block.use == "semis" then
				-- X30: pairs centred in their slots with driveways between, and
				-- pushed back so the front garden stays inside the block
				local slots, drives = EstateBuilder.rowLayout(width, EstateBuilder.SIDE_GAP)
				local houseDepth, houseX = EstateDresser.pairFit(depth)
				for _, slot in slots do
					local pair = EstateBuilder.semiPair(cf * CFrame.new(houseX, 0, slot.z), slot.width, houseDepth, block.size.Y, m, rng)
					local front = pair:GetAttribute("Front")
					EstateBuilder.flowerBeds(cf * CFrame.new(houseX, 0, slot.z), slot.width, houseDepth, if type(front) == "string" then front else nil, pair, bedRng)
					-- X74: a street tree at the kerb in front of the pair (RivermereNorthfields.png is tree-lined)
					local spot = EstateDresser.kerbTreeSpot((cf * CFrame.new(houseX, 0, slot.z)).Position, TownLayout.ROADS, treeAvoid)
					if spot then
						TerraceStreetDresser.lightTree(m, spot, treeRng)
						table.insert(treeAvoid, spot)
						treeCount += 1
					end
					pairCount += 1
				end
				-- driveways run from the road edge back to the house backs (the block's
				-- back edge on a normal block), DRIVE_INSET short of both
				local driveFront = -depth / 2 + DRIVE_INSET
				local driveBack = math.min(depth / 2, houseX + houseDepth / 2) - DRIVE_INSET
				for _, drive in drives do
					local withCar = driveRng:NextInteger(1, 3) == 1
					local centre = CFrame.new((driveFront + driveBack) / 2, 0, (drive.z0 + drive.z1) / 2)
					local driveWidth, driveLength = drive.z1 - drive.z0, driveBack - driveFront
					local footprint = if withCar then KitPlacer.footprint(DRIVE_CAR_KIT) else nil
					local scale, yaw = nil, 0
					if footprint then
						scale, yaw = EstateDresser.driveCarFit(footprint, driveWidth, driveLength)
					end
					local blockCar = EstateDresser.wantsBlockCar(withCar, scale, driveWidth)
					local drivewayModel = EstateBuilder.driveway(cf * centre, driveWidth, driveLength, m, blockCar, driveRng)
					if footprint and scale then
						-- nose 1 stud inside the road end, like the block car
						local carLength = math.max(footprint.X, footprint.Z) * scale
						local at = cf * centre * CFrame.new(-driveLength / 2 + 1 + carLength / 2, DRIVE_TOP + 0.02, 0) * CFrame.Angles(0, yaw, 0)
						KitPlacer.place(DRIVE_CAR_KIT, at, drivewayModel, { scale = scale })
						kitCars += 1
					end
					driveCount += 1
				end
			else
				shedCount += 1
				-- X64: the body moves back so its yard stays inside the block
				local bodyDepth, bodyX = EstateBuilder.shedFit(depth)
				EstateBuilder.shed(cf * CFrame.new(bodyX, 0, 0), Vector3.new(width, block.size.Y, bodyDepth), m, rng, block.use, shedCount)
			end
		end
	end

	-- X54: estate entrance totem by the estate bus stop
	for _, stop in TownLayout.BUS_STOPS do
		if stop.name == TOTEM_STOP then
			local blocks: { TownLayout.Box } = {}
			for _, district in TownLayout.DISTRICTS do
				for _, block in district.blocks do
					table.insert(blocks, block)
				end
			end
			local spot, facing = EstateDresser.totemSpot(stop.position, TownLayout.ROADS, blocks)
			if spot and facing then
				buildTotem(estates, spot, facing)
			end
		end
	end

	-- X56: district name stones
	local signSpots: { [string]: Vector3 } = {}
	local allBlocks: { TownLayout.Box } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(allBlocks, block)
		end
	end
	for _, district in TownLayout.DISTRICTS do
		if table.find(DISTRICT_SIGNS, district.name) then
			local gateway = EstateDresser.gatewayBlock(district, TownLayout.SQUARE.centre)
			if gateway then
				local spot, facing = EstateDresser.totemSpot(gateway.centre, TownLayout.ROADS, allBlocks, 120)
				if spot and facing then
					buildDistrictSign(estates, district.name, spot, facing)
					signSpots[district.name] = spot
					-- X75: the street name wall beside the stone
					local wallAt, roadName = EstateDresser.nameWallSpot(spot, facing, TownLayout.ROADS, allBlocks)
					if wallAt and roadName then
						buildNameWall(estates, wallAt, facing - spot, roadName, district.name)
					end
				end
			end
		end
	end

	-- X57: a play area near the district stone
	for _, district in TownLayout.DISTRICTS do
		if table.find(PLAY_AREA_DISTRICTS, district.name) then
			local gateway = EstateDresser.gatewayBlock(district, TownLayout.SQUARE.centre)
			local avoid = { signSpots[district.name] }
			if gateway then
				local centre, facing = EstateDresser.playAreaSpot(gateway.centre, TownLayout.ROADS, allBlocks, PLAY_AREA_SIDE, 200, avoid)
				if centre and facing then
					buildPlayArea(estates, centre, facing)
				end
			end
		end
	end

	lampBanners(town, estates)
	for _, rb in TownLayout.ROUNDABOUTS do
		if table.find(EstateDresser.PLANTED_ROUNDABOUTS, rb.name) then
			plantIsland(estates, rb)
		end
	end

	estates.Parent = town
	local parts = 0
	for _, d in estates:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("estates: %d semis pairs, %d street trees, %d driveways (%d kit cars), %d sheds, %d parts"):format(pairCount, treeCount, driveCount, kitCars, shedCount, parts)
end

return EstateDresser
