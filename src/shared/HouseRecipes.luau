--!strict
-- Rivermere v3, Lane H. PURE data + selection for houses assembled from the Modular English
-- Housing (MEH) kit. No Instances are created here; HouseAssembler turns a recipe into meshes.
--
-- Kit facts measured in Studio 2026-09-20 (see docs/TOWN_V3_HANDOFFS.md, Lane H):
--   * module grid is 8.25 studs (3 m at 2.75 studs/m): walls are 8.25 or 16.5 wide, a storey is
--     8.25 high, Roof_A is one 8.25 slope module, Roof_Wall_Full is the gable for a 16.5 deep body
--   * every piece pivots at its bounding-box bottom centre; at yaw 0 the EXTERIOR face looks
--     down -Z (the same way the prefab houses face). Walls are single-sided.
--   * 67 of the 68 modular pieces were uploaded WITHOUT textures. They share the prefab houses'
--     trim sheet UVs, so the assembler clones the SurfaceAppearance of House_02 ts1 / ts3 on.
--     That also gives every recipe two trims (dark brick, pale render) for free.
--
-- SCALE vs MODULE COUNT (the decision the brief asks for):
--   A lot gives each house 18-21 studs of frontage (unitWidth minus the row gap) and 24-26 of
--   depth. A body of 2 x 2 modules is 16.5 x 16.5, so one uniform scale of about 1.25 fills the
--   width, leaves a 3-5 stud back yard, makes a storey 10.3 and a door 6.6 studs tall (right for
--   a 5-5.5 stud avatar). Three modules would need scale 0.84 (4.4 stud doors) and 50% more
--   parts. So: ALWAYS 2 modules wide, scale = unit width / 16.5, clamped.
--
-- Recipe space: unscaled kit studs, origin at ground level in the centre of the 16.5 x 16.5
-- body, +X along the street, -Z towards the street (front wall at z = -8.25).

local HouseRecipes = {}

export type Piece = {
	piece: string, -- MEH short name, e.g. "Wall_Door_A" (assembler adds "MEH__" and the "__ts" suffix)
	offset: Vector3, -- bottom centre of the piece's bounding box
	yaw: number, -- degrees
	role: string, -- front | door | canopy | back | roof | chimney | side | gable | prefab
	tier: number, -- 1 shell, 2 detail (chimneys, canopies). The assembler can drop tiers.
	scale: number?, -- extra uniform scale on top of the unit scale
	stretchX: number?, -- non-uniform stretch along the piece's own X (roofs spanning 2 modules)
	once: boolean?, -- skipped on the mirrored half of a semi pair
}

export type Recipe = {
	id: string,
	kind: "terraced" | "semi" | "detached",
	body: Vector3, -- X width, Y height, Z depth of the body in unscaled studs
	doorX: number, -- where the front door is, for the garden gate gap
	prefab: boolean?, -- one textured prefab mesh; the trim picks the "__ts1"/"__ts3" asset
	ends: boolean?, -- true when the recipe already closes its own sides (detached, prefab)
	weight: number?, -- how many tickets this recipe gets in the draw (default 1)
	pieces: { Piece },
}

local M = 8.25 -- module width and storey height
local H = M / 2
HouseRecipes.MODULE = M
HouseRecipes.BODY = Vector3.new(2 * M, 2 * M + 5.5, 2 * M)
HouseRecipes.SCALE_MIN = 0.85
HouseRecipes.SCALE_MAX = 1.35
HouseRecipes.TRIMS = { "ts1", "ts3" }

-- Bounding sizes of the pieces recipes use (X, Y, Z), from the Studio inventory. Used by the
-- fit test and by nothing else.
HouseRecipes.PIECE_SIZE = {
	Wall_A = Vector3.new(8.25, 8.25, 0.05),
	Wall_Door_A = Vector3.new(8.25, 8.25, 0.5),
	Wall_Door_B = Vector3.new(8.25, 8.25, 0.5),
	Wall_Door_C = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_A = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_B = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_C = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_D = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_E = Vector3.new(8.25, 8.25, 0.4),
	Wall_Window_F = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_G = Vector3.new(8.25, 8.25, 0.5),
	Wall_Window_H = Vector3.new(8.25, 8.25, 1.2),
	Wall_WindowDoor_A = Vector3.new(16.5, 8.25, 0.5),
	Wall_WindowDoor_B = Vector3.new(16.5, 8.25, 0.5),
	Wall_WindowCentre_A = Vector3.new(16.5, 8.25, 2.0),
	Wall_WindowCentre_B = Vector3.new(16.5, 8.25, 0.5),
	Door_A = Vector3.new(2.3, 5.3, 0.2),
	Door_B = Vector3.new(2.3, 5.3, 0.2),
	Door_C = Vector3.new(2.3, 5.3, 0.2),
	Door_Canopy_A = Vector3.new(4.2, 3.6, 1.7),
	Door_Canopy_B = Vector3.new(3.7, 3.0, 1.8),
	Roof_A = Vector3.new(8.25, 5.5, 8.6),
	Roof_Wall_Full_A = Vector3.new(17.3, 5.5, 0.4),
	Roof_Wall_Full_B = Vector3.new(17.3, 5.5, 0.6),
	Chimney_A = Vector3.new(1.8, 4.1, 1.8),
	House_02_VAR1 = Vector3.new(17.3, 22.8, 26.9),
}

local FRONT_Z = -M
local BACK_Z = M

-- The wall plane sits behind the bounding-box centre on pieces with a bay or deep sill.
local function frontZ(piece: string): number
	local size = HouseRecipes.PIECE_SIZE[piece]
	local depth = if size then size.Z else 0.5
	return FRONT_Z - math.max(0, (depth - 0.5) / 2)
end

local function front(piece: string, x: number, storey: number): Piece
	return { piece = piece, offset = Vector3.new(x, storey * M, frontZ(piece)), yaw = 0, role = "front", tier = 1 }
end

local function door(piece: string, x: number): Piece
	return { piece = piece, offset = Vector3.new(x, 0, FRONT_Z + 0.2), yaw = 0, role = "door", tier = 1 }
end

local function canopy(piece: string, x: number): Piece
	return { piece = piece, offset = Vector3.new(x, 5.0, FRONT_Z - 0.85), yaw = 0, role = "canopy", tier = 2 }
end

local function chimney(x: number, once: boolean?): Piece
	return {
		piece = "Chimney_A",
		offset = Vector3.new(x, 2 * M + 4.2, 0),
		yaw = 0,
		role = "chimney",
		tier = 2,
		scale = 1.4,
		once = once,
	}
end

-- Back wall (one plain wall at double scale covers 2 modules x 2 storeys) and a two-slope roof
-- with each slope stretched across both modules: 3 parts for the whole rear and top of a unit.
local function shell(): { Piece }
	return {
		{ piece = "Wall_A", offset = Vector3.new(0, 0, BACK_Z), yaw = 180, role = "back", tier = 1, scale = 2 },
		{ piece = "Roof_A", offset = Vector3.new(0, 2 * M, -H - 0.17), yaw = 0, role = "roof", tier = 1, stretchX = 2 },
		{ piece = "Roof_A", offset = Vector3.new(0, 2 * M, H + 0.17), yaw = 180, role = "roof", tier = 1, stretchX = 2 },
	}
end

-- One gable end. side = -1 closes the -X end, +1 the +X end. `windowed` is the street-facing
-- gable used on corner lots: four modules with windows instead of one blank double-scale wall.
function HouseRecipes.endCap(side: number, windowed: boolean): { Piece }
	local x = side * M
	local yaw = if side < 0 then 90 else -90
	local pieces: { Piece } = {
		{ piece = "Roof_Wall_Full_A", offset = Vector3.new(x, 2 * M, 0), yaw = yaw, role = "gable", tier = 1 },
	}
	if windowed then
		table.insert(pieces, { piece = "Wall_Window_B", offset = Vector3.new(x, 0, -H), yaw = yaw, role = "side", tier = 1 })
		table.insert(pieces, { piece = "Wall_A", offset = Vector3.new(x, 0, H), yaw = yaw, role = "side", tier = 1 })
		table.insert(pieces, { piece = "Wall_Window_C", offset = Vector3.new(x, M, -H), yaw = yaw, role = "side", tier = 1 })
		table.insert(pieces, { piece = "Wall_A", offset = Vector3.new(x, M, H), yaw = yaw, role = "side", tier = 1 })
	else
		table.insert(pieces, { piece = "Wall_A", offset = Vector3.new(x, 0, 0), yaw = yaw, role = "side", tier = 1, scale = 2 })
	end
	return pieces
end

local function concat(...: { Piece }): { Piece }
	local out: { Piece } = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(out, p)
		end
	end
	return out
end

local function recipe(id: string, kind: any, doorX: number, fronts: { Piece }, extras: { Piece }?, ends: boolean?): Recipe
	local pieces = concat(fronts, shell(), extras or {})
	if ends then
		pieces = concat(pieces, HouseRecipes.endCap(-1, true), HouseRecipes.endCap(1, false))
	end
	return { id = id, kind = kind, body = HouseRecipes.BODY, doorX = doorX, ends = ends, pieces = pieces }
end

local RECIPES: { Recipe } = {
	------------------------------------------------------------------ terraced (10)
	recipe("T01_plain", "terraced", 0, { front("Wall_WindowDoor_A", 0, 0), front("Wall_WindowCentre_B", 0, 1), door("Door_A", 0) }, { chimney(7) }),
	recipe("T02_bay", "terraced", 0, { front("Wall_WindowDoor_B", 0, 0), front("Wall_WindowCentre_A", 0, 1), door("Door_B", 0) }, { chimney(-7) }),
	recipe("T03_door_left", "terraced", -H, { front("Wall_Door_A", -H, 0), front("Wall_Window_B", H, 0), front("Wall_Window_C", -H, 1), front("Wall_Window_C", H, 1), door("Door_C", -H) }, { chimney(7) }),
	recipe("T04_door_right", "terraced", H, { front("Wall_Window_D", -H, 0), front("Wall_Door_B", H, 0), front("Wall_Window_D", -H, 1), front("Wall_Window_D", H, 1), door("Door_A", H) }),
	recipe("T05_canopy", "terraced", 0, { front("Wall_WindowDoor_A", 0, 0), front("Wall_Window_E", -H, 1), front("Wall_Window_E", H, 1), door("Door_B", 0) }, { canopy("Door_Canopy_A", 0), chimney(-7) }),
	recipe("T06_left_canopy", "terraced", -H, { front("Wall_Door_C", -H, 0), front("Wall_Window_F", H, 0), front("Wall_WindowCentre_B", 0, 1), door("Door_A", -H) }, { canopy("Door_Canopy_B", -H) }),
	recipe("T07_mixed_upper", "terraced", 0, { front("Wall_WindowDoor_B", 0, 0), front("Wall_Window_G", -H, 1), front("Wall_Window_B", H, 1), door("Door_C", 0) }, { chimney(7) }),
	recipe("T08_deep_sill", "terraced", H, { front("Wall_Window_H", -H, 0), front("Wall_Door_A", H, 0), front("Wall_WindowCentre_A", 0, 1), door("Door_B", H) }, { chimney(-7) }),
	recipe("T09_tall_lights", "terraced", -H, { front("Wall_Door_B", -H, 0), front("Wall_Window_C", H, 0), front("Wall_Window_F", -H, 1), front("Wall_Window_G", H, 1), door("Door_C", -H) }),
	recipe("T10_bay_plain", "terraced", 0, { front("Wall_WindowDoor_A", 0, 0), front("Wall_WindowCentre_A", 0, 1), door("Door_A", 0) }, { canopy("Door_Canopy_B", 0), chimney(7) }),

	------------------------------------------------------------------ semis (4): door on the OUTER side, the pair mirrors
	recipe("S01_plain", "semi", -H, { front("Wall_Door_A", -H, 0), front("Wall_Window_D", H, 0), front("Wall_WindowCentre_B", 0, 1), door("Door_A", -H) }, { chimney(7.2, true) }),
	recipe("S02_bay", "semi", -H, { front("Wall_Door_B", -H, 0), front("Wall_Window_H", H, 0), front("Wall_WindowCentre_A", 0, 1), door("Door_B", -H) }, { canopy("Door_Canopy_A", -H), chimney(7.2, true) }),
	recipe("S03_four_lights", "semi", -H, { front("Wall_Door_C", -H, 0), front("Wall_Window_E", H, 0), front("Wall_Window_E", -H, 1), front("Wall_Window_E", H, 1), door("Door_C", -H) }, { canopy("Door_Canopy_B", -H), chimney(7.2, true) }),
	recipe("S04_wide_lower", "semi", -H, { front("Wall_Door_A", -H, 0), front("Wall_Window_F", H, 0), front("Wall_Window_G", -H, 1), front("Wall_Window_C", H, 1), door("Door_B", -H) }, { chimney(7.2, true) }),

	------------------------------------------------------------------ detached (4 modular + 1 prefab in two trims)
	recipe("D01_villa", "detached", 0, { front("Wall_WindowDoor_A", 0, 0), front("Wall_WindowCentre_B", 0, 1), door("Door_A", 0) }, { canopy("Door_Canopy_A", 0), chimney(-7), chimney(7) }, true),
	recipe("D02_bay_villa", "detached", 0, { front("Wall_WindowDoor_B", 0, 0), front("Wall_WindowCentre_A", 0, 1), door("Door_B", 0) }, { canopy("Door_Canopy_B", 0), chimney(7) }, true),
	recipe("D03_side_door", "detached", H, { front("Wall_Window_H", -H, 0), front("Wall_Door_B", H, 0), front("Wall_Window_F", -H, 1), front("Wall_Window_F", H, 1), door("Door_C", H) }, { canopy("Door_Canopy_A", H), chimney(-7) }, true),
	recipe("D04_cottage", "detached", -H, { front("Wall_Door_C", -H, 0), front("Wall_Window_E", H, 0), front("Wall_Window_E", -H, 1), front("Wall_Window_E", H, 1), door("Door_A", -H) }, { chimney(-7), chimney(7) }, true),
	{
		id = "D05_prefab_02",
		kind = "detached",
		body = Vector3.new(17.3, 22.8, 26.9),
		doorX = 0,
		prefab = true,
		ends = true,
		weight = 3, -- one MeshPart instead of 12: section 9 wants detached houses mostly prefab
		pieces = { { piece = "House_02_VAR1", offset = Vector3.new(0, 0, 0), yaw = 0, role = "prefab", tier = 1 } },
	},
}

HouseRecipes.RECIPES = RECIPES

local USE_KIND: { [string]: string } = {
	["terraced row"] = "terraced",
	["semis"] = "semi",
	["detached house"] = "detached",
}
HouseRecipes.USE_KIND = USE_KIND

local byKind: { [string]: { Recipe } } = {}
local drawByKind: { [string]: { Recipe } } = {}
for _, r in RECIPES do
	byKind[r.kind] = byKind[r.kind] or {}
	drawByKind[r.kind] = drawByKind[r.kind] or {}
	table.insert(byKind[r.kind], r)
	for _ = 1, r.weight or 1 do
		table.insert(drawByKind[r.kind], r)
	end
end

function HouseRecipes.forKind(kind: string): { Recipe }
	return byKind[kind] or {}
end

-- djb2, kept inside 31 bits so it is identical on every platform.
function HouseRecipes.hash(text: string): number
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 2147483648
	end
	return h
end

function HouseRecipes.trimFor(lotId: string): string
	local trims = HouseRecipes.TRIMS
	return trims[HouseRecipes.hash(lotId .. "#trim") % #trims + 1]
end

-- Deterministic pick for one unit. `avoid` is the recipe id of the neighbour already chosen, so
-- two identical fronts never sit side by side in a terrace.
function HouseRecipes.select(kind: string, lotId: string, unitIndex: number, avoid: string?): Recipe
	local list = drawByKind[kind]
	assert(list and #list > 0, "no recipes for kind " .. tostring(kind))
	local index = HouseRecipes.hash(lotId .. "#" .. tostring(unitIndex)) % #list + 1
	for _ = 1, #list do
		if not (avoid and list[index].id == avoid) then
			break
		end
		index = index % #list + 1
	end
	return list[index]
end

export type UnitPlan = { recipe: Recipe, mirrored: boolean }

-- Every unit of a lot. Semis share one recipe per pair and mirror the second half.
function HouseRecipes.planLot(use: string, lotId: string, units: number): { UnitPlan }
	local kind = USE_KIND[use]
	assert(kind, "not a housing use: " .. tostring(use))
	local plans: { UnitPlan } = {}
	local previous: string? = nil
	for i = 1, units do
		if kind == "semi" then
			local pairIndex = math.floor((i - 1) / 2) + 1
			local r = HouseRecipes.select(kind, lotId, pairIndex, nil)
			table.insert(plans, { recipe = r, mirrored = (i % 2 == 0) })
		else
			local r = HouseRecipes.select(kind, lotId, i, previous)
			previous = r.id
			table.insert(plans, { recipe = r, mirrored = false })
		end
	end
	return plans
end

-- Pieces of a recipe, mirrored across the unit's centre line when asked (x and yaw negate; the
-- kit pieces themselves are left/right symmetric enough for this to read correctly).
function HouseRecipes.pieces(recipe: Recipe, mirrored: boolean): { Piece }
	if not mirrored then
		return recipe.pieces
	end
	local out: { Piece } = {}
	for _, p in recipe.pieces do
		if not p.once then
			local copy = table.clone(p)
			copy.offset = Vector3.new(-p.offset.X, p.offset.Y, p.offset.Z)
			copy.yaw = -p.yaw
			table.insert(out, copy)
		end
	end
	return out
end

-- Uniform scale that fits a recipe body into a unit box of `width` x `depth`.
function HouseRecipes.scaleFor(recipe: Recipe, width: number, depth: number): number
	local s = math.min(width / recipe.body.X, depth / recipe.body.Z)
	if recipe.prefab then
		return s
	end
	return math.clamp(s, HouseRecipes.SCALE_MIN, HouseRecipes.SCALE_MAX)
end

-- Front garden boundary styles. `length` is the native length along X, `parts` the MeshParts in
-- one piece. Single-part pieces are stretched to the run; multi-part ones are uniformly scaled.
--
-- Section 9 caps a boundary piece at 1,000 triangles. Measured 2026-09-20 (V3Perf, Edit mode):
--   GardenWallA WithFence 512, WithoutFence 260, GardenWallB WithoutRailing 912,
--   MEH Wood_Fence_A 352, MEH Railing_A 64  -> allowed
--   RailingWall__Wall 1,144 and GardenWallB WithRailing 1,320 -> just over, Tier A only
--   GardenWall__Wall 3,620, WoodFences Fence01-05 ~8,000, TrashBags ~11,400 -> NOT used
-- `light` styles are the ones Tier B may use: at most 2 MeshParts a piece and under the cap.
export type GardenStyle = { id: string, piece: string, length: number, parts: number, scale: number?, light: boolean?, trim: boolean? }
HouseRecipes.GARDEN_STYLES = {
	{ id = "brick_fence", piece = "UKSP__GardenWallA__GardenWallAWithFence", length = 5.7, parts = 3 },
	{ id = "brick_low", piece = "UKSP__GardenWallA__GardenWallAWithoutFence", length = 5.7, parts = 2, light = true },
	{ id = "brick_b", piece = "UKSP__GardenWallB__WallBStraightWithoutRailing", length = 5.6, parts = 2, light = true },
	{ id = "brick_railing", piece = "UKSP__GardenWallB__WallBStraightWithRailing", length = 5.6, parts = 3 },
	{ id = "railing_wall", piece = "UKSP__RailingWall__Wall", length = 8.2, parts = 2 },
	{ id = "iron_railing", piece = "MEH__Railing_A__ts1", length = 2.8, parts = 1, scale = 1.3, light = true, trim = true },
	{ id = "wood", piece = "MEH__Wood_Fence_A__ts1", length = 5.5, parts = 1, scale = 0.65, light = true, trim = true },
	{ id = "hedge", piece = "HedgeLong", length = 19, parts = 2, scale = 0.42 },
} :: { GardenStyle }

function HouseRecipes.gardenStyleFor(lotId: string, unitIndex: number, lightOnly: boolean?): GardenStyle
	local styles = HouseRecipes.GARDEN_STYLES
	if lightOnly then
		local light = {}
		for _, style in styles do
			if style.light then
				table.insert(light, style)
			end
		end
		styles = light
	end
	return styles[HouseRecipes.hash(lotId .. "#garden" .. tostring(unitIndex)) % #styles + 1]
end

-- Back yards: the MEH close-board fence (352 triangles, 1 MeshPart) and a wheelie bin. The UKSP
-- WoodFences and TrashBags the brief names are 8-11k triangles each and fail the section 9 cap.
HouseRecipes.BACK_FENCE = { id = "back", piece = "MEH__Wood_Fence_A__ts1", length = 5.5, parts = 1, trim = true } :: GardenStyle
HouseRecipes.BIN = { base = "UKSP__TrachCan__TrashcanBase", lid = "UKSP__TrachCan__TrashcanLid", lidHeight = 2.75 }
HouseRecipes.GATE_GAP = 3.4

return HouseRecipes
