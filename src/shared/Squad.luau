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

-- X337: a prospect's ceiling reaches the player as the band his scout will
-- commit to, not as a fact. The exact `potential` stays on the server until he
-- signs.
export type Prospect = Player & { fee: number, potentialLow: number?, potentialHigh: number? }

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
	-- second pass: fill gaps with the shared picker (X338), which prefers the
	-- same kind - keeper or outfield - before it reaches for anybody
	for slot = 1, #Pitch.ROLES do
		if xi[slot] then
			continue
		end
		local id = Squad.fillSlot(players, slot, taken)
		if id then
			taken[id] = true
			xi[slot] = id
		end
	end

	local bench = Squad.benchOrder(players, taken)
	for _, id in bench do
		taken[id] = true
	end
	return { xi = xi, bench = bench }
end

-- X338: the two lineup paths had their own idea of who fills a hole. Auto
-- Squad's second pass prefers a player of the same kind (keeper or outfield),
-- so it never puts the reserve goalkeeper at right back; the manual repair in
-- ClubService scored on role-then-overall only, so with Auto Squad off a hole
-- in the XI could be filled by the spare keeper - and it filled the bench in
-- raw squad order while Auto Squad sorted it by rating, which then decided who
-- came on as a substitute. Both paths use these now.

-- The best available player for `slot`: in role first, then the same kind
-- (keeper or outfield), then anyone, and the higher rating within each of
-- those. `taken` is the set of ids already used.
function Squad.fillSlot(players: { Player }, slot: number, taken: { [number]: boolean }): number?
	local role = Pitch.ROLES[slot]
	local wantKeeper = role == "GK"
	local best: Player? = nil
	local function rank(p: Player): number
		if p.role == role then
			return 2
		end
		return if (p.role == "GK") == wantKeeper then 1 else 0
	end
	for _, p in players do
		if p.injured > 0 or taken[p.id] then
			continue
		end
		if best == nil then
			best = p
		else
			local b = best :: Player
			local pr, br = rank(p), rank(b)
			if pr > br or (pr == br and (p.overall > b.overall or (p.overall == b.overall and p.id < b.id))) then
				best = p
			end
		end
	end
	return if best then (best :: Player).id else nil
end

-- Who sits on the bench: the fittest available players by rating, best first,
-- up to Config.BenchSize. The order matters because Squad.nextSub takes the
-- first one it can use.
function Squad.benchOrder(players: { Player }, taken: { [number]: boolean }): { number }
	local spare: { Player } = {}
	for _, p in players do
		if p.injured == 0 and not taken[p.id] then
			table.insert(spare, p)
		end
	end
	table.sort(spare, function(a, b)
		if a.overall ~= b.overall then
			return a.overall > b.overall
		end
		return a.id < b.id
	end)
	local bench: { number } = {}
	for _, p in spare do
		if #bench >= Config.BenchSize then
			break
		end
		table.insert(bench, p.id)
	end
	return bench
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
-- X333: whether the coach would make a change now. The choice of who comes off
-- and who comes on is `Squad.nextSub` - the same one the SUB button uses - so
-- an automatic substitution and a manual one are the same event to everything
-- downstream (the presenter, the scorer credit, the summary).
function Squad.coachWantsSub(minute: number, made: { Sub }, allowance: number): boolean
	local madeCount = #made
	if madeCount >= math.min(allowance, Config.MaxSubs) then
		return false
	end
	local due = Config.AutoSubMinutes[madeCount + 1]
	return due ~= nil and minute >= due
end

-- X334: the change an injury forces. `outIdx` is the slot that went down, so
-- this is not a choice - it only has to find somebody on the bench who can
-- take his place (a keeper for a keeper), or give up if there is nobody.
-- X344: which squad index is in `slot`'s shirt now, after every substitution
-- made in it. The sim names a starting slot, but a coach change (X333) can
-- already have put a substitute there - and the injury used to name and injure
-- the starter who walked off twenty minutes earlier.
-- `at` is a moment in the match: `index` is how far down the timeline we are
-- and `minute` the clock. Without it, every substitution counts - "who is in
-- that shirt now". With it, only the changes made before that moment count,
-- which is X218's rule: a goal earlier in the same minute as a substitution
-- still belongs to the man who was on then. Substitutions carry `afterEvent`
-- (how many timeline events had been shown when they were made) and fall back
-- to the minute for older saves.
export type Moment = { index: number, minute: number }
function Squad.filledBy(made: { Sub }, slot: number, at: Moment?): number
	local idx = slot
	for _, s in made do
		local counts = true
		if at then
			counts = if s.afterEvent then at.index > s.afterEvent else (s.minute or 0) <= at.minute
		end
		if s.out == idx and counts then
			idx = s["in"]
		end
	end
	return idx
end

function Squad.forcedSub(matchSquad: { MatchPlayer }, made: { Sub }, outIdx: number): Sub?
	if #made >= Config.MaxSubs then
		return nil
	end
	-- who has been taken off, and who has come on: a substitute already on the
	-- pitch can go down himself, and that is not the same as "already off"
	local off: { [number]: boolean } = {}
	local on: { [number]: boolean } = {}
	for _, s in made do
		off[s.out] = true
		on[s["in"]] = true
	end
	local idx = Squad.filledBy(made, outIdx)
	local hurt = matchSquad[idx]
	if off[idx] or not hurt then
		return nil -- already off
	end
	-- a keeper for a keeper, by the injured man's own role (a substitute is not
	-- in a formation slot at all, so Pitch.ROLES cannot answer it)
	local wantKeeper = hurt.role == "GK"
	local inIdx: number? = nil
	for i = #Pitch.ROLES + 1, #matchSquad do
		local p = matchSquad[i]
		if off[i] or on[i] or not p then
			continue
		end
		local isKeeper = p.role == "GK"
		if isKeeper ~= wantKeeper then
			continue
		end
		if inIdx == nil or p.overall > matchSquad[inIdx :: number].overall then
			inIdx = i
		end
	end
	if inIdx == nil then
		return nil -- nobody on the bench can take that place
	end
	return { out = idx, ["in"] = inIdx :: number, minute = 0, afterEvent = 0 }
end

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
		local scored = ev :: any
		local slot = scored.scorer
		if ev.team == "Home" and ev.type == "GOAL" and type(slot) == "number" then
			-- X357: the rule itself lives in Squad.filledBy now. The moment
			-- goes through a local because `slot = f(...)` followed by a line
			-- starting with `(` is the one syntax Luau calls ambiguous.
			slot = Squad.filledBy(subs, slot, { index = index, minute = scored.minute })
			scored.scorer = slot
			table.insert(scorers, slot)
		end
	end
	return scorers
end

-- Post-match bookkeeping. `scorerIds` are player ids; `subIds` are the
-- players who came on (X219: they played too). Mutates players and returns
-- human-readable news lines for the summary.
-- X334: `injuredId` is the player the match sim put down, if any. Injuries
-- used to be rolled here, per starter, after the whistle - so they never
-- happened *during* a match and could not force a substitution.
function Squad.afterMatch(players: { Player }, xi: { number }, scorerIds: { number }, coachLevel: number, rng: Random, subIds: { number }?, injuredId: number?): ({ string }, { RatingChange })
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
	-- X308: a trialist filling an empty slot is not in the squad, so there is
	-- nobody to credit — but the summary card lists them as the scorer, so the
	-- news has to admit it happened.
	local trialGoals = 0
	for _, id in scorerIds do
		if not map[id] then
			trialGoals += 1
		end
	end
	if trialGoals > 0 then
		table.insert(news, ("A trialist scored %d (no contract, no record)"):format(trialGoals))
	end
	local coach = Config.CoachLevels[coachLevel + 1]
	local developMul = if coach then coach.developMultiplier else 1

	for _, p in players do
		if played[p.id] then
			p.apps += 1
			if APP_MILESTONES[p.apps] then
				table.insert(news, ("%s makes their %dth appearance"):format(p.name, p.apps))
			end
			if injuredId and p.id == injuredId then
				p.injured = rng:NextInteger(Config.InjuryMatches[1], Config.InjuryMatches[2])
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
-- X308: `matchSquad` is optional and only matters when a trialist played: they
-- hold an empty slot (id = -slot) and are not in `players`, so without it the
-- award skipped the man the card lists as the scorer.
function Squad.manOfTheMatch(players: { Player }, xi: { number }, scorerIds: { number }, conceded: number, matchSquad: { MatchPlayer }?): Award?
	local map: { [number]: any } = byId(players)
	for _, m in matchSquad or {} do
		if map[m.id] == nil then
			map[m.id] = m
		end
	end
	local function award(p: any, reason: string): Award
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

	local keeper: any, best: any = nil, nil
	for _, id in xi do
		local p = map[id]
		if p then
			if p.role == "GK" then
				keeper = p
			end
			if not best or p.overall > (best :: any).overall then
				best = p
			end
		end
	end
	if conceded == 0 and keeper then
		return award(keeper :: any, "a clean sheet")
	end
	return if best then award(best :: any, "the best display on the pitch") else nil
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

-- X337: how wide a band this scout reports a ceiling in. 0 means he names it.
function Squad.scoutDoubt(scoutLevel: number): number
	local level = Config.ScoutLevels[scoutLevel]
	return if level then (level.potentialDoubt or 0) else 0
end

-- X337: the band a scout will commit a ceiling to. The truth is always inside
-- it, but the band is deliberately *not* centred on it, so a player cannot
-- read the midpoint and know the number anyway. `seed` makes it stable: the
-- same prospect is reported the same way every time the panel is rebuilt.
-- `floor` is the lowest the band is allowed to start: pass a prospect's
-- current overall, because no scout would suggest a player's ceiling is below
-- what he already is.
function Squad.potentialBand(potential: number, width: number, seed: number, floor: number?): (number, number)
	if width <= 0 then
		return potential, potential
	end
	local bottom = math.max(floor or Squad.MIN_OVERALL, Squad.MIN_OVERALL)
	local rng = Random.new(seed)
	local low = potential - rng:NextInteger(0, width)
	local high = low + width
	-- a band that runs past the ratings the game uses, or below what the player
	-- already is, slides back inside without ever leaving the truth out of it
	if low < bottom then
		low = bottom
		high = math.max(low + width, potential)
	end
	if high > Squad.MAX_OVERALL then
		high = Squad.MAX_OVERALL
		low = math.min(high - width, potential)
	end
	return low, high
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
		-- X337: what the scout will actually say about his ceiling
		prospect.potentialLow, prospect.potentialHigh = Squad.potentialBand(p.potential, level.potentialDoubt or 0, p.id, p.overall)
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
