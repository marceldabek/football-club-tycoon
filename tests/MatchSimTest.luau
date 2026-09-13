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
			assert(ev.minute >= 3 and ev.minute <= 88, "event minute out of range: " .. ev.minute)
		end
	end
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

return T
