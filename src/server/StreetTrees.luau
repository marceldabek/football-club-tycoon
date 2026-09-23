--!strict
-- #28: street trees on the grass verges, the club grounds' oaks (TreeKit, OakPack6).
--
-- Only the ring road and the main roads have a verge wide enough for a tree: between the
-- outer edge of the paving and where the street's own ground ends (RoadTiles.corridorHalf)
-- there are ~12 studs on the ring road and ~5.5 on a main road; a residential street keeps
-- only 2.5 before its front gardens, which get garden trees instead (HouseAssembler).
--
-- Spots run down the middle of each verge at SPACING, on the filleted centrelines (the kit
-- bends), both sides. A spot is dropped near a junction mouth, a roundabout, a bus stop, a
-- bridge, the river, the railway, a club plot, a special block or a frontage lot (all pure,
-- tested), and at build time if a lamp, sign or shelter already stands there. Decor: the
-- whole folder hides on Low. SPACING and MAX are TEMP (question in the lane H report).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local RoadPaths = require(ReplicatedStorage.Shared.RoadPaths)
local PedestrianMath = require(ReplicatedStorage.Shared.PedestrianMath)
local FrontPaths = require(ReplicatedStorage.Shared.FrontPaths)
local StreetDresser = require(script.Parent.StreetDresser)
local TreeKit = require(script.Parent.TreeKit)

local StreetTrees = {}

StreetTrees.KINDS = { ring = true, main = true } :: { [string]: boolean }
StreetTrees.MIN_VERGE = 4 -- narrower verges get none
StreetTrees.SPACING = 55 -- TEMP
StreetTrees.MAX = 240 -- TEMP: ~3 MeshParts a tree
StreetTrees.JUNCTION_CLEAR = 10 -- past a crossing road's own ground
StreetTrees.ROUNDABOUT_CLEAR = 14 -- past the ring's rim
StreetTrees.STOP_CLEAR = 16
StreetTrees.RIVER_CLEAR = 10
StreetTrees.RAIL_CLEAR = 10
StreetTrees.BLOCK_CLEAR = 4
StreetTrees.LOT_CLEAR = 2
StreetTrees.HEIGHT = { 16, 21 }
local SEED = 2828

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Pure: the verge's middle, as a distance from the centreline; nil when there is no verge
-- worth a tree.
function StreetTrees.vergeOffset(road: TownLayout.Road): number?
	if not StreetTrees.KINDS[road.kind] then
		return nil
	end
	local corridor = RoadTiles.corridorHalf(road.kind, road.width)
	if not corridor then
		return nil
	end
	local paving = FrontPaths.pavingReach(road)
	if corridor - paving < StreetTrees.MIN_VERGE then
		return nil
	end
	return (corridor + paving) / 2
end

local lotCache: { TownFrontage.Lot }? = nil
local function frontageLots(): { TownFrontage.Lot }
	if not lotCache then
		lotCache = TownFrontage.generate()
	end
	return lotCache :: { TownFrontage.Lot }
end

local function inLot(p: Vector3, lot: TownFrontage.Lot, grow: number): boolean
	local l = TownFrontage.lotCFrame(lot):PointToObjectSpace(Vector3.new(p.X, lot.centre.Y, p.Z))
	return math.abs(l.X) <= lot.size.X / 2 + grow and math.abs(l.Z) <= lot.size.Z / 2 + grow
end

-- Pure: is this verge spot on road `own` clear of everything else?
function StreetTrees.clear(p: Vector3, own: TownLayout.Road): boolean
	for _, road in TownLayout.ROADS do
		if road.name == own.name then
			if TownLayout.distanceToPolyline(p, road.points) < FrontPaths.pavingReach(road) + 1.5 then
				return false
			end
		else
			local corridor = RoadTiles.corridorHalf(road.kind, road.width) or road.width / 2
			if TownLayout.distanceToPolyline(p, road.points) < corridor + StreetTrees.JUNCTION_CLEAR then
				return false
			end
		end
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		if (flat(rb.centre) - flat(p)).Magnitude < rb.radius + TownLayout.PAVEMENT_WIDTH + StreetTrees.ROUNDABOUT_CLEAR then
			return false
		end
	end
	for _, stop in TownLayout.BUS_STOPS do
		if (flat(stop.position) - flat(p)).Magnitude < StreetTrees.STOP_CLEAR then
			return false
		end
	end
	for i = 1, #TownLayout.PLOTS do
		if TownLayout.pointInPlot(p, i) or (flat(TownLayout.PLOTS[i].busStop) - flat(p)).Magnitude < StreetTrees.STOP_CLEAR then
			return false
		end
	end
	if PedestrianMath.inRiver(p, TownLayout.RIVER, StreetTrees.RIVER_CLEAR) then
		return false
	end
	if TownLayout.distanceToPolyline(p, TownLayout.RAIL.points) < TownLayout.RAIL.width / 2 + StreetTrees.RAIL_CLEAR then
		return false
	end
	if PedestrianMath.roadBridgeAt(p, TownLayout.BRIDGES, 12) then
		return false
	end
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if StreetDresser.distanceToBlock(p, block) < StreetTrees.BLOCK_CLEAR then
				return false
			end
		end
	end
	for _, lot in frontageLots() do
		if (flat(lot.centre) - flat(p)).Magnitude < 120 and inLot(p, lot, StreetTrees.LOT_CLEAR) then
			return false
		end
	end
	return true
end

-- Pure: the spots, in a stable order, at most MAX (thinned evenly when there are more).
function StreetTrees.spots(): { Vector3 }
	local found: { Vector3 } = {}
	local filleted = RoadPaths.townRoads()
	for index, road in TownLayout.ROADS do
		local offset = StreetTrees.vergeOffset(road)
		if not offset then
			continue
		end
		for _, side in { 1, -1 } do
			local line = PedestrianMath.offsetPolyline(filleted[index].points, road.width, side, offset)
			local cumulative = PedestrianMath.cumulativeLengths(line)
			local nextAt = StreetTrees.SPACING / 2
			for i = 1, #line - 1 do
				local a, b = line[i], line[i + 1]
				local from, to = cumulative[i], cumulative[i + 1]
				while nextAt <= to do
					local t = if to > from then (nextAt - from) / (to - from) else 0
					local p = flat(a:Lerp(b, t))
					if StreetTrees.clear(p, road) then
						table.insert(found, p)
					end
					nextAt += StreetTrees.SPACING
				end
			end
		end
	end
	if #found <= StreetTrees.MAX then
		return found
	end
	local out: { Vector3 } = {}
	for k = 1, StreetTrees.MAX do
		table.insert(out, found[math.floor((k - 1) * #found / StreetTrees.MAX) + 1])
	end
	return out
end

local function occupied(p: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return #workspace:GetPartBoundsInBox(CFrame.new(p.X, 7, p.Z), Vector3.new(3, 12, 3), params) > 0
end

function StreetTrees.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "street trees: no town"
	end
	local old = town:FindFirstChild("StreetTrees")
	if old then
		old:Destroy()
	end
	if not TreeKit.available() then
		return "street trees: no oak pack"
	end
	local root = Instance.new("Folder")
	root.Name = "StreetTrees"
	root:SetAttribute("Decor", true)
	root.Parent = town
	local rng = Random.new(SEED)
	local trees, taken, parts = 0, 0, 0
	for _, p in StreetTrees.spots() do
		if occupied(p, { root }) then
			taken += 1
			continue
		end
		local oak = TreeKit.tree(root, p, { height = rng:NextNumber(StreetTrees.HEIGHT[1], StreetTrees.HEIGHT[2]), slim = true, rng = rng, name = "StreetTree" })
		if oak then
			trees += 1
			for _, d in oak:GetDescendants() do
				if d:IsA("MeshPart") then
					parts += 1
				end
			end
		end
	end
	return ("street trees: %d on the verges, %d spots taken, %d MeshParts"):format(trees, taken, parts)
end

return StreetTrees
