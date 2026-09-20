--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PedestrianMath = require(ReplicatedStorage.Shared.PedestrianMath)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)

local T = {}

local EPS = 1e-3
local PAVE = TownLayout.PAVEMENT_WIDTH

local function near(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < EPS
end

-- ----------------------------------------------------------------- kinds

function T.walkableKindsAreMainAndResidentialOnly()
	assert(PedestrianMath.isWalkableKind("main"), "main roads have walkers")
	assert(PedestrianMath.isWalkableKind("residential"), "residential roads have walkers")
	assert(not PedestrianMath.isWalkableKind("ring"), "ring road has no walkers")
	assert(not PedestrianMath.isWalkableKind("lane"), "lanes have no pavements")
end

function T.walkableRoadIndicesFiltersByKind()
	local roads: { TownLayout.Road } = {
		{ name = "Ring", kind = "ring", width = 32, points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) } },
		{ name = "Main", kind = "main", width = 20, points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) } },
		{ name = "Lane", kind = "lane", width = 10, points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) } },
		{ name = "Res", kind = "residential", width = 16, points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) } },
	}
	local idx = PedestrianMath.walkableRoadIndices(roads)
	assert(#idx == 2 and idx[1] == 2 and idx[2] == 4, "expected indices 2 and 4")
end

function T.theRealTownHasWalkableRoads()
	assert(#PedestrianMath.walkableRoadIndices(TownLayout.ROADS) > 0, "TownLayout should have main/residential roads")
end

-- ----------------------------------------------------------------- pavementOffset

function T.pavementOffsetLandsMidPavement()
	local direction = Vector3.new(1, 0, 0)
	local offset = PedestrianMath.pavementOffset(direction, 20, 1)
	assert(math.abs(offset:Dot(direction)) < EPS, "offset is perpendicular to the road")
	assert(math.abs(offset.Magnitude - (10 + PAVE / 2)) < EPS, "offset is half the carriageway plus half a pavement")
end

-- v3: the kit road's paved strip is narrow and close to the kerb; the rest of the
-- corridor is grass verge, so walkers must not use the v2 width-based distance.
function T.kitPavementLineStaysOnThePavedStrip()
	for _, kind in { "main", "residential" } do
		local scale = RoadTiles.SCALE[kind]
		local d = PedestrianMath.kitPavementDistance(kind)
		local j = PedestrianMath.kitPavementJitter(kind)
		assert(j >= 0, "jitter is not negative")
		assert(d - j - 1 >= 8.6 * scale - EPS, kind .. ": walker clears the kerb")
		assert(d + j + 1 <= 12.26 * scale + EPS, kind .. ": walker stays off the verge")
	end
	local line = PedestrianMath.offsetPolyline({ Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, 20, 1, 8)
	assert(math.abs(math.abs(line[1].Z) - 8) < EPS, "offsetPolyline honours an explicit distance")
end

function T.pavementOffsetSidesAreOpposite()
	local direction = Vector3.new(0.6, 0, 0.8)
	local a = PedestrianMath.pavementOffset(direction, 26, 1)
	local b = PedestrianMath.pavementOffset(direction, 26, -1)
	assert(near(a + b, Vector3.zero), "the two pavements mirror each other")
end

function T.pavementOffsetIsClearOfTheCarriageway()
	local offset = PedestrianMath.pavementOffset(Vector3.new(0, 0, -1), 16, -1)
	local lateral = offset.Magnitude
	-- whole walker (+-2 studs jitter) stays between the kerb and the back of the pavement
	assert(lateral - 2 > 8 and lateral + 2 < 8 + PAVE, "walker line stays on the pavement")
end

-- ----------------------------------------------------------------- offsetPolyline

function T.offsetPolylineStraightRoad()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
	local line = PedestrianMath.offsetPolyline(points, 20, 1)
	local d = 10 + PAVE / 2
	assert(#line == 2, "one point per road point")
	assert(near(line[1], Vector3.new(0, 0, d)), "start offset")
	assert(near(line[2], Vector3.new(100, 0, d)), "end offset")
end

function T.offsetPolylineMitresARightAngle()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100) }
	local line = PedestrianMath.offsetPolyline(points, 20, 1)
	local d = 10 + PAVE / 2
	assert(near(line[1], Vector3.new(0, 0, d)), "first leg offset")
	assert(near(line[2], Vector3.new(100 - d, 0, d)), "corner point is the mitre, not a jump")
	assert(near(line[3], Vector3.new(100 - d, 0, 100)), "second leg offset")
	-- every point stays exactly d from the centreline
	for i, p in line do
		local dist = TownLayout.distanceToPolyline(p, points)
		assert(math.abs(dist - d) < EPS, "point " .. i .. " is on the pavement line")
	end
end

function T.offsetPolylineSharpBendIsLimited()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(0, 0, 5) }
	local line = PedestrianMath.offsetPolyline(points, 20, -1)
	local d = 10 + PAVE / 2
	local push = (line[2] - points[2]).Magnitude
	assert(push <= d / PedestrianMath.MITER_MIN_COS + EPS, "mitre is capped on a hairpin")
end

function T.offsetPolylineSkipsZeroLengthSegments()
	local points = { Vector3.new(0, 0, 0), Vector3.new(50, 0, 0), Vector3.new(50, 0, 0), Vector3.new(100, 0, 0) }
	local line = PedestrianMath.offsetPolyline(points, 20, 1)
	local d = 10 + PAVE / 2
	for i, p in line do
		assert(math.abs(p.Z - d) < EPS, "point " .. i .. " stays on the straight pavement")
	end
end

function T.offsetPolylineClosedRingMitresTheSeam()
	local ring = {
		Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100), Vector3.new(0, 0, 100), Vector3.new(0, 0, 0),
	}
	local line = PedestrianMath.offsetPolyline(ring, 20, 1)
	assert(near(line[1], line[5]), "seam points coincide")
	local d = 10 + PAVE / 2
	assert(near(line[1], Vector3.new(d, 0, d)), "seam corner is mitred like any other corner")
end

function T.cumulativeLengths()
	local cum = PedestrianMath.cumulativeLengths({ Vector3.new(0, 0, 0), Vector3.new(3, 0, 0), Vector3.new(3, 0, 4) })
	assert(cum[1] == 0 and math.abs(cum[2] - 3) < EPS and math.abs(cum[3] - 7) < EPS, "running totals")
end

-- ----------------------------------------------------------------- advance

function T.advanceMovesForwardAndBack()
	local d, dir = PedestrianMath.advance(10, 1, 5, 100, false)
	assert(math.abs(d - 15) < EPS and dir == 1, "forward")
	d, dir = PedestrianMath.advance(10, -1, 5, 100, false)
	assert(math.abs(d - 5) < EPS and dir == -1, "backward")
end

function T.advanceTurnsRoundAtTheEnds()
	local d, dir = PedestrianMath.advance(98, 1, 5, 100, false)
	assert(math.abs(d - 97) < EPS and dir == -1, "bounces off the far end")
	d, dir = PedestrianMath.advance(2, -1, 5, 100, false)
	assert(math.abs(d - 3) < EPS and dir == 1, "bounces off the start")
end

function T.advanceHugeStepStaysInRange()
	local d = PedestrianMath.advance(50, 1, 1000, 10, false)
	assert(d >= 0 and d <= 10, "clamped inside the line")
end

function T.advanceWrapsOnAClosedLine()
	local d, dir = PedestrianMath.advance(98, 1, 5, 100, true)
	assert(math.abs(d - 3) < EPS and dir == 1, "wraps forward")
	d = PedestrianMath.advance(2, -1, 5, 100, true)
	assert(math.abs(d - 97) < EPS, "wraps backward")
end

function T.advanceZeroLengthDoesNotError()
	local d = PedestrianMath.advance(5, 1, 5, 0, false)
	assert(d == 0, "zero-length line pins to 0")
end

-- ----------------------------------------------------------------- walkCycle

function T.walkCycleStandingStillIsStill()
	local bob, swing = PedestrianMath.walkCycle(3.2, 0)
	assert(bob == 0 and swing == 0, "no motion at zero speed")
end

function T.walkCycleStaysInBounds()
	for i = 0, 200 do
		local bob, swing = PedestrianMath.walkCycle(i * 0.037, 6)
		assert(bob >= 0 and bob <= PedestrianMath.BOB_HEIGHT + EPS, "bob in range")
		assert(math.abs(swing) <= PedestrianMath.MAX_SWING + EPS, "swing in range")
	end
end

function T.walkCycleSwingsBothWays()
	local speed = 6
	local quarter = PedestrianMath.STEP_LENGTH / speed / 2 -- phase pi/2
	local _, s1 = PedestrianMath.walkCycle(quarter, speed)
	local _, s2 = PedestrianMath.walkCycle(quarter * 3, speed)
	assert(math.abs(s1 - PedestrianMath.MAX_SWING) < EPS, "full swing forward")
	assert(math.abs(s2 + PedestrianMath.MAX_SWING) < EPS, "full swing back")
	local bobUp = PedestrianMath.walkCycle(0, speed)
	local bobDown = PedestrianMath.walkCycle(quarter, speed)
	assert(bobUp > bobDown, "body is highest when the legs pass vertical")
end

-- ----------------------------------------------------------------- segmentsNear

function T.segmentsNearFindsOnlyCloseWalkableSegments()
	local roads: { TownLayout.Road } = {
		{ name = "A", kind = "residential", width = 16, points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(1000, 0, 0) } },
		{ name = "B", kind = "main", width = 20, points = { Vector3.new(0, 0, 5000), Vector3.new(100, 0, 5000) } },
	}
	local refs = PedestrianMath.segmentsNear(roads, { 1, 2 }, Vector3.new(50, 0, 30), 50)
	assert(#refs == 2, "both segments of road A touch the radius, got " .. #refs)
	for _, r in refs do
		assert(r.roadIndex == 1, "road B is too far")
	end
	local none = PedestrianMath.segmentsNear(roads, { 1, 2 }, Vector3.new(50, 0, 2000), 100)
	assert(#none == 0, "nothing near")
end

-- ----------------------------------------------------------------- bridges / river

local BRIDGES: { TownLayout.Bridge } = {
	{ name = "Test Bridge", kind = "road", from = Vector3.new(0, 0, 0), to = Vector3.new(0, 0, 100), width = 26 },
	{ name = "Test Viaduct", kind = "rail", from = Vector3.new(500, 0, 0), to = Vector3.new(500, 0, 100), width = 16 },
}

function T.roadBridgeCoversItsFootways()
	local footway = Vector3.new(13 + PAVE / 2, 0, 50)
	assert(PedestrianMath.roadBridgeAt(footway, BRIDGES, 0) ~= nil, "footway centre is on the deck")
	assert(PedestrianMath.roadBridgeAt(Vector3.new(40, 0, 50), BRIDGES, 0) == nil, "beyond the parapet is off the deck")
	assert(PedestrianMath.roadBridgeAt(Vector3.new(0, 0, 105), BRIDGES, 0) == nil, "past the deck end")
	assert(PedestrianMath.roadBridgeAt(Vector3.new(0, 0, 105), BRIDGES, 10) ~= nil, "slack stretches the deck")
	assert(PedestrianMath.roadBridgeAt(Vector3.new(500, 0, 50), BRIDGES, 0) == nil, "rail viaducts are ignored")
end

function T.groundYIsPavementOrFootway()
	local off = PedestrianMath.groundY(Vector3.new(200, 0, 50), "main", BRIDGES)
	assert(math.abs(off - PedestrianMath.PAVEMENT_TOP) < EPS, "pavement top off the bridge")
	local on = PedestrianMath.groundY(Vector3.new(17, 0, 50), "main", BRIDGES)
	assert(math.abs(on - (0.21 + 0.75 + TownLayout.BRIDGE_RISE)) < EPS, "footway top on the level middle of the bridge")
	assert(on > off, "the footway is above the street pavement")
	local ramp = PedestrianMath.groundY(Vector3.new(17, 0, TownLayout.BRIDGE_RAMP / 2), "main", BRIDGES)
	assert(math.abs(ramp - (0.21 + 0.75 + TownLayout.BRIDGE_RISE / 2)) < EPS, "half way up the ramp")
end

function T.riverBlocksOnlyOffTheBridges()
	local river: TownLayout.River = { name = "Test River", width = 40, points = { Vector3.new(-1000, 0, 50), Vector3.new(1000, 0, 50) } }
	assert(PedestrianMath.inRiver(Vector3.new(300, 0, 60), river, 0), "mid-channel is river")
	assert(not PedestrianMath.inRiver(Vector3.new(300, 0, 200), river, 0), "far bank is dry")
	assert(PedestrianMath.blockedByRiver(Vector3.new(300, 0, 60), river, BRIDGES, 5), "open water blocks")
	assert(not PedestrianMath.blockedByRiver(Vector3.new(17, 0, 60), river, BRIDGES, 5), "the bridge footway does not")
end

function T.realBridgeFootwaysAreNotRiver()
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind ~= "road" then
			continue
		end
		local mid = bridge.from:Lerp(bridge.to, 0.5)
		local u = (bridge.to - bridge.from).Unit
		local side = Vector3.new(-u.Z, 0, u.X) * (bridge.width / 2 + PAVE / 2)
		for _, p in { mid + side, mid - side } do
			assert(not PedestrianMath.blockedByRiver(p, TownLayout.RIVER, TownLayout.BRIDGES, 12), bridge.name .. " footway blocked")
		end
	end
end

function T.onRoundaboutIsTheDiscOnly()
	local rbs = { { name = "Test", centre = Vector3.new(0, 0, 0), radius = 40 } }
	assert(PedestrianMath.onRoundabout(Vector3.new(10, 0, 10), rbs), "inside the disc")
	assert(PedestrianMath.onRoundabout(Vector3.new(39, 5, 0), rbs), "height ignored")
	assert(not PedestrianMath.onRoundabout(Vector3.new(41, 0, 0), rbs), "on the pavement outside")
	assert(not PedestrianMath.onRoundabout(Vector3.new(0, 0, 0), {}), "no roundabouts")
end

return T
