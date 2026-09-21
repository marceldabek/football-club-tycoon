--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Squad = require(ReplicatedStorage.Shared.Squad)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Config = require(ReplicatedStorage.Shared.Config)
local Nations = require(ReplicatedStorage.Shared.Nations)

local T = {}

local function counts(players)
	local c = { GK = 0, DEF = 0, MID = 0, FWD = 0 }
	for _, p in players do
		c[p.role] += 1
	end
	return c
end

function T.generateShape()
	local players = Squad.generate(1, 45)
	assert(#players == 16, "expected 16 players")
	local c = counts(players)
	assert(c.GK == 2 and c.DEF == 5 and c.MID == 5 and c.FWD == 4, "unexpected role mix")
	for i, p in players do
		assert(p.id == i and p.number == i, "ids / numbers should be 1..16")
		assert(p.overall >= 30 and p.overall <= 99, "overall out of range")
		assert(p.potential >= p.overall, "potential below overall")
		assert(p.age >= 17 and p.age <= 33, "age out of range")
		assert(p.injured == 0 and p.apps == 0 and p.goals == 0, "fresh player has history")
	end
	local avg = Squad.average(players)
	assert(avg > 40 and avg < 50, "average " .. avg .. " far from 45")
end

function T.playersCarryLookSeed()
	local a = Squad.generate(7, 45)
	local b = Squad.generate(7, 45)
	for i, p in a do
		assert(type(p.look) == "number" and p.look >= 1, "look seed missing")
		assert(p.look == b[i].look, "look seed not deterministic")
	end
	assert(a[1].look ~= a[2].look, "players share a look seed")
	local ms = Squad.matchSquad(a, Squad.autoLineup(a))
	assert(ms[1].look == Squad.byId(a)[ms[1].id].look, "matchSquad drops look")
	assert(Squad.lookSeedFor(3, "Bob") == Squad.lookSeedFor(3, "Bob"), "hash unstable")
	assert(Squad.lookSeedFor(3, "Bob") ~= Squad.lookSeedFor(4, "Bob"), "hash ignores id")
	local prospects = Squad.prospects(4, 45, 1)
	assert(#prospects == 0 or type(prospects[1].look) == "number", "prospect look missing")
end

function T.autoLineupPicksBestFitPerRole()
	local players = Squad.generate(2, 45)
	local lineup = Squad.autoLineup(players)
	assert(#lineup.xi == 11, "xi should have 11")
	local map = Squad.byId(players)
	local inXi = {}
	for slot, id in lineup.xi do
		assert(not inXi[id], "player used twice")
		inXi[id] = true
		assert(map[id].role == Pitch.ROLES[slot], ("slot %d filled out of role"):format(slot))
	end
	-- the best DEF must be starting
	local bestDef
	for _, p in players do
		if p.role == "DEF" and (not bestDef or p.overall > bestDef.overall) then
			bestDef = p
		end
	end
	assert(inXi[bestDef.id], "best defender not in the XI")
	assert(#lineup.bench == Config.BenchSize, "bench should be full with 16 players")
	for _, id in lineup.bench do
		assert(not inXi[id], "bench player also starting")
	end
end

function T.autoLineupSkipsInjuredAndFillsOutOfRole()
	local players = Squad.generate(3, 45)
	for _, p in players do
		if p.role == "FWD" then
			p.injured = 2
		end
	end
	local lineup = Squad.autoLineup(players)
	local map = Squad.byId(players)
	for _, id in lineup.xi do
		assert(map[id].injured == 0, "injured player selected")
	end
	assert(map[lineup.xi[10]].role ~= "GK" and map[lineup.xi[11]].role ~= "GK", "keeper used up front")
	local full = Squad.strength(players, Squad.autoLineup(Squad.generate(3, 45)).xi)
	local weakened = Squad.strength(players, lineup.xi)
	assert(weakened < full, "out-of-role lineup should be weaker")
end

function T.strengthIsMeanOverallWhenInRole()
	local players = Squad.generate(4, 50)
	local lineup = Squad.autoLineup(players)
	local map = Squad.byId(players)
	local sum = 0
	for _, id in lineup.xi do
		sum += map[id].overall
	end
	assert(math.abs(Squad.strength(players, lineup.xi) - sum / 11) < 1e-6, "strength should be the mean of the XI")
end

function T.matchSquadOrderAndNextSub()
	local players = Squad.generate(5, 45)
	local lineup = Squad.autoLineup(players)
	local ms = Squad.matchSquad(players, lineup)
	assert(#ms == 16, "match squad should be xi + bench")
	for slot = 1, 11 do
		assert(ms[slot].role == Pitch.ROLES[slot], "match squad out of formation order")
	end
	local made = {}
	for i = 1, Config.MaxSubs do
		local sub = Squad.nextSub(ms, made)
		assert(sub, "sub " .. i .. " was nil")
		assert(sub.out >= 2 and sub.out <= 11, "keeper or non-starter subbed off")
		assert(sub["in"] > 11, "sub must come from the bench")
		assert(ms[sub["in"]].role ~= "GK", "outfield sub brought on a keeper")
		table.insert(made, sub)
	end
	assert(Squad.nextSub(ms, made) == nil, "fourth sub should be refused")
	-- the first sub takes off the weakest outfield starter
	local weakest = 2
	for idx = 3, 11 do
		if ms[idx].overall < ms[weakest].overall then
			weakest = idx
		end
	end
	assert(made[1].out == weakest, "first sub should remove the weakest outfield starter")
end

function T.assignScorersOnlyHomeGoals()
	local players = Squad.generate(6, 45)
	local ms = Squad.matchSquad(players, Squad.autoLineup(players))
	local events = {
		{ minute = 10, team = "Home", type = "GOAL" },
		{ minute = 20, team = "Away", type = "GOAL" },
		{ minute = 30, team = "Home", type = "MISS" },
		{ minute = 40, team = "Home", type = "GOAL" },
	}
	local scorers = Squad.assignScorers(events, ms, Random.new(1))
	assert(#scorers == 2, "expected two scorers")
	assert(events[1].scorer and events[4].scorer, "home goals need scorers")
	assert(events[2].scorer == nil and events[3].scorer == nil, "only home goals get scorers")
	for _, slot in scorers do
		assert(slot >= 2 and slot <= 11, "keeper scored")
	end
end

function T.afterMatchDevelopsWithinPotentialAndTicksInjuries()
	local players = Squad.generate(7, 45)
	local lineup = Squad.autoLineup(players)
	local benchId = lineup.bench[1]
	local map = Squad.byId(players)
	map[benchId].injured = 2
	for round = 1, 30 do
		Squad.afterMatch(players, lineup.xi, {}, 3, Random.new(round))
	end
	for _, p in players do
		assert(p.overall <= p.potential, p.name .. " exceeded potential")
		assert(p.injured >= 0, "negative injury")
	end
	assert(map[benchId].injured == 0, "injury should have ticked down while not playing")
	assert(map[lineup.xi[1]].apps == 30, "starter apps not counted")
end

function T.afterMatchCountsGoals()
	local players = Squad.generate(8, 45)
	local lineup = Squad.autoLineup(players)
	local striker = lineup.xi[10]
	Squad.afterMatch(players, lineup.xi, { striker, striker }, 0, Random.new(1))
	assert(Squad.byId(players)[striker].goals == 2, "goals not recorded")
end

function T.everyPackIsThreeCards()
	for level = 0, #Config.ScoutLevels do
		local list = Squad.prospects(level * 10 + 1, 45, level)
		assert(#list == Config.PackSize, ("level %d gave %d cards"):format(level, #list))
		for _, p in list do
			assert(p.fee >= 100, "fee too small")
			assert(p.id < 0, "prospect ids must be negative")
		end
	end
end

function T.walkInPackIsMostlyBronze()
	local bronze, total = 0, 0
	for seed = 1, 300 do
		for _, p in Squad.prospects(seed, 45, 0) do
			total += 1
			if Squad.rarity(p.overall) == "Bronze" then
				bronze += 1
			end
		end
	end
	assert(bronze / total >= 0.9, ("only %d%% bronze"):format(bronze / total * 100))
end

function T.walkInsAreWorseThanAScouts()
	local walk, local_ = 0, 0
	for seed = 1, 200 do
		for _, p in Squad.prospects(seed, 50, 0) do
			walk += p.overall
		end
		for _, p in Squad.prospects(seed, 50, 1) do
			local_ += p.overall
		end
	end
	assert(walk < local_, "hiring a scout should improve the pack")
end

function T.trialistPackBeatsTheWeakestStarter()
	for seed = 1, 100 do
		local players = Squad.generate(seed, 45)
		local lineup = Squad.autoLineup(players)
		local byId = Squad.byId(players)
		local weakest = byId[lineup.xi[1]]
		for _, id in lineup.xi do
			if byId[id].overall < weakest.overall then
				weakest = byId[id]
			end
		end
		local pack = Squad.trialistPack(seed, players, lineup.xi)
		assert(#pack == Config.PackSize, "trialist pack is three cards")
		local found = false
		for _, p in pack do
			if p.role == weakest.role and p.overall >= weakest.overall + Config.TrialistBonus[1] then
				found = true
			end
			assert(p.potential >= p.overall, "potential below overall")
		end
		assert(found, "nobody in the pack improves the weakest position")
	end
end

-- An elite signing has to be a real decision, not pocket change. The old
-- linear fee made a 76 overall cost 3,000 and an 85 cost 3,250, so a club
-- sitting on 75k could buy every prospect on the list without thinking.
function T.eliteSigningsCostRealMoney()
	local function p(overall: number, potential: number)
		return { id = 1, name = "a", number = 1, role = "MID", age = 22, overall = overall, potential = potential, injured = 0, apps = 0, goals = 0, look = 1 } :: any
	end
	local decent, elite = Squad.fee(p(65, 75)), Squad.fee(p(85, 92))
	assert(elite >= decent * 3, ("an elite player should cost far more: %d vs %d"):format(elite, decent))
	assert(elite >= 15000, ("an 85 overall should be a major outlay, got %d"):format(elite))
	-- and the bottom of the market stays affordable for a grassroots club
	assert(Squad.fee(p(45, 55)) <= 1500, "a fourth-tier squad player should stay cheap")
end

-- Late-game scouts are the way a rich club converts cash into squad strength.
function T.topScoutsFindBetterPlayersThanEarlyOnes()
	local first = Config.ScoutLevels[1]
	local last = Config.ScoutLevels[#Config.ScoutLevels]
	assert(#Config.ScoutLevels >= 5, "there should be a scouting ladder worth climbing")
	assert(last.overallBonus > first.overallBonus * 2, "the best scout should find far better players")
	for level = 2, #Config.ScoutLevels do
		local prev, cur = Config.ScoutLevels[level - 1], Config.ScoutLevels[level]
		assert(cur.cost > prev.cost, ("scout level %d should cost more than %d"):format(level, level - 1))
		assert(cur.overallBonus > prev.overallBonus, ("scout level %d should find better players"):format(level))
	end
end

function T.feeGrowsWithQuality()
	local low = { id = 1, name = "a", number = 1, role = "MID", age = 25, overall = 40, potential = 42, injured = 0, apps = 0, goals = 0 }
	local high = { id = 2, name = "b", number = 2, role = "MID", age = 20, overall = 55, potential = 70, injured = 0, apps = 0, goals = 0 }
	assert(Squad.fee(high :: any) > Squad.fee(low :: any), "better player should cost more")
end

function T.valueNeverExceedsFeeAndFallsWithAge()
	local young = { id = 1, name = "a", number = 1, role = "MID", age = 21, overall = 55, potential = 65, injured = 0, apps = 0, goals = 0, look = 1 }
	local old = { id = 2, name = "b", number = 2, role = "MID", age = 33, overall = 55, potential = 65, injured = 0, apps = 0, goals = 0, look = 2 }
	assert(Squad.value(young :: any) <= Squad.fee(young :: any), "sale value above buying fee")
	-- X351: and never the whole fee back, however young he is
	assert(Squad.value(young :: any) < Squad.fee(young :: any), "a signing should not be a free undo")
	assert(Squad.value(young :: any) > Squad.value(old :: any), "veteran should be worth less")
	assert(Squad.value(old :: any) >= 100 and Squad.value(old :: any) % 50 == 0, "value not rounded to 50 / below floor")
end

function T.afterMatchReportsRatingChanges()
	local players = Squad.generate(9, 45)
	local lineup = Squad.autoLineup(players)
	local seen = 0
	for round = 1, 20 do
		local news, changes = Squad.afterMatch(players, lineup.xi, {}, 3, Random.new(round))
		assert(type(changes) == "table", "changes missing")
		for _, c in changes do
			seen += 1
			assert(math.abs(c.to - c.from) == 1, "a change should move OVR by exactly one")
			assert(type(c.look) == "number" and type(c.name) == "string" and type(c.number) == "number", "change lacks card fields")
			local found = false
			for _, line in news do
				if line:find(c.name, 1, true) then
					found = true
				end
			end
			assert(found, "every change needs a matching news line")
		end
	end
	assert(seen > 0, "20 matches with a pro coach should develop somebody")
end

-- X214: prospects avoid the names passed in (the current squad)
function T.prospectsAvoidSquadNames()
	local first = Squad.prospects(77, 45, 3)
	local avoid: { [string]: boolean } = {}
	for _, p in first do
		avoid[p.name] = true
	end
	local again = Squad.prospects(77, 45, 3, avoid)
	for _, p in again do
		assert(not avoid[p.name], "prospect reuses a squad name: " .. p.name)
	end
end

function T.matchSquadKeepsSlotsWhenShort()
	local players = Squad.generate(12, 45)
	for i = 1, 7 do
		players[i].injured = 2
	end
	local ms = Squad.matchSquad(players, Squad.autoLineup(players))
	assert(#ms >= #Pitch.ROLES, "matchday squad shorter than the XI")
	for slot, role in Pitch.ROLES do
		assert(ms[slot] ~= nil, "empty slot " .. slot)
		if ms[slot].id < 0 then
			assert(ms[slot].role == role, "trialist in the wrong role")
		end
	end
end

function T.creditScorersFollowsSubs()
	local events = {
		{ team = "Home", type = "GOAL", minute = 20, scorer = 10 },
		{ team = "Home", type = "GOAL", minute = 70, scorer = 10 },
		{ team = "Away", type = "GOAL", minute = 75 },
		{ team = "Home", type = "GOAL", minute = 80, scorer = 9 },
	}
	local slots = Squad.creditScorers(events :: any, { { out = 10, ["in"] = 13, minute = 60 } })
	assert(#slots == 3, "expected three home scorers")
	assert(slots[1] == 10 and slots[2] == 13 and slots[3] == 9, "goals after the sub should go to the substitute")
	assert((events[2] :: any).scorer == 13, "event scorer not updated")
end

function T.afterMatchCountsSubstitutes()
	local players = Squad.generate(9, 45)
	local lineup = Squad.autoLineup(players)
	local benchId = lineup.bench[1]
	Squad.afterMatch(players, lineup.xi, {}, 0, Random.new(3), { benchId })
	assert(Squad.byId(players)[benchId].apps == 1, "substitute got no appearance")
end


function T.creditScorersKeepsSameMinuteGoalBeforeSub()
	local events = {
		{ team = "Home", type = "GOAL", minute = 40, scorer = 10 },
		{ team = "Home", type = "GOAL", minute = 41, scorer = 10 },
	}
	-- the sub came in minute 40 but after the first goal was shown
	local slots = Squad.creditScorers(events :: any, { { out = 10, ["in"] = 13, minute = 40, afterEvent = 1 } })
	assert(slots[1] == 10, "a goal shown before the sub stays the starter's")
	assert(slots[2] == 13, "a later goal goes to the substitute")
end

function T.veteransRetireAndFreeTheirShirt()
	local players = Squad.generate(11, 45)
	-- a settled squad: 20 players, most of them past it
	while #players < Config.SquadMax do
		local clone = table.clone(players[1])
		clone.id = #players + 1
		clone.number = #players + 1
		clone.role = "MID"
		table.insert(players, clone)
	end
	for i, p in players do
		p.age = if i <= 6 then 22 else 36
	end
	local retired = Squad.retireVeterans(players, Random.new(4))
	assert(#retired > 0, "nobody retired from a squad of 36-year-olds")
	local freed = retired[1].number
	for _, p in retired do
		assert(p.age >= Config.RetireAge, "retired a player from inside the window")
		assert(Squad.byId(players)[p.id] == nil, "a retired player is still in the squad")
	end
	local used = {}
	for _, p in players do
		assert(not used[p.number], "two players share a shirt number")
		used[p.number] = true
	end
	assert(used[freed] == nil, "the retired shirt number is still taken")
end

function T.retirementKeepsALastKeeper()
	local players = Squad.generate(12, 45)
	for _, p in players do
		p.age = 40 -- everyone is well past Config.RetireMaxAge
	end
	local before = #players
	local retired = Squad.retireVeterans(players, Random.new(5))
	assert(#retired == before - 1, "everyone but the last keeper should have gone")
	assert(#players == 1 and players[1].role == "GK", "the last goalkeeper was retired")
end

-- The squad the above leaves behind is the case that used to freeze: at (or
-- below) the minimum, nobody could retire and everyone kept ageing.
function T.academyRefillsTheSquadAfterRetirements()
	local players = Squad.generate(14, 45)
	for _, p in players do
		p.age = 40
	end
	Squad.retireVeterans(players, Random.new(7))
	local graduates = Squad.promoteYouth(players, Random.new(8), 100)
	-- a matchday needs an XI and a full bench, not Config.SquadMin (review of
	-- X277), and the 40-year-old keeper who could not retire gets a successor
	-- the refill itself covers the missing keeper: neediestRole puts GK first
	local matchday = #Pitch.ROLES + Config.BenchSize
	assert(#players == matchday, "the academy did not refill to a matchday squad")
	assert(#graduates == matchday - 1, "wrong number of graduates")
	local used, names = {}, {}
	local keepers = 0
	for _, p in players do
		assert(not used[p.number], "two players share a shirt number")
		assert(not names[p.name], "two players share a name")
		used[p.number], names[p.name] = true, true
		keepers += if p.role == "GK" then 1 else 0
	end
	assert(keepers >= 2, "the academy should have covered the missing goalkeeper")
	for i, p in graduates do
		assert(p.age <= 19, "an academy graduate is not young")
		assert(p.potential > p.overall, "an academy graduate has no headroom")
		assert(p.id == 99 + i, "graduate ids should follow the club's next id")
	end
end

-- X286: the academy used to be measured against the squad it was joining, so
-- an old club that lived off its academy walked down to the 30 OVR floor.
function T.academyDoesNotSpiralDownwards()
	local players = Squad.generate(21, 45)
	local rng = Random.new(22)
	for generation = 1, 20 do
		for _, p in players do
			p.age = 40
		end
		Squad.retireVeterans(players, rng)
		Squad.promoteYouth(players, rng, generation * 100)
		assert(#players >= #Pitch.ROLES + Config.BenchSize, "the squad did not refill in generation " .. generation)
	end
	local avg = Squad.average(players)
	assert(avg > Squad.MIN_OVERALL + 5, ("twenty academy generations decayed the squad to %d OVR"):format(avg))
end

function T.academyDoesNothingForAFullSquad()
	local players = Squad.generate(15, 45)
	assert(#Squad.promoteYouth(players, Random.new(9), 100) == 0, "promoted into a full squad")
	assert(#players == 16, "squad changed")
end

-- Review of X277: the academy also has to cover the one player retirement
-- cannot take, and must not hand a graduate a name the club is still showing.
function T.academyReplacesTheAgeingLastKeeper()
	local players = Squad.generate(16, 45)
	for i = #players, 1, -1 do
		if players[i].role == "GK" then
			table.remove(players, i)
			break
		end
	end
	for _, p in players do
		if p.role == "GK" then
			p.age = Config.RetireMaxAge + 3 -- the only keeper, past the window
		end
	end
	local before = #players
	local graduates = Squad.promoteYouth(players, Random.new(10), 200)
	assert(#graduates > 0 and #players > before, "nobody came up for the old keeper")
	local youngKeepers = 0
	for _, p in players do
		if p.role == "GK" and p.age < Config.RetireMaxAge then
			youngKeepers += 1
		end
	end
	assert(youngKeepers >= 1, "the academy left the club with only an over-age keeper")
end

function T.academyAvoidsNamesTheClubIsStillShowing()
	local players = Squad.generate(17, 45)
	while #players > Config.SquadMin do
		table.remove(players)
	end
	local avoid = { ["Rafa Retiree"] = true, ["Kit Prospect"] = true }
	local graduates = Squad.promoteYouth(players, Random.new(11), 300, avoid)
	assert(#graduates > 0, "nobody came up")
	for _, p in graduates do
		assert(not avoid[p.name], "a graduate took a name the club is still showing")
	end
end

function T.nobodyRetiresBeforeTheWindow()
	local players = Squad.generate(13, 45)
	for _, p in players do
		p.age = Config.RetireAge - 1
	end
	assert(#Squad.retireVeterans(players, Random.new(6)) == 0, "a player retired below the window")
	assert(#players == 16, "squad changed")
end

function T.manOfTheMatchGoesToTheScorer()
	local players = Squad.generate(31, 45)
	local lineup = Squad.autoLineup(players)
	local scorer = lineup.xi[6]
	local award = Squad.manOfTheMatch(players, lineup.xi, { scorer, scorer }, 2)
	assert(award and award.id == scorer, "the two-goal scorer should take it")
	assert(award.reason == "2 goals", "the reason should count the goals")
end

function T.manOfTheMatchGoesToTheKeeperInAGoallessDraw()
	local players = Squad.generate(32, 45)
	local lineup = Squad.autoLineup(players)
	local award = Squad.manOfTheMatch(players, lineup.xi, {}, 0)
	assert(award, "somebody should get it")
	assert(Squad.byId(players)[award.id].role == "GK", "a clean sheet with no goals is the keeper's")
	assert(award.reason == "a clean sheet", "say why")
end

function T.manOfTheMatchFallsBackToTheBestPlayer()
	local players = Squad.generate(33, 45)
	local lineup = Squad.autoLineup(players)
	local award = Squad.manOfTheMatch(players, lineup.xi, {}, 3)
	assert(award, "somebody should get it even in a 0-3")
	local best = 0
	for _, id in lineup.xi do
		best = math.max(best, Squad.byId(players)[id].overall)
	end
	assert(Squad.byId(players)[award.id].overall == best, "the best player on the pitch")
end

function T.milestonesAreAnnouncedOnTheMatchTheyFall()
	local players = Squad.generate(34, 45)
	local lineup = Squad.autoLineup(players)
	local byId = Squad.byId(players)
	local hero = byId[lineup.xi[9]]
	hero.apps = 49
	hero.goals = 9
	local news = Squad.afterMatch(players, lineup.xi, { hero.id, hero.id, hero.id }, 0, Random.new(35))
	local joined = table.concat(news, " | ")
	assert(string.find(joined, "makes their 50th appearance", 1, true), "the 50th appearance should be news: " .. joined)
	assert(string.find(joined, "reaches 10 goals", 1, true), "the 10th goal should be news: " .. joined)
	assert(string.find(joined, "hat-trick", 1, true), "three in a match is a hat-trick: " .. joined)
	-- and not again next week
	local quiet = table.concat(Squad.afterMatch(players, lineup.xi, {}, 0, Random.new(36)), " | ")
	assert(not string.find(quiet, "appearance", 1, true), "a milestone should only be announced once")
end

-- X292: a coach has to keep paying past a player's 24th birthday.
function T.peakAgePlayersStillImproveWithACoach()
	local function seasonsOfDevelopment(coachLevel: number, age: number): number
		local players = Squad.generate(41, 45)
		local lineup = Squad.autoLineup(players)
		local watched = Squad.byId(players)[lineup.xi[8]]
		watched.age = age
		watched.overall = 50
		watched.potential = 70
		local rng = Random.new(42)
		for _ = 1, 40 do
			Squad.afterMatch(players, lineup.xi, {}, coachLevel, rng)
			watched.injured = 0 -- injuries are not what this test is about
		end
		return watched.overall - 50
	end
	local withCoach = seasonsOfDevelopment(3, 25)
	local without = seasonsOfDevelopment(0, 25)
	assert(withCoach > 0, "a player in his prime never improved even with a Pro Coach")
	assert(withCoach > without, "the coach should make the difference in the peak years")
	local young = seasonsOfDevelopment(3, 19)
	assert(young > withCoach, "a 19-year-old should still come on faster than a 25-year-old")
	assert(seasonsOfDevelopment(3, 29) == 0, "28-30 is a plateau, not a growth window")
end

-- X308: a trialist holds an empty slot and is not in the squad table.
function T.aTrialistCanWinTheAwardAndTheirGoalsAreAdmitted()
	local players = Squad.generate(51, 45)
	-- leave one slot unfillable: only ten fit players
	while #players > 10 do
		table.remove(players)
	end
	local lineup = Squad.autoLineup(players)
	local matchSquad = Squad.matchSquad(players, lineup)
	local trialist = nil
	for _, m in matchSquad do
		if m.id < 0 then
			trialist = m
			break
		end
	end
	assert(trialist, "a short squad should get a trialist")
	local award = Squad.manOfTheMatch(players, lineup.xi, { trialist.id, trialist.id }, 2, matchSquad)
	assert(award and award.id == trialist.id, "the trialist scored twice and should take the award")
	assert(award.name == "Trialist", "with their name on it")
	local news = Squad.afterMatch(players, lineup.xi, { trialist.id, trialist.id }, 0, Random.new(52))
	local joined = table.concat(news, " | ")
	assert(string.find(joined, "A trialist scored 2", 1, true), "the goals should be admitted: " .. joined)
end

-- X338: one picker and one bench order, shared by Auto Squad and the manual repair

local function squadFor338(): { Squad.Player }
	local out = {}
	local function add(id, role, overall, injured)
		table.insert(out, {
			id = id, name = "P" .. id, number = id, role = role, age = 24,
			overall = overall, potential = overall + 5, injured = injured or 0, apps = 0, goals = 0, look = id,
		})
	end
	add(1, "GK", 60)
	add(2, "GK", 58) -- the reserve keeper: must never fill an outfield hole
	for i = 3, 14 do
		add(i, if i < 7 then "DEF" elseif i < 11 then "MID" else "FWD", 40 + i)
	end
	return out
end

function T.fillSlotNeverReachesForTheSpareKeeper()
	local players = squadFor338()
	local taken = { [1] = true } -- the first keeper is already in goal
	-- a defender's slot: the reserve keeper (58) outranks every outfielder here,
	-- so a rating-only picker would put him at the back
	local slot = nil
	for i, role in Pitch.ROLES do
		if role == "DEF" then
			slot = i
			break
		end
	end
	assert(slot, "the formation should have a defender")
	local id = Squad.fillSlot(players, slot :: number, taken)
	assert(id ~= 2, "the reserve goalkeeper should not fill an outfield slot")
	local picked = nil
	for _, p in players do
		if p.id == id then
			picked = p
		end
	end
	assert(picked and picked.role == "DEF", "it should be a defender, got " .. tostring(picked and picked.role))
end

function T.fillSlotPrefersAKeeperInGoal()
	local players = squadFor338()
	local slot = nil
	for i, role in Pitch.ROLES do
		if role == "GK" then
			slot = i
		end
	end
	assert(Squad.fillSlot(players, slot :: number, {}) == 1, "the better keeper goes in goal")
	assert(Squad.fillSlot(players, slot :: number, { [1] = true }) == 2, "and the reserve keeper when he is taken")
end

function T.fillSlotSkipsTheInjuredAndTheTaken()
	local players = squadFor338()
	players[3].injured = 2
	local taken = {}
	for i = 4, 14 do
		taken[players[i].id] = true
	end
	local slot = nil
	for i, role in Pitch.ROLES do
		if role == "DEF" then
			slot = i
			break
		end
	end
	local id = Squad.fillSlot(players, slot :: number, taken)
	assert(id ~= players[3].id, "an injured player should not be picked")
end

function T.benchComesBackBestFirst()
	local players = squadFor338()
	local bench = Squad.benchOrder(players, {})
	assert(#bench > 0, "there should be a bench")
	local best = nil
	for i, id in bench do
		local p = nil
		for _, q in players do
			if q.id == id then
				p = q
			end
		end
		assert(p, "bench ids should be real players")
		if best then
			assert(p.overall <= best, ("bench should be best first: %d after %d"):format(p.overall, best))
		end
		best = p.overall
		assert(i <= Config.BenchSize, "and no longer than the bench")
	end
end

function T.benchSkipsTheInjuredAndTheTaken()
	local players = squadFor338()
	players[5].injured = 1
	local bench = Squad.benchOrder(players, { [players[6].id] = true })
	for _, id in bench do
		assert(id ~= players[5].id, "an injured player should not be benched")
		assert(id ~= players[6].id, "nor one already in the XI")
	end
end

-- X333: the coach's own substitutions

function T.noCoachNeverMakesASubstitution()
	for minute = 0, 90, 5 do
		assert(not Squad.coachWantsSub(minute, {}, 0), "a club with no coach should never sub itself at " .. minute)
	end
end

function T.aCoachWaitsForTheHour()
	local first = Config.AutoSubMinutes[1]
	assert(not Squad.coachWantsSub(first - 1, {}, 3), "not before his first window")
	assert(Squad.coachWantsSub(first, {}, 3), "and does at it")
	assert(Squad.coachWantsSub(90, {}, 3), "and certainly by the end")
end

function T.eachCoachOnlyGetsHisOwnAllowance()
	local made = { { out = 2, ["in"] = 12, minute = 60, afterEvent = 0 } }
	assert(not Squad.coachWantsSub(90, made, 1), "a volunteer coach only makes one")
	assert(Squad.coachWantsSub(Config.AutoSubMinutes[2], made, 2), "a qualified coach makes a second")
	local three = { made[1], { out = 3, ["in"] = 13, minute = 72, afterEvent = 0 }, { out = 4, ["in"] = 14, minute = 82, afterEvent = 0 } }
	assert(not Squad.coachWantsSub(90, three, 3), "and nobody makes a fourth")
end

-- X271: the coach's own tactics

function T.noCoachNeverChangesTheTactic()
	for minute = 0, 90, 5 do
		assert(Squad.coachTactic(minute, 0, 3, 0) == nil, "a club with no coach has nobody to change it at " .. minute)
	end
end

function T.aCoachChasesTheGameAndProtectsALead()
	for level = 1, #Config.CoachLevels - 1 do
		local from = Config.CoachLevels[level + 1].tacticsFrom
		assert(from, "every real coach has a minute he starts thinking at")
		assert(Squad.coachTactic(from - 1, 0, 1, level) == nil, "not before his minute")
		assert(Squad.coachTactic(from, 0, 1, level) == "Attack", "behind: go for it")
		assert(Squad.coachTactic(from, 2, 1, level) == "Defend", "ahead: shut it down")
		assert(Squad.coachTactic(from, 1, 1, level) == "Balanced", "level: as you were")
	end
end

function T.aBetterCoachReactsSooner()
	local last = math.huge
	for level = 1, #Config.CoachLevels - 1 do
		local from = Config.CoachLevels[level + 1].tacticsFrom
		assert(from < last, "level " .. level .. " should react before the one below")
		last = from
	end
end

function T.theCoachNeverExceedsTheMatchLimit()
	local made = {}
	for i = 1, Config.MaxSubs do
		table.insert(made, { out = i + 1, ["in"] = 11 + i, minute = 60, afterEvent = 0 })
	end
	assert(not Squad.coachWantsSub(90, made, 99), "the match limit still applies")
end

-- X334: the change an injury forces

local function matchSquadFor334(): { Squad.MatchPlayer }
	local out = {}
	local function add(idx, role, overall)
		out[idx] = { id = idx, name = "P" .. idx, number = idx, role = role, overall = overall, injured = 0 } :: any
	end
	for slot, role in Pitch.ROLES do
		add(slot, role, 50 + slot)
	end
	add(#Pitch.ROLES + 1, "DEF", 48)
	add(#Pitch.ROLES + 2, "FWD", 52)
	add(#Pitch.ROLES + 3, "GK", 45)
	return out
end

function T.aForcedSubTakesOffTheManWhoWentDown()
	local squad = matchSquadFor334()
	local sub = Squad.forcedSub(squad, {}, 4)
	assert(sub and sub.out == 4, "the injured slot is the one that comes off")
	assert(sub and sub["in"] > #Pitch.ROLES, "and the replacement comes off the bench")
end

function T.aKeeperIsReplacedByAKeeper()
	local squad = matchSquadFor334()
	local gkSlot = nil
	for slot, role in Pitch.ROLES do
		if role == "GK" then
			gkSlot = slot
		end
	end
	local sub = Squad.forcedSub(squad, {}, gkSlot :: number)
	assert(sub, "there is a spare keeper on this bench")
	assert(squad[(sub :: any)["in"]].role == "GK", "and he is the one who comes on")
end

function T.aForcedSubGivesUpWhenThereIsNobody()
	local squad = matchSquadFor334()
	-- strip the bench
	for idx = #Pitch.ROLES + 1, #squad do
		squad[idx] = nil
	end
	assert(Squad.forcedSub(squad, {}, 3) == nil, "no bench, no substitution")
end

function T.aForcedSubRespectsTheMatchLimit()
	local squad = matchSquadFor334()
	local made = {}
	for i = 1, Config.MaxSubs do
		table.insert(made, { out = i + 1, ["in"] = #Pitch.ROLES + i, minute = 60, afterEvent = 0 })
	end
	assert(Squad.forcedSub(squad, made, 5) == nil, "the match limit still applies")
end

-- X344 ----------------------------------------------------------------------

function T.aShirtIsFollowedThroughEverySubstitutionMadeInIt()
	assert(Squad.filledBy({}, 7) == 7, "nobody has moved")
	local one = { { out = 7, ["in"] = 13, minute = 60 } }
	assert(Squad.filledBy(one, 7) == 13, "the substitute is in that shirt now")
	assert(Squad.filledBy(one, 8) == 8, "and the shirt beside it is untouched")
	local chain = { { out = 7, ["in"] = 13, minute = 60 }, { out = 13, ["in"] = 14, minute = 75 } }
	assert(Squad.filledBy(chain, 7) == 14, "two changes in one shirt follow through")
end

function T.aMomentDecidesWhetherAChangeCountsYet()
	-- X357: X218's rule, now in one place. A goal earlier in the same minute as
	-- the substitution still belongs to the man who was on the pitch then.
	local made = { { out = 9, ["in"] = 14, minute = 60, afterEvent = 3 } }
	assert(Squad.filledBy(made, 9) == 14, "with no moment, the change has happened")
	assert(Squad.filledBy(made, 9, { index = 3, minute = 60 }) == 9, "the third event is not after the change")
	assert(Squad.filledBy(made, 9, { index = 4, minute = 60 }) == 14, "the fourth is")
	-- a saved substitution without afterEvent falls back to the minute
	local old = { { out = 9, ["in"] = 14, minute = 60 } }
	assert(Squad.filledBy(old, 9, { index = 1, minute = 59 }) == 9, "before his minute")
	assert(Squad.filledBy(old, 9, { index = 1, minute = 60 }) == 14, "and from his minute on")
end

function T.anInjuryInAShirtAlreadySubstitutedTakesOffTheSubstitute()
	-- X344: the sim names a starting slot, and the coach (X333) may already
	-- have put somebody else in it. The old code walked the starter off again
	-- and injured him for next week while the substitute played on.
	local squad = matchSquadFor334()
	local first = { out = 2, ["in"] = #Pitch.ROLES + 1, minute = 60, afterEvent = 0 }
	local forced = Squad.forcedSub(squad, { first }, 2)
	assert(forced, "the substitute can be replaced himself")
	local f = forced :: any
	assert(f.out == first["in"], ("%d should be the man who goes off, not %d"):format(first["in"], f.out))
	assert(f["in"] ~= first["in"] and f["in"] > #Pitch.ROLES, "and a different bench player comes on")
	-- and the chain follows once more, given somebody left to bring on
	squad[#Pitch.ROLES + 4] = { id = 98, name = "P98", number = 98, role = "DEF", overall = 46, injured = 0 } :: any
	local third = Squad.forcedSub(squad, { first, f }, 2)
	assert(third and (third :: any).out == f["in"], "a third man in the same shirt can go off too")
	assert(third and (third :: any)["in"] == #Pitch.ROLES + 4, "and the last outfielder on the bench comes on")
end

function T.aKeeperOffTheBenchIsReplacedByAKeeper()
	-- X344: a substitute is in no formation slot, so his own role decides
	local squad = matchSquadFor334()
	local gkBench, otherGk = nil, nil
	for idx = #Pitch.ROLES + 1, #squad do
		if squad[idx] and squad[idx].role == "GK" then
			gkBench = idx
		end
	end
	assert(gkBench, "this bench has a keeper")
	-- add a second spare keeper so there is somebody to bring on
	squad[#Pitch.ROLES + 4] = { id = 99, name = "P99", number = 99, role = "GK", overall = 44, injured = 0 } :: any
	otherGk = #Pitch.ROLES + 4
	local keeperSlot = nil
	for slot, role in Pitch.ROLES do
		if role == "GK" then
			keeperSlot = slot
		end
	end
	local first = { out = keeperSlot :: number, ["in"] = gkBench :: number, minute = 30, afterEvent = 0 }
	local forced = Squad.forcedSub(squad, { first }, keeperSlot :: number)
	assert(forced and (forced :: any)["in"] == otherGk, "the other keeper comes on, not an outfielder")
end

-- X337 ----------------------------------------------------------------------

function T.aScoutsBandAlwaysHoldsTheTruth()
	for width = 1, 12 do
		for potential = Squad.MIN_OVERALL, Squad.MAX_OVERALL, 7 do
			for seed = 1, 6 do
				local low, high = Squad.potentialBand(potential, width, seed)
				assert(low <= potential and potential <= high,
					("%d is outside %d-%d (width %d)"):format(potential, low, high, width))
				assert(high - low == width, ("%d-%d should be %d wide"):format(low, high, width))
			end
		end
	end
end

function T.aBandNeverLeavesTheRatingsTheGameUses()
	for _, potential in { Squad.MIN_OVERALL, Squad.MIN_OVERALL + 1, Squad.MAX_OVERALL - 1, Squad.MAX_OVERALL } do
		for seed = 1, 20 do
			local low, high = Squad.potentialBand(potential, 10, seed)
			assert(low >= Squad.MIN_OVERALL, ("low %d under the floor"):format(low))
			assert(high <= Squad.MAX_OVERALL, ("high %d over the ceiling"):format(high))
			assert(low <= potential and potential <= high, ("%d is outside %d-%d"):format(potential, low, high))
		end
	end
end

function T.theBestScoutNamesTheNumber()
	local low, high = Squad.potentialBand(72, 0, 5)
	assert(low == 72 and high == 72, ("got %d-%d"):format(low, high))
	local levels = Config.ScoutLevels
	assert(Squad.scoutDoubt(#levels) == 0, "the top scouting network deals in facts")
	assert(Squad.scoutDoubt(0) == 0 and Squad.scoutDoubt(#levels + 1) == 0, "and no scout at all cannot be wrong")
	local previous = math.huge
	for i, level in levels do
		local doubt = level.potentialDoubt or 0
		assert(doubt <= previous, ("level %d (%s) is vaguer than the one below it"):format(i, level.name))
		previous = doubt
	end
end

function T.theMidpointIsNotAShortcutToTheRealNumber()
	-- the band is deliberately not centred on the truth
	local same, total = 0, 0
	for seed = 1, 300 do
		local low, high = Squad.potentialBand(70, 10, seed)
		total += 1
		if (low + high) / 2 == 70 then
			same += 1
		end
	end
	assert(same < total / 2, ("the midpoint gave it away %d times in %d"):format(same, total))
end

function T.aBandNeverStartsBelowWhatThePlayerAlreadyIs()
	for seed = 1, 30 do
		local low, high = Squad.potentialBand(60, 10, seed, 58)
		assert(low >= 58, ("band %d-%d starts under the floor"):format(low, high))
		assert(low <= 60 and 60 <= high, ("60 is outside %d-%d"):format(low, high))
		assert(high - low == 10, ("%d-%d should be 10 wide"):format(low, high))
	end
	-- a floor under the game's own minimum changes nothing
	local low = Squad.potentialBand(60, 10, 3, 5)
	assert(low >= Squad.MIN_OVERALL, "the ratings floor still applies")
end

function T.theSameProspectIsReportedTheSameWay()
	for seed = 1, 10 do
		local lowA, highA = Squad.potentialBand(64, 7, seed)
		local lowB, highB = Squad.potentialBand(64, 7, seed)
		assert(lowA == lowB and highA == highB, "a rebuilt panel must not re-roll the band")
	end
end

function T.everyProspectCarriesHisScoutsBand()
	for scoutLevel = 1, #Config.ScoutLevels do
		local list = Squad.prospects(1234, 55, scoutLevel)
		assert(#list > 0, "the scout found nobody")
		local width = Config.ScoutLevels[scoutLevel].potentialDoubt or 0
		for _, p in list do
			local low, high = (p :: any).potentialLow, (p :: any).potentialHigh
			assert(type(low) == "number" and type(high) == "number", "no band on a prospect")
			assert(low <= p.potential and p.potential <= high,
				("%s: %d outside %d-%d"):format(p.name, p.potential, low, high))
			-- no scout suggests a ceiling below what the player already is
			assert(low >= p.overall, ("%s: band %d-%d starts under his %d OVR"):format(p.name, low, high, p.overall))
			if width == 0 then
				assert(low == high and low == p.potential, "the best scout names it")
			end
		end
	end
end

-- X351 ----------------------------------------------------------------------

function T.aPlayerYouHaveJustSignedSellsAtALoss()
	local function man(age, apps)
		return { id = 1, name = "P", number = 9, role = "FWD", age = age, overall = 62, potential = 74,
			injured = 0, apps = apps, goals = 0, look = 1 } :: any
	end
	local fresh = man(21, 0)
	local settled = man(21, Config.ResaleAppearances)
	local fee = Squad.fee(fresh)
	assert(Squad.value(fresh) < fee, ("a signing with no appearances should sell below his %d fee"):format(fee))
	assert(Squad.value(settled) > Squad.value(fresh), "and he is worth more once he has played")
	assert(Squad.value(settled) < fee, "but never the whole fee back")
	-- it rises with appearances and then stops
	local half = Squad.value(man(21, math.ceil(Config.ResaleAppearances / 2)))
	assert(half > Squad.value(fresh) and half < Squad.value(settled), "the discount should narrow with appearances")
	assert(Squad.value(man(21, 200)) == Squad.value(settled), "and stop narrowing once he is established")
	-- age still matters on top of it
	assert(Squad.value(man(35, 200)) < Squad.value(man(21, 200)), "a veteran is worth less than a youngster")
	assert(Squad.value(fresh) % 50 == 0 and Squad.value(fresh) >= 100, "still rounded to 50, still above the floor")
end

-- X356 ----------------------------------------------------------------------

function T.theVerdictSaysWhereTheSquadStandsInItsDivision()
	local base = 60
	-- X359: the boundaries themselves, not points either side of them - the
	-- first version sampled +10/+3/0/-1/-4/-12 and tested none of the four
	local function verdict(gap: number): string
		return Squad.divisionVerdict(base + gap, base)
	end
	assert(verdict(6) == "too good for this level", "+6 is the top band")
	assert(verdict(5.99) == "stronger than this level", "just under it is not")
	assert(verdict(2) == "stronger than this level", "+2 is the second band")
	assert(verdict(1.99) == "about right", "just under it is level")
	assert(verdict(-1.99) == "about right", "and so is just above -2")
	assert(verdict(-2) == "a bit light", "-2 is light")
	assert(verdict(-5.99) == "a bit light", "and so is just above -6")
	assert(verdict(-6) == "well short", "-6 is short")
	assert(verdict(-30) == "well short", "and anything worse")
	-- every division has a verdict for every rating the game can produce
	for tier = 1, #Config.Divisions do
		for rating = Squad.MIN_OVERALL, Squad.MAX_OVERALL, 5 do
			local text = Squad.divisionVerdict(rating, Config.Divisions[tier].baseStrength)
			assert(type(text) == "string" and #text > 0, ("no verdict at %d in tier %d"):format(rating, tier))
		end
	end
end

-- X352 ----------------------------------------------------------------------

function T.aProCoachPicksABetterTeamThanNobody()
	-- CLAUDE.md s9 puts "automatic lineup quality" first among what a coach
	-- influences, and a club with no coach used to pick a bit-for-bit
	-- identical XI to a 10,000 pound Pro Coach.
	local pro = Squad.misjudgeFor(#Config.CoachLevels - 1)
	local none = Squad.misjudgeFor(0)
	assert(pro == 0 and none > 0, ("a Pro Coach should see straight: %d against %d"):format(pro, none))
	local weaker, equal = 0, 0
	for seed = 1, 40 do
		local players = Squad.generate(seed, 55)
		local best = Squad.autoLineup(players, pro)
		local guess = Squad.autoLineup(players, none)
		local bestStrength = Squad.strength(players, best.xi)
		local guessStrength = Squad.strength(players, guess.xi)
		assert(guessStrength <= bestStrength + 0.001,
			("no coach out-picked a Pro Coach on seed %d: %.2f against %.2f"):format(seed, guessStrength, bestStrength))
		if guessStrength < bestStrength - 0.001 then
			weaker += 1
		else
			equal += 1
		end
	end
	assert(weaker > 0, "a coachless club should sometimes pick the wrong XI")
	assert(equal > 0, "and sometimes stumble on the right one")
end

function T.theSameCoachAlwaysPicksTheSameTeam()
	-- the misjudgement is a function of the player's id, not a roll, or the XI
	-- would flicker every time the panel refreshed
	local players = Squad.generate(7, 50)
	local misjudge = Squad.misjudgeFor(1)
	local first = Squad.autoLineup(players, misjudge)
	for _ = 1, 5 do
		local again = Squad.autoLineup(players, misjudge)
		for slot = 1, #Pitch.ROLES do
			assert(again.xi[slot] == first.xi[slot], "the XI moved between refreshes")
		end
		for i, id in first.bench do
			assert(again.bench[i] == id, "the bench moved between refreshes")
		end
	end
end

function T.aBetterCoachIsNeverAWorseJudge()
	local misjudges = {}
	for level = 0, #Config.CoachLevels - 1 do
		table.insert(misjudges, Squad.misjudgeFor(level))
	end
	for i = 2, #misjudges do
		assert(misjudges[i] <= misjudges[i - 1], ("level %d is a worse judge than the one below it"):format(i - 1))
	end
	-- and a player is seen as himself when nobody is guessing
	local players = Squad.generate(3, 60)
	assert(Squad.perceived(players[1], 0) == players[1].overall, "a Pro Coach sees the real rating")
	assert(math.abs(Squad.perceived(players[1], 6) - players[1].overall) <= 6, "and nobody is wrong by more than the spread")
end

-- Nationality: everybody comes from somewhere, and the name matches the flag
local function nameFits(p: any): boolean
	local nation = Nations.get(p.nation)
	local first, last = p.name:match("^(%S+) (.+)$")
	return nation.code == p.nation and table.find(nation.first, first) ~= nil and table.find(nation.last, last) ~= nil
end

function T.everyGeneratedPlayerHasANationThatFitsHisName()
	for _, p in Squad.generate(21, 45) do
		assert(type(p.nation) == "string" and nameFits(p), p.name .. " does not fit " .. tostring(p.nation))
	end
	for _, p in Squad.prospects(22, 60, #Config.ScoutLevels) do
		assert(nameFits(p), "prospect " .. p.name .. " does not fit " .. tostring(p.nation))
	end
	local players = Squad.generate(23, 45)
	table.remove(players, 1)
	for _, p in Squad.promoteYouth(players, Random.new(1), 100) do
		assert(nameFits(p), "graduate " .. p.name .. " does not fit " .. tostring(p.nation))
	end
end

function T.aGrassrootsSquadIsMostlyHomeGrown()
	local home, total = 0, 0
	for seed = 1, 20 do
		for _, p in Squad.generate(seed, 45) do
			total += 1
			if Nations.get(p.nation).home then
				home += 1
			end
		end
	end
	assert(home / total > 0.8, ("only %d of %d starting players are home-grown"):format(home, total))
end

function T.aBetterScoutLooksFurtherAbroad()
	local function abroad(level: number): number
		local n, total = 0, 0
		for seed = 1, 150 do
			for _, p in Squad.prospects(seed, 60, level) do
				total += 1
				if not Nations.get(p.nation).home then
					n += 1
				end
			end
		end
		return n / total
	end
	local first, last = abroad(1), abroad(#Config.ScoutLevels)
	assert(Squad.scoutReach(1) == 0, "a Local Scout is local")
	assert(Squad.scoutReach(#Config.ScoutLevels) == 1, "the top network covers the world")
	assert(last > first + 0.25, ("top scout %.0f%% abroad vs local scout %.0f%%"):format(last * 100, first * 100))
end

function T.theMatchdaySquadCarriesTheNation()
	local players = Squad.generate(24, 45)
	for _, m in Squad.matchSquad(players, Squad.autoLineup(players)) do
		assert(type((m :: any).nation) == "string", m.name .. " lost his nation on matchday")
	end
end

-- Rarity: the card colour, from the overall alone
function T.rarityFollowsTheOverall()
	local previous = 0
	for i, tier in Config.Rarity do
		assert(tier.min > previous or i == 1, tier.name .. " does not start above the tier below")
		previous = tier.min
		assert(Squad.rarity(tier.min) == tier.name, ("%d should be %s"):format(tier.min, tier.name))
		if i > 1 then
			assert(Squad.rarity(tier.min - 1) == Config.Rarity[i - 1].name, "the point below a tier belongs to the one under it")
		end
	end
	assert(Squad.rarity(Squad.MIN_OVERALL) == "Bronze" and Squad.rarity(Squad.MAX_OVERALL) == Config.Rarity[#Config.Rarity].name, "the ends of the scale")
	assert(Squad.rarity(Config.StartingSquadOverall) == "Bronze", "a new club is a bronze club")
	assert(Squad.rarity(Config.Divisions[#Config.Divisions].baseStrength) == "Gold", "the top division is gold standard")
end

function T.aWonderkidIsAYoungPlayerWithRealHeadroom()
	assert(Squad.rollsWonderkid(18, Config.WonderkidHeadroom), "a teenager with a high ceiling is the shiny card")
	assert(not Squad.rollsWonderkid(18, Config.WonderkidHeadroom - 1), "not quite enough headroom")
	assert(not Squad.rollsWonderkid(Config.WonderkidMaxAge + 1, 30), "too old to be a wonderkid")
end

function T.wonderkidsAreActuallyUncommon()
	for _, level in { 1, #Config.ScoutLevels } do
		local rare, total = 0, 0
		for seed = 1, 300 do
			for _, p in Squad.prospects(seed, 50, level) do
				total += 1
				if p.wonderkid then
					rare += 1
					assert(p.age <= Config.WonderkidMaxAge, p.name .. " is shiny at " .. p.age)
				end
			end
		end
		local share = rare / total
		assert(share > 0.03 and share < 0.15, ("scout level %d: %.0f%% of cards are wonderkids"):format(level, share * 100))
	end
end

-- Measures the tier odds per scout level at a mid-table squad and checks them
-- against Config.PackOdds (Roblox wants odds published if packs are ever sold).
function T.packOddsAreDocumented()
	for level = 0, #Config.ScoutLevels do
		local counts: { [string]: number } = {}
		local total = 0
		for seed = 1, 400 do
			for _, p in Squad.prospects(seed, 60, level) do
				local tier = Squad.rarity(p.overall)
				counts[tier] = (counts[tier] or 0) + 1
				total += 1
			end
		end
		local documented = Config.PackOdds[level + 1]
		for tier, n in counts do
			local measured = n / total
			assert(math.abs(measured - (documented[tier] or 0)) < 0.03, ("level %d %s: measured %.3f"):format(level, tier, measured))
		end
	end
end

return T
