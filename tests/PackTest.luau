--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pack = require(ReplicatedStorage.Shared.Pack)
local Squad = require(ReplicatedStorage.Shared.Squad)

local T = {}

local function fresh(free: boolean?): Pack.State
	return { shortlist = Squad.prospects(9, 45, 1), pinned = nil, free = free == true, revealed = false }
end

function T.pinMovesTheCardAndLocksTheFee()
	local s = fresh()
	local target = s.shortlist[2]
	local fee = target.fee
	assert(Pack.pin(s, target.id), "pin failed")
	assert(#s.shortlist == 2 and s.pinned == target, "card did not move")
	Pack.replace(s, Squad.prospects(10, 80, 5), false)
	assert(s.pinned == target and (s.pinned :: any).fee == fee, "pin lost or re-priced by a new report")
	assert(s.revealed == false, "a new report is unrevealed")
end

function T.secondPinReplacesTheFirst()
	local s = fresh()
	local a, b = s.shortlist[1], s.shortlist[2]
	Pack.pin(s, a.id)
	Pack.pin(s, b.id)
	assert(s.pinned == b, "second pin should win")
	assert(Pack.find(s, a.id) == nil, "the old pin is gone, not back in the pack")
end

function T.pinUnknownIdFails()
	local s = fresh()
	assert(Pack.pin(s, 12345) == false)
end

function T.freeSignIsOnceAndNeverThePin()
	local s = fresh(true)
	Pack.pin(s, s.shortlist[3].id)
	local pinned = s.pinned :: Squad.Prospect
	assert(Pack.fee(s, pinned) == pinned.fee, "the pin is never free")
	local card = s.shortlist[1]
	assert(Pack.fee(s, card) == 0, "first trialist is free")
	assert(Pack.take(s, card.id) == card)
	assert(s.free == false, "free signing spent")
	local other = s.shortlist[1]
	assert(Pack.fee(s, other) == other.fee, "second one costs")
end

function T.takeThePin()
	local s = fresh()
	local target = s.shortlist[1]
	Pack.pin(s, target.id)
	assert(Pack.take(s, target.id) == target and s.pinned == nil)
end

function T.newSeasonClearsThePin()
	local s = fresh()
	Pack.pin(s, s.shortlist[1].id)
	Pack.newSeason(s)
	assert(s.pinned == nil)
end

return T
