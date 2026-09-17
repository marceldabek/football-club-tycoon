--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ImperfectionDresser = require(ServerScriptService.Server.ImperfectionDresser)
local TownBuilder = require(ServerScriptService.Server.TownBuilder)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local EPS = 1e-3

local function near(a: number, b: number, tol: number?): boolean
	return math.abs(a - b) <= (tol or EPS)
end

local function road(name: string, kind: string, width: number, points: { Vector3 }): any
	return { name = name, kind = kind, width = width, points = points }
end

function T.dashPositionsOnAStraightLineAreEvenlySpaced()
	local dashes = ImperfectionDresser.dashPositions({ Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, 6, 20, nil)
	assert(#dashes == 5, "count " .. #dashes)
	for i, d in dashes do
		assert(near(d.centre.X, 10 + (i - 1) * 20) and near(d.centre.Z, 0), ("dash %d at %s"):format(i, tostring(d.centre)))
		assert(near(d.direction.X, 1) and near(d.direction.Z, 0), "direction " .. tostring(d.direction))
		assert(d.slot == i, "slot " .. d.slot)
	end
end

function T.dashPositionsFollowTheSkipPattern()
	local dashes = ImperfectionDresser.dashPositions({ Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, 6, 20, { true, false })
	assert(#dashes == 3, "count " .. #dashes)
	assert(near(dashes[1].centre.X, 10) and near(dashes[2].centre.X, 50) and near(dashes[3].centre.X, 90), "positions")
	local none = ImperfectionDresser.dashPositions({ Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }, 6, 20, { false })
	assert(#none == 0, "all-false pattern painted " .. #none)
end

function T.dashesNeverStraddleABend()
	-- 17 along X then 100 along Z: slots every 10 from s = 5; s = 15 and s = 115
	-- would poke 1 stud past a segment end, so they are dropped
	local points = { Vector3.new(0, 0, 0), Vector3.new(17, 0, 0), Vector3.new(17, 0, 100) }
	local dashes = ImperfectionDresser.dashPositions(points, 6, 10, nil)
	assert(#dashes == 10, "count " .. #dashes)
	local bend = points[2]
	for _, d in dashes do
		assert(d.slot ~= 2 and d.slot ~= 12, "slot " .. d.slot .. " should be dropped")
		local dx, dz = d.centre.X - bend.X, d.centre.Z - bend.Z
		assert(math.sqrt(dx * dx + dz * dz) >= 3 - EPS, "dash too close to the bend: " .. tostring(d.centre))
	end
end

function T.skipPatternMissesTheRightShareDeterministically()
	local a = ImperfectionDresser.skipPattern(Random.new(7), 10, 0.3)
	local b = ImperfectionDresser.skipPattern(Random.new(7), 10, 0.3)
	assert(#a == 10, "length " .. #a)
	local misses = 0
	for i = 1, 10 do
		assert(a[i] == b[i], "same seed differs at " .. i)
		if not a[i] then
			misses += 1
		end
	end
	assert(misses == 3, "misses " .. misses)
	for _, painted in ImperfectionDresser.skipPattern(Random.new(1), 8, 0) do
		assert(painted, "share 0 should paint every slot")
	end
end

function T.acceptRectsKeepsOnlyNonOverlapping()
	local a = TownBuilder.rect(0, 0, 1, 0, 2, 1)
	local b = TownBuilder.rect(1, 0, 1, 0, 2, 1) -- overlaps a
	local c = TownBuilder.rect(10, 0, 1, 0, 2, 1)
	local taken = {}
	local kept = ImperfectionDresser.acceptRects({ a, b, c }, taken, nil)
	assert(#kept == 2 and kept[1] == a and kept[2] == c, "kept " .. #kept)
	assert(#taken == 2, "taken " .. #taken)
	-- a spacing margin rejects c too
	local spaced = ImperfectionDresser.acceptRects({ a, c }, {}, 9)
	assert(#spaced == 1 and spaced[1] == a, "with margin kept " .. #spaced)
	-- patches accepted one at a time against a shared list never overlap
	local shared = {}
	local rng = Random.new(3)
	for _ = 1, 200 do
		ImperfectionDresser.acceptRects({ TownBuilder.rect(rng:NextNumber(0, 60), rng:NextNumber(0, 60), 1, 0, rng:NextNumber(2, 5), rng:NextNumber(1, 3)) }, shared, 1)
	end
	for i = 1, #shared do
		for j = i + 1, #shared do
			assert(not TownBuilder.rectsOverlap(shared[i], shared[j]), ("patches %d and %d overlap"):format(i, j))
		end
	end
end

function T.giveWayLinesSpanTheApproachLaneOnTheLeft()
	-- minor road leaves the junction heading south (+Z); traffic approaching it
	-- drives north, so its left (UK lane) is west (-X)
	local rects = ImperfectionDresser.giveWayRects(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), 10)
	assert(#rects == 6, "count " .. #rects)
	for i, r in rects do
		assert(near(math.abs(r.ux), 1) and near(r.uz, 0), "dash " .. i .. " should run across the road")
		assert(r.cx - r.hl > -10 + 0.5 and r.cx + r.hl < 0, ("dash %d spans x %.2f..%.2f"):format(i, r.cx - r.hl, r.cx + r.hl))
		assert(r.cz > 0 and r.cz < 2, ("dash %d at z %.2f"):format(i, r.cz))
	end
	-- the two lines are separate (no dash overlaps another)
	for i = 1, #rects do
		for j = i + 1, #rects do
			assert(not TownBuilder.rectsOverlap(rects[i], rects[j]), ("dashes %d and %d overlap"):format(i, j))
		end
	end
	assert(#ImperfectionDresser.giveWayRects(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), 2) == 0, "too narrow a road gets no line")
end

function T.junctionsFindTeesAndRoundaboutsButNotEndToEnd()
	local major = road("Major", "main", 26, { Vector3.new(-200, 0, 0), Vector3.new(200, 0, 0) })
	local minor = road("Minor", "residential", 20, { Vector3.new(0, 0, 0), Vector3.new(0, 0, 150) })
	local onward = road("Onward", "main", 26, { Vector3.new(200, 0, 0), Vector3.new(400, 0, 0) })
	local spur = road("Spur", "residential", 20, { Vector3.new(0, 0, -300), Vector3.new(0, 0, -500) })
	local roundabouts = { { name = "Test Roundabout", centre = Vector3.new(0, 0, -300), radius = 40 } }
	local found = ImperfectionDresser.junctions({ major, minor, onward, spur }, roundabouts)
	assert(#found == 2, "junctions " .. #found)
	local tee, round = found[1], found[2]
	assert(tee.road == minor and tee.atStart and tee.major == major and near(tee.majorHalf, 13), "tee")
	assert(round.road == spur and round.atStart and round.major == nil and round.roundabout ~= nil and near(round.majorHalf, 40), "roundabout")
end

function T.mouthDistanceIsJustPastTheMajorCarriageway()
	local majorPoints = { Vector3.new(-200, 0, 0), Vector3.new(200, 0, 0) }
	local minorPoints = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 150) }
	local fn = function(p: Vector3): number
		return TownLayout.distanceToPolyline(p, majorPoints)
	end
	local s = ImperfectionDresser.mouthDistance(minorPoints, fn, 14.5, 90)
	assert(s ~= nil and s > 14.5 and s <= 15 + EPS, "mouth " .. tostring(s))
	assert(ImperfectionDresser.mouthDistance(minorPoints, fn, 14.5, 10) == nil, "beyond maxS should be nil")
end

function T.pointAtAndProjectAgree()
	local points = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) }
	local st = ImperfectionDresser.pointAt(points, 15)
	assert(st, "station")
	assert(near(st.position.X, 10) and near(st.position.Z, 5), "position " .. tostring(st.position))
	assert(st.segment == 2 and near(st.along, 5) and near(st.segmentLength, 10), "segment")
	assert(near(ImperfectionDresser.projectOnPolyline(Vector3.new(12, 0, 5), points), 15), "project")
	local clamped = ImperfectionDresser.pointAt(points, 999)
	assert(clamped and near(clamped.position.Z, 10), "clamped to the end")
	assert(near(ImperfectionDresser.polylineLength(ImperfectionDresser.reversed(points)), 20), "reversed length")
end

function T.roadRectSitsToTheRightOfTravel()
	local st = ImperfectionDresser.pointAt({ Vector3.new(0, 0, 0), Vector3.new(0, 0, -100) }, 50)
	assert(st, "station")
	-- heading north (-Z): right is east (+X)
	local r = ImperfectionDresser.roadRect(st, 4, 3, 1)
	assert(near(r.cx, 4) and near(r.cz, -50), ("centre %.2f, %.2f"):format(r.cx, r.cz))
	assert(near(r.hl, 3) and near(r.hw, 1) and near(r.uz, -1), "axes")
end

function T.capsFitThePartBudgetWithRoomForDashes()
	local max = ImperfectionDresser.maxParts()
	assert(max <= ImperfectionDresser.PART_BUDGET - 200, ("caps use %d of %d"):format(max, ImperfectionDresser.PART_BUDGET))
end

function T.surfaceLiftsKeepVisibleFacesApart()
	local lifts = { ImperfectionDresser.PATCH_LIFT, ImperfectionDresser.MARK_LIFT, ImperfectionDresser.IRON_LIFT }
	assert(lifts[1] >= 0.02 - EPS, "patch lift above the road")
	for i = 2, #lifts do
		assert(lifts[i] - lifts[i - 1] >= 0.02 - EPS, "lift " .. i)
	end
	-- the highest road kind plus its step stays under the pavement top
	local highest = TownBuilder.roadTop("lane") + TownBuilder.Y.STEP + ImperfectionDresser.IRON_LIFT
	assert(highest < TownBuilder.Y.PAVEMENT - 0.05, "iron top " .. highest)
end

function T.postersAreFictionalRivermereNotices()
	assert(#ImperfectionDresser.POSTERS >= 3, "posters")
	for _, poster in ImperfectionDresser.POSTERS do
		assert(not poster.text:lower():find("riverdale"), "poster says Riverdale: " .. poster.text)
		assert(#poster.text > 0, "empty poster")
	end
end

function T.realLayoutHasJunctionsWithAMajorRoadOrRoundabout()
	local found = ImperfectionDresser.junctions(TownLayout.ROADS, TownLayout.ROUNDABOUTS)
	assert(#found >= 10, "junctions " .. #found)
	for _, j in found do
		assert(j.major ~= nil or j.roundabout ~= nil, "junction without a major road: " .. j.road.name)
		assert(j.major ~= j.road, "road joins itself: " .. j.road.name)
	end
end

function T.blockRectMatchesTheLayoutBox()
	local r = ImperfectionDresser.blockRect({ centre = Vector3.new(5, 10, -7), size = Vector3.new(40, 20, 20), yaw = 0, use = "shops" }, 1)
	assert(near(r.cx, 5) and near(r.cz, -7), "centre")
	assert(near(r.hl, 21) and near(r.hw, 11) and near(r.ux, 1) and near(r.uz, 0), "extents")
end

return T
