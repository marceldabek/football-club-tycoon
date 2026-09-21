--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)

local T = {}

local EPS = 1e-3

local function insideExtent(p: Vector3): boolean
	local e = TownLayout.EXTENT
	return p.X >= e.minX - EPS and p.X <= e.maxX + EPS and p.Z >= e.minZ - EPS and p.Z <= e.maxZ + EPS
end

local function nearestRoadDistance(p: Vector3): number
	local best = math.huge
	for _, road in TownLayout.ROADS do
		best = math.min(best, TownLayout.distanceToPolyline(p, road.points))
	end
	return best
end

-- Points every `step` studs along a polyline, ends included.
local function samplePolyline(points: { Vector3 }, step: number): { Vector3 }
	local out = { points[1] }
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / step))
		for k = 1, n do
			table.insert(out, a:Lerp(b, k / n))
		end
	end
	return out
end

local function plotOutline(i: number, step: number): { Vector3 }
	local corners = TownLayout.plotCorners(i)
	table.insert(corners, corners[1])
	return samplePolyline(corners, step)
end

-- Separating-axis test for two convex polygons in XZ. Touching counts as apart.
local function project(poly: { Vector3 }, ax: number, az: number): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, p in poly do
		local d = p.X * ax + p.Z * az
		lo = math.min(lo, d)
		hi = math.max(hi, d)
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

function T.exactlyFourPlots()
	assert(#TownLayout.PLOTS == 4, "expected 4 plots, got " .. #TownLayout.PLOTS)
	for i, plot in TownLayout.PLOTS do
		assert(plot.index == i, ("plot at slot %d says index %d"):format(i, plot.index))
		assert(plot.yaw % 90 == 0, plot.name .. " yaw is not a multiple of 90")
	end
end

function T.plotsInsideExtent()
	for i = 1, #TownLayout.PLOTS do
		for _, c in TownLayout.plotCorners(i) do
			assert(insideExtent(c), ("plot %d corner %s outside the town extent"):format(i, tostring(c)))
		end
	end
end

function T.plotsDoNotOverlap()
	for i = 1, #TownLayout.PLOTS do
		for j = i + 1, #TownLayout.PLOTS do
			for _, c in TownLayout.plotCorners(i) do
				assert(not TownLayout.pointInPlot(c, j), ("plot %d corner inside plot %d"):format(i, j))
			end
			for _, c in TownLayout.plotCorners(j) do
				assert(not TownLayout.pointInPlot(c, i), ("plot %d corner inside plot %d"):format(j, i))
			end
			assert(
				not polygonsOverlap(TownLayout.plotCorners(i), TownLayout.plotCorners(j)),
				("plots %d and %d overlap"):format(i, j)
			)
		end
	end
end

function T.plotsClearOfRiver()
	local clearance = TownLayout.RIVER.width / 2 + 20
	for i, plot in TownLayout.PLOTS do
		local points = plotOutline(i, 20)
		table.insert(points, plot.centre)
		for _, p in points do
			local d = TownLayout.distanceToPolyline(p, TownLayout.RIVER.points)
			assert(d > clearance, ("plot %d point %s is %.0f from the river"):format(i, tostring(p), d))
		end
	end
end

function T.plotsClearOfRailAndRoads()
	for i = 1, #TownLayout.PLOTS do
		for _, p in samplePolyline(TownLayout.RAIL.points, 10) do
			assert(not TownLayout.pointInPlot(p, i), ("rail runs through plot %d at %s"):format(i, tostring(p)))
		end
		for _, road in TownLayout.ROADS do
			for _, p in samplePolyline(road.points, 10) do
				assert(not TownLayout.pointInPlot(p, i), ("%s runs through plot %d"):format(road.name, i))
			end
		end
	end
end

function T.noDistrictBlockInsideAPlot()
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			for i = 1, #TownLayout.PLOTS do
				assert(
					not TownLayout.pointInPlot(block.centre, i),
					("%s %s block is inside plot %d"):format(district.name, block.use, i)
				)
			end
		end
	end
end

function T.plotBusStopsAreOnARoadOutsideThePlot()
	for i, plot in TownLayout.PLOTS do
		local d = nearestRoadDistance(plot.busStop)
		assert(d <= 120, ("plot %d bus stop is %.0f from the nearest road"):format(i, d))
		assert(not TownLayout.pointInPlot(plot.busStop, i), ("plot %d bus stop is inside the plot"):format(i))
	end
end

-- X6: the access lane no longer meets the middle of the entrance side; it ends
-- at the vehicle gate (PlotGrounds: plot-local x = -380, z 60..100), so check
-- the gate point 10 outside the wall instead of the side centre.
function T.plotEntranceFacesAnAccessRoad()
	for i in TownLayout.PLOTS do
		local gate = TownLayout.plotCFrame(i) * TownLayout.PLOT_LANE_END
		local d = nearestRoadDistance(gate)
		assert(d <= 1, ("plot %d vehicle gate is %.0f from a road"):format(i, d))
		assert(not TownLayout.pointInPlot(gate, i), ("plot %d lane end is inside the plot"):format(i))
	end
end

local function roadNamed(name: string): TownLayout.Road?
	for _, road in TownLayout.ROADS do
		if road.name == name then
			return road
		end
	end
	return nil
end

function T.plotLanesRunFromTheRingToTheVehicleGate()
	local ring = roadNamed("Ring Road")
	assert(ring, "no Ring Road")
	for i, plot in TownLayout.PLOTS do
		local lane = roadNamed(plot.name .. " Lane")
		assert(lane, "no lane for " .. plot.name)
		local gate = TownLayout.plotCFrame(i) * TownLayout.PLOT_LANE_END
		local last = lane.points[#lane.points]
		assert(
			math.abs(last.X - gate.X) < EPS and math.abs(last.Z - gate.Z) < EPS,
			("%s ends at %s, gate is %s"):format(lane.name, tostring(last), tostring(gate))
		)
		local first = lane.points[1]
		local joined = TownLayout.distanceToPolyline(first, ring.points) <= ring.width / 2
		-- v3: Plot 3 sits outside the ring in Westdale, so its lane leaves a main road instead
		for _, road in TownLayout.ROADS do
			if road.kind == "main" and TownLayout.distanceToPolyline(first, road.points) <= road.width / 2 then
				joined = true
			end
		end
		for _, r in TownLayout.ROUNDABOUTS do
			local offset = first - r.centre
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= r.radius then
				joined = true
			end
		end
		assert(joined, lane.name .. " does not start on the ring road, a roundabout or a main road")
		local stop = plot.busStop
		assert(TownLayout.distanceToPolyline(stop, lane.points) <= 30, plot.name .. " bus stop is not beside its lane")
		assert(Vector3.new(stop.X - gate.X, 0, stop.Z - gate.Z).Magnitude <= 60, plot.name .. " bus stop is far from the gate")
		local listed = false
		for _, busStop in TownLayout.BUS_STOPS do
			if busStop.name == plot.name then
				listed = (busStop.position - stop).Magnitude < EPS
			end
		end
		assert(listed, plot.name .. " BUS_STOPS entry does not match PLOTS busStop")
	end
end

-- District blocks (v3: the hand-placed specials only) ---------------------------
-- v3 allows a special at any yaw (the Hollingford river meadow sits at 45 on its
-- 45-degree estate), so every check works on the rotated footprint.

type Placed = { district: string, block: TownLayout.Box, frame: CFrame, corners: { Vector3 } }

local function blockCorners(frame: CFrame, size: Vector3, grow: number): { Vector3 }
	local hx, hz = size.X / 2 + grow, size.Z / 2 + grow
	return {
		frame * Vector3.new(-hx, 0, -hz),
		frame * Vector3.new(hx, 0, -hz),
		frame * Vector3.new(hx, 0, hz),
		frame * Vector3.new(-hx, 0, hz),
	}
end

local function allBlocks(): { Placed }
	local out: { Placed } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			local frame = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
			table.insert(out, { district = district.name, block = block, frame = frame, corners = blockCorners(frame, block.size, 0) })
		end
	end
	return out
end

-- The block's centre plus its outline every 5 studs, at ground level.
local function blockSamples(p: Placed): { Vector3 }
	local corners = table.clone(p.corners)
	table.insert(corners, corners[1])
	local out = samplePolyline(corners, 5)
	table.insert(out, p.frame.Position)
	return out
end

local function blockPointDistance(p: Placed, point: Vector3): number
	local l = p.frame:PointToObjectSpace(Vector3.new(point.X, 0, point.Z))
	local dx = math.max(math.abs(l.X) - p.block.size.X / 2, 0)
	local dz = math.max(math.abs(l.Z) - p.block.size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function describe(p: Placed): string
	local c, s = p.block.centre, p.block.size
	return ("%s %s at (%.0f, %.0f) %.0f x %.0f yaw %.0f"):format(p.district, p.block.use, c.X, c.Z, s.X, s.Z, p.block.yaw)
end

-- A building may stand on a flat ground piece (the bandstand on the park lawn).
local function standsOn(ground: Placed, other: Placed): boolean
	if ground.block.size.Y > 2 or other.block.size.Y <= 2 then
		return false
	end
	for _, c in other.corners do
		if blockPointDistance(ground, c) > 0 then
			return false
		end
	end
	return true
end

-- v1 asserted >= 400 authored blocks. In v3 the authored blocks are only the
-- specials and the town is filled by TownFrontage, so "built up" means both.
function T.townIsBuiltUp()
	local specials = #allBlocks()
	assert(specials >= 30, ("only %d special blocks; the town has lost its civic buildings"):format(specials))
	local lots = #TownFrontage.generate()
	assert(specials + lots >= 700, ("only %d blocks + lots; the town reads as empty grass"):format(specials + lots))
end

-- v3: nothing generated is authored. If a terrace or a shop parade turns up in
-- DISTRICTS it will be built twice (once here, once by TownFrontage).
function T.districtsHoldOnlySpecials()
	for _, placed in allBlocks() do
		assert(TownFrontage.TYPES[placed.block.use] == nil or placed.block.use == "shops", describe(placed) .. " is a generated use; it belongs to TownFrontage")
		assert(placed.block.centre.Y == placed.block.size.Y / 2, describe(placed) .. " does not sit on the ground")
	end
end

function T.districtBlocksDoNotOverlap()
	local blocks = allBlocks()
	for i = 1, #blocks do
		-- 1-stud tolerance: faces that touch or graze are fine
		local a = blockCorners(blocks[i].frame, blocks[i].block.size, -0.5)
		for j = i + 1, #blocks do
			local b = blockCorners(blocks[j].frame, blocks[j].block.size, -0.5)
			if polygonsOverlap(a, b) then
				assert(
					standsOn(blocks[i], blocks[j]) or standsOn(blocks[j], blocks[i]),
					("%s overlaps %s"):format(describe(blocks[i]), describe(blocks[j]))
				)
			end
		end
	end
end

function T.districtBlocksClearOfRoads()
	for _, placed in allBlocks() do
		local reach = (placed.block.size.X + placed.block.size.Z) / 2
		local c = placed.block.centre
		local samples: { Vector3 }? = nil
		for _, road in TownLayout.ROADS do
			local clear = road.width / 2 + TownLayout.PAVEMENT_WIDTH - 0.5
			for i = 1, #road.points - 1 do
				local a, b = road.points[i], road.points[i + 1]
				if
					math.min(a.X, b.X) - clear - reach > c.X
					or math.max(a.X, b.X) + clear + reach < c.X
					or math.min(a.Z, b.Z) - clear - reach > c.Z
					or math.max(a.Z, b.Z) + clear + reach < c.Z
				then
					continue
				end
				local points = samples or blockSamples(placed)
				samples = points
				for _, p in points do
					local d = TownLayout.segmentDistance(p, a, b)
					assert(d > clear, ("%s is %.1f from %s"):format(describe(placed), d, road.name))
				end
			end
		end
	end
end

function T.districtBlocksClearOfRiver()
	local clear = TownLayout.RIVER.width / 2 + 20
	for _, placed in allBlocks() do
		if placed.block.use == "marina" then
			continue -- the marina basin opens onto the river by design
		end
		for _, p in blockSamples(placed) do
			local d = TownLayout.distanceToPolyline(p, TownLayout.RIVER.points)
			assert(d > clear, ("%s is %.1f from the river"):format(describe(placed), d))
		end
	end
end

function T.districtBlocksClearOfRailPlotsStopsAndLandmarks()
	local railClear = TownLayout.RAIL.width / 2 + 10
	local plotReach = TownLayout.PLOT_SIZE / 2 + 20
	local circles: { { name: string, centre: Vector3, radius: number } } = {}
	for _, r in TownLayout.ROUNDABOUTS do
		table.insert(circles, { name = r.name, centre = r.centre, radius = r.radius + TownLayout.PAVEMENT_WIDTH })
	end
	local square = TownLayout.SQUARE
	table.insert(circles, { name = square.name, centre = square.centre, radius = square.radius + TownLayout.PAVEMENT_WIDTH })
	-- v3: cul-de-sac turning heads are road too
	for _, road in TownLayout.ROADS do
		if road.head then
			table.insert(circles, { name = road.name .. " turning head", centre = road.points[#road.points], radius = TownLayout.HEAD_RADIUS })
		end
	end
	for _, placed in allBlocks() do
		for _, p in blockSamples(placed) do
			local d = TownLayout.distanceToPolyline(p, TownLayout.RAIL.points)
			assert(d > railClear, ("%s is %.1f from the railway"):format(describe(placed), d))
			for i = 1, #TownLayout.PLOTS do
				local localP = TownLayout.plotCFrame(i):PointToObjectSpace(p)
				assert(
					math.abs(localP.X) > plotReach or math.abs(localP.Z) > plotReach,
					("%s is within 20 of plot %d"):format(describe(placed), i)
				)
			end
		end
		for _, c in circles do
			assert(blockPointDistance(placed, c.centre) > c.radius, describe(placed) .. " is on " .. c.name)
		end
		for _, stop in TownLayout.BUS_STOPS do
			local d = blockPointDistance(placed, stop.position)
			assert(d > 12, ("%s is %.1f from the %s bus stop"):format(describe(placed), d, stop.name))
		end
		for _, landmark in TownLayout.LANDMARKS do
			local d = blockPointDistance(placed, landmark.position)
			if placed.block.use == "church" and d == 0 then
				continue -- the church nave stands under its own spire
			end
			assert(d > 30, ("%s is %.1f from %s"):format(describe(placed), d, landmark.name))
		end
	end
end

-- v1 pinned >= 8 authored blocks here. The rows are generated now, so pin the
-- generated ones: the district must still read as streets of terraces.
function T.millStreetTerracesKeepTheirRows()
	local rows = 0
	for _, lot in TownFrontage.lotsByDistrict()["Mill Street Terraces"] or {} do
		if lot.use == "terraced row" then
			rows += 1
		end
	end
	assert(rows >= 30, ("Mill Street Terraces has only %d terraced rows"):format(rows))
end

-- Roads (v3) ------------------------------------------------------------------------

-- The bought road kit only tiles straight and 45-degree runs.
function T.everyRoadSegmentIsAxisAlignedOr45()
	for _, road in TownLayout.ROADS do
		for i = 1, #road.points - 1 do
			local d = road.points[i + 1] - road.points[i]
			local dx, dz = math.abs(d.X), math.abs(d.Z)
			assert(d.Y == 0 and dx + dz > 0, ("%s segment %d is degenerate"):format(road.name, i))
			assert(
				dx < EPS or dz < EPS or math.abs(dx - dz) < EPS,
				("%s segment %d runs (%.0f, %.0f): not axis-aligned or 45 degrees"):format(road.name, i, d.X, d.Z)
			)
		end
	end
end

function T.roadFieldsAreValid()
	local widths = { ring = 32, main = 26, residential = 20, lane = 20, alley = 10 }
	local districts: { [string]: boolean } = {}
	for _, district in TownLayout.DISTRICTS do
		assert(not districts[district.name], "duplicate district " .. district.name)
		districts[district.name] = true
	end
	local seen: { [string]: boolean } = {}
	for _, road in TownLayout.ROADS do
		assert(not seen[road.name], "duplicate road name " .. road.name)
		seen[road.name] = true
		assert(widths[road.kind] == road.width, ("%s is a %s but %d wide"):format(road.name, road.kind, road.width))
		assert(road.front == "both" or road.front == "left" or road.front == "right" or road.front == "none", road.name .. " front")
		if road.district then
			assert(districts[road.district], ("%s is in %s, which is not a district"):format(road.name, road.district))
		end
		if road.kind == "ring" or road.kind == "lane" then
			assert(road.front == "none", road.name .. " must not be fronted")
		end
	end
	assert(#TownLayout.ROADS >= 90, "v3 has 94 roads; got " .. #TownLayout.ROADS)
end

-- A turning head is a dead end: nothing else may join it, and it keeps clear of
-- the river, the rail, the plots and every other road.
function T.turningHeadsAreRealDeadEnds()
	local heads = 0
	local reach = TownLayout.HEAD_RADIUS
	for _, road in TownLayout.ROADS do
		if not road.head then
			continue
		end
		heads += 1
		-- every street is one kit size now, so a main road can carry the CulDeSac piece too
		-- (Riverside Road ends at Riverside Park: no kit junction fits at East Bridge)
		assert(road.kind == "residential" or road.kind == "main", road.name .. " has a turning head but is not a street")
		local h = road.points[#road.points]
		for _, other in TownLayout.ROADS do
			if other ~= road then
				local d = TownLayout.distanceToPolyline(h, other.points)
				local need = reach + other.width / 2 + TownLayout.PAVEMENT_WIDTH
				assert(d > need, ("%s turning head is %.0f from %s (needs %.0f)"):format(road.name, d, other.name, need))
			end
		end
		assert(TownLayout.distanceToPolyline(h, TownLayout.RIVER.points) > reach + TownLayout.RIVER.width / 2 + 20, road.name .. " head is at the river")
		assert(TownLayout.distanceToPolyline(h, TownLayout.RAIL.points) > reach + TownLayout.RAIL.width / 2 + 10, road.name .. " head is on the railway")
		local e = TownLayout.EXTENT
		assert(h.X - reach > e.minX and h.X + reach < e.maxX and h.Z - reach > e.minZ and h.Z + reach < e.maxZ, road.name .. " head leaves the extent")
		local plotReach = TownLayout.PLOT_SIZE / 2 + reach
		for i = 1, #TownLayout.PLOTS do
			local l = TownLayout.plotCFrame(i):PointToObjectSpace(h)
			assert(math.abs(l.X) > plotReach or math.abs(l.Z) > plotReach, ("%s head is inside plot %d"):format(road.name, i))
		end
	end
	assert(heads >= 10, "v3 has cul-de-sac closes; only " .. heads .. " turning heads")
end

-- Every road end either joins another road / roundabout, leaves town at the
-- extent, reaches a plot gate, or is a turning head. v3 fixed Westdale's streets
-- stopping dead at the railway; this keeps it fixed.
-- KNOWN dead ends carried from the approved drawing are listed, so a NEW one fails.
-- Do not add to this list to get a test green: give a close a turning head (head)
-- and a terraced street a terrace across its end (closed).
local KNOWN_DEAD_ENDS = {
	["Station Road"] = true, -- ends in the station car park (X51)
	["Quay Street"] = true, -- ends at the pub and cafes on the waterfront
	["Wharf Road"] = true, -- ends at the last yard on the river bank
	["Moss Lane"] = true, -- both ends: a back lane between Greenbridge Road and the river
	["Lune View"] = true, -- its west end stops short of the ring; the east end has the head
	["Fellmonger Street"] = true, -- starts blind behind Lunebank Road
	-- junction moves (docs/TOWN_V3_JUNCTION_MOVES.md): their west ends stop short of the ring
	-- road, where a T piece cannot fit beside the ring's bend (as Lune View already does)
	["Cooper Street"] = true,
	["Signal Street"] = true,
	-- these eight stop at the central railway, as they did in v1 (handoffs: Lane A question 2)
	["Weaver Street"] = true,
	["Elm Grove"] = true,
	["Signal Street"] = true,
	["Lock Street"] = true,
	["Lune Street"] = true,
	["Viaduct Road"] = true,
	["Weir Road"] = true,
	["Fuller Street"] = true,
}

function T.roadsDoNotStopDead()
	local e = TownLayout.EXTENT
	for _, road in TownLayout.ROADS do
		if (road.points[1] - road.points[#road.points]).Magnitude < EPS then
			continue -- a closed loop (the ring) has no ends
		end
		for _, which in { 1, #road.points } do
			local p = road.points[which]
			if which == #road.points and (road.head or road.closed or road.kind == "lane") then
				continue
			end
			if road.kind == "alley" then
				continue -- a back alley may stop at the end of its terrace
			end
			if math.abs(p.X - e.minX) < EPS or math.abs(p.X - e.maxX) < EPS or math.abs(p.Z - e.minZ) < EPS or math.abs(p.Z - e.maxZ) < EPS then
				continue
			end
			local joined = false
			for _, other in TownLayout.ROADS do
				if other ~= road and TownLayout.distanceToPolyline(p, other.points) <= other.width / 2 + EPS then
					joined = true
					break
				end
			end
			for _, r in TownLayout.ROUNDABOUTS do
				if Vector3.new(p.X - r.centre.X, 0, p.Z - r.centre.Z).Magnitude <= r.radius then
					joined = true
				end
			end
			local square = TownLayout.SQUARE
			if Vector3.new(p.X - square.centre.X, 0, p.Z - square.centre.Z).Magnitude <= square.radius + EPS then
				joined = true
			end
			assert(joined or KNOWN_DEAD_ENDS[road.name], ("%s stops dead at %s"):format(road.name, tostring(p)))
		end
	end
end

function T.roundaboutsSitOnTheirRoads()
	local names: { [string]: boolean } = {}
	for _, r in TownLayout.ROUNDABOUTS do
		names[r.name] = true
		local arms = 0
		for _, road in TownLayout.ROADS do
			if TownLayout.distanceToPolyline(r.centre, road.points) < 1 then
				arms += 1
			end
		end
		assert(arms >= 2, ("%s has %d roads through its centre"):format(r.name, arms))
	end
	assert(names["Lunebank Roundabout"] and not names["Plot 3 Roundabout"], "v3 renamed Plot 3 Roundabout to Lunebank Roundabout")
end

-- X51 / X71: the taxi lay-by is cut into Station Road's station-side pavement.
function T.stationLaybyLiesInStationRoadsPavement()
	local layby = TownLayout.STATION_LAYBY
	local road = roadNamed("Station Road")
	assert(road, "no Station Road")
	local station = TownLayout.RAIL.station
	local inner, outer = road.width / 2, road.width / 2 + TownLayout.PAVEMENT_WIDTH
	for _, p in { layby.from, layby.to } do
		local d = TownLayout.distanceToPolyline(p, road.points)
		assert(d - layby.width / 2 >= inner - EPS and d + layby.width / 2 <= outer + EPS, ("lay-by end %s is %.1f from Station Road, outside its pavement"):format(tostring(p), d))
		assert(math.abs(p.X - station.centre.X) <= station.size.X / 2, "lay-by runs past the station building")
		local roadZ = p.Z + (if p.Z > station.centre.Z then d else -d)
		assert(math.abs(p.Z - station.centre.Z) < math.abs(roadZ - station.centre.Z), "lay-by is on the far side of Station Road from the station")
	end
end

-- Every bus stop stands on the pavement of a road, not in it and not in a field.
function T.busStopsStandOnAPavement()
	for _, stop in TownLayout.BUS_STOPS do
		local best, bestRoad = math.huge, nil :: TownLayout.Road?
		for _, road in TownLayout.ROADS do
			local d = TownLayout.distanceToPolyline(stop.position, road.points) - road.width / 2
			if d < best then
				best, bestRoad = d, road
			end
		end
		assert(bestRoad, "no roads")
		assert(best >= 0, ("%s bus stop is in %s's carriageway"):format(stop.name, (bestRoad :: TownLayout.Road).name))
		assert(best <= 14, ("%s bus stop is %.0f from the kerb of %s"):format(stop.name, best, (bestRoad :: TownLayout.Road).name))
		assert(stop.yaw % 90 == 0, stop.name .. " bus stop yaw")
	end
end

function T.roadPointsInsideExtent()
	for _, road in TownLayout.ROADS do
		assert(#road.points >= 2, road.name .. " needs at least two points")
		for _, p in road.points do
			assert(insideExtent(p), ("%s point %s outside the extent"):format(road.name, tostring(p)))
		end
	end
end

function T.riverCrossesTownWestToEast()
	local points = TownLayout.RIVER.points
	local e = TownLayout.EXTENT
	assert(math.abs(points[1].X - e.minX) < EPS, "river does not start on the west edge")
	assert(math.abs(points[#points].X - e.maxX) < EPS, "river does not end on the east edge")
	for i, p in points do
		assert(insideExtent(p), "river point " .. i .. " outside the extent")
		if i > 1 then
			assert(p.X > points[i - 1].X, "river doubles back westward at point " .. i)
		end
	end
end

function T.roadBridgesCrossTheRiver()
	local half = TownLayout.RIVER.width / 2
	local roadBridges = 0
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind ~= "road" then
			continue
		end
		roadBridges += 1
		local a, b = TownLayout.riverSide(bridge.from), TownLayout.riverSide(bridge.to)
		assert(a * b < 0, bridge.name .. " ends are on the same side of the river")
		assert(math.abs(a) > half and math.abs(b) > half, bridge.name .. " ends in the water")
		for _, p in { bridge.from, bridge.to } do
			assert(nearestRoadDistance(p) < 1, bridge.name .. " end is not on a road")
		end
	end
	assert(roadBridges == 3, "expected 3 road bridges, got " .. roadBridges)
end

function T.bridgeRiseRampsUpThenStaysLevel()
	local b: TownLayout.Bridge = { name = "T", kind = "road", from = Vector3.new(0, 0, 0), to = Vector3.new(0, 0, 180), width = 26 }
	local rise, ramp = TownLayout.BRIDGE_RISE, TownLayout.BRIDGE_RAMP
	assert(TownLayout.bridgeRise(b, 0) == 0 and TownLayout.bridgeRise(b, 180) == 0, "ends at street level")
	assert(math.abs(TownLayout.bridgeRise(b, ramp / 2) - rise / 2) < 1e-6, "half way up the ramp")
	assert(TownLayout.bridgeRise(b, 90) == rise, "level in the middle")
	assert(math.abs(TownLayout.bridgeRise(b, 180 - ramp / 4) - rise / 4) < 1e-6, "down-ramp mirrors")
	assert(TownLayout.bridgeRise(b, -5) == 0 and TownLayout.bridgeRise(b, 200) == 0, "off the ends")
	local rail = table.clone(b)
	rail.kind = "rail"
	assert(TownLayout.bridgeRise(rail, 90) == 0, "rail bridges stay flat")

	local sections = TownLayout.bridgeSections(b)
	assert(#sections == 3, "ramp, level, ramp")
	assert(sections[1].s0 == 0 and sections[1].s1 == ramp and sections[1].rise1 == rise, "up-ramp")
	assert(sections[2].rise0 == rise and sections[2].rise1 == rise, "level")
	assert(sections[3].s1 == 180 and sections[3].rise1 == 0, "down-ramp")
	local short = table.clone(b)
	short.to = Vector3.new(0, 0, 60)
	local shortSections = TownLayout.bridgeSections(short)
	assert(#shortSections == 2 and shortSections[1].s1 == 30, "a short bridge is two ramps meeting in the middle")

	local along, across = TownLayout.bridgeAlong(b, Vector3.new(5, 3, 40))
	assert(math.abs(along - 40) < 1e-6 and math.abs(across - 5) < 1e-6, "along/across")
end

function T.realRoadBridgesKeepTheWaterUnderTheLevelPart()
	local half = TownLayout.RIVER.width / 2
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind ~= "road" then
			continue
		end
		local length = TownLayout.bridgeLength(bridge)
		for s = 0, length, 1 do
			local p = bridge.from:Lerp(bridge.to, s / length)
			if TownLayout.distanceToPolyline(p, TownLayout.RIVER.points) <= half then
				assert(TownLayout.bridgeRise(bridge, s) == TownLayout.BRIDGE_RISE, bridge.name .. " ramps over water at " .. s)
			end
		end
	end
end

function T.railViaductCrossesTheRiver()
	local found = false
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind == "rail" then
			found = true
			assert(TownLayout.riverSide(bridge.from) * TownLayout.riverSide(bridge.to) < 0, bridge.name .. " does not cross")
			assert(TownLayout.distanceToPolyline(bridge.from, TownLayout.RAIL.points) < 1, bridge.name .. " is off the line")
			assert(TownLayout.distanceToPolyline(bridge.to, TownLayout.RAIL.points) < 1, bridge.name .. " is off the line")
		end
	end
	assert(found, "no rail bridge")
end

function T.churchNearTheSquare()
	local church: { name: string, position: Vector3, height: number }? = nil
	for _, landmark in TownLayout.LANDMARKS do
		if landmark.name:find("Church") then
			church = landmark
		end
	end
	assert(church, "no church landmark")
	local offset = church.position - TownLayout.SQUARE.centre
	local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
	assert(d <= 500, ("church is %.0f from the square"):format(d))
end

function T.helpersBehave()
	local a, b = Vector3.new(0, 0, 0), Vector3.new(100, 0, 0)
	assert(math.abs(TownLayout.segmentDistance(Vector3.new(50, 9, 30), a, b) - 30) < EPS, "segment middle")
	assert(math.abs(TownLayout.segmentDistance(Vector3.new(130, 0, 40), a, b) - 50) < EPS, "segment end")
	local poly = { a, b, Vector3.new(100, 0, 100) }
	assert(math.abs(TownLayout.distanceToPolyline(Vector3.new(120, 0, 60), poly) - 20) < EPS, "polyline")
	for i, plot in TownLayout.PLOTS do
		assert(TownLayout.pointInPlot(plot.centre, i), "plot centre not in its own plot")
		assert(not TownLayout.pointInPlot(plot.centre + Vector3.new(TownLayout.PLOT_SIZE, 0, 0), i), "far point in plot")
	end
end

-- Every string in the module is non-empty and uses Rivermere names only.
function T.namesPresentAndNoOldTownName()
	local banned = { "River" .. "dale", "Da" .. "le" }
	local seen: { [any]: boolean } = {}
	local function scan(value: any, path: string)
		if type(value) == "string" then
			assert(#value > 0, "empty string at " .. path)
			for _, word in banned do
				assert(not value:find(word, 1, true), ("%q at %s"):format(value, path))
			end
			assert(not value:lower():find(("River" .. "dale"):lower(), 1, true), ("%q at %s"):format(value, path))
		elseif type(value) == "table" and not seen[value] then
			seen[value] = true
			for k, v in value do
				scan(k, path .. "." .. tostring(k))
				scan(v, path .. "." .. tostring(k))
			end
		end
	end
	scan(TownLayout, "TownLayout")

	local named: { { name: string } } = {}
	for _, list in { TownLayout.PLOTS, TownLayout.ROADS, TownLayout.BRIDGES, TownLayout.DISTRICTS } :: { { any } } do
		for _, item in list do
			table.insert(named, item)
		end
	end
	for _, list in { TownLayout.LANDMARKS, TownLayout.BUS_STOPS, TownLayout.ROUNDABOUTS } :: { { any } } do
		for _, item in list do
			table.insert(named, item)
		end
	end
	table.insert(named, TownLayout.RIVER)
	table.insert(named, TownLayout.RAIL.station)
	for _, item in named do
		assert(type(item.name) == "string" and #item.name > 0, "missing name")
	end
	for _, district in TownLayout.DISTRICTS do
		-- v3: a district may have no hand-placed specials, but then it must have generated lots
		local lots = TownFrontage.lotsByDistrict()[district.name]
		assert(#district.blocks > 0 or (lots and #lots > 0), district.name .. " has no blocks and no lots")
		for _, block in district.blocks do
			assert(#block.use > 0, district.name .. " block without a use")
		end
	end
end

return T
