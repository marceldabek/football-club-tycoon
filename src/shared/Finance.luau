--!strict
-- X299: where the money went. Until now the only number in the game was the
-- current balance: the panel had five tabs and none of them was finance, so
-- after ten matches a player could not say whether the gate or the prize money
-- had paid for their stand, or how much the squad had cost them.
--
-- Pure and JSON-safe. ClubState owns the ledger and records into it from the
-- one place money moves (ClubState.addCash); the Finance tab reads it back.

local Finance = {}

-- Every way money moves. `gate`, `concessions`, `bonus`, `prize` and `sales`
-- are income; the rest is spend. Stored as positive totals either way, so the
-- tab can show them side by side.
-- `tradesIn` and `trades` are the two halves of the same thing: cash that came
-- in with a player trade, and cash that went out with one. They are separate
-- names because a category lives on one side of the ledger only.
Finance.INCOME = { "gate", "concessions", "bonus", "sponsor", "prize", "sales", "friendly", "tradesIn" }
Finance.SPEND = { "transfers", "stands", "amenities", "staff", "trades" }

-- `sponsor` (X309) is part of `total`, so the row adds up on screen (review)
export type MatchRow = { round: number, gate: number, concessions: number, bonus: number, sponsor: number, total: number }

export type Ledger = {
	income: { [string]: number },
	spend: { [string]: number },
	matches: { MatchRow }, -- the last few matchdays, newest last
}

-- TEMP: enough matchdays to see a trend without bloating the save.
Finance.MATCH_ROWS = 5

local function isIncome(category: string): boolean
	for _, name in Finance.INCOME do
		if name == category then
			return true
		end
	end
	return false
end
Finance.isIncome = isIncome

local function isSpend(category: string): boolean
	for _, name in Finance.SPEND do
		if name == category then
			return true
		end
	end
	return false
end
Finance.isSpend = isSpend

function Finance.new(): Ledger
	return { income = {}, spend = {}, matches = {} }
end

-- `amount` is signed the way the cash moved: +£ for income, -£ for spend. An
-- unknown category is ignored rather than fatal, so a new call site that
-- forgets to declare itself cannot corrupt the ledger.
function Finance.record(ledger: Ledger, category: string, amount: number)
	if amount == 0 or amount ~= amount then
		return
	end
	-- Review: `math.abs` alone would file a negative "income" as income. A
	-- movement whose sign disagrees with its category is dropped instead.
	local size = math.abs(amount)
	if isIncome(category) then
		if amount > 0 then
			ledger.income[category] = (ledger.income[category] or 0) + size
		end
	elseif isSpend(category) then
		if amount < 0 then
			ledger.spend[category] = (ledger.spend[category] or 0) + size
		end
	end
end

function Finance.recordMatch(ledger: Ledger, row: MatchRow)
	table.insert(ledger.matches, {
		round = row.round,
		gate = row.gate,
		concessions = row.concessions,
		bonus = row.bonus,
		sponsor = row.sponsor or 0,
		total = row.total,
	})
	while #ledger.matches > Finance.MATCH_ROWS do
		table.remove(ledger.matches, 1)
	end
end

function Finance.totalIncome(ledger: Ledger): number
	local total = 0
	for _, name in Finance.INCOME do
		total += ledger.income[name] or 0
	end
	return total
end

function Finance.totalSpend(ledger: Ledger): number
	local total = 0
	for _, name in Finance.SPEND do
		total += ledger.spend[name] or 0
	end
	return total
end

-- Drops anything that is not a finite number or a known category, so a save
-- written by an older build (or a corrupted one) loads instead of failing.
function Finance.normalize(raw: any): Ledger
	local out = Finance.new()
	if type(raw) ~= "table" then
		return out
	end
	local function copy(from: any, into: { [string]: number }, allowed: (string) -> boolean)
		if type(from) ~= "table" then
			return
		end
		for key, value in from do
			if type(key) == "string" and allowed(key) and type(value) == "number" and value == value and value >= 0 and value < math.huge then
				into[key] = math.floor(value)
			end
		end
	end
	copy(raw.income, out.income, isIncome)
	copy(raw.spend, out.spend, isSpend)
	if type(raw.matches) == "table" then
		for _, row in ipairs(raw.matches) do
			if type(row) == "table" and type(row.total) == "number" then
				Finance.recordMatch(out, {
					round = if type(row.round) == "number" then math.floor(row.round) else 0,
					gate = if type(row.gate) == "number" then math.floor(row.gate) else 0,
					concessions = if type(row.concessions) == "number" then math.floor(row.concessions) else 0,
					bonus = if type(row.bonus) == "number" then math.floor(row.bonus) else 0,
					sponsor = if type(row.sponsor) == "number" then math.floor(row.sponsor) else 0,
					total = math.floor(row.total),
				})
			end
		end
	end
	return out
end

return Finance
