--!strict
-- Rivermere v3, Lane F: the built furniture. Needs the real kit in
-- ServerStorage.Kit: a missing asset is exactly what these tests must catch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local FurniturePlan = require(ReplicatedStorage.Shared.FurniturePlan)
local StreetFurniture = require(ServerScriptService.Server.StreetFurniture)

local T = {}

local ORIGIN = CFrame.new(100, 0, -200)
local REVIEW_DISTRICT = "Mill Street Terraces"

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

local function fixture(): FurniturePlan.Input
	local lots = {}
	for i, z in { 110, 250 } do
		table.insert(lots, { id = "w" .. i, use = "terraced row", district = "Testfield", street = "Side Street", centre = v(-36, z), size = Vector3.new(132, 28, 24), front = Vector3.new(1, 0, 0) })
		table.insert(lots, { id = "e" .. i, use = "terraced row", district = "Testfield", street = "Side Street", centre = v(36, z), size = Vector3.new(132, 28, 24), front = Vector3.new(-1, 0, 0) })
	end
	table.insert(lots, { id = "shops", use = "shops with flats", district = "Testfield", street = "High Road", centre = v(150, -36), size = Vector3.new(130, 36, 30), front = Vector3.new(0, 0, 1) })
	return {
		roads = {
			{ name = "High Road", kind = "main", width = 26, points = { v(-600, 0), v(600, 0) } },
			{ name = "Side Street", kind = "residential", width = 20, points = { v(0, 0), v(0, 400) }, district = "Testfield", head = true },
		},
		lots = lots,
		roundabouts = { { centre = v(600, 0), radius = 40 } },
		specials = { { use = "school", centre = v(-300, -70), size = Vector3.new(120, 0, 80), yaw = 0 } },
		busStops = { { name = "Testfield", position = v(-120, 22) } },
	}
end

local function withFolder(fn: (Folder) -> ())
	local folder = Instance.new("Folder")
	folder.Name = "StreetFurnitureTest"
	folder.Parent = workspace
	local ok, err = pcall(fn, folder)
	folder:Destroy()
	if not ok then
		error(err, 0)
	end
end

local function audit(root: Instance): (number, number, number)
	local missing, primitives, parts = 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:GetAttribute("KitMissing") ~= nil then
			missing += 1
		end
		if d:IsA("BasePart") then
			parts += 1
			if not d:IsA("MeshPart") and d:GetAttribute("V3Exempt") == nil then
				primitives += 1
			end
		end
	end
	return missing, primitives, parts
end

T["fixture builds with no missing kit, no primitives, nothing clipped"] = function()
	withFolder(function(folder)
		local result = StreetFurniture.buildFrom(fixture(), folder, ORIGIN, nil, nil)
		local missing, primitives, parts = audit(folder)
		assert(result.planned > 40, "fixture planned too little: " .. result.planned)
		assert(missing == 0 and result.missing == 0, ("%d KitMissing instances, %d missing assets"):format(missing, result.missing))
		assert(primitives == 0, primitives .. " primitive parts without V3Exempt")
		assert(result.clipped == 0, result.clipped .. " props clipped")
		assert(result.placed == result.planned, ("placed %d of %d"):format(result.placed, result.planned))
		assert(parts == result.parts, ("reported %d parts, found %d"):format(result.parts, parts))
	end)
end

T["one non-atomic Model per district, props carry Kit and Road, decor is tagged"] = function()
	withFolder(function(folder)
		StreetFurniture.buildFrom(fixture(), folder, ORIGIN, nil, nil)
		local names = {}
		for _, child in folder:GetChildren() do
			assert(child:IsA("Model"), child.Name .. " is not a Model")
			assert((child :: Model).ModelStreamingMode == Enum.ModelStreamingMode.Default, child.Name .. " must not be Atomic (section 9 rule 1)")
			names[child.Name] = true
			for _, prop in child:GetChildren() do
				assert(prop:GetAttribute("Kit") ~= nil and prop:GetAttribute("Road") ~= nil, prop.Name .. " lacks Kit/Road attributes")
				local decor = prop.Name == "manhole" or prop.Name == "cone"
				assert(game:GetService("CollectionService"):HasTag(prop, "V3Decor") == decor, prop.Name .. " has the wrong V3Decor tag")
			end
		end
		assert(names["Furniture_Testfield"] and names["Furniture_" .. FurniturePlan.NO_DISTRICT], "district models missing")
	end)
end

T["origin offsets the whole build and props stand on the pavement"] = function()
	withFolder(function(folder)
		StreetFurniture.buildFrom(fixture(), folder, ORIGIN, { district = "Testfield" }, nil)
		local lamps = 0
		for _, prop in folder:GetDescendants() do
			if prop:IsA("Model") and prop.Name == "lamp" then
				lamps += 1
				local cf, size = (prop :: Model):GetBoundingBox()
				local foot = cf.Position.Y - size.Y / 2
				assert(math.abs(foot - FurniturePlan.PAVEMENT_Y) < 0.05, ("lamp foot at y=%.2f"):format(foot))
				-- Side Street runs south from the origin offset: x near 100, z between -200 and 200
				assert(math.abs(cf.Position.X - 100) < 20 and cf.Position.Z > -200 and cf.Position.Z < 200, "lamp not offset by origin")
			end
		end
		assert(lamps >= 3, "too few lamps: " .. lamps)
	end)
end

T["a budget that clips is loud: counted, and never exceeded"] = function()
	withFolder(function(folder)
		local result = StreetFurniture.buildFrom(fixture(), folder, ORIGIN, nil, 12)
		local _, _, parts = audit(folder)
		assert(result.clipped > 0, "a 12-part budget clipped nothing")
		assert(parts <= 12 and result.parts == parts, ("budget 12, built %d parts"):format(parts))
		assert(result.placed + result.clipped + result.missing == result.planned, "placed + clipped + missing does not add up to planned")
	end)
end

T["every asset the plan can name exists in the kit"] = function()
	local KitPlacer = require(ServerScriptService.Server.KitPlacer)
	local function check(value: any)
		if type(value) == "table" then
			for _, inner in value do
				check(inner)
			end
		else
			assert(KitPlacer.find(value) ~= nil, "kit asset missing: " .. tostring(value))
		end
	end
	check(FurniturePlan.ASSETS)
end

T["one real district fits the town budget with nothing clipped or missing"] = function()
	withFolder(function(folder)
		local result = StreetFurniture.build(folder, ORIGIN, { district = REVIEW_DISTRICT })
		local missing, primitives = audit(folder)
		assert(result.planned > 50, REVIEW_DISTRICT .. " planned only " .. result.planned)
		assert(result.clipped == 0 and result.missing == 0 and missing == 0, ("clipped %d, missing %d"):format(result.clipped, result.missing))
		assert(primitives == 0, primitives .. " primitive parts")
		assert(result.parts <= StreetFurniture.PART_BUDGET, "over budget")
	end)
end

T["the whole town's plan is clean and inside the budget"] = function()
	local KitPlacer = require(ServerScriptService.Server.KitPlacer)
	local input = StreetFurniture.townInput()
	local list, stats = FurniturePlan.plan(input)
	local bad = FurniturePlan.violations(input, list)
	assert(#bad == 0, #bad .. " violations, first: " .. tostring(bad[1]))
	local perAsset: { [string]: number } = {}
	local parts = 0
	for _, pl in list do
		local n = perAsset[pl.name]
		if not n then
			n = 0
			local template = KitPlacer.find(pl.name)
			assert(template, "kit asset missing: " .. pl.name)
			if template:IsA("BasePart") then
				n = 1
			end
			for _, d in template:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
				end
			end
			perAsset[pl.name] = n
		end
		parts += n
	end
	assert(parts <= StreetFurniture.PART_BUDGET, ("town furniture needs %d parts, budget is %d: it WOULD clip"):format(parts, StreetFurniture.PART_BUDGET))
	assert(#list > 1500, "town furniture is thin: " .. #list)
	assert(#stats.skippedBusStops <= 4, #stats.skippedBusStops .. " bus stops have no road")
end

return T
