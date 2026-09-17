--!strict
-- Dresses greybox districts, one district at a time. Runs after
-- TownBuilder.build() and finds a district's greybox volumes by name. Two modes:
--
--   KIT (DRESSED, backlog E3.1) -- swaps "terraced row" volumes for the kit
--     terrace (~166 parts a row) and lines the listed streets with kit lamps,
--     bins and parked cars. Anything missing from the kit falls back to
--     KitPlacer's grey blocks, so a place without ServerStorage.Kit still works.
--     Only the showpiece Mill Street block uses this.
--
--   LIGHT (every other district, and the kit district's rows away from its
--     kit streets; backlog X12 / X13) -- town-wide mode for mobile: every
--     "terraced row" volume becomes a TerraceBuilder.row (6-12 parts, textured
--     facades) turned so its front door faces the nearest road, and every
--     residential street whose midpoint is within LIGHT_STREET_RADIUS of one
--     of the district's blocks gets 6-part TerraceBuilder.lamp posts. Semis,
--     shops etc. stay greybox for now.
--
-- Reference: assets/references/RiveremereWestdale.png (red-brick terraces,
-- black lamp posts, bins at the kerb, cars parked along one side).
--
-- Kit (assets/kit/MANIFEST.md, "Town kit"):
--   TerraceRowVictorian  23 x 25 x 128, the row runs along its local Z, doors
--                        both sides; one row per "terraced row" block, scaled
--                        to the block's length
--   LampVictorian        4 x 20 x 2 black gas lamp
--   UKSP__LitterBin__LitterBin, Vehicles: HatchbackWhite / HatchbackOrange / VanWhite

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local KitPlacer = require(script.Parent.KitPlacer)
local TerraceBuilder = require(script.Parent.TerraceBuilder)

local StreetDresser = {}

-- TEMP: districts and streets that get the heavy kit dressing (showpiece only;
-- kit terraces are ~166 parts a row).
local DRESSED = {
	-- xRange: only this stretch gets the kit (the streets were extended to x 900)
	["Mill Street Terraces"] = { streets = { "Mill Street", "Weaver Street" }, xRange = { 0, 400 } },
} :: { [string]: { streets: { string }, xRange: { number }? } }
StreetDresser.DRESSED = DRESSED -- read by TerraceStreetDresser (X11)

-- Every other district gets the low-part TerraceBuilder row and lamp; the
-- kit district's rows away from its kit streets do too. The densified layout
-- has ~300 terraced rows, far too many for kit rows.
local KIT_ROW_RADIUS = 30 -- a kit district's row gets the kit only this close to a kit street
local LIGHT_STREET_RADIUS = 60
local LIGHT_LAMP_SPACING = 80 -- light streets are many; the kit streets keep 50

local ROW_KIT = "TerraceRowVictorian"
local ROW_LENGTH = 128 -- kit row length along its local Z
local LAMP_KIT = "LampVictorian"
local BIN_KIT = "UKSP__LitterBin__LitterBin"
-- HatchbackWhite is 153 parts, so the one-mesh hatchback is weighted in
-- X45: three generated hatchbacks (generate_mesh, one MeshPart each) join the kit car; vans stay 1 in 3
local CAR_KITS = { "HatchbackOrange", "HatchbackNavy", "HatchbackRed", "HatchbackSilver", "VanWhite", "VanWhite" }

local PAVEMENT_TOP = 0.45 -- TownBuilder.Y.PAVEMENT
local LAMP_SPACING = 50 -- staggered: each side gets every other one (the kit lamp is 36 parts)
local LAMP_INSET = 1.4 -- from the kerb edge onto the pavement
local BIN_EVERY = 3 -- a bin beside every third lamp
local CAR_GAP = 34 -- studs between parked cars (not every slot is filled)
local CAR_KERB_OFFSET = 4.2 -- car centre from the kerb, into the carriageway

-- Pure: yaw (radians) and scale for a kit row filling a layout block. The row
-- runs along its local Z, so a block that is long in X turns 90 degrees.
function StreetDresser.rowPlacement(block: TownLayout.Box): (CFrame, number)
	local longX = block.size.X >= block.size.Z
	local length = if longX then block.size.X else block.size.Z
	local yaw = math.rad(block.yaw) + (if longX then math.pi / 2 else 0)
	local scale = math.clamp(length / ROW_LENGTH, 0.7, 1.2)
	return CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, yaw, 0), scale
end

-- Pure: points along a polyline every `spacing`, starting half a gap in, with
-- the unit direction of the segment each point is on.
function StreetDresser.stations(points: { Vector3 }, spacing: number): { { position: Vector3, direction: Vector3 } }
	local out = {}
	local carry = spacing / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length < 1e-6 then
			continue
		end
		local dir = flat / length
		local s = carry
		while s <= length do
			table.insert(out, { position = Vector3.new(a.X, 0, a.Z) + dir * s, direction = dir })
			s += spacing
		end
		carry = s - length
	end
	return out
end

-- Pure: the point halfway along a polyline (by length, in XZ).
function StreetDresser.polylineMidpoint(points: { Vector3 }): Vector3
	local total = 0
	for i = 1, #points - 1 do
		total += Vector3.new(points[i + 1].X - points[i].X, 0, points[i + 1].Z - points[i].Z).Magnitude
	end
	local remaining = total / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length > 0 and remaining <= length then
			return Vector3.new(a.X, 0, a.Z) + flat * (remaining / length)
		end
		remaining -= length
	end
	local first = points[1]
	return Vector3.new(first.X, 0, first.Z)
end

-- Pure: XZ distance from p to a layout block's footprint (0 inside it).
function StreetDresser.distanceToBlock(p: Vector3, block: TownLayout.Box): number
	local cf = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
	local q = cf:PointToObjectSpace(Vector3.new(p.X, 0, p.Z))
	local dx = math.max(0, math.abs(q.X) - block.size.X / 2)
	local dz = math.max(0, math.abs(q.Z) - block.size.Z / 2)
	return math.sqrt(dx * dx + dz * dz)
end

local function districtNamed(name: string): TownLayout.District?
	for _, d in TownLayout.DISTRICTS do
		if d.name == name then
			return d
		end
	end
	return nil
end

-- Pure: residential streets that belong to a LIGHT district (midpoint within
-- LIGHT_STREET_RADIUS of one of its blocks), minus streets the kit mode owns.
function StreetDresser.lightStreets(districtName: string): { TownLayout.Road }
	local out: { TownLayout.Road } = {}
	local district = districtNamed(districtName)
	if not district then
		return out
	end
	local kitOwned: { [string]: boolean } = {}
	for _, spec in DRESSED do
		for _, name in spec.streets do
			kitOwned[name] = true
		end
	end
	for _, road in TownLayout.ROADS do
		if road.kind ~= "residential" or kitOwned[road.name] then
			continue
		end
		local mid = StreetDresser.polylineMidpoint(road.points)
		for _, block in district.blocks do
			if StreetDresser.distanceToBlock(mid, block) <= LIGHT_STREET_RADIUS then
				table.insert(out, road)
				break
			end
		end
	end
	return out
end

-- Pure: like rowPlacement (row along the block's long side = local Z), but
-- turned 180 degrees when needed so the front (local -X) faces the nearest road.
function StreetDresser.lightRowPlacement(block: TownLayout.Box): CFrame
	local cf = StreetDresser.rowPlacement(block)
	local depth = math.min(block.size.X, block.size.Z)
	local front = cf:VectorToWorldSpace(Vector3.new(-1, 0, 0))
	local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
	local function nearestRoad(p: Vector3): number
		local best = math.huge
		for _, road in TownLayout.ROADS do
			best = math.min(best, TownLayout.distanceToPolyline(p, road.points))
		end
		return best
	end
	if nearestRoad(centre - front * depth) < nearestRoad(centre + front * depth) then
		cf *= CFrame.Angles(0, math.pi, 0)
	end
	return cf
end

local function roadNamed(name: string): TownLayout.Road?
	for _, road in TownLayout.ROADS do
		if road.name == name then
			return road
		end
	end
	return nil
end

local function removeGreyboxRows(greybox: Instance?)
	if greybox then
		for _, p in greybox:GetChildren() do
			if p.Name == "terraced row" or p.Name == "terraced row roof" then
				p:Destroy()
			end
		end
	end
end

-- Where the lamp for station i of a street goes: staggered sides, on the
-- pavement, facing so local -Z leans over the carriageway.
local function lampSpot(road: TownLayout.Road, i: number, st: { position: Vector3, direction: Vector3 }): (CFrame, Vector3, Vector3, number)
	local side = if i % 2 == 0 then 1 else -1
	local right = Vector3.new(-st.direction.Z, 0, st.direction.X)
	local lateral = side * (road.width / 2 + LAMP_INSET)
	local pos = st.position + right * lateral + Vector3.new(0, PAVEMENT_TOP, 0)
	return CFrame.lookAt(pos, pos - right * side), pos, right, side
end

-- True when a block fronts one of the named streets (kit showpiece rows).
local function nearStreets(block: TownLayout.Box, streets: { string }): boolean
	for _, name in streets do
		local road = roadNamed(name)
		if road then
			local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
			local reach = road.width / 2 + TownLayout.PAVEMENT_WIDTH + math.min(block.size.X, block.size.Z) / 2 + KIT_ROW_RADIUS
			if TownLayout.distanceToPolyline(centre, road.points) <= reach then
				return true
			end
		end
	end
	return false
end

local function inRange(x: number, range: { number }?): boolean
	return range == nil or (x >= range[1] and x <= range[2])
end

-- Pure: true when StreetDresser gives this district's "terraced row" block the
-- kit row (inside a DRESSED district's xRange and fronting one of its streets).
function StreetDresser.isKitRow(districtName: string, block: TownLayout.Box): boolean
	local spec = DRESSED[districtName]
	return spec ~= nil and block.use == "terraced row" and inRange(block.centre.X, spec.xRange) and nearStreets(block, spec.streets)
end

-- Pure: XZ positions (Y = 0) of every lamp post StreetDresser can put on this
-- street: the kit streets' staggered 50-stud stations (only every other one
-- beyond the showpiece stretch), otherwise the light 80-stud stations. A light
-- street that ends up unlit just gets a few spots avoided for nothing.
function StreetDresser.lampPositions(road: TownLayout.Road): { Vector3 }
	local out: { Vector3 } = {}
	local xRange: { number }? = nil
	local kit = false
	for _, spec in DRESSED do
		if table.find(spec.streets, road.name) then
			kit, xRange = true, spec.xRange
		end
	end
	for i, st in StreetDresser.stations(road.points, if kit then LAMP_SPACING else LIGHT_LAMP_SPACING) do
		if kit and not inRange(st.position.X, xRange) and i % 2 ~= 0 then
			continue
		end
		local _, pos = lampSpot(road, i, st)
		table.insert(out, Vector3.new(pos.X, 0, pos.Z))
	end
	return out
end

local function dressRows(districtName: string, streets: { string }, xRange: { number }?, greybox: Instance?, parent: Instance, rng: Random): (number, number)
	local district = districtNamed(districtName)
	if not district then
		return 0, 0
	end
	removeGreyboxRows(greybox)
	local placed, light = 0, 0
	for _, block in district.blocks do
		if block.use ~= "terraced row" then
			continue
		end
		if not StreetDresser.isKitRow(districtName, block) then
			local length = math.max(block.size.X, block.size.Z)
			local depth = math.min(block.size.X, block.size.Z)
			TerraceBuilder.row(StreetDresser.lightRowPlacement(block), length, depth, block.size.Y, parent, rng)
			light += 1
			continue
		end
		local cf, scale = StreetDresser.rowPlacement(block)
		KitPlacer.place(ROW_KIT, cf, parent, {
			scale = scale,
			fallbackSize = Vector3.new(block.size.Z, block.size.Y, block.size.X),
			fallbackColor = Color3.fromRGB(150, 90, 70),
			fallbackMaterial = Enum.Material.Brick,
		})
		placed += 1
	end
	return placed, light
end

local function dressStreet(road: TownLayout.Road, xRange: { number }?, parent: Instance, rng: Random): number
	local count = 0
	local half = road.width / 2
	for i, st in StreetDresser.stations(road.points, LAMP_SPACING) do
		-- lamp heads lean over the road
		local facing, pos, right, side = lampSpot(road, i, st)
		if not inRange(st.position.X, xRange) then
			-- beyond the showpiece stretch: the light lamp, at about the light spacing
			if i % 2 == 0 then
				TerraceBuilder.lamp(facing, parent)
				count += 1
			end
			continue
		end
		KitPlacer.place(LAMP_KIT, facing, parent, { fallbackSize = Vector3.new(0.8, 16, 0.8), fallbackColor = Color3.fromRGB(25, 25, 28) })
		count += 1
		if i % BIN_EVERY == 0 or i % BIN_EVERY == 1 then
			local binPos = pos + st.direction * 3
			KitPlacer.place(BIN_KIT, CFrame.lookAt(binPos, binPos - right * side), parent, {
				fallbackSize = Vector3.new(2, 3.5, 2),
				fallbackColor = Color3.fromRGB(30, 30, 30),
			})
			count += 1
		end
	end
	-- parked cars along one kerb, not every slot filled
	for _, st in StreetDresser.stations(road.points, CAR_GAP) do
		if rng:NextNumber() < 0.45 or not inRange(st.position.X, xRange) then
			continue
		end
		local right = Vector3.new(-st.direction.Z, 0, st.direction.X)
		local pos = st.position + right * (half - CAR_KERB_OFFSET) + Vector3.new(0, 0.25, 0)
		local kit = CAR_KITS[rng:NextInteger(1, #CAR_KITS)]
		KitPlacer.place(kit, CFrame.lookAt(pos, pos + st.direction), parent, {
			fallbackSize = Vector3.new(6, 5, 12),
			fallbackColor = Color3.fromRGB(90, 100, 120),
			yawJitter = math.rad(2),
			rng = rng,
		})
		count += 1
	end
	return count
end

local function dressLightRows(districtName: string, greybox: Instance?, parent: Instance, rng: Random): number
	local district = districtNamed(districtName)
	if not district then
		return 0
	end
	removeGreyboxRows(greybox)
	local placed = 0
	for _, block in district.blocks do
		if block.use ~= "terraced row" then
			continue
		end
		local length = math.max(block.size.X, block.size.Z)
		local depth = math.min(block.size.X, block.size.Z)
		TerraceBuilder.row(StreetDresser.lightRowPlacement(block), length, depth, block.size.Y, parent, rng)
		placed += 1
	end
	return placed
end

local function dressLightStreet(road: TownLayout.Road, parent: Instance): number
	local count = 0
	for i, st in StreetDresser.stations(road.points, LIGHT_LAMP_SPACING) do
		local facing = lampSpot(road, i, st)
		TerraceBuilder.lamp(facing, parent)
		count += 1
	end
	return count
end

-- Returns a summary line for the log.
function StreetDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "no town"
	end
	local old = town:FindFirstChild("Dressing")
	if old then
		old:Destroy()
	end
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	local districts = town:FindFirstChild("Districts")
	local rng = Random.new(1884)
	local lightRng = Random.new(1885)
	local rows, lightRows, props = 0, 0, 0
	for districtName, spec in DRESSED do
		local m = Instance.new("Model")
		m.Name = districtName
		m.Parent = dressing
		local kit, light = dressRows(districtName, spec.streets, spec.xRange, districts and districts:FindFirstChild(districtName), m, lightRng)
		rows += kit
		lightRows += light
		for _, streetName in spec.streets do
			local road = roadNamed(streetName)
			if road then
				props += dressStreet(road, spec.xRange, m, rng)
			end
		end
	end
	-- every other district, in layout order so the seeded facades are stable;
	-- a street near two districts only gets lamps once
	local litStreets: { [string]: boolean } = {}
	for _, district in TownLayout.DISTRICTS do
		if DRESSED[district.name] then
			continue
		end
		local m = Instance.new("Model")
		m.Name = district.name
		m.Parent = dressing
		lightRows += dressLightRows(district.name, districts and districts:FindFirstChild(district.name), m, lightRng)
		for _, road in StreetDresser.lightStreets(district.name) do
			if not litStreets[road.name] then
				litStreets[road.name] = true
				props += dressLightStreet(road, m)
			end
		end
	end
	-- the kit district's own residential streets beyond the kit ones
	for districtName in DRESSED do
		local m = dressing:FindFirstChild(districtName)
		for _, road in StreetDresser.lightStreets(districtName) do
			if m and not litStreets[road.name] then
				litStreets[road.name] = true
				props += dressLightStreet(road, m)
			end
		end
	end
	dressing.Parent = town
	local parts = 0
	for _, d in dressing:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("dressed: %d kit rows, %d light rows, %d props, %d parts"):format(rows, lightRows, props, parts)
end

return StreetDresser
