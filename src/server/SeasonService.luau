--!strict
-- Owns the league season: which division the club is in, the fixtures and
-- table, the round counter and club popularity. MatchService asks it for the
-- next fixture and reports the result; it simulates the rest of the round and
-- handles the end of the season. League maths lives in League.luau.
-- TEMP: one shared club per server until persistence (Milestone 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local League = require(ReplicatedStorage.Shared.League)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ClubState = require(script.Parent.ClubState)
local ClubService = require(script.Parent.ClubService)

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
}

export type SeasonSummary = {
	season: number,
	division: string,
	position: number,
	outcome: League.Outcome,
	prize: number,
	nextDivision: string,
	nextTier: number,
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
	local _, opp = League.playerFixture(season, round + 1)
	ClubState.set("NextOpponent", if opp then season.teams[opp].name else "")
	publishTable()
end

local function startSeason()
	season = League.newSeason(tier, rng:NextInteger(1, 1000000), ClubState.get("ClubName") :: string, Config.HomeSquadSeed)
	round = 0
end

function SeasonService.init()
	tier = 1
	seasonNumber = 1
	popularity = Config.StartingPopularity
	startSeason()
	publish()
end

function SeasonService.demand(): number
	return Economy.demand(tier, popularity, (ClubState.get("AmenityLevel") :: number?) or 0)
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
	}
end

export type RoundResult = {
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
	local result: RoundResult = {
		position = position,
		round = round,
		rounds = season.rounds,
		seasonOver = League.isOver(season),
		summary = nil,
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
	seasonNumber += 1
	ClubService.newSeason()
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
	}
end

function SeasonService.refreshDemand()
	ClubState.set("Demand", SeasonService.demand())
end

return SeasonService
