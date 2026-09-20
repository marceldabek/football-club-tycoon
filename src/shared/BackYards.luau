--!strict
-- Rivermere v3: PURE geometry for the back yards of terraces that back onto a back
-- alley (TownLayout roads of kind "alley"). A unit gets a yard when an alley runs
-- parallel behind it: the yard reaches from the back of the lot to the alley's edge.
-- The assembler (HouseAssembler) walls it with kit pieces; nothing is built here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)

local BackYards = {}

export type RoadIn = { name: string, kind: string, points: { Vector3 } }
export type Piece = { piece: string, length: number, parts: number, trim: boolean? }

-- Kit pieces (sizes measured in Studio 2026-09-20).
BackYards.WALL = { id = "yard_wall", piece = "UKSP__GardenWall__Wall", length = 8.2, parts = 2 } -- brick, 4.6 high (ExteriorWall is an iron railing)
BackYards.WALL_MAX_STRETCH = 2 -- one wall piece spans a yard (about 15 studs) in every tier
BackYards.PARTY_FENCE = { id = "yard_party", piece = "MEH__Wood_Fence_A__ts1", length = 5.5, parts = 1, trim = true }
BackYards.GATE = { piece = "MEH__Wood_Gate_A__ts1", width = 2.4, trim = true }
BackYards.GATE_GAP = 2.8 -- the gate plus a little clearance either side
BackYards.WALL_SETBACK = 0.5 -- the wall's centreline stands this far off the alley's edge
BackYards.MIN_DEPTH = 2.5 -- a shallower strip is left as grass
BackYards.MAX_DEPTH = 14 -- further than this and the alley is not "behind" the house
BackYards.PARALLEL_TOLERANCE = 0.05 -- |front . alley direction| must be under this

-- Half the width of an alley road piece: the alley's edge from its centreline.
function BackYards.alleyHalfWidth(): number
	return RoadTiles.KIT_HALF_WIDTH * RoadTiles.ALLEY_SCALE
end

-- Depth of the yard behind `back` (a point on the back edge of a lot whose doors face
-- `front`), or nil when no alley runs parallel behind that point.
function BackYards.depthBehind(back: Vector3, front: Vector3, roads: { RoadIn }): number?
	local away = Vector3.new(-front.X, 0, -front.Z).Unit
	local best: number? = nil
	for _, road in roads do
		if road.kind ~= "alley" then
			continue
		end
		for i = 1, #road.points - 1 do
			local a, b = road.points[i], road.points[i + 1]
			local seg = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local len = seg.Magnitude
			if len < 1e-6 then
				continue
			end
			local dir = seg / len
			if math.abs(dir:Dot(away)) > BackYards.PARALLEL_TOLERANCE then
				continue
			end
			local rel = Vector3.new(back.X - a.X, 0, back.Z - a.Z)
			local along = rel:Dot(dir)
			if along < 0 or along > len then
				continue -- the alley does not run past this point
			end
			-- signed distance from the point to the alley's centreline, measured backwards
			local behind = -(rel - dir * along):Dot(away)
			local depth = behind - BackYards.alleyHalfWidth() - BackYards.WALL_SETBACK
			if depth >= BackYards.MIN_DEPTH and depth <= BackYards.MAX_DEPTH and (best == nil or depth < best) then
				best = depth
			end
		end
	end
	return best
end

return BackYards
