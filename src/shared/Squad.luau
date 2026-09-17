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
	look: number, -- appearance seed, see Appearance.luau
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
	look: number,
}

export type Sub = { out: number, ["in"]: number, minute: number?, afterEvent: number? }

-- One OVR move after a match, for the post-match development strip.
export type RatingChange = { id: number, name: string, number: number, look: number, from: number, to: number }

export type ScoredEvent = { minute: number, team: string, type: string, scorer: number? }

-- X302: nobody was ever singled out after a match. `Award` is the man of the
-- match; the milestones go into the summary's news lines.
export type Award = { id: number, name: string, number: number, look: number, reason: string }

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

-- TEMP milestones: the numbers a grassroots career would actually mark.
local APP_MILESTONES: { [number]: boolean } = { [50] = true, [100] = true, [200] = true }
local GOAL_MILESTONES: { [number]: boolean } = { [10] = true, [25] = true, [50] = true }

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
		look = rng:NextInteger(1, 2 ^ 30),
	}
end

-- Stable look seed for players saved before looks existed (FNV-1a over the
-- name, salted with the id).
function Squad.lookSeedFor(id: number, name: string): number
	local h = 2166136261
	for i = 1, #name do
		h = (bit32.bxor(h, name:byte(i)) * 16777619) % 2 ^ 31
	end
	return (h + id * 7919) % 2 ^ 30 + 1
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
			table.insert(out, { id = p.id, name = p.name, number = p.number, role = p.role, overall = p.overall, look = p.look })
		end
	end
	for slot = 1, #Pitch.ROLES do
		if lineup.xi[slot] and map[lineup.xi[slot]] then
			add(lineup.xi[slot])
		else
			-- X220: too few fit players. A trialist holds the slot so every index
			-- keeps its role (scorers, subs and the presenter all index by slot).
			-- Rated like an empty slot in Squad.strength; negative id, never saved.
			table.insert(out, {
				id = -slot,
				name = "Trialist",
				number = 40 + slot,
				role = Pitch.ROLES[slot],
				overall = Squad.MIN_OVERALL,
				look = 7919 * slot,
			})
		end
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

-- X218: a goal is scored by whoever fills the slot when it happens. A starter
-- subbed off before the goal hands it to the substitute (the one the crowd
-- sees score). `afterEvent` is how many timeline events had been shown when
-- the sub was made, so a goal earlier in the same minute stays the starter's;
-- subs without it fall back to the minute. Mutates the events' scorer; returns
-- the scorer indices (into the matchSquad) in match order.
function Squad.creditScorers(events: { ScoredEvent }, subs: { Sub }): { number }
	local scorers: { number } = {}
	for index, ev in events do
		local slot = (ev :: any).scorer
		if ev.team == "Home" and ev.type == "GOAL" and type(slot) == "number" then
			for _, sub in subs do
				local after = if sub.afterEvent then index > sub.afterEvent else (sub.minute or 0) <= (ev :: any).minute
				if sub.out == slot and after then
					slot = sub["in"]
				end
			end
			(ev :: any).scorer = slot
			table.insert(scorers, slot)
		end
	end
	return scorers
end

-- Post-match bookkeeping. `scorerIds` are player ids; `subIds` are the
-- players who came on (X219: they played too). Mutates players and returns
-- human-readable news lines for the summary.
function Squad.afterMatch(players: { Player }, xi: { number }, scorerIds: { number }, coachLevel: number, rng: Random, subIds: { number }?): ({ string }, { RatingChange })
	local news: { string } = {}
	local changes: { RatingChange } = {}
	local played: { [number]: boolean } = {}
	for _, id in xi do
		played[id] = true
	end
	for _, id in subIds or {} do
		played[id] = true
	end
	local map = byId(players)
	-- X302: goals in this match, for a hat-trick line and the award
	local thisMatch: { [number]: number } = {}
	for _, id in scorerIds do
		local p = map[id]
		if p then
			p.goals += 1
			thisMatch[id] = (thisMatch[id] or 0) + 1
			if GOAL_MILESTONES[p.goals] then
				table.insert(news, ("%s reaches %d goals for the club"):format(p.name, p.goals))
			end
		end
	end
	for id, scored in thisMatch do
		if scored >= 3 and map[id] then
			table.insert(news, ("%s scores a hat-trick!"):format(map[id].name))
		end
	end
	local coach = Config.CoachLevels[coachLevel + 1]
	local developMul = if coach then coach.developMultiplier else 1

	for _, p in players do
		if played[p.id] then
			p.apps += 1
			if APP_MILESTONES[p.apps] then
				table.insert(news, ("%s makes their %dth appearance"):format(p.name, p.apps))
			end
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

		-- X292: under-24s come on quickly, players in their prime slowly (and
		-- only with a coach worth the name), 28-30 plateau, 31+ decline.
		local growing = p.overall < p.potential and p.age <= Config.PeakTo
		if growing then
			local base = if p.age < Config.PeakFrom then Config.DevelopChance else Config.DevelopChancePeak
			local chance = base * developMul * (if played[p.id] then 1 else 0.5)
			if rng:NextNumber() < chance then
				p.overall += 1
				table.insert(news, ("%s improved to %d OVR"):format(p.name, p.overall))
				table.insert(changes, { id = p.id, name = p.name, number = p.number, look = p.look, from = p.overall - 1, to = p.overall })
			end
		elseif p.age >= 31 and rng:NextNumber() < Config.DeclineChance then
			local before = p.overall
			p.overall = math.max(p.overall - 1, Squad.MIN_OVERALL)
			if p.overall < before then
				table.insert(news, ("%s is slowing down (%d OVR)"):format(p.name, p.overall))
				table.insert(changes, { id = p.id, name = p.name, number = p.number, look = p.look, from = before, to = p.overall })
			end
		end
	end
	return news, changes
end

-- X302: one player to talk about after a match. TEMP rule: whoever scored the
-- most, then the keeper if he kept a clean sheet, then the best player on the
-- pitch — so there is always someone, even in a 0-0.
function Squad.manOfTheMatch(players: { Player }, xi: { number }, scorerIds: { number }, conceded: number): Award?
	local map = byId(players)
	local function award(p: Player, reason: string): Award
		return { id = p.id, name = p.name, number = p.number, look = p.look, reason = reason }
	end

	local goals: { [number]: number } = {}
	for _, id in scorerIds do
		goals[id] = (goals[id] or 0) + 1
	end
	local bestId, bestGoals = nil, 0
	for id, scored in goals do
		local p = map[id]
		if p and (scored > bestGoals or (scored == bestGoals and bestId and p.overall > map[bestId :: number].overall)) then
			bestId, bestGoals = id, scored
		end
	end
	if bestId then
		local p = map[bestId :: number]
		return award(p, if bestGoals > 1 then ("%d goals"):format(bestGoals) else "the goal")
	end

	local keeper, best = nil, nil
	for _, id in xi do
		local p = map[id]
		if p then
			if p.role == "GK" then
				keeper = p
			end
			if not best or p.overall > (best :: Player).overall then
				best = p
			end
		end
	end
	if conceded == 0 and keeper then
		return award(keeper :: Player, "a clean sheet")
	end
	return if best then award(best :: Player, "the best display on the pitch") else nil
end

-- New season: everyone a year older. Returns nothing notable.
function Squad.ageAll(players: { Player })
	for _, p in players do
		p.age += 1
	end
end

-- X277: the end of a career. Called right after ageAll, so a player who has
-- just turned RetireAge can go in the same summer. Removes the retirees from
-- `players` (which frees their shirt number, see Squad.freeNumber) and returns
-- them, oldest first.
--
-- The first version stopped at Config.SquadMin, which looked safe and was
-- actually worse: a squad already down to 14 veterans froze, everybody kept
-- ageing and nobody could ever leave. So retirement is unconditional (bar the
-- last goalkeeper, who gets one more season) and Squad.promoteYouth refills the
-- squad afterwards.
function Squad.retireVeterans(players: { Player }, rng: Random): { Player }
	local veterans: { Player } = {}
	for _, p in players do
		if p.age >= Config.RetireAge then
			table.insert(veterans, p)
		end
	end
	table.sort(veterans, function(a, b)
		if a.age ~= b.age then
			return a.age > b.age
		end
		return a.id < b.id -- stable: the same squad always retires the same way
	end)

	local keepers = 0
	for _, p in players do
		if p.role == "GK" then
			keepers += 1
		end
	end

	local retired: { Player } = {}
	for _, p in veterans do
		if p.role == "GK" and keepers <= 1 then
			continue
		end
		local chance = if p.age >= Config.RetireMaxAge
			then 1
			else (p.age - Config.RetireAge + 1) * Config.RetireChancePerYear
		if rng:NextNumber() < chance then
			for i, q in players do
				if q.id == p.id then
					table.remove(players, i)
					break
				end
			end
			if p.role == "GK" then
				keepers -= 1
			end
			table.insert(retired, p)
		end
	end
	return retired
end

-- Smallest unused shirt number. A retirement frees one, and the next arrival
-- (academy or signing) takes it, so numbers stay low and stable.
function Squad.freeNumber(players: { Player }): number
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

-- The shape Squad.generate makes, so the academy fills the gap the squad
-- actually has rather than handing over another midfielder.
local SQUAD_SHAPE: { [string]: number } = { GK = 2, DEF = 5, MID = 5, FWD = 4 }
local SHAPE_ORDER: { Pitch.Role } = { "GK", "DEF", "MID", "FWD" }

local function neediestRole(players: { Player }): Pitch.Role
	local have: { [string]: number } = { GK = 0, DEF = 0, MID = 0, FWD = 0 }
	for _, p in players do
		have[p.role] += 1
	end
	local best: Pitch.Role, bestGap = "MID", -math.huge
	for _, role in SHAPE_ORDER do
		local gap = SQUAD_SHAPE[role] - have[role]
		if gap > bestGap then
			best, bestGap = role, gap
		end
	end
	return best
end

-- X277: the academy. Retirement is unconditional, so something has to keep the
-- squad playable: after the veterans go, young players come up until the squad
-- is back to Config.SquadMin. They are free, a little below the squad's level
-- and carry real headroom, so a club that never signs anyone still renews
-- itself instead of silting up. `firstId` is the club's next free id; the
-- graduates are appended to `players` and returned.
-- Review of X277: refilling to Config.SquadMin (14) left a matchday two short.
-- Retirement is unconditional, so 14 became the squad's resting size, and an XI
-- plus a full bench is 16 — the bench emptied and matchSquad started handing
-- trialists a place in the XI. The academy refills to a matchday squad.
local function matchdaySquadSize(): number
	return math.max(Config.SquadMin, #Pitch.ROLES + Config.BenchSize)
end

-- X277: the academy. Retirement is unconditional, so something has to keep the
-- squad playable: after the veterans go, young players come up until there is a
-- full XI and bench again. They are free, a little below the squad's level and
-- carry real headroom, so a club that never signs anyone still renews itself
-- instead of silting up. `firstId` is the club's next free id; `avoidNames`
-- covers names the club is still showing elsewhere (the players who have just
-- retired, and the scout's shortlist). The graduates are appended to `players`
-- and returned.
function Squad.promoteYouth(players: { Player }, rng: Random, firstId: number, avoidNames: { [string]: boolean }?): { Player }
	local graduates: { Player } = {}
	local taken: { [string]: boolean } = if avoidNames then table.clone(avoidNames) else {}
	for _, p in players do
		taken[p.name] = true
	end
	-- X286: "a bit below the squad" alone spirals. Each intake is measured
	-- against a squad that is itself mostly academy, so the average walks down
	-- every generation: a save rolled on 15 seasons came out at 30 OVR, the
	-- floor, with the club unable to win anything. The academy is a grassroots
	-- club's own level, so it never drops below where a new club starts.
	local avg = math.max(Squad.average(players) - 6, Config.StartingSquadOverall - 5)
	local function promote(role: Pitch.Role)
		local name = TeamGen.generateNames(rng, 1, taken)[1]
		taken[name] = true
		local p = makePlayer(rng, firstId + #graduates, name, Squad.freeNumber(players), role, avg, 8, 19)
		table.insert(players, p)
		table.insert(graduates, p)
	end

	while #players < matchdaySquadSize() do
		promote(neediestRole(players))
	end

	-- Review of X277: retireVeterans never retires the last goalkeeper, so
	-- without this he plays for ever — the squad is up to size, so nothing else
	-- would promote his replacement. One comes up, and he can go next season.
	-- (A squad already at Config.SquadMax has no room for him, so there the
	-- keeper does keep going until the player releases somebody.)
	local keeperToCome = false
	for _, p in players do
		if p.role == "GK" and p.age < Config.RetireMaxAge then
			keeperToCome = true
			break
		end
	end
	if not keeperToCome and #players < Config.SquadMax then
		promote("GK")
	end
	return graduates
end

-- TEMP fee formula: pay for current quality and for headroom, rounded to 50.
-- Both terms are superlinear. A linear fee made the top of the market cost
-- almost the same as the middle (a 76 overall went for 3,000 and an 85 for
-- 3,250), so a rich club bought every prospect on the list without choosing.
function Squad.fee(p: Player): number
	local quality = math.max(p.overall - 35, 1) ^ 2.6
	local headroom = math.max(p.potential - p.overall, 0) ^ 1.5 * 15
	return math.max(math.floor((quality + headroom) / 50) * 50, 100)
end

-- TEMP transfer value: what the club receives for selling a player. Younger
-- players hold their fee; veterans fetch much less. Rounded to 50, min 100.
function Squad.value(p: Player): number
	local ageFactor = if p.age <= 23 then 1 elseif p.age <= 29 then 0.85 elseif p.age <= 32 then 0.55 else 0.35
	return math.max(math.floor((Squad.fee(p) * ageFactor) / 50) * 50, 100)
end

-- Scout shortlist. Better scouts find more and higher-ceiling players.
-- Ids are negative and unique per seed so they never clash with squad ids.
function Squad.prospects(seed: number, avgOverall: number, scoutLevel: number, avoidNames: { [string]: boolean }?): { Prospect }
	local level = Config.ScoutLevels[scoutLevel]
	if not level then
		return {}
	end
	local rng = Random.new(seed)
	local names = TeamGen.generateNames(rng, level.prospects, avoidNames)
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
