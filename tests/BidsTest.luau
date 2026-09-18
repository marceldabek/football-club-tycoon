--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bids = require(ReplicatedStorage.Shared.Bids)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

local function player(id: number, overall: number, potential: number, age: number, role: string?): Squad.Player
	return {
		id = id,
		name = "Player " .. id,
		number = id,
		role = (role or "MID") :: any,
		age = age,
		overall = overall,
		potential = potential,
		injured = 0,
		apps = 10,
		goals = 1,
		look = id,
	}
end

-- a National League (tier 4, base 68) squad with one star and one prospect
local function squad(): { Squad.Player }
	local out = {}
	for i = 1, 16 do
		table.insert(out, player(i, 60, 64, 26))
	end
	out[3] = player(3, 78, 80, 27) -- well above the division
	out[7] = player(7, 64, 84, 20) -- young with a ceiling
	out[1] = player(1, 60, 64, 26, "GK")
	return out
end

function T.candidatesAreTheOnesABiggerClubWouldWant()
	local list = Bids.candidates(squad(), 4)
	local ids = {}
	for _, p in list do
		ids[p.id] = true
	end
	assert(ids[3], "a 78 in a 68-strength division should attract interest")
	assert(ids[7], "a 20-year-old with an 84 ceiling should attract interest")
	assert(not ids[5], "a run-of-the-mill 60 should not")
end

function T.nobodyWantsAnOrdinarySquad()
	local ordinary = {}
	for i = 1, 16 do
		table.insert(ordinary, player(i, 58, 60, 28))
	end
	assert(#Bids.candidates(ordinary, 4) == 0, "nobody in this squad is worth a bid")
	for seed = 1, 40 do
		assert(Bids.after(ordinary, 4, 3, seed) == nil, "no candidates means no approach, seed " .. seed)
	end
end

function T.approachesAreOccasionalNotEveryWeek()
	local players = squad()
	local came = 0
	for seed = 1, 200 do
		if Bids.after(players, 4, 3, seed) then
			came += 1
		end
	end
	assert(came > 10 and came < 90, ("about a fifth of weeks should bring a bid, got %d in 200"):format(came))
end

function T.theSameWeekAlwaysBringsTheSameBid()
	local players = squad()
	local seed = nil
	for s = 1, 200 do
		if Bids.after(players, 4, 3, s) then
			seed = s
			break
		end
	end
	assert(seed, "expected at least one bid in 200 seeds")
	local a = Bids.after(players, 4, 3, seed :: number) :: Bids.Bid
	local b = Bids.after(players, 4, 3, seed :: number) :: Bids.Bid
	assert(a.playerId == b.playerId and a.fee == b.fee and a.club == b.club, "the same seed must give the same approach")
end

function T.theBidIsForSomebodyWorthHaving()
	local players = squad()
	for seed = 1, 200 do
		local bid = Bids.after(players, 4, 3, seed)
		if bid then
			local wanted = false
			for _, p in Bids.candidates(players, 4) do
				if p.id == bid.playerId then
					wanted = true
				end
			end
			assert(wanted, "a bid should only ever be for a candidate, seed " .. seed)
		end
	end
end

function T.theFeeBeatsSellingThemYourself()
	local players = squad()
	local byId: { [number]: Squad.Player } = {}
	for _, p in players do
		byId[p.id] = p
	end
	local seen = 0
	for seed = 1, 200 do
		local bid = Bids.after(players, 4, 3, seed)
		if bid then
			seen += 1
			local value = Squad.value(byId[bid.playerId])
			assert(bid.fee > value, ("a bid (%d) should beat the release price (%d)"):format(bid.fee, value))
			assert(bid.fee <= value * 3, ("a bid (%d) should not be silly money against %d"):format(bid.fee, value))
		end
	end
	assert(seen > 0, "expected some bids")
end

function T.theBidderIsFromAHigherDivision()
	local players = squad()
	for seed = 1, 200 do
		local bid = Bids.after(players, 2, 3, seed)
		if bid then
			assert(bid.tier > 2, "the approach should come from above, got tier " .. bid.tier)
			assert(bid.tier <= #Config.Divisions, "and from a division that exists")
			local named = false
			for _, club in Config.Clubs[bid.tier] do
				if club.name == bid.club then
					named = true
				end
			end
			assert(named, "the bidder should be a real club from that division: " .. bid.club)
		end
	end
end

function T.theTopDivisionStillGetsApproaches()
	-- the Premier Division's base is 76, so it takes a better player than the
	-- National League squad above to turn a top-flight club's head
	local players = squad()
	players[3] = player(3, 86, 88, 26)
	local any = false
	for seed = 1, 200 do
		local bid = Bids.after(players, #Config.Divisions, 3, seed)
		if bid then
			any = true
			assert(bid.tier == #Config.Divisions, "at the top, the bid comes from your own division")
		end
	end
	assert(any, "the top division should still see approaches")
end

function T.sellingCannotBreakTheSquad()
	local players = squad()
	assert(Bids.blocker(players, 3, false) == nil, "a reserve can be sold")
	assert(Bids.blocker(players, 3, true) ~= nil, "not out of the starting XI")
	assert(Bids.blocker(players, 1, false) ~= nil, "not the last goalkeeper")
	assert(Bids.blocker(players, 999, false) ~= nil, "not somebody who has already gone")
	local thin = {}
	for i = 1, Config.SquadMin do
		table.insert(thin, player(i, 70, 74, 24))
	end
	assert(Bids.blocker(thin, 2, false) ~= nil, "not down to fewer than the minimum")
end

function T.aBidGoesStaleAtTheNextMatch()
	local bid: Bids.Bid = { playerId = 3, playerName = "x", club = "y", tier = 5, fee = 1000, round = 4 }
	assert(not Bids.isStale(bid, 4), "it stands on the matchday it arrived")
	assert(Bids.isStale(bid, 5), "and is gone once the next match is played")
	assert(not Bids.isStale(nil, 9), "no bid is not a stale bid")
end

return T
