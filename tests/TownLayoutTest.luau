--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

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

function T.plotEntranceFacesAnAccessRoad()
	local h = TownLayout.PLOT_SIZE / 2
	for i, plot in TownLayout.PLOTS do
		local gate = plot.centre + TownLayout.plotEntranceDirection(i) * (h + 30)
		local d = nearestRoadDistance(gate)
		assert(d <= 60, ("plot %d entrance side is %.0f from a road"):format(i, d))
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
		assert(#district.blocks > 0, district.name .. " has no blocks")
		for _, block in district.blocks do
			assert(#block.use > 0, district.name .. " block without a use")
		end
	end
end

return T
