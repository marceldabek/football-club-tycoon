--!strict
-- X323: nobody ever bid for your players. A footballer left only at the release
-- price (Squad.value, paid by nobody in particular) or in a same-server trade,
-- so the 19-year-old the scout found and the coach grew into an 80 was never a
-- windfall, and CLAUDE.md s11's trade-off - "spend £15,000 on a striker now, or
-- on seats" - had no selling side at all.
--
-- After a match, a club from a higher division can come in for one of your
-- better players. You accept the money or you keep the player. Everything here
-- is pure: ClubService decides when to ask, this decides what the offer is.
-- Tested in tests/BidsTest.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Squad = require(ReplicatedStorage.Shared.Squad)

local Bids = {}

-- TEMP tuning.
Bids.CHANCE = 0.22 -- per match, when there is anybody worth bidding for
Bids.MIN_OVERALL_OVER_DIVISION = 4 -- this far above the division's base strength
Bids.MIN_POTENTIAL_OVER_DIVISION = 12 -- or this much promise, at 23 or younger
Bids.YOUNG_AGE = 23
Bids.FEE_MIN, Bids.FEE_MAX = 1.25, 1.9 -- multiples of Squad.value
Bids.FEE_PER_TIER = 0.25 -- each division above you pays this much more again

export type Bid = {
	playerId: number,
	playerName: string,
	club: string,
	tier: number, -- the bidder's division (1 = Sunday Parks)
	fee: number,
	round: number, -- the matchday the approach came in
}

-- Everyone a bigger club would actually want: good enough for a division above,
-- or young with a ceiling well above it.
function Bids.candidates(players: { Squad.Player }, tier: number): { Squad.Player }
	local division = Config.Divisions[math.clamp(tier, 1, #Config.Divisions)]
	local base = division.baseStrength
	local out: { Squad.Player } = {}
	for _, p in players do
		local good = p.overall >= base + Bids.MIN_OVERALL_OVER_DIVISION
		local promising = p.age <= Bids.YOUNG_AGE and p.potential >= base + Bids.MIN_POTENTIAL_OVER_DIVISION
		if good or promising then
			table.insert(out, p)
		end
	end
	return out
end

-- The best of them, so an approach always reads as "somebody wants your man"
-- rather than a random name: highest overall, then highest potential.
local function pick(candidates: { Squad.Player }, rng: Random): Squad.Player?
	if #candidates == 0 then
		return nil
	end
	local sorted = table.clone(candidates)
	table.sort(sorted, function(a, b)
		if a.overall ~= b.overall then
			return a.overall > b.overall
		end
		if a.potential ~= b.potential then
			return a.potential > b.potential
		end
		return a.id < b.id
	end)
	-- usually the best, sometimes the second or third, so it is not always the
	-- same player being asked after
	local reach = math.min(#sorted, 3)
	local weights = { 0.6, 0.3, 0.1 }
	local roll = rng:NextNumber()
	local acc = 0
	for i = 1, reach do
		acc += weights[i]
		if roll <= acc or i == reach then
			return sorted[i]
		end
	end
	return sorted[1]
end

-- A club from a division above, by name, so the approach means something.
function Bids.bidder(tier: number, rng: Random): (string, number)
	local top = #Config.Divisions
	local above = math.min(tier + rng:NextInteger(1, 2), top)
	if above <= tier then
		above = math.min(tier + 1, top)
	end
	local pool = Config.Clubs[above]
	if not pool or #pool == 0 then
		return "a club from a higher division", above
	end
	return pool[rng:NextInteger(1, #pool)].name, above
end

function Bids.fee(player: Squad.Player, fromTier: number, ourTier: number, rng: Random): number
	local step = math.max(fromTier - ourTier, 0)
	local multiple = Bids.FEE_MIN + rng:NextNumber() * (Bids.FEE_MAX - Bids.FEE_MIN) + step * Bids.FEE_PER_TIER
	return math.max(math.floor(Squad.value(player) * multiple / 50) * 50, 150)
end

-- The approach after a match, or nil for "nobody came in this week". `seed`
-- keeps it deterministic for a given club and matchday.
function Bids.after(players: { Squad.Player }, tier: number, round: number, seed: number): Bid?
	local rng = Random.new(seed)
	if rng:NextNumber() > Bids.CHANCE then
		return nil
	end
	local player = pick(Bids.candidates(players, tier), rng)
	if not player then
		return nil
	end
	local club, fromTier = Bids.bidder(tier, rng)
	return {
		playerId = player.id,
		playerName = player.name,
		club = club,
		tier = fromTier,
		fee = Bids.fee(player, fromTier, tier, rng),
		round = round,
	}
end

-- Whether the club is allowed to take the money: the same rules as selling by
-- hand, so a bid can never leave a squad that cannot field a team.
function Bids.blocker(players: { Squad.Player }, playerId: number, inXi: boolean): string?
	local player: Squad.Player? = nil
	for _, p in players do
		if p.id == playerId then
			player = p
		end
	end
	if not player then
		return "That player has already gone."
	end
	if #players <= Config.SquadMin then
		return ("Squad cannot go below %d players"):format(Config.SquadMin)
	end
	if inXi then
		return "Take them out of the XI first"
	end
	if (player :: Squad.Player).role == "GK" then
		local keepers = 0
		for _, p in players do
			if p.role == "GK" then
				keepers += 1
			end
		end
		if keepers <= 1 then
			return "Keep at least one goalkeeper"
		end
	end
	return nil
end

-- A bid stands until the next match is played.
function Bids.isStale(bid: Bid?, round: number): boolean
	return bid ~= nil and round > bid.round
end

return Bids
