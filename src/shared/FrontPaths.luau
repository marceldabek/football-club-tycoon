--!strict
-- #31: footpaths from front doors to the pavement, from the layout data alone.
--
-- A TownFrontage lot's front garden starts where its street's own ground ends
-- (RoadTiles.corridorHalf: the road's nominal width plus its pavement). The paving
-- stops short of that: PavingStrips lays the walked streets' pavements out to
-- RoadTiles.pavementOuter, the other kinds keep only the kit's paving, and the kit
-- piece's grass verge fills the gap. So a path from the door has to cross the
-- garden AND that verge.
--
-- Paths stand a little proud of everything they cross: the kit verges sit at up to
-- 0.42 (a 45 degree bend's) and the plain pavement strips at 0.33, so a top of
-- 0.44 shows over both and ends as a hairline lip at the paving's edge.

local RoadTiles = require(script.Parent.RoadTiles)
local PedestrianMath = require(script.Parent.PedestrianMath)
local TownLayout = require(script.Parent.TownLayout)

local FrontPaths = {}

FrontPaths.TOP = 0.44 -- path top above the town ground
FrontPaths.THICKNESS = 0.3
FrontPaths.WIDTH = 2.2 -- a house's path (at kit scale; houses scale it with the unit)
FrontPaths.COLOR = Color3.fromRGB(176, 172, 164)
FrontPaths.MAX_VERGE = 12 -- never run a path further than this past the garden

-- Centreline to the outer edge of a road's paving. PavingStrips widens the walked streets'
-- pavements everywhere but the town centre (RoadTiles.CENTRE), so pass `at` to get the
-- kit's own narrower paving there.
function FrontPaths.pavingReach(road: TownLayout.Road, at: Vector3?): number
	local c = RoadTiles.CENTRE
	local inCentre = at ~= nil and at.X >= c.minX and at.X <= c.maxX and at.Z >= c.minZ and at.Z <= c.maxZ
	if PedestrianMath.isWalkableKind(road.kind) and not inCentre then
		return RoadTiles.pavementOuter(road.kind)
	end
	return RoadTiles.KIT_PAVING_OUTER * (RoadTiles.SCALE[road.kind] or RoadTiles.STREET_SCALE)
end

local byName: { [string]: TownLayout.Road }? = nil
local function roadNamed(name: string): TownLayout.Road?
	local map = byName
	if not map then
		map = {}
		for _, road in TownLayout.ROADS do
			map[road.name] = road
		end
		byName = map
	end
	return map[name]
end

-- A cul-de-sac's turning head (kit CulDeSac) is paved out to this radius from the road's last
-- point; the fan of lots round it starts its gardens at TownLayout.HEAD_RADIUS (34). Measured
-- top-down against debug dots, 2026-09-23 (the mesh's collision hull reads wider).
FrontPaths.HEAD_PAVING = 33.4

-- Pure: the grass verge between the front of a lot's garden and the paving of the
-- street it fronts. 0 when the street is unknown or has no pavement of its own (lanes,
-- alleys). `at` is the garden's front edge where the path leaves it (town coordinates) and
-- `dir` the lot's front: a lot in the town centre crosses a wider verge (no PavingStrips
-- there), and a lot round a close's turning head is measured to the head's paving. A lot
-- across a blunt end gets none: the road's end is paved up to its gardens.
function FrontPaths.verge(street: string, closesStreet: boolean, at: Vector3?, dir: Vector3?): number
	local road = roadNamed(street)
	if closesStreet then
		if not (road and road.head and at and dir) then
			return 0
		end
		local centre = road.points[#road.points]
		local flatDir = Vector3.new(dir.X, 0, dir.Z).Unit
		local t = 0
		while t < FrontPaths.MAX_VERGE do
			local p = at + flatDir * t
			if Vector3.new(p.X - centre.X, 0, p.Z - centre.Z).Magnitude <= FrontPaths.HEAD_PAVING then
				return t
			end
			t += 0.25
		end
		return 0
	end
	if not road then
		return 0
	end
	local corridor = RoadTiles.corridorHalf(road.kind, road.width)
	if not corridor then
		return 0
	end
	return math.clamp(corridor - FrontPaths.pavingReach(road, at), 0, FrontPaths.MAX_VERGE)
end

return FrontPaths
