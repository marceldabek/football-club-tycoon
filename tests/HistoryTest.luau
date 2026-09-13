--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local History = require(ReplicatedStorage.Shared.History)

local T = {}

local function record(season: number, tier: number, position: number, outcome: string)
	return {
		season = season,
		tier = tier,
		division = "Div " .. tier,
		position = position,
		outcome = outcome,
		played = 10,
		won = 5,
		drawn = 2,
		lost = 3,
		gf = 15,
		ga = 10,
		points = 17,
		prize = 1000,
	}
end

function T.recordAppendsInOrder()
	local h = History.new()
	History.recordSeason(h, record(1, 1, 1, "Promoted"))
	History.recordSeason(h, record(2, 2, 4, "Stayed"))
	assert(#h.seasons == 2, "two records")
	assert(h.seasons[2].season == 2, "order kept")
end

function T.recordIsCopied()
	local h = History.new()
	local r = record(1, 1, 1, "Promoted")
	History.recordSeason(h, r)
	r.position = 6
	assert(h.seasons[1].position == 1, "stored record should be a copy")
end

function T.honoursCounts()
	local h = History.new()
	History.recordSeason(h, record(1, 1, 1, "Promoted"))
	History.recordSeason(h, record(2, 2, 5, "Relegated"))
	History.recordSeason(h, record(3, 1, 1, "Promoted"))
	History.recordSeason(h, record(4, 2, 3, "Stayed"))
	local honours = History.honours(h)
	assert(honours.seasons == 4, "seasons")
	assert(honours.titles == 2, "titles " .. honours.titles)
	assert(honours.promotions == 2, "promotions")
	assert(honours.relegations == 1, "relegations")
	assert(honours.bestTier == 2, "best tier")
end

function T.emptyHonours()
	local honours = History.honours(History.new())
	assert(honours.seasons == 0 and honours.titles == 0 and honours.bestTier == 0, "all zero")
end

return T
