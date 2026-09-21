--!strict
-- Generates fictional footballers (a name and a nation) and throwaway opponent
-- squads for the matchday visuals. Pure and deterministic. The home club's
-- persistent squad with ratings lives in Squad.luau and reuses generatePeople.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Nations = require(ReplicatedStorage.Shared.Nations)

local TeamGen = {}

export type Player = {
	name: string,
	nation: string, -- Nations code
	number: number,
	role: Pitch.Role,
	look: number, -- appearance seed, see Appearance.luau
}

export type Person = { name: string, nation: string }

-- TEMP: how far an opponent's squad is drawn from (see Nations.pick).
TeamGen.OPPONENT_REACH = 0.15

-- `count` distinct people drawn from the shared rng, each named from his own
-- country, never with a name in `avoid` (X214: scouted prospects must not
-- share a name with the current squad). `reach` is 0 for a local club.
function TeamGen.generatePeople(rng: Random, count: number, avoid: { [string]: boolean }?, reach: number?): { Person }
	local people: { Person } = {}
	local used: { [string]: boolean } = if avoid then table.clone(avoid) else {}
	while #people < count do
		local nation = Nations.pick(rng, reach)
		local name = Nations.nameFor(rng, nation)
		if not used[name] then
			used[name] = true
			table.insert(people, { name = name, nation = nation.code })
		end
	end
	return people
end

function TeamGen.generateNames(rng: Random, count: number, avoid: { [string]: boolean }?): { string }
	local names: { string } = {}
	for _, person in TeamGen.generatePeople(rng, count, avoid) do
		table.insert(names, person.name)
	end
	return names
end

-- Bench roles are always outfield. Fixed shape for opponents.
local BENCH_ROLES: { Pitch.Role } = { "DEF", "MID", "MID", "FWD", "DEF" }

-- An opponent's 16: starting XI in formation order plus a five-man bench.
function TeamGen.generate(seed: number): { Player }
	local rng = Random.new(seed)
	local people = TeamGen.generatePeople(rng, #Pitch.ROLES + #BENCH_ROLES, nil, TeamGen.OPPONENT_REACH)
	local squad: { Player } = {}
	for i, role in Pitch.ROLES do
		table.insert(squad, { name = people[i].name, nation = people[i].nation, number = i, role = role, look = rng:NextInteger(1, 2 ^ 30) })
	end
	for i, role in BENCH_ROLES do
		table.insert(squad, { name = people[#Pitch.ROLES + i].name, nation = people[#Pitch.ROLES + i].nation, number = #Pitch.ROLES + i, role = role, look = rng:NextInteger(1, 2 ^ 30) })
	end
	return squad
end

return TeamGen
