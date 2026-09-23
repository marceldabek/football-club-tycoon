--!strict
-- Owns the club's football side: the persistent squad, the lineup (auto or
-- manual), the coach, the scout and the current shortlist. Publishes it all as
-- one JSON attribute (ClubState.Club) and handles the ClubAction remote.
-- Pure squad maths lives in Squad.luau; this module only holds state and rules.
-- The squad persists: Session restores it from the profile and serializes it back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Bids = require(ReplicatedStorage.Shared.Bids)
local Format = require(ReplicatedStorage.Shared.Format) -- X342
local Nations = require(ReplicatedStorage.Shared.Nations)
local Pack = require(ReplicatedStorage.Shared.Pack)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Trade = require(ReplicatedStorage.Shared.Trade)
local Telemetry = require(ReplicatedStorage.Shared.Telemetry)
local ClubState = require(script.Parent.ClubState)
local PlotContext = require(script.Parent.PlotContext)

local ClubService = {}

local players: { Squad.Player } = {}
local lineup: Squad.Lineup = { xi = {}, bench = {} }
local autoSquad = true
local coachLevel = 0
local scoutLevel = 0
-- the latest scout pack, the pinned card and the match-1 free signing (Shared/Pack)
local pack: Pack.State = { shortlist = {}, pinned = nil, free = false, revealed = false }
-- the match-1 trialist pack has been dealt (true for any save older than packs)
local trialDone = false
-- X323: the standing approach from a bigger club, if there is one. It arrives
-- after a match and lasts until the next one is played, and it is saved, so
-- rejoining mid-week does not quietly lose the offer.
local bid: Bids.Bid? = nil

-- X289: this season's academy intake, for the board outside the hut. Saved,
-- because otherwise a rejoin blanked the board and emptied the youth session
-- until the next rollover (review).
local academy: { string } = {}
-- X276: the list used to be re-rolled after every match, so a prospect the
-- player was saving up for vanished and the fee they were quoted never applied.
-- Marcel, 2026-09-21: a new report after every match again, but a card can be
-- pinned, which keeps the man and the fee he was quoted (Shared/Pack).
local nextId = 1
local rng = Random.new()

local money = Format.money -- X204, X342

-- X323 (review): the approach has to go when the man does - he can retire in
-- the season rollover, be traded, or be sold by hand - or the card advertises
-- somebody who is not in the squad and ACCEPT can never do anything.
local function dropBidIfGone()
	local standing = bid
	if not standing then
		return
	end
	for _, p in players do
		if p.id == standing.playerId then
			return
		end
	end
	bid = nil
	ClubState.set("BidNews", "")
end

-- X337: a prospect as the player is allowed to see him. The exact ceiling stays
-- here until he signs; the client gets the band his scout will commit to
-- (recomputed for a card saved before scouts had any doubt at all).
local function publishedProspect(p: Squad.Prospect): any
	local copy = table.clone(p) :: any
	local low, high = p.potentialLow, p.potentialHigh
	if type(low) ~= "number" or type(high) ~= "number" then
		low, high = Squad.potentialBand(p.potential, Squad.scoutDoubt(scoutLevel), p.id, p.overall)
	end
	copy.potentialLow, copy.potentialHigh = low, high
	copy.potential = nil
	-- what Sign will actually cost today (0 for the free trialist)
	copy.fee = Pack.fee(pack, p)
	return copy
end

local function publishedShortlist(): { any }
	local out = {}
	for _, p in pack.shortlist do
		table.insert(out, publishedProspect(p))
	end
	return out
end

local function publish()
	dropBidIfGone()
	ClubState.set("Club", HttpService:JSONEncode({
		players = players,
		lineup = lineup,
		autoSquad = autoSquad,
		coachLevel = coachLevel,
		scoutLevel = scoutLevel,
		shortlist = publishedShortlist(), -- X337
		pinned = if pack.pinned then publishedProspect(pack.pinned) else nil,
		packRevealed = pack.revealed,
		packFree = pack.free,
		bid = bid, -- X323
	}))
	ClubState.set("CoachLevel", coachLevel)
	ClubState.set("ScoutLevel", scoutLevel)
	ClubState.set("AutoSquad", autoSquad)
	ClubState.markDirty()
end

local function findPlayer(id: number): Squad.Player?
	for _, p in players do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function xiSlotOf(id: number): number?
	for slot, pid in lineup.xi do
		if pid == id then
			return slot
		end
	end
	return nil
end

local function benchIndexOf(id: number): number?
	for i, pid in lineup.bench do
		if pid == id then
			return i
		end
	end
	return nil
end

local function smallestFreeNumber(): number
	return Squad.freeNumber(players) -- one rule, shared with the academy (X277)
end

local function refreshShortlist()
	-- X214: no prospect shares a name with a current player (or the pin)
	local taken: { [string]: boolean } = {}
	for _, p in players do
		taken[p.name] = true
	end
	if pack.pinned then
		taken[pack.pinned.name] = true
	end
	local seed = rng:NextInteger(1, 1000000)
	if not trialDone then
		-- the pack after match 1: keep one of the three for nothing
		trialDone = true
		Pack.replace(pack, Squad.trialistPack(seed, players, lineup.xi, taken), true)
	else
		Pack.replace(pack, Squad.prospects(seed, Squad.average(players), scoutLevel, taken), false)
	end
	-- the folder on the office desk glows until it has been opened
	ClubState.set("ScoutReportNew", #pack.shortlist > 0)
end

-- Manual lineups can rot (injuries, releases). Fill or repair without
-- overriding the manager's healthy choices.
local function repairLineup()
	local inUse: { [number]: boolean } = {}
	local map = Squad.byId(players)
	for slot = 1, #Pitch.ROLES do
		local p = map[lineup.xi[slot]]
		if p and p.injured == 0 and not inUse[p.id] then
			inUse[p.id] = true
		else
			lineup.xi[slot] = nil :: any
		end
	end
	local newBench: { number } = {}
	for _, id in lineup.bench do
		local p = map[id]
		if p and p.injured == 0 and not inUse[id] and #newBench < Config.BenchSize then
			inUse[id] = true
			table.insert(newBench, id)
		end
	end
	lineup.bench = newBench

	-- X338: fill empty XI slots with the same picker Auto Squad uses, so a hole
	-- is never plugged with the reserve goalkeeper
	for slot = 1, #Pitch.ROLES do
		if not lineup.xi[slot] then
			-- nil when every fit player is already used: the slot stays empty and
			-- Squad.matchSquad puts a trialist there (the auto XI fallback here
			-- used to name a player already in the XI or on the bench)
			local id = Squad.fillSlot(players, slot, inUse, Squad.misjudgeFor(coachLevel)) -- X352
			if id then
				lineup.xi[slot] = id
				inUse[id] = true
			end
		end
	end
	-- X338: and top the bench up in rating order, like Auto Squad, because
	-- Squad.nextSub brings on the first name it can use
	for _, id in Squad.benchOrder(players, inUse, Squad.misjudgeFor(coachLevel)) do -- X352
		if #lineup.bench >= Config.BenchSize then
			break
		end
		inUse[id] = true
		table.insert(lineup.bench, id)
	end
end

local function recomputeLineup()
	if autoSquad then
		lineup = Squad.autoLineup(players, Squad.misjudgeFor(coachLevel)) -- X352
	else
		repairLineup()
	end
end

local VALID_ROLES: { [string]: boolean } = { GK = true, DEF = true, MID = true, FWD = true }

local function validPlayer(p: any): boolean
	if type(p) ~= "table" then
		return false
	end
	for _, key in { "id", "number", "age", "overall", "potential", "injured", "apps", "goals" } do
		if type(p[key]) ~= "number" then
			return false
		end
	end
	return type(p.name) == "string" and VALID_ROLES[p.role] == true
end

-- A saved card, repaired, or nil if the save was junk. Shared by the shortlist
-- and the pin so a pinned player cannot come back in a different shape.
local function restoredProspect(p: any): Squad.Prospect?
	if not (validPlayer(p) and type(p.fee) == "number") then
		return nil
	end
	local copy = table.clone(p)
	-- saves from before looks existed get a stable seed so faces stay put
	if type(copy.look) ~= "number" then
		copy.look = Squad.lookSeedFor(copy.id, copy.name)
	end
	-- and saves from before nationality get a stable home
	if type(copy.nation) ~= "string" then
		copy.nation = Nations.codeFor(copy.id, copy.name)
	end
	return copy
end

local function generateFresh()
	-- every club gets its own 16; the fixed Config.HomeSquadSeed is for tests
	players = Squad.generate(rng:NextInteger(1, 1000000), Config.StartingSquadOverall)
	nextId = #players + 1
	autoSquad = true
	coachLevel = 0
	scoutLevel = 0
	pack = { shortlist = {}, pinned = nil, free = false, revealed = false }
	trialDone = false
	academy = {} -- X289: a brand-new club has produced nobody yet
	-- X323 (review): the folder outlives the owner, so a new club has to clear
	-- the news as well as the offer, or it inherits a stranger's transfer story
	bid = nil
	ClubState.set("BidNews", "")
	lineup = { xi = {}, bench = {} }
	-- Review of X325: the intake is published on the restore path only, and
	-- ReplicatedStorage.Clubs.PlotN is found-or-created and never cleared, so a
	-- new player claiming a plot whose last owner had an intake saw that
	-- stranger's youngsters chalked on their board (and a youth session on
	-- pitch 2 for players they do not have). A fresh club publishes an empty
	-- one.
	ClubState.set("Academy", "[]")
	recomputeLineup()
end

-- nil = a brand-new club. Anything malformed falls back to a fresh squad
-- rather than a crash; the warning tells us the save was bad.
function ClubService.restore(data: any?)
	if data == nil then
		generateFresh()
		publish()
		return
	end
	local ok = type(data) == "table" and type(data.players) == "table" and #data.players >= 1
	if ok then
		for _, p in data.players do
			if not validPlayer(p) then
				ok = false
				break
			end
		end
	end
	if not ok then
		warn("[FCT] saved squad was invalid; generating a fresh one")
		generateFresh()
		publish()
		return
	end
	players = {}
	for _, p in data.players do
		local copy = table.clone(p)
		-- saves from before looks existed get a stable seed so faces stay put
		if type(copy.look) ~= "number" then
			copy.look = Squad.lookSeedFor(copy.id, copy.name)
		end
		-- and saves from before nationality get a stable home
		if type(copy.nation) ~= "string" then
			copy.nation = Nations.codeFor(copy.id, copy.name)
		end
		table.insert(players, copy)
	end
	local maxId = 0
	for _, p in players do
		maxId = math.max(maxId, p.id)
	end
	nextId = math.max(if type(data.nextId) == "number" then data.nextId else 0, maxId + 1)
	autoSquad = data.autoSquad ~= false
	coachLevel = math.clamp(if type(data.coachLevel) == "number" then data.coachLevel else 0, 0, #Config.CoachLevels - 1)
	scoutLevel = math.clamp(if type(data.scoutLevel) == "number" then data.scoutLevel else 0, 0, #Config.ScoutLevels)
	pack = { shortlist = {}, pinned = nil, free = data.packFree == true, revealed = data.packRevealed == true }
	-- a save from before packs has played its first match already
	trialDone = data.trialDone == true or ((ClubState.get("MatchesPlayed") :: number?) or 0) > 0
	-- X289 (review): the intake board and the youth session read this, so it has
	-- to come back with the save rather than blanking until the next rollover
	academy = {}
	if type(data.academy) == "table" then
		for _, line in data.academy do
			if type(line) == "string" then
				table.insert(academy, line)
			end
		end
	end
	ClubState.set("Academy", HttpService:JSONEncode(academy))
	-- X323: a standing approach, if the save was made between matches, and only
	-- if a match has not been played since (review)
	bid = nil
	ClubState.set("BidNews", "")
	local round = (ClubState.get("MatchesPlayed") :: number?) or 0
	if Bids.isValid(data.bid) and not Bids.isStale(data.bid, round) then
		bid = data.bid
		local b = bid :: Bids.Bid
		ClubState.set("BidNews", ("%s have come in for %s: %s."):format(b.club, b.playerName, money(b.fee)))
	end
	if type(data.shortlist) == "table" then
		for _, p in data.shortlist do
			local card = restoredProspect(p)
			if card then
				table.insert(pack.shortlist, card)
			end
		end
	end
	if type(data.pinned) == "table" then
		pack.pinned = restoredProspect(data.pinned)
	end
	local savedLineup = if type(data.lineup) == "table" then data.lineup else {}
	lineup = {
		xi = if type(savedLineup.xi) == "table" then Profile.unpackXi(savedLineup.xi) else {},
		bench = if type(savedLineup.bench) == "table" then table.clone(savedLineup.bench) else {},
	}
	recomputeLineup() -- auto: best XI; manual: repair anything stale
	publish()
end

function ClubService.serialize()
	return {
		players = players,
		lineup = { xi = Profile.packXi(lineup.xi), bench = lineup.bench },
		autoSquad = autoSquad,
		coachLevel = coachLevel,
		scoutLevel = scoutLevel,
		shortlist = pack.shortlist,
		pinned = pack.pinned,
		packFree = pack.free,
		packRevealed = pack.revealed,
		trialDone = trialDone,
		academy = academy,
		bid = bid, -- X323
		nextId = nextId,
	}
end

-- Wires the remote only; the squad arrives through restore().
function ClubService.init()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local action = remotes:FindFirstChild("ClubAction") :: RemoteEvent?
	if not action then
		action = Instance.new("RemoteEvent")
		action.Name = "ClubAction"
		action.Parent = remotes
	end
	local toast = remotes:FindFirstChild("Toast") :: RemoteEvent
	PlotContext.onRemote(action, function(player: Player, name: unknown, a: unknown, b: unknown)
		if type(name) ~= "string" then
			return
		end
		if not ClubState.isOwner(player) then
			if toast then
				toast:FireClient(player, "You're visiting this club. Only the owner can manage it.", false)
			end
			return
		end
		local ok, message = ClubService.act(name, a, b)
		if message and toast then
			toast:FireClient(player, message, ok)
		end
	end)
end

-- Why this player cannot leave right now, or nil. Shared by Release and by
-- signing into a full squad, so the two can never disagree.
local function releaseBlocker(p: Squad.Player): string?
	-- X363: the matchday squad, not Config.SquadMin - see Squad.matchdaySquadSize
	local floor = Squad.matchdaySquadSize()
	if #players <= floor then
		return ("You need %d players for an XI and a full bench"):format(floor)
	end
	if xiSlotOf(p.id) then
		-- X203: with Auto Squad on, swaps are refused, so say how to get there
		return if autoSquad then "Turn Auto Squad off, then take them out of the XI to sell" else "Take them out of the XI first"
	end
	-- X199: never sell the last goalkeeper (trades already require one)
	if p.role == "GK" then
		local keepers = 0
		for _, q in players do
			if q.role == "GK" then
				keepers += 1
			end
		end
		if keepers <= 1 then
			return "Keep at least one goalkeeper"
		end
	end
	return nil
end

local function removePlayer(p: Squad.Player): number
	for i, q in players do
		if q.id == p.id then
			table.remove(players, i)
			break
		end
	end
	local value = Squad.value(p)
	ClubState.addCash(value, "sales") -- X299
	return value
end

-- Every management action. Returns ok plus a message for a toast.
function ClubService.act(name: string, a: unknown, b: unknown): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Locked during matchday"
	end
	local cash = ClubState.get("Cash") :: number

	if name == "openReport" then
		ClubState.set("ScoutReportNew", false)
		return true, nil
	elseif name == "packRevealed" then
		if not pack.revealed then
			pack.revealed = true
			publish()
			Telemetry.event(ClubState.owner(), "PackRevealed") -- SL23
		end
		return true, nil
	elseif name == "pin" then
		local pid = tonumber(a)
		if not pid or not Pack.pin(pack, pid) then
			return false, "That player is no longer available"
		end
		publish()
		return true, ("%s pinned. His fee is held until the season ends."):format((pack.pinned :: Squad.Prospect).name)
	elseif name == "unpin" then
		if Pack.unpin(pack) then
			publish()
		end
		return true, nil
	elseif name == "setAutoSquad" then
		autoSquad = a == true
		recomputeLineup()
		publish()
		return true, if autoSquad then "Auto Squad on: the best XI is picked for you" else "Auto Squad off: tap two players to swap them"
	elseif name == "swap" then
		if autoSquad then
			return false, "Turn Auto Squad off to pick the team"
		end
		local idA, idB = tonumber(a), tonumber(b)
		if not idA or not idB or idA == idB then
			return false, "Pick two different players"
		end
		local pa, pb = findPlayer(idA), findPlayer(idB)
		if not pa or not pb then
			return false, "Unknown player"
		end
		local slotA, slotB = xiSlotOf(idA), xiSlotOf(idB)
		local benchA, benchB = benchIndexOf(idA), benchIndexOf(idB)
		if (slotA and pb.injured > 0) or (slotB and pa.injured > 0) then
			return false, "Injured players cannot start"
		end
		-- X230: kick-off would silently drop an injured substitute
		if (benchA and not slotB and not benchB and pb.injured > 0) or (benchB and not slotA and not benchA and pa.injured > 0) then
			return false, "Injured players can't be on the bench"
		end
		if slotA and slotB then
			lineup.xi[slotA], lineup.xi[slotB] = idB, idA
		elseif slotA or slotB then
			local slot = (slotA or slotB) :: number
			local starter, other = if slotA then pa else pb, if slotA then pb else pa
			local otherBench = if slotA then benchB else benchA
			lineup.xi[slot] = other.id
			if otherBench then
				lineup.bench[otherBench] = starter.id
			end
		elseif benchA or benchB then
			if benchA and benchB then
				lineup.bench[benchA], lineup.bench[benchB] = idB, idA
			else
				local idx = (benchA or benchB) :: number
				lineup.bench[idx] = if benchA then idB else idA
			end
		else
			return false, "Both players are already reserves"
		end
		publish()
		return true, ("Swapped %s and %s"):format(pa.name, pb.name)
	elseif name == "hireScout" or name == "upgradeScout" then
		local nextLevel = Config.ScoutLevels[scoutLevel + 1]
		if not nextLevel then
			return false, "Scouting is fully upgraded"
		end
		if (ClubState.get("MatchesPlayed") :: number) < 1 and scoutLevel == 0 then
			return false, "Play your first match before hiring a scout"
		end
		if cash < nextLevel.cost then
			return false, ("Need %s more"):format(money(nextLevel.cost - cash))
		end
		ClubState.addCash(-nextLevel.cost, "staff") -- X299 (review): scouting is staff
		-- X344: this line only existed in the place file. On disk the fee was
		-- taken and nothing happened: no scout, no prospects, and the button
		-- ready to charge again. It went missing when the addCash line above
		-- was rewritten (X307), and the tests never caught it because they run
		-- against Studio's copy (known bug 4).
		scoutLevel += 1
		-- a new scout files a report straight away, except over the free trialist
		-- pack: re-dealing that would quietly cost the player his free signing
		if Pack.keepOnHire(pack) then
			publish()
			return true, ("%s hired. His first report lands after your next match."):format(nextLevel.name)
		end
		refreshShortlist()
		publish()
		return true, ("%s hired. %d prospects found."):format(nextLevel.name, #pack.shortlist)
	elseif name == "hireCoach" or name == "upgradeCoach" then
		local nextLevel = Config.CoachLevels[coachLevel + 2]
		if not nextLevel then
			return false, "Coaching is fully upgraded"
		end
		if cash < nextLevel.cost then
			return false, ("Need %s more"):format(money(nextLevel.cost - cash))
		end
		ClubState.addCash(-nextLevel.cost, "staff") -- X299
		coachLevel += 1
		-- X352: the new coach picks the team again. Without this the XI he
		-- inherited stayed exactly as the old one had left it, so a Pro Coach
		-- changed nothing until the next squad change happened to trigger a
		-- recompute - which is what the live test showed.
		recomputeLineup()
		publish()
		return true, ("%s hired"):format(nextLevel.name)
	elseif name == "sign" then
		local pid = tonumber(a)
		local prospect = if pid then Pack.find(pack, pid) else nil
		if not prospect then
			return false, "That player is no longer available"
		end
		-- everything is checked before anything changes, so a failed signing
		-- can never cost the player the man he released to make room
		local leaving: Squad.Player? = nil
		if #players >= Config.SquadMax then
			local rid = tonumber(b)
			leaving = if rid then findPlayer(rid) else nil
			if not leaving then
				return false, ("Squad is full (%d). Release someone first."):format(Config.SquadMax)
			end
			local blocked = releaseBlocker(leaving)
			if blocked then
				return false, blocked
			end
		end
		local fee = Pack.fee(pack, prospect)
		local funds = cash + (if leaving then Squad.value(leaving) else 0)
		if funds < fee then
			return false, ("Need %s more"):format(money(fee - funds))
		end
		if leaving then
			removePlayer(leaving)
		end
		if fee > 0 then
			ClubState.addCash(-fee, "transfers") -- X299
		end
		Pack.take(pack, prospect.id)
		local signed: Squad.Player = {
			id = nextId,
			name = prospect.name,
			number = smallestFreeNumber(),
			role = prospect.role,
			age = prospect.age,
			overall = prospect.overall,
			potential = prospect.potential,
			injured = 0,
			apps = 0,
			goals = 0,
			look = prospect.look, -- X227: keep the face the pack showed
			nation = prospect.nation,
			wonderkid = prospect.wonderkid,
		}
		nextId += 1
		table.insert(players, signed)
		recomputeLineup()
		publish()
		Telemetry.event(ClubState.owner(), "PlayerSigned") -- SL23
		return true, ("%s signed! Shirt number %d."):format(signed.name, signed.number)
	elseif name == "acceptBid" or name == "declineBid" then
		-- X323
		local standing = bid
		if not standing then
			return false, "There is no offer on the table."
		end
		if name == "declineBid" then
			bid = nil
			ClubState.set("BidNews", "")
			publish()
			return true, ("%s turned down."):format(standing.club)
		end
		local blocker = Bids.blocker(players, standing.playerId)
		if blocker then
			-- review: an offer for somebody who has already gone must not stick
			-- around unanswerable
			dropBidIfGone()
			publish()
			return false, blocker
		end
		local sold: Squad.Player? = nil
		for i, q in players do
			if q.id == standing.playerId then
				sold = q
				table.remove(players, i)
				break
			end
		end
		bid = nil
		ClubState.set("BidNews", "")
		ClubState.addCash(standing.fee, "sales")
		recomputeLineup()
		publish()
		return true, ("%s sold to %s for %s"):format(
			if sold then sold.name else standing.playerName,
			standing.club,
			money(standing.fee)
		)
	elseif name == "release" then
		local pid = tonumber(a)
		local p = if pid then findPlayer(pid) else nil
		if not p then
			return false, "Unknown player"
		end
		local blocked = releaseBlocker(p)
		if blocked then
			return false, blocked
		end
		local value = removePlayer(p)
		recomputeLineup()
		publish()
		return true, ("%s sold for %s"):format(p.name, money(value))
	end
	return false, "Unknown action"
end

export type Prepared = { matchSquad: { Squad.MatchPlayer }, strength: number }

-- Called at kickoff: settles the XI and returns the matchday squad + strength.
function ClubService.prepareMatch(): Prepared
	recomputeLineup()
	publish()
	local coach = Config.CoachLevels[coachLevel + 1]
	return {
		matchSquad = Squad.matchSquad(players, lineup),
		strength = Squad.strength(players, lineup.xi) + coach.strengthBonus,
	}
end

-- Called after the final whistle. `scorerSlots` index into the matchSquad.
-- X334: `injuredId` is whoever the sim put down during the match, if anyone.
function ClubService.finishMatch(scorerSlots: { number }, matchSquad: { Squad.MatchPlayer }, subs: { Squad.Sub }?, conceded: number?, injuredId: number?): ({ string }, { Squad.RatingChange }, Squad.Award?)
	local scorerIds: { number } = {}
	for _, slot in scorerSlots do
		local p = matchSquad[slot]
		if p then
			table.insert(scorerIds, p.id)
		end
	end
	local subIds: { number } = {}
	for _, sub in subs or {} do
		local p = matchSquad[sub["in"]]
		if p then
			table.insert(subIds, p.id)
		end
	end
	-- X302: the award is picked before afterMatch's injuries and ratings move,
	-- so it is about the match that was just played
	local award = Squad.manOfTheMatch(players, lineup.xi, scorerIds, conceded or 0, matchSquad)
	local news, changes = Squad.afterMatch(players, lineup.xi, scorerIds, coachLevel, rng, subIds, injuredId)
	refreshShortlist() -- a new report after every match, scout or no scout
	recomputeLineup()
	publish()
	return news, changes, award
end

-- X323: after a match, a club from a higher division may come in for one of
-- your better players. The seed is the club and the matchday, so the same week
-- always brings the same approach (and a rejoin does not re-roll it).
--
-- X332: called by MatchService *after* it increments MatchesPlayed, not from
-- finishMatch. It used to run five lines earlier, so the offer was stamped with
-- the previous match number and `Bids.isStale` threw it away on the first
-- rejoin - the feature was switched off for anyone who reconnected mid-week.
function ClubService.considerBid()
	local round = (ClubState.get("MatchesPlayed") :: number?) or 0
	local tier = (ClubState.get("Tier") :: number?) or 1
	local name = (ClubState.get("ClubName") :: string?) or Config.ClubName
	local seed = round * 7919 + #name * 131 + string.byte(name) * 17 + tier
	bid = Bids.after(players, tier, round, seed)
	if bid then
		local b = bid :: Bids.Bid
		ClubState.set("BidNews", ("%s have come in for %s: %s."):format(b.club, b.playerName, money(b.fee)))
	else
		ClubState.set("BidNews", "")
	end
	publish()
end

-- New season housekeeping (Milestone 4 calls this).
-- Returns the season card's lists — who retired (X277), who came up to replace
-- them and who is back from injury (X367) — and the retired players themselves,
-- so the club can keep them in its history (X288).
function ClubService.newSeason(): ({ string }, { string }, { Squad.Player }, { string })
	Squad.ageAll(players)
	local retired = Squad.retireVeterans(players, rng)
	local recovered: { string } = {}
	for _, p in Squad.healAll(players) do
		table.insert(recovered, ("%s is fit again for the new season."):format(p.name))
	end
	local news: { string } = {}
	for _, p in retired do
		table.insert(news, ("%s retires at %d (%d app%s, %d goal%s)."):format(
			p.name,
			p.age,
			p.apps,
			if p.apps == 1 then "" else "s",
			p.goals,
			if p.goals == 1 then "" else "s"
		))
	end
	Pack.newSeason(pack) -- a pin only lasts the season
	-- Review of X277: a graduate used to be able to draw a name the club was
	-- still showing — the man retiring in the same breath, or a prospect on the
	-- shortlist (which now survives a season, X276).
	local spoken: { [string]: boolean } = {}
	for _, p in retired do
		spoken[p.name] = true
	end
	for _, p in pack.shortlist do
		spoken[p.name] = true
	end
	local arrivals: { string } = {}
	local graduates = Squad.promoteYouth(players, rng, nextId, spoken)
	nextId += #graduates
	local intake: { string } = {}
	for _, p in graduates do
		table.insert(arrivals, ("%s (%d) comes up from the academy, shirt %d."):format(p.name, p.age, p.number))
		-- X289: chalked on the board outside the academy hut
		table.insert(intake, ("%d  %s  (%d)"):format(p.number, p.name, p.age))
	end
	academy = intake
	ClubState.set("Academy", HttpService:JSONEncode(intake))
	recomputeLineup()
	publish()
	return news, arrivals, retired, recovered
end

function ClubService.coachLevel(): number
	return coachLevel
end

function ClubService.scoutLevel(): number
	return scoutLevel
end

function ClubService.squadAverage(): number
	return Squad.average(players)
end

-- X350: how many players are on the books, which is part of the wage bill
function ClubService.squadSize(): number
	return #players
end

-- X355: the strength of the XI as the match sim sees it, so a new season can
-- build its rivals around the club they are actually going to play. 0 for a
-- club that has no squad yet.
function ClubService.squadStrength(): number
	if #players == 0 then
		return 0
	end
	return Squad.strength(players, lineup.xi)
end

-- Trades (I4.1). A copy of the squad for validation; changing it changes nothing.
function ClubService.squadCopy(): { Squad.Player }
	local out = {}
	for _, p in players do
		table.insert(out, table.clone(p))
	end
	return out
end

-- Removes these players for a trade and returns them. Callers validate first
-- (Trade.validate); unknown ids are skipped.
function ClubService.tradeAway(ids: { number }): { Squad.Player }
	local gone: { Squad.Player } = {}
	for _, id in ids do
		for i, p in players do
			if p.id == id then
				table.insert(gone, table.remove(players, i) :: Squad.Player)
				break
			end
		end
	end
	recomputeLineup()
	publish()
	return gone
end

-- Adds traded-in players under fresh ids and the lowest free shirt numbers.
function ClubService.tradeIn(arrivals: { Squad.Player }): { Squad.Player }
	local incoming = table.clone(arrivals)
	local ids = {}
	for _, p in incoming do
		table.insert(ids, p.id)
	end
	local moved
	nextId, moved = Trade.move(ids, incoming :: any, players :: any, nextId)
	recomputeLineup()
	publish()
	return moved :: any
end

return ClubService
