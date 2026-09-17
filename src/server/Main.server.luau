--!strict
-- Entry point: the shared town scenery and Rivermere greybox, then the four club plots.
-- Each claimed plot runs its own copy of the club services (docs/PLOTS.md).

local PlotService = require(script.Parent.PlotService)
local Scenery = require(script.Parent.Scenery)
local TownBuilder = require(script.Parent.TownBuilder)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- Studio-only debug hook so agent/manual playtests can drive the real services
-- without walking to prompts. Never present in a live server. Commands run
-- against the first claimed plot unless prefixed with "plot|N|".
--   ("playMatch", durationSeconds?, walkoutSeconds?)
--   ("expandStand", "East"|"West"|"North"|"South") / ("amenity")
--   ("tactic", "Attack" | "Defend" | "Balanced" | "Sub")
--   ("club", action, a?, b?)  e.g. ("club", "hireScout"), ("club", "swap", 3, 14)
--   ("cash", amount) adds money / ("tier", 1..5) jumps to that division
--   ("save") flush now / ("reload") snapshot -> restore round trip / ("wipe") fresh club
--   ("preview", "4,2,1,0") rebuild the ground at those East/West/North/South plot
--       levels and fill the crowd; for looking at layout changes, not a real purchase
--
-- The same commands can be driven by writing a string attribute, because the
-- Studio MCP bridge runs in a sandboxed thread that may not invoke a
-- BindableFunction here. Arguments are separated by "|":
--   ServerScriptService.Server:SetAttribute("DebugRun", "preview|4,2,1,0")
--   ServerScriptService.Server:SetAttribute("DebugRun", "plot|2|playMatch|20|3")
-- The result is written back to the "DebugResult" attribute.
if game:GetService("RunService"):IsStudio() then
	local function run(command: string, ...): (boolean, string?)
		local args = { ... }
		local plot: number? = nil
		if command == "plot" then
			plot = tonumber(args[1])
			command = args[2]
			args = { select(3, ...) }
		end
		local m = PlotService.debugModules(plot)
		if not m then
			return false, "no club is running"
		end
		local a1, a2, a3 = args[1], args[2], args[3]
		if command == "playMatch" then
			return m.MatchService.playMatch(a1, a2)
		elseif command == "expandStand" then
			return m.UpgradeService.tryExpandStand(a1)
		elseif command == "amenity" then
			return m.UpgradeService.tryUpgradeAmenity()
		elseif command == "tactic" then
			return m.MatchService.applyTactic(a1)
		elseif command == "club" then
			return m.ClubService.act(a1, a2, a3)
		elseif command == "cash" then
			m.ClubState.addCash(a1 or 1000)
			return true
		elseif command == "tier" then
			return m.SeasonService.setTier(tonumber(a1) or 1)
		elseif command == "save" then
			return m.Session.saveNow()
		elseif command == "reload" then
			return m.Session.reload()
		elseif command == "wipe" then
			return m.Session.wipe()
		elseif command == "preview" then
			local levels: { [string]: number } = {}
			local i = 1
			for value in tostring(a1):gmatch("[^,%s]+") do
				local standPlot = Config.StandPlots[i]
				if standPlot then
					levels[standPlot.key] = math.clamp(tonumber(value) or 0, 0, #Config.StandLevels)
				end
				i += 1
			end
			for index, standPlot in Config.StandPlots do
				m.ClubState.setPlotLevel(standPlot, levels[standPlot.key] or 0)
				m.WorldBuilder.buildPlot(index, levels[standPlot.key] or 0)
			end
			local capacity = m.ClubState.capacity()
			m.WorldBuilder.buildCrowd(m.ClubState.plotLevels(), capacity, capacity)
			m.UpgradeService.refreshPrompt()
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

Scenery.setupTown()
TownBuilder.build()
require(script.Parent.Backdrop).build()
print("[FCT] " .. require(script.Parent.StreetDresser).build())
print("[FCT] " .. require(script.Parent.SquareDresser).build())
print("[FCT] " .. require(script.Parent.RiverDresser).build())
PlotService.start()
require(script.Parent.BusService).start()

print("[FCT] town ready")
