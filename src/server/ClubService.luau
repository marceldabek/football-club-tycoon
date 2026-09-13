--!strict
-- Owns the club's football side: the persistent squad, the lineup (auto or
-- manual), the coach, the scout and the current shortlist. Publishes it all as
-- one JSON attribute (ClubState.Club) and handles the ClubAction remote.
-- Pure squad maths lives in Squad.luau; this module only holds state and rules.
-- TEMP: one shared club per server until persistence (Milestone 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local ClubState = require(script.Parent.ClubState)

local ClubService = {}

local players: { Squad.Player } = {}
local lineup: Squad.Lineup = { xi = {}, bench = {} }
local autoSquad = true
local coachLevel = 0
local scoutLevel = 0
local shortlist: { Squad.Prospect } = {}
local nextId = 1
local rng = Random.new()

local function money(n: number): string
	return ("£%d"):format(n)
end

local function publish()
	ClubState.set("Club", HttpService:JSONEncode({
		players = players,
		lineup = lineup,
		autoSquad = autoSquad,
		coachLevel = coachLevel,
		scoutLevel = scoutLevel,
		shortlist = shortlist,
	}))
	ClubState.set("CoachLevel", coachLevel)
	ClubState.set("ScoutLevel", scoutLevel)
	ClubState.set("AutoSquad", autoSquad)
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
	local used: { [number]: boolean } = {}
	for _, p in players do
		used[p.number] = true
	end
	for n = 1, 99 do
		if not used[n] then
			return n
		end
	end
	return 99
end

local function refreshShortlist()
	if scoutLevel == 0 then
		shortlist = {}
		return
	end
	shortlist = Squad.prospects(rng:NextInteger(1, 1000000), Squad.average(players), scoutLevel)
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
	local auto = Squad.autoLineup(players)
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
			local id = pickFor(slot) or auto.xi[slot]
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

function ClubService.init()
	players = Squad.generate(Config.HomeSquadSeed, Config.StartingSquadOverall)
	nextId = #players + 1
	autoSquad = true
	coachLevel = 0
	scoutLevel = 0
	shortlist = {}
	recomputeLineup()
	publish()

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
	action.OnServerEvent:Connect(function(player: Player, name: unknown, a: unknown, b: unknown)
		if type(name) ~= "string" then
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
		ClubState.addCash(-nextLevel.cost)
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
		ClubState.addCash(-prospect.fee)
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
			return false, "Take them out of the XI first"
		end
		for i, q in players do
			if q.id == p.id then
				table.remove(players, i)
				break
			end
		end
		recomputeLineup()
		publish()
		return true, ("%s released"):format(p.name)
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
function ClubService.finishMatch(scorerSlots: { number }, matchSquad: { Squad.MatchPlayer }): { string }
	local scorerIds: { number } = {}
	for _, slot in scorerSlots do
		local p = matchSquad[slot]
		if p then
			table.insert(scorerIds, p.id)
		end
	end
	local news = Squad.afterMatch(players, lineup.xi, scorerIds, coachLevel, rng)
	refreshShortlist()
	recomputeLineup()
	publish()
	return news
end

-- New season housekeeping (Milestone 4 calls this).
function ClubService.newSeason()
	Squad.ageAll(players)
	recomputeLineup()
	publish()
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

return ClubService
