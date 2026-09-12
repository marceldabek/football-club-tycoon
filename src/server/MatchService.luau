--!strict
-- Runs a matchday: locks the club, runs the hidden sim, replays goal events on
-- the scoreboard over the match duration, then settles revenue.
-- The final score always comes from the sim, never from what was displayed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local MatchSim = require(ReplicatedStorage.Shared.MatchSim)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ClubState = require(script.Parent.ClubState)

local MatchService = {}

local running = false

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

local function summaryEvent(): RemoteEvent
	local remotes = findOrCreate(ReplicatedStorage, "Remotes", "Folder")
	return findOrCreate(remotes, "MatchSummary", "RemoteEvent") :: RemoteEvent
end

function MatchService.init()
	summaryEvent()
end

local function bump(key: string, delta: number)
	ClubState.set(key, (ClubState.get(key) :: number) + delta)
end

-- durationOverride exists for tests only.
function MatchService.playMatch(durationOverride: number?): boolean
	if running or ClubState.get("Phase") ~= "Manage" then
		return false
	end
	running = true

	local matchIndex = (ClubState.get("MatchesPlayed") :: number) + 1
	local opponent = Config.OpponentNames[((matchIndex - 1) % #Config.OpponentNames) + 1]
	local duration = durationOverride or Config.MatchDurationSeconds

	ClubState.set("Opponent", opponent)
	ClubState.set("HomeGoals", 0)
	ClubState.set("AwayGoals", 0)
	ClubState.set("MatchDuration", duration)
	ClubState.set("TimeLeft", duration)
	ClubState.set("Phase", "Match")

	-- Simulation layer: result decided up front.
	local result = MatchSim.simulate({
		homeStrength = Config.HomeStrength,
		awayStrength = Config.AwayStrength,
		bias = MatchSim.biasForMatch(matchIndex),
	})

	-- Presentation layer: replay goal events against the clock.
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
			if ev.team == "Home" then
				bump("HomeGoals", 1)
			else
				bump("AwayGoals", 1)
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

	local settlement = Economy.settle({
		homeGoals = result.homeGoals,
		awayGoals = result.awayGoals,
		capacity = ClubState.capacity(),
		demand = Config.BaseDemand,
		ticketPrice = Config.TicketPrice,
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
	ClubState.set("Phase", "Manage")
	running = false

	summaryEvent():FireAllClients({
		opponent = opponent,
		homeGoals = result.homeGoals,
		awayGoals = result.awayGoals,
		outcome = settlement.outcome,
		attendance = settlement.attendance,
		capacity = settlement.capacity,
		turnedAway = settlement.turnedAway,
		ticketRevenue = settlement.ticketRevenue,
		resultBonus = settlement.resultBonus,
		total = settlement.total,
		cash = ClubState.get("Cash"),
	})
	return true
end

return MatchService
