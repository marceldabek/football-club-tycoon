--!strict
-- Runs a matchday: locks the club, runs the hidden sim, publishes the timeline
-- for clients to visualise, replays goal events on the scoreboard over the
-- match duration, then settles revenue and reports the result to the league.
-- The final score always comes from the sim, never from what was displayed.
--
-- Phases: Manage -> PreMatch (iris + walkout) -> Match (clock running) -> Manage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local MatchSim = require(ReplicatedStorage.Shared.MatchSim)
local Economy = require(ReplicatedStorage.Shared.Economy)
local TeamGen = require(ReplicatedStorage.Shared.TeamGen)
local Squad = require(ReplicatedStorage.Shared.Squad)
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local ClubService = require(script.Parent.ClubService)
local SeasonService = require(script.Parent.SeasonService)

local MatchService = {}

local running = false
local homeSquad: { Squad.MatchPlayer } = {}
local subsMade: { Squad.Sub } = {}

-- Set by Session: called once the result and revenue are applied, so the
-- profile is saved at the one moment that matters most.
MatchService.onSettled = nil :: (() -> ())?

local function findOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function remote(name: string): RemoteEvent
	local remotes = findOrCreate(ReplicatedStorage, "Remotes", "Folder")
	return findOrCreate(remotes, name, "RemoteEvent") :: RemoteEvent
end

local function bump(key: string, delta: number)
	ClubState.set(key, (ClubState.get(key) :: number) + delta)
end

local function colorToJson(c: Color3): { number }
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

-- Attack / Defend / Balanced / Sub. Returns false plus a reason if refused.
function MatchService.applyTactic(action: string): (boolean, string?)
	if ClubState.get("Phase") ~= "Match" then
		return false, "No match in progress"
	end
	if action == "Attack" or action == "Defend" or action == "Balanced" then
		ClubState.set("Tactic", action)
		return true
	elseif action == "Sub" then
		local sub = Squad.nextSub(homeSquad, subsMade)
		if not sub then
			return false, "No substitutions left"
		end
		table.insert(subsMade, sub)
		ClubState.set("Subs", HttpService:JSONEncode(subsMade))
		return true
	end
	return false, "Unknown action"
end

function MatchService.init()
	remote("MatchSummary")
	remote("Toast")
	local tactic = remote("Tactic")
	tactic.OnServerEvent:Connect(function(player: Player, action: unknown)
		if type(action) ~= "string" then
			return
		end
		if not ClubState.isOwner(player) then
			remote("Toast"):FireClient(player, "You're visiting this club. Only the owner can manage it.")
			return
		end
		local ok, reason = MatchService.applyTactic(action)
		if not ok and reason then
			remote("Toast"):FireClient(player, reason)
		end
	end)
end

-- Overrides exist for tests only.
function MatchService.playMatch(durationOverride: number?, walkoutOverride: number?): boolean
	if running or ClubState.get("Phase") ~= "Manage" then
		return false
	end
	local fixture = SeasonService.nextFixture()
	if not fixture then
		return false
	end
	running = true

	local matchIndex = (ClubState.get("MatchesPlayed") :: number) + 1
	local duration = durationOverride or Config.MatchDurationSeconds
	local walkout = walkoutOverride or Config.WalkoutSeconds

	-- Simulation layer: result decided up front from squad strength vs the
	-- division-driven opponent strength.
	local prepared = ClubService.prepareMatch()
	homeSquad = prepared.matchSquad
	local result = MatchSim.simulate({
		homeStrength = prepared.strength,
		awayStrength = fixture.strength,
		bias = MatchSim.biasForMatch(matchIndex),
	})
	local scorerSlots = Squad.assignScorers(result.events :: any, homeSquad, Random.new())
	-- opponents keep the same names for both meetings in a season
	local awaySquad = TeamGen.generate(fixture.seed)
	subsMade = {}

	local capacity = ClubState.capacity()
	local demand = SeasonService.demand()
	local attendance = math.min(capacity, demand)
	WorldBuilder.buildCrowd(ClubState.get("StandLevel") :: number, attendance, capacity)

	ClubState.set("Opponent", fixture.opponent)
	ClubState.set("HomeGoals", 0)
	ClubState.set("AwayGoals", 0)
	ClubState.set("MatchDuration", duration)
	ClubState.set("TimeLeft", duration)
	ClubState.set("Attendance", attendance)
	ClubState.set("Tactic", "Balanced")
	ClubState.set("Subs", "[]")
	ClubState.set("Timeline", HttpService:JSONEncode({
		events = result.events,
		home = { name = ClubState.get("ClubName"), kit = colorToJson(Config.HomeKit), squad = homeSquad },
		away = { name = fixture.opponent, kit = fixture.kit, squad = awaySquad },
	}))
	ClubState.set("Phase", "PreMatch")

	task.wait(walkout)

	ClubState.set("KickoffAt", workspace:GetServerTimeNow())
	ClubState.set("Phase", "Match")

	-- Presentation layer (scoreboard): replay goal events against the clock.
	local startClock = os.clock()
	local nextEvent = 1
	while true do
		local elapsed = os.clock() - startClock
		if elapsed >= duration then
			break
		end
		local minute = math.floor(elapsed / duration * 90)
		while result.events[nextEvent] and result.events[nextEvent].minute <= minute do
			local ev = result.events[nextEvent]
			if ev.type == "GOAL" then
				bump(ev.team == "Home" and "HomeGoals" or "AwayGoals", 1)
			end
			nextEvent += 1
		end
		ClubState.set("TimeLeft", math.ceil(duration - elapsed))
		task.wait(0.25)
	end

	-- Authoritative final score, regardless of presentation timing.
	ClubState.set("HomeGoals", result.homeGoals)
	ClubState.set("AwayGoals", result.awayGoals)
	ClubState.set("TimeLeft", 0)

	local amenity = Config.AmenityLevels[((ClubState.get("AmenityLevel") :: number?) or 0) + 1]
	local settlement = Economy.settle({
		homeGoals = result.homeGoals,
		awayGoals = result.awayGoals,
		capacity = capacity,
		demand = demand,
		ticketPrice = Config.TicketPrice,
		concessionPerFan = amenity.perFan,
		winBonus = Config.WinBonus,
		drawBonus = Config.DrawBonus,
		lossBonus = Config.LossBonus,
	})

	ClubState.addCash(settlement.total)
	bump("MatchesPlayed", 1)
	if settlement.outcome == "Win" then
		bump("Wins", 1)
	elseif settlement.outcome == "Draw" then
		bump("Draws", 1)
	else
		bump("Losses", 1)
	end

	local news = ClubService.finishMatch(scorerSlots, homeSquad)
	local scorers = {}
	for _, ev in result.events do
		local scorer = (ev :: any).scorer
		if scorer and homeSquad[scorer] then
			table.insert(scorers, ("%d' %s"):format(ev.minute, homeSquad[scorer].name))
		end
	end
	-- league bookkeeping last: at season end this ages the squad and rolls the division
	local roundResult = SeasonService.recordPlayerResult(result.homeGoals, result.awayGoals, settlement.outcome)

	ClubState.set("Phase", "Manage")
	running = false

	local settled = MatchService.onSettled
	if settled then
		task.spawn(settled)
	end

	remote("MatchSummary"):FireAllClients({
		opponent = fixture.opponent,
		homeGoals = result.homeGoals,
		awayGoals = result.awayGoals,
		outcome = settlement.outcome,
		attendance = settlement.attendance,
		capacity = settlement.capacity,
		turnedAway = settlement.turnedAway,
		ticketRevenue = settlement.ticketRevenue,
		concessionRevenue = settlement.concessionRevenue,
		resultBonus = settlement.resultBonus,
		total = settlement.total,
		cash = ClubState.get("Cash"),
		scorers = scorers,
		news = news,
		division = ClubState.get("DivisionName"),
		position = roundResult.position,
		round = roundResult.round,
		rounds = roundResult.rounds,
		season = roundResult.summary,
	})
	return true
end

return MatchService
