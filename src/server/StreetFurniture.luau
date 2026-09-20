--!strict
-- Rivermere v3, Lane F: street furniture at vertical-slice density. Turns the
-- pure FurniturePlan into kit models, one (non-atomic) Model per district. No primitives:
-- every prop is a ServerStorage.Kit asset placed through KitPlacer.
--
-- FAILS LOUDLY. The old budgeted dressers stopped placing props with no error
-- when their budget ran out. Here anything the budget clips, and any kit name
-- that is missing, is warned about and counted in the `[FCT] Furniture:` line
-- as placed/planned per category.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FurniturePlan = require(ReplicatedStorage.Shared.FurniturePlan)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)
local KitPlacer = require(script.Parent.KitPlacer)
local V3Perf = require(script.Parent.V3Perf)

local StreetFurniture = {}

StreetFurniture.PART_BUDGET = 4500 -- docs/TOWN_V3_BUILD.md section 9, published by Lane P (MeshParts, whole town)

-- V3Perf.applyDefaults kind per category. "decor" has no collision at all.
local PERF_KIND: { [string]: string } = {
	manhole = "decor",
	cone = "decor",
}

-- Cheap things go last, so if the budget ever does clip, it clips manholes and
-- cones before lamps and shelters.
local PRIORITY = { "shelter", "giveWay", "sign", "lamp", "guardRail", "pole", "phoneBox", "bench", "bin", "car", "cabinet", "roadworks", "cone", "manhole" }

export type Result = { [string]: number }

local function countParts(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- The live town's data in FurniturePlan's input shape.
function StreetFurniture.townInput(): FurniturePlan.Input
	local layout = TownLayout :: any
	local frontage = TownFrontage :: any
	assert(type(frontage.generate) == "function", "StreetFurniture: TownFrontage.generate is not there yet (Lane A)")
	local specials = {}
	for _, district in layout.DISTRICTS or {} do
		for _, block in district.blocks or {} do
			table.insert(specials, { use = block.use, centre = block.centre, size = block.size, yaw = block.yaw or 0, district = district.name })
		end
	end
	local plots = {}
	for i in layout.PLOTS or {} do
		table.insert(plots, { centre = layout.plotCFrame(i).Position })
	end
	-- Tier A (section 9): the plots, the market square and the station.
	local tierA = { Vector3.new(0, 0, 0), Vector3.new(-900, 0, -350) }
	for _, plot in plots do
		table.insert(tierA, plot.centre)
	end
	return {
		roads = layout.ROADS,
		lots = frontage.generate(),
		roundabouts = layout.ROUNDABOUTS,
		specials = specials,
		busStops = layout.BUS_STOPS,
		bridges = layout.BRIDGES,
		rail = layout.RAIL,
		plots = plots,
		plotSize = layout.PLOT_SIZE,
		square = layout.SQUARE,
		tierACentres = tierA,
	}
end

-- Builds from explicit data (tests and the sandbox use this with a fixture).
function StreetFurniture.buildFrom(input: FurniturePlan.Input, parent: Instance, origin: CFrame, filter: { district: string? }?, budget: number?): Result
	local district = filter and filter.district or nil
	local placements, stats = FurniturePlan.plan(input, { district = district })
	local partBudget = budget or StreetFurniture.PART_BUDGET

	local byCategory: { [string]: { FurniturePlan.Placement } } = {}
	for _, pl in placements do
		local list = byCategory[pl.category]
		if not list then
			list = {}
			byCategory[pl.category] = list
		end
		table.insert(list, pl)
	end
	local order = table.clone(PRIORITY)
	for category in byCategory do
		if not table.find(order, category) then
			table.insert(order, category)
		end
	end

	local models: { [string]: Model } = {}
	local function districtModel(name: string): Model
		local model = models[name]
		if not model then
			model = Instance.new("Model")
			model.Name = "Furniture_" .. name
			-- section 9 rule 1: furniture is a plain grouping model, never Atomic
			model.ModelStreamingMode = Enum.ModelStreamingMode.Default
			model.Parent = parent
			models[name] = model
		end
		return model
	end

	local result: Result = { planned = #placements, placed = 0, clipped = 0, missing = 0, parts = 0 }
	local summary = {}
	local parkedRoads: { [string]: boolean } = {}
	for _, category in order do
		local list = byCategory[category]
		if not list then
			continue
		end
		local placed = 0
		for _, pl in list do
			if result.parts >= partBudget then
				result.clipped += 1
				continue
			end
			local model = KitPlacer.place(pl.name, origin * pl.cframe, districtModel(pl.district), if pl.scale then { scale = pl.scale } else nil)
			local missing = false
			for _, d in model:GetDescendants() do
				if d:GetAttribute("KitMissing") ~= nil then
					missing = true
				end
			end
			if missing or model:GetAttribute("KitMissing") ~= nil then
				-- never leave a grey block in the street
				model:Destroy()
				result.missing += 1
				warn(("[FCT] Furniture: kit asset %s is MISSING (%s on %s)"):format(pl.name, category, pl.road))
				continue
			end
			local parts = countParts(model)
			if result.parts + parts > partBudget then
				model:Destroy()
				result.clipped += 1
				continue
			end
			model.Name = category
			model:SetAttribute("Road", pl.road)
			local kind = PERF_KIND[category] or "prop"
			V3Perf.applyDefaults(model, kind :: any)
			if kind == "decor" then
				CollectionService:AddTag(model, "V3Decor") -- Quality Low hides these
			end
			result.parts += parts
			result.placed += 1
			placed += 1
			if category == "car" then
				parkedRoads[pl.road] = true
			end
		end
		result[category] = placed
		table.insert(summary, ("%s %d/%d"):format(category, placed, #list))
	end

	if result.clipped > 0 then
		warn(("[FCT] Furniture: BUDGET CLIPPED %d of %d props (budget %d parts). Widen FurniturePlan.RULES spacing or raise PART_BUDGET."):format(result.clipped, #placements, partBudget))
	end
	for _, name in stats.skippedBusStops do
		warn(("[FCT] Furniture: bus stop %q is not beside any road, no shelter placed (TownLayout.BUS_STOPS needs a v3 position)"):format(name))
	end
	result.skippedBusStops = #stats.skippedBusStops

	-- Parked cars stand on the carriageway, one lane each side, so client Traffic must
	-- keep off those streets (the v1 X36 contract: a "|" list in a ParkedStreets attribute).
	local parkedNames: { string } = {}
	for name in parkedRoads do
		table.insert(parkedNames, name)
	end
	table.sort(parkedNames)
	parent:SetAttribute("ParkedStreets", table.concat(parkedNames, "|"))
	result.parkedStreets = #parkedNames

	local perf = ""
	local ok, counts = pcall(function()
		return V3Perf.format(V3Perf.count(parent))
	end)
	if ok then
		perf = " | " .. counts
	end
	print(("[FCT] Furniture: %s%d/%d placed, %d parts of %d, clipped %d, missing %d | %s%s"):format(
		if district then district .. ": " else "",
		result.placed, #placements, result.parts, partBudget, result.clipped, result.missing,
		table.concat(summary, ", "), perf
	))
	return result
end

-- The section 4.3 contract.
function StreetFurniture.build(parent: Instance, origin: CFrame, filter: { district: string? }?): Result
	return StreetFurniture.buildFrom(StreetFurniture.townInput(), parent, origin, filter, nil)
end

return StreetFurniture
