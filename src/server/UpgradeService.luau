--!strict
-- World-based physical upgrades: the stand chain and the concourse amenity
-- chain. Each has a ProximityPrompt in the world whose text shows the next
-- level and price.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local SeasonService = require(script.Parent.SeasonService)

local UpgradeService = {}

local standPrompts: { [string]: ProximityPrompt } = {}
local amenityPrompt: ProximityPrompt

local function money(n: number): string
	local s = tostring(math.floor(n))
	local withCommas = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return "£" .. withCommas
end

function UpgradeService.refreshPrompt()
	local managing = ClubState.get("Phase") == "Manage"

	-- X293: a stand was priced but never valued — "Main Stand (400 seats) —
	-- £1,500" says nothing about what those seats earn, so choosing between a
	-- stand, a scout and a striker was blind. Seats only pay while there are
	-- fans being turned away, so the figure is the fans this build would let in
	-- at today's demand, at today's takings per fan.
	local capacity = ClubState.capacity()
	local demand = (ClubState.get("Demand") :: number?) or 0
	local queue = math.max(demand - capacity, 0)
	local amenityNow = Config.AmenityLevels[((ClubState.get("AmenityLevel") :: number?) or 0) + 1]
	local perFan = Config.TicketPrice + (if amenityNow then amenityNow.perFan else 0)

	for _, plot in Config.StandPlots do
		local prompt = standPrompts[plot.key]
		if not prompt then
			continue
		end
		local level = ClubState.plotLevel(plot)
		local nextLevel = Config.StandLevels[level + 1]
		if nextLevel then
			local seats = Config.plotCapacity(plot, level + 1)
			local verb = if level == 0 then "Build" else "Expand to"
			-- X228: the first build on an empty plot costs nothing (TEMP, question 18); say so
			local price = if nextLevel.cost <= 0 then "Free" else money(nextLevel.cost)
			local extraFans = math.min(queue, seats - Config.plotCapacity(plot, level))
			prompt.ActionText = if extraFans > 0
				-- "while seats are short": two plots can each let in the same
				-- queue, so the figures are not additive (review of X293)
				then ("%s %s (%d seats, +%s a match while seats are short) — %s"):format(verb, nextLevel.name, seats, money(extraFans * perFan), price)
				else ("%s %s (%d seats, ground isn't full yet) — %s"):format(verb, nextLevel.name, seats, price)
			prompt.Enabled = managing
		else
			prompt.ActionText = "Fully expanded"
			prompt.Enabled = false
		end
	end

	local amenity = (ClubState.get("AmenityLevel") :: number?) or 0
	local nextAmenity = Config.AmenityLevels[amenity + 2]
	if nextAmenity then
		-- X215: the levels are cumulative, so show the step from the current one
		local current = Config.AmenityLevels[amenity + 1]
		local perFanGain = nextAmenity.perFan - (if current then current.perFan else 0)
		local demandGain = nextAmenity.demandBonus - (if current then current.demandBonus else 0)
		-- X280: demand runs ahead of capacity for most of the game, so the extra
		-- fans the bonus brings are turned away and earn nothing. Only sell the
		-- demand when there is room for it.
		local roomToGrow = capacity > demand
		amenityPrompt.ActionText = if roomToGrow
			then ("Build %s (+%s per fan, +%d%% demand) — %s"):format(
				nextAmenity.name, money(perFanGain), math.floor(demandGain * 100 + 0.5), money(nextAmenity.cost))
			else ("Build %s (+%s per fan — ground already full) — %s"):format(
				nextAmenity.name, money(perFanGain), money(nextAmenity.cost))
		amenityPrompt.Enabled = managing
	else
		amenityPrompt.ActionText = "Fully built"
		amenityPrompt.Enabled = false
	end
end

function UpgradeService.init(prompts: { stands: { [string]: ProximityPrompt }, amenity: ProximityPrompt })
	standPrompts = prompts.stands
	amenityPrompt = prompts.amenity
	UpgradeService.refreshPrompt()
end

local function pay(cost: number, category: string): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Locked during matchday"
	end
	local cash = ClubState.get("Cash") :: number
	if cash < cost then
		return false, ("Need %s more"):format(money(cost - cash))
	end
	ClubState.addCash(-cost, category) -- X299: which upgrade the money went on
	return true
end

-- Expands one side of the ground. `key` is a Config.StandPlots key; it
-- defaults to the east (main) stand so the Studio debug command still works.
-- Returns true if the purchase happened, otherwise a reason string.
function UpgradeService.tryExpandStand(key: string?): (boolean, string?)
	local plotKey = key or Config.StandPlots[1].key
	local plot
	for _, candidate in Config.StandPlots do
		if candidate.key == plotKey then
			plot = candidate
		end
	end
	if not plot then
		return false, "No such stand"
	end
	local level = ClubState.plotLevel(plot)
	local nextLevel = Config.StandLevels[level + 1]
	if not nextLevel then
		return false, "Already fully expanded"
	end
	local ok, reason = pay(nextLevel.cost, "stands")
	if not ok then
		return false, reason
	end
	ClubState.setPlotLevel(plot, level + 1)
	WorldBuilder.buildPlot(table.find(Config.StandPlots, plot) :: number, level + 1)
	SeasonService.refreshDemand()
	UpgradeService.refreshPrompt()
	return true, ("%s: %s built, %d seats"):format(plot.label, nextLevel.name, ClubState.capacity())
end

function UpgradeService.tryUpgradeAmenity(): (boolean, string?)
	local level = (ClubState.get("AmenityLevel") :: number?) or 0
	local nextLevel = Config.AmenityLevels[level + 2]
	if not nextLevel then
		return false, "Already fully built"
	end
	local ok, reason = pay(nextLevel.cost, "amenities")
	if not ok then
		return false, reason
	end
	ClubState.set("AmenityLevel", level + 1)
	WorldBuilder.buildAmenity(level + 1)
	SeasonService.refreshDemand()
	UpgradeService.refreshPrompt()
	return true, ("%s open! Fans spend more and more of them come."):format(nextLevel.name)
end

return UpgradeService
