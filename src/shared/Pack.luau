--!strict
-- The rules of a scout pack, with no server state in them: the three cards of
-- the latest report, the one card the player has pinned to come back to, and
-- the free signing from the match-1 trialist pack. ClubService owns a State
-- and saves it; everything here is pure so it can be tested.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Squad = require(ReplicatedStorage.Shared.Squad)

local Pack = {}

export type State = {
	shortlist: { Squad.Prospect },
	pinned: Squad.Prospect?,
	free: boolean, -- one card of this report can be kept for nothing
	revealed: boolean, -- the cards have been turned over once already
	-- P6 (#19): the ids this report was rolled with, and the cards signed out of
	-- it, so a signed or pinned card keeps its slot instead of the rest sliding
	-- over. Session only: a rejoin rebuilds `report` from the shortlist.
	report: { number }?,
	signed: { Squad.Prospect }?,
}

function Pack.find(state: State, id: number): (Squad.Prospect?, string?)
	for _, p in state.shortlist do
		if p.id == id then
			return p, "shortlist"
		end
	end
	local pinned = state.pinned
	if pinned and pinned.id == id then
		return pinned, "pinned"
	end
	return nil, nil
end

-- One slot: a new pin throws the old one away. The fee travels with the card,
-- so it is the fee he was quoted on the day.
function Pack.pin(state: State, id: number): boolean
	for i, p in state.shortlist do
		if p.id == id then
			table.remove(state.shortlist, i)
			state.pinned = p
			return true
		end
	end
	return false
end

function Pack.unpin(state: State): boolean
	if not state.pinned then
		return false
	end
	state.pinned = nil
	return true
end

function Pack.fee(state: State, prospect: Squad.Prospect): number
	if state.free and state.pinned ~= prospect then
		return 0
	end
	return prospect.fee
end

local function remember(state: State, p: Squad.Prospect)
	local signed = state.signed or {}
	table.insert(signed, p)
	state.signed = signed
end

function Pack.take(state: State, id: number): Squad.Prospect?
	local pinned = state.pinned
	if pinned and pinned.id == id then
		state.pinned = nil
		remember(state, pinned)
		return pinned
	end
	for i, p in state.shortlist do
		if p.id == id then
			table.remove(state.shortlist, i)
			state.free = false
			remember(state, p)
			return p
		end
	end
	return nil
end

-- A new report replaces the old one; unopened packs do not stack.
function Pack.replace(state: State, shortlist: { Squad.Prospect }, free: boolean)
	state.shortlist = shortlist
	state.free = free
	state.revealed = false
	state.report = Pack.ids(shortlist)
	state.signed = {}
end

function Pack.ids(cards: { any }): { number }
	local out = {}
	for _, p in cards do
		table.insert(out, p.id)
	end
	return out
end

export type Slot = { card: any, state: "open" | "pinned" | "signed", extra: boolean }

-- Where each card sits on the pack screen (P6, #19). Works on the published
-- club JSON as well as a State, so it only reads ids. The report's cards keep
-- their slots for good, worst first like the reveal: pinned ones glow in place
-- and signed ones stay, stamped. A card from an older report (the pin, or the
-- pin just signed) rides in a smaller extra slot at the end. A report card
-- thrown away by a newer pin has no slot any more.
function Pack.slots(shortlist: { any }, pinned: any?, signed: { any }?, report: { number }?): { Slot }
	local order = if report and #report > 0 then report else Pack.ids(shortlist)
	local inReport: { [number]: boolean } = {}
	for _, id in order do
		inReport[id] = true
	end
	local out: { Slot } = {}
	local function find(id: number): Slot?
		for _, p in shortlist do
			if p.id == id then
				return { card = p, state = "open", extra = false }
			end
		end
		if pinned and pinned.id == id then
			return { card = pinned, state = "pinned", extra = false }
		end
		for _, p in signed or {} do
			if p.id == id then
				return { card = p, state = "signed", extra = false }
			end
		end
		return nil
	end
	for _, id in order do
		local slot = find(id)
		if slot then
			table.insert(out, slot)
		end
	end
	table.sort(out, function(a, b)
		if a.card.overall ~= b.card.overall then
			return a.card.overall < b.card.overall
		end
		return a.card.id < b.card.id
	end)
	for _, p in signed or {} do
		if not inReport[p.id] then
			table.insert(out, { card = p, state = "signed", extra = true })
		end
	end
	if pinned and not inReport[pinned.id] then
		table.insert(out, { card = pinned, state = "pinned", extra = true })
	end
	return out
end

-- A new scout re-scouts at once, which throws the current report away. The one
-- report that must survive is the rigged trialist pack, where a card is still
-- free: losing it would cost the player his free signing.
function Pack.keepOnHire(state: State): boolean
	return state.free
end

function Pack.newSeason(state: State)
	state.pinned = nil -- TEMP: a pin lasts the season
end

return Pack
