--!strict
-- Hidden match simulation. Pure: no instances, no yielding, no presentation.
-- Given two strengths and a seed it returns a final score plus timestamped
-- GOAL events. The presentation layer only replays these events.

local MatchSim = {}

export type Event = {
	minute: number,
	team: "Home" | "Away",
	type: "GOAL",
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

	local events: { Event } = {}
	for _ = 1, homeGoals do
		table.insert(events, { minute = rng:NextInteger(1, 90), team = "Home" :: "Home", type = "GOAL" :: "GOAL" })
	end
	for _ = 1, awayGoals do
		table.insert(events, { minute = rng:NextInteger(1, 90), team = "Away" :: "Away", type = "GOAL" :: "GOAL" })
	end
	table.sort(events, function(a, b)
		return a.minute < b.minute
	end)

	return {
		homeGoals = homeGoals,
		awayGoals = awayGoals,
		events = events,
	}
end

return MatchSim
