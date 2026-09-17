--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrafficMath = require(ReplicatedStorage.Shared.TrafficMath)

local T = {}

local EPS = 1e-3

-- ----------------------------------------------------------------- length

function T.polylineLengthStraightLine()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
	assert(math.abs(TrafficMath.polylineLength(points) - 100) < EPS, "straight line length")
end

function T.polylineLengthMultiSegment()
	-- 3-4-5 triangle legs, two segments
	local points = { Vector3.new(0, 0, 0), Vector3.new(3, 0, 0), Vector3.new(3, 0, 4) }
	assert(math.abs(TrafficMath.polylineLength(points) - 7) < EPS, "multi-segment length")
end

function T.polylineLengthSinglePoint()
	assert(TrafficMath.polylineLength({ Vector3.new(0, 0, 0) }) == 0, "single point has zero length")
end

-- ----------------------------------------------------------------- isClosed

function T.isClosedTrueForARing()
	local ring = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10), Vector3.new(0, 0, 0) }
	assert(TrafficMath.isClosed(ring, EPS), "ring should be closed")
end

function T.isClosedFalseForAnOpenRoad()
	local road = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) }
	assert(not TrafficMath.isClosed(road, EPS), "open road should not be closed")
end

function T.isClosedFalseForASinglePoint()
	assert(not TrafficMath.isClosed({ Vector3.new(0, 0, 0) }, EPS), "single point is not closed")
end

-- ----------------------------------------------------------------- pointAt

function T.pointAtStartMiddleEnd()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
	local p0, d0 = TrafficMath.pointAt(points, 0)
	assert((p0 - Vector3.new(0, 0, 0)).Magnitude < EPS, "start position")
	assert((d0 - Vector3.new(1, 0, 0)).Magnitude < EPS, "start direction follows the first segment")

	local p50, d50 = TrafficMath.pointAt(points, 50)
	assert((p50 - Vector3.new(50, 0, 0)).Magnitude < EPS, "midpoint position")
	assert((d50 - Vector3.new(1, 0, 0)).Magnitude < EPS, "midpoint direction follows the segment")

	local p100 = TrafficMath.pointAt(points, 100)
	assert((p100 - Vector3.new(100, 0, 0)).Magnitude < EPS, "end position")
end

function T.pointAtClampsBeyondTheEndsOfAnOpenRoad()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
	local pNeg = TrafficMath.pointAt(points, -50)
	assert((pNeg - Vector3.new(0, 0, 0)).Magnitude < EPS, "clamps before the start")
	local pOver = TrafficMath.pointAt(points, 500)
	assert((pOver - Vector3.new(100, 0, 0)).Magnitude < EPS, "clamps past the end")
end

function T.pointAtFollowsABend()
	local points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) }
	local p, d = TrafficMath.pointAt(points, 15)
	assert((p - Vector3.new(10, 0, 5)).Magnitude < EPS, "position after the bend")
	assert((d - Vector3.new(0, 0, 1)).Magnitude < EPS, "direction after the bend")
end

function T.pointAtWrapsOnAClosedRing()
	local ring = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10), Vector3.new(0, 0, 0) }
	local total = TrafficMath.polylineLength(ring)
	local pWrap = TrafficMath.pointAt(ring, total + 5)
	local pDirect = TrafficMath.pointAt(ring, 5)
	assert((pWrap - pDirect).Magnitude < EPS, "distance past the seam wraps to the start")

	local pNegWrap = TrafficMath.pointAt(ring, -5)
	local pFromEnd = TrafficMath.pointAt(ring, total - 5)
	assert((pNegWrap - pFromEnd).Magnitude < EPS, "negative distance wraps backward from the seam")
end

function T.pointAtEmptyPolylineDoesNotError()
	local p, d = TrafficMath.pointAt({}, 10)
	assert(p == Vector3.zero, "empty polyline returns the origin")
	assert(d.Magnitude > 0, "empty polyline still returns a usable direction")
end

-- ----------------------------------------------------------------- laneOffset

function T.laneOffsetIsPerpendicularAndScaledByWidth()
	local direction = Vector3.new(1, 0, 0)
	local offset = TrafficMath.laneOffset(direction, 20, -1)
	assert(math.abs(offset:Dot(direction)) < EPS, "lane offset is perpendicular to travel")
	assert(math.abs(offset.Magnitude - 5) < EPS, "lane offset magnitude is width/4")
end

function T.laneOffsetFlipsWithDirection()
	local direction = Vector3.new(1, 0, 0)
	local forward = TrafficMath.laneOffset(direction, 20, -1)
	local backward = TrafficMath.laneOffset(-direction, 20, -1)
	-- Opposite-direction traffic keeps its own left, which puts it on the
	-- opposite physical side of the centreline -- the two lanes of a
	-- two-way road never land on the same side.
	assert((forward + backward).Magnitude < EPS, "opposite travel directions use opposite sides")
end

function T.laneOffsetSideFlipsTheSameWay()
	local direction = Vector3.new(0, 0, -1)
	local left = TrafficMath.laneOffset(direction, 20, -1)
	local right = TrafficMath.laneOffset(direction, 20, 1)
	assert((left + right).Magnitude < EPS, "left and right sides are opposite")
end

-- ----------------------------------------------------------------- connections

function T.connectionsSharedEndpointForward()
	-- A plot lane starting exactly on a main road's start point.
	local roads = {
		{ points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, width = 20 }, -- main
		{ points = { Vector3.new(0, 0, 0), Vector3.new(0, 0, -50) }, width = 10 }, -- lane, joins main's start
	}
	local conns = TrafficMath.connections(roads, 2, false, 5)
	assert(#conns == 1, "expected exactly one connection, got " .. #conns)
	assert(conns[1].roadIndex == 1, "connects to the main road")
	assert(conns[1].distance == 0, "joins at the start of the main road")
	assert(conns[1].direction == 1, "continues forward along the main road")
end

function T.connectionsSharedEndpointBackward()
	local roads = {
		{ points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, width = 20 }, -- main
		{ points = { Vector3.new(100, 0, 0), Vector3.new(100, 0, 50) }, width = 10 }, -- lane, joins main's end
	}
	local conns = TrafficMath.connections(roads, 2, false, 5)
	assert(#conns == 1, "expected exactly one connection, got " .. #conns)
	assert(conns[1].roadIndex == 1, "connects to the main road")
	assert(math.abs(conns[1].distance - 100) < EPS, "joins at the end of the main road")
	assert(conns[1].direction == -1, "continues backward along the main road")
end

function T.connectionsMidRoadJunctionReturnsBothDirections()
	-- A lane starting in the middle of a main road (a T-junction), well away
	-- from either of the main road's own ends.
	local roads = {
		{ points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, width = 20 }, -- main
		{ points = { Vector3.new(50, 0, 0), Vector3.new(50, 0, -50) }, width = 10 }, -- lane
	}
	local conns = TrafficMath.connections(roads, 2, false, 5)
	assert(#conns == 2, "expected both directions of the mid-road join, got " .. #conns)
	for _, c in conns do
		assert(c.roadIndex == 1, "joins the main road")
		assert(math.abs(c.distance - 50) < EPS, "joins at the nearest point (halfway along the main road)")
	end
	local dirs = { conns[1].direction, conns[2].direction }
	table.sort(dirs)
	assert(dirs[1] == -1 and dirs[2] == 1, "both directions are offered")
end

function T.connectionsNoneWithinToleranceGivesEmptyList()
	local roads = {
		{ points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, width = 20 },
		{ points = { Vector3.new(1000, 0, 1000), Vector3.new(1000, 0, 1050) }, width = 10 },
	}
	local conns = TrafficMath.connections(roads, 2, false, 5)
	assert(#conns == 0, "far-away roads should not connect")
end

function T.connectionsExcludesTheRoadItself()
	local roads = {
		{ points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, width = 20 },
	}
	local conns = TrafficMath.connections(roads, 1, true, 1000)
	assert(#conns == 0, "a road never connects to itself")
end

function T.connectionsAtEndUsesTheLastPoint()
	local roads = {
		{ points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, width = 20 }, -- main
		{ points = { Vector3.new(100, 0, 0), Vector3.new(100, 0, 50) }, width = 10 }, -- lane, at main's end
	}
	-- Querying road 1's end (atEnd = true) should find the lane; querying its
	-- start (atEnd = false) should not.
	local atEnd = TrafficMath.connections(roads, 1, true, 5)
	local atStart = TrafficMath.connections(roads, 1, false, 5)
	assert(#atEnd == 1, "main road's end is near the lane")
	assert(#atStart == 0, "main road's start is not near the lane")
end

function T.kerbOffsetRidesOnTheDrivingSideNearTheKerb()
	local dir = Vector3.new(0, 0, -1)
	local lane = TrafficMath.laneOffset(dir, 20, -1)
	local kerb = TrafficMath.kerbOffset(dir, 20, 2.2)
	assert(kerb:Dot(lane) > 0, "same side as the driving lane")
	assert(math.abs(kerb.Magnitude - 7.8) < 1e-6, "width / 2 - inset from the centre line")
	assert(kerb.Magnitude > lane.Magnitude, "closer to the kerb than the cars")
	assert(TrafficMath.kerbOffset(dir, 3, 2.2).Magnitude == 0, "never past the centre line")
end

return T
