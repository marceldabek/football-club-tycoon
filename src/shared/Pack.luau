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

function Pack.take(state: State, id: number): Squad.Prospect?
	local pinned = state.pinned
	if pinned and pinned.id == id then
		state.pinned = nil
		return pinned
	end
	for i, p in state.shortlist do
		if p.id == id then
			table.remove(state.shortlist, i)
			state.free = false
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
end

function Pack.newSeason(state: State)
	state.pinned = nil -- TEMP: a pin lasts the season
end

return Pack
