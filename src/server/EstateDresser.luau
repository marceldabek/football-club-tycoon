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
					EstateBuilder.semiPair(cf * CFrame.new(houseX, 0, slot.z), slot.width, houseDepth, block.size.Y, m, rng)
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
					local drivewayModel = EstateBuilder.driveway(cf * centre, driveWidth, driveLength, m, withCar and scale == nil, driveRng)
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
				EstateBuilder.shed(cf, Vector3.new(width, block.size.Y, depth), m, rng, block.use)
				shedCount += 1
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
