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

function tests.crowdedTeesAreDowngradedToRaisedEntries()
	-- two branches 30 studs apart: two 90-long T pieces cannot both fit
	local plan = RoadTiles.plan({
		road("Through", { v(0, 0), v(600, 0) }),
		road("B1", { v(300, 0), v(300, 300) }),
		road("B2", { v(330, 0), v(330, -300) }),
	}, {})
	assert(plan.stats.unresolved == 0, "conflict resolved")
	assert(plan.stats.downgraded >= 1, "at least one T downgraded")
	assert((plan.stats.entries or 0) >= 1 and (plan.stats.tucked or 0) == 0, "its branch comes in as a raised entry, not a tuck")
	for _, t in plan.tiles do
		if t.entry then
			assert(t.cframe.Position.Y > RoadTiles.SURFACE_Y, "entry tile is ramped above the surface")
			assert(t.cframe.Position.Y < RoadTiles.SURFACE_Y + 0.5, "but only slightly")
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
-- Marcel 2026-09-20: two road sizes only. Every street is one scale, so no tile
-- meets a tile of another width; alleys are the one smaller, paved size.
function tests.everyStreetIsOneSizeAndNoJunctionSteps()
	local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
	for _, kind in { "ring", "main", "residential", "lane" } do
		assert(RoadTiles.SCALE[kind] == RoadTiles.STREET_SCALE, kind .. " is not street sized")
	end
	assert(RoadTiles.SCALE.alley == RoadTiles.ALLEY_SCALE and RoadTiles.ALLEY_SCALE < RoadTiles.STREET_SCALE, "alleys are the smaller size")
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any, TownLayout.BRIDGES :: any)
	for _, t in plan.tiles do
		local want = if t.roadKind == "alley" then RoadTiles.ALLEY_SCALE else RoadTiles.STREET_SCALE
		assert(t.scale == want, ("%s (%s) tile at scale %.3f"):format(t.road, t.roadKind, t.scale))
	end
end

function tests.alleyTilesAreHalfWidthAndFlaggedForPaving()
	local plan = RoadTiles.plan({
		{ name = "Test Alley", kind = "alley", points = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 200) }, district = "Test" },
	} :: any, {}, {})
	assert(#plan.tiles > 0, "alley tiled")
	for _, t in plan.tiles do
		assert(t.roadKind == "alley" and t.scale == RoadTiles.ALLEY_SCALE, "alley tile is alley sized")
	end
end

-- A side road that meets a plain through road square on must open into it: it comes
-- in as a raised entry ending on the through road's kerb line, never tucked under.
function tests.squareSideRoadsComeInAsRaisedEntries()
	local plan = RoadTiles.plan({
		{ name = "Main", kind = "main", points = { Vector3.new(-400, 0, 0), Vector3.new(400, 0, 0) } },
		-- two side streets 40 apart: too close for two T pieces (90 long each)
		{ name = "Side A", kind = "residential", points = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 300) } },
		{ name = "Side B", kind = "residential", points = { Vector3.new(40, 0, 0), Vector3.new(40, 0, -300) } },
	} :: any, {}, {})
	local entries = 0
	for _, t in plan.tiles do
		if t.road ~= "Main" then
			assert(not t.tucked, t.road .. " still tucks under the main road")
		end
		if t.entry then
			entries += 1
			local kerb = RoadTiles.KIT_CARRIAGEWAY / 2 * RoadTiles.STREET_SCALE
			local nearest, high = math.huge, -math.huge
			for _, m in RoadTiles.mouths(t) do
				nearest = math.min(nearest, math.abs(m.Z))
			end
			assert(math.abs(nearest - kerb) < 0.1, ("%s entry ends %.2f from the main centreline, kerb line is %.2f"):format(t.road, nearest, kerb))
			-- the mouth end is the high end, and clears the through pavement
			local look = t.cframe.LookVector
			assert(math.abs(look.Y) > 1e-4, t.road .. " entry is not ramped")
			assert(t.cframe.Position.Y > RoadTiles.SURFACE_Y, t.road .. " entry does not rise")
		end
	end
	assert(entries >= 1, "at least one of the two side streets is a raised entry, got " .. entries)
end

function tests.theTownHasNoSquareTucksLeft()
	local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
	local plan = RoadTiles.plan(TownLayout.ROADS :: any, TownLayout.ROUNDABOUTS :: any, TownLayout.BRIDGES :: any)
	assert((plan.stats.entries or 0) >= 20, "raised entries in town: " .. tostring(plan.stats.entries))
	-- what still tucks is only the skew junctions: three 45-degree arms (Station Road,
	-- Riverside Road, Ferry Lane) and four arms that arrive at another road's bend
	-- (Fern Street, Cooper Street, Lune Street x2)
	assert((plan.stats.tucked or 0) <= 7, "tucked tiles left: " .. tostring(plan.stats.tucked))
end

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
