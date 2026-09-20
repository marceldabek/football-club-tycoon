--!strict
-- Rivermere v3, Lane R: pure tiling tests on small fixtures. No Instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

local function road(name: string, points: { Vector3 }, extra: { [string]: any }?): any
	local r = { name = name, kind = "residential", width = 20, points = points, district = "Test" }
	for k, val in extra or {} do
		r[k] = val
	end
	return r
end

local function count(plan: any, kind: string): number
	return plan.stats[kind] or 0
end

-- Every mouth must meet another mouth within a stud. Returns the unmatched ones.
local function looseMouths(plan: any): { Vector3 }
	local all = {}
	for _, tile in plan.tiles do
		for _, m in RoadTiles.mouths(tile) do
			table.insert(all, m)
		end
	end
	local loose = {}
	for i, m in all do
		local matched = false
		for j, other in all do
			if i ~= j and (m - other).Magnitude <= 1 then
				matched = true
				break
			end
		end
		if not matched then
			table.insert(loose, m)
		end
	end
	return loose
end

local function hasLooseNear(loose: { Vector3 }, p: Vector3, tolerance: number): boolean
	for _, m in loose do
		if (m - p).Magnitude <= tolerance then
			return true
		end
	end
	return false
end

local tests = {}

function tests.straightFitsItsRemainderExactly()
	local plan = RoadTiles.plan({ road("A", { v(0, 0), v(300, 0) }) }, {})
	assert(count(plan, "straight") == 3, "expected 3 straights, got " .. count(plan, "straight"))
	assert(plan.stats.tiles == 3, "only straights expected")
	local tileLen = 110 * 0.816
	for _, t in plan.tiles do
		assert(math.abs(t.stretch * tileLen - 100) < 1e-3, "each tile should cover 100 studs")
		assert(t.stretch > 0.66 and t.stretch < 1.5, "stretch out of range " .. t.stretch)
		assert(math.abs(t.cframe.Position.Y - RoadTiles.SURFACE_Y) < 1e-4, "tile top at the surface level")
	end
	local loose = looseMouths(plan)
	assert(#loose == 2, "only the two dead ends are loose, got " .. #loose)
	assert(hasLooseNear(loose, v(0, 0), 0.01) and hasLooseNear(loose, v(300, 0), 0.01), "ends land on the road's ends")
end

function tests.rightAngleGetsOneBendAndJoinsUp()
	local plan = RoadTiles.plan({ road("L", { v(0, 0), v(400, 0), v(400, 300) }) }, {})
	assert(count(plan, "bend90") == 1, "one 90 bend")
	assert(#looseMouths(plan) == 2, "bend mouths meet the straights")
end

function tests.bothTurnDirectionsJoinUp()
	for _, zEnd in { 300, -300 } do
		local plan = RoadTiles.plan({ road("L", { v(0, 0), v(400, 0), v(400, zEnd) }) }, {})
		assert(#looseMouths(plan) == 2, "90 bend towards z=" .. zEnd)
		local plan45 = RoadTiles.plan({ road("D", { v(0, 0), v(400, 0), v(700, zEnd) }) }, {})
		assert(count(plan45, "bend45") == 1, "one 45 bend")
		assert(#looseMouths(plan45) == 2, "45 bend towards z=" .. zEnd)
	end
end

function tests.shortLegGoesOnTheShorterStretch()
	-- 130 studs is room for the 45 bend's short leg twice (49 + 49) but not long + short + ...
	local plan = RoadTiles.plan({ road("Z", { v(0, 0), v(400, 0), v(500, 100), v(900, 100) }) }, {})
	assert(count(plan, "bend45") == 2, "two 45 bends")
	assert(plan.stats.unresolved == 0, "fits without conflict")
	assert(plan.stats.shrunk == 0, "fits without shrinking")
	assert(#looseMouths(plan) == 2, "joined up")
end

function tests.teeJunction()
	local plan = RoadTiles.plan({
		road("Through", { v(0, 0), v(600, 0) }),
		road("Branch", { v(300, 0), v(300, 300) }),
	}, {})
	assert(count(plan, "tee") == 1, "one T")
	assert(count(plan, "cross") == 0, "no cross")
	assert(#looseMouths(plan) == 3, "three dead ends, got " .. #looseMouths(plan))
end

function tests.teeOnTheOtherSide()
	local plan = RoadTiles.plan({
		road("Through", { v(0, 0), v(600, 0) }),
		road("Branch", { v(300, 0), v(300, -300) }),
	}, {})
	assert(count(plan, "tee") == 1 and #looseMouths(plan) == 3, "T with the branch to -Z")
end

function tests.crossroadsWhereTwoRoadsCross()
	local plan = RoadTiles.plan({
		road("EW", { v(0, 0), v(600, 0) }),
		road("NS", { v(300, -300), v(300, 300) }),
	}, {})
	assert(count(plan, "cross") == 1, "one crossroads")
	assert(#looseMouths(plan) == 4, "four dead ends")
end

function tests.headRoadEndsInACulDeSacOnThePoint()
	-- out of the Town Centre box, so the plain (not yellow-line) head is used
	local plan = RoadTiles.plan({ road("Close", { v(3000, 0), v(3000, 250) }, { head = true }) }, {})
	assert(count(plan, "head") == 1, "one head")
	local loose = looseMouths(plan)
	assert(#loose == 1 and hasLooseNear(loose, v(3000, 0), 0.01), "only the open end is loose")
	for _, t in plan.tiles do
		if t.kind == "head" then
			-- bulb centre is 16.39 * scale from the bbox centre, towards the closed end
			local bulb = t.cframe * Vector3.new(-16.39 * t.scale, 0, 0)
			assert((Vector3.new(bulb.X, 0, bulb.Z) - v(3000, 250)).Magnitude < 0.01, "bulb sits on the head point")
		end
	end
end

function tests.yellowHeadInTheCentreJoinsUpToo()
	local plan = RoadTiles.plan({ road("Marina", { v(0, 0), v(0, 250) }, { head = true }) }, {})
	assert(plan.tiles[1].piece:find("CulDeSacYellowLines") ~= nil, "yellow head piece")
	assert(#looseMouths(plan) == 1, "joined to its straights")
end

function tests.crowdedTeesAreDowngradedToTucks()
	-- two branches 30 studs apart: two 90-long T pieces cannot both fit
	local plan = RoadTiles.plan({
		road("Through", { v(0, 0), v(600, 0) }),
		road("B1", { v(300, 0), v(300, 300) }),
		road("B2", { v(330, 0), v(330, -300) }),
	}, {})
	assert(plan.stats.unresolved == 0, "conflict resolved")
	assert(plan.stats.downgraded >= 1, "at least one T downgraded")
	assert((plan.stats.tucked or 0) >= 1, "its branch is tucked")
	for _, t in plan.tiles do
		if t.tucked then
			assert(t.cframe.Position.Y < RoadTiles.SURFACE_Y, "tucked tile is pitched below the surface")
			assert(t.cframe.Position.Y > RoadTiles.SURFACE_Y - 1, "but only slightly")
		end
	end
end

function tests.fortyFiveDegreeSpurTucksUnderTheBend()
	-- the High Street / Station Road split: one road bends 45, another leaves on the old line
	local plan = RoadTiles.plan({
		road("High", { v(400, 400), v(0, 0), v(-500, 0) }, { kind = "main" }),
		road("Station", { v(0, 0), v(-300, -300) }),
	}, {})
	assert(count(plan, "bend45") == 1, "the main road keeps its bend")
	assert(count(plan, "tee") == 0, "no T at 45 degrees")
	assert((plan.stats.tucked or 0) == 1, "the spur tucks")
	assert(plan.stats.unresolved == 0, "no conflicts")
end

function tests.bigRoundaboutTrimsArmsAndLeavesAStandIn()
	local plan = RoadTiles.plan({
		road("EW", { v(-400, 0), v(400, 0) }, { kind = "ring" }),
		road("N", { v(0, 0), v(0, -400) }, { kind = "main" }),
	}, { { name = "RB", centre = v(0, 0), radius = 40 } })
	assert(count(plan, "tee") == 0, "no T under a roundabout")
	assert(#plan.exempt == 2, "disc + island")
	for _, ex in plan.exempt do
		assert(ex.id == "E3", "registered as E3")
	end
	for _, t in plan.tiles do
		for _, m in RoadTiles.mouths(t) do
			assert(m.Magnitude >= 31.9, "no tile reaches inside the trimmed circle")
		end
	end
end

function tests.yellowLinesInTheCentreAndOnLanes()
	local plan = RoadTiles.plan({
		road("Centre", { v(0, 100), v(300, 100) }, { district = false }),
		road("Far", { v(3000, 0), v(3300, 0) }),
		road("Plot Lane", { v(4000, 0), v(4000, 200) }, { kind = "lane" }),
	}, {})
	for _, t in plan.tiles do
		local yellow = t.piece:find("YellowLines") ~= nil
		if t.road == "Far" then
			assert(not yellow, "no yellow lines out of town")
		else
			assert(yellow, "yellow lines on " .. t.road)
		end
	end
end

function tests.deterministic()
	local roads = { road("L", { v(0, 0), v(400, 0), v(400, 300) }), road("B", { v(200, 0), v(200, -250) }, { head = true }) }
	local a, b = RoadTiles.plan(roads, {}), RoadTiles.plan(roads, {})
	assert(#a.tiles == #b.tiles, "same count")
	for i, t in a.tiles do
		assert(t.piece == b.tiles[i].piece and (t.cframe.Position - b.tiles[i].cframe.Position).Magnitude < 1e-6, "same tiles in the same order")
	end
end

-- Lane I stage 3: the bridge deck is the road over the water, so no tile may sit
-- inside a bridge span, and the straights still reach both ends of it.
function tests.straightsStopAtABridgeSpan()
	local bridge = { from = v(200, 0), to = v(380, 0), kind = "road" }
	local plan = RoadTiles.plan({ road("A", { v(0, 0), v(600, 0) }) }, {}, { bridge })
	assert(plan.stats.bridged == 1, "one run crosses the bridge")
	for _, t in plan.tiles do
		local half = t.stretch * 110 * t.scale / 2
		local x = t.cframe.Position.X
		assert(x + half <= 200.01 or x - half >= 379.99, ("tile at %.0f overlaps the span"):format(x))
	end
	local loose = looseMouths(plan)
	assert(hasLooseNear(loose, v(200, 0), 0.01) and hasLooseNear(loose, v(380, 0), 0.01), "straights reach both bridge ends")
	local plain = RoadTiles.plan({ road("A", { v(0, 0), v(600, 0) }) }, {})
	assert(plain.stats.bridged == nil, "no bridges given, nothing bridged")
end

function tests.wholeTownSkipsEveryRoadBridge()
	local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any, TownLayout.BRIDGES :: any)
	assert(plan.stats.unresolved == 0, plan.stats.unresolved .. " unresolved conflicts")
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind == "road" then
			local length = TownLayout.bridgeLength(bridge)
			for _, t in plan.tiles do
				local along, across = TownLayout.bridgeAlong(bridge, t.cframe.Position)
				assert(not (along > 5 and along < length - 5 and across < 5), ("%s tile centred on %s"):format(t.road, bridge.name))
			end
		end
	end
end

-- Lane I stage 3: a crossroads whose arm is a few studs longer than a dead-end
-- lane keeps its piece (it was downgraded to a bend that ran 38 studs into Plot 2).
function tests.plotLanesDoNotOvershootTheirEnd()
	local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any, TownLayout.BRIDGES :: any)
	for i = 1, 4 do
		local plotCFrame = TownLayout.plotCFrame(i)
		for _, t in plan.tiles do
			for _, m in RoadTiles.mouths(t) do
				if TownLayout.pointInPlot(m, i) then
					local past = plotCFrame:PointToObjectSpace(m).X - TownLayout.PLOT_LANE_END.X
					assert(past <= RoadTiles.END_OVERSHOOT + 0.01, ("%s runs %.1f past Plot %d's lane end"):format(t.road, past, i))
				end
			end
		end
	end
end

function tests.wholeTownResolvesAndJoinsUp()
	local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any)
	assert(plan.stats.unresolved == 0, plan.stats.unresolved .. " unresolved conflicts")
	assert(plan.stats.maxGap <= 1, "gap over a stud: " .. plan.stats.maxGap)
	assert(plan.stats.tiles <= 1200, "tile count " .. plan.stats.tiles)
	for _, t in plan.tiles do
		assert(t.stretch > 0.01 and t.stretch < 1.5, ("stretch %.2f on %s"):format(t.stretch, t.road))
		assert(t.scale >= 0.5, ("scale %.2f on %s"):format(t.scale, t.road))
	end
end

return tests
