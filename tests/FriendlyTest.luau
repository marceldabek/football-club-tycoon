--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Friendly = require(ReplicatedStorage.Shared.Friendly)

local T = {}

function T.challengeAndAccept()
	local book = Friendly.new()
	assert(book:challenge(1, 2, 0, true, true), "challenge")
	assert(#book:incomingFor(2) == 1 and #book:incomingFor(1) == 0, "incoming")
	local invite = book:respond(2, 1, true, 10)
	assert(invite and invite.from == 1 and invite.to == 2, "accepted invite")
	assert(#book.invites == 0, "cleared")
end

function T.declineReturnsNothing()
	local book = Friendly.new()
	book:challenge(1, 2, 0, true, true)
	local invite, reason = book:respond(2, 1, false, 1)
	assert(invite == nil and reason == "declined", tostring(reason))
	assert(#book.invites == 0, "removed")
end

function T.refusals()
	local book = Friendly.new()
	assert(not book:challenge(1, 1, 0, true, true), "self")
	assert(not book:challenge(1, 2, 0, false, true), "challenger busy")
	assert(not book:challenge(1, 2, 0, true, false), "target busy")
	assert(book:challenge(1, 2, 0, true, true), "first")
	assert(not book:challenge(1, 3, 1, true, true), "one outgoing at a time")
	local ok, reason = book:challenge(2, 1, 1, true, true)
	assert(not ok and reason and reason:find("Answer"), "reverse invite points at the existing one")
	assert(book:challenge(3, 2, 1, true, true), "someone else can also challenge 2")
end

function T.invitesExpire()
	local book = Friendly.new()
	book:challenge(1, 2, 0, true, true)
	assert(#book:expire(Friendly.INVITE_SECONDS - 1) == 0, "still live")
	local invite, reason = book:respond(2, 1, true, Friendly.INVITE_SECONDS)
	assert(invite == nil and reason and reason:find("expired"), "expired on answer")
	assert(book:challenge(1, 2, Friendly.INVITE_SECONDS, true, true), "can challenge again after expiry")
end

function T.acceptClearsOtherInvitesOfBothClubs()
	local book = Friendly.new()
	book:challenge(1, 2, 0, true, true)
	book:challenge(3, 2, 0, true, true)
	book:challenge(4, 1, 0, true, true)
	assert(book:respond(2, 1, true, 1), "accept 1 vs 2")
	assert(#book.invites == 0, "3->2 and 4->1 are gone")
end

function T.dropUserOnLeave()
	local book = Friendly.new()
	book:challenge(1, 2, 0, true, true)
	book:challenge(3, 4, 0, true, true)
	local dropped = book:dropUser(2)
	assert(#dropped == 1 and dropped[1].from == 1, "dropped the one involving 2")
	assert(#book.invites == 1, "other stays")
end

function T.homePayoutIsShareOfGate()
	assert(Friendly.homePayout(150, 2450, 8) == math.floor(150 * 8 * Friendly.PAYOUT_SHARE), "capped by capacity")
	assert(Friendly.homePayout(900, 100, 8) == math.floor(100 * 8 * Friendly.PAYOUT_SHARE), "capped by demand")
	assert(Friendly.homePayout(0, 0, 8) == 0, "empty")
end

return T
