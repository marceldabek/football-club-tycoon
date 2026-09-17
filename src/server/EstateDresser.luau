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
local KitPlacer = require(script.Parent.KitPlacer)

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
function EstateDresser.build(): string
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
				EstateBuilder.shed(cf, Vector3.new(width, block.size.Y, depth), m, rng, block.use, shedCount)
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

	estates.Parent = town
	local parts = 0
	for _, d in estates:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("estates: %d semis pairs, %d driveways (%d kit cars), %d sheds, %d parts"):format(pairCount, driveCount, kitCars, shedCount, parts)
end

return EstateDresser
