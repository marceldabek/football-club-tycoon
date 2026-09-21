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

function T.busStopsProjectOntoTheirRoad()
	local road = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100) }
	local stops = { Vector3.new(40, 0, 18), Vector3.new(118, 0, 60), Vector3.new(50, 0, 80) }
	local ds = TrafficMath.stopDistances(road, stops, 20)
	assert(#ds == 2, "the far stop is ignored, got " .. #ds)
	assert(math.abs(ds[1] - 40) < 1e-4 and math.abs(ds[2] - 160) < 1e-4, "distances along the polyline, sorted")
	assert(#TrafficMath.stopDistances({ Vector3.zero }, stops, 20) == 0, "degenerate road")
end

function T.passedStopWorksBothWays()
	local stops = { 40, 160 }
	assert(TrafficMath.passedStop(30, 45, stops) == 40, "forward across a stop")
	assert(TrafficMath.passedStop(41, 60, stops) == nil, "forward, nothing crossed")
	assert(TrafficMath.passedStop(170, 150, stops) == 160, "backward across a stop")
	assert(TrafficMath.passedStop(30, 170, stops) == 40, "first reached wins going forward")
	assert(TrafficMath.passedStop(170, 30, stops) == 160, "first reached wins going backward")
end

function T.junctionBusyChecksFlatDistance()
	local j = Vector3.new(100, 0, 100)
	assert(TrafficMath.junctionBusy(j, { Vector3.new(110, 5, 105) }, 22), "a vehicle 11 away (height ignored) is in the junction")
	assert(not TrafficMath.junctionBusy(j, { Vector3.new(130, 0, 100) }, 22), "30 away is clear")
	assert(not TrafficMath.junctionBusy(j, {}, 22), "no vehicles")
end

-- A crossroads of two 400-stud roads on a roundabout at (100, 0, 100).
local function ringFixture()
	local roads = {
		{ points = { Vector3.new(100, 0, 300), Vector3.new(100, 0, -100) }, width = 26 }, -- south to north
		{ points = { Vector3.new(-100, 0, 100), Vector3.new(100, 0, 100) }, width = 26 }, -- from the west, ends at the centre
	}
	local centre = Vector3.new(100, 0, 100)
	local arms = TrafficMath.ringArms(roads, centre, 29, function()
		return 4
	end)
	return roads, centre, arms
end

function T.ringArmsAreWhereRoadsCrossTheRing()
	local _, _, arms = ringFixture()
	assert(#arms == 3, "a through road gives two arms, a road ending at the centre one; got " .. #arms)
	local south = TrafficMath.armReached(arms, 1, 150, 180, 1)
	assert(south and math.abs(south.distance - 171) < EPS and south.outward == -1, "south arm at 200 - 29, leaving is backwards along the road")
	assert(TrafficMath.armReached(arms, 1, 150, 180, -1) == nil, "only a car heading in reaches it")
	assert(TrafficMath.armReached(arms, 1, 100, 120, 1) == nil, "not there yet")
	-- inbound from the south (heading -Z) keeps left: west of the centreline
	local p = TrafficMath.ringPose(Vector3.new(100, 0, 100), 29, south.entryAngle)
	assert(p.X < 100 and p.Z > 100, "enters on the left of its road")
end

function T.ringIsDrivenTheUkWayRound()
	local _, _, arms = ringFixture()
	local south = TrafficMath.armReached(arms, 1, 150, 180, 1) :: TrafficMath.RingArm
	local west = TrafficMath.armReached(arms, 2, 150, 180, 1) :: TrafficMath.RingArm
	local north = TrafficMath.armReached(arms, 1, 250, 220, -1) :: TrafficMath.RingArm
	local left = TrafficMath.ringSweep(south, west)
	local straight = TrafficMath.ringSweep(south, north)
	local back = TrafficMath.ringSweep(south, south)
	assert(left > math.rad(60) and left < math.rad(90), "first exit on the left is under a quarter turn: " .. math.deg(left))
	assert(straight > math.rad(150) and straight < math.rad(180), "straight on is under a half turn: " .. math.deg(straight))
	assert(back > math.rad(330), "back the way it came is nearly a full lap")
	-- the island stays on the car's right
	local pos, tangent = TrafficMath.ringPose(Vector3.new(100, 0, 100), 29, south.entryAngle)
	local toCentre = Vector3.new(100, 0, 100) - pos
	local right = Vector3.new(-tangent.Z, 0, tangent.X)
	assert(right:Dot(toCentre) > 0, "island on the right")
end

-- The bug this replaced: a car's apparent speed round the island was up to 7x its
-- road speed. Driving the arc, equal steps of distance are equal steps of ground.
function T.ringSpeedIsSteady()
	local centre = Vector3.new(100, 0, 100)
	local last = TrafficMath.ringPose(centre, 29, 0)
	for k = 1, 40 do
		local p = TrafficMath.ringPose(centre, 29, (k * 2) / 29) -- 2 studs of arc per step
		local step = (p - last).Magnitude
		assert(step > 1.95 and step <= 2.0001, "2 studs of arc moved " .. step)
		last = p
	end
end

function T.ringHeadingSwingsInAndOut()
	local tangent, inbound, outbound = Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)
	assert((TrafficMath.ringHeading(tangent, inbound, outbound, 0, 40, 8) - inbound).Magnitude < EPS, "arrives on its road's heading")
	assert((TrafficMath.ringHeading(tangent, inbound, outbound, 20, 40, 8) - tangent).Magnitude < EPS, "tangent in the middle")
	assert((TrafficMath.ringHeading(tangent, inbound, outbound, 40, 40, 8) - outbound).Magnitude < EPS, "leaves on the exit's heading")
	assert(math.abs(TrafficMath.ringHeading(tangent, inbound, outbound, 3, 40, 8).Magnitude - 1) < EPS, "unit")
end

function T.easeNearSlowsForARoundabout()
	assert(TrafficMath.easeNear(40, 16, 80, 50) == 40, "far away: free speed")
	assert(math.abs(TrafficMath.easeNear(40, 16, 0, 50) - 16) < EPS, "at the arm: ring speed")
	local mid = TrafficMath.easeNear(40, 16, 25, 50)
	assert(mid > 16 and mid < 40, "eased between")
	assert(TrafficMath.easeNear(14, 16, 0, 50) == 14, "a slow lane is not sped up")
end

-- Cars circulate on RoadTiles.ringRadius; their inner side must clear the island
-- RoadTiles builds (at a 0.35 ring share against a 0.45 island they drove through its edge).
function T.carsClearTheIslandRoadTilesBuilds()
	local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
	for _, radius in { 40, 16 } do
		local carHalfWidth = 9.8 * RoadTiles.CAR_SCALE / 2
		assert(RoadTiles.ringRadius(radius) - carHalfWidth > RoadTiles.islandRadius(radius), "car's inner side is outside the island")
		assert(RoadTiles.ringRadius(radius) + carHalfWidth < radius, "and its outer side inside the rim")
	end
end

function T.vehiclesFitTheirLane()
	local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
	local lane = RoadTiles.carriagewayWidth("residential") / 2
	assert(9.8 * RoadTiles.CAR_SCALE < lane, "car narrower than a lane")
	assert(8.3 * RoadTiles.BUS_SCALE < lane, "bus narrower than a lane")
end

function T.followGapCountsBothLengths()
	-- a car (half 5.8) behind a bus (half 10.1) with 8 clear: 23.9 between centres
	assert(math.abs(TrafficMath.followGap(10.1, 5.8, 8) - 23.9) < EPS, "gap is both halves plus daylight")
end

function T.followSpeedEasesDownToTheLeader()
	assert(TrafficMath.followSpeed(20, 10, 100, 20) == 20, "free beyond twice the gap")
	assert(math.abs(TrafficMath.followSpeed(20, 10, 30, 20) - 15) < EPS, "half way in: half way to the leader's speed")
	assert(math.abs(TrafficMath.followSpeed(20, 10, 20, 20) - 10) < EPS, "at the gap: the leader's speed")
	assert(math.abs(TrafficMath.followSpeed(20, 10, 10, 20) - 5) < EPS, "inside the gap: slower, so it opens")
	assert(TrafficMath.followSpeed(20, 10, 0, 20) == 0, "touching: stopped")
	assert(TrafficMath.followSpeed(8, 10, 20, 20) == 8, "never above its own free speed")
end

function T.weightedIndexFollowsTheWeights()
	local cumulative = { 10, 10, 110 } -- weights 10, 0, 100
	assert(TrafficMath.weightedIndex(cumulative, 0) == 1, "start")
	assert(TrafficMath.weightedIndex(cumulative, 0.05) == 1, "inside the first")
	assert(TrafficMath.weightedIndex(cumulative, 0.5) == 3, "the long one takes the rest")
	assert(TrafficMath.weightedIndex(cumulative, 0.999) == 3, "end")
	assert(TrafficMath.weightedIndex({}, 0.5) == nil, "empty")
end

function T.crowdedSeesANearbyVehicle()
	local taken = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
	assert(TrafficMath.crowded(Vector3.new(30, 5, 0), taken, 40), "30 away is inside 40")
	assert(not TrafficMath.crowded(Vector3.new(50, 0, 0), taken, 40), "50 from both")
end

return T
