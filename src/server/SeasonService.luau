--!strict
-- Owns the league season: which division the club is in, the fixtures and
-- table, the round counter and club popularity. MatchService asks it for the
-- next fixture and reports the result; it simulates the rest of the round and
-- handles the end of the season. League maths lives in League.luau.
-- The season persists: Session restores it from the profile and serializes it back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local League = require(ReplicatedStorage.Shared.League)
local Economy = require(ReplicatedStorage.Shared.Economy)
local DayCycle = require(ReplicatedStorage.Shared.DayCycle) -- X301: evening kickoffs on the notice
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local ClubService = require(script.Parent.ClubService)
local HistoryService = require(script.Parent.HistoryService)

local SeasonService = {}

local season: League.Season
local tier = 1
local seasonNumber = 1
local round = 0 -- matches played this season
local popularity = Config.StartingPopularity
local rng = Random.new()

export type Fixture = {
	round: number,
	rounds: number,
	opponent: string,
	strength: number,
	kit: { number },
	seed: number,
	atHome: boolean, -- X261: the fixture list alternates venues
}

export type SeasonSummary = {
	season: number,
	division: string,
	position: number,
	outcome: League.Outcome,
	prize: number,
	nextDivision: string,
	nextTier: number,
	retirements: { string }, -- X277: who hung up their boots at the end of it
	arrivals: { string }, -- and who came up from the academy to replace them
}

local function publishTable()
	local rows = {}
	for _, row in League.standings(season) do
		table.insert(rows, {
			position = row.position,
			name = row.name,
			isPlayer = row.isPlayer,
			played = row.played,
			won = row.won,
			drawn = row.drawn,
			lost = row.lost,
			gd = row.gf - row.ga,
			gf = row.gf,
			points = row.points,
		})
	end
	ClubState.set("LeagueTable", HttpService:JSONEncode(rows))
	ClubState.set("Position", League.positionOf(season, season.playerIndex))
end

local function publish()
	ClubState.set("Tier", tier)
	ClubState.set("DivisionName", League.divisionName(tier))
	ClubState.set("Season", seasonNumber)
	ClubState.set("Round", round)
	ClubState.set("Rounds", season.rounds)
	ClubState.set("Popularity", popularity)
	ClubState.set("Demand", SeasonService.demand())
	local nextF, opp = League.playerFixture(season, round + 1)
	ClubState.set("NextOpponent", if opp then season.teams[opp].name else "")
	-- X261 (review): the venue decides the sim's home advantage, so it has to be
	-- on screen. TEMP: the match is still played and paid for at this ground.
	ClubState.set("NextAtHome", if nextF then nextF.home == season.playerIndex else true)
	publishTable()
	-- X301: the office notice, from the fixtures that are actually left
	local notice = {}
	local played = (ClubState.get("MatchesPlayed") :: number?) or 0
	for ahead = 1, 4 do
		local f, opp = League.playerFixture(season, round + ahead)
		if f and opp then
			local name = season.teams[opp].name
			local short = string.match(name, "^(%S+)") or name
			local evening = DayCycle.isEveningFixture(played + ahead)
			table.insert(notice, ("%s %s %s"):format(
				if f.home == season.playerIndex then "H" else "A",
				string.sub(short, 1, 9),
				if evening then "7:45" else "3pm"
			))
		end
	end
	WorldBuilder.setFixtureNotice(notice)
	ClubState.markDirty()
end

local function startSeason()
	season = League.newSeason(tier, rng:NextInteger(1, 1000000), ClubState.get("ClubName") :: string, Config.HomeSquadSeed)
	round = 0
end

function SeasonService.init()
	tier = 1
	seasonNumber = 1
	round = 0
	popularity = Config.StartingPopularity
end

-- nil = a brand-new club. A malformed season (or one whose round counter
-- disagrees with its fixtures) restarts the current season fresh.
function SeasonService.restore(data: any?)
	if type(data) == "table" then
		tier = math.clamp(if type(data.tier) == "number" then math.floor(data.tier) else 1, 1, League.topTier())
		seasonNumber = math.max(if type(data.seasonNumber) == "number" then math.floor(data.seasonNumber) else 1, 1)
		popularity = math.clamp(if type(data.popularity) == "number" then data.popularity else Config.StartingPopularity, 0, 100)
		local savedRound = if type(data.round) == "number" then math.floor(data.round) else -1
		if League.isValid(data.league) and data.league.tier == tier and savedRound >= 0 and savedRound < data.league.rounds then
			season = data.league
			round = savedRound
			-- the table is the club's; keep its name in step with the profile
			season.teams[season.playerIndex].name = ClubState.get("ClubName") :: string
		else
			if data.league ~= nil then
				warn("[FCT] saved season was invalid; starting the season again")
			end
			startSeason()
		end
	else
		tier = 1
		seasonNumber = 1
		popularity = Config.StartingPopularity
		startSeason()
	end
	publish()
end

function SeasonService.serialize()
	return {
		tier = tier,
		seasonNumber = seasonNumber,
		round = round,
		popularity = popularity,
		league = season,
	}
end

-- The club was named / renamed: the league table row follows.
function SeasonService.renameClub(name: string)
	season.teams[season.playerIndex].name = name
	publish()
end

-- X262: this season's wins minus losses, so a run shows up at the gate
local function formNet(): number
	-- read the player's own row: standings() clones and sorts every team, and
	-- demand() can be asked before a season is restored
	local row = season and season.teams[season.playerIndex]
	return if row then row.won - row.lost else 0
end

function SeasonService.demand(): number
	return Economy.demand(tier, popularity, (ClubState.get("AmenityLevel") :: number?) or 0, formNet())
end

-- The player's next match. nil only if the season is somehow complete.
function SeasonService.nextFixture(): Fixture?
	local f, opp = League.playerFixture(season, round + 1)
	if not f or not opp then
		return nil
	end
	local team = season.teams[opp]
	return {
		round = round + 1,
		rounds = season.rounds,
		opponent = team.name,
		strength = team.strength + rng:NextInteger(-3, 3),
		kit = team.kit,
		seed = team.seed,
		atHome = f.home == season.playerIndex,
	}
end

export type RoundResult = {
	elsewhere: { League.RoundResult }, -- X294: the other clubs' scores this round
	position: number,
	round: number,
	rounds: number,
	seasonOver: boolean,
	summary: SeasonSummary?,
}

-- Records the player's result, plays the rest of the round, and rolls the
-- season over after the final match.
function SeasonService.recordPlayerResult(goalsFor: number, goalsAgainst: number, outcome: string): RoundResult
	round += 1
	League.completeRound(season, round, goalsFor, goalsAgainst, rng)
	popularity = Economy.popularityAfter(popularity, outcome)
	local position = League.positionOf(season, season.playerIndex)
	-- X294: the rest of the division's scores, for the summary card and the
	-- league tab (the player's own fixture is dropped: it is the card's headline)
	local elsewhere = {}
	for _, r in League.roundResults(season, round) do
		if not r.player then
			table.insert(elsewhere, r)
		end
	end
	ClubState.set("LastRound", HttpService:JSONEncode({ round = round, results = elsewhere }))
	local result: RoundResult = {
		position = position,
		round = round,
		rounds = season.rounds,
		seasonOver = League.isOver(season),
		summary = nil,
		elsewhere = elsewhere,
	}
	if result.seasonOver then
		result.summary = SeasonService.endSeason()
	else
		publish()
	end
	return result
end

function SeasonService.endSeason(): SeasonSummary
	local outcome, position = League.outcome(season)
	local prize = League.prizeFor(tier, position)
	local oldDivision = League.divisionName(tier)
	local oldSeason = seasonNumber

	-- club history: the player's final row before the table is thrown away
	local row = season.teams[season.playerIndex]
	HistoryService.record({
		season = oldSeason,
		tier = tier,
		division = oldDivision,
		position = position,
		outcome = outcome,
		played = row.played,
		won = row.won,
		drawn = row.drawn,
		lost = row.lost,
		gf = row.gf,
		ga = row.ga,
		points = row.points,
		prize = prize,
	})

	ClubState.addCash(prize)
	if outcome == "Promoted" then
		tier += 1
		popularity = Economy.popularityAfter(popularity, "Promoted")
	elseif outcome == "Relegated" then
		tier -= 1
		popularity = Economy.popularityAfter(popularity, "Relegated")
	elseif outcome == "Champions" then
		popularity = Economy.popularityAfter(popularity, "Champions")
	end
	-- X262: drift toward the new division's baseline before the next season
	popularity = Economy.popularityAtSeasonEnd(popularity, tier)
	seasonNumber += 1
	local retirements, arrivals, retired = ClubService.newSeason()
	HistoryService.recordRetirements(retired, oldSeason)
	startSeason()
	publish()

	return {
		season = oldSeason,
		division = oldDivision,
		position = position,
		outcome = outcome,
		prize = prize,
		nextDivision = League.divisionName(tier),
		nextTier = tier,
		retirements = retirements,
		arrivals = arrivals,
	}
end

-- Studio only: jump straight to a division to look at its clubs and crests
-- without playing up to it. Starts that division's season from scratch.
function SeasonService.setTier(newTier: number): (boolean, string)
	local clamped = math.clamp(math.floor(newTier), 1, League.topTier())
	tier = clamped
	popularity = Config.StartingPopularity
	startSeason()
	publish()
	return true, ("tier %d: %s"):format(clamped, League.divisionName(clamped))
end

function SeasonService.refreshDemand()
	ClubState.set("Demand", SeasonService.demand())
end

return SeasonService
