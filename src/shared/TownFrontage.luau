--!strict
-- Rivermere v3: everything built along a street, generated from TownLayout.ROADS.
-- Pure data, deterministic, no Instances, no randomness.
--
-- THIS FILE IS THE SOURCE OF TRUTH for what stands where. tools/town_plan_v3.py
-- holds the same algorithm only so the town can be drawn without Studio
-- (docs/town_map_v3.png); tools/town_v3_parity.py checks the two produce the
-- same lots. Change the algorithm HERE first, then mirror it in the Python,
-- keeping the arithmetic in the same order (both sides use sqrt(x*x + z*z), not
-- hypot, so a lot sitting exactly on a clearance lands the same way in both).
--
-- How it works: every road with front ~= "none" gets one row of cells down each
-- fronted side at a fixed setback, so nothing can stand behind anything else and
-- nothing can be off-parallel. A cell is kept only if it is clear of every other
-- road corridor, the river, the rail, roundabouts, turning heads, the square, the
-- station, bus stops, the plots (+20), the hand-placed specials in
-- TownLayout.DISTRICTS and every cell accepted before it. Main roads are filled
-- first, then the rest longest first, so the important frontage wins a clash.
-- Accepted cells are then joined into lots (a terrace of 6, a pair of semis...).
-- Each cul-de-sac (road.head) also gets a short row across its end.
--
-- Lot.yaw follows the Roblox convention: TownFrontage.lotCFrame(lot) =
-- CFrame.new(centre) * CFrame.Angles(0, rad(yaw), 0) puts local +X along the
-- street and local Z across it. Use lot.front (unit, lot -> street) to know which
-- way the doors face: yaw alone does not say which side of the street a lot is on.

local TownLayout = require(script.Parent.TownLayout)

local TownFrontage = {}

export type Lot = {
	id: string, -- stable: "<road name>|<side>|<segment index>|<n>", side = left | right | head
	use: string, -- TYPES key
	district: string,
	street: string, -- road name it fronts
	centre: Vector3, -- ground level, centre of the footprint
	size: Vector3, -- X = frontage length along the street, Z = depth, Y = nominal height
	yaw: number, -- degrees, Roblox convention; local +X runs along the street
	front: Vector3, -- unit vector pointing FROM the lot TO its street (doors face this way)
	units: number, -- houses/shops in this lot (a terraced row of 6 has units = 6)
	unitWidth: number, -- frontage per unit
	closesStreet: boolean, -- the row across the end of a cul-de-sac
	corner: boolean, -- first/last lot of its run (corner shops, gable ends)
}
export type BuildingType = { cell: number, depth: number, group: number, gap: number, garden: number, height: number }

-- cell = frontage one unit takes, group = how many units join into one lot before
-- a gap, garden = pavement -> front wall. Heights are TEMP nominal values.
TownFrontage.TYPES = {
	["terraced row"] = { cell = 22, depth = 24, group = 6, gap = 8, garden = 6, height = 28 },
	["semis"] = { cell = 25, depth = 24, group = 2, gap = 12, garden = 8, height = 28 },
	["detached house"] = { cell = 34, depth = 26, group = 1, gap = 14, garden = 10, height = 28 },
	["corner shop"] = { cell = 22, depth = 24, group = 1, gap = 4, garden = 6, height = 28 },
	["shops with flats"] = { cell = 26, depth = 30, group = 5, gap = 6, garden = 0, height = 36 },
	["shops"] = { cell = 30, depth = 30, group = 3, gap = 6, garden = 0, height = 20 },
	["flats"] = { cell = 70, depth = 36, group = 1, gap = 16, garden = 8, height = 44 },
	["workshop"] = { cell = 80, depth = 50, group = 1, gap = 16, garden = 10, height = 24 },
	["trade counter"] = { cell = 80, depth = 50, group = 1, gap = 16, garden = 10, height = 24 },
	["warehouse"] = { cell = 160, depth = 100, group = 1, gap = 24, garden = 14, height = 36 },
} :: { [string]: BuildingType }

TownFrontage.HOMES = { ["terraced row"] = true, ["semis"] = true, ["detached house"] = true }

TownFrontage.END_MARGIN = 4 -- no cell within this of a segment end
TownFrontage.SAMPLE_STEP = 10 -- spacing of the outline points a clearance is tested at
TownFrontage.SKIP = 11 -- how far to step on when a cell does not fit
TownFrontage.ROAD_EXTRA = 4 -- a cell keeps this far beyond every OTHER road's pavement
TownFrontage.CELL_MARGIN = 10 -- between cells of different runs
TownFrontage.SPECIAL_MARGIN = 6 -- between a cell and a hand-placed special
TownFrontage.STOP_CLEAR = 16 -- nothing this close to a bus stop (shelter + painted bay)
TownFrontage.HEAD_CLEAR = 5 -- beyond TownLayout.HEAD_RADIUS
TownFrontage.CORNER_SHOP_TRIM = 4 -- a corner shop is this much narrower than its cell

local function hyp(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

-- What fronts a town-centre street: shops at the square, flats toward the river,
-- terraces beyond.
local function centreUse(x: number, z: number): (string?, string?)
	local r = hyp(x, z * 1.4)
	if r < 430 then
		return "shops with flats", "Town Centre"
	end
	if z > 60 and r < 1000 then
		return "flats", "Riverside"
	end
	if r < 640 then
		return "shops", "Town Centre"
	end
	return "terraced row", if z < 0 then "Mill Street Terraces" else "Riverside"
end

-- A road's useAt names one of these. Each returns (use, district), or nil where
-- that stretch of the street is left open.
TownFrontage.RULES = {
	["centre"] = centreUse,
	["industrial"] = function(x: number, z: number): (string?, string?)
		if z < -250 or z > 40 then
			return "warehouse", "Industrial Estate"
		end
		return if math.floor(x / 96) % 3 == 0 then "trade counter" else "workshop", "Industrial Estate"
	end,
	["north road"] = function(_x: number, z: number): (string?, string?)
		if z > -150 then
			return "shops with flats", "Town Centre"
		end
		return nil, nil
	end,
	["high street"] = function(x: number, _z: number): (string?, string?)
		if x > -520 then
			return "shops with flats", "Town Centre"
		end
		return if x > -700 then "shops" else "terraced row", "Station"
	end,
	["bridge street"] = function(_x: number, z: number): (string?, string?)
		if z < 300 then
			return "shops with flats", "Town Centre"
		end
		return nil, nil
	end,
} :: { [string]: (number, number) -> (string?, string?) }

-- Internal working shape: XZ only. `yaw` here is the MATHS angle of the street,
-- atan2(dz, dx) in degrees, which is minus the Roblox yaw stored on a Lot.
type Cell = {
	cx: number,
	cz: number,
	w: number,
	d: number,
	yaw: number,
	use: string,
	district: string?,
	fx: number,
	fz: number,
}
type Row = {
	key: string,
	use: string,
	district: string,
	street: string,
	cx: number,
	cz: number,
	w: number,
	d: number,
	yaw: number,
	fx: number,
	fz: number,
	units: number,
	unitWidth: number,
	corner: boolean,
	closesStreet: boolean,
}

local function segDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local t = 0
	if l2 ~= 0 then
		t = math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / l2))
	end
	return hyp(px - ax - t * dx, pz - az - t * dz)
end

-- Four corners as { x1, z1, x2, z2, x3, z3, x4, z4 }, grown by `grow` all round.
local function corners(c: Cell, grow: number): { number }
	local sx, sz = c.w / 2 + grow, c.d / 2 + grow
	local a = math.rad(c.yaw)
	local ca, sa = math.cos(a), math.sin(a)
	local cx, cz = c.cx, c.cz
	return {
		cx + -sx * ca - -sz * sa,
		cz + -sx * sa + -sz * ca,
		cx + sx * ca - -sz * sa,
		cz + sx * sa + -sz * ca,
		cx + sx * ca - sz * sa,
		cz + sx * sa + sz * ca,
		cx + -sx * ca - sz * sa,
		cz + -sx * sa + sz * ca,
	}
end

-- The outline every SAMPLE_STEP studs or less, then the centre, as { x1, z1, x2, z2, ... }:
-- the points every clearance tests. Dense enough that a road cannot cross a 160-wide
-- warehouse between two samples (corners + midpoints alone let three do exactly that).
local function samples(c: Cell): { number }
	local k = corners(c, 0)
	local out: { number } = {}
	for i = 0, 3 do
		local j = (i + 1) % 4
		local x0, z0, x1, z1 = k[i * 2 + 1], k[i * 2 + 2], k[j * 2 + 1], k[j * 2 + 2]
		local n = math.max(1, math.ceil(hyp(x1 - x0, z1 - z0) / TownFrontage.SAMPLE_STEP))
		for step = 0, n - 1 do
			table.insert(out, x0 + (x1 - x0) * (step / n))
			table.insert(out, z0 + (z1 - z0) * (step / n))
		end
	end
	table.insert(out, c.cx)
	table.insert(out, c.cz)
	return out
end

-- Separating-axis test for two rotated rectangles, each grown by margin / 2.
local function overlap(a: Cell, b: Cell, margin: number): boolean
	local ka, kb = corners(a, margin / 2), corners(b, margin / 2)
	for _, poly in { ka, kb } do
		for i = 0, 1 do
			local ex, ez = poly[i * 2 + 3] - poly[i * 2 + 1], poly[i * 2 + 4] - poly[i * 2 + 2]
			local nx, nz = -ez, ex
			local loA, hiA, loB, hiB = math.huge, -math.huge, math.huge, -math.huge
			for k = 1, 7, 2 do
				local pa = ka[k] * nx + ka[k + 1] * nz
				local pb = kb[k] * nx + kb[k + 1] * nz
				loA, hiA = math.min(loA, pa), math.max(hiA, pa)
				loB, hiB = math.min(loB, pb), math.max(hiB, pb)
			end
			if hiA <= loB or hiB <= loA then
				return false
			end
		end
	end
	return true
end

local function rectPointDist(c: Cell, px: number, pz: number): number
	local a = math.rad(c.yaw)
	local ca, sa = math.cos(a), math.sin(a)
	local dx, dz = px - c.cx, pz - c.cz
	local lx, lz = dx * ca + dz * sa, -dx * sa + dz * ca
	return hyp(math.max(math.abs(lx) - c.w / 2, 0), math.max(math.abs(lz) - c.d / 2, 0))
end

local function polylineLength(points: { Vector3 }): number
	local total = 0
	for i = 1, #points - 1 do
		total += hyp(points[i + 1].X - points[i].X, points[i + 1].Z - points[i].Z)
	end
	return total
end

-- Runs the generator from scratch, ignoring the cache (tests use it to prove two runs match).
function TownFrontage.build(): { Lot }
	local PAVE = TownLayout.PAVEMENT_WIDTH
	local HEAD = TownLayout.HEAD_RADIUS
	local roads = TownLayout.ROADS
	local kept: { Cell } = {}
	local cells: { Cell } = {}
	local rows: { Row } = {}

	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			table.insert(kept, {
				cx = block.centre.X,
				cz = block.centre.Z,
				w = block.size.X,
				d = block.size.Z,
				yaw = -block.yaw,
				use = block.use,
				district = district.name,
				fx = 0,
				fz = 0,
			})
		end
	end

	-- skipRoad / skipSegment: the cell's own street segment, which it is meant to be near.
	local function roadClear(cell: Cell, pts: { number }, skipRoad: TownLayout.Road?, skipSegment: number): boolean
		for _, road in roads do
			local need = road.width / 2 + (if road.kind == "lane" then 0 else PAVE) + TownFrontage.ROAD_EXTRA
			for s = 1, #road.points - 1 do
				if road == skipRoad and s == skipSegment then
					continue
				end
				local a, b = road.points[s], road.points[s + 1]
				-- conservative cull: the centre is within 120 of every sample (a warehouse's half diagonal is 95)
				local reach = need + 120
				if
					cell.cx < math.min(a.X, b.X) - reach
					or cell.cx > math.max(a.X, b.X) + reach
					or cell.cz < math.min(a.Z, b.Z) - reach
					or cell.cz > math.max(a.Z, b.Z) + reach
				then
					continue
				end
				for k = 1, #pts, 2 do
					if segDist(pts[k], pts[k + 1], a.X, a.Z, b.X, b.Z) < need then
						return false
					end
				end
			end
		end
		return true
	end

	local function groundClear(cell: Cell, pts: { number }, heads: boolean): boolean
		local e = TownLayout.EXTENT
		local river, rail = TownLayout.RIVER, TownLayout.RAIL
		local station = rail.station
		local plotReach = TownLayout.PLOT_SIZE / 2 + 20
		for k = 1, #pts, 2 do
			local px, pz = pts[k], pts[k + 1]
			if not (e.minX + 20 < px and px < e.maxX - 20 and e.minZ + 20 < pz and pz < e.maxZ - 20) then
				return false
			end
			for i = 1, #river.points - 1 do
				local a, b = river.points[i], river.points[i + 1]
				if segDist(px, pz, a.X, a.Z, b.X, b.Z) < river.width / 2 + 20 then
					return false
				end
			end
			for i = 1, #rail.points - 1 do
				local a, b = rail.points[i], rail.points[i + 1]
				if segDist(px, pz, a.X, a.Z, b.X, b.Z) < rail.width / 2 + 22 then
					return false
				end
			end
			for _, r in TownLayout.ROUNDABOUTS do
				if hyp(px - r.centre.X, pz - r.centre.Z) < r.radius + PAVE + 6 then
					return false
				end
			end
			if heads then
				for _, road in roads do
					if road.head then
						local h = road.points[#road.points]
						if hyp(px - h.X, pz - h.Z) < HEAD + TownFrontage.HEAD_CLEAR then
							return false
						end
					end
				end
			end
			local square = TownLayout.SQUARE
			if hyp(px - square.centre.X, pz - square.centre.Z) < square.radius + 14 then
				return false
			end
			if
				math.abs(px - station.centre.X) < station.size.X / 2 + 30
				and math.abs(pz - station.centre.Z) < station.size.Z / 2 + 40
			then
				return false
			end
			for _, plot in TownLayout.PLOTS do
				if math.abs(px - plot.centre.X) < plotReach and math.abs(pz - plot.centre.Z) < plotReach then
					return false
				end
			end
		end
		for _, stop in TownLayout.BUS_STOPS do
			if rectPointDist(cell, stop.position.X, stop.position.Z) < TownFrontage.STOP_CLEAR then
				return false
			end
		end
		return true
	end

	local function fits(cell: Cell, skipRoad: TownLayout.Road?, skipSegment: number, heads: boolean, run: { Cell }): boolean
		local pts = samples(cell)
		if not groundClear(cell, pts, heads) or not roadClear(cell, pts, skipRoad, skipSegment) then
			return false
		end
		for _, k in kept do
			if overlap(cell, k, TownFrontage.SPECIAL_MARGIN) then
				return false
			end
		end
		local reach = math.max(cell.w, cell.d) + 110
		for _, c in cells do
			if math.abs(c.cx - cell.cx) < reach and math.abs(c.cz - cell.cz) < reach and not table.find(run, c) then
				if overlap(cell, c, TownFrontage.CELL_MARGIN) then
					return false
				end
			end
		end
		return true
	end

	local function keyHash(key: string): number
		local sum = 0
		for i = 1, #key do
			sum += string.byte(key, i)
		end
		return sum
	end

	-- Turns a run of accepted cells into lots.
	local function flush(run: { Cell }, road: TownLayout.Road, yaw: number, key: string, closes: boolean)
		if #run == 0 then
			return
		end
		local use = run[1].use
		local t = TownFrontage.TYPES[use]
		if use == "terraced row" and #run == 1 then
			-- never strand a single terraced house
			local at = table.find(cells, run[1])
			if at then
				table.remove(cells, at)
			end
			return
		end
		local from = 1
		-- a corner shop on the end of roughly one terrace in three
		if use == "terraced row" and #run >= 5 and keyHash(key) % 3 == 0 then
			local shop = run[1]
			from = 2
			table.insert(rows, {
				key = key,
				use = "corner shop",
				district = shop.district or "Rivermere",
				street = road.name,
				cx = shop.cx,
				cz = shop.cz,
				w = t.cell - TownFrontage.CORNER_SHOP_TRIM,
				d = t.depth,
				yaw = yaw,
				fx = shop.fx,
				fz = shop.fz,
				units = 1,
				unitWidth = t.cell,
				corner = true,
				closesStreet = closes,
			})
		end
		local first = true
		while from <= #run do
			local left = #run - from + 1
			local take = math.min(t.group, left)
			if use == "terraced row" and left - take == 1 then
				take += 1 -- a terrace of 7 rather than 6 and a stranded 1
			end
			local a, b = run[from], run[from + take - 1]
			from += take
			table.insert(rows, {
				key = key,
				use = use,
				district = a.district or "Rivermere",
				street = road.name,
				cx = (a.cx + b.cx) / 2,
				cz = (a.cz + b.cz) / 2,
				w = take * t.cell - t.gap,
				d = t.depth,
				yaw = yaw,
				fx = a.fx,
				fz = a.fz,
				units = take,
				unitWidth = t.cell,
				corner = first or from > #run,
				closesStreet = closes,
			})
			first = false
		end
	end

	local function useAt(road: TownLayout.Road, x: number, z: number): (string?, string?)
		if road.useAt then
			local rule = TownFrontage.RULES[road.useAt]
			assert(rule, road.name .. " names an unknown useAt rule: " .. road.useAt)
			return rule(x, z)
		end
		return road.use, road.district
	end

	-- 1. a short row across the end of each cul-de-sac, looking back down it
	for _, road in roads do
		if not road.head or road.front == "none" then
			continue
		end
		local n = #road.points
		local a, b = road.points[n - 1], road.points[n]
		local seg = hyp(b.X - a.X, b.Z - a.Z)
		local ux, uz = (b.X - a.X) / seg, (b.Z - a.Z) / seg
		local yaw = math.deg(math.atan2(uz, ux)) + 90
		local use, district = useAt(road, b.X, b.Z)
		if use == nil or not TownFrontage.HOMES[use] then
			continue
		end
		local t = TownFrontage.TYPES[use]
		local d = HEAD + t.garden + t.depth / 2
		local run: { Cell } = {}
		for _, k in if use == "semis" then { -0.5, 0.5 } else { -1, 0, 1 } do
			local cell: Cell = {
				cx = b.X + ux * d - uz * k * t.cell,
				cz = b.Z + uz * d + ux * k * t.cell,
				w = t.cell,
				d = t.depth,
				yaw = yaw,
				use = use,
				district = district,
				fx = -ux,
				fz = -uz,
			}
			if not fits(cell, nil, 0, false, run) then
				run = {}
				break
			end
			table.insert(run, cell)
		end
		for _, cell in run do
			table.insert(cells, cell)
		end
		flush(run, road, yaw, ("%s|head|%d"):format(road.name, n - 1), true)
	end

	-- 2. frontage: main roads first, then longest first (stable)
	local order: { { road: TownLayout.Road, index: number, length: number } } = {}
	for index, road in roads do
		if road.front ~= "none" then
			table.insert(order, { road = road, index = index, length = polylineLength(road.points) })
		end
	end
	table.sort(order, function(p, q)
		local pm, qm = p.road.kind == "main", q.road.kind == "main"
		if pm ~= qm then
			return pm
		end
		if p.length ~= q.length then
			return p.length > q.length
		end
		return p.index < q.index
	end)

	local margin = TownFrontage.END_MARGIN
	for _, entry in order do
		local road = entry.road
		for s = 1, #road.points - 1 do
			local a, b = road.points[s], road.points[s + 1]
			local seg = hyp(b.X - a.X, b.Z - a.Z)
			local ux, uz = (b.X - a.X) / seg, (b.Z - a.Z) / seg
			local yaw = math.deg(math.atan2(uz, ux))
			for _, side in { { 1, "left" }, { -1, "right" } } :: { { any } } do
				local sign: number, label: string = side[1], side[2]
				if road.front ~= "both" and road.front ~= label then
					continue
				end
				local nx, nz = uz * sign, -ux * sign
				local key = ("%s|%s|%d"):format(road.name, label, s)
				local run: { Cell } = {}
				local t = 4.0
				assert(margin == 4, "END_MARGIN is mirrored as 4.0 in tools/town_plan_v3.py")
				while t < seg - margin do
					local use, district = useAt(road, a.X + ux * t, a.Z + uz * t)
					if use == nil then
						flush(run, road, yaw, key, false)
						run = {}
						t += TownFrontage.SKIP
						continue
					end
					local ty = TownFrontage.TYPES[use]
					assert(ty, road.name .. " wants an unknown use: " .. use)
					if t + ty.cell > seg - margin then
						break
					end
					local setback = road.width / 2 + PAVE + ty.garden + ty.depth / 2
					local m = t + ty.cell / 2
					local cell: Cell = {
						cx = a.X + ux * m + nx * setback,
						cz = a.Z + uz * m + nz * setback,
						w = ty.cell,
						d = ty.depth,
						yaw = yaw,
						use = use,
						district = district,
						fx = -nx,
						fz = -nz,
					}
					if #run > 0 and run[#run].use ~= use then
						flush(run, road, yaw, key, false)
						run = {}
					end
					if fits(cell, road, s, true, run) then
						table.insert(run, cell)
						table.insert(cells, cell)
						t += ty.cell
					else
						flush(run, road, yaw, key, false)
						run = {}
						t += TownFrontage.SKIP
					end
				end
				flush(run, road, yaw, key, false)
			end
		end
	end

	-- 3. rows -> the public Lot shape
	local lots: { Lot } = {}
	local seen: { [string]: number } = {}
	for _, row in rows do
		local n = (seen[row.key] or 0) + 1
		seen[row.key] = n
		local yaw = -row.yaw
		if yaw == 0 then
			yaw = 0 -- no negative zero
		end
		table.insert(lots, {
			id = ("%s|%d"):format(row.key, n),
			use = row.use,
			district = row.district,
			street = row.street,
			centre = Vector3.new(row.cx, 0, row.cz),
			size = Vector3.new(row.w, TownFrontage.TYPES[row.use].height, row.d),
			yaw = yaw,
			front = Vector3.new(row.fx, 0, row.fz),
			units = row.units,
			unitWidth = row.unitWidth,
			closesStreet = row.closesStreet,
			corner = row.corner,
		})
	end
	return lots
end

local cache: { Lot }? = nil

-- Every generated lot, in a stable order. Cached: treat the result as read-only.
function TownFrontage.generate(): { Lot }
	local lots = cache
	if lots == nil then
		lots = TownFrontage.build()
		cache = lots
	end
	return lots :: { Lot }
end

function TownFrontage.lotsByDistrict(): { [string]: { Lot } }
	local out: { [string]: { Lot } } = {}
	for _, lot in TownFrontage.generate() do
		local list = out[lot.district]
		if list == nil then
			list = {}
			out[lot.district] = list
		end
		table.insert(list, lot)
	end
	return out
end

function TownFrontage.lotsByUse(use: string): { Lot }
	local out: { Lot } = {}
	for _, lot in TownFrontage.generate() do
		if lot.use == use then
			table.insert(out, lot)
		end
	end
	return out
end

-- Ground-level frame of a lot: local +X along the street, local Z across it.
function TownFrontage.lotCFrame(lot: Lot): CFrame
	return CFrame.new(lot.centre) * CFrame.Angles(0, math.rad(lot.yaw), 0)
end

-- World-space footprint corners at ground level, in order, grown by `grow` all round.
function TownFrontage.lotCorners(lot: Lot, grow: number?): { Vector3 }
	local cf = TownFrontage.lotCFrame(lot)
	local hx, hz = lot.size.X / 2 + (grow or 0), lot.size.Z / 2 + (grow or 0)
	return {
		cf * Vector3.new(-hx, 0, -hz),
		cf * Vector3.new(hx, 0, -hz),
		cf * Vector3.new(hx, 0, hz),
		cf * Vector3.new(-hx, 0, hz),
	}
end

return TownFrontage
