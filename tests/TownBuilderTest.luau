--!strict
-- Pure checks for TownBuilder helpers; nothing is built into workspace.
local ServerScriptService = game:GetService("ServerScriptService")
local TownBuilder = require(ServerScriptService.Server.TownBuilder)

local T = {}

local EPS = 1e-4

local function close(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or EPS)
end

function T.segmentCFrameLengthAndMidpoint()
	local cf, length = TownBuilder.segmentCFrame(Vector3.new(0, 0, 0), Vector3.new(30, 0, 40), 0.1)
	assert(close(length, 50), "length " .. length)
	assert(close(cf.Position.X, 15) and close(cf.Position.Y, 0.1) and close(cf.Position.Z, 20), tostring(cf.Position))
end

function T.segmentCFrameIgnoresInputY()
	local cf, length = TownBuilder.segmentCFrame(Vector3.new(-10, 50, 5), Vector3.new(10, -20, 5), 2)
	assert(close(length, 20), "length " .. length)
	assert(close(cf.Position.Y, 2), "y " .. cf.Position.Y)
	assert(close(cf.LookVector.Y, 0), "look not level")
end

function T.segmentCFrameLooksAlongSegment()
	local cases = {
		{ Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) },
		{ Vector3.new(0, 0, 0), Vector3.new(-100, 0, 0) },
		{ Vector3.new(0, 0, 0), Vector3.new(0, 0, 100) },
		{ Vector3.new(0, 0, 0), Vector3.new(0, 0, -100) },
		{ Vector3.new(-1300, 0, -800), Vector3.new(-650, 0, -1000) },
		{ Vector3.new(1250, 0, 720), Vector3.new(700, 0, 800) },
	}
	for _, case in cases do
		local a, b = case[1], case[2]
		local cf = TownBuilder.segmentCFrame(a, b, 0)
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		assert((cf.LookVector - dir).Magnitude < EPS, ("look %s want %s"):format(tostring(cf.LookVector), tostring(dir)))
		assert(close(cf.UpVector.Y, 1), "not upright")
		-- a part of that length centred on the CFrame reaches both ends
		local halfLength = (b - a).Magnitude / 2
		local front = cf * Vector3.new(0, 0, -halfLength)
		assert(close(front.X, b.X, 1e-3) and close(front.Z, b.Z, 1e-3), "front end " .. tostring(front))
	end
end

function T.segmentCFrameZeroLength()
	local cf, length = TownBuilder.segmentCFrame(Vector3.new(5, 0, 5), Vector3.new(5, 9, 5), 1)
	assert(length == 0, "length " .. length)
	assert(close(cf.Position.X, 5) and close(cf.Position.Y, 1), tostring(cf.Position))
end

function T.freeRunsSplitsAndDropsShortRuns()
	local blocked = { false, false, true, false, true, true, false, false, false }
	local runs = TownBuilder.freeRuns(blocked, 2, 3)
	assert(#runs == 2, "runs " .. #runs)
	assert(runs[1][1] == 0 and runs[1][2] == 4, "run 1")
	assert(runs[2][1] == 12 and runs[2][2] == 18, "run 2")
	assert(#TownBuilder.freeRuns({ true, true }, 2, 1) == 0, "all blocked")
	local all = TownBuilder.freeRuns({ false, false, false }, 1.5, 1)
	assert(#all == 1 and all[1][1] == 0 and close(all[1][2], 4.5), "all free")
end

function T.rectsOverlapCrossingParallelTouching()
	local road = TownBuilder.segmentRect(Vector3.new(-50, 0, 0), Vector3.new(50, 0, 0), 10) :: TownBuilder.Rect
	local crossing = TownBuilder.segmentRect(Vector3.new(0, 0, -50), Vector3.new(0, 0, 50), 4) :: TownBuilder.Rect
	assert(TownBuilder.rectsOverlap(road, crossing), "crossing should overlap")
	local pavement = TownBuilder.segmentRect(Vector3.new(-50, 0, 14), Vector3.new(50, 0, 14), 4) :: TownBuilder.Rect
	assert(not TownBuilder.rectsOverlap(road, pavement), "touching pavement should not overlap")
	local apart = TownBuilder.segmentRect(Vector3.new(-50, 0, 30), Vector3.new(50, 0, 30), 4) :: TownBuilder.Rect
	assert(not TownBuilder.rectsOverlap(road, apart), "parallel apart")
	local diagonal = TownBuilder.segmentRect(Vector3.new(40, 0, 40), Vector3.new(60, 0, 20), 2) :: TownBuilder.Rect
	assert(not TownBuilder.rectsOverlap(road, diagonal), "diagonal clear of the corner")
	assert(TownBuilder.segmentRect(Vector3.new(1, 0, 1), Vector3.new(1, 0, 1), 3) == nil, "degenerate")
end

function T.circleOverlapsRect()
	local road = TownBuilder.segmentRect(Vector3.new(-50, 0, 0), Vector3.new(50, 0, 0), 10) :: TownBuilder.Rect
	assert(TownBuilder.circleOverlapsRect(0, 15, 8, road), "circle over the edge")
	assert(not TownBuilder.circleOverlapsRect(0, 18, 8, road), "circle touching the edge")
	assert(not TownBuilder.circleOverlapsRect(60, 10, 8, road), "circle off the corner")
end

function T.yLevelsAreOrderedAndDistinct()
	local Y = TownBuilder.Y
	local ring, main, residential, lane = Y.ROAD.ring, Y.ROAD.main, Y.ROAD.residential, Y.ROAD.lane
	assert(Y.ROUNDABOUT < ring and ring < main and main < residential and residential < lane, "road kinds")
	assert(lane < Y.SQUARE and Y.SQUARE < Y.FLAT and Y.FLAT < Y.PAVEMENT and Y.PAVEMENT < Y.RAIL_BED, "ground pieces")
	assert(Y.WATER_TOP < 0 and Y.RIVER_BED < Y.WATER_TOP, "river")
	-- every carriageway surface (joint, odd, even segment) of every kind is unique
	local tops: { number } = { Y.ROUNDABOUT, Y.SQUARE, Y.FLAT, Y.PAVEMENT }
	for _, kind in { "ring", "main", "residential", "lane" } do
		local top = TownBuilder.roadTop(kind)
		table.insert(tops, top - Y.STEP)
		table.insert(tops, top)
		table.insert(tops, top + Y.STEP)
	end
	for i = 1, #tops do
		for j = i + 1, #tops do
			assert(math.abs(tops[i] - tops[j]) >= 0.001, ("tops %d and %d coincide (%.3f)"):format(i, j, tops[i]))
		end
	end
	assert(TownBuilder.roadTop("unknown") == lane, "fallback kind")
end

return T
