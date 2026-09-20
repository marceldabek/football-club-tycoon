--!strict
-- Rivermere v3, Lane R: builds the town's roads from the UKSP ModularRoads kit.
-- All geometry decisions live in the pure module Shared/RoadTiles; this file only
-- turns its tile list into kit models via KitPlacer. See docs/TOWN_V3_BUILD.md s6.
--
-- Primitives: only the roundabout stand-ins (register row E3), tagged V3Exempt.
-- Kerbs and pavements are part of every kit road piece, so E4 is not used here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local KitPlacer = require(script.Parent.KitPlacer)

local RoadTiler = {}

-- TEMP from TOWN_V3_BUILD.md s9. NOTE the s9 figure assumed one MeshPart per tile;
-- kit road pieces are 3 MeshParts each (4 with yellow lines), so the honest unit
-- is TILES. See the Lane R handoff for the MeshPart count.
RoadTiler.PART_BUDGET = 1200

local LOOKS: { [string]: { color: Color3, material: Enum.Material } } = {
	asphalt = { color = Color3.fromRGB(62, 63, 66), material = Enum.Material.Asphalt },
	island = { color = Color3.fromRGB(86, 122, 68), material = Enum.Material.Grass },
	paint = { color = Color3.fromRGB(235, 235, 230), material = Enum.Material.SmoothPlastic },
}

-- Stretches a placed straight along its own length. KitPlacer only scales
-- uniformly; remainder fitting needs the last few percent along one axis.
local function stretchZ(model: Model, factor: number)
	if math.abs(factor - 1) < 1e-3 then
		return
	end
	local boxCFrame = model:GetBoundingBox()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = boxCFrame:ToObjectSpace(d.CFrame)
			d.Size = Vector3.new(d.Size.X, d.Size.Y, d.Size.Z * factor)
			d.CFrame = boxCFrame * (CFrame.new(rel.X, rel.Y, rel.Z * factor) * rel.Rotation)
		end
	end
end

local function districtModel(parent: Instance, cache: { [string]: Model }, district: string): Model
	local model = cache[district]
	if not model then
		model = Instance.new("Model")
		model.Name = "Roads_" .. district
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("District", district)
		model.Parent = parent
		cache[district] = model
	end
	return model
end

local function nearestDistrict(tiles: { RoadTiles.Tile }, pos: Vector3): string
	local best, bestDist = RoadTiles.ARTERIAL, math.huge
	for _, t in tiles do
		local d = (t.cframe.Position - pos).Magnitude
		if d < bestDist then
			best, bestDist = t.district, d
		end
	end
	return best
end

function RoadTiler.build(parent: Instance, origin: CFrame, filter: { district: string? }?): { [string]: number }
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any)
	local want = filter and filter.district
	local models: { [string]: Model } = {}
	local counts: { [string]: number } = { tiles = 0, meshParts = 0, missing = 0, exempt = 0, models = 0 }

	for _, tile in plan.tiles do
		if want and tile.district ~= want then
			continue
		end
		local holder = districtModel(parent, models, tile.district)
		local bottom = origin * tile.cframe * CFrame.new(0, -RoadTiles.heightOf(tile.piece) * tile.scale, 0)
		local model = KitPlacer.place(tile.piece, bottom, holder, { scale = tile.scale })
		if model:GetAttribute("KitMissing") then
			counts.missing += 1
		else
			stretchZ(model, tile.stretch)
		end
		model:SetAttribute("Road", tile.road)
		model:SetAttribute("TileKind", tile.kind)
		counts.tiles += 1
		counts[tile.kind] = (counts[tile.kind] or 0) + 1
	end

	for _, ex in plan.exempt do
		local district = nearestDistrict(plan.tiles, ex.centre)
		if want and district ~= want then
			continue
		end
		local look = LOOKS[ex.look] or LOOKS.asphalt
		local part = Instance.new("Part")
		part.Name = "Roundabout_" .. ex.look
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.Size = Vector3.new(ex.height, ex.radius * 2, ex.radius * 2)
		part.CFrame = origin * CFrame.new(ex.centre) * CFrame.Angles(0, 0, math.pi / 2)
		part.Color = look.color
		part.Material = look.material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part:SetAttribute("V3Exempt", ex.id)
		part.Parent = districtModel(parent, models, district)
		counts.exempt += 1
	end

	for _, model in models do
		counts.models += 1
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") then
				counts.meshParts += 1
			end
		end
	end
	counts.downgraded = plan.stats.downgraded
	counts.unresolved = plan.stats.unresolved

	print(("[FCT] Roads: %d tiles (%d MeshParts, budget %d) in %d district models; %d straight, %d bends, %d T, %d cross, %d heads; %d roundabout stand-ins (E3); %d tucked junctions; %d KitMissing%s"):format(
		counts.tiles, counts.meshParts, RoadTiler.PART_BUDGET, counts.models,
		counts.straight or 0, (counts.bend90 or 0) + (counts.bend45 or 0), counts.tee or 0, counts.cross or 0, counts.head or 0,
		counts.exempt, counts.downgraded, counts.missing,
		if want then " [district " .. want .. "]" else ""
	))
	return counts
end

return RoadTiler
