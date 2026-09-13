--!strict
-- Entry point: build the world and wire the world prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local MatchService = require(script.Parent.MatchService)
local UpgradeService = require(script.Parent.UpgradeService)
local ClubService = require(script.Parent.ClubService)
local SeasonService = require(script.Parent.SeasonService)

ClubState.init()
MatchService.init()
ClubService.init()
SeasonService.init()

local world = WorldBuilder.build(ClubState.get("StandLevel"), ClubState.get("AmenityLevel"))
UpgradeService.init({ stand = world.standPrompt, amenity = world.amenityPrompt })

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toast = remotes:WaitForChild("Toast") :: RemoteEvent

world.matchdayPrompt.Triggered:Connect(function(player)
	local started = MatchService.playMatch()
	if not started then
		toast:FireClient(player, "A match is already in progress")
	end
end)

world.standPrompt.Triggered:Connect(function(player)
	local ok, message = UpgradeService.tryExpandStand()
	if ok then
		toast:FireAllClients(message or "Stand expanded!", true)
	else
		toast:FireClient(player, message or "Cannot expand right now")
	end
end)

world.amenityPrompt.Triggered:Connect(function(player)
	local ok, message = UpgradeService.tryUpgradeAmenity()
	if ok then
		toast:FireAllClients(message or "Amenity built!", true)
	else
		toast:FireClient(player, message or "Cannot build right now")
	end
end)

-- Lock world upgrades while a match is running (PreMatch and Match).
ClubState.Folder:GetAttributeChangedSignal("Phase"):Connect(function()
	local managing = ClubState.get("Phase") == "Manage"
	world.matchdayPrompt.Enabled = managing
	UpgradeService.refreshPrompt()
end)

-- Studio-only debug hook so agent/manual playtests can drive the real services
-- without walking to prompts. Never present in a live server.
--   ("playMatch", durationSeconds?, walkoutSeconds?)
--   ("expandStand") / ("amenity")
--   ("tactic", "Attack" | "Defend" | "Balanced" | "Sub")
--   ("club", action, a?, b?)  e.g. ("club", "hireScout"), ("club", "swap", 3, 14)
--   ("cash", amount) adds money
if game:GetService("RunService"):IsStudio() then
	local debug = Instance.new("BindableFunction")
	debug.Name = "DebugCommand"
	debug.Parent = script.Parent
	debug.OnInvoke = function(command: string, ...)
		if command == "playMatch" then
			return MatchService.playMatch(...)
		elseif command == "expandStand" then
			return UpgradeService.tryExpandStand()
		elseif command == "amenity" then
			return UpgradeService.tryUpgradeAmenity()
		elseif command == "tactic" then
			return MatchService.applyTactic(...)
		elseif command == "club" then
			return ClubService.act(...)
		elseif command == "cash" then
			ClubState.addCash((...) or 1000)
			return true
		end
		return false, "unknown command: " .. tostring(command)
	end
end

print("[FCT] world ready")
