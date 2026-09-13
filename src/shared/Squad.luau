--!strict
-- Persistent squad model: generated footballers with ratings, auto lineup,
-- substitutions, injuries, development and scouting prospects.
-- Pure and deterministic given a seed / Random. No instances, no yielding.
-- The server (ClubService) owns the tables; this module only transforms them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local TeamGen = require(ReplicatedStorage.Shared.TeamGen)
local Config = require(ReplicatedStorage.Shared.Config)

local Squad = {}

export type Player = {
	id: number,
	name: string,
	number: number,
	role: Pitch.Role,
	age: number,
	overall: number,
	potential: number,
	injured: number, -- matches still out; 0 = fit
	apps: number,
	goals: number,
}

export type Prospect = Player & { fee: number }

export type Lineup = { xi: { number }, bench: { number } }

-- A player as the matchday timeline carries them (TeamGen shape + rating).
export type MatchPlayer = {
	id: number,
	name: string,
	number: number,
	role: Pitch.Role,
	overall: number,
}

export type Sub = { out: number, ["in"]: number }

export type ScoredEvent = { minute: number, team: string, type: string, scorer: number? }

-- Starting squad shape: 16 players. TEMP.
local GENERATE_ROLES: { Pitch.Role } = {
	"GK", "GK",
	"DEF", "DEF", "DEF", "DEF", "DEF",
	"MID", "MID", "MID", "MID", "MID",
	"FWD", "FWD", "FWD", "FWD",
}

local ROLE_WEIGHT_FOR_GOAL: { [string]: number } = { GK = 0, DEF = 1, MID = 3, FWD = 5 }

Squad.MIN_OVERALL = 30
Squad.MAX_OVERALL = 99
Squad.OUT_OF_ROLE_PENALTY = 6

local function clampOverall(n: number): number
	return math.clamp(math.floor(n + 0.5), Squad.MIN_OVERALL, Squad.MAX_OVERALL)
end

local function byId(players: { Player }): { [number]: Player }
	local map = {}
	for _, p in players do
		map[p.id] = p
	end
	return map
end
Squad.byId = byId

-- Builds one player. `avg` is the target overall; spread and potential are TEMP.
local function makePlayer(rng: Random, id: number, name: string, number: number, role: Pitch.Role, avg: number, potentialBoost: number, maxAge: number?): Player
	local age = rng:NextInteger(17, maxAge or 33)
	local overall = clampOverall(avg + rng:NextInteger(-6, 6))
	-- younger players carry more headroom
	local headroom
	if age <= 20 then
		headroom = rng:NextInteger(6, 18)
	elseif age <= 24 then
		headroom = rng:NextInteger(3, 12)
	elseif age <= 28 then
		headroom = rng:NextInteger(0, 5)
	else
		headroom = 0
	end
	local potential = clampOverall(overall + headroom + potentialBoost)
	return {
		id = id,
		name = name,
		number = number,
		role = role,
		age = age,
		overall = overall,
		potential = math.max(potential, overall),
		injured = 0,
		apps = 0,
		goals = 0,
	}
end

-- Starting squad: 16 players with ids and shirt numbers 1..16.
function Squad.generate(seed: number, avgOverall: number): { Player }
	local rng = Random.new(seed)
	local names = TeamGen.generateNames(rng, #GENERATE_ROLES)
	local players: { Player } = {}
	for i, role in GENERATE_ROLES do
		table.insert(players, makePlayer(rng, i, names[i], i, role, avgOverall, 0))
	end
	return players
end

-- Best fit player per formation slot; injured players never start.
-- Falls back to any fit player when a role runs out (strength() applies the
-- out-of-role penalty). Bench: best remaining fit players.
function Squad.autoLineup(players: { Player }): Lineup
	local fit: { Player } = {}
	for _, p in players do
		if p.injured == 0 then
			table.insert(fit, p)
		end
	end
	table.sort(fit, function(a, b)
		if a.overall ~= b.overall then
			return a.overall > b.overall
		end
		return a.id < b.id
	end)

	local taken: { [number]: boolean } = {}
	local xi: { number } = {}
	-- first pass: in-role picks
	for slot, role in Pitch.ROLES do
		for _, p in fit do
			if not taken[p.id] and p.role == role then
				taken[p.id] = true
				xi[slot] = p.id
				break
			end
		end
	end
	-- second pass: fill gaps. Prefer same kind (keeper / outfield), else anyone.
	for slot, role in Pitch.ROLES do
		if xi[slot] then
			continue
		end
		local wantKeeper = role == "GK"
		local best: Player? = nil
		for _, p in fit do
			if taken[p.id] then
				continue
			end
			local sameKind = (p.role == "GK") == wantKeeper
			if best == nil then
				best = p
			elseif sameKind and (best.role == "GK") ~= wantKeeper then
				best = p
			end
			if best == p and sameKind then
				break
			end
		end
		if best then
			taken[best.id] = true
			xi[slot] = best.id
		end
	end

	local bench: { number } = {}
	for _, p in fit do
		if #bench >= Config.BenchSize then
			break
		end
		if not taken[p.id] then
			taken[p.id] = true
			table.insert(bench, p.id)
		end
	end
	return { xi = xi, bench = bench }
end

-- Team strength for the hidden sim: mean overall of the XI with a penalty
-- for every starter playing out of role. Missing slots count as MIN_OVERALL.
function Squad.strength(players: { Player }, xi: { number }): number
	local map = byId(players)
	local total = 0
	for slot, role in Pitch.ROLES do
		local p = map[xi[slot]]
		if p then
			local rating = p.overall
			if p.role ~= role then
				rating -= Squad.OUT_OF_ROLE_PENALTY
			end
			total += rating
		else
			total += Squad.MIN_OVERALL
		end
	end
	return total / #Pitch.ROLES
end

-- Ordered matchday list: XI in formation order, then the bench.
function Squad.matchSquad(players: { Player }, lineup: Lineup): { MatchPlayer }
	local map = byId(players)
	local out: { MatchPlayer } = {}
	local function add(id: number?)
		local p = if id then map[id] else nil
		if p then
			table.insert(out, { id = p.id, name = p.name, number = p.number, role = p.role, overall = p.overall })
		end
	end
	for slot = 1, #Pitch.ROLES do
		add(lineup.xi[slot])
	end
	for _, id in lineup.bench do
		add(id)
	end
	return out
end

-- Lowest-rated outfield starter comes off for the best unused bench player
-- of the same role (any outfield role if none). Indices are matchSquad
-- positions, like the presenter expects. nil when no sub is possible.
function Squad.nextSub(matchSquad: { MatchPlayer }, made: { Sub }): Sub?
	if #made >= Config.MaxSubs then
		return nil
	end
	local used: { [number]: boolean } = {}
	for _, s in made do
		used[s.out] = true
		used[s["in"]] = true
	end
	local outIdx: number? = nil
	for idx = 2, #Pitch.ROLES do
		local p = matchSquad[idx]
		if p and not used[idx] then
			if outIdx == nil or p.overall < matchSquad[outIdx :: number].overall then
				outIdx = idx
			end
		end
	end
	if outIdx == nil then
		return nil
	end
	local outRole = Pitch.ROLES[outIdx :: number]
	local inIdx: number? = nil
	for idx = #Pitch.ROLES + 1, #matchSquad do
		local p = matchSquad[idx]
		if used[idx] or p.role == "GK" then
			continue
		end
		if inIdx == nil then
			inIdx = idx
		else
			local cur = matchSquad[inIdx :: number]
			local curInRole, pInRole = cur.role == outRole, p.role == outRole
			if (pInRole and not curInRole) or (pInRole == curInRole and p.overall > cur.overall) then
				inIdx = idx
			end
		end
	end
	if inIdx == nil then
		return nil
	end
	return { out = outIdx :: number, ["in"] = inIdx :: number }
end

-- Gives every Home GOAL a scorer (an XI slot), weighted toward forwards.
-- Mutates the events; returns the list of scorer slots in match order.
function Squad.assignScorers(events: { ScoredEvent }, matchSquad: { MatchPlayer }, rng: Random): { number }
	local scorers: { number } = {}
	local weights: { number } = {}
	local totalWeight = 0
	for slot = 1, #Pitch.ROLES do
		local p = matchSquad[slot]
		local w = if p then (ROLE_WEIGHT_FOR_GOAL[p.role] or 1) else 0
		weights[slot] = w
		totalWeight += w
	end
	for _, ev in events do
		if ev.team == "Home" and ev.type == "GOAL" and totalWeight > 0 then
			local pick = rng:NextNumber() * totalWeight
			for slot = 1, #Pitch.ROLES do
				pick -= weights[slot]
				if pick <= 0 then
					ev.scorer = slot
					table.insert(scorers, slot)
					break
				end
			end
		end
	end
	return scorers
end

-- Post-match bookkeeping. `scorerIds` are player ids. Mutates players and
-- returns human-readable news lines for the summary.
function Squad.afterMatch(players: { Player }, xi: { number }, scorerIds: { number }, coachLevel: number, rng: Random): { string }
	local news: { string } = {}
	local played: { [number]: boolean } = {}
	for _, id in xi do
		played[id] = true
	end
	local map = byId(players)
	for _, id in scorerIds do
		local p = map[id]
		if p then
			p.goals += 1
		end
	end
	local coach = Config.CoachLevels[coachLevel + 1]
	local developMul = if coach then coach.developMultiplier else 1

	for _, p in players do
		if played[p.id] then
			p.apps += 1
			if rng:NextNumber() < Config.InjuryChance then
				p.injured = rng:NextInteger(1, 3)
				table.insert(news, ("%s injured (out %d match%s)"):format(p.name, p.injured, if p.injured == 1 then "" else "es"))
			end
		elseif p.injured > 0 then
			p.injured -= 1
			if p.injured == 0 then
				table.insert(news, ("%s is fit again"):format(p.name))
			end
		end

		if p.age < 24 and p.overall < p.potential then
			local chance = Config.DevelopChance * developMul * (if played[p.id] then 1 else 0.5)
			if rng:NextNumber() < chance then
				p.overall += 1
				table.insert(news, ("%s improved to %d OVR"):format(p.name, p.overall))
			end
		elseif p.age >= 31 and rng:NextNumber() < Config.DeclineChance then
			p.overall = math.max(p.overall - 1, Squad.MIN_OVERALL)
			table.insert(news, ("%s is slowing down (%d OVR)"):format(p.name, p.overall))
		end
	end
	return news
end

-- New season: everyone a year older. Returns nothing notable.
function Squad.ageAll(players: { Player })
	for _, p in players do
		p.age += 1
	end
end

-- TEMP fee formula: pay for current quality and for headroom, rounded to 50.
function Squad.fee(p: Player): number
	local quality = math.max(p.overall - 35, 1) * 60
	local headroom = math.max(p.potential - p.overall, 0) * 25
	return math.max(math.floor((quality + headroom) / 50) * 50, 100)
end

-- Scout shortlist. Better scouts find more and higher-ceiling players.
-- Ids are negative and unique per seed so they never clash with squad ids.
function Squad.prospects(seed: number, avgOverall: number, scoutLevel: number): { Prospect }
	local level = Config.ScoutLevels[scoutLevel]
	if not level then
		return {}
	end
	local rng = Random.new(seed)
	local names = TeamGen.generateNames(rng, level.prospects)
	local list: { Prospect } = {}
	for i = 1, level.prospects do
		local role: Pitch.Role = GENERATE_ROLES[rng:NextInteger(3, #GENERATE_ROLES)]
		if rng:NextNumber() < 0.12 then
			role = "GK"
		end
		-- scouts look for players with a future: nobody over 27 on a shortlist
		local p = makePlayer(rng, -(seed * 100 + i), names[i], 0, role, avgOverall + level.overallBonus, level.potentialBoost, 27)
		local prospect = p :: any
		prospect.fee = Squad.fee(p)
		table.insert(list, prospect)
	end
	return list
end

-- Average overall across the squad; prospects are generated around it.
function Squad.average(players: { Player }): number
	if #players == 0 then
		return Config.StartingSquadOverall
	end
	local total = 0
	for _, p in players do
		total += p.overall
	end
	return total / #players
end

return Squad
