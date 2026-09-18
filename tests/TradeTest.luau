--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trade = require(ReplicatedStorage.Shared.Trade)

local T = {}

local LIMITS = { squadMin = 3, squadMax = 6 }

-- ids start at `base`; the first player is the goalkeeper
local function squad(base: number, size: number, keepers: number?): { any }
	local out = {}
	for i = 1, size do
		table.insert(out, {
			id = base + i,
			number = i,
			role = if i <= (keepers or 1) then "GK" else "MID",
			name = "P" .. (base + i),
			overall = 50,
			goals = i,
		})
	end
	return out
end

local function offer(give: { number }, take: { number }, giveCash: number?, takeCash: number?): Trade.Offer
	return { from = 1, to = 2, give = give, take = take, giveCash = giveCash or 0, takeCash = takeCash or 0, createdAt = 0 }
end

function T.simpleSwapIsValid()
	local ok, reason = Trade.validate(offer({ 12 }, { 22 }), squad(10, 4), squad(20, 4), 0, 0, LIMITS)
	assert(ok, reason)
end

function T.cashNeedsAPlayer()
	local ok, reason = Trade.validate(offer({}, {}, 500), squad(10, 4), squad(20, 4), 1000, 0, LIMITS)
	assert(not ok and reason and reason:find("at least one player"), reason)
	assert(Trade.validate(offer({}, { 22 }, 500), squad(10, 4), squad(20, 4), 1000, 0, LIMITS), "buy a player for cash")
end

function T.cashOneWayAndAffordable()
	assert(not Trade.validate(offer({ 12 }, { 22 }, 10, 10), squad(10, 4), squad(20, 4), 100, 100, LIMITS), "both pay")
	assert(not Trade.validate(offer({}, { 22 }, 500), squad(10, 4), squad(20, 4), 499, 0, LIMITS), "can't afford")
	assert(not Trade.validate(offer({ 12 }, {}, 0, 900), squad(10, 4), squad(20, 4), 0, 800, LIMITS), "receiver can't afford")
	assert(not Trade.validate(offer({ 12 }, {}, -5), squad(10, 4), squad(20, 4), 100, 0, LIMITS), "negative")
	assert(not Trade.validate(offer({ 12 }, {}, 1.5), squad(10, 4), squad(20, 4), 100, 0, LIMITS), "fraction")
end

function T.playersMustBelong()
	assert(not Trade.validate(offer({ 22 }, {}), squad(10, 4), squad(20, 4), 0, 0, LIMITS), "giving their player")
	assert(not Trade.validate(offer({ 12, 12 }, {}), squad(10, 4), squad(20, 4), 0, 0, LIMITS), "duplicate")
	assert(not Trade.validate(offer({}, { 99 }), squad(10, 4), squad(20, 4), 0, 0, LIMITS), "unknown")
end

function T.squadLimitsAndKeepers()
	-- proposer at the minimum can't give without taking back
	assert(not Trade.validate(offer({ 12 }, {}), squad(10, 3), squad(20, 4), 0, 0, LIMITS), "below min")
	-- receiver at the max can't take one more
	assert(not Trade.validate(offer({ 12 }, {}), squad(10, 4), squad(20, 6), 0, 0, LIMITS), "above max")
	-- giving away the only keeper
	local ok, reason = Trade.validate(offer({ 11 }, { 22 }), squad(10, 4), squad(20, 4), 0, 0, LIMITS)
	assert(not ok and reason and reason:find("goalkeeper"), reason)
	-- swapping keepers is fine
	assert(Trade.validate(offer({ 11 }, { 21 }), squad(10, 4), squad(20, 4), 0, 0, LIMITS), "keeper swap")
	-- a spare keeper can go
	assert(Trade.validate(offer({ 11 }, {}), squad(10, 4, 2), squad(20, 4), 0, 0, LIMITS), "second keeper")
end

function T.maxPlayersPerSide()
	local big = squad(10, 6)
	local ok = Trade.validate(offer({ 13, 14, 15, 16 }, {}), big, squad(20, 3), 0, 0, { squadMin = 1, squadMax = 10 })
	assert(not ok, "four is too many")
end

function T.moveReassignsIdsAndNumbers()
	local a, b = squad(10, 4), squad(20, 4)
	local nextId, moved = Trade.move({ 12 }, a, b, 25)
	assert(nextId == 26, "next id")
	assert(#a == 3 and #b == 5, "sizes")
	assert(moved[1].id == 25 and moved[1].number == 5 and moved[1].name == "P12" and moved[1].goals == 2, "copied with new id and number")
	for _, p in a do
		assert(p.id ~= 12, "gone from source")
	end
	-- a freed number is reused
	table.remove(b, 2) -- number 2 is free now
	local _, again = Trade.move({ 13 }, a, b, 26)
	assert(again[1].number == 2, "lowest free number")
end

function T.bookOneOutgoingAndExpiry()
	local book = Trade.newBook()
	assert(book:propose(offer({ 12 }, {}), 0), "first")
	assert(not book:propose(offer({ 13 }, {}), 1), "second outgoing refused")
	assert(book:take(2, 1, 10) ~= nil, "taken")
	assert(book:take(2, 1, 10) == nil, "only once")
	book:propose(offer({ 12 }, {}), 20)
	assert(book:take(2, 1, 20 + Trade.OFFER_SECONDS) == nil, "expired")
	book:propose(offer({ 12 }, {}), 200)
	assert(#book:dropUser(2) == 1 and #book.offers == 0, "dropped on leave")
end

function T.parseCash()
	assert(Trade.parseCash("") == 0, "empty is zero")
	assert(Trade.parseCash("1500") == 1500, "plain")
	assert(Trade.parseCash("£1,500") == 1500, "pound and comma")
	assert(Trade.parseCash(" 20 ") == 20, "spaces")
	assert(Trade.parseCash("-5") == nil, "negative")
	assert(Trade.parseCash("1.5") == nil, "fraction")
	assert(Trade.parseCash("abc") == nil, "text")
	assert(Trade.parseCash("9999999999") == nil, "too big")
end

function T.offerLinesFromReceiverView()
	local lines = Trade.offerLines({
		give = { { name = "Kit Lomax", role = "MID", overall = 54, age = 23, injured = 0 } },
		take = { { name = "Ezra Ings", role = "DEF", overall = 53, age = 21, injured = 2 } },
		giveCash = 2500,
		takeCash = 0,
	})
	assert(lines[1] == "You get: Kit Lomax (MID 54, age 23)", lines[1])
	assert(lines[2] == "You give: Ezra Ings (DEF 53, age 21, injured)", lines[2])
	assert(lines[3] == "They pay you £2,500", lines[3])
	local buy = Trade.offerLines({ give = {}, take = { { name = "A", role = "GK", overall = 40, age = 30 } }, giveCash = 0, takeCash = 900 })
	assert(#buy == 2 and buy[1]:sub(1, 9) == "You give:" and buy[2] == "You pay them £900", table.concat(buy, " / "))
end

-- X363 ----------------------------------------------------------------------

function T.aTradeMayNotLeaveEitherClubShortOfABench()
	-- TradeService passes Squad.matchdaySquadSize() as the floor, so the rule
	-- is checked here with the real number rather than this file's LIMITS of 3
	local Squad = require(ReplicatedStorage.Shared.Squad)
	local Config = require(ReplicatedStorage.Shared.Config)
	local floor = Squad.matchdaySquadSize()
	assert(floor == 11 + Config.BenchSize, ("the floor should be an XI and a bench, got %d"):format(floor))
	local limits = { squadMin = floor, squadMax = Config.SquadMax }
	-- two out, one in leaves the seller a man short of a matchday
	local mine, theirs = squad(10, floor), squad(20, floor + 2)
	local ok, reason = Trade.validate(offer({ 12, 13 }, { 22 }), mine, theirs, 0, 0, limits)
	assert(not ok, "a trade that empties a bench place should be refused")
	assert(reason and reason:find(tostring(floor)), ("the refusal should say how many: %s"):format(tostring(reason)))
	-- and the same trade is fine once the seller has the depth for it
	assert(Trade.validate(offer({ 12, 13 }, { 22 }), squad(10, floor + 1), theirs, 0, 0, limits),
		"one man spare and the trade goes through")
end

return T
