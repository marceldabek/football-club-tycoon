--!strict
-- Entry point: boot the session (load the owner's club, build the world).

local Session = require(script.Parent.Session)
local MatchService = require(script.Parent.MatchService)
local UpgradeService = require(script.Parent.UpgradeService)
local ClubService = require(script.Parent.ClubService)
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- Studio-only debug hook so agent/manual playtests can drive the real services
-- without walking to prompts. Never present in a live server.
--   ("playMatch", durationSeconds?, walkoutSeconds?)
--   ("expandStand", "East"|"West"|"North"|"South") / ("amenity")
--   ("tactic", "Attack" | "Defend" | "Balanced" | "Sub")
--   ("club", action, a?, b?)  e.g. ("club", "hireScout"), ("club", "swap", 3, 14)
--   ("cash", amount) adds money
--   ("save") flush now / ("reload") snapshot -> restore round trip / ("wipe") fresh club
--   ("preview", "4,2,1,0") rebuild the ground at those East/West/North/South plot
--       levels and fill the crowd; for looking at layout changes, not a real purchase
--
-- The same commands can be driven by writing a string attribute, because the
-- Studio MCP bridge runs in a sandboxed thread that may not invoke a
-- BindableFunction here. Arguments are separated by "|":
--   ServerScriptService.Server:SetAttribute("DebugRun", "preview|4,2,1,0")
--   ServerScriptService.Server:SetAttribute("DebugRun", "playMatch|20|3")
-- The result is written back to the "DebugResult" attribute.
if game:GetService("RunService"):IsStudio() then
	local function run(command: string, ...): (boolean, string?)
		if command == "playMatch" then
			return MatchService.playMatch(...)
		elseif command == "expandStand" then
			return UpgradeService.tryExpandStand(...)
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
		elseif command == "preview" then
			local levels: { [string]: number } = {}
			local i = 1
			for value in tostring((...)):gmatch("[^,%s]+") do
				local plot = Config.StandPlots[i]
				if plot then
					levels[plot.key] = math.clamp(tonumber(value) or 0, 0, #Config.StandLevels)
				end
				i += 1
			end
			for index, plot in Config.StandPlots do
				ClubState.setPlotLevel(plot, levels[plot.key] or 0)
				WorldBuilder.buildPlot(index, levels[plot.key] or 0)
			end
			local capacity = ClubState.capacity()
			WorldBuilder.buildCrowd(ClubState.plotLevels(), capacity, capacity)
			UpgradeService.refreshPrompt()
			return true, ("preview: capacity %d"):format(capacity)
		end
		return false, "unknown command: " .. tostring(command)
	end

	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "DebugCommand"
	debugFn.Parent = script.Parent
	debugFn.OnInvoke = run

	script.Parent:GetAttributeChangedSignal("DebugRun"):Connect(function()
		local spec = script.Parent:GetAttribute("DebugRun")
		if type(spec) ~= "string" or spec == "" then
			return
		end
		local args: { any } = {}
		for token in spec:gmatch("[^|]+") do
			table.insert(args, tonumber(token) or token)
		end
		local ok, message = run(table.unpack(args))
		script.Parent:SetAttribute("DebugResult", ("%s %s"):format(tostring(ok), tostring(message)))
		print("[FCT] debug", spec, "->", ok, message)
	end)
end

Session.start()

print("[FCT] world ready")
