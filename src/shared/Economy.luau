--!strict
-- Pure matchday economy. No instances, no yielding.

local Economy = {}

export type Settlement = {
	demand: number,
	capacity: number,
	attendance: number,
	turnedAway: number,
	ticketRevenue: number,
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
	winBonus: number,
	drawBonus: number,
	lossBonus: number,
}

function Economy.settle(inputs: Inputs): Settlement
	local attendance = math.min(inputs.capacity, inputs.demand)
	local turnedAway = math.max(inputs.demand - inputs.capacity, 0)
	local ticketRevenue = attendance * inputs.ticketPrice

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
		resultBonus = bonus,
		total = ticketRevenue + bonus,
		outcome = outcome,
	}
end

return Economy
