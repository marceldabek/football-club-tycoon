--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeRecipes = require(ReplicatedStorage.Shared.TradeRecipes)

local T = {}

-- Both inputs are checked: the built-in fixture, and the live TownFrontage / TownLayout data.
local function lots()
	local out = TradeRecipes.lots(nil, nil)
	local okF, frontage = pcall(require, ReplicatedStorage.Shared.TownFrontage)
	local okL, layout = pcall(require, ReplicatedStorage.Shared.TownLayout)
	for _, lot in TradeRecipes.lots(if okF then frontage else nil, if okL then layout else nil) do
		table.insert(out, lot)
	end
	return out
end

function T.fixtureCoversEveryUseAndTheSpecials()
	local byUse: { [string]: number } = {}
	for _, lot in lots() do
		byUse[lot.use] = (byUse[lot.use] or 0) + 1
	end
	for use in TradeRecipes.USES do
		assert((byUse[use] or 0) > 0, "no lots with use " .. use)
	end
	for _, use in { "pub", "church", "town hall", "school", "supermarket" } do
		assert((byUse[use] or 0) > 0, "no special with use " .. use)
	end
end

function T.everyLotGetsARecipeWithPieces()
	for _, lot in lots() do
		local recipe = TradeRecipes.recipeFor(lot)
		assert(recipe.kind ~= "none", "no recipe for use " .. lot.use)
		assert(#recipe.pieces > 0, "empty recipe for " .. lot.id)
	end
end

function T.everyPieceNamesAMeasuredKitAsset()
	for _, lot in lots() do
		for _, piece in TradeRecipes.recipeFor(lot).pieces do
			assert(TradeRecipes.SIZES[piece.kit], piece.kit .. " is not in TradeRecipes.SIZES")
		end
	end
end

function T.recipesFitTheirLotBox()
	local slack = 1 -- studs: module rounding (8.25 x 15 = 123.75 on a 124 lot) and eaves
	for _, lot in lots() do
		local lo, hi = TradeRecipes.bounds(TradeRecipes.recipeFor(lot))
		local hx, hz = lot.size.X / 2 + slack, lot.size.Z / 2 + slack
		assert(lo.X >= -hx and hi.X <= hx, ("%s is %.1f..%.1f wide on a %.0f lot"):format(lot.id, lo.X, hi.X, lot.size.X))
		assert(lo.Z >= -hz and hi.Z <= hz, ("%s is %.1f..%.1f deep on a %.0f lot"):format(lot.id, lo.Z, hi.Z, lot.size.Z))
		assert(lo.Y >= -0.01, lot.id .. " goes below ground")
		if lot.use ~= "church" then
			assert(hi.Y <= lot.size.Y + slack, ("%s is %.1f tall, lot allows %.0f"):format(lot.id, hi.Y, lot.size.Y))
		end
	end
end

-- A corner shop ends a terrace built from the same modules at ~1.25, so it is never
-- built under kit size (it was a prefab shrunk to 0.87: doors shorter than a person).
function T.cornerShopsAreBuiltAtLeastFullSize()
	local seen = 0
	for _, lot in lots() do
		if lot.use == "corner shop" then
			seen += 1
			local recipe = TradeRecipes.recipeFor(lot)
			for _, p in recipe.pieces do
				assert(p.fit or (p.scale or 1) >= 1, ("%s has %s at scale %.2f"):format(lot.id, p.kit, p.scale or 1))
			end
			local _, hi = TradeRecipes.bounds(recipe)
			assert(hi.Y >= 20, ("%s is only %.1f tall"):format(lot.id, hi.Y))
		end
	end
	assert(seen > 0, "no corner shop lots in the fixture")
end

function T.shopfrontsSitAtTheStreetEdge()
	for _, lot in lots() do
		if lot.use == "shops with flats" or lot.use == "shops" then
			local lo = TradeRecipes.bounds(TradeRecipes.recipeFor(lot))
			assert(lo.Z < -lot.size.Z / 2 + 4, lot.id .. " shopfront is set back from the street")
		end
	end
end

function T.recipesAreDeterministic()
	for _, lot in lots() do
		local a, b = TradeRecipes.recipeFor(lot), TradeRecipes.recipeFor(lot)
		assert(#a.pieces == #b.pieces, lot.id .. " piece count changed between calls")
		for i, p in a.pieces do
			local q = b.pieces[i]
			assert(p.kit == q.kit and p.pos == q.pos and p.yaw == q.yaw, lot.id .. " piece " .. i .. " changed between calls")
		end
	end
end

function T.everyStandInNamesItsRegisterRow()
	for _, lot in lots() do
		local recipe = TradeRecipes.recipeFor(lot)
		if recipe.kind ~= "flats" then
			assert(recipe.gap and string.match(recipe.gap, "^EC%d$"), lot.id .. " has no register id")
		end
	end
end

function T.pieceCountsStayInsideTheLanePAllowance()
	-- Section 9: 12 MeshParts per commercial unit, 40 per special block, 4,000 for the town.
	-- Every recipe piece is one MeshPart except the church keeper (0) and four 2-4 part props.
	local total = 0
	local okF, frontage = pcall(require, ReplicatedStorage.Shared.TownFrontage)
	local okL, layout = pcall(require, ReplicatedStorage.Shared.TownLayout)
	for _, lot in TradeRecipes.lots(if okF then frontage else nil, if okL then layout else nil) do
		local n = #TradeRecipes.recipeFor(lot).pieces
		total += n
		if string.sub(lot.id, 1, 8) == "special|" then
			assert(n <= 60, ("%s uses %d pieces; specials average 40"):format(lot.id, n))
		elseif lot.use == "shops with flats" or lot.use == "shops" then
			assert(n <= 12 * lot.units + 8, ("%s uses %d pieces for %d units"):format(lot.id, n, lot.units))
		end
	end
	assert(total <= 3600, "recipes total " .. total .. " pieces; leave headroom under the 4,000 budget")
end

return T
