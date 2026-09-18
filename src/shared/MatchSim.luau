--!strict
-- Hidden match simulation. Pure: no instances, no yielding, no presentation.
-- Given two strengths and a seed it returns a final score plus a timeline of
-- chances (GOAL / MISS / SAVE). The presentation layer only replays the
-- timeline; the score is authoritative regardless of what gets shown.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config) -- X334: the injury chance

local MatchSim = {}

-- X334: CLAUDE.md s22 puts injuries in the simulation layer, beside goals and
-- substitutions. They used to be rolled after the whistle inside
-- Squad.afterMatch, so nobody ever went down during a match and the first the
-- player heard of it was the post-match card.
export type EventType = "GOAL" | "MISS" | "SAVE"

export type Event = {
	minute: number,
	team: "Home" | "Away",
	type: EventType,
}

-- X334: one of ours going down, at a minute. It is kept out of `events` on
-- purpose: that list is the chance timeline the presenter replays shot by
-- shot, and it has its own spacing rules.
export type Injury = { minute: number, slot: number }

export type Result = {
	homeGoals: number,
	awayGoals: number,
	events: { Event },
	injury: Injury?, -- X334
}

export type Params = {
	playerIsAway: boolean?, -- X261: the reported side is the visitor
	homeStrength: number,
	awayStrength: number,
	seed: number?,
	-- Hidden onboarding bias. nil = fair sim.
	bias: ("NarrowWin" | "LikelyWin")?,
}

-- Goal expectancy. A flat home/(home+away) share barely moved with squad
-- quality -- a side rated 75 against a 44 division still only won half its
-- games -- so the ratio is raised to a power and the goals scale with it
-- rather than being split out of a fixed total. BASE_XG is what each side
-- expects when the two are level; the clamps stop a freak mismatch from
-- producing a cricket score.
local BASE_XG = 1.35
local STRENGTH_EXPONENT = 1.6
local MIN_XG, MAX_XG = 0.15, 5
-- Playing at your own ground is worth roughly three rating points.
local HOME_ADVANTAGE = 3

-- Minimum football minutes between two chances so their 3D sequences never
-- overlap (a sequence takes ~6 real seconds = ~6 minutes of a 90s match).
MatchSim.MIN_EVENT_GAP = 8
-- Chances live in two windows so nothing straddles the half-time break at 45':
-- first chance no earlier than 10' (kick-off needs a few seconds of open play
-- before a build-up, or the first shot is a slam from the centre circle),
-- nothing from 42' to 49' (build-up before / celebration after the whistle).
MatchSim.FIRST_HALF_LAST = 41
MatchSim.SECOND_HALF_FIRST = 50
local FIRST_MINUTE, LAST_MINUTE = 10, 88
-- 4 per half at the minimum gap.
MatchSim.MAX_CHANCES = math.floor((MatchSim.FIRST_HALF_LAST - FIRST_MINUTE) / MatchSim.MIN_EVENT_GAP)
	+ math.floor((LAST_MINUTE - MatchSim.SECOND_HALF_FIRST) / MatchSim.MIN_EVENT_GAP)

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

-- Picks `count` distinct minutes inside [first, last] with at least
-- MIN_EVENT_GAP between them, by spreading them over evenly sized windows and
-- jittering inside each.
local function pickMinutesIn(rng: Random, count: number, first: number, last: number): { number }
	local minutes = {}
	if count == 0 then
		return minutes
	end
	local span = last - first
	local window = span / count
	local jitter = math.max(math.floor(window - MatchSim.MIN_EVENT_GAP), 0)
	for i = 1, count do
		local windowStart = first + math.floor(window * (i - 1))
		table.insert(minutes, windowStart + rng:NextInteger(0, jitter))
	end
	return minutes
end

-- Splits the chances between the halves (the odd one lands randomly) and
-- keeps the half-time window clear.
local function pickMinutes(rng: Random, count: number): { number }
	local firstHalfMax = math.floor((MatchSim.FIRST_HALF_LAST - FIRST_MINUTE) / MatchSim.MIN_EVENT_GAP)
	local firstHalf = math.floor(count / 2)
	if count % 2 == 1 and rng:NextNumber() < 0.5 then
		firstHalf += 1
	end
	firstHalf = math.min(firstHalf, firstHalfMax)
	local secondHalf = count - firstHalf
	local minutes = pickMinutesIn(rng, firstHalf, FIRST_MINUTE, MatchSim.FIRST_HALF_LAST)
	for _, m in pickMinutesIn(rng, secondHalf, MatchSim.SECOND_HALF_FIRST, LAST_MINUTE) do
		table.insert(minutes, m)
	end
	return minutes
end

-- The timeline can only space MAX_CHANCES sequences at the minimum gap and
-- goals are never dropped, so a very high score is trimmed rather than let two
-- 3D sequences overlap. Rare at these expectancies. X229: goals come off both
-- sides together so the winner and the margin never change (trimming only the
-- leading side turned 5-4 into 3-4).
function MatchSim.trimGoals(homeGoals: number, awayGoals: number): (number, number)
	while homeGoals + awayGoals > MatchSim.MAX_CHANCES do
		if homeGoals > 0 and awayGoals > 0 then
			homeGoals -= 1
			awayGoals -= 1
		elseif homeGoals > 0 then
			homeGoals -= 1
		else
			awayGoals -= 1
		end
	end
	return homeGoals, awayGoals
end

function MatchSim.simulate(params: Params): Result
	-- X201: unseeded matches get their own random sequence (os.time() gave two
	-- clubs kicking off in the same second identical games)
	local rng = if params.seed then Random.new(params.seed) else Random.new()
	-- `homeStrength` is the side this result is reported for (its goals come back
	-- as homeGoals). X261: when that side is actually the visitor, the venue
	-- advantage belongs to the opponent instead, so a player's away fixtures are
	-- no longer played as if every match were at home.
	local us = math.max(params.homeStrength, 1)
	local them = math.max(params.awayStrength, 1)
	local edge
	if params.playerIsAway then
		edge = (us / math.max(them + HOME_ADVANTAGE, 1)) ^ STRENGTH_EXPONENT
	else
		edge = (math.max(us + HOME_ADVANTAGE, 1) / them) ^ STRENGTH_EXPONENT
	end

	local homeGoals = samplePoisson(rng, math.clamp(BASE_XG * edge, MIN_XG, MAX_XG))
	local awayGoals = samplePoisson(rng, math.clamp(BASE_XG / edge, MIN_XG, MAX_XG))

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

	homeGoals, awayGoals = MatchSim.trimGoals(homeGoals, awayGoals)

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
	for i = #chances, 1, -1 do
		if #chances <= MatchSim.MAX_CHANCES then
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

	-- X334: and at most one of ours goes down, at a minute, with the slot named
	-- so the match can bring somebody on for him. Keepers included: a keeper
	-- who limps off is a story, and the swap refuses it if the bench cannot.
	local injury: Injury? = nil
	if rng:NextNumber() < Config.MatchInjuryChance then
		injury = { minute = rng:NextInteger(8, 88), slot = rng:NextInteger(1, 11) }
	end

	return {
		homeGoals = homeGoals,
		awayGoals = awayGoals,
		events = events,
		injury = injury, -- X334
	}
end

return MatchSim
