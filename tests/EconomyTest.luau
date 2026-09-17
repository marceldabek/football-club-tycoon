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
		tier = 1, popularity = 0, sponsorSeed = 1,
	})
	assert(s.attendance == 100 and s.turnedAway == 150, "attendance capped by capacity")
	assert(s.ticketRevenue == 800 and s.concessionRevenue == 200, "revenue wrong")
	-- X309: the shirt sponsor's fee is part of the takings
	assert(s.sponsorFee == Economy.sponsorFee(1, 0), "the sponsor fee should be in the settlement")
	assert(s.total == 1400 + s.sponsorFee and s.outcome == "Win", "total / outcome wrong")
	assert(s.sponsorName ~= "", "the sponsor should be named")
end

-- X309: sponsorship is the second revenue CLAUDE.md s11 lists and it did not exist.
function T.sponsorFeeGrowsWithTheDivisionAndTheClub()
	local bottom = Economy.sponsorFee(1, 0)
	local knownBottom = Economy.sponsorFee(1, 100)
	local top = Economy.sponsorFee(5, 0)
	assert(bottom > 0, "even a Sunday league club has a sponsor")
	assert(knownBottom > bottom, "a better-known club is worth more")
	assert(top > bottom, "a higher division is worth more")
	assert(Economy.sponsorFee(1, 200) == knownBottom, "popularity past 100 should not keep paying")
	assert(bottom % 10 == 0 and top % 10 == 0, "fees are rounded to ten")
	-- the same seed always signs the same sponsor, and every seed names somebody
	assert(Economy.sponsorName(3) == Economy.sponsorName(3), "deterministic")
	for seed = 0, 12 do
		assert(#Economy.sponsorName(seed) > 0, "a seed should always name a sponsor")
	end
end


function T.formMovesDemandAndPopularityDrifts()
	-- X262: the same club with a good and a bad run should not draw the same gate
	local flat = Economy.demand(2, 100, 0, 0)
	local hot = Economy.demand(2, 100, 0, 6)
	local cold = Economy.demand(2, 100, 0, -6)
	assert(hot > flat and flat > cold, ("form should move demand: %d / %d / %d"):format(cold, flat, hot))
	-- and the cap holds, so a long run can't run away with it
	assert(Economy.demand(2, 100, 0, 40) == Economy.demand(2, 100, 0, 12), "form past the cap should stop moving demand")
	-- a maxed-out club drifts back toward its division's baseline at a season end
	local dropped = Economy.popularityAtSeasonEnd(100, 2)
	assert(dropped < 100 and dropped > Config.PopularityBaseline[2], ("100 should drift toward the baseline, got %d"):format(dropped))
	-- and a club below the baseline drifts up, not down
	assert(Economy.popularityAtSeasonEnd(10, 2) > 10, "below the baseline should drift up")
	-- the top flight keeps a higher floor than the bottom
	assert(Config.PopularityBaseline[5] > Config.PopularityBaseline[1], "baselines should rise with the division")
end

return T
