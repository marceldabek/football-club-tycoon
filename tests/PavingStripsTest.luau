--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PavingStrips = require(ReplicatedStorage.Shared.PavingStrips)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local function road(name: string, kind: string, points: { Vector3 }, head: boolean?): any
	return { name = name, kind = kind, width = 20, points = points, front = "none", head = head }
end

-- far from the Town Centre box, the river and any roundabout
local O = Vector3.new(5000, 0, 5000)

-- Lateral reach of a strip from the x axis through O (for a road along +X).
local function lateral(strip: PavingStrips.Strip): (number, number)
	local z = math.abs(strip.cframe.Position.Z - O.Z)
	return z - strip.size.X / 2, z + strip.size.X / 2
end

function T.aStreetGetsAStripEachSideBehindTheKitPaving()
	local strips = PavingStrips.plan({ road("Street", "residential", { O, O + Vector3.new(300, 0, 0) }) }, {}, {}, nil)
	assert(#strips >= 2, "both sides")
	local sides = { [1] = 0, [-1] = 0 }
	local total = 0
	for _, s in strips do
		local inner, outer = lateral(s)
		assert(math.abs(outer - RoadTiles.pavementOuter("residential")) < 1e-3, "out to the pavement's back edge")
		assert(inner < RoadTiles.KIT_PAVING_OUTER * RoadTiles.STREET_SCALE and inner > RoadTiles.kerbDistance("residential"), "starts under the kit paving, clear of the kerb")
		assert(s.size.Z <= PavingStrips.CHUNK + 2 * PavingStrips.JOINT + 1e-3, "no piece longer than a chunk")
		local top = s.cframe.Position.Y + s.size.Y / 2
		assert(top < RoadTiles.SURFACE_Y and top > RoadTiles.SURFACE_Y - 0.05, "just under the kit paving's top")
		sides[if s.cframe.Position.Z > O.Z then 1 else -1] += 1
		total += s.size.Z - 2 * PavingStrips.JOINT
	end
	assert(sides[1] > 0 and sides[-1] > 0, "one on each side")
	assert(math.abs(total - 600) < 1, "the whole street, both sides")
	assert(RoadTiles.pavementOuter("residential") < (RoadTiles.corridorHalf("residential", 20) :: number), "grass left before the garden fences")
end

function T.onlyWalkedStreetsAreWidened()
	for _, kind in { "ring", "lane", "alley" } do
		assert(#PavingStrips.plan({ road("R", kind, { O, O + Vector3.new(300, 0, 0) }) }, {}, {}, nil) == 0, kind .. " is not widened")
	end
end

function T.stripsStopAtASideRoadsMouthAndAtItsEnd()
	local roads = {
		road("Through", "residential", { O, O + Vector3.new(400, 0, 0) }),
		road("Side", "residential", { O + Vector3.new(200, 0, 300), O + Vector3.new(200, 0, 0) }),
	}
	local mouth = RoadTiles.KIT_PAVING_OUTER * RoadTiles.STREET_SCALE
	for _, s in PavingStrips.plan(roads, {}, {}, nil) do
		local p = s.cframe.Position
		local alongX = math.abs(s.cframe.LookVector.X) > 0.5
		if s.road == "Through" and p.Z > O.Z then
			-- the side of the through road the side road joins
			local from, to = p.X - s.size.Z / 2 - O.X, p.X + s.size.Z / 2 - O.X
			assert(to <= 200 - mouth + PavingStrips.JOINT + 1.01 or from >= 200 + mouth - PavingStrips.JOINT - 1.01, ("strip %.0f..%.0f crosses the mouth"):format(from, to))
		elseif s.road == "Side" then
			assert(not alongX, "side road strips run along it")
			local nearEnd = p.Z - s.size.Z / 2 - O.Z
			assert(nearEnd >= RoadTiles.pavementOuter("residential") - PavingStrips.JOINT - 1.01, "stops at the back of the through road's pavement")
		end
	end
end

function T.aTurningHeadsBulbIsLeftAlone()
	local strips = PavingStrips.plan({ road("Close", "residential", { O, O + Vector3.new(300, 0, 0) }, true) }, {}, {}, nil)
	local bulb = RoadTiles.PIECES.head.legA * RoadTiles.STREET_SCALE
	for _, s in strips do
		assert(s.cframe.Position.X + s.size.Z / 2 - O.X <= 300 - bulb + PavingStrips.JOINT + 1.01, "strip runs into the bulb")
	end
	assert(#strips >= 2, "the rest of the close is widened")
end

function T.theTownCentreRoundaboutsAndBridgesAreSkipped()
	local inCentre = PavingStrips.plan({ road("High", "main", { Vector3.new(-100, 0, 0), Vector3.new(100, 0, 0) }) }, {}, {}, nil)
	assert(#inCentre == 0, "the centre's verge is already paving")
	local rbs = { { name = "R", centre = O + Vector3.new(150, 0, 0), radius = 40 } } :: any
	for _, s in PavingStrips.plan({ road("Street", "residential", { O, O + Vector3.new(300, 0, 0) }) }, rbs, {}, nil) do
		assert(math.abs(s.cframe.Position.X - (O.X + 150)) > 20, "strip centred on the roundabout")
	end
end

function T.theTownsStripsStayInsideTheirRoadsCorridor()
	local strips = PavingStrips.town()
	assert(#strips > 200 and #strips < 2500, ("%d strips"):format(#strips)) -- TEMP part budget
	local byName: { [string]: TownLayout.Road } = {}
	for _, r in TownLayout.ROADS do
		byName[r.name] = r
	end
	for _, s in strips do
		local r = byName[s.road]
		assert(r and (r.kind == "main" or r.kind == "residential"), "strip on " .. s.road)
		-- bends are rounded, so allow the fillet's 0.41 R on top of the pavement's back edge
		local limit = RoadTiles.pavementOuter(r.kind) + RoadTiles.KIT_BEND90_RADIUS * RoadTiles.STREET_SCALE * 0.42
		assert(TownLayout.distanceToPolyline(s.cframe.Position, r.points) <= limit, s.road .. " strip off its road")
	end
end

return T
