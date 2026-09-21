--!strict
-- Runs a matchday: locks the club, runs the hidden sim, publishes the timeline
-- for clients to visualise, replays goal events on the scoreboard over the
-- match duration, then settles revenue and reports the result to the league.
-- The final score always comes from the sim, never from what was displayed.
-- Friendlies against another club on the server share the same matchday but
-- skip the league, injuries and development (I3.1).
--
-- Phases: Manage -> PreMatch (iris + walkout) -> Match (clock running) -> Manage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local MatchSim = require(ReplicatedStorage.Shared.MatchSim)
local Economy = require(ReplicatedStorage.Shared.Economy)
local TeamGen = require(ReplicatedStorage.Shared.TeamGen)
local Squad = require(ReplicatedStorage.Shared.Squad)
local DayCycle = require(ReplicatedStorage.Shared.DayCycle)
local Friendly = require(ReplicatedStorage.Shared.Friendly)
local ClubState = require(script.Parent.ClubState)
local PlotContext = require(script.Parent.PlotContext)
local WorldBuilder = require(script.Parent.WorldBuilder)
local ClubService = require(script.Parent.ClubService)
local SeasonService = require(script.Parent.SeasonService)

local MatchService = {}

export type Opponent = {
	name: string,
	kit: { number },
	strength: number,
	squad: { any },
}

type Played = {
	result: MatchSim.Result,
	scorerSlots: { number },
	capacity: number,
	demand: number,
}

local running = false
local homeSquad: { Squad.MatchPlayer } = {}
-- X314: rebuilds this match's crowd at a share of the gate; nil between matches
local crowdFill: ((number) -> ())? = nil
local matchMinute = 0 -- the scoreboard minute, stamped on substitutions (X218)
local eventsShown = 0 -- timeline events already on the scoreboard, stamped on substitutions
local subsMade: { Squad.Sub } = {}
-- X271: the match being played, so a change of tactic can replay what is left
-- of it. nil between matches.
local live: {
	result: MatchSim.Result,
	sim: MatchSim.Params,
	timeline: { [string]: any },
	duration: number,
}? = nil
-- X271: the owner has pressed ATTACK / DEFEND this match, so the coach leaves
-- the tactic alone until the whistle
local tacticByHand = false

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

local function jsonToColor(c: { number }): Color3
	return Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
end

-- X271: plays the rest of the match again under the new tactic. The result
-- table is changed in place (playCore's clock loop reads it every tick) and
-- the timeline is published again for the presenters; everything already
-- shown, and anything close enough to be in build-up, is kept as it was.
local function retune(tactic: MatchSim.Tactic)
	local m = live
	if not m then
		return
	end
	local params = table.clone(m.sim) :: any
	params.result = m.result
	params.fromMinute = matchMinute
	params.tactic = tactic
	params.lockMinutes = MatchSim.lockMinutes(m.duration)
	local fresh, kept = MatchSim.resimulate(params)
	local tail = table.move(fresh.events, kept + 1, #fresh.events, 1, {})
	Squad.assignScorers(tail :: any, homeSquad, Random.new())
	m.result.events = fresh.events
	m.result.homeGoals = fresh.homeGoals
	m.result.awayGoals = fresh.awayGoals
	m.timeline.events = fresh.events
	ClubState.set("Timeline", HttpService:JSONEncode(m.timeline))
end

local function setTactic(tactic: MatchSim.Tactic)
	if ClubState.get("Tactic") ~= tactic then
		retune(tactic)
		ClubState.set("Tactic", tactic)
	end
end

local COACH_CALLS = {
	Attack = "The coach throws men forward.",
	Defend = "The coach shuts up shop.",
	Balanced = "The coach settles it back down.",
}

-- Attack / Defend / Balanced / Sub. Returns false plus a reason if refused.
function MatchService.applyTactic(action: string): (boolean, string?)
	if ClubState.get("Phase") ~= "Match" then
		return false, "No match in progress"
	end
	if action == "Attack" or action == "Defend" or action == "Balanced" then
		tacticByHand = true
		setTactic(action :: MatchSim.Tactic)
		return true
	elseif action == "Sub" then
		local sub = Squad.nextSub(homeSquad, subsMade)
		if not sub then
			return false, "No substitutions left"
		end
		sub.minute = matchMinute
		sub.afterEvent = eventsShown
		table.insert(subsMade, sub)
		ClubState.set("Subs", HttpService:JSONEncode(subsMade))
		return true
	end
	return false, "Unknown action"
end

-- True from kickoff prep until the result is settled.
function MatchService.isRunning(): boolean
	return running
end

function MatchService.init()
	remote("MatchSummary")
	remote("Toast")
	local tactic = remote("Tactic")
	PlotContext.onRemote(tactic, function(player: Player, action: unknown)
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

-- Shared matchday: sim up front, crowd, PreMatch walkout, Match clock with
-- goals replayed on the scoreboard, authoritative final score. Leaves the
-- club in Match phase; the caller settles and calls finishCore.
local function playCore(opponent: Opponent, bias: number, evening: boolean, duration: number, walkout: number, playerIsAway: boolean?): Played
	-- Simulation layer: result decided up front from squad strength vs the opponent.
	local prepared = ClubService.prepareMatch()
	homeSquad = prepared.matchSquad
	local simParams: MatchSim.Params = {
		homeStrength = prepared.strength,
		awayStrength = opponent.strength,
		bias = bias :: any,
		-- X261: an away fixture gives the venue advantage to the opponent. The
		-- match is still watched at this club's ground (CLAUDE.md MVP scope).
		playerIsAway = playerIsAway,
	}
	local result = MatchSim.simulate(simParams)
	local scorerSlots = Squad.assignScorers(result.events :: any, homeSquad, Random.new())
	subsMade = {}
	matchMinute = 0
	eventsShown = 0

	local capacity = ClubState.capacity()
	local demand = SeasonService.demand()
	local attendance = math.min(capacity, demand)
	-- X297: the visiting club's colours fill one end
	-- X310: away from home the stands wear the hosts' colour and our following
	-- takes the away end
	local ourKit = ClubState.kit() -- crest builder: the club's own colours
	local theirKit = Config.pitchKit(jsonToColor(opponent.kit), ourKit)
	-- X314: the stands used to snap from empty to a full house one frame before
	-- the walkout, while X104's fans were still queueing outside, and stayed
	-- full through the 45s X161 spends walking them home. The ground fills in
	-- three steps instead: a third of the gate in before kick-off, the rest by
	-- the whistle, and a thin crowd left while the leavers walk out.
	local function fill(share: number)
		if playerIsAway then
			WorldBuilder.buildCrowd(ClubState.plotLevels(), attendance, capacity, ourKit, theirKit, share)
		else
			WorldBuilder.buildCrowd(ClubState.plotLevels(), attendance, capacity, theirKit, nil, share)
		end
	end
	crowdFill = fill
	fill(Config.CrowdEarlyShare)

	-- X310: the venue of the match actually being played (X261 published only
	-- the next fixture's), so the scoreboard, the crowd and the card can dress
	-- an away match as an away match
	ClubState.set("AtHome", playerIsAway ~= true)
	ClubState.set("Opponent", opponent.name)
	ClubState.set("HomeGoals", 0)
	ClubState.set("AwayGoals", 0)
	ClubState.set("MatchDuration", duration)
	ClubState.set("TimeLeft", duration)
	ClubState.set("Attendance", attendance)
	ClubState.set("Tactic", "Balanced")
	tacticByHand = false
	ClubState.set("Subs", "[]")
	ClubState.set("InjuryNews", "") -- X334: last week's casualty is not this week's
	ClubState.set("InjuryMinute", 0) -- X344
	ClubState.set("Evening", evening)
	local timeline = {
		events = result.events,
		home = { name = ClubState.get("ClubName"), kit = colorToJson(ourKit), squad = homeSquad },
		-- X263: shift an away kit that would read as this club's own colour
		away = { name = opponent.name, kit = colorToJson(theirKit), squad = opponent.squad },
	}
	ClubState.set("Timeline", HttpService:JSONEncode(timeline))
	live = { result = result, sim = simParams, timeline = timeline, duration = duration } -- X271
	ClubState.set("Phase", "PreMatch")

	-- Review of X314: filling the ground on the kick-off frame rebuilt every
	-- fan (up to MAX_FANS rigs) in the first frame of the match, where a phone
	-- would feel it. The build happens in the last second and a half of the
	-- walkout instead, under the presentation, and the ground is still full
	-- when the whistle goes.
	local settle = math.min(walkout, 1.5)
	task.wait(math.max(walkout - settle, 0))
	fill(1)
	task.wait(settle)

	ClubState.set("KickoffAt", workspace:GetServerTimeNow())
	ClubState.set("Phase", "Match")

	-- X334: the man the sim put down, once his minute comes round
	local injuredSlot: number? = nil
	local injuredId: number? = nil
	-- X344: a friendly has no injuries (Friendly TEMP rules, CLAUDE.md s27),
	-- but the sim rolls one for every match, so the friendly path was walking
	-- a man off and announcing him - and then he was fit, because friendlies
	-- never reach ClubService.finishMatch.
	local injury = if ClubState.get("Friendly") == true then nil else result.injury

	-- X333: what the coach is allowed to do on his own this match
	local coachLevel = (ClubState.get("CoachLevel") :: number?) or 0
	local coachSubs = (Config.CoachLevels[coachLevel + 1] or Config.CoachLevels[1]).autoSubs or 0

	-- Presentation layer (scoreboard): replay goal events against the clock.
	local startClock = os.clock()
	local nextEvent = 1
	while true do
		local elapsed = os.clock() - startClock
		if elapsed >= duration then
			break
		end
		local minute = math.floor(elapsed / duration * 90)
		matchMinute = minute
		while result.events[nextEvent] and result.events[nextEvent].minute <= minute do
			local ev = result.events[nextEvent]
			if ev.type == "GOAL" then
				bump(ev.team == "Home" and "HomeGoals" or "AwayGoals", 1)
			end
			nextEvent += 1
		end
		eventsShown = nextEvent - 1
		-- X334: one of ours goes down at his minute, and comes off if there is
		-- anybody to bring on. The injury itself is applied after the whistle.
		if injury and injuredSlot == nil and minute >= injury.minute then
			injuredSlot = injury.slot
			-- X344: the man in that shirt *now*. A coach substitution earlier in
			-- the match can have taken the starter off already, and this used to
			-- name him, walk him off a second time and injure him for next week
			-- while the substitute actually playing was untouched.
			local slot = Squad.filledBy(subsMade, injury.slot)
			local hurt = homeSquad[slot]
			if hurt and hurt.id > 0 then
				injuredId = hurt.id
			end
			local forced = Squad.forcedSub(homeSquad, subsMade, slot)
			if forced then
				forced.minute = minute
				forced.afterEvent = eventsShown
				table.insert(subsMade, forced)
				ClubState.set("Subs", HttpService:JSONEncode(subsMade))
			end
			if hurt then
				-- X344: and he only "cannot carry on" if somebody can replace
				-- him. With an empty bench (or the subs spent) he limps on, and
				-- the ground should be told that instead.
				ClubState.set("InjuryMinute", minute)
				ClubState.set("InjuryNews", if forced
					then ("%d %s is down, and cannot carry on."):format(hurt.number, hurt.name)
					else ("%d %s is down, with nobody to bring on."):format(hurt.number, hurt.name))
			end
		end
		-- X333: the coach makes his own changes on the clock, through exactly
		-- the same path as the SUB button
		while coachSubs > 0 and Squad.coachWantsSub(minute, subsMade, coachSubs) do
			local sub = Squad.nextSub(homeSquad, subsMade)
			if not sub then
				break
			end
			sub.minute = minute
			sub.afterEvent = eventsShown
			table.insert(subsMade, sub)
			ClubState.set("Subs", HttpService:JSONEncode(subsMade))
		end
		-- X271: and reads the score, unless the owner has taken the tactic over
		if not tacticByHand then
			local want = Squad.coachTactic(minute, ClubState.get("HomeGoals") :: number, ClubState.get("AwayGoals") :: number, coachLevel)
			if want and want ~= ClubState.get("Tactic") then
				setTactic(want)
				local owner = ClubState.owner()
				if owner then
					remote("Toast"):FireClient(owner, COACH_CALLS[want])
				end
			end
		end
		ClubState.set("TimeLeft", math.ceil(duration - elapsed))
		task.wait(0.25)
	end

	-- Authoritative final score, regardless of presentation timing.
	live = nil -- X271: the whistle has gone; nothing more can change it
	ClubState.set("HomeGoals", result.homeGoals)
	ClubState.set("AwayGoals", result.awayGoals)
	ClubState.set("TimeLeft", 0)
	matchMinute = 90
	-- X218: goals after a substitution belong to the player who came on
	scorerSlots = Squad.creditScorers(result.events :: any, subsMade)

	return { result = result, scorerSlots = scorerSlots, capacity = capacity, demand = demand, injuredId = injuredId }
end

local function scorerLines(result: MatchSim.Result): { string }
	local scorers = {}
	for _, ev in result.events do
		local scorer = (ev :: any).scorer
		if scorer and homeSquad[scorer] then
			local p = homeSquad[scorer]
			-- trialists share a name; the shirt number tells two of them apart
			local name = if p.id < 0 then ("%s (%d)"):format(p.name, p.number) else p.name
			table.insert(scorers, ("%d' %s"):format(ev.minute, name))
		end
	end
	return scorers
end

local function finishCore()
	live = nil -- X271: also on the error path
	ClubState.set("Phase", "Manage")
	-- X314: the ground empties while X161's leavers are walking home, rather
	-- than staying full and then vanishing
	local thin = crowdFill
	crowdFill = nil
	if thin then
		local ok = pcall(thin, Config.CrowdLeavingShare)
		if not ok then
			WorldBuilder.clearCrowd()
		end
		-- Review of X314: the timer only checked `running`, but the owner can
		-- leave inside those 40 s and the plot be claimed again; clearCrowd
		-- resolves the club lazily, so it would have emptied the new
		-- claimant's stands mid-match. Bail if the club is not ours any more.
		local ourClub = PlotContext.clubModel()
		task.delay(Config.CrowdEmptySeconds, function()
			if not running and ourClub and ourClub.Parent and PlotContext.clubModel() == ourClub then
				WorldBuilder.clearCrowd()
			end
		end)
	else
		WorldBuilder.clearCrowd()
	end
	running = false

	local settled = MatchService.onSettled
	if settled then
		task.spawn(settled)
	end
end

-- Overrides exist for tests only.
local function playMatchInner(durationOverride: number?, walkoutOverride: number?): boolean
	if running or ClubState.get("Phase") ~= "Manage" then
		return false
	end
	local fixture = SeasonService.nextFixture()
	if not fixture then
		return false
	end
	running = true

	local matchIndex = (ClubState.get("MatchesPlayed") :: number) + 1
	local played = playCore({
		name = fixture.opponent,
		kit = fixture.kit,
		strength = fixture.strength,
		-- opponents keep the same names for both meetings in a season
		squad = TeamGen.generate(fixture.seed),
	},
		MatchSim.biasForMatch(matchIndex),
		-- TEMP rule in DayCycle: some fixtures kick off under the floodlights
		DayCycle.isEveningFixture(matchIndex),
		durationOverride or Config.MatchDurationSeconds,
		walkoutOverride or Config.WalkoutSeconds,
		fixture.atHome == false
	)
	local result = played.result

	local amenity = Config.AmenityLevels[((ClubState.get("AmenityLevel") :: number?) or 0) + 1]
	local settlement = Economy.settle({
		homeGoals = result.homeGoals,
		awayGoals = result.awayGoals,
		capacity = played.capacity,
		demand = played.demand,
		ticketPrice = Config.TicketPrice,
		concessionPerFan = amenity.perFan,
		merchPerFan = amenity.merchPerFan, -- X353: the club shop's stock
		winBonus = Config.WinBonus,
		drawBonus = Config.DrawBonus,
		lossBonus = Config.LossBonus,
		-- X309: the shirt sponsor's match fee
		tier = (ClubState.get("Tier") :: number?) or 1,
		popularity = (ClubState.get("Popularity") :: number?) or 0,
		sponsorSeed = ((ClubState.get("Season") :: number?) or 1) + #((ClubState.get("ClubName") :: string?) or ""),
		atHome = fixture.atHome ~= false, -- X361: the gate belongs to the hosts
		-- X350: and what the club costs to run for a match
		squadAverage = ClubService.squadAverage(),
		squadSize = ClubService.squadSize(),
		coachLevel = (ClubState.get("CoachLevel") :: number?) or 0,
		scoutLevel = (ClubState.get("ScoutLevel") :: number?) or 0,
	})

	local news, development, award = ClubService.finishMatch(played.scorerSlots, homeSquad, subsMade, result.awayGoals, played.injuredId)
	local scorers = scorerLines(result)
	-- X301 (review): the season service publishes the office fixture notice,
	-- and the evening-kickoff rule counts the club's matches, so the count has
	-- to be right before the round is recorded. The payment still comes last.
	bump("MatchesPlayed", 1)
	-- X332: the approach belongs to the match that has just been counted, so it
	-- is asked for here rather than inside finishMatch, which runs before the
	-- count moves (a bid stamped with the old number was dropped as stale by
	-- the next rejoin)
	ClubService.considerBid()
	-- league bookkeeping after the squad: at season end this ages the squad and rolls the division
	local roundResult = SeasonService.recordPlayerResult(result.homeGoals, result.awayGoals, settlement.outcome)

	-- review of X200: pay last, so an error above that repeats every match can't
	-- pay out again and again for a fixture that never moves on
	-- X299: the gate, the pie money and the win bonus are three different
	-- answers to "where did that come from", so they are recorded apart
	ClubState.addCash(settlement.ticketRevenue, "gate")
	ClubState.addCash(settlement.concessionRevenue, "concessions")
	ClubState.addCash(settlement.merchRevenue, "merch") -- X353
	ClubState.addCash(settlement.resultBonus, "bonus")
	ClubState.addCash(settlement.sponsorFee, "sponsor") -- X309
	-- X350: and the two things the matchday costs, which is the first money the
	-- player did not choose to spend. X359: what the club could actually pay -
	-- the balance clamps at zero, so a loss against an empty account takes
	-- less than the bill, and the row has to report what moved.
	local paidWages = -ClubState.addCash(-settlement.wages, "wages")
	local paidUpkeep = -ClubState.addCash(-settlement.upkeep, "upkeep")
	local paidCosts = paidWages + paidUpkeep
	local netTotal = settlement.income - paidCosts

	ClubState.recordMatchFinance({
		round = roundResult.round,
		gate = settlement.ticketRevenue,
		concessions = settlement.concessionRevenue,
		merch = settlement.merchRevenue, -- X353
		bonus = settlement.resultBonus,
		sponsor = settlement.sponsorFee, -- X309, so the row adds up
		costs = paidCosts, -- X350/X359: what was actually paid
		total = netTotal,
	})
	if settlement.outcome == "Win" then
		bump("Wins", 1)
	elseif settlement.outcome == "Draw" then
		bump("Draws", 1)
	else
		bump("Losses", 1)
	end

	finishCore()

	-- only the owner sees their club's summary
	local owner = ClubState.owner()
	if not owner then
		return true
	end
	remote("MatchSummary"):FireClient(owner, {
		opponent = fixture.opponent,
		awayKit = colorToJson(Config.pitchKit(jsonToColor(fixture.kit), ClubState.kit())),
		homeGoals = result.homeGoals,
		awayGoals = result.awayGoals,
		outcome = settlement.outcome,
		attendance = settlement.attendance,
		capacity = settlement.capacity,
		turnedAway = settlement.turnedAway,
		ticketRevenue = settlement.ticketRevenue,
		merchRevenue = settlement.merchRevenue, -- X353
		atHomeMoney = settlement.atHome, -- X361 (the card already has atHome)
		wages = paidWages, -- X350/X359: what the club could actually pay
		upkeep = paidUpkeep,
		costs = paidCosts,
		income = settlement.income,
		concessionRevenue = settlement.concessionRevenue,
		resultBonus = settlement.resultBonus,
		sponsorFee = settlement.sponsorFee, -- X309
		sponsorName = settlement.sponsorName,
		total = settlement.total,
		cash = ClubState.get("Cash"),
		scorers = scorers,
		news = news,
		development = development,
		-- X216: the season may have rolled over; the card is about the season just played
		division = if roundResult.summary then roundResult.summary.division else ClubState.get("DivisionName"),
		position = roundResult.position,
		round = roundResult.round,
		rounds = roundResult.rounds,
		season = roundResult.summary,
		elsewhere = roundResult.elsewhere, -- X294
		atHome = fixture.atHome ~= false, -- X310
		award = award, -- X302
	})
	return true
end

-- X200: an error anywhere in a match (walkout, simulation, crowd, settlement,
-- season bookkeeping) used to leave `running` set and the Phase stuck in
-- PreMatch/Match, locking every button until the owner rejoined. The wrappers
-- below put the club back into Manage instead.
local function recoverFromMatchError(err: any)
	warn("[FCT] match failed: " .. tostring(err))
	ClubState.set("Friendly", false)
	if running or ClubState.get("Phase") ~= "Manage" then
		finishCore()
	end
end

function MatchService.playMatch(durationOverride: number?, walkoutOverride: number?): boolean
	local ok, started = pcall(playMatchInner, durationOverride, walkoutOverride)
	if not ok then
		recoverFromMatchError(started)
		return false
	end
	return started
end

-- The side this club would send to a friendly away from home. Reads the squad
-- only; nothing saved changes.
function MatchService.awayTeam(): Opponent
	local prepared = ClubService.prepareMatch()
	local name = ClubState.get("ClubName") :: string
	return {
		name = name,
		kit = colorToJson(ClubState.kit()), -- a player club: its crest colours
		strength = prepared.strength,
		squad = prepared.matchSquad,
	}
end

-- A friendly at this ground (I3.1). TEMP rules in Friendly: no injuries or
-- development, no league table, not in W/D/L or MatchesPlayed; the home club
-- gets a share of the gate. Returns the final score for the away owner.
local function playFriendlyInner(opponent: Opponent, durationOverride: number?, walkoutOverride: number?): (boolean, number?, number?)
	if running or ClubState.get("Phase") ~= "Manage" then
		return false
	end
	running = true
	ClubState.set("Friendly", true)

	local played = playCore(
		opponent,
		0,
		false,
		durationOverride or Config.MatchDurationSeconds,
		walkoutOverride or Config.WalkoutSeconds
	)
	local result = played.result
	local payout = Friendly.homePayout(played.capacity, played.demand, Config.TicketPrice)
	ClubState.addCash(payout, "friendly") -- X299
	local scorers = scorerLines(result)
	local outcome = if result.homeGoals > result.awayGoals
		then "Win"
		elseif result.homeGoals == result.awayGoals then "Draw"
		else "Loss"

	ClubState.set("Friendly", false)
	finishCore()

	local owner = ClubState.owner()
	if owner then
		remote("MatchSummary"):FireClient(owner, {
			friendly = true,
			opponent = opponent.name,
			awayKit = colorToJson(Config.pitchKit(jsonToColor(opponent.kit), ClubState.kit())),
			homeGoals = result.homeGoals,
			awayGoals = result.awayGoals,
			outcome = outcome,
			attendance = math.min(played.capacity, played.demand),
			capacity = played.capacity,
			turnedAway = math.max(0, played.demand - played.capacity),
			ticketRevenue = payout,
			concessionRevenue = 0,
			resultBonus = 0,
			total = payout,
			cash = ClubState.get("Cash"),
			scorers = scorers,
			news = {},
			development = {},
			division = "Friendly",
		})
	end
	return true, result.homeGoals, result.awayGoals
end

function MatchService.playFriendly(opponent: Opponent, durationOverride: number?, walkoutOverride: number?): (boolean, number?, number?)
	local ok, started, home, away = pcall(playFriendlyInner, opponent, durationOverride, walkoutOverride)
	if not ok then
		recoverFromMatchError(started)
		return false
	end
	return started, home, away
end

return MatchService
