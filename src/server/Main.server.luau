--!strict
-- Entry point: boot the session (load the owner's club, build the world).

local Session = require(script.Parent.Session)
local MatchService = require(script.Parent.MatchService)
local UpgradeService = require(script.Parent.UpgradeService)
local ClubService = require(script.Parent.ClubService)
local ClubState = require(script.Parent.ClubState)

-- Studio-only debug hook so agent/manual playtests can drive the real services
-- without walking to prompts. Never present in a live server.
--   ("playMatch", durationSeconds?, walkoutSeconds?)
--   ("expandStand") / ("amenity")
--   ("tactic", "Attack" | "Defend" | "Balanced" | "Sub")
--   ("club", action, a?, b?)  e.g. ("club", "hireScout"), ("club", "swap", 3, 14)
--   ("cash", amount) adds money
--   ("save") flush now / ("reload") snapshot -> restore round trip / ("wipe") fresh club
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
		elseif command == "save" then
			return Session.saveNow()
		elseif command == "reload" then
			return Session.reload()
		elseif command == "wipe" then
			return Session.wipe()
		end
		return false, "unknown command: " .. tostring(command)
	end
end

Session.start()

print("[FCT] world ready")
