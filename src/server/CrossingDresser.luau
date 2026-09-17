--!strict
-- Tactile paving at side-road crossings (backlog X102, RiveremereWestdale.png:
-- buff blister slabs at the dropped kerbs where the pavement crosses a side
-- road). Runs after the street dressers.
--
-- For every residential road, at each junction where it ends on a road that
-- has pavements (a T; crossroads are skipped), a pedestrian walking along the other road's pavement crosses this
-- road's mouth. A slab goes either side of that mouth: on the other road's
-- pavement, against this road's carriageway edge, CROSSING_DEPTH back from the
-- kerb and CROSSING_WIDTH along the walk. A spot is only used if a Pavement
-- part is really underneath (junction corners can be cut by blocks, bus stops
-- or roundabouts).
--
-- Heights: pavement top 0.45 (TownBuilder.Y.PAVEMENT); a slab tops out at 0.47
-- and sinks 0.08 into the pavement, under the verge (0.49) and tree pits (0.51).
-- Part budget: 1 per slab. Quality hides them on Low (name Tactile).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TerraceStreetDresser = require(script.Parent.TerraceStreetDresser)

local CrossingDresser = {}

CrossingDresser.CROSSING_DEPTH = 3 -- back from this road's kerb, across the walk
CrossingDresser.CROSSING_WIDTH = 5 -- along this road, inside the other road's pavement
CrossingDresser.TOP = 0.47
local THICK = 0.1
local BUFF = Color3.fromRGB(206, 172, 112)
local PAVEMENT_WIDTH = TownLayout.PAVEMENT_WIDTH

export type Slab = { cframe: CFrame, size: Vector3 }

-- Pure: slab frames for one road. Each CFrame is at the slab centre on the
-- ground (Y 0), looking along the road away from the junction.
function CrossingDresser.slabs(road: TownLayout.Road, roads: { TownLayout.Road }): { Slab }
	local out: { Slab } = {}
	for _, j in TerraceStreetDresser.junctions(road, roads) do
		-- only where this road ends on the other (a T): at a crossroads both
		-- roads would put slabs on the same corners
		if j.other.kind == "lane" or #j.dirs ~= 1 then
			continue -- a lane has no pavement to cross along
		end
		for _, d in j.dirs do
			local right = Vector3.new(-d.Z, 0, d.X)
			local mid = j.point + d * (j.other.width / 2 + PAVEMENT_WIDTH / 2)
			for _, side in { -1, 1 } do
				local c = mid + right * side * (road.width / 2 + CrossingDresser.CROSSING_DEPTH / 2)
				table.insert(out, {
					cframe = CFrame.lookAt(c, c + d),
					size = Vector3.new(CrossingDresser.CROSSING_DEPTH, THICK, CrossingDresser.CROSSING_WIDTH),
				})
			end
		end
	end
	return out
end

local function onPavement(p: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, hit in workspace:GetPartBoundsInBox(CFrame.new(p.X, 0.3, p.Z), Vector3.new(0.5, 0.2, 0.5), params) do
		if hit.Name == "Pavement" then
			return true
		end
	end
	return false
end

function CrossingDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "crossings: no town"
	end
	local old = town:FindFirstChild("Crossings")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Crossings"
	root.Parent = town
	local placed, skipped = 0, 0
	for _, road in TownLayout.ROADS do
		if road.kind ~= "residential" then
			continue
		end
		for _, slab in CrossingDresser.slabs(road, TownLayout.ROADS) do
			-- every corner of the slab must be on pavement
			local ok = true
			for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
				local p = slab.cframe * (Vector3.new(slab.size.X / 2 - 0.3, 0, slab.size.Z / 2 - 0.3) * corner)
				if not onPavement(p, { root }) then
					ok = false
					break
				end
			end
			if not ok then
				skipped += 1
				continue
			end
			local p = Instance.new("Part")
			p.Name = "Tactile"
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Size = slab.size
			p.CFrame = slab.cframe * CFrame.new(0, CrossingDresser.TOP - THICK / 2, 0)
			p.Color = BUFF
			p.Material = Enum.Material.Pavement
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = root
			placed += 1
		end
	end
	return ("crossings: %d tactile slabs (%d spots off the pavement)"):format(placed, skipped)
end

return CrossingDresser
