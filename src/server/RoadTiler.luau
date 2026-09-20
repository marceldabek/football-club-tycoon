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

-- MeshParts, whole town (TOWN_V3_BUILD.md s9, published by Lane P: a kit road
-- piece is 3 MeshParts, 4 with yellow lines).
RoadTiler.PART_BUDGET = 2600

local LOOKS: { [string]: { color: Color3, material: Enum.Material } } = {
	asphalt = { color = Color3.fromRGB(62, 63, 66), material = Enum.Material.Asphalt },
	island = { color = Color3.fromRGB(86, 122, 68), material = Enum.Material.Grass },
	paint = { color = Color3.fromRGB(235, 235, 230), material = Enum.Material.SmoothPlastic },
}

-- The kit's grass verge texture is a bright lime that reads as a green stripe
-- against the town's terrain grass (Lane I stage 1 playtest, problem 1). The verge
-- MeshPart's SurfaceAppearance is tinted toward the terrain colour instead.
-- Observed in Play (rendered verge colour, eyeballed from screenshots):
--   (240, 212, 235) -> lime (150, 190, 45)        stage 3, Elder Close
--   (255, 185, 200) -> mustard                    stage 2
--   (150, 158, 118) -> dark saturated green       stage 2
--   (160, 158, 255) -> dark bluish green (25, 80, 45)   stage 3, West Bridge approach
-- The tint does NOT act linearly on the rendered colour: those four fit
-- rendered = base * (tint / 255) ^ 2.4 per channel. The texture has almost no blue,
-- so blue stays at 255. Solving that for the terrain grass beside the road (rendered
-- about (100, 130, 60); Terrain grass material colour is (111, 126, 62)) gives the
-- value below. It is the model's answer from four observations and has NOT itself
-- been looked at (stage 3 used its last screenshot finding that 160/158 was too dark).
RoadTiler.VERGE_TINT = Color3.fromRGB(203, 181, 255)

-- Town Centre streets are fronted by shops, where a grass verge reads wrong. Inside
-- RoadTiles.CENTRE the verge mesh loses its grass SurfaceAppearance and is shown as
-- plain paving instead. This is a STAND-IN for a missing pavement / kerb asset
-- (register row E4): the mesh is still the kit's, only its surface is swapped.
-- Shop-fronted roads outside the centre box keep grass verges.
RoadTiler.PAVED_VERGE = { color = Color3.fromRGB(150, 148, 142), material = Enum.Material.Pavement }

function RoadTiler.isPavedVerge(position: Vector3): boolean
	local c = RoadTiles.CENTRE
	return position.X >= c.minX and position.X <= c.maxX and position.Z >= c.minZ and position.Z <= c.maxZ
end

-- The verge MeshPart of a placed kit road piece. SurfaceAppearance.ColorMap cannot
-- be read in a running server, so it is found by shape: the verge has the largest
-- footprint; where every layer is the same square (the crossroads) it is the part
-- named <piece>2. RoadTilerTest checks this against the grass texture for all 44.
function RoadTiler.vergeOf(model: Instance): MeshPart?
	local parts: { MeshPart } = {}
	local maxArea = 0
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
			maxArea = math.max(maxArea, d.Size.X * d.Size.Z)
		end
	end
	local tied: { MeshPart } = {}
	for _, p in parts do
		if p.Size.X * p.Size.Z >= maxArea * 0.99 then
			table.insert(tied, p)
		end
	end
	if #tied <= 1 then
		return tied[1]
	end
	local base = tied[1].Name
	for _, p in tied do
		if #p.Name < #base then
			base = p.Name
		end
	end
	for _, p in tied do
		if p.Name == base .. "2" then
			return p
		end
	end
	return nil
end

local function tintVerge(model: Instance, paved: boolean)
	local verge = RoadTiler.vergeOf(model)
	if not verge then
		return
	end
	local sa = verge:FindFirstChildOfClass("SurfaceAppearance")
	if paved then
		if sa then
			sa:Destroy()
		end
		verge.Color = RoadTiler.PAVED_VERGE.color
		verge.Material = RoadTiler.PAVED_VERGE.material
		verge:SetAttribute("V3Exempt", "E4")
		model:SetAttribute("PavedVerge", true)
	elseif sa then
		pcall(function()
			sa.Color = RoadTiler.VERGE_TINT
		end)
	end
end

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
		-- TOWN_V3_BUILD.md s9 rule 1: a district is a grouping model, never Atomic
		model.ModelStreamingMode = Enum.ModelStreamingMode.Default
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
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any, TownLayout.BRIDGES :: any)
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
			tintVerge(model, RoadTiler.isPavedVerge(tile.cframe.Position))
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
