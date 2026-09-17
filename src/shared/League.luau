--!strict
-- League season: teams, round-robin fixtures, results table, promotion and
-- relegation. Pure and deterministic given a seed. The player's own matches
-- are played by MatchService; this module simulates the rest of each round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local MatchSim = require(ReplicatedStorage.Shared.MatchSim)

local League = {}

export type Team = {
	name: string,
	strength: number,
	kit: { number }, -- RGB 0..255 for JSON
	isPlayer: boolean,
	seed: number, -- visual squad seed so opponents keep their names all season
	-- record
	played: number,
	won: number,
	drawn: number,
	lost: number,
	gf: number,
	ga: number,
	points: number,
}

export type Fixture = { round: number, home: number, away: number, played: boolean, hg: number?, ag: number? }

export type Season = {
	tier: number,
	seed: number,
	teams: { Team },
	fixtures: { Fixture },
	rounds: number,
	playerIndex: number,
}

export type Row = Team & { index: number, position: number }

export type Outcome = "Promoted" | "Relegated" | "Stayed" | "Champions"

local function colorToJson(c: Color3): { number }
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

function League.divisionName(tier: number): string
	local d = Config.Divisions[tier]
	return if d then d.name else ("Division %d"):format(tier)
end

function League.topTier(): number
	return #Config.Divisions
end

-- Circle-method round robin for an even team count, then the reverse fixtures.
local function buildFixtures(n: number): { Fixture }
	local fixtures: { Fixture } = {}
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	local singleRounds = n - 1
	for round = 1, singleRounds do
		for i = 1, n / 2 do
			local a, b = order[i], order[n - i + 1]
			-- alternate venues so no team is at home every round
			if (round + i) % 2 == 0 then
				a, b = b, a
			end
			table.insert(fixtures, { round = round, home = a, away = b, played = false })
		end
		-- rotate everyone except the first
		local last = table.remove(order)
		table.insert(order, 2, last)
	end
	for _, f in table.clone(fixtures) do
		table.insert(fixtures, { round = f.round + singleRounds, home = f.away, away = f.home, played = false })
	end
	return fixtures
end

function League.newSeason(tier: number, seed: number, clubName: string, playerSeed: number): Season
	local rng = Random.new(seed)
	local division = Config.Divisions[tier]
	local n = Config.TeamsPerDivision

	local pool = table.clone(Config.Clubs[tier] or Config.Clubs[1])
	local teams: { Team } = {}
	local function newTeam(name: string, strength: number, kit: { number }, isPlayer: boolean, teamSeed: number): Team
		return {
			name = name,
			strength = strength,
			kit = kit,
			isPlayer = isPlayer,
			seed = teamSeed,
			played = 0,
			won = 0,
			drawn = 0,
			lost = 0,
			gf = 0,
			ga = 0,
			points = 0,
		}
	end
	table.insert(teams, newTeam(clubName, 0, colorToJson(Config.HomeKit), true, playerSeed))
	for i = 2, n do
		local pick = table.remove(pool, rng:NextInteger(1, #pool)) :: Config.Club
		local strength = division.baseStrength + rng:NextInteger(-4, 4)
		-- The club's own kit, not a per-slot colour: the shirt in the 3D match
		-- has to agree with the crest drawn beside its name in the table.
		table.insert(teams, newTeam(pick.name, strength, table.clone(pick.kit), false, seed * 10 + i))
	end
	-- shuffle so the player is not always team 1 in the schedule
	for i = #teams, 2, -1 do
		local j = rng:NextInteger(1, i)
		teams[i], teams[j] = teams[j], teams[i]
	end
	local playerIndex = 1
	for i, t in teams do
		if t.isPlayer then
			playerIndex = i
		end
	end

	return {
		tier = tier,
		seed = seed,
		teams = teams,
		fixtures = buildFixtures(n),
		rounds = (n - 1) * 2,
		playerIndex = playerIndex,
	}
end

-- Shape check for a season that came back from a save. Anything false here
-- means the caller should start a fresh season rather than trust it.
function League.isValid(season: any): boolean
	if type(season) ~= "table" then
		return false
	end
	if type(season.tier) ~= "number" or not Config.Divisions[season.tier] then
		return false
	end
	if type(season.teams) ~= "table" or #season.teams ~= Config.TeamsPerDivision then
		return false
	end
	if type(season.playerIndex) ~= "number" or not season.teams[season.playerIndex] then
		return false
	end
	if type(season.fixtures) ~= "table" or type(season.rounds) ~= "number" then
		return false
	end
	if #season.fixtures ~= season.rounds * Config.TeamsPerDivision / 2 then
		return false
	end
	for _, t in season.teams do
		if type(t.name) ~= "string" or type(t.strength) ~= "number" or type(t.points) ~= "number" or type(t.kit) ~= "table" then
			return false
		end
	end
	for _, f in season.fixtures do
		if type(f.round) ~= "number" or not season.teams[f.home] or not season.teams[f.away] or type(f.played) ~= "boolean" then
			return false
		end
	end
	return season.teams[season.playerIndex].isPlayer == true
end

-- The player's fixture in a round (opponent index and whether the schedule
-- says home). Presentation is always at the player's ground for now.
function League.playerFixture(season: Season, round: number): (Fixture?, number?)
	for _, f in season.fixtures do
		if f.round == round and (f.home == season.playerIndex or f.away == season.playerIndex) then
			local opp = if f.home == season.playerIndex then f.away else f.home
			return f, opp
		end
	end
	return nil, nil
end

local function applyResult(season: Season, f: Fixture, hg: number, ag: number)
	f.played, f.hg, f.ag = true, hg, ag
	local h, a = season.teams[f.home], season.teams[f.away]
	h.played += 1
	a.played += 1
	h.gf += hg
	h.ga += ag
	a.gf += ag
	a.ga += hg
	if hg > ag then
		h.won += 1
		a.lost += 1
		h.points += 3
	elseif hg == ag then
		h.drawn += 1
		a.drawn += 1
		h.points += 1
		a.points += 1
	else
		a.won += 1
		h.lost += 1
		a.points += 3
	end
end

-- Records the player's result (goals for / against from the player's point
-- of view) and simulates the other fixtures of the round.
function League.completeRound(season: Season, round: number, playerFor: number, playerAgainst: number, rng: Random)
	for _, f in season.fixtures do
		if f.round ~= round or f.played then
			continue
		end
		if f.home == season.playerIndex then
			applyResult(season, f, playerFor, playerAgainst)
		elseif f.away == season.playerIndex then
			applyResult(season, f, playerAgainst, playerFor)
		else
			local r = MatchSim.simulate({
				homeStrength = season.teams[f.home].strength,
				awayStrength = season.teams[f.away].strength,
				seed = rng:NextInteger(1, 2 ^ 30),
			})
			applyResult(season, f, r.homeGoals, r.awayGoals)
		end
	end
end

function League.standings(season: Season): { Row }
	local rows: { Row } = {}
	for i, t in season.teams do
		local row = table.clone(t) :: any
		row.index = i
		row.position = 0
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		if a.points ~= b.points then
			return a.points > b.points
		end
		local gdA, gdB = a.gf - a.ga, b.gf - b.ga
		if gdA ~= gdB then
			return gdA > gdB
		end
		if a.gf ~= b.gf then
			return a.gf > b.gf
		end
		return a.name < b.name
	end)
	for pos, row in rows do
		row.position = pos
	end
	return rows
end

function League.positionOf(season: Season, teamIndex: number): number
	for _, row in League.standings(season) do
		if row.index == teamIndex then
			return row.position
		end
	end
	return #season.teams
end

function League.isOver(season: Season): boolean
	for _, f in season.fixtures do
		if not f.played then
			return false
		end
	end
	return true
end

-- What the final position means for the player's club.
function League.outcome(season: Season): (Outcome, number)
	local pos = League.positionOf(season, season.playerIndex)
	local n = #season.teams
	if pos <= Config.PromotionSpots then
		if season.tier >= League.topTier() then
			return if pos == 1 then "Champions" else "Stayed", pos
		end
		return "Promoted", pos
	elseif pos > n - Config.RelegationSpots and season.tier > 1 then
		return "Relegated", pos
	end
	return "Stayed", pos
end

function League.prizeFor(tier: number, position: number): number
	local base = Config.PrizeByPosition[position] or Config.PrizeByPosition[#Config.PrizeByPosition]
	local division = Config.Divisions[tier]
	return math.floor(base * (if division then division.prizeMultiplier else 1))
end

-- Ordinal helper for UI text: 1st, 2nd, 3rd...
function League.ordinal(n: number): string
	local suffix = "th"
	local last = n % 10
	if n % 100 < 11 or n % 100 > 13 then
		if last == 1 then
			suffix = "st"
		elseif last == 2 then
			suffix = "nd"
		elseif last == 3 then
			suffix = "rd"
		end
	end
	return ("%d%s"):format(n, suffix)
end

return League
