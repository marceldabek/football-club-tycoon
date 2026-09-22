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
--   ServerScriptService.Server:SetAttribute("DebugRun", "friendly|20|3")
--   ServerScriptService.Server:SetAttribute("DebugRun", "claim|1")
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
		-- X340 (testing): claim a ground for the first player. Everything below
		-- needs a club to be running, and the only other way in is clicking
		-- BUILD MY CLUB HERE on the picker, which the MCP cannot do reliably.
		if command == "claim" then
			local claimant = game:GetService("Players"):GetPlayers()[1]
			if not claimant then
				return false, "no player"
			end
			return PlotService.claim(claimant, tonumber(args[1]) or 1)
		end
		local m = PlotService.debugModules(plot)
		if not m then
			return false, "no club is running"
		end
		local a1, a2, a3 = args[1], args[2], args[3]
		if command == "playMatch" then
			return m.MatchService.playMatch(a1, a2)
		elseif command == "tradeRoundTrip" then
			-- trades a player out of the first club and straight back in (new id and number)
			local owner = game:GetService("Players"):GetPlayers()[1]
			if not owner then
				return false, "no player"
			end
			return require(script.Parent.TradeService).debugRoundTrip(owner.UserId, { a1 })
		elseif command == "tradeOffer" then
			-- shows the trade offer card to the first player without a second club
			local target = game:GetService("Players"):GetPlayers()[1]
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			local offer = remotes and remotes:FindFirstChild("TradeOffer") :: RemoteEvent?
			if not (target and offer) then
				return false, "no player or remote"
			end
			offer:FireClient(target, {
				from = -1,
				fromName = "Debug",
				fromClub = "Lune Albion",
				give = { { name = "Kit Lomax", role = "MID", overall = 56, age = 23, injured = 0 } },
				take = { { name = "Ezra Ings", role = "DEF", overall = 54, age = 21, injured = 0 } },
				giveCash = 2500,
				takeCash = 0,
				seconds = 60,
			})
			return true
		elseif command == "invite" then
			-- shows the friendly invite card to the first player without a second club
			local target = game:GetService("Players"):GetPlayers()[1]
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			local invite = remotes and remotes:FindFirstChild("FriendlyInvite") :: RemoteEvent?
			if not (target and invite) then
				return false, "no player or remote"
			end
			invite:FireClient(target, { from = -1, fromName = "Debug", fromClub = "Friendly Test XI", seconds = 45 })
			return true
		elseif command == "friendly" then
			-- solo stand-in for a second club: the same side under another name
			local away = m.MatchService.awayTeam()
			away.name = "Friendly Test XI"
			away.kit = { 40, 90, 200 }
			return m.MatchService.playFriendly(away, a1, a2)
		elseif command == "crest" then
			-- crest builder: "crest|random" or "crest|<shape>,<pattern>,<emblem>,<main>,<second>"
			local ClubCrest = require(game:GetService("ReplicatedStorage").Shared.ClubCrest)
			local spec = ClubCrest.random()
			if a1 and a1 ~= "random" then
				local f = string.split(tostring(a1), ",")
				spec = ClubCrest.normalize({ shape = f[1], pattern = f[2], emblem = f[3], main = f[4], second = f[5] })
			end
			m.ClubState.set("Crest", ClubCrest.encode(spec))
			return true, ClubCrest.encode(spec)
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
		elseif command == "newSeason" then
			-- X277: rolls the squad on a year so retirements can be checked without
			-- playing out ten matches
			local news, arrivals, retired = m.ClubService.newSeason()
			for _, line in arrivals do
				table.insert(news, line)
			end
			m.HistoryService.recordRetirements(retired, (m.ClubState.get("Season") :: number?) or 1)
			return true, if #news > 0 then table.concat(news, "  ") else "nobody retired"
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

-- A club saved into the place at the origin (the Edit-mode test suite builds one
-- with no plot context) would stand in the Market Square: clubs only live on plots.
local strayClub = workspace:FindFirstChild("Club")
if strayClub then
	print("[FCT] removed a stray Workspace.Club saved in the place file")
	strayClub:Destroy()
end
-- The same suite leaves its state folder behind. Clients take it for a
-- single-club place and never look at their own plot (ClubRef.state).
local strayState = game:GetService("ReplicatedStorage"):FindFirstChild("ClubState")
if strayState then
	print("[FCT] removed a stray ReplicatedStorage.ClubState saved in the place file")
	strayState:Destroy()
end

Scenery.setupTown()
TownBuilder.build()
require(script.Parent.Backdrop).build()

-- Rivermere v3: roads, housing, trade / civic buildings and street furniture come
-- from the kit (docs/TOWN_V3_BUILD.md). Each builder prints its own [FCT] line and
-- gets its own holder so its V3Perf count is its own. Furniture goes last: it reads
-- the same layout data, but belongs on top of the roads and lots.
do
	local town = workspace:WaitForChild("Town")
	local function holder(name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = town
		return folder
	end
	local origin = CFrame.identity
	-- The town build runs for well over ten seconds. Without a yield it is one
	-- resume, and Studio's script timeout killed Main part-way down the dressers
	-- (Lane I stage 2 playtest: "EstateDresser:958 exhausted allowed execution time").
	-- task.wait() between steps starts a fresh timeout window for each.
	require(script.Parent.RoadTiler).build(holder("V3Roads"), origin, nil, { carve = true })
	task.wait()
	require(script.Parent.RoadTiler).buildPavements(holder("V3Pavements"), origin)
	task.wait()
	require(script.Parent.HouseAssembler).build(holder("V3Housing"), origin, nil)
	task.wait()
	require(script.Parent.TradeAssembler).build(holder("V3Trade"), origin, nil)
	task.wait()
	require(script.Parent.StreetFurniture).build(holder("V3Furniture"), origin, nil)
	task.wait()
end

-- Retired by v3 Lane I: StreetDresser.build and ShopDresser.build (gone), the
-- housing / parked-car halves of TerraceStreetDresser, EstateDresser's building
-- pass and SportsCentreDresser's hall (V3_*_RETIRED constants in those files).
print("[FCT] " .. require(script.Parent.TerraceStreetDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.SquareDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.EstateDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.ForecourtDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.SchoolDresser).build()) -- X320
task.wait()
-- v3: ImperfectionDresser (900 primitive road markings) was deleted in Lane I stage 3;
-- kit roads carry their markings and StreetFurniture places manholes, bins and cones.
print("[FCT] " .. require(script.Parent.RiverDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.MarinaDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.ParkDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.StationDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.SportsCentreDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.ViaductDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.BridgeDresser).build())
task.wait()
-- v3: WireDresser (poles superseded by StreetFurniture) and CrossingDresser (primitive
-- tactile slabs keyed to v1 pavements) were deleted in Lane I stage 3.
-- X341: after the street and estate passes, so it can see which roads they
-- have already signed
print("[FCT] " .. require(script.Parent.SignDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.CentreTreeDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.GreeneryDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.GatewayDresser).build())
task.wait()
print("[FCT] " .. require(script.Parent.ClientKit).publish())
PlotService.start()
require(script.Parent.BusService).start()
require(script.Parent.FriendlyService).start()
require(script.Parent.TradeService).start()

-- SL13: ReplicatedFirst.LoadingScreen holds every client behind a cover until
-- this is set, so nobody stands in a half-built town with no picker
game:GetService("ReplicatedStorage"):SetAttribute("TownReady", true)
print("[FCT] town ready")
