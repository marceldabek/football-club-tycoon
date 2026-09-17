--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ForecourtDresser = require(ServerScriptService.Server.ForecourtDresser)
local TownBuilder = require(ServerScriptService.Server.TownBuilder)
local ShopBuilder = require(ServerScriptService.Server.ShopBuilder)

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

function T.basketsHangOnShopfrontJoinsClearOfTheRowEnds()
	-- three 20-wide bays on a 60 row, given out of order: joins at -10 and +10
	local bays: { ForecourtDresser.Bay } = {
		{ z = 20, width = 20, key = nil },
		{ z = -20, width = 20, key = nil },
		{ z = 0, width = 20, key = nil },
	}
	local zs = ForecourtDresser.basketZs(bays, 60)
	assert(#zs == 2, "baskets " .. #zs)
	assert(math.abs(zs[1] + 10) < 1e-6 and math.abs(zs[2] - 10) < 1e-6, ("at %.2f, %.2f"):format(zs[1], zs[2]))
	-- a single shopfront has no join, so no basket
	assert(#ForecourtDresser.basketZs({ { z = 0, width = 20, key = nil } }, 20) == 0, "single bay")
	-- a join within 2 studs of the row end is skipped (a 1.5-wide sliver bay at the end)
	local sliver: { ForecourtDresser.Bay } = { { z = -0.75, width = 18.5, key = nil }, { z = 9.25, width = 1.5, key = nil } }
	assert(#ForecourtDresser.basketZs(sliver, 20) == 0, "join 1.5 from the end")
	-- every basket stays at least 2 from either end on real bay layouts
	for _, length in { 20, 35, 60, 97, 140 } do
		local built: { ForecourtDresser.Bay } = {}
		for _, bay in ShopBuilder.bays(length, if length == 140 then "supermarket" else "shops") do
			table.insert(built, { z = bay.centre, width = bay.width, key = nil })
		end
		for _, z in ForecourtDresser.basketZs(built, length) do
			assert(math.abs(z) <= length / 2 - 2 + 1e-6, ("length %d basket at %.2f"):format(length, z))
		end
		assert(#ForecourtDresser.basketZs(built, length) == #built - 1, "one per join at length " .. length)
	end
end

-- X103: the POST OFFICE sign hangs inside the row's -Z end but outside the
-- stretch where hanging baskets can go, so the two never meet.
function T.postOfficeSignSitsPastTheBaskets()
	for _, length in { 20, 40, 60, 100 } do
		local z = ForecourtDresser.postOfficeSignZ(length)
		assert(z > -length / 2 and z < -length / 2 + 2, ("length %d: sign z %.2f"):format(length, z))
		local bays = { { z = -length / 4, width = length / 2, key = nil }, { z = length / 4, width = length / 2, key = nil } }
		for _, bz in ForecourtDresser.basketZs(bays, length) do
			assert(math.abs(bz - z) > 1.5, ("length %d: basket at %.2f by the sign"):format(length, bz))
		end
	end
end

return T
