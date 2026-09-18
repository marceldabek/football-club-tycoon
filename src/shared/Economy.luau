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
	total: number,
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
		total = ticketRevenue + concessionRevenue + bonus + sponsorFee,
		outcome = outcome,
	}
end

return Economy
