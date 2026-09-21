--!strict
-- Rivermere v3: the frontage generator. Strict on purpose: builder lanes place
-- kit houses on these lots without looking, so a lot in the road is a house in
-- the road.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)

local T = {}

local EPS = 1e-3

-- PARITY-BEGIN (written by `python tools/town_v3_parity.py --write`; do not edit by hand)
local PARITY = {
	total = 892,
	byUse = { ["corner shop"] = 47, ["detached house"] = 109, ["flats"] = 10, ["semis"] = 214, ["shops"] = 16, ["shops with flats"] = 34, ["terraced row"] = 437, ["trade counter"] = 4, ["warehouse"] = 3, ["workshop"] = 18 },
	byDistrict = { ["Hollingford"] = 100, ["Industrial Estate"] = 25, ["Mapleford"] = 85, ["Mill Street Terraces"] = 59, ["Millbrook"] = 110, ["Northfields"] = 120, ["Riverside"] = 143, ["Station"] = 43, ["Town Centre"] = 40, ["Westdale"] = 167 },
	positionSum = 71124,
	idSum = 1862291,
}
-- PARITY-END

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function roadNamed(name: string): TownLayout.Road
	for _, road in TownLayout.ROADS do
		if road.name == name then
			return road
		end
	end
	error("no road named " .. name)
end

-- "<road>|<side>|<segment>|<n>"
local function parseId(id: string): (string, string, number, number)
	local road, side, segment, n = id:match("^(.+)|(%a+)|(%d+)|(%d+)$")
	assert(road and side and segment and n, "malformed lot id: " .. id)
	return road, side, tonumber(segment) :: number, tonumber(n) :: number
end

-- The footprint outline every `step` studs (corners included) plus the centre.
local function outline(corners: { Vector3 }, step: number): { Vector3 }
	local out: { Vector3 } = {}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / step))
		for k = 0, n - 1 do
			table.insert(out, a:Lerp(b, k / n))
		end
	end
	table.insert(out, (corners[1] + corners[3]) / 2)
	return out
end

local function project(poly: { Vector3 }, ax: number, az: number): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, p in poly do
		local d = p.X * ax + p.Z * az
		lo, hi = math.min(lo, d), math.max(hi, d)
	end
	return lo, hi
end

local function polygonsOverlap(a: { Vector3 }, b: { Vector3 }): boolean
	for _, poly in { a, b } do
		for k = 1, #poly do
			local p, q = poly[k], poly[k % #poly + 1]
			local ax, az = -(q.Z - p.Z), q.X - p.X
			local loA, hiA = project(a, ax, az)
			local loB, hiB = project(b, ax, az)
			if hiA <= loB + EPS or hiB <= loA + EPS then
				return false
			end
		end
	end
	return true
end

local function boxCorners(box: TownLayout.Box, grow: number): { Vector3 }
	local cf = CFrame.new(box.centre.X, 0, box.centre.Z) * CFrame.Angles(0, math.rad(box.yaw), 0)
	local hx, hz = box.size.X / 2 + grow, box.size.Z / 2 + grow
	return {
		cf * Vector3.new(-hx, 0, -hz),
		cf * Vector3.new(hx, 0, -hz),
		cf * Vector3.new(hx, 0, hz),
		cf * Vector3.new(-hx, 0, hz),
	}
end

local function lotPointDistance(lot: TownFrontage.Lot, p: Vector3): number
	local l = TownFrontage.lotCFrame(lot):PointToObjectSpace(Vector3.new(p.X, 0, p.Z))
	local dx = math.max(math.abs(l.X) - lot.size.X / 2, 0)
	local dz = math.max(math.abs(l.Z) - lot.size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function setbackOf(lot: TownFrontage.Lot, road: TownLayout.Road): number
	-- a corner shop is cut from a terraced cell, so it sits on the terrace's line
	local t = TownFrontage.TYPES[lot.use]
	return road.width / 2 + TownLayout.PAVEMENT_WIDTH + t.garden + t.depth / 2
end

function T.generatesATown()
	local lots = TownFrontage.generate()
	assert(#lots >= 700, ("only %d lots; the town reads as empty grass"):format(#lots))
	assert(TownFrontage.generate() == lots, "generate() is not cached")
end

function T.matchesThePythonDrawing()
	local lots = TownFrontage.generate()
	local byUse: { [string]: number } = {}
	local byDistrict: { [string]: number } = {}
	local positionSum, idSum = 0, 0
	for _, lot in lots do
		byUse[lot.use] = (byUse[lot.use] or 0) + 1
		byDistrict[lot.district] = (byDistrict[lot.district] or 0) + 1
		positionSum += math.floor(lot.centre.X + 0.5) + 3 * math.floor(lot.centre.Z + 0.5)
		for i = 1, #lot.id do
			idSum += string.byte(lot.id, i)
		end
	end
	local hint = " (python tools/town_v3_parity.py shows the Python side)"
	assert(#lots == PARITY.total, ("%d lots, Python has %d%s"):format(#lots, PARITY.total, hint))
	for _, pair in { { byUse, PARITY.byUse, "use" }, { byDistrict, PARITY.byDistrict, "district" } } :: { { any } } do
		local mine: { [string]: number }, theirs: { [string]: number }, what: string = pair[1], pair[2], pair[3]
		for name, count in theirs do
			assert(mine[name] == count, ("%s %s: %s lots, Python has %d%s"):format(what, name, tostring(mine[name]), count, hint))
		end
		for name, count in mine do
			assert(theirs[name] ~= nil, ("%s %s: %d lots, Python has none%s"):format(what, name, count, hint))
		end
	end
	assert(positionSum == PARITY.positionSum, ("position sum %d, Python has %d%s"):format(positionSum, PARITY.positionSum, hint))
	assert(idSum == PARITY.idSum, ("id sum %d, Python has %d%s"):format(idSum, PARITY.idSum, hint))
end

function T.twoRunsAreIdentical()
	local a, b = TownFrontage.build(), TownFrontage.build()
	assert(a ~= b, "build() must not return the cached table")
	assert(#a == #b, "two runs gave different lot counts")
	for i, lot in a do
		local other = b[i]
		for key, value in lot :: any do
			assert((other :: any)[key] == value, ("lot %s differs between runs at %s"):format(lot.id, key))
		end
	end
end

function T.idsAreUniqueAndWellFormed()
	local seen: { [string]: boolean } = {}
	for _, lot in TownFrontage.generate() do
		assert(not seen[lot.id], "duplicate lot id " .. lot.id)
		seen[lot.id] = true
		local roadName, side, segment = parseId(lot.id)
		assert(roadName == lot.street, lot.id .. " does not name its street " .. lot.street)
		local road = roadNamed(roadName)
		assert(segment >= 1 and segment <= #road.points - 1, lot.id .. " names a segment the road does not have")
		assert(side == "left" or side == "right" or side == "head", lot.id .. " has an unknown side")
		assert((side == "head") == lot.closesStreet, lot.id .. " side and closesStreet disagree")
		if side ~= "head" then
			assert(road.front == "both" or road.front == side, lot.id .. " is on a side its road does not front")
		else
			assert(road.head == true or road.closed == true, lot.id .. " closes a street that has no turning head or blunt end")
		end
	end
end

function T.lotFieldsAreConsistent()
	local districts: { [string]: boolean } = {}
	for _, district in TownLayout.DISTRICTS do
		districts[district.name] = true
	end
	for _, lot in TownFrontage.generate() do
		local t = TownFrontage.TYPES[lot.use]
		assert(t, lot.id .. " has an unknown use " .. lot.use)
		assert(districts[lot.district], lot.id .. " is in an unknown district " .. lot.district)
		assert(lot.centre.Y == 0, lot.id .. " centre is not at ground level")
		assert(lot.size.Y == t.height and lot.size.Z == t.depth, lot.id .. " height/depth do not match TYPES")
		assert(lot.units >= 1 and lot.units % 1 == 0, lot.id .. " units")
		if lot.use == "corner shop" then
			assert(lot.units == 1 and lot.corner, lot.id .. " corner shop must be a single corner unit")
			assert(lot.unitWidth == TownFrontage.TYPES["terraced row"].cell, lot.id .. " corner shop is not cut from a terrace cell")
			assert(math.abs(lot.size.X - (lot.unitWidth - TownFrontage.CORNER_SHOP_TRIM)) < EPS, lot.id .. " corner shop width")
		else
			assert(lot.unitWidth == t.cell, lot.id .. " unitWidth does not match TYPES")
			assert(math.abs(lot.size.X - (lot.units * t.cell - t.gap)) < EPS, lot.id .. " frontage is not units * cell - gap")
			assert(lot.units <= t.group + (if lot.use == "terraced row" then 1 else 0), lot.id .. " is longer than its group")
		end
		if lot.use == "terraced row" then
			assert(lot.units >= 2, lot.id .. " is a stranded single terraced house")
		end
		assert(math.abs(lot.front.Magnitude - 1) < EPS and lot.front.Y == 0, lot.id .. " front is not a flat unit vector")
	end
end

function T.indexesAddUp()
	local lots = TownFrontage.generate()
	local total = 0
	for district, list in TownFrontage.lotsByDistrict() do
		for _, lot in list do
			assert(lot.district == district, lot.id .. " filed under the wrong district")
		end
		total += #list
	end
	assert(total == #lots, "lotsByDistrict loses lots")
	total = 0
	for use in TownFrontage.TYPES do
		for _, lot in TownFrontage.lotsByUse(use) do
			assert(lot.use == use, lot.id .. " filed under the wrong use")
			total += 1
		end
	end
	assert(total == #lots, "lotsByUse loses lots")
end

-- Every lot sits at exactly its type's setback from its own street, square to it,
-- with `front` pointing at the street.
function T.lotsStandOnTheirStreetsBuildingLine()
	for _, lot in TownFrontage.generate() do
		local _, _, segment = parseId(lot.id)
		local road = roadNamed(lot.street)
		local a, b = flat(road.points[segment]), flat(road.points[segment + 1])
		local along = (b - a).Unit
		local right = TownFrontage.lotCFrame(lot).RightVector
		if lot.closesStreet and road.head then
			-- round the turning circle, facing its centre
			local t = TownFrontage.TYPES[lot.use]
			local out = lot.centre - b
			local expected = TownLayout.HEAD_RADIUS + t.garden + t.depth / 2
			assert(math.abs(out.Magnitude - expected) < 0.01, ("%s is %.2f from the centre of its turning head, expected %.2f"):format(lot.id, out.Magnitude, expected))
			assert(lot.front:Dot(out.Unit) < -1 + 1e-4, lot.id .. " does not face the centre of its turning head")
			local round = math.deg(math.acos(math.clamp(out.Unit:Dot(along), -1, 1)))
			assert(round < 0.1 or math.abs(round - TownFrontage.FAN_ANGLE) < 0.1, ("%s stands %.1f degrees round its turning head"):format(lot.id, round))
		elseif lot.closesStreet then
			-- across the blunt end of a terraced street, facing back down it
			local t = TownFrontage.TYPES[lot.use]
			assert(math.abs(right:Dot(along)) < 1e-4, lot.id .. " does not stand square across its street end")
			assert(lot.front:Dot(along) < -1 + 1e-4, lot.id .. " does not face back down its street")
			local reach = (lot.centre - b):Dot(along)
			local expected = road.width / 2 + TownLayout.PAVEMENT_WIDTH + t.garden + t.depth / 2
			assert(math.abs(reach - expected) < 0.01, ("%s is %.2f beyond its street end, expected %.2f"):format(lot.id, reach, expected))
		else
			assert(math.abs(right:Dot(along)) > 1 - 1e-6, lot.id .. " is not parallel to its street")
			assert(math.abs(lot.front:Dot(along)) < 1e-4, lot.id .. " does not face its street squarely")
			local setback = setbackOf(lot, road)
			local foot = lot.centre + lot.front * setback
			local d = TownLayout.segmentDistance(foot, a, b)
			assert(d < 0.01, ("%s is not at its %.0f setback (off the centreline by %.2f)"):format(lot.id, setback, d))
			-- and wholly alongside its own segment, not hanging past either end
			local s = (lot.centre - a):Dot(along)
			assert(s - lot.size.X / 2 > 0 and s + lot.size.X / 2 < (b - a).Magnitude, lot.id .. " overhangs the end of its street segment")
		end
	end
end

function T.lotsDoNotOverlapEachOther()
	local lots = TownFrontage.generate()
	local grown: { { Vector3 } } = {}
	for i, lot in lots do
		grown[i] = TownFrontage.lotCorners(lot, 1) -- so neighbours keep a real gap, not a shared wall
	end
	for i = 1, #lots do
		local a = lots[i]
		local reachA = a.size.X + a.size.Z
		for j = i + 1, #lots do
			local b = lots[j]
			local reach = reachA + b.size.X + b.size.Z
			if math.abs(a.centre.X - b.centre.X) < reach and math.abs(a.centre.Z - b.centre.Z) < reach then
				assert(not polygonsOverlap(grown[i], grown[j]), ("%s overlaps %s"):format(a.id, b.id))
			end
		end
	end
end

function T.lotsKeepOffEveryRoadCorridor()
	for _, lot in TownFrontage.generate() do
		local points = outline(TownFrontage.lotCorners(lot), 5)
		local reach = (lot.size.X + lot.size.Z) / 2
		for _, road in TownLayout.ROADS do
			-- carriageway + pavement; a lane has no pavement of its own
			local clear = road.width / 2 + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH)
			for s = 1, #road.points - 1 do
				local a, b = road.points[s], road.points[s + 1]
				if
					lot.centre.X < math.min(a.X, b.X) - clear - reach
					or lot.centre.X > math.max(a.X, b.X) + clear + reach
					or lot.centre.Z < math.min(a.Z, b.Z) - clear - reach
					or lot.centre.Z > math.max(a.Z, b.Z) + clear + reach
				then
					continue
				end
				for _, p in points do
					local d = TownLayout.segmentDistance(p, a, b)
					assert(d > clear - EPS, ("%s is %.1f from %s (needs %.0f)"):format(lot.id, d, road.name, clear))
				end
			end
		end
	end
end

function T.lotsKeepOffRiverRailAndStation()
	local riverClear = TownLayout.RIVER.width / 2 + 20
	local railClear = TownLayout.RAIL.width / 2 + 10
	local station = TownLayout.RAIL.station
	local stationCorners = boxCorners(station :: any, 0)
	for _, lot in TownFrontage.generate() do
		local corners = TownFrontage.lotCorners(lot)
		for _, p in outline(corners, 5) do
			local d = TownLayout.distanceToPolyline(p, TownLayout.RIVER.points)
			assert(d > riverClear, ("%s is %.1f from the river"):format(lot.id, d))
			d = TownLayout.distanceToPolyline(p, TownLayout.RAIL.points)
			assert(d > railClear, ("%s is %.1f from the railway"):format(lot.id, d))
		end
		assert(not polygonsOverlap(corners, stationCorners), lot.id .. " stands on the station")
	end
end

function T.lotsKeepOffRoundaboutsSquareHeadsPlotsAndExtent()
	local pave = TownLayout.PAVEMENT_WIDTH
	local circles: { { name: string, centre: Vector3, radius: number } } = {}
	for _, r in TownLayout.ROUNDABOUTS do
		table.insert(circles, { name = r.name, centre = r.centre, radius = r.radius + pave })
	end
	table.insert(circles, { name = "Market Square", centre = TownLayout.SQUARE.centre, radius = TownLayout.SQUARE.radius + pave })
	for _, road in TownLayout.ROADS do
		if road.head then
			table.insert(circles, { name = road.name .. " turning head", centre = road.points[#road.points], radius = TownLayout.HEAD_RADIUS })
		end
	end
	local plotReach = TownLayout.PLOT_SIZE / 2 + 20
	local e = TownLayout.EXTENT
	for _, lot in TownFrontage.generate() do
		for _, c in circles do
			local d = lotPointDistance(lot, c.centre)
			assert(d > c.radius, ("%s is %.1f from the middle of %s (needs %.0f)"):format(lot.id, d, c.name, c.radius))
		end
		for _, p in outline(TownFrontage.lotCorners(lot), 5) do
			assert(p.X > e.minX and p.X < e.maxX and p.Z > e.minZ and p.Z < e.maxZ, lot.id .. " leaves the town extent")
			for i = 1, #TownLayout.PLOTS do
				local l = TownLayout.plotCFrame(i):PointToObjectSpace(p)
				assert(math.abs(l.X) > plotReach or math.abs(l.Z) > plotReach, ("%s is within 20 of plot %d"):format(lot.id, i))
			end
		end
	end
end

function T.lotsKeepOffSpecialsBusStopsAndLandmarks()
	local specials: { { name: string, corners: { Vector3 } } } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(specials, { name = district.name .. " " .. block.use, corners = boxCorners(block, 0) })
		end
	end
	for _, lot in TownFrontage.generate() do
		local corners = TownFrontage.lotCorners(lot)
		for _, special in specials do
			assert(not polygonsOverlap(corners, special.corners), ("%s overlaps the %s"):format(lot.id, special.name))
		end
		for _, stop in TownLayout.BUS_STOPS do
			local d = lotPointDistance(lot, stop.position)
			assert(d > 12, ("%s is %.1f from the %s bus stop"):format(lot.id, d, stop.name))
		end
		for _, landmark in TownLayout.LANDMARKS do
			local d = lotPointDistance(lot, landmark.position)
			assert(d > 30, ("%s is %.1f from %s"):format(lot.id, d, landmark.name))
		end
	end
end

-- The point of v3: nothing stands behind anything else. Every home is within one
-- setback of a street, and every plot has housing on its doorstep.
function T.everyFrontedStreetGotSomething()
	local counts: { [string]: number } = {}
	for _, lot in TownFrontage.generate() do
		counts[lot.street] = (counts[lot.street] or 0) + 1
	end
	for _, road in TownLayout.ROADS do
		if road.front ~= "none" then
			assert((counts[road.name] or 0) >= 1, road.name .. " fronts nothing: fix its line or set front = \"none\"")
		else
			assert(counts[road.name] == nil, road.name .. " has front = \"none\" but got lots")
		end
	end
end

-- Marcel, 2026-09-20: a turning circle belongs to a semis / detached close. A terraced
-- street joins another street or stops at a terrace across its end, and no street end is
-- left bare: a close has lots round its circle, a blunt end has its row.
local BARE_ENDS = {
	-- two flats streets whose circles are 92 apart on the waterfront: the blocks along them close the view
	["Lune Street"] = true,
	["Marina Way"] = true,
}
local TERRACED_HEADS = {
	["Riverside Road"] = true, -- TEMP: ends at Riverside Park until Marcel picks between this and a smaller park
}

function T.everyStreetEndIsBuiltRound()
	local closing: { [string]: number } = {}
	for _, lot in TownFrontage.generate() do
		if lot.closesStreet then
			closing[lot.street] = (closing[lot.street] or 0) + 1
		end
	end
	for _, road in TownLayout.ROADS do
		if not (road.head or road.closed) then
			continue
		end
		assert(not (road.head and road.closed), road.name .. " is both a close and a blunt end")
		local last = road.points[#road.points]
		local use = road.use
		if road.useAt then
			use = (TownFrontage.RULES[road.useAt](last.X, last.Z))
		end
		if road.closed then
			assert(use == "terraced row", road.name .. " has a blunt end but is not a terraced street")
			assert(closing[road.name] == 1, road.name .. " has no terrace across its blunt end")
		else
			assert(use ~= "terraced row" or TERRACED_HEADS[road.name], road.name .. " is a terraced street with a turning circle")
			assert(BARE_ENDS[road.name] or (closing[road.name] or 0) >= 1, road.name .. " has nothing round its turning circle")
		end
	end
end

function T.everyRoadRuleAndUseIsKnown()
	for _, road in TownLayout.ROADS do
		if road.front == "none" then
			continue
		end
		assert((road.use ~= nil) ~= (road.useAt ~= nil), road.name .. " needs exactly one of use / useAt")
		if road.use then
			assert(TownFrontage.TYPES[road.use], road.name .. " has an unknown use " .. road.use)
			assert(road.district, road.name .. " has a use but no district")
		else
			assert(TownFrontage.RULES[road.useAt :: string], road.name .. " names an unknown rule " .. tostring(road.useAt))
		end
	end
end

return T
