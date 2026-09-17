--!strict
-- Replaces the greybox shop, flats and civic volumes in every district with
-- ShopBuilder buildings (backlog E2.1). Runs after TownBuilder.build() (and the
-- other dressers); output goes to workspace.Town.Shops, one Model per district.
--
-- Greybox volumes are found under workspace.Town.Districts.<district> by name
-- (block.use and block.use .. " roof", see TownBuilder.buildBlock) AND by
-- position, since many blocks share a use.
--
-- Each building turns to face its nearest road (ShopDresser.facingYaw): the
-- long side faces the road, or for near-square blocks whichever side is
-- closest to a road.
--
-- Reference: assets/references/RivermereCenter.png, RiveremereWestdale.png.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local ShopBuilder = require(script.Parent.ShopBuilder)

local ShopDresser = {}

ShopDresser.SHOP_USES = {
	shops = true,
	["shops with flats"] = true,
	pub = true,
	["pub and cafes"] = true,
	["corner shop"] = true,
	supermarket = true,
	["park cafe"] = true,
} :: { [string]: boolean }
ShopDresser.FLATS_USES = { flats = true } :: { [string]: boolean }
ShopDresser.CIVIC_USES = { ["town hall"] = true, school = true } :: { [string]: boolean }

local SQUARE_RATIO = 1.3 -- blocks closer to square than this may face any side
local MATCH_RADIUS = 0.5

function ShopDresser.handles(use: string): boolean
	return ShopDresser.SHOP_USES[use] == true or ShopDresser.FLATS_USES[use] == true or ShopDresser.CIVIC_USES[use] == true
end

-- Pure: yaw (radians) for the building frame so its local -X (the street
-- front) faces the nearest road. Candidates are the block's two long sides, or
-- all four for near-square blocks; each is scored by the distance from the
-- middle of that side to the nearest road's edge. Ties keep the earlier side.
function ShopDresser.facingYaw(block: TownLayout.Box, roads: { TownLayout.Road }): number
	local sx, sz = block.size.X, block.size.Z
	local square = math.max(sx, sz) / math.max(1e-6, math.min(sx, sz)) < SQUARE_RATIO
	-- block-local outward normals with the half extent along them
	local candidates: { { n: Vector3, half: number } } = {}
	if square or sx >= sz then
		table.insert(candidates, { n = Vector3.new(0, 0, -1), half = sz / 2 })
		table.insert(candidates, { n = Vector3.new(0, 0, 1), half = sz / 2 })
	end
	if square or sz > sx then
		table.insert(candidates, { n = Vector3.new(-1, 0, 0), half = sx / 2 })
		table.insert(candidates, { n = Vector3.new(1, 0, 0), half = sx / 2 })
	end
	local blockCf = CFrame.Angles(0, math.rad(block.yaw), 0)
	local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
	local bestYaw, bestDist = 0, math.huge
	for _, c in candidates do
		local n = blockCf:VectorToWorldSpace(c.n)
		local p = centre + n * c.half
		local d = math.huge
		for _, road in roads do
			d = math.min(d, TownLayout.distanceToPolyline(p, road.points) - road.width / 2)
		end
		if d < bestDist then
			bestDist = d
			-- rotating local -X by yaw about Y gives (-cos yaw, 0, sin yaw)
			bestYaw = math.atan2(n.Z, -n.X)
		end
	end
	return bestYaw
end

-- Pure: the building frame plus its length (along local Z) and depth (along local X).
function ShopDresser.placement(block: TownLayout.Box, roads: { TownLayout.Road }): (CFrame, number, number)
	local yaw = ShopDresser.facingYaw(block, roads)
	local cf = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, yaw, 0)
	local blockCf = CFrame.Angles(0, math.rad(block.yaw), 0)
	local along = blockCf:VectorToObjectSpace(cf.LookVector)
	local across = blockCf:VectorToObjectSpace(cf.RightVector)
	local length = math.abs(along.X) * block.size.X + math.abs(along.Z) * block.size.Z
	local depth = math.abs(across.X) * block.size.X + math.abs(across.Z) * block.size.Z
	return cf, length, depth
end

local function removeGreybox(greybox: Instance?, block: TownLayout.Box): number
	if not greybox then
		return 0
	end
	local removed = 0
	local roofName = block.use .. " roof"
	for _, p in greybox:GetChildren() do
		if (p.Name == block.use or p.Name == roofName) and p:IsA("BasePart") then
			local pos = p.Position
			if math.abs(pos.X - block.centre.X) <= MATCH_RADIUS and math.abs(pos.Z - block.centre.Z) <= MATCH_RADIUS then
				p:Destroy()
				removed += 1
			end
		end
	end
	return removed
end

-- Returns a summary line for the log.
function ShopDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "shops: no town"
	end
	local old = town:FindFirstChild("Shops")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Shops"
	local districts = town:FindFirstChild("Districts")
	local rng = Random.new(2101)
	local blocks = 0
	for _, district in TownLayout.DISTRICTS do
		local m: Model? = nil
		local greybox = districts and districts:FindFirstChild(district.name)
		for _, block in district.blocks do
			if not ShopDresser.handles(block.use) then
				continue
			end
			if not m then
				local model = Instance.new("Model")
				model.Name = district.name
				model.Parent = folder
				m = model
			end
			local parent = m :: Model
			removeGreybox(greybox, block)
			local cf, length, depth = ShopDresser.placement(block, TownLayout.ROADS)
			if ShopDresser.FLATS_USES[block.use] then
				ShopBuilder.flats(cf, Vector3.new(depth, block.size.Y, length), parent)
			elseif ShopDresser.CIVIC_USES[block.use] then
				ShopBuilder.civic(cf, Vector3.new(depth, block.size.Y, length), parent, block.use)
			else
				ShopBuilder.shopRow(cf, length, depth, block.size.Y, parent, rng, block.use, district.name)
			end
			blocks += 1
		end
	end
	folder.Parent = town
	local parts = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("shops: %d blocks, %d parts"):format(blocks, parts)
end

return ShopDresser
