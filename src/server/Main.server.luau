--!strict
-- Entry point: build the world and wire the world prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local MatchService = require(script.Parent.MatchService)
local UpgradeService = require(script.Parent.UpgradeService)

ClubState.init()
MatchService.init()

local world = WorldBuilder.build(ClubState.get("StandLevel"))
UpgradeService.init(world.standPrompt)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toast = remotes:WaitForChild("Toast") :: RemoteEvent

world.matchdayPrompt.Triggered:Connect(function(player)
	local started = MatchService.playMatch()
	if not started then
		toast:FireClient(player, "A match is already in progress")
	end
end)

world.standPrompt.Triggered:Connect(function(player)
	local ok, reason = UpgradeService.tryExpandStand()
	if ok then
		toast:FireAllClients("Stand expanded!")
	else
		toast:FireClient(player, reason or "Cannot expand right now")
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
--   ("expandStand")
--   ("tactic", "Attack" | "Defend" | "Balanced" | "Sub")
if game:GetService("RunService"):IsStudio() then
	local debug = Instance.new("BindableFunction")
	debug.Name = "DebugCommand"
	debug.Parent = script.Parent
	debug.OnInvoke = function(command: string, ...)
		if command == "playMatch" then
			return MatchService.playMatch(...)
		elseif command == "expandStand" then
			return UpgradeService.tryExpandStand()
		elseif command == "tactic" then
			return MatchService.applyTactic(...)
		end
		return false, "unknown command: " .. tostring(command)
	end
end

print("[FCT] world ready")
