--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSim = require(ReplicatedStorage.Shared.MatchSim)

local T = {}

local function sim(seed: number, bias: any?)
	return MatchSim.simulate({ homeStrength = 50, awayStrength = 50, seed = seed, bias = bias })
end

function T.goalEventsMatchScore()
	for seed = 1, 40 do
		local r = sim(seed)
		local h, a = 0, 0
		for _, ev in r.events do
			if ev.type == "GOAL" then
				if ev.team == "Home" then h += 1 else a += 1 end
			end
		end
		assert(h == r.homeGoals and a == r.awayGoals, ("seed %d: events %d-%d vs score %d-%d"):format(seed, h, a, r.homeGoals, r.awayGoals))
	end
end

function T.timelineHasMissesAndSaves()
	local sawMiss, sawSave = false, false
	for seed = 1, 40 do
		for _, ev in sim(seed).events do
			if ev.type == "MISS" then sawMiss = true end
			if ev.type == "SAVE" then sawSave = true end
		end
	end
	assert(sawMiss, "no MISS events in 40 sims")
	assert(sawSave, "no SAVE events in 40 sims")
end

function T.eventsAreSortedAndSpaced()
	for seed = 1, 40 do
		local evs = sim(seed).events
		for i = 2, #evs do
			local gap = evs[i].minute - evs[i - 1].minute
			assert(gap >= MatchSim.MIN_EVENT_GAP, ("seed %d: gap %d between events %d and %d"):format(seed, gap, i - 1, i))
		end
		for _, ev in evs do
			-- never before minute 10 so kick-off gets real build-up, not a long-range slam
			assert(ev.minute >= 10 and ev.minute <= 88, "event minute out of range: " .. ev.minute)
		end
	end
end

function T.noChancesAcrossHalfTime()
	-- the presenter swaps ends at 45'; a chance whose build-up or aftermath
	-- straddles it would delay the break, so the sim keeps that window clear
	for seed = 1, 60 do
		local r = sim(seed)
		assert(#r.events <= MatchSim.MAX_CHANCES, ("seed %d: %d chances"):format(seed, #r.events))
		for _, ev in r.events do
			assert(ev.minute <= MatchSim.FIRST_HALF_LAST or ev.minute >= MatchSim.SECOND_HALF_FIRST,
				("seed %d: chance at %d' sits across half time"):format(seed, ev.minute))
		end
	end
end

-- Win rate over many seeds for a given strength pairing, as a percentage.
local function winRate(home: number, away: number): number
	local wins = 0
	local runs = 600
	for seed = 1, runs do
		local r = MatchSim.simulate({ homeStrength = home, awayStrength = away, seed = seed })
		if r.homeGoals > r.awayGoals then
			wins += 1
		end
	end
	return wins / runs * 100
end

-- The whole point of buying players: a squad that outclasses the division has
-- to win most weeks. The old flat share gave 75.6 v 44 only a 53% win rate,
-- so investing in the squad never showed up on the scoreboard.
function T.strongSquadDominatesWeakDivision()
	local rate = winRate(75.6, 44)
	assert(rate >= 82, ("a 75.6 squad should bully a 44 division, got %.1f%%"):format(rate))
end

-- ...but an evenly matched game still has to be a real contest, or every
-- division would be decided the moment the season starts.
function T.evenMatchIsStillACoinFlip()
	local rate = winRate(50, 50)
	assert(rate >= 38 and rate <= 58, ("even match should stay competitive, got %.1f%%"):format(rate))
end

-- Difficulty has to keep rising: the same squad that walks the bottom tier
-- must not walk the top one.
function T.winRateFallsAsTheDivisionGetsHarder()
	local tier1 = winRate(75.6, 44)
	local tier3 = winRate(75.6, 60)
	local tier5 = winRate(75.6, 76)
	assert(tier1 > tier3 and tier3 > tier5, ("win rate should fall with tier: %.1f / %.1f / %.1f"):format(tier1, tier3, tier5))
	assert(tier5 <= 50, ("an out-of-depth squad should struggle, got %.1f%%"):format(tier5))
end

-- Mismatches should look like mismatches on the scoreboard, not 1-0 every week.
function T.scorelinesGrowWithTheMismatch()
	local even, gulf = 0, 0
	for seed = 1, 400 do
		even += MatchSim.simulate({ homeStrength = 50, awayStrength = 50, seed = seed }).homeGoals
		gulf += MatchSim.simulate({ homeStrength = 75.6, awayStrength = 44, seed = seed }).homeGoals
	end
	assert(gulf / 400 >= even / 400 * 1.8, ("a dominant side should score far more: %.2f vs %.2f"):format(gulf / 400, even / 400))
end

-- Playing at home is worth something, so the league table is not symmetric.
function T.homeAdvantageExists()
	assert(winRate(50, 50) > 50 - 12, "home side should not be the underdog")
	local home, away = 0, 0
	for seed = 1, 600 do
		local r = MatchSim.simulate({ homeStrength = 50, awayStrength = 50, seed = seed })
		home += r.homeGoals
		away += r.awayGoals
	end
	assert(home > away, ("home side should outscore away over a season: %d vs %d"):format(home, away))
end

function T.seedIsDeterministic()
	local a, b = sim(7), sim(7)
	assert(a.homeGoals == b.homeGoals and a.awayGoals == b.awayGoals and #a.events == #b.events, "same seed gave different results")
	for i, ev in a.events do
		assert(ev.minute == b.events[i].minute and ev.type == b.events[i].type, "event " .. i .. " differs")
	end
end

function T.narrowWinBiasStillHolds()
	for seed = 1, 40 do
		local r = sim(seed, "NarrowWin")
		assert(r.homeGoals - r.awayGoals == 1 and r.homeGoals <= 2, ("seed %d: %d-%d"):format(seed, r.homeGoals, r.awayGoals))
	end
end


function T.trimGoalsKeepsWinnerAndMargin()
	local max = MatchSim.MAX_CHANCES
	for h = 0, 12 do
		for a = 0, 12 do
			local th, ta = MatchSim.trimGoals(h, a)
			assert(th + ta <= max, ("%d-%d still too many"):format(h, a))
			assert(th >= 0 and ta >= 0, "negative goals")
			if h + a <= max then
				assert(th == h and ta == a, "trimmed a score that fit")
			elseif h > 0 and a > 0 and math.abs(h - a) <= max then
				assert(th - ta == h - a, ("%d-%d margin changed to %d-%d"):format(h, a, th, ta))
			end
			local sign = function(x) return if x > 0 then 1 elseif x < 0 then -1 else 0 end
			assert(sign(th - ta) == sign(h - a), ("%d-%d winner changed to %d-%d"):format(h, a, th, ta))
		end
	end
end


function T.awayFixturesLoseTheVenueAdvantage()
	-- X261: same squads, 400 seeds each way. At home the club should score more
	-- and concede less than the same fixture away.
	local function run(away: boolean): (number, number)
		local goalsFor, goalsAgainst = 0, 0
		for seed = 1, 400 do
			local r = MatchSim.simulate({ homeStrength = 50, awayStrength = 50, seed = seed, playerIsAway = away })
			goalsFor += r.homeGoals
			goalsAgainst += r.awayGoals
		end
		return goalsFor, goalsAgainst
	end
	local homeFor, homeAgainst = run(false)
	local awayFor, awayAgainst = run(true)
	assert(homeFor > awayFor, ("home %d should score more than away %d"):format(homeFor, awayFor))
	assert(homeAgainst < awayAgainst, ("home %d should concede less than away %d"):format(homeAgainst, awayAgainst))
end

-- X334: injuries happen in the sim, at a minute, outside the chance timeline

function T.atMostOneInjuryAndItNamesOneOfTheEleven()
	local hurt = 0
	for seed = 1, 150 do
		local r = MatchSim.simulate({ homeStrength = 60, awayStrength = 60, seed = seed })
		if r.injury then
			hurt += 1
			assert(r.injury.slot >= 1 and r.injury.slot <= 11, "it names one of the eleven, seed " .. seed)
			assert(r.injury.minute >= 1 and r.injury.minute <= 90, "at a minute in the match, seed " .. seed)
		end
		for _, ev in r.events do
			assert(ev.type ~= "INJURY", "the chance timeline stays chances only")
		end
	end
	assert(hurt > 150 * 0.15 and hurt < 150 * 0.5, ("about a third of matches should have one, got %d in 150"):format(hurt))
end

function T.theSameMatchIsHurtTheSameWay()
	local a = MatchSim.simulate({ homeStrength = 60, awayStrength = 60, seed = 7 })
	local b = MatchSim.simulate({ homeStrength = 60, awayStrength = 60, seed = 7 })
	assert((a.injury == nil) == (b.injury == nil), "the same seed means the same match")
	if a.injury and b.injury then
		assert(a.injury.minute == b.injury.minute and a.injury.slot == b.injury.slot, "down to the minute and the man")
	end
end

-- X271: ATTACK / DEFEND re-simulate the rest of the match

local LOCK = MatchSim.lockMinutes(90)

local function resim(seed: number, from: number, tactic: any, bias: any?): (MatchSim.Result, MatchSim.Result, number)
	local old = MatchSim.simulate({ homeStrength = 50, awayStrength = 50, seed = seed, bias = bias })
	local new, kept = MatchSim.resimulate({
		homeStrength = 50,
		awayStrength = 50,
		seed = seed + 1000,
		bias = bias,
		result = old,
		fromMinute = from,
		tactic = tactic,
	})
	return old, new, kept
end

function T.resimKeepsWhatHasBeenPlayed()
	for seed = 1, 60 do
		for _, from in { 0, 20, 44, 60 } do
			local old, new, kept = resim(seed, from, "Attack")
			for i, ev in old.events do
				if ev.minute <= from + LOCK then
					assert(new.events[i] == ev, ("seed %d from %d: event %d (%d') was replaced"):format(seed, from, i, ev.minute))
					assert(i <= kept, "kept count is short")
				end
			end
			for i = kept + 1, #new.events do
				assert(new.events[i].minute > from + LOCK, ("seed %d from %d: new chance at %d' is inside the lock"):format(seed, from, new.events[i].minute))
			end
			assert(new.injury == old.injury, "the casualty is not re-rolled")
		end
	end
end

function T.resimTimelineStillObeysTheRules()
	for seed = 1, 60 do
		for _, from in { 0, 12, 30, 38, 44, 55, 70, 79 } do
			for _, tactic in { "Attack", "Defend", "Balanced" } do
				local _, r = resim(seed, from, tactic)
				local h, a = 0, 0
				for i, ev in r.events do
					if ev.type == "GOAL" then
						if ev.team == "Home" then h += 1 else a += 1 end
					end
					assert(ev.minute >= 10 and ev.minute <= 88, "minute out of range: " .. ev.minute)
					assert(ev.minute <= MatchSim.FIRST_HALF_LAST or ev.minute >= MatchSim.SECOND_HALF_FIRST,
						("seed %d from %d: chance at %d' sits across half time"):format(seed, from, ev.minute))
					if i > 1 then
						local gap = ev.minute - r.events[i - 1].minute
						assert(gap >= MatchSim.MIN_EVENT_GAP, ("seed %d from %d %s: gap %d"):format(seed, from, tactic, gap))
					end
				end
				assert(h == r.homeGoals and a == r.awayGoals, ("seed %d from %d: events %d-%d vs score %d-%d"):format(seed, from, h, a, r.homeGoals, r.awayGoals))
				assert(#r.events <= MatchSim.MAX_CHANCES, "too many chances")
			end
		end
	end
end

function T.attackOpensTheGameAndDefendClosesIt()
	local goals = { Attack = { 0, 0 }, Balanced = { 0, 0 }, Defend = { 0, 0 } }
	for seed = 1, 500 do
		for tactic, sum in goals do
			local old, new, kept = resim(seed, 0, tactic)
			-- only the re-simulated part: what was kept is the same in all three
			local keptHome, keptAway = 0, 0
			for i = 1, kept do
				local ev = old.events[i]
				if ev.type == "GOAL" then
					if ev.team == "Home" then keptHome += 1 else keptAway += 1 end
				end
			end
			sum[1] += new.homeGoals - keptHome
			sum[2] += new.awayGoals - keptAway
		end
	end
	local function line(): string
		return ("A %d-%d  B %d-%d  D %d-%d"):format(goals.Attack[1], goals.Attack[2], goals.Balanced[1], goals.Balanced[2], goals.Defend[1], goals.Defend[2])
	end
	assert(goals.Attack[1] > goals.Balanced[1] * 1.1 and goals.Attack[2] > goals.Balanced[2] * 1.1, "attacking should mean more goals at both ends: " .. line())
	assert(goals.Defend[1] < goals.Balanced[1] * 0.9 and goals.Defend[2] < goals.Balanced[2] * 0.9, "defending should mean fewer goals at both ends: " .. line())
end

function T.resimLeavesTheFirstMatchAlone()
	-- Match 1 is a narrow win whatever the player presses (CLAUDE.md s3)
	for seed = 1, 40 do
		for _, tactic in { "Attack", "Defend" } do
			local old, new = resim(seed, 5, tactic, "NarrowWin")
			assert(new.homeGoals == old.homeGoals and new.awayGoals == old.awayGoals, "score moved")
			assert(#new.events == #old.events, "timeline moved")
		end
	end
end

function T.resimNeverThrowsAwayTheSecondMatch()
	for seed = 1, 200 do
		for _, tactic in { "Attack", "Defend" } do
			local old, new = resim(seed, 5, tactic, "LikelyWin")
			if old.homeGoals > old.awayGoals then
				assert(new.homeGoals > new.awayGoals, ("seed %d %s: a won match 2 became %d-%d"):format(seed, tactic, new.homeGoals, new.awayGoals))
			end
		end
	end
end

function T.resimIsDeterministicAndTooLateIsANoOp()
	local _, a = resim(9, 20, "Attack")
	local _, b = resim(9, 20, "Attack")
	assert(a.homeGoals == b.homeGoals and a.awayGoals == b.awayGoals and #a.events == #b.events, "same seed gave different results")
	for seed = 1, 40 do
		local old, new, kept = resim(seed, 86, "Attack")
		assert(kept == #old.events and #new.events == #old.events, "nothing fits after 86'")
	end
end

function T.lockCoversThePresentersLead()
	-- the presenter starts a build-up 4.5 s before the chance; a chance inside
	-- that lead may already be on the pitch
	assert(LOCK >= 5 and LOCK <= 8, "lock at 90 s is " .. LOCK)
	assert(MatchSim.lockMinutes(30) > LOCK, "a shorter match locks more football minutes")
end

return T
