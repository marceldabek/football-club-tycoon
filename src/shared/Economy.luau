--!strict
-- Pure matchday economy: attendance demand, popularity and settlement.
-- No instances, no yielding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local League = require(ReplicatedStorage.Shared.League) -- X354: divisionFactor

local Economy = {}

export type Settlement = {
	demand: number,
	capacity: number,
	attendance: number,
	turnedAway: number,
	ticketRevenue: number,
	concessionRevenue: number,
	resultBonus: number,
	sponsorFee: number, -- X309
	sponsorName: string, -- X309: who paid it
	wages: number, -- X350: the squad's wages for this match
	upkeep: number, -- X350: keeping the coach and the scout
	costs: number, -- X350: wages + upkeep, what the matchday cost to put on
	income: number, -- X350: everything that came in
	total: number, -- income - costs, and it can be negative
	outcome: "Win" | "Draw" | "Loss",
}

export type Inputs = {
	homeGoals: number,
	awayGoals: number,
	capacity: number,
	demand: number,
	ticketPrice: number,
	concessionPerFan: number,
	winBonus: number,
	drawBonus: number,
	lossBonus: number,
	tier: number, -- X309: the sponsor pays more in a higher division
	popularity: number,
	sponsorSeed: number, -- which of Config.Sponsors signed the deal
	-- X350: what the club costs to run for one match
	squadAverage: number?, -- Squad.average across the whole squad
	squadSize: number?,
	coachLevel: number?,
	scoutLevel: number?,
}

-- Fans who want to come. Grows with the division, popularity and amenities.
-- Popularity is deliberately a modest modifier rather than the whole story:
-- when it carried a 0.5..1.5 range a mid-table club's demand sat below its own
-- capacity, so expanding the ground earned nothing and a losing run cut the
-- club off from the money it needed to stop losing.
-- `formNet` (X262) is this season's wins minus losses. Popularity is a slow
-- lifetime measure, so on its own it stopped saying anything once it capped;
-- the form term is what makes a run of results show up at the gate.
function Economy.demand(tier: number, popularity: number, amenityLevel: number, formNet: number?): number
	local division = Config.Divisions[tier] or Config.Divisions[1]
	local amenity = Config.AmenityLevels[amenityLevel + 1] or Config.AmenityLevels[1]
	local pop = math.clamp(popularity, 0, 100)
	local form = math.clamp((formNet or 0) * Config.FormDemandPerNet, -Config.FormDemandCap, Config.FormDemandCap)
	return math.floor(division.demandBase * (0.75 + pop / 60) * (1 + amenity.demandBonus) * (1 + form) + 0.5)
end

-- X262: at a season end popularity drifts toward the baseline for the division
-- the club is in now, so it can neither sit at 100 for ever nor collapse.
function Economy.popularityAtSeasonEnd(popularity: number, tier: number): number
	local baseline = Config.PopularityBaseline[tier] or Config.PopularityBaseline[#Config.PopularityBaseline]
	local drifted = popularity + (baseline - popularity) * Config.PopularitySeasonDrift
	return math.clamp(math.floor(drifted + 0.5), 0, 100)
end

-- Popularity after a result or season event. Clamped to 0..100.
function Economy.popularityAfter(popularity: number, event: string): number
	local delta = Config.PopularityDelta[event] or 0
	return math.clamp(popularity + delta, 0, 100)
end

-- X309: what the shirt sponsor pays for one match. Rounded to 10 so the
-- summary reads like a fee and not a calculation.
-- X354: the fee used to be `SponsorBase + SponsorPerTier * (tier - 1)`, which
-- runs 250..1,130 across the five divisions (4.5x) while the money a division
-- actually generates runs 1x..20x (demandBase 600..12,000). So the shirt was
-- worth about 6% of a Sunday Parks League gate and under 1% of a Premier
-- Division one, and the FINANCE tab quietly lost an income line as the club
-- climbed. It is a share of the division's own money now, exactly as X272 did
-- for prize money.
function Economy.sponsorFee(tier: number, popularity: number): number
	local known = 1 + Config.SponsorPopularityShare * math.clamp(popularity, 0, 100) / 100
	local base = Config.SponsorBase * League.divisionFactor(tier)
	return math.floor(base * known / 10 + 0.5) * 10
end

-- X350: the squad's wages for one match. A squad rated at its division's own
-- standard costs about a third of that division's matchday takings; paying for
-- a squad above the division costs sharply more (WageCurve), which is what
-- makes buying a promotion-ready squad a decision rather than a free win. A
-- smaller squad is cheaper, so releasing a reserve is worth something.
function Economy.wageBill(squadAverage: number, squadSize: number, tier: number): number
	local division = Config.Divisions[tier] or Config.Divisions[1]
	local standard = math.max(division.baseStrength, 1)
	local ratio = (math.max(squadAverage, 1) / standard) ^ Config.WageCurve
	local size = math.max(squadSize, 0) / Config.WageSquadSize
	local money = League.divisionFactor(tier) ^ Config.WageDivisionDamping
	local bill = Config.WageBase * money * ratio * size
	return math.floor(bill / 10 + 0.5) * 10
end

-- X350: what the staff cost to keep, per match: a share of what they cost to
-- hire. A Continental Network is a standing commitment, not a one-off.
function Economy.staffUpkeep(coachLevel: number, scoutLevel: number): number
	local coach = Config.CoachLevels[math.max(math.floor(coachLevel), 0) + 1]
	local scout = Config.ScoutLevels[math.floor(scoutLevel)]
	local paid = (if coach then coach.cost else 0) + (if scout then scout.cost else 0)
	return math.floor(paid * Config.StaffUpkeepShare / 10 + 0.5) * 10
end

-- X309: the same sponsor every match of a season, picked from the boards that
-- are already painted round the pitch.
function Economy.sponsorName(seed: number): string
	local list = Config.Sponsors
	local index = (math.floor(math.abs(seed)) % #list) + 1
	return list[index].text
end

function Economy.settle(inputs: Inputs): Settlement
	local attendance = math.min(inputs.capacity, inputs.demand)
	local turnedAway = math.max(inputs.demand - inputs.capacity, 0)
	local ticketRevenue = attendance * inputs.ticketPrice
	local concessionRevenue = attendance * inputs.concessionPerFan

	local outcome: "Win" | "Draw" | "Loss"
	local bonus
	if inputs.homeGoals > inputs.awayGoals then
		outcome, bonus = "Win", inputs.winBonus
	elseif inputs.homeGoals == inputs.awayGoals then
		outcome, bonus = "Draw", inputs.drawBonus
	else
		outcome, bonus = "Loss", inputs.lossBonus
	end

	local sponsorFee = Economy.sponsorFee(inputs.tier or 1, inputs.popularity or 0)
	local income = ticketRevenue + concessionRevenue + bonus + sponsorFee
	-- X350: and what it cost to put the match on
	local wages = Economy.wageBill(inputs.squadAverage or 0, inputs.squadSize or 0, inputs.tier or 1)
	local upkeep = Economy.staffUpkeep(inputs.coachLevel or 0, inputs.scoutLevel or 0)
	local costs = wages + upkeep
	return {
		demand = inputs.demand,
		capacity = inputs.capacity,
		attendance = attendance,
		turnedAway = turnedAway,
		ticketRevenue = ticketRevenue,
		concessionRevenue = concessionRevenue,
		resultBonus = bonus,
		sponsorFee = sponsorFee,
		sponsorName = Economy.sponsorName(inputs.sponsorSeed or 0),
		wages = wages,
		upkeep = upkeep,
		costs = costs,
		income = income,
		total = income - costs,
		outcome = outcome,
	}
end

return Economy
