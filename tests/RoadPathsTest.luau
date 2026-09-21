--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoadPaths = require(ReplicatedStorage.Shared.RoadPaths)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TrafficMath = require(ReplicatedStorage.Shared.TrafficMath)

local T = {}

local EPS = 1e-3

local function flatDist(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The kit's 90 bend is an arc of radius R: a path that keeps the sharp corner is
-- 0.41 R inside the asphalt there. The filleted path is on the arc.
function T.ninetyCornerBecomesTheKitArc()
	local R = 20
	local corner = Vector3.new(100, 0, 0)
	local out = RoadPaths.fillet({ Vector3.new(0, 0, 0), corner, Vector3.new(100, 0, 100) }, R, 35)
	assert(out[1] == Vector3.new(0, 0, 0) and out[#out] == Vector3.new(100, 0, 100), "ends do not move")
	local centre = Vector3.new(100 - R, 0, R)
	local closest = math.huge
	for i = 2, #out - 1 do
		assert(math.abs(flatDist(out[i], centre) - R) < EPS, "every new point is on the arc")
		closest = math.min(closest, flatDist(out[i], corner))
	end
	assert(math.abs(closest - R * (math.sqrt(2) - 1)) < 0.05, "the path passes 0.41 R from the old corner")
	assert(flatDist(out[2], Vector3.new(100 - R, 0, 0)) < EPS, "arc starts a radius before the corner")
	assert(flatDist(out[#out - 1], Vector3.new(100, 0, R)) < EPS, "and ends a radius after it")
end

function T.fortyFiveCornerUsesTheOtherRadius()
	local S = math.sqrt(0.5)
	local corner = Vector3.new(100, 0, 0)
	local out = RoadPaths.fillet({ Vector3.new(0, 0, 0), corner, corner + Vector3.new(S, 0, -S) * 100 }, 20, 35)
	local tangent = 35 * math.tan(math.rad(22.5))
	assert(flatDist(out[2], Vector3.new(100 - tangent, 0, 0)) < EPS, "tangent length from the 45 radius")
	-- turning towards -Z: the arc's centre is on that side
	local centre = Vector3.new(100 - tangent, 0, -35)
	for i = 2, #out - 1 do
		assert(math.abs(flatDist(out[i], centre) - 35) < EPS, "on the 45 arc")
	end
end

function T.shortSegmentsShrinkTheArcInsteadOfOverlapping()
	-- two 90 corners 20 apart: each arc may use 0.45 of the 20 between them
	local out = RoadPaths.fillet({ Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 20), Vector3.new(200, 0, 20) }, 30, 35)
	local length = TrafficMath.polylineLength(out)
	assert(length < 220 and length > 200, "rounded, so a little shorter than the zig-zag")
	local _, dirBefore = TrafficMath.pointAt(out, 0)
	for d = 1, math.floor(length) do
		local _, dir = TrafficMath.pointAt(out, d)
		assert(dir:Dot(dirBefore) > 0.85, "no reversal or sharp kink along the path")
		dirBefore = dir
	end
end

function T.straightAndGentleRoadsAreUntouched()
	local straight = { Vector3.new(0, 0, 0), Vector3.new(50, 0, 0), Vector3.new(100, 0, 0) }
	assert(#RoadPaths.fillet(straight, 20, 35) == 3, "collinear point kept as it is")
	local gentle = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(200, 0, 8) }
	assert(#RoadPaths.fillet(gentle, 20, 35) == 3, "under 10 degrees is left alone")
end

function T.closedRoadStaysClosedWithItsSeamRounded()
	local square = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100), Vector3.new(0, 0, 100), Vector3.new(0, 0, 0) }
	local out = RoadPaths.fillet(square, 20, 35)
	assert(TrafficMath.isClosed(out, EPS), "still closed")
	for _, p in out do
		assert(flatDist(p, Vector3.new(0, 0, 0)) > 5, "the seam corner is rounded like the others")
	end
end

function T.townRoadsKeepTheLayoutsIndicesAndEnds()
	local roads = RoadPaths.townRoads()
	assert(#roads == #TownLayout.ROADS, "one path per road")
	local rounded = 0
	for i, road in TownLayout.ROADS do
		local path = roads[i]
		assert(path.name == road.name and path.kind == road.kind and path.width == road.width, "same road")
		if not TrafficMath.isClosed(road.points, EPS) then
			assert(flatDist(path.points[1], road.points[1]) < EPS and flatDist(path.points[#path.points], road.points[#road.points]) < EPS, road.name .. " ends moved")
		end
		if #path.points > #road.points then
			rounded += 1
		end
		-- never further from the layout line than a 90 corner's 0.41 R
		local limit = RoadTiles.KIT_BEND90_RADIUS * RoadTiles.STREET_SCALE * 0.42
		for _, p in path.points do
			assert(TownLayout.distanceToPolyline(p, road.points) <= limit, road.name .. " path strays from its road")
		end
	end
	assert(rounded > 0, "the town has bends")
end

return T
