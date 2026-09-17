--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Squad = require(ReplicatedStorage.Shared.Squad)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Config = require(ReplicatedStorage.Shared.Config)

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

function T.prospectsRespectScoutLevel()
	assert(#Squad.prospects(1, 45, 0) == 0, "no scout should mean no prospects")
	for level, spec in Config.ScoutLevels do
		local list = Squad.prospects(level * 10, 45, level)
		assert(#list == spec.prospects, ("level %d should give %d prospects"):format(level, spec.prospects))
		for _, p in list do
			assert(p.fee >= 100, "fee too small")
			assert(p.id < 0, "prospect ids must be negative")
			assert(p.potential >= p.overall, "potential below overall")
		end
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

return T
