--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Finance = require(ReplicatedStorage.Shared.Finance)

local T = {}

function T.incomeAndSpendAreKeptApart()
	local l = Finance.new()
	Finance.record(l, "gate", 6952)
	Finance.record(l, "concessions", 1738)
	Finance.record(l, "stands", -1500)
	Finance.record(l, "transfers", -3000)
	assert(l.income.gate == 6952, "gate")
	assert(l.spend.stands == 1500, "spend is stored positive")
	assert(Finance.totalIncome(l) == 6952 + 1738, "income total")
	assert(Finance.totalSpend(l) == 4500, "spend total")
end

function T.unknownCategoriesAreIgnoredNotFatal()
	local l = Finance.new()
	Finance.record(l, "mystery", 500)
	Finance.record(l, "gate", 0)
	Finance.record(l, "gate", 0 / 0)
	assert(Finance.totalIncome(l) == 0 and Finance.totalSpend(l) == 0, "nothing should have been recorded")
	assert(l.income.mystery == nil, "an unknown category is not stored")
end

function T.matchRowsKeepTheLastFew()
	local l = Finance.new()
	for round = 1, Finance.MATCH_ROWS + 3 do
		Finance.recordMatch(l, { round = round, gate = round * 100, concessions = 10, bonus = 0, total = round * 110 })
	end
	assert(#l.matches == Finance.MATCH_ROWS, "the list is capped")
	assert(l.matches[1].round == 4, "the oldest rows drop off the front")
	assert(l.matches[#l.matches].round == Finance.MATCH_ROWS + 3, "the newest row is last")
end

function T.normalizeDropsRubbish()
	local l = Finance.normalize({
		income = { gate = 100.9, bonus = "lots", broken = 5 },
		spend = { staff = 800, transfers = -1 },
		matches = { { round = 2, gate = 50, concessions = 5, bonus = 0, total = 55 }, "nope" },
	})
	assert(l.income.gate == 100, "floored")
	assert(l.income.bonus == nil and l.income.broken == nil, "bad values and categories go")
	assert(l.spend.staff == 800 and l.spend.transfers == nil, "negative totals go")
	assert(#l.matches == 1, "only the real row survives")
	local empty = Finance.normalize(nil)
	assert(Finance.totalIncome(empty) == 0, "nil normalizes to an empty ledger")
end

function T.everyCategoryHasALabelInEitherList()
	for _, name in Finance.INCOME do
		assert(Finance.isIncome(name) and not Finance.isSpend(name), name .. " should be income only")
	end
	for _, name in Finance.SPEND do
		assert(Finance.isSpend(name) and not Finance.isIncome(name), name .. " should be spend only")
	end
end

return T
