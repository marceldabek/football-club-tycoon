--!strict
-- Rivermere v3, Lane C: recipes for commercial, industrial and civic buildings.
-- Pure data: no Instances, deterministic from Lot.id. TradeAssembler turns a recipe into kit clones.
--
-- Frame of a recipe: origin = lot centre at ground level, +X along the street, **-Z towards the
-- street** (so a piece with yaw 0 shows its exterior face to the street; measured in Studio, every
-- MEH wall and prefab has its exterior / front door on local -Z). `pos` is the bottom centre of the
-- piece's bounding box, which is what KitPlacer.place expects.
--
-- The kit has NO shopfront, pub, industrial unit, supermarket or station mesh. Everything here is
-- the honest best from Modular English Housing pieces plus UKSP corrugated sheet; each recipe
-- carries the `gap` id of its row in docs/TOWN_V3_BUILD.md section 7 so the stand-ins can be found
-- and replaced when the section 8 buy list is approved.

local HouseUnits = require(script.Parent.HouseUnits)

local TradeRecipes = {}

export type Piece = {
	kit: string,
	pos: Vector3,
	yaw: number, -- degrees about Y; 0 = exterior faces the street, 180 = faces the back
	scale: number?, -- uniform
	fit: Vector3?, -- non-uniform target box (width, height, depth before yaw); roofs and cladding only
}
export type Recipe = {
	kind: string,
	gap: string?,
	pieces: { Piece },
	-- Set when `pieces` are merged HOUSE__ unit meshes (Shared/HouseUnits): what to build instead
	-- in a place whose kit does not hold them, and the dark box that goes inside the body.
	fallback: { Piece }?,
	core: { pos: Vector3, size: Vector3 }?,
}
export type Lot = {
	id: string,
	use: string,
	district: string,
	street: string,
	centre: Vector3,
	size: Vector3,
	yaw: number,
	front: Vector3,
	units: number,
	unitWidth: number,
	closesStreet: boolean,
	corner: boolean,
}

local M = 8.25 -- MEH module, studs (measured)
local CORNER_SHOP_SCALE_MAX = 1.25 -- HouseRecipes' usual terrace scale: a corner shop never outgrows its row
-- The corner shop IS one of the terrace's houses standing free: same merged unit meshes, same
-- scale, so its storeys, door and brick line up with the row it ends.
local CORNER_SHOP_UNITS = { "D01_villa", "D02_bay_villa", "D03_side_door", "D04_cottage" }
local CORNER_SHOP_CORE_INSET = 0.7 -- HouseRecipes.CORE_INSET
TradeRecipes.MODULE = M

TradeRecipes.USES = {
	["shops with flats"] = true,
	["shops"] = true,
	["corner shop"] = true,
	["flats"] = true,
	["workshop"] = true,
	["trade counter"] = true,
	["warehouse"] = true,
}

-- Specials this lane builds. The rest (parks, pitches, marina, bandstand, car park) are ground or
-- belong to the existing district dressers.
TradeRecipes.SPECIAL_USES = {
	["pub"] = true,
	["pub and cafes"] = true,
	["park cafe"] = true,
	["supermarket"] = true,
	["shops"] = true,
	["town hall"] = true,
	["school"] = true,
	["church"] = true,
	["waterfront flats"] = true,
	["sports hall"] = true,
	["builders yard"] = true,
}

-- Measured bounding boxes (width, height, depth) for every kit name a recipe may use. Keeps the
-- fit test pure. A name missing from here fails TradeRecipesTest.
local function meh(n: string): string
	return "MEH__" .. n .. "__ts1"
end
local SIZES: { [string]: Vector3 } = {
	[meh("Wall_A")] = Vector3.new(M, M, 0.05),
	[meh("Wall_Door_A")] = Vector3.new(M, M, 0.45),
	[meh("Wall_Door_B")] = Vector3.new(M, M, 0.45),
	[meh("Wall_Window_A")] = Vector3.new(M, M, 0.46),
	[meh("Wall_Window_B")] = Vector3.new(M, M, 0.46),
	[meh("Wall_Window_C")] = Vector3.new(M, M, 0.46),
	[meh("Wall_Window_D")] = Vector3.new(M, M, 0.46),
	[meh("Wall_Garage_A")] = Vector3.new(M, M, 0.2),
	[meh("Wall_Low_A")] = Vector3.new(M, 2.75, 0.05),
	[meh("Wall_WideDoor_A")] = Vector3.new(2 * M, M, 0.45),
	[meh("Wall_WindowDoor_A")] = Vector3.new(2 * M, M, 0.46),
	[meh("Wall_WindowCentre_A")] = Vector3.new(2 * M, M, 2.0), -- ground-floor bay window
	[meh("Wall_WindowCentre_B")] = Vector3.new(2 * M, M, 0.46),
	[meh("Roof_A")] = Vector3.new(M, 5.5, 8.64),
	[meh("Roof_Flat_A")] = Vector3.new(M, 0.05, M),
	[meh("Roof_Wall_Full_A")] = Vector3.new(17.3, 5.5, 0.4),
	[meh("Door_Canopy_A")] = Vector3.new(4.2, 3.6, 2.2),
	["MEH__House_01_VAR01__ts1"] = Vector3.new(25.5, 25.6, 25.5),
	["MEH__House_01_VAR01__ts3"] = Vector3.new(25.5, 25.6, 25.5),
	["MEH__House_02_VAR1__ts1"] = Vector3.new(17.3, 22.8, 26.9),
	["MEH__House_02_VAR1__ts3"] = Vector3.new(17.3, 22.8, 26.9),
	["MEH__House_03_VAR01__ts1"] = Vector3.new(25.5, 25.1, 18.5),
	["MEH__House_03_VAR01__ts3"] = Vector3.new(25.5, 25.1, 18.5),
	["MEH__House_05_VAR01__ts1"] = Vector3.new(50.3, 22.1, 29.8),
	["MEH__Office_01_VAR01__ts1"] = Vector3.new(82.6, 39.1, 36.2),
	["ChurchSpire"] = Vector3.new(163.2, 202.8, 77.2),
	["PH__rollershutter_door"] = Vector3.new(3.0, 6.6, 0.8),
	["PH__exterior_aircon_unit"] = Vector3.new(2.2, 2.6, 1.0),
	["PH__security_camera_01"] = Vector3.new(0.5, 0.8, 1.5),
	["PH__utility_box_01"] = Vector3.new(1.4, 3.1, 1.2),
	["UKSP__CorrugatedFence__CorrugatedFenceA01"] = Vector3.new(8.3, 6.1, 0.6),
	["UKSP__CorrugatedFence__CorrugatedFenceA02"] = Vector3.new(8.3, 6.1, 0.6),
	["UKSP__CorrugatedFence__CorrugatedFenceB01"] = Vector3.new(8.3, 6.1, 0.6),
	["UKSP__Skips__Skip01"] = Vector3.new(5.9, 4.2, 8.6),
	["UKSP__Skips__Skip02"] = Vector3.new(5.9, 4.2, 8.6),
	["UKSP__dumpster__DumpsterNew"] = Vector3.new(9.5, 5.5, 5.5),
	["UKSP__dumpster__DumpsterRusted"] = Vector3.new(9.5, 5.5, 5.5),
	["UKSP__WoodPallets__PalletA01"] = Vector3.new(5, 0.5, 5),
	["UKSP__WoodPallets__PalletB02"] = Vector3.new(5, 0.5, 5),
	["UKSP__WoodPallets__PalletC03"] = Vector3.new(5, 0.5, 5),
	["UKSP__boxes__Box01"] = Vector3.new(2.7, 1.9, 3.7),
	["UKSP__boxes__Box08"] = Vector3.new(2.8, 1.6, 3.8),
	["UKSP__ConcreteBarriers__BarrierA01"] = Vector3.new(11.1, 3.0, 1.8),
	["UKSP__PicnicBenches__BenchNew"] = Vector3.new(4.7, 2.7, 4.7),
	["UKSP__PicnicBenches__BenchOld"] = Vector3.new(4.7, 2.7, 4.7),
	["ForkliftYellow"] = Vector3.new(6.5, 4.0, 6.5),
}
for _, key in CORNER_SHOP_UNITS do
	for _, mesh in HouseUnits.UNITS[key].meshes do
		SIZES[mesh.name] = mesh.size
	end
end
TradeRecipes.SIZES = SIZES

local CLAD = {
	"UKSP__CorrugatedFence__CorrugatedFenceA01",
	"UKSP__CorrugatedFence__CorrugatedFenceA02",
	"UKSP__CorrugatedFence__CorrugatedFenceB01",
}
local UPPER_SINGLE = { meh("Wall_Window_A"), meh("Wall_Window_B"), meh("Wall_Window_C"), meh("Wall_Window_D") }

local function seedOf(id: string): number
	local h = 5381
	for i = 1, #id do
		h = (h * 33 + string.byte(id, i)) % 2147483647
	end
	return h
end
TradeRecipes.seedOf = seedOf

local function add(pieces: { Piece }, kit: string, x: number, y: number, z: number, yaw: number, scale: number?, fit: Vector3?)
	table.insert(pieces, { kit = kit, pos = Vector3.new(x, y, z), yaw = yaw, scale = scale, fit = fit })
end

-- A face of a box building centred on (cx, cz), W wide along X and D deep along Z.
-- Returns where a piece whose centre is `along` from the face's left end (seen from outside) sits.
type Face = { yaw: number, len: number, at: (along: number, out: number) -> (number, number) }
local function faceOf(side: string, cx: number, cz: number, W: number, D: number): Face
	if side == "front" then
		return { yaw = 0, len = W, at = function(a, o) return cx + W / 2 - a, cz - D / 2 - o end }
	elseif side == "back" then
		return { yaw = 180, len = W, at = function(a, o) return cx - W / 2 + a, cz + D / 2 + o end }
	elseif side == "left" then
		return { yaw = 90, len = D, at = function(a, o) return cx - W / 2 - o, cz - D / 2 + a end }
	end
	return { yaw = -90, len = D, at = function(a, o) return cx + W / 2 + o, cz + D / 2 - a end }
end

-- Lays `items` (kit, width in modules, optional proud offset) left to right along a face at height y.
local function run(pieces: { Piece }, f: Face, y: number, items: { { any } }, scale: number?)
	local s = scale or 1
	local a = 0
	for _, it in items do
		local w = (it[2] :: number) * M * s
		local x, z = f.at(a + w / 2, (it[3] :: number?) or 0)
		add(pieces, it[1] :: string, x, y, z, f.yaw, if s ~= 1 then s else nil)
		a += w
	end
end

-- Covers a blank rectangle (l x h modules) with the fewest uniformly scaled Wall_A squares, so the
-- brick never stretches. 6 x 4 modules costs 3 pieces instead of 24.
local function blank(pieces: { Piece }, f: Face, y0: number, l: number, h: number, a0: number?)
	local a = a0 or 0
	if l <= 0 or h <= 0 then
		return
	end
	local k = math.min(l, h)
	if l >= h then
		local n = l // k
		for i = 0, n - 1 do
			local x, z = f.at((a + i * k + k / 2) * M, 0)
			add(pieces, meh("Wall_A"), x, y0, z, f.yaw, if k ~= 1 then k else nil)
		end
		blank(pieces, f, y0, l - n * k, h, a + n * k)
	else
		local n = h // k
		for i = 0, n - 1 do
			local x, z = f.at((a + k / 2) * M, 0)
			add(pieces, meh("Wall_A"), x, y0 + i * k * M, z, f.yaw, if k ~= 1 then k else nil)
		end
		blank(pieces, f, y0 + n * k * M, l, h - n * k, a)
	end
end

local function flatRoof(pieces: { Piece }, cx: number, cz: number, W: number, D: number, y: number)
	add(pieces, meh("Roof_Flat_A"), cx, y, cz, 0, nil, Vector3.new(W, 0.05, D))
end

-- Ground-floor "shop" bays: a bay window plus a door per three modules. This is the EC1 stand-in.
local function shopGround(n: number, rng: Random): { { any } }
	local items = {}
	local left = n
	local flip = rng:NextInteger(0, 1) == 1
	while left >= 3 do
		local bay = { meh("Wall_WindowCentre_A"), 2, 0.77 }
		local door = { if rng:NextInteger(1, 3) == 1 then meh("Wall_Door_B") else meh("Wall_Door_A"), 1 }
		if flip then
			table.insert(items, door)
			table.insert(items, bay)
		else
			table.insert(items, bay)
			table.insert(items, door)
		end
		flip = not flip
		left -= 3
	end
	if left == 2 then
		table.insert(items, { meh("Wall_WindowDoor_A"), 2 })
	elseif left == 1 then
		table.insert(items, { meh("Wall_Window_A"), 1 })
	end
	return items
end

local function upperFloor(n: number, rng: Random): { { any } }
	local items = {}
	local left = n
	while left >= 3 do
		table.insert(items, { meh("Wall_WindowCentre_B"), 2 })
		table.insert(items, { UPPER_SINGLE[rng:NextInteger(1, #UPPER_SINGLE)], 1 })
		left -= 3
	end
	if left == 2 then
		table.insert(items, { meh("Wall_WindowCentre_B"), 2 })
	elseif left == 1 then
		table.insert(items, { UPPER_SINGLE[rng:NextInteger(1, #UPPER_SINGLE)], 1 })
	end
	return items
end

-- A brick parade: shop bays at street level, `storeys - 1` floors of flats over, pitched roof.
local function parade(lot: Lot, rng: Random, storeys: number, pitched: boolean): { Piece }
	local pieces: { Piece } = {}
	local n = math.max(2, math.floor(lot.size.X / M + 0.01))
	local W, D = n * M, 2 * M
	local cz = -lot.size.Z / 2 + 2.5 + D / 2
	local front, back = faceOf("front", 0, cz, W, D), faceOf("back", 0, cz, W, D)
	run(pieces, front, 0, shopGround(n, rng))
	for s = 1, storeys - 1 do
		run(pieces, front, s * M, upperFloor(n, rng))
	end
	blank(pieces, back, 0, n, storeys)
	blank(pieces, faceOf("left", 0, cz, W, D), 0, 2, storeys)
	blank(pieces, faceOf("right", 0, cz, W, D), 0, 2, storeys)
	local top = storeys * M
	if pitched then
		for i = 0, n - 1 do
			add(pieces, meh("Roof_A"), -W / 2 + (i + 0.5) * M, top, cz - D / 2 + 4.32 - 0.2, 0)
		end
		-- The rear slope is one stretched piece: it is only seen from the back lane.
		add(pieces, meh("Roof_A"), 0, top, cz + D / 2 - 4.32 + 0.2, 180, nil, Vector3.new(W, 5.5, 8.64))
		add(pieces, meh("Roof_Wall_Full_A"), -W / 2, top, cz, 90)
		add(pieces, meh("Roof_Wall_Full_A"), W / 2, top, cz, -90)
	else
		flatRoof(pieces, 0, cz, W, D, top)
		local parapet = {}
		for _ = 1, n do
			table.insert(parapet, { meh("Wall_Low_A"), 1 })
		end
		run(pieces, front, top, parapet)
	end
	-- One shuttered doorway and one camera per parade, from the seed.
	if n >= 3 then
		local x = -W / 2 + (rng:NextInteger(0, n - 1) + 0.5) * M
		add(pieces, "PH__security_camera_01", x, M - 1.2, cz - D / 2 - 0.8, 180)
	end
	return pieces
end

-- A block of flats: 6 x 3 modules, four storeys, flat roof. Returns pieces centred on (cx, 0).
local function flatsBlock(pieces: { Piece }, rng: Random, cx: number, cz: number)
	local W, D, storeys = 6 * M, 3 * M, 4
	local front = faceOf("front", cx, cz, W, D)
	run(pieces, front, 0, { { meh("Wall_WindowCentre_B"), 2 }, { meh("Wall_WideDoor_A"), 2 }, { meh("Wall_WindowCentre_B"), 2 } })
	for s = 1, storeys - 1 do
		run(pieces, front, s * M, upperFloor(6, rng))
	end
	blank(pieces, faceOf("back", cx, cz, W, D), 0, 6, storeys)
	blank(pieces, faceOf("left", cx, cz, W, D), 0, 3, storeys)
	blank(pieces, faceOf("right", cx, cz, W, D), 0, 3, storeys)
	flatRoof(pieces, cx, cz, W, D, storeys * M)
	add(pieces, meh("Door_Canopy_A"), cx, 4.6, cz - D / 2 - 1.1, 0)
end

-- A steel-clad shed: corrugated sheet stretched to panel size, MEH garage doors scaled up as the
-- loading doors, a brick personnel door. EC2 stand-in for a real industrial unit.
local function shed(pieces: { Piece }, rng: Random, cx: number, cz: number, W: number, D: number, H: number, doors: number)
	local doorScale = H / M
	local doorW = M * doorScale
	local front = faceOf("front", cx, cz, W, D)
	local a = 0
	for _ = 1, doors do
		local x, z = front.at(a + doorW / 2, 0)
		add(pieces, meh("Wall_Garage_A"), x, 0, z, 0, doorScale)
		a += doorW
	end
	do
		local x, z = front.at(a + doorW / 2, 0)
		add(pieces, meh("Wall_Door_A"), x, 0, z, 0, doorScale)
		a += doorW
	end
	local function clad(f: Face, from: number)
		local span = f.len - from
		if span < 1 then
			return
		end
		local count = math.max(1, math.floor(span / (H * 1.36) + 0.5))
		local w = span / count
		for i = 0, count - 1 do
			local x, z = f.at(from + (i + 0.5) * w, 0.3)
			add(pieces, CLAD[rng:NextInteger(1, #CLAD)], x, 0, z, f.yaw, nil, Vector3.new(w, H, 0.6))
		end
	end
	clad(front, a)
	clad(faceOf("back", cx, cz, W, D), 0)
	clad(faceOf("left", cx, cz, W, D), 0)
	clad(faceOf("right", cx, cz, W, D), 0)
	flatRoof(pieces, cx, cz, W + 0.6, D + 0.6, H)
	add(pieces, "PH__exterior_aircon_unit", cx - W / 2 - 0.9, 0, cz + D / 4, 90)
end

local YARD = {
	"UKSP__Skips__Skip01",
	"UKSP__WoodPallets__PalletA01",
	"UKSP__dumpster__DumpsterRusted",
	"UKSP__WoodPallets__PalletC03",
	"UKSP__boxes__Box01",
	"ForkliftYellow",
	"UKSP__Skips__Skip02",
	"UKSP__WoodPallets__PalletB02",
	"UKSP__dumpster__DumpsterNew",
	"UKSP__boxes__Box08",
	"UKSP__ConcreteBarriers__BarrierA01",
}

-- Scatters `count` yard props on a grid over the forecourt rectangle, and fences both lot sides.
local function yard(pieces: { Piece }, rng: Random, lot: Lot, z0: number, z1: number, count: number)
	local halfW = lot.size.X / 2
	local cols = math.max(1, math.floor((lot.size.X - 16) / 14))
	local start = rng:NextInteger(1, #YARD)
	for i = 0, count - 1 do
		local col = i % cols
		local row = i // cols
		local x = -halfW + 12 + col * 14 + rng:NextNumber(-1.5, 1.5)
		local z = z0 + 7 + row * 11
		if z + 5 > z1 then
			break
		end
		add(pieces, YARD[(start + i) % #YARD + 1], x, 0, z, rng:NextInteger(0, 3) * 90)
	end
	local panels = math.floor((z1 - z0) / 8.3)
	for i = 0, panels - 1 do
		local z = z0 + (i + 0.5) * 8.3
		add(pieces, CLAD[1], -halfW + 0.4, 0, z, 90)
		add(pieces, CLAD[1], halfW - 0.4, 0, z, -90)
	end
end

-- A row of MEH prefab houses standing in for pubs and cafes (EC3).
local PREFABS = {
	"MEH__House_01_VAR01__ts1",
	"MEH__House_03_VAR01__ts3",
	"MEH__House_02_VAR1__ts1",
	"MEH__House_01_VAR01__ts3",
	"MEH__House_03_VAR01__ts1",
	"MEH__House_02_VAR1__ts3",
}
local function prefabRow(lot: Lot, rng: Random, benches: boolean): { Piece }
	local pieces: { Piece } = {}
	local i = rng:NextInteger(1, #PREFABS)
	local x = -lot.size.X / 2 + 1
	local gap = 3
	while true do
		local kit = PREFABS[(i - 1) % #PREFABS + 1]
		local s = SIZES[kit]
		if s.Z > lot.size.Z - 1 then
			i += 1
			kit = "MEH__House_03_VAR01__ts1"
			s = SIZES[kit]
		end
		if x + s.X > lot.size.X / 2 - 1 then
			break
		end
		local z = -lot.size.Z / 2 + 1 + s.Z / 2
		if benches and lot.size.Z - s.Z > 12 then
			z = lot.size.Z / 2 - 1 - s.Z / 2
			add(pieces, if rng:NextInteger(0, 1) == 0 then "UKSP__PicnicBenches__BenchNew" else "UKSP__PicnicBenches__BenchOld", x + s.X / 2, 0, -lot.size.Z / 2 + 5, 0)
		end
		add(pieces, kit, x + s.X / 2, 0, z, 0)
		x += s.X + gap
		i += 1
	end
	return pieces
end

function TradeRecipes.recipeFor(lot: Lot): Recipe
	local rng = Random.new(seedOf(lot.id))
	local use = lot.use
	local pieces: { Piece } = {}
	if use == "shops with flats" then
		local tall = lot.street == "High Street" or lot.street == "Market Street" or rng:NextInteger(1, 4) == 1
		return { kind = "parade", gap = "EC1", pieces = parade(lot, rng, if tall then 3 else 2, true) }
	elseif use == "shops" or use == "supermarket" then
		return { kind = "shops", gap = if use == "supermarket" then "EC4" else "EC1", pieces = parade(lot, rng, 1, false) }
	elseif use == "corner shop" then
		-- A two-bay shop with a flat over, built like the parades and scaled up to fill its
		-- 18-wide lot. It stands at the end of a terrace whose houses are the same modules at
		-- about 1.25, so it has to be near their size: the prefab house that stood here was
		-- 26.9 deep on a 24-deep lot, so it was shrunk to 0.87 and its door was under 5 studs,
		-- shorter than the people walking past it (Marcel: "one of the houses is tiny").
		local k = math.clamp(lot.size.X / (2 * M), 1, CORNER_SHOP_SCALE_MAX)
		local inner = table.clone(lot)
		inner.size = lot.size / k
		local fallback: { Piece } = {}
		for _, p in parade(inner, rng, 2, true) do
			add(fallback, p.kit, p.pos.X * k, p.pos.Y * k, p.pos.Z * k, p.yaw, if p.fit then nil else (p.scale or 1) * k, if p.fit then p.fit * k else nil)
		end
		-- That parade had no door leaf, no back faces and stood at 1.09 beside houses at 1.25
		-- (Marcel 2026-09-21: "still missing its door and is half the size"). Now it is a whole
		-- merged house unit at the terrace's own scale, front wall on the lot's front edge like
		-- the row. It overhangs its 18-wide lot by 1.3 a side; the row gap beside it is 6.
		local s = math.min(CORNER_SHOP_SCALE_MAX, lot.size.Z / (2 * M))
		local key = CORNER_SHOP_UNITS[seedOf(lot.id .. "#unit") % #CORNER_SHOP_UNITS + 1]
		local cz = -lot.size.Z / 2 + M * s
		for _, mesh in HouseUnits.UNITS[key].meshes do
			add(pieces, mesh.name, mesh.offset.X * s, mesh.offset.Y * s, cz + mesh.offset.Z * s, 0, s)
		end
		local inset = CORNER_SHOP_CORE_INSET * s
		local core = { pos = Vector3.new(0, 0, cz), size = Vector3.new(2 * M * s - 2 * inset, 2 * M * s - 0.05, 2 * M * s - 2 * inset) }
		return { kind = "corner shop", gap = "EC1", pieces = pieces, fallback = fallback, core = core }
	elseif use == "flats" then
		flatsBlock(pieces, rng, 0, -lot.size.Z / 2 + 4 + 1.5 * M)
		return { kind = "flats", pieces = pieces }
	elseif use == "waterfront flats" then
		local cz = -lot.size.Z / 2 + 4 + 1.5 * M
		flatsBlock(pieces, rng, -3.5 * M, cz)
		flatsBlock(pieces, rng, 3.5 * M, cz)
		return { kind = "flats", pieces = pieces }
	elseif use == "workshop" or use == "trade counter" then
		local W, D, H = 6 * M, 4 * M, 1.5 * M
		local cz = lot.size.Z / 2 - 2 - D / 2
		shed(pieces, rng, 0, cz, W, D, H, if use == "workshop" then 2 else 1)
		if use == "workshop" and rng:NextInteger(0, 1) == 0 then
			add(pieces, "PH__rollershutter_door", W / 2 - 3, 0, cz - D / 2 - 0.7, 0, 1.25)
		end
		yard(pieces, rng, lot, -lot.size.Z / 2, cz - D / 2 - 3, 4)
		return { kind = use, gap = "EC2", pieces = pieces }
	elseif use == "warehouse" or use == "sports hall" or use == "builders yard" then
		local big = use ~= "builders yard"
		local W = if big then math.min(lot.size.X - 8, 128) else 6 * M
		local D = if big then math.min(lot.size.Z * 0.62, 64) else 4 * M
		local H = if big then 2.5 * M else 1.5 * M
		local cz = lot.size.Z / 2 - 3 - D / 2
		shed(pieces, rng, 0, cz, W, D, H, if use == "sports hall" then 0 else 2)
		if use ~= "sports hall" then
			yard(pieces, rng, lot, -lot.size.Z / 2, cz - D / 2 - 4, if big then 8 else 12)
		end
		return { kind = use, gap = if use == "sports hall" then "EC5" else "EC2", pieces = pieces }
	elseif use == "pub" or use == "pub and cafes" or use == "park cafe" then
		return { kind = use, gap = "EC3", pieces = prefabRow(lot, rng, true) }
	elseif use == "town hall" or use == "school" then
		local kit = "MEH__Office_01_VAR01__ts1"
		add(pieces, kit, 0, 0, lot.size.Z / 2 - 2 - SIZES[kit].Z / 2, 0)
		if lot.size.X >= 140 then
			add(pieces, "MEH__House_05_VAR01__ts1", -lot.size.X / 2 + 28, 0, -lot.size.Z / 2 + 2 + 15, 0)
		end
		return { kind = use, gap = "EC5", pieces = pieces }
	elseif use == "church" then
		-- The Creator Store keeper is a spire-and-nave model 163 studs long; the lot is 40 x 90, so
		-- it is turned end-on to the street and scaled to the lot.
		local s = SIZES["ChurchSpire"]
		local k = math.min((lot.size.Z - 1) / s.X, (lot.size.X - 1) / s.Z)
		add(pieces, "ChurchSpire", 0, 0, 0, 90, k)
		return { kind = "church", gap = "EC7", pieces = pieces }
	end
	return { kind = "none", pieces = pieces }
end

-- Local-frame bounds of a recipe from SIZES: min, max. Errors on an unknown kit name.
function TradeRecipes.bounds(recipe: Recipe): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in recipe.pieces do
		local s = SIZES[p.kit]
		assert(s, "TradeRecipes.SIZES has no entry for " .. p.kit)
		local box = p.fit or (s * (p.scale or 1))
		local turned = math.abs(math.sin(math.rad(p.yaw))) > 0.5
		local half = Vector3.new(if turned then box.Z else box.X, 0, if turned then box.X else box.Z) / 2
		lo = lo:Min(p.pos - half)
		hi = hi:Max(p.pos + half + Vector3.new(0, box.Y, 0))
	end
	return lo, hi
end

-- FIXTURE: TEMP until Lane A lands TownFrontage.generate() and the v3 TownLayout specials.
-- Generated from docs/town_v3_lots.json; do not edit by hand.
-- Row: id, use, district, street, cx, cz, sx, sy, sz, yaw, fx, fz, units, unitWidth, closesStreet, corner
-- FIXTURE BEGIN
local FIXTURE: { { any } } = {
	{ "Riverside Road|left|1|1", "shops with flats", "Town Centre", "Riverside Road", 160, -36, 98, 36, 30, 0, 0, 1, 4, 26, false, true },
	{ "Riverside Road|left|1|2", "shops with flats", "Town Centre", "Riverside Road", 304, -36, 46, 36, 30, 0, 0, 1, 2, 26, false, true },
	{ "Riverside Road|left|1|3", "shops", "Town Centre", "Riverside Road", 573, -36, 84, 20, 30, 0, 0, 1, 3, 30, false, true },
	{ "Riverside Road|left|1|4", "shops", "Town Centre", "Riverside Road", 633, -36, 24, 20, 30, 0, 0, 1, 1, 30, false, true },
	{ "Riverside Road|right|1|1", "shops with flats", "Town Centre", "Riverside Road", 140, 36, 124, 36, 30, 0, 0, -1, 5, 26, false, true },
	{ "Riverside Road|right|1|2", "shops with flats", "Town Centre", "Riverside Road", 347, 36, 124, 36, 30, 0, 0, -1, 5, 26, false, true },
	{ "Riverside Road|right|1|3", "shops with flats", "Town Centre", "Riverside Road", 425, 36, 20, 36, 30, 0, 0, -1, 1, 26, false, true },
	{ "Riverside Road|right|1|4", "shops", "Town Centre", "Riverside Road", 464, 36, 24, 20, 30, 0, 0, -1, 1, 30, false, true },
	{ "Riverside Road|right|1|5", "shops", "Town Centre", "Riverside Road", 557, 36, 84, 20, 30, 0, 0, -1, 3, 30, false, true },
	{ "Riverside Road|right|1|6", "shops", "Town Centre", "Riverside Road", 632, 36, 54, 20, 30, 0, 0, -1, 2, 30, false, true },
	{ "Riverside Road|right|1|8", "corner shop", "Riverside", "Riverside Road", 794, 39, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Greenbridge Road|right|1|1", "corner shop", "Westdale", "Greenbridge Road", -1209, 521, 18, 28, 24, -180, 0, 1, 1, 22, false, true },
	{ "Greenbridge Road|right|1|5", "corner shop", "Westdale", "Greenbridge Road", -1638, 521, 18, 28, 24, -180, 0, 1, 1, 22, false, true },
	{ "High Street|left|1|1", "shops with flats", "Town Centre", "High Street", -101, 36, 46, 36, 30, -180, 0, -1, 2, 26, false, true },
	{ "High Street|left|1|2", "shops with flats", "Town Centre", "High Street", -173, 36, 20, 36, 30, -180, 0, -1, 1, 26, false, true },
	{ "High Street|right|1|1", "shops with flats", "Town Centre", "High Street", -259, -36, 98, 36, 30, -180, 0, 1, 4, 26, false, true },
	{ "High Street|right|2|1", "shops with flats", "Town Centre", "High Street", -402.12, -53.03, 20, 36, 30, 135, -0.7071, 0.7071, 1, 26, false, true },
	{ "High Street|left|3|1", "shops", "Station", "High Street", -565, -69, 84, 20, 30, -180, 0, -1, 3, 30, false, true },
	{ "High Street|left|3|2", "shops", "Station", "High Street", -655, -69, 84, 20, 30, -180, 0, -1, 3, 30, false, true },
	{ "High Street|left|3|3", "corner shop", "Station", "High Street", -722, -66, 18, 28, 24, -180, 0, -1, 1, 22, false, true },
	{ "High Street|left|3|5", "corner shop", "Station", "High Street", -887, -66, 18, 28, 24, -180, 0, -1, 1, 22, false, true },
	{ "High Street|right|3|1", "shops", "Station", "High Street", -642, -141, 84, 20, 30, -180, 0, 1, 3, 30, false, true },
	{ "High Street|right|3|2", "shops", "Station", "High Street", -702, -141, 24, 20, 30, -180, 0, 1, 1, 30, false, true },
	{ "Hollingford Road|right|2|1", "corner shop", "Hollingford", "Hollingford Road", 1298.59, 653.74, 18, 28, 24, -45, 0.7071, -0.7071, 1, 22, false, true },
	{ "Hollingford Road|left|3|1", "corner shop", "Hollingford", "Hollingford Road", 1559, 761, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Hollingford Road|left|3|3", "corner shop", "Hollingford", "Hollingford Road", 1801, 761, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Hollingford Road|left|3|5", "corner shop", "Hollingford", "Hollingford Road", 1977, 761, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Hollingford Road|left|3|7", "corner shop", "Hollingford", "Hollingford Road", 2164, 761, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Mapleford Road|left|1|1", "warehouse", "Industrial Estate", "Mapleford Road", -1511, -315, 136, 36, 100, -180, 0, -1, 1, 160, false, true },
	{ "Mapleford Road|left|1|2", "warehouse", "Industrial Estate", "Mapleford Road", -1671, -315, 136, 36, 100, -180, 0, -1, 1, 160, false, false },
	{ "Mapleford Road|left|1|3", "warehouse", "Industrial Estate", "Mapleford Road", -1831, -315, 136, 36, 100, -180, 0, -1, 1, 160, false, false },
	{ "Mapleford Road|left|1|4", "warehouse", "Industrial Estate", "Mapleford Road", -1991, -315, 136, 36, 100, -180, 0, -1, 1, 160, false, false },
	{ "Mapleford Road|left|1|5", "warehouse", "Industrial Estate", "Mapleford Road", -2151, -315, 136, 36, 100, -180, 0, -1, 1, 160, false, true },
	{ "Estate Road|left|1|1", "workshop", "Industrial Estate", "Estate Road", -1343, -49, 64, 24, 50, -180, 0, -1, 1, 80, false, true },
	{ "Estate Road|left|1|2", "workshop", "Industrial Estate", "Estate Road", -1863, -49, 64, 24, 50, -180, 0, -1, 1, 80, false, true },
	{ "Estate Road|left|1|3", "workshop", "Industrial Estate", "Estate Road", -1943, -49, 64, 24, 50, -180, 0, -1, 1, 80, false, true },
	{ "Estate Road|left|1|4", "trade counter", "Industrial Estate", "Estate Road", -2034, -49, 64, 24, 50, -180, 0, -1, 1, 80, false, true },
	{ "Estate Road|left|1|5", "workshop", "Industrial Estate", "Estate Road", -2191, -49, 64, 24, 50, -180, 0, -1, 1, 80, false, true },
	{ "Estate Road|right|1|1", "workshop", "Industrial Estate", "Estate Road", -1662, -161, 64, 24, 50, -180, 0, 1, 1, 80, false, true },
	{ "Estate Road|right|1|2", "workshop", "Industrial Estate", "Estate Road", -1863, -161, 64, 24, 50, -180, 0, 1, 1, 80, false, true },
	{ "Estate Road|right|1|3", "workshop", "Industrial Estate", "Estate Road", -1943, -161, 64, 24, 50, -180, 0, 1, 1, 80, false, true },
	{ "Estate Road|right|1|4", "trade counter", "Industrial Estate", "Estate Road", -2034, -161, 64, 24, 50, -180, 0, 1, 1, 80, false, true },
	{ "Estate Road|right|1|5", "workshop", "Industrial Estate", "Estate Road", -2191, -161, 64, 24, 50, -180, 0, 1, 1, 80, false, true },
	{ "North Road|left|1|1", "shops with flats", "Town Centre", "North Road", -36, -134, 46, 36, 30, 90, 1, 0, 2, 26, false, true },
	{ "North Road|right|1|1", "shops with flats", "Town Centre", "North Road", 36, -114, 72, 36, 30, 90, -1, 0, 3, 26, false, true },
	{ "Bridge Street|left|1|1", "shops with flats", "Town Centre", "Bridge Street", 36, 88, 20, 36, 30, -90, -1, 0, 1, 26, false, true },
	{ "Bridge Street|left|1|2", "shops with flats", "Town Centre", "Bridge Street", 36, 169, 20, 36, 30, -90, -1, 0, 1, 26, false, true },
	{ "Bridge Street|right|1|1", "shops with flats", "Town Centre", "Bridge Street", -36, 88, 20, 36, 30, -90, 1, 0, 1, 26, false, true },
	{ "Bridge Street|right|1|2", "shops with flats", "Town Centre", "Bridge Street", -36, 169, 20, 36, 30, -90, 1, 0, 1, 26, false, true },
	{ "Bridge Street|left|2|1", "shops with flats", "Town Centre", "Bridge Street", 60.81, 209.9, 20, 36, 30, -45, -0.7071, 0.7071, 1, 26, false, true },
	{ "Station Road|left|1|1", "shops", "Station", "Station Road", -645.01, -194.1, 24, 20, 30, 135, 0.7071, -0.7071, 1, 30, false, true },
	{ "Station Road|left|1|2", "shops", "Station", "Station Road", -736.22, -285.31, 24, 20, 30, 135, 0.7071, -0.7071, 1, 30, false, true },
	{ "Station Road|right|1|1", "shops", "Station", "Station Road", -545.31, -196.22, 84, 20, 30, 135, -0.7071, 0.7071, 3, 30, false, true },
	{ "Station Road|right|1|2", "shops", "Station", "Station Road", -608.94, -259.86, 84, 20, 30, 135, -0.7071, 0.7071, 3, 30, false, true },
	{ "Station Road|left|2|1", "shops", "Station", "Station Road", -819, -301, 84, 20, 30, -180, 0, -1, 3, 30, false, true },
	{ "Station Road|left|2|2", "shops", "Station", "Station Road", -894, -301, 54, 20, 30, -180, 0, -1, 2, 30, false, true },
	{ "Northfields Avenue|right|1|1", "corner shop", "Northfields", "Northfields Avenue", -1302, -564, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Northfields Avenue|right|1|10", "corner shop", "Northfields", "Northfields Avenue", 40, -564, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Northfields Avenue|right|1|14", "corner shop", "Northfields", "Northfields Avenue", 491, -564, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Orchard Road|right|1|1", "corner shop", "Westdale", "Orchard Road", -2225, 1516, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Elm Grove|left|1|1", "corner shop", "Mill Street Terraces", "Elm Grove", -485, -476, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Elm Grove|left|1|4", "corner shop", "Mill Street Terraces", "Elm Grove", -166, -476, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Elm Grove|left|1|6", "corner shop", "Mill Street Terraces", "Elm Grove", 43, -476, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Elm Grove|left|1|10", "corner shop", "Mill Street Terraces", "Elm Grove", 483, -476, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Lune Street|left|1|1", "flats", "Riverside", "Lune Street", -401, 216, 54, 44, 36, 0, 0, 1, 1, 70, false, true },
	{ "Lune Street|left|1|2", "flats", "Riverside", "Lune Street", -265, 216, 54, 44, 36, 0, 0, 1, 1, 70, false, true },
	{ "Lune Street|left|1|3", "shops with flats", "Town Centre", "Lune Street", -50, 227, 46, 36, 30, 0, 0, 1, 2, 26, false, true },
	{ "Lune Street|left|1|4", "shops with flats", "Town Centre", "Lune Street", 162, 227, 124, 36, 30, 0, 0, 1, 5, 26, false, true },
	{ "Lune Street|left|1|5", "flats", "Riverside", "Lune Street", 317, 216, 54, 44, 36, 0, 0, 1, 1, 70, false, true },
	{ "Lune Street|left|1|6", "flats", "Riverside", "Lune Street", 387, 216, 54, 44, 36, 0, 0, 1, 1, 70, false, false },
	{ "Lune Street|left|1|7", "flats", "Riverside", "Lune Street", 457, 216, 54, 44, 36, 0, 0, 1, 1, 70, false, true },
	{ "Lune Street|right|1|1", "flats", "Riverside", "Lune Street", -401, 304, 54, 44, 36, 0, 0, -1, 1, 70, false, true },
	{ "Lune Street|right|1|2", "shops with flats", "Town Centre", "Lune Street", -114, 293, 124, 36, 30, 0, 0, -1, 5, 26, false, true },
	{ "Lune Street|right|1|3", "shops with flats", "Town Centre", "Lune Street", -10, 293, 72, 36, 30, 0, 0, -1, 3, 26, false, true },
	{ "Lune Street|right|1|4", "shops with flats", "Town Centre", "Lune Street", 180, 293, 98, 36, 30, 0, 0, -1, 4, 26, false, true },
	{ "Lune Street|right|1|5", "flats", "Riverside", "Lune Street", 278, 304, 54, 44, 36, 0, 0, -1, 1, 70, false, true },
	{ "Lune Street|right|1|6", "flats", "Riverside", "Lune Street", 348, 304, 54, 44, 36, 0, 0, -1, 1, 70, false, false },
	{ "Lune Street|right|1|7", "flats", "Riverside", "Lune Street", 418, 304, 54, 44, 36, 0, 0, -1, 1, 70, false, false },
	{ "Lune Street|right|1|8", "flats", "Riverside", "Lune Street", 488, 304, 54, 44, 36, 0, 0, -1, 1, 70, false, true },
	{ "Meadow Road|right|1|1", "corner shop", "Riverside", "Meadow Road", 137, 596, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Meadow Road|right|1|5", "corner shop", "Riverside", "Meadow Road", 643, 596, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Tannery Row|right|1|1", "corner shop", "Riverside", "Tannery Row", 137, 716, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Tannery Row|right|1|5", "corner shop", "Riverside", "Tannery Row", 643, 716, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Alder Road|right|1|1", "corner shop", "Westdale", "Alder Road", -1346, 597, 18, 28, 24, -90, 1, 0, 1, 22, false, true },
	{ "Mill Street|left|1|1", "corner shop", "Mill Street Terraces", "Mill Street", 37, -236, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Mill Street|left|1|5", "corner shop", "Mill Street Terraces", "Mill Street", 488, -236, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Millbrook Road|left|1|1", "corner shop", "Millbrook", "Millbrook Road", 1426, -736, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Cooper Street|right|1|1", "corner shop", "Station", "Cooper Street", -1291, -204, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Cooper Street|right|1|5", "corner shop", "Station", "Cooper Street", -807, -204, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Cedar Road|right|1|1", "corner shop", "Riverside", "Cedar Road", -506, 848, 18, 28, 24, -90, 1, 0, 1, 22, false, true },
	{ "Hollins Road|left|1|1", "corner shop", "Riverside", "Hollins Road", 626, 848, 18, 28, 24, -90, -1, 0, 1, 22, false, true },
	{ "Quarry Road|right|1|1", "corner shop", "Millbrook", "Quarry Road", 1363, -1116, 18, 28, 24, -180, 0, 1, 1, 22, false, true },
	{ "Quarry Road|right|1|3", "corner shop", "Millbrook", "Quarry Road", 1143, -1116, 18, 28, 24, -180, 0, 1, 1, 22, false, true },
	{ "Quarry Road|left|2|1", "corner shop", "Millbrook", "Quarry Road", 863.94, -1065.15, 18, 28, 24, 135, 0.7071, -0.7071, 1, 22, false, true },
	{ "Viaduct Road|left|1|1", "corner shop", "Riverside", "Viaduct Road", -530, 584, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Drovers Road|left|1|1", "corner shop", "Mapleford", "Drovers Road", -1280, -1246, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Drovers Road|left|1|3", "corner shop", "Mapleford", "Drovers Road", -1082, -1246, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Westdale Avenue|left|1|1", "corner shop", "Westdale", "Westdale Avenue", -1240, 914, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Coronation Street|left|1|1", "corner shop", "Westdale", "Coronation Street", -1240, 1329, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Weir Road|right|1|1", "corner shop", "Riverside", "Weir Road", -1080, 596, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Weir Road|right|1|4", "corner shop", "Riverside", "Weir Road", -816, 596, 18, 28, 24, 0, 0, -1, 1, 22, false, true },
	{ "Foundry Way|left|1|1", "workshop", "Industrial Estate", "Foundry Way", -1427, -202, 64, 24, 50, -90, -1, 0, 1, 80, false, true },
	{ "Foundry Way|left|1|2", "workshop", "Industrial Estate", "Foundry Way", -1427, -34, 64, 24, 50, -90, -1, 0, 1, 80, false, true },
	{ "Foundry Way|left|1|3", "workshop", "Industrial Estate", "Foundry Way", -1427, 46, 64, 24, 50, -90, -1, 0, 1, 80, false, true },
	{ "Foundry Way|right|1|1", "workshop", "Industrial Estate", "Foundry Way", -1533, -202, 64, 24, 50, -90, 1, 0, 1, 80, false, true },
	{ "Foundry Way|right|1|2", "workshop", "Industrial Estate", "Foundry Way", -1533, -34, 64, 24, 50, -90, 1, 0, 1, 80, false, true },
	{ "Foundry Way|right|1|3", "workshop", "Industrial Estate", "Foundry Way", -1533, 46, 64, 24, 50, -90, 1, 0, 1, 80, false, true },
	{ "Forge Lane|left|1|1", "workshop", "Industrial Estate", "Forge Lane", -1747, -202, 64, 24, 50, -90, -1, 0, 1, 80, false, true },
	{ "Forge Lane|right|1|1", "workshop", "Industrial Estate", "Forge Lane", -1853, 29, 64, 24, 50, -90, 1, 0, 1, 80, false, true },
	{ "Furnace Lane|left|1|1", "workshop", "Industrial Estate", "Furnace Lane", -2067, 29, 64, 24, 50, -90, -1, 0, 1, 80, false, true },
	{ "Furnace Lane|right|1|1", "workshop", "Industrial Estate", "Furnace Lane", -2173, 29, 64, 24, 50, -90, 1, 0, 1, 80, false, true },
	{ "Quay Street|left|1|1", "shops with flats", "Town Centre", "Quay Street", 135, 97, 124, 36, 30, 0, 0, 1, 5, 26, false, true },
	{ "Quay Street|left|1|2", "shops with flats", "Town Centre", "Quay Street", 213, 97, 20, 36, 30, 0, 0, 1, 1, 26, false, true },
	{ "Quay Street|left|1|3", "shops with flats", "Town Centre", "Quay Street", 346, 97, 124, 36, 30, 0, 0, 1, 5, 26, false, true },
	{ "Quay Street|right|1|1", "shops with flats", "Town Centre", "Quay Street", 135, 163, 124, 36, 30, 0, 0, -1, 5, 26, false, true },
	{ "Quay Street|right|1|2", "shops with flats", "Town Centre", "Quay Street", 213, 163, 20, 36, 30, 0, 0, -1, 1, 26, false, true },
	{ "Quay Street|right|1|3", "shops with flats", "Town Centre", "Quay Street", 346, 163, 124, 36, 30, 0, 0, -1, 5, 26, false, true },
	{ "Park Road|right|1|1", "corner shop", "Mill Street Terraces", "Park Road", 936, -215, 18, 28, 24, 90, -1, 0, 1, 22, false, true },
	{ "Guild Street|left|1|1", "shops with flats", "Town Centre", "Guild Street", -239, 97, 124, 36, 30, 0, 0, 1, 5, 26, false, true },
	{ "Guild Street|left|1|2", "shops with flats", "Town Centre", "Guild Street", -122, 97, 98, 36, 30, 0, 0, 1, 4, 26, false, true },
	{ "Guild Street|right|1|1", "shops with flats", "Town Centre", "Guild Street", -265, 163, 72, 36, 30, 0, 0, -1, 3, 26, false, true },
	{ "Chapel Street|left|1|1", "shops with flats", "Town Centre", "Chapel Street", -183, -120, 72, 36, 30, 90, 1, 0, 3, 26, false, true },
	{ "Chapel Street|right|1|1", "shops with flats", "Town Centre", "Chapel Street", -117, -146, 124, 36, 30, 90, -1, 0, 5, 26, false, true },
	{ "Chapel Street|right|1|2", "shops with flats", "Town Centre", "Chapel Street", -117, -237, 46, 36, 30, 90, -1, 0, 2, 26, false, true },
	{ "Hazel Close|left|1|1", "corner shop", "Northfields", "Hazel Close", -436, -670, 18, 28, 24, 90, 1, 0, 1, 22, false, true },
	{ "Holly Close|right|1|1", "corner shop", "Northfields", "Holly Close", 261, -670, 18, 28, 24, 90, -1, 0, 1, 22, false, true },
	{ "Hayfield Close|left|1|1", "corner shop", "Northfields", "Hayfield Close", 364, -670, 18, 28, 24, 90, 1, 0, 1, 22, false, true },
	{ "Laurel Close|right|1|1", "corner shop", "Northfields", "Laurel Close", 686, -670, 18, 28, 24, 90, -1, 0, 1, 22, false, true },
	{ "Fern Street|left|1|1", "corner shop", "Westdale", "Fern Street", -1240, 764, 18, 28, 24, 0, 0, 1, 1, 22, false, true },
	{ "Tanner Row|right|1|1", "shops with flats", "Town Centre", "Tanner Row", -363, 160, 20, 36, 30, -90, 1, 0, 1, 26, false, true },
	{ "Fountain Street|left|1|1", "shops with flats", "Town Centre", "Fountain Street", 217, -96, 46, 36, 30, 90, 1, 0, 2, 26, false, true },
	{ "Fountain Street|right|1|1", "shops with flats", "Town Centre", "Fountain Street", 283, -96, 46, 36, 30, 90, -1, 0, 2, 26, false, true },
	{ "Dyers Lane|left|1|1", "shops", "Town Centre", "Dyers Lane", 467, -100, 54, 20, 30, 90, 1, 0, 2, 30, false, true },
	{ "Dyers Lane|right|1|1", "shops", "Town Centre", "Dyers Lane", 533, -100, 54, 20, 30, 90, -1, 0, 2, 30, false, true },
	{ "Marina Way|left|1|1", "flats", "Riverside", "Marina Way", 804, 105, 54, 44, 36, -90, -1, 0, 1, 70, false, true },
	{ "special|pub|0", "pub", "Town Centre", "", 400, -41, 100, 40, 30, 0, 0, 1, 1, 100, false, false },
	{ "special|supermarket|1", "supermarket", "Town Centre", "", -260, 36, 100, 40, 30, 0, 0, 1, 1, 100, false, false },
	{ "special|town hall|2", "town hall", "Town Centre", "", -150, 200, 120, 40, 60, 0, 0, 1, 1, 120, false, false },
	{ "special|church|3", "church", "Town Centre", "", -220, -230, 40, 40, 90, 0, 0, 1, 1, 40, false, false },
	{ "special|pub|4", "pub", "Town Centre", "", -50, -87, 30, 40, 30, 0, 0, 1, 1, 30, false, false },
	{ "special|pub|5", "pub", "Town Centre", "", 87, -50, 30, 40, 30, 0, 0, 1, 1, 30, false, false },
	{ "special|pub|6", "pub", "Town Centre", "", -385, 41, 50, 40, 30, 0, 0, 1, 1, 50, false, false },
	{ "special|pub|7", "pub", "Town Centre", "", -183, -59, 30, 40, 30, 0, 0, 1, 1, 30, false, false },
	{ "special|pub|8", "pub", "Town Centre", "", -117, -54, 30, 40, 30, 0, 0, 1, 1, 30, false, false },
	{ "special|school|9", "school", "Town Centre", "", -250, 310, 120, 40, 60, 0, 0, 1, 1, 120, false, false },
	{ "special|pub|10", "pub", "Town Centre", "", -365, 95, 30, 40, 30, 0, 0, 1, 1, 30, false, false },
	{ "special|school|11", "school", "Northfields", "", -1100, -750, 140, 40, 90, 0, 0, 1, 1, 140, false, false },
	{ "special|shops|15", "shops", "Northfields", "", 75, -645, 110, 40, 30, 0, 0, 1, 1, 110, false, false },
	{ "special|shops|16", "shops", "Northfields", "", -75, -555, 110, 40, 30, 0, 0, 1, 1, 110, false, false },
	{ "special|pub and cafes|17", "pub and cafes", "Riverside", "", 560, 130, 120, 40, 40, 0, 0, 1, 1, 120, false, false },
	{ "special|waterfront flats|18", "waterfront flats", "Riverside", "", 600, 214, 140, 40, 40, 0, 0, 1, 1, 140, false, false },
	{ "special|park cafe|22", "park cafe", "Riverside Park", "", 1050, -120, 40, 40, 30, 0, 0, 1, 1, 40, false, false },
	{ "special|pub|24", "pub", "Station", "", -668, -330, 30, 40, 30, 0, 0, 1, 1, 30, false, false },
	{ "special|builders yard|25", "builders yard", "Industrial Estate", "", -1650, 20, 160, 40, 90, 0, 0, 1, 1, 160, false, false },
	{ "special|school|26", "school", "Westdale", "", -1110, 1025, 140, 40, 90, 0, 0, 1, 1, 140, false, false },
	{ "special|sports hall|31", "sports hall", "Community Sports Centre", "", 220, 1300, 120, 40, 80, 0, 0, 1, 1, 120, false, false },
}
-- FIXTURE END

local function fromRow(r: { any }): Lot
	return {
		id = r[1], use = r[2], district = r[3], street = r[4],
		centre = Vector3.new(r[5], 0, r[6]), size = Vector3.new(r[7], r[8], r[9]), yaw = r[10],
		front = Vector3.new(r[11], 0, r[12]), units = r[13], unitWidth = r[14],
		closesStreet = r[15], corner = r[16],
	}
end

local function distToRoads(p: Vector3, roads: { any }): number
	local best = math.huge
	for _, road in roads do
		local pts = road.points
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
			local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
			best = math.min(best, (ap - ab * t).Magnitude)
		end
	end
	return best
end

-- Special blocks carry no `front`. Keep the block's long axis and face whichever long side is
-- nearer a road, so pubs and schools do not turn their backs on the street.
local function specialLots(layout: any): { Lot }
	local out: { Lot } = {}
	local n = 0
	for _, district in layout.DISTRICTS do
		for _, block in district.blocks do
			if TradeRecipes.SPECIAL_USES[block.use] then
				n += 1
				local yaw = math.rad(block.yaw or 0)
				local front = Vector3.new(-math.sin(yaw), 0, math.cos(yaw))
				local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
				if layout.ROADS then
					local reach = front * (block.size.Z / 2)
					if distToRoads(centre - reach, layout.ROADS) < distToRoads(centre + reach, layout.ROADS) then
						front = -front
					end
				end
				table.insert(out, {
					id = ("special|%s|%s|%d"):format(block.use, district.name, n),
					use = block.use, district = district.name, street = "",
					centre = centre, size = Vector3.new(block.size.X, 40, block.size.Z), yaw = block.yaw or 0,
					front = front, units = 1, unitWidth = block.size.X, closesStreet = false, corner = false,
				})
			end
		end
	end
	return out
end

-- Every lot this lane builds: frontage lots of its uses plus the building-type specials.
-- `frontage` is TownFrontage and `layout` is TownLayout; either may be nil (or still a stub), in
-- which case that half comes from the fixture.
function TradeRecipes.lots(frontage: any?, layout: any?): { Lot }
	local out: { Lot } = {}
	local liveLots = type(frontage) == "table" and type(frontage.generate) == "function"
	local liveSpecials = type(layout) == "table" and type(layout.DISTRICTS) == "table"
	if liveLots then
		for _, lot in frontage.generate() do
			if TradeRecipes.USES[lot.use] then
				table.insert(out, lot)
			end
		end
	end
	if liveSpecials then
		for _, lot in specialLots(layout) do
			table.insert(out, lot)
		end
	end
	for _, r in FIXTURE do
		local special = string.sub(r[1], 1, 8) == "special|"
		if (special and not liveSpecials) or (not special and not liveLots) then
			table.insert(out, fromRow(r))
		end
	end
	return out
end

return TradeRecipes
