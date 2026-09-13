--!strict
-- Hidden match simulation. Pure: no instances, no yielding, no presentation.
-- Given two strengths and a seed it returns a final score plus a timeline of
-- chances (GOAL / MISS / SAVE). The presentation layer only replays the
-- timeline; the score is authoritative regardless of what gets shown.

local MatchSim = {}

export type EventType = "GOAL" | "MISS" | "SAVE"

export type Event = {
	minute: number,
	team: "Home" | "Away",
	type: EventType,
}

export type Result = {
	homeGoals: number,
	awayGoals: number,
	events: { Event },
}

export type Params = {
	homeStrength: number,
	awayStrength: number,
	seed: number?,
	-- Hidden onboarding bias. nil = fair sim.
	bias: ("NarrowWin" | "LikelyWin")?,
}

-- Expected total goals per match before strength weighting.
local TOTAL_XG = 2.6

-- Minimum football minutes between two chances so their 3D sequences never
-- overlap (a sequence takes ~6 real seconds = ~6 minutes of a 90s match).
MatchSim.MIN_EVENT_GAP = 8
local FIRST_MINUTE, LAST_MINUTE = 3, 88

-- Extra non-scoring chances per team, on top of goals.
local MIN_EXTRA_CHANCES, MAX_EXTRA_CHANCES = 2, 3

-- Knuth's Poisson sampler; fine for lambdas this small.
local function samplePoisson(rng: Random, lambda: number): number
	local limit = math.exp(-lambda)
	local k = 0
	local p = 1
	repeat
		k += 1
		p *= rng:NextNumber()
	until p <= limit
	return k - 1
end

-- Which bias to apply for the Nth match the club has played (1-based).
function MatchSim.biasForMatch(matchIndex: number): ("NarrowWin" | "LikelyWin")?
	if matchIndex == 1 then
		return "NarrowWin"
	elseif matchIndex == 2 then
		return "LikelyWin"
	end
	return nil
end

-- Picks `count` distinct minutes with at least MIN_EVENT_GAP between them.
-- Works by spreading the events over evenly sized windows and jittering inside.
local function pickMinutes(rng: Random, count: number): { number }
	local minutes = {}
	if count == 0 then
		return minutes
	end
	local span = LAST_MINUTE - FIRST_MINUTE
	local window = span / count
	local jitter = math.max(math.floor(window - MatchSim.MIN_EVENT_GAP), 0)
	for i = 1, count do
		local windowStart = FIRST_MINUTE + math.floor(window * (i - 1))
		table.insert(minutes, windowStart + rng:NextInteger(0, jitter))
	end
	return minutes
end

function MatchSim.simulate(params: Params): Result
	local rng = Random.new(params.seed or os.time())
	local home = math.max(params.homeStrength, 1)
	local away = math.max(params.awayStrength, 1)
	local homeShare = home / (home + away)

	local homeGoals = samplePoisson(rng, TOTAL_XG * homeShare)
	local awayGoals = samplePoisson(rng, TOTAL_XG * (1 - homeShare))

	if params.bias == "NarrowWin" then
		-- Match 1: always a one-goal win, never a blowout.
		if rng:NextNumber() < 0.5 then
			homeGoals, awayGoals = 1, 0
		else
			homeGoals, awayGoals = 2, 1
		end
	elseif params.bias == "LikelyWin" then
		-- Match 2: strong chance of a win, still allows the odd draw/loss.
		if homeGoals <= awayGoals and rng:NextNumber() < 0.85 then
			homeGoals = awayGoals + rng:NextInteger(1, 2)
		end
	end

	-- Build the chance list: every goal plus a few misses/saves per team.
	local chances: { { team: "Home" | "Away", type: EventType } } = {}
	local function addChances(team: "Home" | "Away", goals: number)
		for _ = 1, goals do
			table.insert(chances, { team = team, type = "GOAL" :: EventType })
		end
		for _ = 1, rng:NextInteger(MIN_EXTRA_CHANCES, MAX_EXTRA_CHANCES) do
			table.insert(chances, { team = team, type = (rng:NextNumber() < 0.5 and "MISS" or "SAVE") :: EventType })
		end
	end
	addChances("Home", homeGoals)
	addChances("Away", awayGoals)

	-- Shuffle so goals are not clumped at one end of the match.
	for i = #chances, 2, -1 do
		local j = rng:NextInteger(1, i)
		chances[i], chances[j] = chances[j], chances[i]
	end

	-- Never more chances than fit in the match with the minimum gap. Drop
	-- non-scoring chances first; goals are never dropped.
	local maxChances = math.floor((LAST_MINUTE - FIRST_MINUTE) / MatchSim.MIN_EVENT_GAP)
	for i = #chances, 1, -1 do
		if #chances <= maxChances then
			break
		end
		if chances[i].type ~= "GOAL" then
			table.remove(chances, i)
		end
	end

	local minutes = pickMinutes(rng, #chances)
	local events: { Event } = {}
	for i, chance in chances do
		table.insert(events, { minute = minutes[i], team = chance.team, type = chance.type })
	end

	return {
		homeGoals = homeGoals,
		awayGoals = awayGoals,
		events = events,
	}
end

return MatchSim
