--!strict
-- Rivermere v3, Lane F: where street furniture goes. PURE: roads and lots in,
-- `{ name, cframe }` placements out. No Instances, no services. Deterministic:
-- every road seeds its own Random from its name, so one road's furniture never
-- moves because another road changed.
--
-- Conventions copied from tools/kit/place_slice_C_street.luau (the density and
-- look reference). All distances are measured from the KERB (carriageway edge):
--   lamp 6.5 (back of pavement, arm towards the road), telegraph pole 6.8,
--   sign 6.8, shelter 5, bench 5.5, phone box 5.8, bin 3.4, manhole 4, guard rail 1.2.
-- Kit pivots are bottom centre, so a placement's position is the prop's foot.
-- Facing, per asset (checked in Studio):
--   lamp        RightVector points at the road (the arm overhangs that way)
--   sign        LookVector is the way the face points (towards the oncoming driver)
--   shelter, phone box   LookVector points at the road
--   bench       LookVector points AWAY from the road (its seat faces the back vector)
--   guard rail  RightVector runs along the road
--   car         the bonnet is at the BACK vector (checked on HatchbackNavy), so
--               LookVector is opposite to the way it is parked facing
--
-- The pavement strip is kerb .. kerb + PAVEMENT_WIDTH. Nothing lands in a road
-- corridor, a lot, a special block, a junction mouth, a roundabout, a turning
-- head, a plot, the market square or on a bridge. The ONE exception is category
-- "car": parked cars sit on their own residential carriageway against the kerb
-- (placement.onCarriageway = true), and still obey every other rule.

local FurniturePlan = {}

export type RoadIn = {
	name: string,
	kind: string,
	width: number,
	points: { Vector3 },
	district: string?,
	head: boolean?,
}
export type LotIn = { id: string?, use: string, district: string?, street: string?, centre: Vector3, size: Vector3, front: Vector3 }
export type BoxIn = { use: string, centre: Vector3, size: Vector3, yaw: number, district: string? }
export type Input = {
	roads: { RoadIn },
	lots: { LotIn },
	roundabouts: { { centre: Vector3, radius: number } }?,
	specials: { BoxIn }?,
	busStops: { { name: string, position: Vector3 } }?,
	bridges: { { from: Vector3, to: Vector3, width: number } }?,
	rail: { width: number, points: { Vector3 } }?, -- nothing stands on the track (Lane I stage 3)
	plots: { { centre: Vector3 } }?,
	plotSize: number?,
	square: { centre: Vector3, radius: number }?,
	tierACentres: { Vector3 }?, -- nil or empty: the whole town is Tier B
}
export type Options = { pavementY: number?, roadY: number?, district: string? }
export type Placement = {
	name: string,
	cframe: CFrame,
	category: string,
	road: string,
	district: string,
	onCarriageway: boolean?,
}
export type Stats = {
	planned: { [string]: number },
	rejected: { [string]: number },
	skippedBusStops: { string },
}

FurniturePlan.PAVEMENT_WIDTH = 8
FurniturePlan.PAVEMENT_Y = 0.45 -- TownBuilder.Y.PAVEMENT; the slice uses 0.5
FurniturePlan.ROAD_Y = 0.05 -- TEMP: Lane R owns the road surface height
FurniturePlan.HEAD_RADIUS = 34
FurniturePlan.MOUTH_MARGIN = 6 -- kept clear beyond the crossing road's own pavement
FurniturePlan.NO_DISTRICT = "Through Roads" -- ring, mains and lanes carry no district
FurniturePlan.BUS_STOP_SNAP = 150 -- a stop further than this from any road is skipped and reported

-- Spacing is along ONE side. Lamps alternate sides, so `lamp = 40` is a lamp
-- every 20 studs of road, which is what the slice has.
-- Two tiers, from Lane P (docs/TOWN_V3_BUILD.md section 9): Tier A is slice
-- density, about 15 MeshParts per 100 studs of road, within TIER_A_RADIUS of
-- the plots, the market square and the station; Tier B is about 5 per 100
-- studs everywhere else. The tier is looked up at each spot, so a road that
-- runs out of a Tier A circle thins out along its length.
FurniturePlan.TIER_A_RADIUS = 450
FurniturePlan.RULES = {
	A = {
		ring = { lamp = 50, pole = 0, speed = 300, bin = 0, bench = 0, manhole = 130, car = 0, phoneChance = 0 },
		main = { lamp = 40, pole = 0, speed = 300, bin = 80, bench = 110, manhole = 110, car = 0, phoneChance = 0.6 },
		residential = { lamp = 40, pole = 90, speed = 0, bin = 0, bench = 0, manhole = 120, car = 42, phoneChance = 0.15 },
		lane = { lamp = 80, pole = 90, speed = 0, bin = 0, bench = 0, manhole = 0, car = 0, phoneChance = 0 },
	},
	B = {
		ring = { lamp = 90, pole = 0, speed = 420, bin = 0, bench = 0, manhole = 260, car = 0, phoneChance = 0 },
		main = { lamp = 70, pole = 0, speed = 380, bin = 170, bench = 230, manhole = 220, car = 0, phoneChance = 0.5 },
		residential = { lamp = 90, pole = 95, speed = 0, bin = 0, bench = 0, manhole = 240, car = 65, phoneChance = 0.06 },
		lane = { lamp = 160, pole = 110, speed = 0, bin = 0, bench = 0, manhole = 0, car = 0, phoneChance = 0 },
	},
} :: { [string]: { [string]: { [string]: number } } }
FurniturePlan.ROADWORKS_CHANCE = 0.07 -- per road
FurniturePlan.CAR_KEEP = 0.75 -- a car slot in front of housing is filled this often

local K = "UKSP__"
FurniturePlan.ASSETS = {
	lamps = { K .. "StreetLights__StreetLight01", K .. "StreetLights__StreetLight02", K .. "StreetLights__StreetLight03" },
	poles = { K .. "TelegraphPoles__A05", K .. "TelegraphPoles__A04", K .. "TelegraphPoles__A06" },
	giveWay = K .. "Signs__SignNew04",
	noEntryless = K .. "Signs__SignNew33", -- two-way traffic, unused for now
	speedRing = K .. "Signs__SignNew21", -- 40
	speedMain = K .. "Signs__SignNew21", -- TEMP: no 30 identified in the pack yet
	reduceSpeed = K .. "Signs__SignNew05",
	roundaboutAhead = K .. "Signs__SignNew31",
	school = K .. "Signs__SignOld06", -- pedestrians in road
	bins = { K .. "LitterBin__LitterBin", K .. "TelegraphPoles__UKBin" },
	benches = { K .. "ParkBenches__ParkBench01", K .. "ParkBenches__ParkBench02", K .. "ParkBenches__ParkBench03", K .. "ParkBenches__ParkBench04" },
	phones = { K .. "RedPhoneBoxes__RedPhoneBoxDirty", K .. "RedPhoneBoxes__RedPhoneBoxClean", K .. "ModernPhoneBox__PhoneBoxDirty" },
	shelter = K .. "BusShelter__BusShelter",
	guardRail = K .. "GuardRails__GuardRailAMiddle",
	manhole = "PH__water_manhole_cover",
	cabinet = K .. "UtilityPoles__ElectricBox",
	roadworks = { K .. "RoadWorksSign__RoadWorksSignNew", K .. "RoadWorksSign__RoadWorksSignOld" },
	cones = { K .. "TrafficCones__TrafficCone01", K .. "TrafficCones__TrafficCone02", K .. "TrafficCones__TrafficCone05", K .. "TrafficCones__TrafficCone07" },
	barrier = K .. "CrowdBarrier__CrowdBarrierOldA",
	-- Creator Store keepers, one MeshPart each. VanWhite (71 parts) and HatchbackWhite
	-- (153 parts) are left out on purpose: they would eat the budget.
	cars = { "HatchbackOrange", "HatchbackSilver", "HatchbackRed", "HatchbackNavy" },
}

local SHOP_USES = { ["corner shop"] = true, ["shops with flats"] = true, ["shops"] = true }
local PARKING_USES = { ["terraced row"] = true, ["semis"] = true, ["flats"] = true, ["corner shop"] = true }

-- ---------------------------------------------------------------- geometry

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Left of the direction of travel `t` (x east, z south, seen from above).
function FurniturePlan.leftOf(t: Vector3): Vector3
	return Vector3.new(t.Z, 0, -t.X)
end

function FurniturePlan.segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local len2 = abx * abx + abz * abz
	local t = 0
	if len2 > 1e-9 then
		t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / len2, 0, 1)
	end
	local dx, dz = p.X - (a.X + abx * t), p.Z - (a.Z + abz * t)
	return math.sqrt(dx * dx + dz * dz)
end

function FurniturePlan.polylineDistance(p: Vector3, points: { Vector3 }): number
	local best = math.huge
	for i = 1, #points - 1 do
		local d = FurniturePlan.segmentDistance(p, points[i], points[i + 1])
		if d < best then
			best = d
		end
	end
	return best
end

function FurniturePlan.roadLength(road: RoadIn): number
	local total = 0
	for i = 1, #road.points - 1 do
		total += flat(road.points[i + 1] - road.points[i]).Magnitude
	end
	return total
end

-- Point and unit tangent at arc length `s` along the road.
function FurniturePlan.pointAt(road: RoadIn, s: number): (Vector3, Vector3)
	local pts = road.points
	local remaining = math.max(s, 0)
	for i = 1, #pts - 1 do
		local a, b = flat(pts[i]), flat(pts[i + 1])
		local len = (b - a).Magnitude
		if len > 1e-6 then
			if remaining <= len or i == #pts - 1 then
				local t = (b - a) / len
				return a + t * math.min(remaining, len), t
			end
			remaining -= len
		end
	end
	return flat(pts[#pts]), Vector3.new(1, 0, 0)
end

-- Arc length of the point on the road nearest to `p`, and its distance.
function FurniturePlan.project(road: RoadIn, p: Vector3): (number, number)
	local pts = road.points
	local bestS, bestD, run = 0, math.huge, 0
	for i = 1, #pts - 1 do
		local a, b = flat(pts[i]), flat(pts[i + 1])
		local ab = b - a
		local len = ab.Magnitude
		if len > 1e-6 then
			local t = math.clamp((flat(p) - a):Dot(ab) / (len * len), 0, 1)
			local d = (flat(p) - (a + ab * t)).Magnitude
			if d < bestD then
				bestD, bestS = d, run + t * len
			end
			run += len
		end
	end
	return bestS, bestD
end

-- Is `p` inside the footprint (grown by `grow`) whose depth axis is `front`?
local function inFrontBox(p: Vector3, centre: Vector3, size: Vector3, front: Vector3, grow: number): boolean
	local f = flat(front)
	if f.Magnitude < 1e-6 then
		f = Vector3.new(0, 0, 1)
	end
	f = f.Unit
	local along = Vector3.new(-f.Z, 0, f.X)
	local d = flat(p) - flat(centre)
	return math.abs(d:Dot(along)) <= size.X / 2 + grow and math.abs(d:Dot(f)) <= size.Z / 2 + grow
end

local function yawFront(yaw: number): Vector3
	local r = math.rad(yaw)
	return Vector3.new(-math.sin(r), 0, -math.cos(r))
end

function FurniturePlan.seedFor(name: string): number
	local h = 5381
	for i = 1, #name do
		h = (h * 33 + string.byte(name, i)) % 2147483647
	end
	return h
end

-- ---------------------------------------------------------------- context

local CELL = 120

type Context = {
	input: Input,
	lotGrid: { [string]: { LotIn } },
	placed: { [string]: { { p: Vector3, r: number } } },
	plotHalf: number,
}

local function cellKey(cx: number, cz: number): string
	return cx .. ":" .. cz
end

local function makeContext(input: Input): Context
	local grid: { [string]: { LotIn } } = {}
	for _, lot in input.lots do
		local reach = math.max(lot.size.X, lot.size.Z) / 2 + 12
		local x0, x1 = math.floor((lot.centre.X - reach) / CELL), math.floor((lot.centre.X + reach) / CELL)
		local z0, z1 = math.floor((lot.centre.Z - reach) / CELL), math.floor((lot.centre.Z + reach) / CELL)
		for cx = x0, x1 do
			for cz = z0, z1 do
				local key = cellKey(cx, cz)
				local bucket = grid[key]
				if not bucket then
					bucket = {}
					grid[key] = bucket
				end
				table.insert(bucket, lot)
			end
		end
	end
	return { input = input, lotGrid = grid, placed = {}, plotHalf = (input.plotSize or 760) / 2 }
end

-- Why `p` (a prop of half-depth `r`) may not stand here, or nil when it may.
-- `own` is the road the prop belongs to; `onCarriageway` is the parked-car case.
local function blockedBy(ctx: Context, p: Vector3, r: number, own: RoadIn?, onCarriageway: boolean?): string?
	local input = ctx.input
	for _, road in input.roads do
		local d = FurniturePlan.polylineDistance(p, road.points)
		if road == own then
			if not onCarriageway then
				if d < road.width / 2 + r - 0.01 then
					return "corridor"
				end
				if d > road.width / 2 + FurniturePlan.PAVEMENT_WIDTH - r + 0.01 then
					return "offPavement"
				end
			end
		elseif d < road.width / 2 + FurniturePlan.PAVEMENT_WIDTH + FurniturePlan.MOUTH_MARGIN + r then
			return "junction"
		end
		if road.head then
			local tip = road.points[#road.points]
			if flat(p - tip).Magnitude < FurniturePlan.HEAD_RADIUS + r + 1 then
				return "head"
			end
		end
	end
	for _, rb in input.roundabouts or {} do
		if flat(p - rb.centre).Magnitude < rb.radius + FurniturePlan.PAVEMENT_WIDTH + FurniturePlan.MOUTH_MARGIN + r then
			return "roundabout"
		end
	end
	local bucket = ctx.lotGrid[cellKey(math.floor(p.X / CELL), math.floor(p.Z / CELL))]
	if bucket then
		for _, lot in bucket do
			if inFrontBox(p, lot.centre, lot.size, lot.front, r) then
				return "lot"
			end
		end
	end
	for _, box in input.specials or {} do
		if inFrontBox(p, box.centre, box.size, yawFront(box.yaw), r) then
			return "special"
		end
	end
	for _, plot in input.plots or {} do
		if math.abs(p.X - plot.centre.X) < ctx.plotHalf + r and math.abs(p.Z - plot.centre.Z) < ctx.plotHalf + r then
			return "plot"
		end
	end
	local square = input.square
	if square and flat(p - square.centre).Magnitude < square.radius + r then
		return "square"
	end
	for _, bridge in input.bridges or {} do
		local dir = flat(bridge.to - bridge.from)
		if dir.Magnitude > 1e-6 then
			local u = dir.Unit
			local a, b = flat(bridge.from) - u * 44, flat(bridge.to) + u * 44 -- ramps
			if FurniturePlan.segmentDistance(p, a, b) < bridge.width / 2 + FurniturePlan.PAVEMENT_WIDTH + 4 + r then
				return "bridge"
			end
		end
	end
	local rail = input.rail
	if rail then
		for i = 1, #rail.points - 1 do
			if FurniturePlan.segmentDistance(p, rail.points[i], rail.points[i + 1]) < rail.width / 2 + 2 + r then
				return "rail"
			end
		end
	end
	return nil
end

-- Exposed for tests and for the Integrator's own checks.
function FurniturePlan.blockedBy(input: Input, p: Vector3, r: number, own: RoadIn?, onCarriageway: boolean?): string?
	return blockedBy(makeContext(input), p, r, own, onCarriageway)
end

local function overlapsPlaced(ctx: Context, p: Vector3, span: number): boolean
	local cx, cz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = ctx.placed[cellKey(cx + dx, cz + dz)]
			if bucket then
				for _, other in bucket do
					if flat(p - other.p).Magnitude < span + other.r then
						return true
					end
				end
			end
		end
	end
	return false
end

local function remember(ctx: Context, p: Vector3, span: number)
	local key = cellKey(math.floor(p.X / CELL), math.floor(p.Z / CELL))
	local bucket = ctx.placed[key]
	if not bucket then
		bucket = {}
		ctx.placed[key] = bucket
	end
	table.insert(bucket, { p = p, r = span })
end

-- ---------------------------------------------------------------- planning

-- CFrame at `pos` whose RightVector is `right` (unit, horizontal).
local function facingRight(pos: Vector3, right: Vector3): CFrame
	local look = Vector3.new(right.Z, 0, -right.X) -- look x up = right
	return CFrame.lookAt(pos, pos + look)
end

local function facing(pos: Vector3, look: Vector3): CFrame
	return CFrame.lookAt(pos, pos + look)
end

function FurniturePlan.plan(input: Input, options: Options?): ({ Placement }, Stats)
	local opts: Options = options or {}
	local pavY = opts.pavementY or FurniturePlan.PAVEMENT_Y
	local roadY = opts.roadY or FurniturePlan.ROAD_Y
	local ctx = makeContext(input)
	local out: { Placement } = {}
	local stats: Stats = { planned = {}, rejected = {}, skippedBusStops = {} }
	local A = FurniturePlan.ASSETS

	local function tierAt(p: Vector3): string
		for _, centre in input.tierACentres or {} do
			if flat(p - centre).Magnitude <= FurniturePlan.TIER_A_RADIUS then
				return "A"
			end
		end
		return "B"
	end

	-- The rule `key` for `road` at arc length `s` (the tier can change along a road).
	local function rule(road: RoadIn, s: number, key: string): number
		local tier = FurniturePlan.RULES[tierAt((FurniturePlan.pointAt(road, s)))]
		return (tier[road.kind] or tier.residential)[key]
	end

	local function wanted(road: RoadIn): boolean
		return opts.district == nil or (road.district or FurniturePlan.NO_DISTRICT) == opts.district
	end

	-- Try one prop. `clear` is its half-depth across the pavement, `span` its
	-- half-length for keeping props off each other.
	local function try(road: RoadIn, category: string, name: string, cf: CFrame, clear: number, span: number, onCarriageway: boolean?): boolean
		local p = cf.Position
		if blockedBy(ctx, p, clear, road, onCarriageway) or overlapsPlaced(ctx, p, span) then
			stats.rejected[category] = (stats.rejected[category] or 0) + 1
			return false
		end
		remember(ctx, p, span)
		stats.planned[category] = (stats.planned[category] or 0) + 1
		table.insert(out, {
			name = name,
			cframe = cf,
			category = category,
			road = road.name,
			district = road.district or FurniturePlan.NO_DISTRICT,
			onCarriageway = onCarriageway,
		})
		return true
	end

	-- Position on the pavement: `kerb` studs behind the kerb, on `side` (+1 left, -1 right).
	local function onPavement(road: RoadIn, s: number, side: number, kerb: number): (Vector3, Vector3, Vector3)
		local p, t = FurniturePlan.pointAt(road, s)
		local n = FurniturePlan.leftOf(t) * side
		local pos = p + n * (road.width / 2 + kerb)
		return Vector3.new(pos.X, pavY, pos.Z), t, n
	end

	-- 1. Bus stops first: they are fixed points, everything else works round them.
	for _, stop in input.busStops or {} do
		local bestRoad: RoadIn? = nil
		local bestS, bestD = 0, math.huge
		for _, road in input.roads do
			if road.kind ~= "lane" then
				local s, d = FurniturePlan.project(road, stop.position)
				if d < bestD then
					bestRoad, bestS, bestD = road, s, d
				end
			end
		end
		local road = bestRoad
		if not road or bestD > FurniturePlan.BUS_STOP_SNAP then
			table.insert(stats.skippedBusStops, stop.name)
			continue
		end
		if not wanted(road) then
			continue
		end
		local p0, t0 = FurniturePlan.pointAt(road, bestS)
		local side = if flat(stop.position - p0):Dot(FurniturePlan.leftOf(t0)) >= 0 then 1 else -1
		local length = FurniturePlan.roadLength(road)
		local done = false
		for step = 0, 20 do
			for _, sign in { 1, -1 } do
				local s = bestS + sign * step * 12
				if not done and s > 0 and s < length then
					local pos, t, n = onPavement(road, s, side, 5)
					if try(road, "shelter", A.shelter, facing(pos, -n), 2.3, 7, nil) then
						done = true
						local benchPos = onPavement(road, s + 10.5, side, 5.5)
						try(road, "bench", A.benches[1], facing(benchPos, n), 1.3, 3.8, nil)
						local binPos = onPavement(road, s - 8.5, side, 3.4)
						try(road, "bin", A.bins[1], facing(binPos, t), 1.1, 1.2, nil)
					end
				end
			end
			if done then
				break
			end
		end
		if not done then
			table.insert(stats.skippedBusStops, stop.name)
		end
	end

	-- 2. Schools: guard rails on the kerb in front, a warning sign either side.
	for _, box in input.specials or {} do
		if box.use ~= "school" then
			continue
		end
		local bestRoad: RoadIn? = nil
		local bestS, bestD = 0, math.huge
		for _, road in input.roads do
			local s, d = FurniturePlan.project(road, box.centre)
			if d < bestD then
				bestRoad, bestS, bestD = road, s, d
			end
		end
		local road = bestRoad
		if not road or bestD > 200 or not wanted(road) then
			continue
		end
		local p0, t0 = FurniturePlan.pointAt(road, bestS)
		local side = if flat(box.centre - p0):Dot(FurniturePlan.leftOf(t0)) >= 0 then 1 else -1
		for i = -2, 2 do
			if i ~= 0 then -- the gap in the middle is the school gate
				local pos, t = onPavement(road, bestS + i * 11.3, side, 1.2)
				try(road, "guardRail", A.guardRail, facingRight(pos, t), 0.6, 5.4, nil)
			end
		end
		for _, dir in { 1, -1 } do
			-- a driver travelling `dir` along the road meets the sign before the school, on their left
			local s = bestS - dir * 70
			local pos, t = onPavement(road, s, dir, 6.8)
			try(road, "sign", A.school, facing(pos, -t * dir), 0.5, 1.2, nil)
		end
	end

	for _, road in input.roads do
		if not wanted(road) then
			continue
		end
		local rng = Random.new(FurniturePlan.seedFor(road.name))
		local length = FurniturePlan.roadLength(road)
		local mid = length / 2
		local closed = flat(road.points[1] - road.points[#road.points]).Magnitude < 1

		-- 3. Give way where this road runs into a bigger or equal one, or into a roundabout.
		if not closed then
			for _, atEnd in { false, true } do
				if atEnd and road.head then
					continue
				end
				local tip = flat(if atEnd then road.points[#road.points] else road.points[1])
				local reach: number? = nil
				for _, rb in input.roundabouts or {} do
					if flat(tip - rb.centre).Magnitude < rb.radius + 24 then
						reach = rb.radius + 16
					end
				end
				if not reach then
					for _, other in input.roads do
						if other ~= road and FurniturePlan.polylineDistance(tip, other.points) <= other.width / 2 + 1 then
							local sharesEnd = flat(other.points[1] - tip).Magnitude < 1 or flat(other.points[#other.points] - tip).Magnitude < 1
							if not sharesEnd and other.width >= road.width then
								reach = math.max(reach or 0, other.width / 2 + 16)
							end
						end
					end
				end
				if reach then
					-- walk back from the mouth until the sign stands clear of it
					for back = 0, 10 do
						local s = reach + back * 4
						if s >= length / 2 then
							break
						end
						local dir = if atEnd then 1 else -1 -- travel direction towards the junction
						local pos, t = onPavement(road, if atEnd then length - s else s, dir, 6.8)
						if try(road, "giveWay", A.giveWay, facing(pos, -t * dir), 0.5, 1.2, nil) then
							break
						end
					end
				end
			end
		end

		-- 4. Lamps, alternating sides, arm towards the road.
		if rule(road, mid, "lamp") > 0 then
			local s, i = rule(road, 0, "lamp") / 4, 0
			while s < length do
				local side = if i % 2 == 0 then 1 else -1
				local pos, _, n = onPavement(road, s, side, 6.5)
				try(road, "lamp", A.lamps[(i // 2) % #A.lamps + 1], facingRight(pos, -n), 0.5, 1.5, nil)
				s += rule(road, s, "lamp") / 2
				i += 1
			end
		end

		-- 5. Telegraph poles down one side (the side is the road's own coin toss).
		local poleSide = if rng:NextNumber() < 0.5 then 1 else -1
		if rule(road, mid, "pole") > 0 then
			local s = rule(road, 0, "pole") * (0.3 + 0.4 * rng:NextNumber())
			while s < length do
				local pos, t = onPavement(road, s, poleSide, 6.8)
				local name = A.poles[rng:NextInteger(1, #A.poles)]
				try(road, "pole", name, facing(pos, t) * CFrame.Angles(0, math.rad(rng:NextInteger(-20, 20)), 0), 0.5, 1.5, nil)
				s += rule(road, s, "pole")
			end
		end

		-- 6. Speed limits on the ring and mains, both directions, on the driver's left.
		if rule(road, mid, "speed") > 0 then
			local name = if road.kind == "ring" then A.speedRing else A.speedMain
			local s = rule(road, 0, "speed") * 0.25
			while s < length do
				local gap = rule(road, s, "speed")
				local pos, t = onPavement(road, s, 1, 6.8)
				try(road, "sign", name, facing(pos, -t), 0.5, 1.2, nil)
				local s2 = s + gap / 2
				if s2 < length then
					local pos2, t2 = onPavement(road, s2, -1, 6.8)
					try(road, "sign", name, facing(pos2, t2), 0.5, 1.2, nil)
				end
				s += gap
			end
		end

		-- 7. Bins and benches along main streets.
		if rule(road, mid, "bin") > 0 then
			local s, i = rule(road, 0, "bin") * rng:NextNumber(), 0
			while s < length do
				local pos, t = onPavement(road, s, if i % 2 == 0 then 1 else -1, 3.4)
				try(road, "bin", A.bins[i % #A.bins + 1], facing(pos, t), 1.1, 1.2, nil)
				s += rule(road, s, "bin")
				i += 1
			end
		end
		if rule(road, mid, "bench") > 0 then
			local s, i = rule(road, 0, "bench") * rng:NextNumber(), 0
			while s < length do
				local pos, _, n = onPavement(road, s, if i % 2 == 0 then -1 else 1, 5.5)
				try(road, "bench", A.benches[i % #A.benches + 1], facing(pos, n), 1.3, 3.8, nil)
				s += rule(road, s, "bench")
				i += 1
			end
		end

		-- 8. A phone box, sometimes.
		if rng:NextNumber() < rule(road, mid, "phoneChance") and length > 120 then
			local s = length * (0.25 + 0.5 * rng:NextNumber())
			local pos, _, n = onPavement(road, s, -poleSide, 5.8)
			try(road, "phoneBox", A.phones[rng:NextInteger(1, #A.phones)], facing(pos, -n), 1.4, 1.6, nil)
		end

		-- 9. Manhole covers and the odd utility cabinet.
		if rule(road, mid, "manhole") > 0 then
			local s, i = rule(road, 0, "manhole") * rng:NextNumber(), 0
			while s < length do
				local side = if rng:NextNumber() < 0.5 then 1 else -1
				local pos, t, n = onPavement(road, s, side, 4)
				try(road, "manhole", A.manhole, facing(pos, t), 1, 1.2, nil)
				if i % 4 == 3 then
					local boxPos = onPavement(road, s + 14, side, 5.9)
					try(road, "cabinet", A.cabinet, facing(boxPos, -n), 1.55, 1.8, nil)
				end
				s += rule(road, s, "manhole")
				i += 1
			end
		end

		-- 10. Roadworks, very rarely: a sign, a barrier and four cones on the pavement.
		if rng:NextNumber() < FurniturePlan.ROADWORKS_CHANCE and length > 200 then
			local s = length * (0.2 + 0.6 * rng:NextNumber())
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			local pos, t, n = onPavement(road, s, side, 5)
			if try(road, "roadworks", A.roadworks[rng:NextInteger(1, #A.roadworks)], facing(pos, -t * side), 0.6, 1.3, nil) then
				local barrierPos = onPavement(road, s + 7, side, 4.5)
				try(road, "roadworks", A.barrier, facingRight(barrierPos, n), 0.6, 1.2, nil)
				for c = 1, 4 do
					local conePos = onPavement(road, s + 2 + c * 3, side, 1.5 + ((c * 7) % 5))
					try(road, "cone", A.cones[c], facing(conePos, t) * CFrame.Angles(0, c * 0.6, 0), 0.6, 0.7, nil)
				end
			end
		end
	end

	-- 11. Bins (and a bench for every other one) outside shops.
	for index, lot in input.lots do
		if not SHOP_USES[lot.use] or not lot.street then
			continue
		end
		local road: RoadIn? = nil
		for _, candidate in input.roads do
			if candidate.name == lot.street then
				road = candidate
				break
			end
		end
		if not road or not wanted(road) then
			continue
		end
		local s, d = FurniturePlan.project(road, lot.centre)
		if d > road.width / 2 + 80 then
			continue
		end
		local p0, t0 = FurniturePlan.pointAt(road, s)
		local side = if flat(lot.centre - p0):Dot(FurniturePlan.leftOf(t0)) >= 0 then 1 else -1
		local shift = math.min(lot.size.X / 2 - 3, 8)
		local pos, t, n = onPavement(road, s - shift, side, 3.4)
		try(road, "bin", FurniturePlan.ASSETS.bins[index % 2 + 1], facing(pos, t), 1.1, 1.2, nil)
		if index % 2 == 0 and lot.size.X > 40 then
			local benchPos = onPavement(road, s + shift, side, 5.5)
			try(road, "bench", A.benches[index % #A.benches + 1], facing(benchPos, n), 1.3, 3.8, nil)
		end
	end

	-- 12. Parked cars: against the kerb, only in front of housing, never across a gap between lots.
	for _, road in input.roads do
		if not wanted(road) then
			continue
		end
		local length = FurniturePlan.roadLength(road)
		if rule(road, length / 2, "car") <= 0 then
			continue
		end
		local rng = Random.new(FurniturePlan.seedFor(road.name .. "|cars"))
		local fronting: { LotIn } = {}
		for _, lot in input.lots do
			if lot.street == road.name and PARKING_USES[lot.use] then
				table.insert(fronting, lot)
			end
		end
		if #fronting == 0 then
			continue
		end
		for _, side in { 1, -1 } do
			local s = rule(road, 0, "car") * rng:NextNumber()
			while s < length do
				local gap = rule(road, s, "car")
				local jitter = (rng:NextNumber() - 0.5) * gap * 0.4
				local keep = rng:NextNumber() < FurniturePlan.CAR_KEEP
				local pick = rng:NextInteger(1, #A.cars)
				local flip = rng:NextNumber() < 0.2
				local p, t = FurniturePlan.pointAt(road, s + jitter)
				local n = FurniturePlan.leftOf(t) * side
				-- the pavement point abreast of the car must be in front of a housing lot's frontage
				local abreast = p + n * (road.width / 2 + 40)
				local housed = false
				for _, lot in fronting do
					local f = flat(lot.front).Unit
					local along = Vector3.new(-f.Z, 0, f.X)
					local rel = flat(abreast - lot.centre)
					if math.abs(rel:Dot(along)) < lot.size.X / 2 - 9 and math.abs(rel:Dot(f)) < lot.size.Z / 2 + 40 then
						housed = true
						break
					end
				end
				if keep and housed then
					local pos = p + n * (road.width / 2 - 5.3)
					local look = if flip then -t * side else t * side -- parked on the left, facing the way of travel
					-- the keeper hatchbacks are modelled bonnet-to-back-vector, hence -look
					try(road, "car", A.cars[pick], facing(Vector3.new(pos.X, roadY, pos.Z), -look), 5, 10.5, true)
				end
				s += gap
			end
		end
	end

	return out, stats
end

-- Every placement that breaks a rule, as "category road reason". Used by the
-- tests; independent of the bookkeeping inside plan().
function FurniturePlan.violations(input: Input, placements: { Placement }): { string }
	local ctx = makeContext(input)
	local byName: { [string]: RoadIn } = {}
	for _, road in input.roads do
		byName[road.name] = road
	end
	local bad = {}
	for _, pl in placements do
		local own = byName[pl.road]
		local reason = blockedBy(ctx, pl.cframe.Position, 0.4, own, pl.onCarriageway)
		if reason then
			table.insert(bad, pl.category .. " " .. pl.road .. " " .. reason)
		elseif pl.onCarriageway and pl.category ~= "car" then
			table.insert(bad, pl.category .. " " .. pl.road .. " onCarriageway")
		end
	end
	return bad
end

return FurniturePlan
