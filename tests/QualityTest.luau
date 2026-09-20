--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Quality = require(ReplicatedStorage.Shared.Quality)

local T = {}

local function part(name: string, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Parent = parent
	return p
end

local function model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- ------------------------------------------------------------ levels

function T.normalizeOnlyLowIsLow()
	assert(Quality.normalize("Low") == "Low", "Low stays Low")
	assert(Quality.normalize("High") == "High", "High stays High")
	assert(Quality.normalize(nil) == "High", "nil is High")
	assert(Quality.normalize("low") == "High", "case-sensitive: unknown is High")
	assert(Quality.normalize(3) == "High", "non-string is High")
end

function T.otherFlips()
	assert(Quality.other("High") == "Low", "High -> Low")
	assert(Quality.other("Low") == "High", "Low -> High")
end

function T.defaultIsLowOnlyForTouchWithoutKeyboard()
	assert(Quality.defaultFor(true, false) == "Low", "phone")
	assert(Quality.defaultFor(true, true) == "High", "touch laptop")
	assert(Quality.defaultFor(false, true) == "High", "desktop")
	assert(Quality.defaultFor(false, false) == "High", "console-ish")
end

function T.levelsListBoth()
	assert(#Quality.LEVELS == 2, "two levels")
	assert(table.find(Quality.LEVELS, "High") and table.find(Quality.LEVELS, "Low"), "High and Low listed")
end

-- ------------------------------------------------------------ budgets

function T.budgetsExistForEveryLevel()
	for _, level in Quality.LEVELS do
		local b = Quality.budget(level)
		assert(b.maxCars > 0 and b.banners > 0 and b.buntingStrings > 0 and b.pedestrians > 0, level .. " budget positive")
	end
end

function T.lowBudgetNeverExceedsHigh()
	local high, low = Quality.budget("High"), Quality.budget("Low")
	assert(low.maxCars <= high.maxCars, "cars")
	assert(low.banners <= high.banners, "banners")
	assert(low.buntingStrings <= high.buntingStrings, "bunting")
	assert(low.pedestrians <= high.pedestrians, "pedestrians")
end

function T.highBudgetMatchesShippedScriptValues()
	-- Traffic MAX_CARS 24, TownLife BANNER_BUDGET 60 / BUNTING_STRING_BUDGET 40
	local high = Quality.budget("High")
	assert(high.maxCars == 24 and high.banners == 60 and high.buntingStrings == 40, "High keeps the old numbers")
	local low = Quality.budget("Low")
	assert(low.maxCars == 8 and low.banners == 20 and low.buntingStrings == 12, "Low matches the constants in Traffic/TownLife")
end

function T.budgetUnknownFallsBackToHigh()
	assert(Quality.budget(nil) == Quality.budget("High"), "nil -> High row")
	assert(Quality.budget("Ultra") == Quality.budget("High"), "unknown -> High row")
end

-- ------------------------------------------------------------ names

function T.baseNameStripsTrailingDigits()
	assert(Quality.baseName("Pots3") == "Pots", "Pots3")
	assert(Quality.baseName("Pallet12") == "Pallet", "Pallet12")
	assert(Quality.baseName("Hedge") == "Hedge", "no digits")
	assert(Quality.baseName("Post1a") == "Post1a", "digits not at the end stay")
end

-- ------------------------------------------------------------ isDecorative

function T.decorPartNamesAreDecorative()
	for _, name in { "Pots", "Pots2", "Pallet1", "SandHeap", "Flowers", "Planter", "Bollard", "Hedge", "Soil", "CanopyTop", "ForkliftBody", "ForkliftWheels", "HangingBasket", "Basket", "AerialMast", "AerialBar", "Dish", "DishBracket", "TelegraphPole", "PoleArm", "Wire", "Tactile" } do
		assert(Quality.isDecorative(part(name)), name .. " should be decorative")
	end
end

function T.terraceLampDetailIsDecorativeButPostStays()
	local lamp = model("TerraceLamp")
	for _, name in { "Base", "Arm", "Glass", "Cap" } do
		assert(Quality.isDecorative(part(name, lamp)), name .. " in a TerraceLamp should hide")
	end
	for _, name in { "Post", "Lantern" } do
		assert(not Quality.isDecorative(part(name, lamp)), name .. " in a TerraceLamp should stay")
	end
	assert(not Quality.isDecorative(part("Base", model("Stand"))), "Base elsewhere stays")
end

function T.structuralPartsAreNotDecorative()
	for _, name in { "Body", "RoofFront", "Ridge", "Stack", "Stack1", "Shopfront2", "Upper", "Post", "Canopy", "Trunk", "Yard", "Field" } do
		assert(not Quality.isDecorative(part(name)), name .. " should stay")
	end
end

function T.nonPartsAreNotDecorative()
	assert(not Quality.isDecorative(model("Pots")), "a Model itself is not hidden, its parts are")
	assert(not Quality.isDecorative(Instance.new("Folder")), "folder")
end

function T.partsInsideDecorModelsAreDecorative()
	for _, name in { "Boat", "Taxi", "MarketStall", "Planter" } do
		local m = model(name)
		assert(Quality.isDecorative(part("Body", m)), name .. " child")
	end
end

function T.nestedPartInDecorModelIsDecorative()
	local boat = model("Boat")
	local inner = model("Inner", boat)
	assert(Quality.isDecorative(part("Hull", inner)), "grandchild of Boat")
end

function T.decorKitModelsAreDecorative()
	for kit in Quality.DECOR_KITS do
		local m = model("Anything")
		m:SetAttribute("Kit", kit)
		assert(Quality.isDecorative(part("Mesh", m)), kit)
	end
end

function T.structuralKitModelsAreNotDecorative()
	for _, kit in { "TerraceRowVictorian", "LampVictorian", "ChurchSpire" } do
		local m = model("Anything")
		m:SetAttribute("Kit", kit)
		assert(not Quality.isDecorative(part("Mesh", m)), kit .. " should stay")
	end
end

function T.decorAttributeOnPartOrAncestor()
	local p = part("Body")
	p:SetAttribute("Decor", true)
	assert(Quality.isDecorative(p), "attribute on the part")

	local folder = Instance.new("Folder")
	folder:SetAttribute("Decor", true)
	local m = model("Thing", folder)
	assert(Quality.isDecorative(part("Body", m)), "attribute on an ancestor folder")

	local off = part("Body")
	off:SetAttribute("Decor", false)
	assert(not Quality.isDecorative(off), "Decor = false is not decor")
end

function T.structuralModelNamesAreNotDecorative()
	for _, name in { "TerraceRow", "ShopRow", "SemiPair", "Shed", "TerraceLamp", "ClockTower", "StationFront" } do
		assert(not Quality.isDecorative(part("Body", model(name))), name .. " should stay")
	end
end

function T.ancestorWalkIsBounded()
	-- a deep chain must terminate and not find a Decor ancestor past the limit
	local top = Instance.new("Folder")
	top:SetAttribute("Decor", true)
	local node: Instance = top
	for _ = 1, 20 do
		local f = Instance.new("Folder")
		f.Parent = node
		node = f
	end
	assert(not Quality.isDecorative(part("Body", node)), "Decor 20 levels up is out of reach")
end

-- ------------------------------------------------------------ textures

local function texture(name: string): Texture
	local t = Instance.new("Texture")
	t.Name = name
	return t
end

function T.fillerTexturesAreHidden()
	for name in Quality.FILLER_TEXTURES do
		assert(Quality.isFillerTexture(texture(name)), name)
	end
end

function T.facadeAndSignTexturesStay()
	for _, name in { "front_a", "shop_front_cafe", "upper_floors_a", "flats_facade", "civic_facade", "semi_front_a", "shed_door", "shed_sign_b" } do
		assert(not Quality.isFillerTexture(texture(name)), name .. " should stay")
	end
end

function T.nonTextureNamedLikeFillerIsNotFiller()
	local decal = Instance.new("Decal")
	decal.Name = "brick"
	assert(not Quality.isFillerTexture(decal), "Decal named brick")
	assert(not Quality.isFillerTexture(part("slate")), "Part named slate")
end

-- Lane I stage 3: v3 builders tag their decor models V3Decor; Low hides them.
function T.v3DecorTagHidesOnLow()
	local tagged = model("UKSP__Anything")
	tagged:AddTag("V3Decor")
	local node = model("Anything_Node", tagged)
	assert(Quality.isDecorative(part("Mesh", node)), "a part two levels under a V3Decor model hides")
	assert(not Quality.isDecorative(part("Mesh", model("Anything_Node", model("UKSP__Anything")))), "untagged stays")
	tagged:Destroy()
end

return T
