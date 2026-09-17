--!strict
-- Local friendlies between two clubs on the same server (backlog I3.1,
-- CLAUDE.md s27: no injuries, small payout to the home club, no league effect).
-- Pure bookkeeping for challenges: who invited whom, expiry, and the payout.
-- No Instances; FriendlyService owns the remotes and starts the match.
--
-- TEMP rules (questions logged for Marcel):
--   * the challenged club is the home side (you challenge from their office)
--   * an invite lasts INVITE_SECONDS, one outgoing invite per player
--   * home payout = PAYOUT_SHARE of a full league gate at that ground

local Friendly = {}

Friendly.INVITE_SECONDS = 45 -- TEMP
Friendly.PAYOUT_SHARE = 0.25 -- TEMP

export type Invite = { from: number, to: number, createdAt: number }

export type Book = {
	invites: { Invite },
	challenge: (self: Book, from: number, to: number, now: number, fromIdle: boolean, toIdle: boolean) -> (boolean, string?),
	respond: (self: Book, to: number, from: number, accept: boolean, now: number) -> (Invite?, string?),
	expire: (self: Book, now: number) -> { Invite },
	dropUser: (self: Book, userId: number) -> { Invite },
	incomingFor: (self: Book, userId: number) -> { Invite },
}

local function removeWhere(list: { Invite }, predicate: (Invite) -> boolean): { Invite }
	local removed = {}
	for i = #list, 1, -1 do
		if predicate(list[i]) then
			table.insert(removed, 1, table.remove(list, i) :: Invite)
		end
	end
	return removed
end

local function challenge(self: Book, from: number, to: number, now: number, fromIdle: boolean, toIdle: boolean): (boolean, string?)
	if from == to then
		return false, "You can't play a friendly against yourself."
	end
	if not fromIdle then
		return false, "Finish your current match first."
	end
	if not toIdle then
		return false, "That club is busy with a match."
	end
	self:expire(now)
	for _, invite in self.invites do
		if invite.from == from then
			return false, "You already have a challenge waiting for an answer."
		end
		if invite.from == to and invite.to == from then
			return false, "They've already challenged you. Answer their invite."
		end
	end
	table.insert(self.invites, { from = from, to = to, createdAt = now })
	return true
end

-- Accept or decline. Returns the invite when accepted.
local function respond(self: Book, to: number, from: number, accept: boolean, now: number): (Invite?, string?)
	self:expire(now)
	local found = removeWhere(self.invites, function(invite)
		return invite.to == to and invite.from == from
	end)
	local invite = found[1]
	if not invite then
		return nil, "That challenge has expired."
	end
	if not accept then
		return nil, "declined"
	end
	-- accepting settles everything else either side had pending
	removeWhere(self.invites, function(other)
		return other.from == from or other.to == from or other.from == to or other.to == to
	end)
	return invite
end

local function expire(self: Book, now: number): { Invite }
	return removeWhere(self.invites, function(invite)
		return now - invite.createdAt >= Friendly.INVITE_SECONDS
	end)
end

local function dropUser(self: Book, userId: number): { Invite }
	return removeWhere(self.invites, function(invite)
		return invite.from == userId or invite.to == userId
	end)
end

local function incomingFor(self: Book, userId: number): { Invite }
	local out = {}
	for _, invite in self.invites do
		if invite.to == userId then
			table.insert(out, invite)
		end
	end
	return out
end

function Friendly.new(): Book
	return {
		invites = {},
		challenge = challenge,
		respond = respond,
		expire = expire,
		dropUser = dropUser,
		incomingFor = incomingFor,
	}
end

-- What the home club earns: a share of a full league gate at its ground.
function Friendly.homePayout(capacity: number, demand: number, ticketPrice: number): number
	local gate = math.max(0, math.min(capacity, demand)) * ticketPrice
	return math.floor(gate * Friendly.PAYOUT_SHARE)
end

return Friendly
