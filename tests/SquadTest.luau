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

return T
