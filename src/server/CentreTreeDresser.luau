--!strict
-- Street trees on the town-centre main roads (backlog X110, RivermereCenter.png:
-- young trees in pits along the high street pavements). The terraced and
-- semis streets already have them (TerraceStreetDresser, EstateDresser); the
-- main roads through the centre had none. Runs last so it can step round what
-- the other dressers put on the pavements.
--
-- Spots come from TerraceStreetDresser.treeSpots (kerb side of both pavements,
-- clear of lamps, junction mouths and bus stops), kept within CENTRE_RADIUS of
-- the market square, then dropped at build time if anything already stands
-- in the tree's footprint (shelters, bollards, A-boards, café tables, signs).
-- Light trees: pit, trunk and one crown, 3 parts each, Decor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local StreetDresser = require(script.Parent.StreetDresser)
local TerraceStreetDresser = require(script.Parent.TerraceStreetDresser)

local CentreTreeDresser = {}

CentreTreeDresser.ROADS = { "High Street", "Riverside Road", "North Road", "Bridge Street" }
CentreTreeDresser.CENTRE_RADIUS = 420 -- TEMP
CentreTreeDresser.SPACING = 44

-- Pure: candidate spots on one road, within CENTRE_RADIUS of the square.
function CentreTreeDresser.spots(road: TownLayout.Road): { TerraceStreetDresser.Spot }
	local centre = TownLayout.SQUARE.centre
	local function outside(p: Vector3): boolean
		return (Vector3.new(p.X - centre.X, 0, p.Z - centre.Z)).Magnitude > CentreTreeDresser.CENTRE_RADIUS
	end
	return TerraceStreetDresser.treeSpots(road, CentreTreeDresser.SPACING, nil, StreetDresser.lampPositions(road), TownLayout.ROADS, outside)
end

local function occupied(p: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- from just above the pavement to the crown, a little wider than the pit
	return #workspace:GetPartBoundsInBox(CFrame.new(p.X, 7, p.Z), Vector3.new(3, 12, 3), params) > 0
end

function CentreTreeDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "centre trees: no town"
	end
	local old = town:FindFirstChild("CentreTrees")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "CentreTrees"
	root.Parent = town
	local rng = Random.new(4242)
	local planted, blocked = 0, 0
	for _, name in CentreTreeDresser.ROADS do
		for _, road in TownLayout.ROADS do
			if road.name ~= name then
				continue
			end
			for _, spot in CentreTreeDresser.spots(road) do
				if occupied(spot.position, { root }) then
					blocked += 1
					continue
				end
				TerraceStreetDresser.lightTree(root, spot.position, rng)
				planted += 1
			end
		end
	end
	return ("centre trees: %d planted, %d spots taken"):format(planted, blocked)
end

return CentreTreeDresser
