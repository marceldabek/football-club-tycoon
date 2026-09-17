--!strict
-- Dresses greybox districts with kit models, one street at a time (backlog
-- E3.1). Runs after TownBuilder.build(): finds a district's greybox volumes
-- by name, swaps them for kit buildings, and lines the district's streets
-- with lamps, bins and parked cars. Anything missing from the kit falls back
-- to KitPlacer's grey blocks, so a place without ServerStorage.Kit still works.
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

local StreetDresser = {}

-- TEMP: which districts and streets get kit dressing so far. Kit terraces are
-- ~166 parts a row, so the rest of town stays greybox until a low-part row exists.
local DRESSED = {
	["Mill Street Terraces"] = { streets = { "Mill Street", "Weaver Street" } },
}

local ROW_KIT = "TerraceRowVictorian"
local ROW_LENGTH = 128 -- kit row length along its local Z
local LAMP_KIT = "LampVictorian"
local BIN_KIT = "UKSP__LitterBin__LitterBin"
-- HatchbackWhite is 153 parts, so the one-mesh hatchback is weighted in
local CAR_KITS = { "HatchbackOrange", "HatchbackOrange", "VanWhite" }

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

local function roadNamed(name: string): TownLayout.Road?
	for _, road in TownLayout.ROADS do
		if road.name == name then
			return road
		end
	end
	return nil
end

local function dressRows(districtName: string, greybox: Instance?, parent: Instance): number
	local district: TownLayout.District? = nil
	for _, d in TownLayout.DISTRICTS do
		if d.name == districtName then
			district = d
		end
	end
	if not district then
		return 0
	end
	if greybox then
		for _, p in greybox:GetChildren() do
			if p.Name == "terraced row" or p.Name == "terraced row roof" then
				p:Destroy()
			end
		end
	end
	local placed = 0
	for _, block in district.blocks do
		if block.use ~= "terraced row" then
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
	return placed
end

local function dressStreet(road: TownLayout.Road, parent: Instance, rng: Random): number
	local count = 0
	local half = road.width / 2
	for i, st in StreetDresser.stations(road.points, LAMP_SPACING) do
		local side = if i % 2 == 0 then 1 else -1
		do
			local right = Vector3.new(-st.direction.Z, 0, st.direction.X)
			local lateral = side * (half + LAMP_INSET)
			local pos = st.position + right * lateral + Vector3.new(0, PAVEMENT_TOP, 0)
			-- lamp heads lean over the road
			local facing = CFrame.lookAt(pos, pos - right * side)
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
	end
	-- parked cars along one kerb, not every slot filled
	for _, st in StreetDresser.stations(road.points, CAR_GAP) do
		if rng:NextNumber() < 0.45 then
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
	local rows, props = 0, 0
	for districtName, spec in DRESSED do
		local m = Instance.new("Model")
		m.Name = districtName
		m.Parent = dressing
		rows += dressRows(districtName, districts and districts:FindFirstChild(districtName), m)
		for _, streetName in spec.streets do
			local road = roadNamed(streetName)
			if road then
				props += dressStreet(road, m, rng)
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
	return ("dressed: %d rows, %d props, %d parts"):format(rows, props, parts)
end

return StreetDresser
