--!strict
-- The single Milestone 1 upgrade: expand the stand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)

local UpgradeService = {}

local standPrompt: ProximityPrompt

local function money(n: number): string
	return ("£%d"):format(n)
end

function UpgradeService.refreshPrompt()
	local level = ClubState.get("StandLevel") :: number
	local nextLevel = Config.StandLevels[level + 1]
	if nextLevel then
		standPrompt.ActionText = ("Expand to %s (%d seats) — %s"):format(nextLevel.name, nextLevel.capacity, money(nextLevel.cost))
		standPrompt.Enabled = ClubState.get("Phase") == "Manage"
	else
		standPrompt.ActionText = "Fully expanded (more upgrades coming)"
		standPrompt.Enabled = false
	end
end

function UpgradeService.init(prompt: ProximityPrompt)
	standPrompt = prompt
	UpgradeService.refreshPrompt()
end

-- Returns true if the purchase happened, otherwise a reason string.
function UpgradeService.tryExpandStand(): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Locked during matchday"
	end
	local level = ClubState.get("StandLevel") :: number
	local nextLevel = Config.StandLevels[level + 1]
	if not nextLevel then
		return false, "Already fully expanded"
	end
	local cash = ClubState.get("Cash") :: number
	if cash < nextLevel.cost then
		return false, ("Need %s more"):format(money(nextLevel.cost - cash))
	end

	ClubState.addCash(-nextLevel.cost)
	ClubState.set("StandLevel", level + 1)
	ClubState.set("Capacity", nextLevel.capacity)
	WorldBuilder.buildStand(level + 1)
	UpgradeService.refreshPrompt()
	return true
end

return UpgradeService
