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
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Trade = require(ReplicatedStorage.Shared.Trade)
local ClubState = require(script.Parent.ClubState)
local PlotContext = require(script.Parent.PlotContext)

local ClubService = {}

local players: { Squad.Player } = {}
local lineup: Squad.Lineup = { xi = {}, bench = {} }
local autoSquad = true
local coachLevel = 0
local scoutLevel = 0
local shortlist: { Squad.Prospect } = {}
-- X276: the list used to be re-rolled after every match, so a prospect the
-- player was saving up for vanished and the fee they were quoted never applied.
-- It now survives and is only re-scouted every few matches. TEMP number.
local SHORTLIST_MATCHES = 4
local shortlistAge = 0 -- matches played since it was last scouted
local nextId = 1
local rng = Random.new()

-- X204: thousands separators, like UpgradeService and Theme.money
local function money(n: number): string
	local s = tostring(math.floor(n))
	local withCommas = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "£" .. withCommas:gsub("^,", "")
end

local function publish()
	ClubState.set("Club", HttpService:JSONEncode({
		players = players,
		lineup = lineup,
		autoSquad = autoSquad,
		coachLevel = coachLevel,
		scoutLevel = scoutLevel,
		shortlist = shortlist,
		shortlistMatchesLeft = math.max(SHORTLIST_MATCHES - shortlistAge, 0),
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
	if scoutLevel == 0 then
		shortlist = {}
		return
	end
	-- X214: no prospect shares a name with a current player
	local taken: { [string]: boolean } = {}
	for _, p in players do
		taken[p.name] = true
	end
	shortlist = Squad.prospects(rng:NextInteger(1, 1000000), Squad.average(players), scoutLevel, taken)
	shortlistAge = 0
end

-- After a match: keep the list unless it has gone stale or is empty (every
-- prospect signed), so a player can save for someone they have seen.
local function ageShortlist()
	if scoutLevel == 0 then
		return
	end
	shortlistAge += 1
	if #shortlist == 0 or shortlistAge >= SHORTLIST_MATCHES then
		refreshShortlist()
	end
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

	-- fill empty XI slots from the best fit players not in use, in-role first
	local function pickFor(slot: number): number?
		local role = Pitch.ROLES[slot]
		local best: Squad.Player? = nil
		for _, p in players do
			if p.injured > 0 or inUse[p.id] then
				continue
			end
			if best == nil then
				best = p
			else
				local b = best :: Squad.Player
				local pIn, bIn = p.role == role, b.role == role
				if (pIn and not bIn) or (pIn == bIn and p.overall > b.overall) then
					best = p
				end
			end
		end
		return if best then (best :: Squad.Player).id else nil
	end
	for slot = 1, #Pitch.ROLES do
		if not lineup.xi[slot] then
			-- nil when every fit player is already used: the slot stays empty and
			-- Squad.matchSquad puts a trialist there (the auto XI fallback here
			-- used to name a player already in the XI or on the bench)
			local id = pickFor(slot)
			if id then
				lineup.xi[slot] = id
				inUse[id] = true
			end
		end
	end
	for _, p in players do
		if #lineup.bench >= Config.BenchSize then
			break
		end
		if p.injured == 0 and not inUse[p.id] then
			inUse[p.id] = true
			table.insert(lineup.bench, p.id)
		end
	end
end

local function recomputeLineup()
	if autoSquad then
		lineup = Squad.autoLineup(players)
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

local function generateFresh()
	-- every club gets its own 16; the fixed Config.HomeSquadSeed is for tests
	players = Squad.generate(rng:NextInteger(1, 1000000), Config.StartingSquadOverall)
	nextId = #players + 1
	autoSquad = true
	coachLevel = 0
	scoutLevel = 0
	shortlist = {}
	lineup = { xi = {}, bench = {} }
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
	shortlist = {}
	shortlistAge = math.max(if type(data.shortlistAge) == "number" then data.shortlistAge else 0, 0)
	if type(data.shortlist) == "table" then
		for _, p in data.shortlist do
			if validPlayer(p) and type(p.fee) == "number" then
				local copy = table.clone(p)
				if type(copy.look) ~= "number" then
					copy.look = Squad.lookSeedFor(copy.id, copy.name)
				end
				table.insert(shortlist, copy)
			end
		end
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
		shortlist = shortlist,
		shortlistAge = shortlistAge,
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

-- Every management action. Returns ok plus a message for a toast.
function ClubService.act(name: string, a: unknown, b: unknown): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Locked during matchday"
	end
	local cash = ClubState.get("Cash") :: number

	if name == "setAutoSquad" then
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
		ClubState.addCash(-nextLevel.cost)
		scoutLevel += 1
		refreshShortlist()
		publish()
		return true, ("%s hired. %d prospects found."):format(nextLevel.name, #shortlist)
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
		publish()
		return true, ("%s hired"):format(nextLevel.name)
	elseif name == "sign" then
		local pid = tonumber(a)
		local index: number? = nil
		for i, p in shortlist do
			if p.id == pid then
				index = i
			end
		end
		if not index then
			return false, "That player is no longer available"
		end
		local prospect = shortlist[index :: number]
		if #players >= Config.SquadMax then
			return false, ("Squad is full (%d). Release someone first."):format(Config.SquadMax)
		end
		if cash < prospect.fee then
			return false, ("Need %s more"):format(money(prospect.fee - cash))
		end
		ClubState.addCash(-prospect.fee, "transfers") -- X299
		table.remove(shortlist, index :: number)
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
			look = prospect.look, -- X227: keep the face the shortlist showed
		}
		nextId += 1
		table.insert(players, signed)
		recomputeLineup()
		publish()
		return true, ("%s signed! Shirt number %d."):format(signed.name, signed.number)
	elseif name == "release" then
		local pid = tonumber(a)
		local p = if pid then findPlayer(pid) else nil
		if not p then
			return false, "Unknown player"
		end
		if #players <= Config.SquadMin then
			return false, ("Squad cannot go below %d players"):format(Config.SquadMin)
		end
		if xiSlotOf(p.id) then
			-- X203: with Auto Squad on, swaps are refused, so say how to get there
			return false, if autoSquad then "Turn Auto Squad off, then take them out of the XI to sell" else "Take them out of the XI first"
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
				return false, "Keep at least one goalkeeper"
			end
		end
		for i, q in players do
			if q.id == p.id then
				table.remove(players, i)
				break
			end
		end
		local value = Squad.value(p)
		ClubState.addCash(value, "sales") -- X299
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
function ClubService.finishMatch(scorerSlots: { number }, matchSquad: { Squad.MatchPlayer }, subs: { Squad.Sub }?, conceded: number?): ({ string }, { Squad.RatingChange }, Squad.Award?)
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
	local award = Squad.manOfTheMatch(players, lineup.xi, scorerIds, conceded or 0)
	local news, changes = Squad.afterMatch(players, lineup.xi, scorerIds, coachLevel, rng, subIds)
	ageShortlist()
	recomputeLineup()
	publish()
	return news, changes, award
end

-- New season housekeeping (Milestone 4 calls this).
-- Returns the season card's two lists — who retired (X277) and who came up to
-- replace them — and the retired players themselves, so the club can keep them
-- in its history (X288).
function ClubService.newSeason(): ({ string }, { string }, { Squad.Player })
	Squad.ageAll(players)
	local retired = Squad.retireVeterans(players, rng)
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
	-- Review of X277: a graduate used to be able to draw a name the club was
	-- still showing — the man retiring in the same breath, or a prospect on the
	-- shortlist (which now survives a season, X276).
	local spoken: { [string]: boolean } = {}
	for _, p in retired do
		spoken[p.name] = true
	end
	for _, p in shortlist do
		spoken[p.name] = true
	end
	local arrivals: { string } = {}
	local graduates = Squad.promoteYouth(players, rng, nextId, spoken)
	nextId += #graduates
	for _, p in graduates do
		table.insert(arrivals, ("%s (%d) comes up from the academy, shirt %d."):format(p.name, p.age, p.number))
	end
	recomputeLineup()
	publish()
	return news, arrivals, retired
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
