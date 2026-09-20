--!strict
-- v1 shop placement maths (which way a shop / flats / civic block faces). The
-- BUILDING half was retired by v3 Lane I: TradeAssembler builds those blocks.
--
-- Each building turns to face its nearest road (ShopDresser.facingYaw): the
-- long side faces the road, or for near-square blocks whichever side is
-- closest to a road.
--
-- Reference: assets/references/RivermereCenter.png, RiveremereWestdale.png.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

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
ShopDresser.FLATS_USES = { flats = true, ["waterfront flats"] = true } :: { [string]: boolean } -- X78: the Riverside block was left greybox
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

-- v3 (Lane I): ShopDresser.build is retired; TradeAssembler builds every shop,
-- pub, flats and civic block from the kit. The placement maths above stays for
-- ForecourtDresser and ImperfectionDresser until stage 2 re-points them at
-- TradeAssembler.lotFrame.

return ShopDresser
