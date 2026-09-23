--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pack = require(ReplicatedStorage.Shared.Pack)
local Squad = require(ReplicatedStorage.Shared.Squad)

local T = {}

local function fresh(free: boolean?): Pack.State
	local s: Pack.State = { shortlist = {}, pinned = nil, free = false, revealed = false }
	Pack.replace(s, Squad.prospects(9, 45, 1), free == true)
	return s
end

local function layout(s: Pack.State): { Pack.Slot }
	return Pack.slots(s.shortlist, s.pinned, s.signed, s.report)
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

function T.hiringAScoutKeepsOnlyTheFreePack()
	assert(Pack.keepOnHire(fresh(true)) == true, "the free trialist pack survives a hire")
	assert(Pack.keepOnHire(fresh(false)) == false, "an ordinary pack is re-dealt by a hire")
	local spent = fresh(true)
	Pack.take(spent, spent.shortlist[1].id) -- the free signing is used up
	assert(Pack.keepOnHire(spent) == false, "nothing left to protect once the free signing is spent")
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

-- P6 (#19a): signing or pinning a card must not slide the others along
function T.signedAndPinnedCardsKeepTheirSlots()
	local s = fresh()
	local before = layout(s)
	assert(#before == 3, "three slots")
	for i = 2, 3 do
		assert(before[i - 1].card.overall <= before[i].card.overall, "worst first, like the reveal")
	end
	Pack.take(s, before[2].card.id)
	Pack.pin(s, before[3].card.id)
	local after = layout(s)
	assert(#after == 3, "still three slots")
	for i = 1, 3 do
		assert(after[i].card.id == before[i].card.id, "slot " .. i .. " moved")
		assert(not after[i].extra, "report cards are never extras")
	end
	assert(after[1].state == "open" and after[2].state == "signed" and after[3].state == "pinned")
end

function T.anOlderPinRidesInTheExtraSlotEvenOnceSigned()
	local s = fresh()
	local old = s.shortlist[1]
	Pack.pin(s, old.id)
	Pack.replace(s, Squad.prospects(10, 45, 1), false)
	local slots = layout(s)
	assert(#slots == 4 and slots[4].card == old and slots[4].extra and slots[4].state == "pinned")
	Pack.take(s, old.id)
	slots = layout(s)
	assert(#slots == 4 and slots[4].card == old and slots[4].state == "signed", "a signed pin stays on screen")
	Pack.replace(s, Squad.prospects(11, 45, 1), false)
	assert(#layout(s) == 3, "a new report forgets the signings")
end

function T.aPinThrownAwayLosesItsSlot()
	local s = fresh()
	local a, b = s.shortlist[1], s.shortlist[2]
	Pack.pin(s, a.id)
	Pack.pin(s, b.id)
	local slots = layout(s)
	assert(#slots == 2, "the discarded pin is gone")
	for _, slot in slots do
		assert(slot.card ~= a)
	end
end

function T.noReportFallsBackToTheShortlist()
	-- a rejoin restores the shortlist without the session's report ids
	local s = fresh()
	assert(#Pack.slots(s.shortlist, nil, nil, nil) == 3)
	assert(#Pack.slots(s.shortlist, nil, nil, {}) == 3)
end

return T
