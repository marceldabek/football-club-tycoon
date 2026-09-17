--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ForecourtDresser = require(ServerScriptService.Server.ForecourtDresser)
local TownBuilder = require(ServerScriptService.Server.TownBuilder)

local T = {}

local function road(kind: string, width: number, a: Vector3, b: Vector3): any
	return { name = "Test " .. kind, kind = kind, width = width, points = { a, b } }
end

local function box(centre: Vector3, size: Vector3): any
	return { centre = centre, size = size, yaw = 0, use = "shops" }
end

-- A residential road along X at z = 0: carriageway to z = +-10, pavement to +-18.
local STREET = road("residential", 20, Vector3.new(-300, 0, 0), Vector3.new(300, 0, 0))

-- Every point of a grid over the forecourt stays off the carriageway.
local function assertOffRoad(fc: ForecourtDresser.Forecourt, r: any, label: string)
	local half = r.width / 2
	for i = 0, 10 do
		for j = 0, 10 do
			local p = fc.cframe:PointToWorldSpace(Vector3.new((i / 10 - 0.5) * fc.depth, 0, (j / 10 - 0.5) * fc.length))
			local best = math.huge
			for k = 1, #r.points - 1 do
				local a, b = r.points[k], r.points[k + 1]
				local abx, abz = b.X - a.X, b.Z - a.Z
				local t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / (abx * abx + abz * abz), 0, 1)
				local dx, dz = p.X - a.X - abx * t, p.Z - a.Z - abz * t
				best = math.min(best, math.sqrt(dx * dx + dz * dz))
			end
			assert(best > half, ("%s: forecourt point %s is on the carriageway (%.2f from centreline)"):format(label, tostring(p), best))
		end
	end
end

function T.blockTwentyStudsBackGetsAForecourtOfTheRightDepth()
	-- 60 x 20 block, front edge at z = -38: 20 studs of grass to the pavement edge at z = -18
	local fc = ForecourtDresser.shopForecourt(box(Vector3.new(0, 10, -48), Vector3.new(60, 20, 20)), { STREET })
	assert(fc, "expected a forecourt")
	assert(math.abs(fc.gap - 20) < 0.05, "gap " .. fc.gap)
	assert(math.abs(fc.depth - (20 + ForecourtDresser.TUCK)) < 0.05, "depth " .. fc.depth)
	assert(math.abs(fc.length - 60) < 1e-4, "length " .. fc.length)
	local p = fc.cframe.Position
	-- from the front (z = -38) toward the road, tucking TUCK under the pavement
	local expected = -38 + (20 + ForecourtDresser.TUCK) / 2
	assert(math.abs(p.Z - expected) < 0.05 and math.abs(p.X) < 1e-4, "centre " .. tostring(p))
	assertOffRoad(fc, STREET, "straight road")
end

function T.blockTouchingThePavementGetsNothing()
	-- front edge exactly on the pavement edge (z = -18)
	assert(ForecourtDresser.shopForecourt(box(Vector3.new(0, 10, -28), Vector3.new(60, 20, 20)), { STREET }) == nil, "touching block")
	-- half a stud of grass is below MIN_GAP
	assert(ForecourtDresser.shopForecourt(box(Vector3.new(0, 10, -28.5), Vector3.new(60, 20, 20)), { STREET }) == nil, "0.5 gap")
	-- and a block far from any road gets nothing either
	assert(ForecourtDresser.shopForecourt(box(Vector3.new(0, 10, -73), Vector3.new(60, 20, 20)), { STREET }) == nil, "45 gap")
end

function T.forecourtNeverOverlapsTheRoad()
	-- slanted road: the gap varies along the frontage, the slab uses the shortest
	local slanted = road("main", 26, Vector3.new(-200, 0, -30), Vector3.new(200, 0, 10))
	local fc = ForecourtDresser.shopForecourt(box(Vector3.new(0, 10, -70), Vector3.new(80, 20, 20)), { slanted })
	assert(fc, "expected a forecourt beside the slanted road")
	assertOffRoad(fc, slanted, "slanted road")
	assert(fc.depth <= fc.gap + ForecourtDresser.TUCK + 1e-6, "depth past the tuck")
	-- a lane has no pavement: the slab stops short of the carriageway itself
	local lane = road("lane", 12, Vector3.new(-200, 0, 0), Vector3.new(200, 0, 0))
	local lfc = ForecourtDresser.shopForecourt(box(Vector3.new(0, 10, -26), Vector3.new(60, 20, 20)), { lane })
	assert(lfc, "expected a forecourt beside the lane")
	assert(math.abs(lfc.gap - 10) < 0.05, "lane gap " .. lfc.gap)
	assertOffRoad(lfc, lane, "lane")
	-- a yawed frame (front facing +X) works the same way
	local northSouth = road("residential", 20, Vector3.new(0, 0, -300), Vector3.new(0, 0, 300))
	local frame = CFrame.new(-40, 0, 0) * CFrame.Angles(0, math.pi, 0) -- local -X now points at world +X
	local yfc = ForecourtDresser.forecourt(frame, 30, 20, { northSouth })
	assert(yfc and math.abs(yfc.gap - 12) < 0.05, "yawed gap " .. tostring(yfc and yfc.gap))
	assertOffRoad(yfc :: ForecourtDresser.Forecourt, northSouth, "yawed")
end

function T.zoneSpansAvoidCarriagewaysAndTheSquareMiddle()
	local centre = Vector3.new(0, 0, 0)
	local r = road("main", 10, Vector3.new(-100, 0, 30), Vector3.new(100, 0, 30))
	local spans = ForecourtDresser.zoneSpans(centre, 20, 40, 4, { r }, nil)
	assert(#spans > 0, "no zone")
	local carriageway = TownBuilder.segmentRect(r.points[1], r.points[2], 5) :: TownBuilder.Rect
	local area = 0
	for _, s in spans do
		assert(s.x1 > s.x0 and s.z1 > s.z0, "empty span")
		local rect = TownBuilder.rect((s.x0 + s.x1) / 2, (s.z0 + s.z1) / 2, 1, 0, (s.x1 - s.x0) / 2, (s.z1 - s.z0) / 2)
		assert(not TownBuilder.rectsOverlap(rect, carriageway), ("span %.1f..%.1f, %.1f..%.1f is on the road"):format(s.x0, s.x1, s.z0, s.z1))
		assert(not (s.x0 <= -4 and s.x1 >= 4 and s.z0 <= -4 and s.z1 >= 4), "span covers the square's middle")
		area += (s.x1 - s.x0) * (s.z1 - s.z0)
	end
	-- 80 x 80 minus the road strip (z 28..32 rounds out to 24..36 in cells) minus the middle
	assert(area > 3000 and area < 6400, "zone area " .. area)
end

return T
