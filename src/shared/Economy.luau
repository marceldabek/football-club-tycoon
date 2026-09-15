--!strict
-- Pure matchday economy: attendance demand, popularity and settlement.
-- No instances, no yielding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Economy = {}

export type Settlement = {
	demand: number,
	capacity: number,
	attendance: number,
	turnedAway: number,
	ticketRevenue: number,
	concessionRevenue: number,
	resultBonus: number,
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
}

-- Fans who want to come. Grows with the division, popularity and amenities.
-- Popularity is deliberately a modest modifier rather than the whole story:
-- when it carried a 0.5..1.5 range a mid-table club's demand sat below its own
-- capacity, so expanding the ground earned nothing and a losing run cut the
-- club off from the money it needed to stop losing.
function Economy.demand(tier: number, popularity: number, amenityLevel: number): number
	local division = Config.Divisions[tier] or Config.Divisions[1]
	local amenity = Config.AmenityLevels[amenityLevel + 1] or Config.AmenityLevels[1]
	local pop = math.clamp(popularity, 0, 100)
	return math.floor(division.demandBase * (0.75 + pop / 60) * (1 + amenity.demandBonus) + 0.5)
end

-- Popularity after a result or season event. Clamped to 0..100.
function Economy.popularityAfter(popularity: number, event: string): number
	local delta = Config.PopularityDelta[event] or 0
	return math.clamp(popularity + delta, 0, 100)
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

	return {
		demand = inputs.demand,
		capacity = inputs.capacity,
		attendance = attendance,
		turnedAway = turnedAway,
		ticketRevenue = ticketRevenue,
		concessionRevenue = concessionRevenue,
		resultBonus = bonus,
		total = ticketRevenue + concessionRevenue + bonus,
		outcome = outcome,
	}
end

return Economy
