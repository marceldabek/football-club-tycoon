--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Economy)
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

function T.demandGrowsWithTierPopularityAndAmenities()
	local base = Economy.demand(1, 20, 0)
	assert(base > 0, "no demand")
	assert(Economy.demand(2, 20, 0) > base, "higher tier should draw more")
	assert(Economy.demand(1, 60, 0) > base, "popularity should draw more")
	assert(Economy.demand(1, 20, 1) > base, "amenities should draw more")
	assert(Economy.demand(1, 200, 0) == Economy.demand(1, 100, 0), "popularity should clamp at 100")
	-- opening match: demand comfortably above the 150-seat bleachers, so fans get turned away
	assert(base > Config.StandLevels[1].capacity, "match 1 should turn fans away")
end

-- Milestone 4 built stands as the money sink, but demand leaned so hard on
-- popularity that a mid-table club's ground was never full, so expanding it
-- earned nothing and matchday income stopped growing.
function T.demandOutgrowsAMidTableGround()
	-- the ground a bottom-tier club actually has after a couple of seasons:
	-- Main Stands down both sides and behind one goal
	local built = Config.plotCapacity(Config.StandPlots[1], 2) * 2 + Config.plotCapacity(Config.StandPlots[3], 2)
	local mid = Economy.demand(1, 42, 3)
	assert(mid > built, ("demand %d should still beat a %d-seat ground"):format(mid, built))
end

function T.demandNeverCollapsesForAStrugglingClub()
	-- popularity 0 after a bad run should still fill the opening bleachers,
	-- or a losing streak locks the club out of its own economy
	assert(Economy.demand(1, 0, 0) > Config.StandLevels[1].capacity, "rock bottom should still beat the bleachers")
end

function T.bottomTierCannotFillAMaxedGround()
	-- there has to be a wrong amount to build, or capacity is a free money printer
	local maxed = 0
	for _, plot in Config.StandPlots do
		maxed += Config.plotCapacity(plot, #Config.StandLevels)
	end
	assert(Economy.demand(1, 100, #Config.AmenityLevels - 1) < maxed, "the bottom division should not fill a maxed ground")
end

function T.popularityClamps()
	assert(Economy.popularityAfter(99, "Win") == 100, "should clamp high")
	assert(Economy.popularityAfter(1, "Loss") == 0, "should clamp low")
	assert(Economy.popularityAfter(50, "Draw") == 51, "draw delta")
	assert(Economy.popularityAfter(50, "Nonsense") == 50, "unknown event should not move popularity")
end

function T.settleIncludesConcessions()
	local s = Economy.settle({
		homeGoals = 2, awayGoals = 1, capacity = 100, demand = 250, ticketPrice = 8,
		concessionPerFan = 2, winBonus = 400, drawBonus = 150, lossBonus = 0,
	})
	assert(s.attendance == 100 and s.turnedAway == 150, "attendance capped by capacity")
	assert(s.ticketRevenue == 800 and s.concessionRevenue == 200, "revenue wrong")
	assert(s.total == 1400 and s.outcome == "Win", "total / outcome wrong")
end

return T
