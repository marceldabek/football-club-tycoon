--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local League = require(ReplicatedStorage.Shared.League)
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

local function season(tier: number, seed: number)
	return League.newSeason(tier, seed, "Test FC", 1)
end

function T.fixturesAreDoubleRoundRobin()
	local s = season(1, 1)
	local n = Config.TeamsPerDivision
	assert(#s.teams == n, "wrong team count")
	assert(s.rounds == (n - 1) * 2, "wrong round count")
	assert(#s.fixtures == s.rounds * n / 2, "wrong fixture count")
	local perTeam = {}
	local pair = {}
	local perRound = {}
	for _, f in s.fixtures do
		perTeam[f.home] = (perTeam[f.home] or 0) + 1
		perTeam[f.away] = (perTeam[f.away] or 0) + 1
		perRound[f.round] = (perRound[f.round] or 0) + 1
		local key = f.home .. "v" .. f.away
		assert(not pair[key], "duplicate fixture " .. key)
		pair[key] = true
		assert(f.home ~= f.away, "team plays itself")
	end
	for i = 1, n do
		assert(perTeam[i] == s.rounds, ("team %d plays %d"):format(i, perTeam[i]))
	end
	for r = 1, s.rounds do
		assert(perRound[r] == n / 2, ("round %d has %d fixtures"):format(r, perRound[r]))
		local seen = {}
		for _, f in s.fixtures do
			if f.round == r then
				assert(not seen[f.home] and not seen[f.away], "team plays twice in round " .. r)
				seen[f.home], seen[f.away] = true, true
			end
		end
	end
	-- each pair meets twice with venues swapped
	for _, f in s.fixtures do
		assert(pair[f.away .. "v" .. f.home], "missing return fixture")
	end
end

-- SL15: only home games pay a gate, so the opener is always at home, and the
-- swap that arranges it must leave the player five home games, not ten
function T.playerAlwaysOpensAtHome()
	for seed = 1, 40 do
		local s = season(1 + seed % 3, seed)
		local homeGames = 0
		for _, f in s.fixtures do
			if f.round == 1 and (f.home == s.playerIndex or f.away == s.playerIndex) then
				assert(f.home == s.playerIndex, ("seed %d opens away"):format(seed))
			end
			if f.home == s.playerIndex then
				homeGames += 1
			end
		end
		assert(homeGames == s.rounds / 2, ("seed %d has %d home games"):format(seed, homeGames))
	end
end

function T.playerHasOneFixtureEveryRound()
	local s = season(2, 5)
	local opponents = {}
	for r = 1, s.rounds do
		local f, opp = League.playerFixture(s, r)
		assert(f and opp, "no player fixture in round " .. r)
		opponents[opp :: number] = (opponents[opp :: number] or 0) + 1
	end
	for i, t in s.teams do
		if not t.isPlayer then
			assert(opponents[i] == 2, t.name .. " met " .. tostring(opponents[i]) .. " times")
		end
	end
	assert(s.teams[s.playerIndex].isPlayer and s.teams[s.playerIndex].name == "Test FC", "player index wrong")
end

function T.opponentsFollowDivisionStrengthAndNames()
	for tier, division in Config.Divisions do
		local s = season(tier, tier * 7)
		local names = {}
		for _, t in s.teams do
			if not t.isPlayer then
				assert(math.abs(t.strength - division.baseStrength) <= 4, "strength off base in tier " .. tier)
				local inPool = false
				for _, club in Config.Clubs[tier] do
					if club.name == t.name then
						inPool = true
						break
					end
				end
				assert(inPool, t.name .. " not in tier " .. tier .. " pool")
				assert(not names[t.name], "duplicate opponent " .. t.name)
				names[t.name] = true
			end
		end
	end
end

function T.completeRoundRecordsEverythingAndOrdersTable()
	local s = season(1, 3)
	local rng = Random.new(9)
	for r = 1, s.rounds do
		assert(not League.isOver(s), "season over early")
		League.completeRound(s, r, 3, 0, rng) -- player wins every match 3-0
	end
	assert(League.isOver(s), "season should be over")
	local me = s.teams[s.playerIndex]
	assert(me.played == 10 and me.won == 10 and me.points == 30 and me.gf == 30 and me.ga == 0, "player record wrong")
	local totalPlayed = 0
	for _, t in s.teams do
		totalPlayed += t.played
		assert(t.played == 10, t.name .. " played " .. t.played)
	end
	local rows = League.standings(s)
	assert(rows[1].index == s.playerIndex and rows[1].position == 1, "player should top the table")
	for i = 2, #rows do
		local a, b = rows[i - 1], rows[i]
		local ok = a.points > b.points or (a.points == b.points and (a.gf - a.ga) >= (b.gf - b.ga))
		assert(ok, "table not sorted at row " .. i)
	end
	local outcome, pos = League.outcome(s)
	assert(outcome == "Promoted" and pos == 1, "winning tier 1 should promote")
end

function T.outcomeRespectsPyramidEnds()
	local top = season(League.topTier(), 2)
	for r = 1, top.rounds do
		League.completeRound(top, r, 5, 0, Random.new(r))
	end
	local outcome = League.outcome(top)
	assert(outcome == "Champions", "winning the top tier should be Champions, got " .. outcome)

	local bottom = season(1, 4)
	for r = 1, bottom.rounds do
		League.completeRound(bottom, r, 0, 5, Random.new(r))
	end
	local o2, pos = League.outcome(bottom)
	assert(o2 == "Stayed" and pos == Config.TeamsPerDivision, "bottom of tier 1 cannot be relegated")

	local mid = season(2, 4)
	for r = 1, mid.rounds do
		League.completeRound(mid, r, 0, 5, Random.new(r))
	end
	assert(League.outcome(mid) == "Relegated", "bottom of tier 2 should be relegated")
end

function T.prizeScalesWithTierAndPosition()
	assert(League.prizeFor(1, 1) > League.prizeFor(1, 2), "first should pay more than second")
	assert(League.prizeFor(2, 1) > League.prizeFor(1, 1), "higher tier should pay more")
	assert(League.prizeFor(1, 99) > 0, "unknown position still pays something")
	-- X272: a title should be worth about the same share of a division's own
	-- money wherever you are in the pyramid
	local bottomShare = League.prizeFor(1, 1) / Config.Divisions[1].demandBase
	for tier = 2, #Config.Divisions do
		local share = League.prizeFor(tier, 1) / Config.Divisions[tier].demandBase
		assert(math.abs(share - bottomShare) < bottomShare * 0.05,
			("a title in tier %d is worth %.2f per demand, against %.2f at the bottom"):format(tier, share, bottomShare))
	end
	assert(League.prizeFor(#Config.Divisions, 1) >= 100000, "a top-flight title should be worth six figures, got " .. League.prizeFor(#Config.Divisions, 1))
	assert(League.prizeFor(1, 1) % 50 == 0, "prizes are rounded to 50")
end

function T.isValidAcceptsSeasonsAndRejectsGarbage()
	local s = season(1, 9)
	assert(League.isValid(s), "fresh season should be valid")
	local HttpService = game:GetService("HttpService")
	assert(League.isValid(HttpService:JSONDecode(HttpService:JSONEncode(s))), "JSON round trip should stay valid")
	assert(not League.isValid(nil), "nil")
	assert(not League.isValid({}), "empty table")
	local broken = season(1, 9)
	broken.teams[6] = nil
	assert(not League.isValid(broken), "missing team")
	local wrongPlayer = season(1, 9)
	wrongPlayer.playerIndex = 99
	assert(not League.isValid(wrongPlayer), "player index out of range")
end

-- Crests are drawn from these colours, so a division must not field two clubs
-- the eye cannot separate, and a club has to look the same in every season.
function T.everyClubHasItsOwnColours()
	for tier in Config.Divisions do
		local seen = {}
		for _, club in Config.Clubs[tier] do
			assert(#club.kit == 3 and #club.accent == 3, club.name .. " has a malformed colour")
			for _, channel in club.kit do
				assert(channel >= 0 and channel <= 255, club.name .. " kit channel out of range")
			end
			for _, channel in club.accent do
				assert(channel >= 0 and channel <= 255, club.name .. " accent channel out of range")
			end
			local key = table.concat(club.kit, ",")
			assert(not seen[key], "two clubs share a kit in tier " .. tier .. ": " .. club.name)
			seen[key] = true
		end
	end
end

function T.opponentKitsComeFromTheClubNotTheSlot()
	-- The same club drawn into two different seasons must wear the same kit.
	local kits: { [string]: string } = {}
	for seed = 1, 12 do
		for tier in Config.Divisions do
			for _, t in season(tier, seed * 31 + tier).teams do
				if not t.isPlayer then
					local key = table.concat(t.kit, ",")
					if kits[t.name] then
						assert(kits[t.name] == key, t.name .. " changed kit between seasons")
					else
						kits[t.name] = key
					end
				end
			end
		end
	end
end

function T.clubCrestLookupCoversEveryClub()
	for tier in Config.Divisions do
		for _, club in Config.Clubs[tier] do
			local kit, accent = Config.clubCrest(club.name)
			assert(typeof(kit) == "Color3" and typeof(accent) == "Color3", club.name .. " has no crest colours")
			assert(kit ~= accent, club.name .. " crest is invisible against itself")
		end
	end
	-- The player's club is named at runtime and is never in the table.
	local playerKit = Config.clubCrest("Anything At All", true)
	assert(playerKit == Config.HomeKit, "player club should wear the home kit")
	-- An unknown club still gets a stable colour rather than erroring.
	local a = Config.clubCrest("Nonexistent Wanderers")
	local b = Config.clubCrest("Nonexistent Wanderers")
	assert(a == b, "unknown club colour is not stable")
end

function T.ordinals()
	assert(League.ordinal(1) == "1st" and League.ordinal(2) == "2nd" and League.ordinal(3) == "3rd", "bad ordinals")
	assert(League.ordinal(4) == "4th" and League.ordinal(11) == "11th" and League.ordinal(22) == "22nd", "bad ordinals")
end

function T.roundResultsReadsBackEveryScore()
	local season = League.newSeason(1, 7, "Test FC", 3)
	League.completeRound(season, 1, 3, 1, Random.new(9))
	local results = League.roundResults(season, 1)
	local teams = #season.teams
	assert(#results == math.floor(teams / 2), "every fixture in the round should have a score")
	local players, total = 0, 0
	for _, r in results do
		assert(r.home ~= "" and r.away ~= "" and r.home ~= r.away, "both clubs should be named")
		assert(r.hg >= 0 and r.ag >= 0, "scores should be real")
		players += if r.player then 1 else 0
		total += r.hg + r.ag
	end
	assert(players == 1, "exactly one fixture is the player's")
	assert(total > 0, "a whole round of 0-0s is not a real result set")
	for _, r in results do
		if r.player then
			assert((r.hg == 3 and r.ag == 1) or (r.hg == 1 and r.ag == 3), "the player's own score should be the one recorded")
		end
	end
	assert(#League.roundResults(season, 2) == 0, "an unplayed round has no results")
end

-- X355 ----------------------------------------------------------------------

function T.aDivisionAimsAtTheClubItIsGoingToFace()
	local base = Config.Divisions[1].baseStrength
	-- a club below the standard never makes the division softer
	assert(League.rivalTarget(1, 0) == base, "no squad yet: the division is itself")
	assert(League.rivalTarget(1, base - 20) == base, "a poor club does not drag the division down")
	-- a strong club pulls it up, to a point
	local strong = League.rivalTarget(1, base + 8)
	assert(strong > base, ("a strong club should be met by better rivals, got %d against %d"):format(strong, base))
	assert(League.rivalTarget(1, base + 100) == base + League.RIVAL_MAX_OVER, "and it stops climbing")
	-- promotion is still the step up: the next division starts above anything
	-- this one can drift to
	-- promotion has to be a real step up: what a division can drift to must
	-- stay *under* what the next one starts at. The first version of this
	-- assertion allowed 2 points of slack, which was exactly the size of the
	-- violation it was meant to catch.
	for tier = 1, #Config.Divisions - 1 do
		local ceiling = Config.Divisions[tier].baseStrength + League.RIVAL_MAX_OVER
		assert(Config.Divisions[tier + 1].baseStrength > ceiling,
			("tier %d can drift to %d, but tier %d only starts at %d"):format(
				tier, ceiling, tier + 1, Config.Divisions[tier + 1].baseStrength))
	end
	-- and going up always changes who you play
	for tier = 1, #Config.Divisions - 1 do
		for strength = 40, 99, 3 do
			assert(League.rivalTarget(tier + 1, strength) > League.rivalTarget(tier, strength),
				("an XI of %d meets the same rivals in tier %d and tier %d"):format(strength, tier, tier + 1))
		end
	end
end

function T.tenSeasonsInOneDivisionGetHarder()
	-- the club improves every season; the division should notice
	local base = Config.Divisions[1].baseStrength
	local first, last = nil, nil
	for season = 1, 10 do
		local playerStrength = base - 4 + season * 2
		local s = League.newSeason(1, 100 + season, "Test FC", 1, playerStrength)
		local total, count = 0, 0
		for _, team in s.teams do
			if not team.isPlayer then
				total += team.strength
				count += 1
			end
		end
		local average = total / count
		if season == 1 then
			first = average
		end
		last = average
	end
	assert(last > first + 4, ("rivals should have moved: %.1f then %.1f"):format(first, last))
	assert(last <= base + League.RIVAL_MAX_OVER + 4, ("and not run away: %.1f"):format(last))
end

-- X362 ----------------------------------------------------------------------

-- Four clubs where two of them finish level on points, goal difference and
-- goals scored, and one of those two won the head-to-head.
local function levelSeason(firstName: string, secondName: string, seed: number)
	local function team(name: string, seedValue: number, points: number, gf: number, ga: number)
		return {
			name = name,
			strength = 50,
			kit = { 40, 40, 40 },
			isPlayer = false,
			seed = seedValue,
			played = 4,
			won = 0,
			drawn = 0,
			lost = 0,
			gf = gf,
			ga = ga,
			points = points,
		}
	end
	return {
		tier = 1,
		seed = seed,
		teams = {
			team(firstName, 11, 7, 6, 4), -- 1
			team(secondName, 22, 7, 6, 4), -- 2, level on all three
			team("Cawthorne Vale", 33, 0, 1, 6), -- 3
			team("Dunmore Athletic", 44, 3, 3, 2), -- 4
		},
		fixtures = {
			{ round = 1, home = 1, away = 2, played = true, hg = 2, ag = 0 },
			{ round = 2, home = 2, away = 1, played = true, hg = 1, ag = 1 },
			{ round = 3, home = 1, away = 3, played = true, hg = 3, ag = 1 },
			{ round = 4, home = 4, away = 1, played = true, hg = 2, ag = 0 },
			{ round = 5, home = 2, away = 3, played = true, hg = 3, ag = 0 },
			{ round = 6, home = 2, away = 4, played = true, hg = 2, ag = 1 },
		},
		rounds = 6,
		playerIndex = 1,
	}
end

function T.aDeadLevelFinishIsSettledOnThePitchNotTheAlphabet()
	-- The old comparator ended `return a.name < b.name`, and League.outcome
	-- reads positionOf straight off it, so with two promotion spots a club
	-- level on points, goal difference and goals scored was promoted on its
	-- name. Club 1 took 4 points off club 2 and club 2 took 1 off club 1.
	for _, names in { { "Zenith Town", "Ashford Rangers" }, { "Ashford Rangers", "Zenith Town" } } do
		local s = levelSeason(names[1], names[2], 4242) :: any
		local rows = League.standings(s)
		assert(rows[1].points == rows[2].points, "the top two should be level on points")
		assert(rows[1].index == 1 and rows[2].index == 2,
			("the head-to-head winner should be first, got %s then %s"):format(rows[1].name, rows[2].name))
		assert(League.positionOf(s, 1) == 1 and League.positionOf(s, 2) == 2, "positionOf should agree")
	end
end

function T.aTieNobodyWonIsDrawnBySeedAndStaysDrawnThatWay()
	-- Level on everything and level head-to-head: the order has to come from
	-- somewhere, and it must be the same every time the table is drawn.
	local function allLevel(seed: number)
		local s = levelSeason("Zenith Town", "Ashford Rangers", seed) :: any
		-- make the two meetings a mirror, so the mini-table cannot separate them
		s.fixtures[1].hg, s.fixtures[1].ag = 2, 1
		s.fixtures[2].hg, s.fixtures[2].ag = 2, 1
		return s
	end
	local s = allLevel(4242)
	local mini = League.miniTable(s, { 1, 2 })
	assert(mini[1].points == mini[2].points and mini[1].diff == mini[2].diff, "setup: the head-to-head is level")
	local firstDraw = League.standings(s)[1].index
	for _ = 1, 5 do
		assert(League.standings(s)[1].index == firstDraw, "the same table must not reorder itself")
	end
	-- and the draw is a draw: over a run of seeds it cannot always be the
	-- alphabet, which is what it was before
	local alphabetical, other = 0, 0
	for seed = 1, 40 do
		local rows = League.standings(allLevel(seed))
		if rows[1].name < rows[2].name then
			alphabetical += 1
		else
			other += 1
		end
	end
	assert(alphabetical > 0 and other > 0,
		("the draw should not be one-sided: %d alphabetical, %d not"):format(alphabetical, other))
end

function T.threeClubsInARockPaperScissorsTieStillGetATable()
	-- head-to-head is not transitive, and a table.sort comparator that says so
	-- can throw "invalid order function for sorting" - which would take the
	-- league tab down at the end of a season rather than mis-order it
	local s = levelSeason("Zenith Town", "Ashford Rangers", 7) :: any
	for _, t in s.teams do
		t.points, t.gf, t.ga = 6, 4, 4
	end
	s.fixtures = {
		{ round = 1, home = 1, away = 2, played = true, hg = 1, ag = 0 },
		{ round = 2, home = 2, away = 3, played = true, hg = 1, ag = 0 },
		{ round = 3, home = 3, away = 1, played = true, hg = 1, ag = 0 },
		{ round = 4, home = 4, away = 1, played = true, hg = 1, ag = 1 },
	}
	local rows = League.standings(s)
	assert(#rows == 4, "every club should still be in the table")
	local seen: { [number]: boolean } = {}
	for pos, row in rows do
		assert(row.position == pos, "positions should be 1..n in order")
		assert(not seen[row.index], "no club should appear twice")
		seen[row.index] = true
	end
end

return T
