--!strict
-- Client quality level (backlog C3.2). Pure: no services, so it can be
-- unit-tested and required from anywhere. QualityController.client.luau
-- picks the level, publishes it as the LocalPlayer attribute "Quality"
-- ("High" | "Low") and hides decoration on Low; other client scripts read
-- that attribute and use the matching budget row below.
--
-- Decoration is recognised from what the builders already set, so no
-- builder had to change:
--   * part names (trailing digits ignored: "Pots3", "Pallet2") -- chimney
--     pots, pallets, sand heaps, planters, flowers, bollards, hedges, soil,
--     and backdrop tree top crowns ("CanopyTop");
--   * whole models by name -- moored boats, station taxis, market stalls,
--     square planters;
--   * KitPlacer models whose "Kit" attribute is a small street prop
--     (bins, benches, parked cars);
--   * an explicit Decor = true attribute on the part or any ancestor, for
--     future builders that want to opt in.
-- The controller only scans workspace.Town and workspace.Backdrop, so a
-- name like "Hedge" never hides the club grounds (Scenery has one too).
--
-- Textures: the seamless filler tiles on backs, gable ends and roofs are
-- hidden on Low (the builders' plain material shows through, the same as
-- when an upload is missing); fronts, shop fascias and signs stay.

local Quality = {}

export type Level = "High" | "Low"

export type Budget = {
	maxCars: number, -- Traffic.client.luau pool size
	banners: number, -- TownLife.client.luau lamp banners at once
	buntingStrings: number, -- TownLife.client.luau matchday bunting crossings
	pedestrians: number, -- reserved for a future pedestrians script
}

local HIGH: Level = "High"
local LOW: Level = "Low"

Quality.ATTRIBUTE = "Quality" -- LocalPlayer attribute name
Quality.LEVELS = { HIGH, LOW }
Quality.DEFAULT = HIGH

-- TEMP numbers, tune on a real mid-range phone. High matches the values the
-- scripts shipped with before this toggle existed.
Quality.BUDGETS = {
	High = { maxCars = 24, banners = 60, buntingStrings = 40, pedestrians = 30 },
	Low = { maxCars = 8, banners = 20, buntingStrings = 12, pedestrians = 12 },
} :: { [Level]: Budget }

-- Part names (after stripping trailing digits) that are pure decoration.
Quality.DECOR_PART_NAMES = {
	Pots = true, -- TerraceBuilder / EstateBuilder chimney pots
	Pallet = true, -- EstateBuilder shed yards
	SandHeap = true, -- EstateBuilder builders yard
	Planter = true, -- RiverDresser / StationDresser planter boxes
	Flowers = true, -- planter tops (river, square, station)
	Soil = true, -- SquareDresser planter soil
	Bollard = true, -- SquareDresser / StationDresser
	Hedge = true, -- EstateBuilder front gardens, Backdrop field hedgerows
	CanopyTop = true, -- Backdrop tree second crown (far detail)
	ForkliftBody = true, -- EstateBuilder shed yard forklift (X55)
	ForkliftSeat = true, -- EstateBuilder shed yard forklift (X55)
	ForkliftGuardPost = true, -- EstateBuilder shed yard forklift (X55)
	ForkliftGuardRoof = true, -- EstateBuilder shed yard forklift (X55)
	ForkliftMast = true, -- EstateBuilder shed yard forklift (X55)
	ForkliftForks = true, -- EstateBuilder shed yard forklift (X55)
	ForkliftWheels = true, -- EstateBuilder shed yard forklift (X55)
} :: { [string]: boolean }

-- Model names whose whole contents are decoration.
Quality.DECOR_MODEL_NAMES = {
	Boat = true, -- RiverDresser moorings
	Taxi = true, -- StationDresser taxi rank
	MarketStall = true, -- SquareDresser
	Planter = true, -- SquareDresser planter model
} :: { [string]: boolean }

-- KitPlacer "Kit" attribute values that are small street props.
Quality.DECOR_KITS = {
	UKSP__LitterBin__LitterBin = true,
	UKSP__ParkBenches__ParkBench01 = true,
	HatchbackOrange = true,
	HatchbackWhite = true,
	VanWhite = true,
} :: { [string]: boolean }

-- Texture instance names (the builders name each Texture after its key)
-- that are seamless filler rather than a facade or sign.
Quality.FILLER_TEXTURES = {
	brick = true,
	brick_buff = true,
	slate = true,
	back = true,
	semi_side = true,
	roof_tiles = true,
	shed_cladding = true,
} :: { [string]: boolean }

local MAX_ANCESTOR_DEPTH = 8

-- Anything that isn't exactly "Low" (nil, typos, old values) counts as High.
function Quality.normalize(value: any): Level
	if value == "Low" then
		return LOW
	end
	return HIGH
end

function Quality.other(level: Level): Level
	return if level == LOW then HIGH else LOW
end

-- TEMP default: phones/tablets without a keyboard start on Low.
function Quality.defaultFor(touchEnabled: boolean, keyboardEnabled: boolean): Level
	if touchEnabled and not keyboardEnabled then
		return LOW
	end
	return HIGH
end

function Quality.budget(level: any): Budget
	return Quality.BUDGETS[Quality.normalize(level)]
end

-- "Pots3" -> "Pots", "Pallet12" -> "Pallet", "Hedge" -> "Hedge".
function Quality.baseName(name: string): string
	return (name:gsub("%d+$", ""))
end

function Quality.isFillerTexture(inst: Instance): boolean
	return inst:IsA("Texture") and Quality.FILLER_TEXTURES[inst.Name] == true
end

-- True for a BasePart that is pure decoration (see the header).
function Quality.isDecorative(inst: Instance): boolean
	if not inst:IsA("BasePart") then
		return false
	end
	if inst:GetAttribute("Decor") == true then
		return true
	end
	if Quality.DECOR_PART_NAMES[Quality.baseName(inst.Name)] then
		return true
	end
	local node = inst.Parent
	local depth = 0
	while node and depth < MAX_ANCESTOR_DEPTH do
		if node:GetAttribute("Decor") == true then
			return true
		end
		if node:IsA("Model") then
			if Quality.DECOR_MODEL_NAMES[node.Name] then
				return true
			end
			local kit = node:GetAttribute("Kit")
			if type(kit) == "string" and Quality.DECOR_KITS[kit] then
				return true
			end
		end
		node = node.Parent
		depth += 1
	end
	return false
end

return Quality
