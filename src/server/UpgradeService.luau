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

local standPrompt: ProximityPrompt
local amenityPrompt: ProximityPrompt

local function money(n: number): string
	local s = tostring(math.floor(n))
	local withCommas = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return "£" .. withCommas
end

function UpgradeService.refreshPrompt()
	local managing = ClubState.get("Phase") == "Manage"

	local level = ClubState.get("StandLevel") :: number
	local nextLevel = Config.StandLevels[level + 1]
	if nextLevel then
		standPrompt.ActionText = ("Expand to %s (%d seats) — %s"):format(nextLevel.name, nextLevel.capacity, money(nextLevel.cost))
		standPrompt.Enabled = managing
	else
		standPrompt.ActionText = "Fully expanded"
		standPrompt.Enabled = false
	end

	local amenity = (ClubState.get("AmenityLevel") :: number?) or 0
	local nextAmenity = Config.AmenityLevels[amenity + 2]
	if nextAmenity then
		amenityPrompt.ActionText = ("Build %s (+%s per fan, +%d%% demand) — %s"):format(
			nextAmenity.name, money(nextAmenity.perFan), math.floor(nextAmenity.demandBonus * 100 + 0.5), money(nextAmenity.cost))
		amenityPrompt.Enabled = managing
	else
		amenityPrompt.ActionText = "Fully built"
		amenityPrompt.Enabled = false
	end
end

function UpgradeService.init(prompts: { stand: ProximityPrompt, amenity: ProximityPrompt })
	standPrompt = prompts.stand
	amenityPrompt = prompts.amenity
	UpgradeService.refreshPrompt()
end

local function pay(cost: number): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Locked during matchday"
	end
	local cash = ClubState.get("Cash") :: number
	if cash < cost then
		return false, ("Need %s more"):format(money(cost - cash))
	end
	ClubState.addCash(-cost)
	return true
end

-- Returns true if the purchase happened, otherwise a reason string.
function UpgradeService.tryExpandStand(): (boolean, string?)
	local level = ClubState.get("StandLevel") :: number
	local nextLevel = Config.StandLevels[level + 1]
	if not nextLevel then
		return false, "Already fully expanded"
	end
	local ok, reason = pay(nextLevel.cost)
	if not ok then
		return false, reason
	end
	ClubState.set("StandLevel", level + 1)
	ClubState.set("Capacity", nextLevel.capacity)
	WorldBuilder.buildStand(level + 1)
	UpgradeService.refreshPrompt()
	return true, ("%s built: %d seats"):format(nextLevel.name, nextLevel.capacity)
end

function UpgradeService.tryUpgradeAmenity(): (boolean, string?)
	local level = (ClubState.get("AmenityLevel") :: number?) or 0
	local nextLevel = Config.AmenityLevels[level + 2]
	if not nextLevel then
		return false, "Already fully built"
	end
	local ok, reason = pay(nextLevel.cost)
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
