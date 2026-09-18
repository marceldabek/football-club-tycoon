--!strict
-- Same-server player trades between two clubs (backlog I4.1, CLAUDE.md s27:
-- no cash gifts, cash only moves as part of a player trade, no anti-abuse
-- limits for now). Pure: offer validation, the pending-offer book, and moving
-- players between two squad lists. No Instances; TradeService does the rest.
--
-- TEMP rules (question logged for Marcel):
--   * up to MAX_PLAYERS_PER_SIDE players each way
--   * cash goes one way only, and only alongside at least one player
--   * both squads stay within Config.SquadMin..SquadMax and keep a goalkeeper
--   * an offer lasts OFFER_SECONDS; one outgoing offer per player
--   * traded players keep age, ratings, injuries, apps and goals, and get a
--     new id and the lowest free shirt number at the new club

local Trade = {}
local Format = require(game:GetService("ReplicatedStorage").Shared.Format) -- X342

Trade.MAX_PLAYERS_PER_SIDE = 3 -- TEMP
Trade.OFFER_SECONDS = 60 -- TEMP

export type Offer = {
	from: number, -- proposer userId
	to: number, -- receiver userId
	give: { number }, -- proposer's player ids going to the receiver
	take: { number }, -- receiver's player ids going to the proposer
	giveCash: number, -- proposer pays this to the receiver
	takeCash: number, -- receiver pays this to the proposer
	createdAt: number,
}

type SquadPlayer = { id: number, number: number, role: string, [string]: any }

export type Limits = { squadMin: number, squadMax: number }

local function byId(squad: { SquadPlayer }): { [number]: SquadPlayer }
	local map = {}
	for _, p in squad do
		map[p.id] = p
	end
	return map
end

local function goalkeepersLeft(squad: { SquadPlayer }, leaving: { [number]: boolean }, arriving: { SquadPlayer }): number
	local n = 0
	for _, p in squad do
		if p.role == "GK" and not leaving[p.id] then
			n += 1
		end
	end
	for _, p in arriving do
		if p.role == "GK" then
			n += 1
		end
	end
	return n
end

local function isWholeNonNegative(n: unknown): boolean
	return type(n) == "number" and n >= 0 and n == math.floor(n) and n < math.huge
end

-- Checks an offer against both clubs as they are right now. Returns false and
-- a player-facing reason when the trade can't happen.
function Trade.validate(
	offer: Offer,
	fromSquad: { SquadPlayer },
	toSquad: { SquadPlayer },
	fromCash: number,
	toCash: number,
	limits: Limits
): (boolean, string?)
	if offer.from == offer.to then
		return false, "You can't trade with yourself."
	end
	if type(offer.give) ~= "table" or type(offer.take) ~= "table" then
		return false, "That offer is incomplete."
	end
	if #offer.give == 0 and #offer.take == 0 then
		return false, "A trade needs at least one player. Cash can't be sent on its own."
	end
	if #offer.give > Trade.MAX_PLAYERS_PER_SIDE or #offer.take > Trade.MAX_PLAYERS_PER_SIDE then
		return false, ("Up to %d players each way."):format(Trade.MAX_PLAYERS_PER_SIDE)
	end
	if not isWholeNonNegative(offer.giveCash) or not isWholeNonNegative(offer.takeCash) then
		return false, "Cash must be a whole amount."
	end
	if offer.giveCash > 0 and offer.takeCash > 0 then
		return false, "Cash can only go one way in a trade."
	end
	if offer.giveCash > fromCash then
		return false, "The club paying can't afford that."
	end
	if offer.takeCash > toCash then
		return false, "The club paying can't afford that."
	end

	local fromMap, toMap = byId(fromSquad), byId(toSquad)
	local leavingFrom, leavingTo = {}, {}
	local arrivingTo, arrivingFrom = {}, {}
	for _, id in offer.give do
		local p = fromMap[id]
		if not p or leavingFrom[id] then
			return false, "One of those players isn't at the club any more."
		end
		leavingFrom[id] = true
		table.insert(arrivingTo, p)
	end
	for _, id in offer.take do
		local p = toMap[id]
		if not p or leavingTo[id] then
			return false, "One of those players isn't at the club any more."
		end
		leavingTo[id] = true
		table.insert(arrivingFrom, p)
	end

	local fromAfter = #fromSquad - #offer.give + #offer.take
	local toAfter = #toSquad - #offer.take + #offer.give
	if fromAfter < limits.squadMin or toAfter < limits.squadMin then
		return false, ("Both squads must keep at least %d players."):format(limits.squadMin)
	end
	if fromAfter > limits.squadMax or toAfter > limits.squadMax then
		return false, ("Squads are capped at %d players."):format(limits.squadMax)
	end
	if goalkeepersLeft(fromSquad, leavingFrom, arrivingFrom) < 1 or goalkeepersLeft(toSquad, leavingTo, arrivingTo) < 1 then
		return false, "Both clubs need to keep a goalkeeper."
	end
	return true
end

local function lowestFreeNumber(squad: { SquadPlayer }): number
	local used = {}
	for _, p in squad do
		used[p.number] = true
	end
	local n = 1
	while used[n] do
		n += 1
	end
	return n
end

-- Moves players out of `source` and into `dest`, giving each a fresh id from
-- `nextId` and the lowest free shirt number. Mutates both lists; returns the
-- next unused id for `dest` and the moved (new) player records.
function Trade.move(ids: { number }, source: { SquadPlayer }, dest: { SquadPlayer }, nextId: number): (number, { SquadPlayer })
	local moved = {}
	for _, id in ids do
		for i, p in source do
			if p.id == id then
				table.remove(source, i)
				local copy = table.clone(p)
				copy.id = nextId
				nextId += 1
				copy.number = lowestFreeNumber(dest)
				table.insert(dest, copy)
				table.insert(moved, copy)
				break
			end
		end
	end
	return nextId, moved
end

export type Book = {
	offers: { Offer },
	propose: (self: Book, offer: Offer, now: number) -> (boolean, string?),
	take: (self: Book, to: number, from: number, now: number) -> Offer?,
	expire: (self: Book, now: number) -> { Offer },
	dropUser: (self: Book, userId: number) -> { Offer },
}

local function removeWhere(list: { Offer }, predicate: (Offer) -> boolean): { Offer }
	local removed = {}
	for i = #list, 1, -1 do
		if predicate(list[i]) then
			table.insert(removed, 1, table.remove(list, i) :: Offer)
		end
	end
	return removed
end

function Trade.newBook(): Book
	local book: Book
	book = {
		offers = {},
		propose = function(self: Book, offer: Offer, now: number): (boolean, string?)
			self:expire(now)
			for _, o in self.offers do
				if o.from == offer.from then
					return false, "You already have a trade offer waiting for an answer."
				end
			end
			offer.createdAt = now
			table.insert(self.offers, offer)
			return true
		end,
		-- Removes and returns the offer from `from` to `to`, if still live.
		take = function(self: Book, to: number, from: number, now: number): Offer?
			self:expire(now)
			local found = removeWhere(self.offers, function(o)
				return o.to == to and o.from == from
			end)
			return found[1]
		end,
		expire = function(self: Book, now: number): { Offer }
			return removeWhere(self.offers, function(o)
				return now - o.createdAt >= Trade.OFFER_SECONDS
			end)
		end,
		dropUser = function(self: Book, userId: number): { Offer }
			return removeWhere(self.offers, function(o)
				return o.from == userId or o.to == userId
			end)
		end,
	}
	return book
end

-- Cash typed into the trade screen: "£1,500" / "1500" / "" -> 1500 / 1500 / 0.
-- Anything that isn't a whole non-negative amount is nil.
function Trade.parseCash(text: string): number?
	local cleaned = (string.gsub(text, "[£,%s]", ""))
	if cleaned == "" then
		return 0
	end
	if not string.match(cleaned, "^%d+$") or #cleaned > 9 then
		return nil
	end
	return tonumber(cleaned)
end

local money = Format.money -- X342

local function playerLine(p: { [string]: any }): string
	local injured = if type(p.injured) == "number" and p.injured > 0 then ", injured" else ""
	return ("%s (%s %d, age %d%s)"):format(tostring(p.name), tostring(p.role), p.overall or 0, p.age or 0, injured)
end

-- The lines the receiving owner reads on the offer card. `give`/`take` are the
-- proposer's point of view, as TradeService sends them.
function Trade.offerLines(data: { [string]: any }): { string }
	local lines = {}
	local function list(label: string, players: { any }?)
		if players and #players > 0 then
			local names = {}
			for _, p in players do
				table.insert(names, playerLine(p))
			end
			table.insert(lines, label .. table.concat(names, "; "))
		end
	end
	list("You get: ", data.give)
	list("You give: ", data.take)
	if type(data.giveCash) == "number" and data.giveCash > 0 then
		table.insert(lines, "They pay you " .. money(data.giveCash))
	elseif type(data.takeCash) == "number" and data.takeCash > 0 then
		table.insert(lines, "You pay them " .. money(data.takeCash))
	end
	return lines
end

return Trade
