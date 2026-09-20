--!strict
-- Rivermere v3, Lane H: HouseRecipes is pure data + selection, so these tests need no kit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HouseRecipes = require(ReplicatedStorage.Shared.HouseRecipes)

local tests = {}

local function countKind(kind: string): number
	return #HouseRecipes.forKind(kind)
end

function tests.enough_variety_per_kind()
	assert(countKind("terraced") >= 8, "need 8 terraced recipes, have " .. countKind("terraced"))
	assert(countKind("semi") >= 4, "need 4 semi recipes")
	assert(countKind("detached") >= 4, "need 4 detached recipes")
end

function tests.recipe_ids_are_unique_and_fronts_differ()
	local ids, signatures = {}, {}
	for _, r in HouseRecipes.RECIPES do
		assert(not ids[r.id], "duplicate recipe id " .. r.id)
		ids[r.id] = true
		local parts = {}
		for _, p in r.pieces do
			if p.role == "front" or p.role == "canopy" or p.role == "prefab" then
				table.insert(parts, ("%s@%.1f,%.1f"):format(p.piece, p.offset.X, p.offset.Y))
			end
		end
		table.sort(parts)
		local signature = r.kind .. ":" .. table.concat(parts, "|")
		assert(not signatures[signature], r.id .. " looks the same as " .. tostring(signatures[signature]))
		signatures[signature] = r.id
	end
end

function tests.every_piece_has_a_known_size()
	for _, r in HouseRecipes.RECIPES do
		for _, p in r.pieces do
			assert(HouseRecipes.PIECE_SIZE[p.piece], r.id .. " uses unsized piece " .. p.piece)
		end
	end
	for _, side in { -1, 1 } do
		for _, windowed in { true, false } do
			for _, p in HouseRecipes.endCap(side, windowed) do
				assert(HouseRecipes.PIECE_SIZE[p.piece], "end cap uses unsized piece " .. p.piece)
			end
		end
	end
end

-- Extents of one piece in recipe space (yaw is always a multiple of 90 in recipes).
local function extents(p): (number, number, number, number, number)
	local size = HouseRecipes.PIECE_SIZE[p.piece] * (p.scale or 1)
	local sx = size.X * (p.stretchX or 1)
	local sz = size.Z
	if math.abs(p.yaw) % 180 == 90 then
		sx, sz = sz, sx
	end
	return p.offset.X - sx / 2, p.offset.X + sx / 2, p.offset.Z - sz / 2, p.offset.Z + sz / 2, p.offset.Y + size.Y
end

function tests.recipes_fit_their_unit_box()
	-- Allowances: eaves and gables overhang the body by under half a stud; bays, sills and door
	-- canopies may lean up to 3 studs into the front garden (gardens are at least 6 deep).
	for _, r in HouseRecipes.RECIPES do
		local halfX, halfZ = r.body.X / 2, r.body.Z / 2
		local all = table.clone(r.pieces)
		if not r.ends then
			for _, p in HouseRecipes.endCap(-1, true) do
				table.insert(all, p)
			end
			for _, p in HouseRecipes.endCap(1, false) do
				table.insert(all, p)
			end
		end
		for _, p in all do
			local x0, x1, z0, z1, top = extents(p)
			assert(x0 >= -halfX - 0.5 and x1 <= halfX + 0.5, ("%s: %s leaves the unit width (%.2f..%.2f)"):format(r.id, p.piece, x0, x1))
			assert(z0 >= -halfZ - 3 and z1 <= halfZ + 0.5, ("%s: %s leaves the unit depth (%.2f..%.2f)"):format(r.id, p.piece, z0, z1))
			assert(top <= r.body.Y + 6, r.id .. ": " .. p.piece .. " is too tall")
		end
	end
end

function tests.scaled_units_fit_real_lot_boxes()
	-- Real boxes from docs/town_v3_lots.json: frontage per unit is (n * cell - gap) / n.
	local boxes = {
		{ kind = "terraced", width = 124 / 6, depth = 24 },
		{ kind = "terraced", width = 36 / 2, depth = 24 },
		{ kind = "terraced", width = 146 / 7, depth = 24 },
		{ kind = "semi", width = 38 / 2, depth = 24 },
		{ kind = "detached", width = 20, depth = 26 },
	}
	for _, box in boxes do
		for _, r in HouseRecipes.forKind(box.kind) do
			local s = HouseRecipes.scaleFor(r, box.width, box.depth)
			assert(r.body.X * s <= box.width + 0.01, r.id .. " is wider than its unit")
			assert(r.body.Z * s <= box.depth + 0.01, r.id .. " is deeper than its lot")
			assert(r.body.Y * s <= 30, r.id .. " is taller than the nominal 28 (+chimney)")
			assert(s >= 0.85, r.id .. " scaled so small that doors drop under avatar height")
		end
	end
end

function tests.selection_is_deterministic()
	for _, use in { "terraced row", "semis", "detached house" } do
		local a = HouseRecipes.planLot(use, "Elm Grove|left|2|3", 6)
		local b = HouseRecipes.planLot(use, "Elm Grove|left|2|3", 6)
		assert(#a == 6 and #b == 6)
		for i = 1, 6 do
			assert(a[i].recipe.id == b[i].recipe.id and a[i].mirrored == b[i].mirrored, "plan changed between calls")
		end
	end
	assert(HouseRecipes.trimFor("x|1") == HouseRecipes.trimFor("x|1"))
	assert(HouseRecipes.hash("Rivermere") == HouseRecipes.hash("Rivermere"))
end

function tests.selection_varies_between_lots_and_neighbours()
	local seen = {}
	for n = 1, 40 do
		local plans = HouseRecipes.planLot("terraced row", "Weaver Street|right|1|" .. n, 6)
		for i, plan in plans do
			seen[plan.recipe.id] = true
			if i > 1 then
				assert(plans[i - 1].recipe.id ~= plan.recipe.id, "identical neighbours in a terrace")
			end
		end
	end
	local distinct = 0
	for _ in seen do
		distinct += 1
	end
	assert(distinct >= 8, "only " .. distinct .. " terraced recipes ever get picked")
end

function tests.semis_mirror_in_pairs()
	local plans = HouseRecipes.planLot("semis", "Smithy Close|left|1|1", 2)
	assert(plans[1].recipe.id == plans[2].recipe.id, "a semi pair shares one recipe")
	assert(plans[1].mirrored == false and plans[2].mirrored == true)
	local left = HouseRecipes.pieces(plans[1].recipe, false)
	local right = HouseRecipes.pieces(plans[2].recipe, true)
	local doorLeft, doorRight
	for _, p in left do
		if p.role == "door" then
			doorLeft = p.offset.X
		end
	end
	for _, p in right do
		if p.role == "door" then
			doorRight = p.offset.X
		end
		assert(not p.once, "once-only pieces must not be mirrored")
	end
	assert(doorLeft < 0 and doorRight > 0, "doors sit on the outer sides of the pair")
end

function tests.garden_styles_use_kit_names()
	for _, style in HouseRecipes.GARDEN_STYLES do
		assert(style.piece:sub(1, 6) == "UKSP__" or style.piece == "HedgeLong", style.id .. " is not a kit asset")
		assert(style.length > 0 and style.parts >= 1)
	end
	assert(HouseRecipes.gardenStyleFor("a", 1).id == HouseRecipes.gardenStyleFor("a", 1).id)
end

return tests
