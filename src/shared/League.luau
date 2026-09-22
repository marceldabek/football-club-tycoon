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

-- X355: the other five clubs were built from `division.baseStrength` every
-- season and nothing ever moved them, so a club that stayed in one division
-- met 44/52/60/68/76-rated opposition for ever while its own players improved
-- every match (Squad.afterMatch) - the tenth Sunday Parks League season was
-- exactly as easy as the first, against Milestone 4's "difficulty scaling".
-- Rivals now aim just below the club they keep meeting, but never far above
-- the division's own standard, so promotion is still the real step up. TEMP.
League.RIVAL_GAP = 4 -- how far below the player's XI the division aims
-- ...and never more than this above its own standard. It has to stay *below*
-- the 8-point step between divisions, or a division can drift level with the
-- one above and promotion changes the opposition by nothing (review at 00:29:
-- at 10, any XI around 56-62 met identical rivals in tiers 1 and 2).
League.RIVAL_MAX_OVER = 6

-- Pure: what this division's rivals are built around, given the club they are
-- up against. A weak club never makes the division weaker than it is.
function League.rivalTarget(tier: number, playerStrength: number?): number
	local division = Config.Divisions[tier] or Config.Divisions[1]
	local base = division.baseStrength
	if not playerStrength or playerStrength <= 0 then
		return base
	end
	return math.clamp(playerStrength - League.RIVAL_GAP, base, base + League.RIVAL_MAX_OVER)
end

function League.newSeason(tier: number, seed: number, clubName: string, playerSeed: number, playerStrength: number?): Season
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
		local strength = League.rivalTarget(tier, playerStrength) + rng:NextInteger(-4, 4)
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

	-- SL15 (docs/SOFT_LAUNCH.md): only home games pay a gate (X361), so an away
	-- opener left about half of all new clubs with next to nothing at the first
	-- payout. If the player would open away, every fixture swaps ends: still one
	-- home and one away game against everybody, and the season starts at home.
	local fixtures = buildFixtures(n)
	for _, f in fixtures do
		if f.round == 1 and f.away == playerIndex then
			for _, g in fixtures do
				g.home, g.away = g.away, g.home
			end
			break
		end
	end

	return {
		tier = tier,
		seed = seed,
		teams = teams,
		fixtures = fixtures,
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

export type RoundResult = { home: string, away: string, hg: number, ag: number, player: boolean }

-- X294: the other five clubs play every round and the player never saw a score,
-- only the table moving. `completeRound` already stores hg/ag on the fixture, so
-- this is just reading them back for the summary card and the league tab.
function League.roundResults(season: Season, round: number): { RoundResult }
	local out: { RoundResult } = {}
	for _, f in season.fixtures do
		if f.round == round and f.played and f.hg and f.ag then
			table.insert(out, {
				home = season.teams[f.home].name,
				away = season.teams[f.away].name,
				hg = f.hg :: number,
				ag = f.ag :: number,
				player = f.home == season.playerIndex or f.away == season.playerIndex,
			})
		end
	end
	return out
end

-- X362: the mini-table of the matches a set of clubs played against each other,
-- which is how a dead-level group is separated. Only played fixtures count, so a
-- half-finished table can use it too.
--
-- It returns a *score per club* rather than comparing two of them, because
-- head-to-head is not transitive - A beats B, B beats C, C beats A is possible
-- between three clubs level on everything else, and a `table.sort` comparator
-- that says so can throw "invalid order function".
export type MiniRow = { points: number, diff: number }

function League.miniTable(season: Season, indices: { number }): { [number]: MiniRow }
	local inGroup: { [number]: boolean } = {}
	local mini: { [number]: MiniRow } = {}
	for _, index in indices do
		inGroup[index] = true
		mini[index] = { points = 0, diff = 0 }
	end
	for _, f in season.fixtures do
		if f.played and f.hg and f.ag and inGroup[f.home] and inGroup[f.away] then
			local hg, ag = f.hg :: number, f.ag :: number
			local home, away = mini[f.home], mini[f.away]
			home.diff += hg - ag
			away.diff += ag - hg
			if hg > ag then
				home.points += 3
			elseif hg == ag then
				home.points += 1
				away.points += 1
			else
				away.points += 3
			end
		end
	end
	return mini
end

-- X362: and if even that is level, a draw - the same one every time the table
-- is drawn, but nothing the player can read off the club names. Mixed from the
-- season seed and the club's own seed, so two dead-level clubs do not keep the
-- same order next season.
local function drawTicket(season: Season, teamSeed: number?): number
	-- `Random.new` rather than hand-rolled arithmetic: it is the same seeded
	-- generator the fixture list and the squads already trust to be repeatable,
	-- and it mixes properly - an xorshift of (season seed XOR club seed) let the
	-- club seed win every tie for forty seasons running, because a season seed
	-- of 7 only moves the bottom three bits.
	--
	-- Floored and defaulted: every season `League.newSeason` builds gives each
	-- club a seed, but a save without one must not take the league table down.
	local a = math.floor(math.abs(season.seed or 0)) % 1000003
	local b = math.floor(math.abs(teamSeed or 0)) % 1000003
	return Random.new(a * 1000003 + b):NextNumber()
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
		-- X362: this used to be `a.name < b.name`, and `League.outcome` reads
		-- `positionOf` straight off this sort - so a club level on points, goal
		-- difference and goals scored was promoted or relegated on the alphabet,
		-- for ever, in a game whose whole point is the promotion. The draw is
		-- only the last resort; clubs level this far are separated by the
		-- mini-table below first.
		return drawTicket(season, a.seed) > drawTicket(season, b.seed)
	end)
	-- X362: now separate each run of clubs that is still level on points, goal
	-- difference and goals scored by what they did to each other.
	local function level(a: Row, b: Row): boolean
		return a.points == b.points and (a.gf - a.ga) == (b.gf - b.ga) and a.gf == b.gf
	end
	local first = 1
	while first <= #rows do
		local last = first
		while last < #rows and level(rows[last + 1], rows[first]) do
			last += 1
		end
		if last > first then
			local group: { number } = {}
			for i = first, last do
				table.insert(group, rows[i].index)
			end
			local mini = League.miniTable(season, group)
			local tied = table.move(rows, first, last, 1, {})
			table.sort(tied, function(a, b)
				local ma, mb = mini[a.index], mini[b.index]
				if ma.points ~= mb.points then
					return ma.points > mb.points
				end
				if ma.diff ~= mb.diff then
					return ma.diff > mb.diff
				end
				return drawTicket(season, a.seed) > drawTicket(season, b.seed)
			end)
			table.move(tied, 1, #tied, first, rows)
		end
		first = last + 1
	end
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

-- X272: the prize is a share of the division's own money rather than a
-- hand-set multiplier, so a title is worth about the same fraction of a
-- season's takings in the Sunday Parks League as in the Premier Division.
function League.divisionFactor(tier: number): number
	local division = Config.Divisions[tier]
	local bottom = Config.Divisions[1]
	if not division or not bottom or bottom.demandBase <= 0 then
		return 1
	end
	return division.demandBase / bottom.demandBase
end

function League.prizeFor(tier: number, position: number): number
	local base = Config.PrizeByPosition[position] or Config.PrizeByPosition[#Config.PrizeByPosition]
	-- rounded to £50, like every other money figure the player is quoted
	return math.floor(base * League.divisionFactor(tier) / 50) * 50
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
