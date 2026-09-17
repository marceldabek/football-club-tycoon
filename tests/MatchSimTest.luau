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

return T
