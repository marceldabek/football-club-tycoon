--!strict
-- Generates a fictional squad for the matchday visuals. Pure and deterministic.
-- Milestone 2 only needs names, numbers and roles; the real persistent squad
-- with ratings arrives in Milestone 3 and can grow from this shape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pitch = require(ReplicatedStorage.Shared.Pitch)

local TeamGen = {}

export type Player = {
	name: string,
	number: number,
	role: Pitch.Role,
}

-- TEMP name pools. Footballer-shaped with a little Roblox flavour.
local FIRST = {
	"Alfie", "Bartek", "Callum", "Dev", "Ezra", "Finn", "Gus", "Harvey", "Idris", "Jaxon",
	"Kofi", "Levi", "Mo", "Noah", "Oscar", "Pablo", "Quinn", "Rafa", "Sonny", "Theo",
	"Umar", "Vinnie", "Wes", "Xavi", "Yusuf", "Zack", "Blaze", "Kit", "Rocco", "Teddy",
}
local LAST = {
	"Abbott", "Brookes", "Cantwell", "Dunmore", "Ellery", "Fairweather", "Goss", "Hartigan", "Ings", "Jarvis",
	"Kettering", "Lomax", "Mbeki", "Nunes", "Oduya", "Pickering", "Quayle", "Rashford-Lee", "Sowerby", "Thorne",
	"Underhill", "Voss", "Wickham", "Xu", "Yarrow", "Zelinski", "Bloxham", "Noobington", "Skyward", "Fairbanks",
}

-- Bench roles are always outfield. TEMP: fixed shape until real squads exist.
local BENCH_ROLES: { Pitch.Role } = { "DEF", "MID", "MID", "FWD", "DEF" }

function TeamGen.generate(seed: number): { Player }
	local rng = Random.new(seed)
	local squad: { Player } = {}
	local used: { [string]: boolean } = {}

	local function uniqueName(): string
		while true do
			local name = FIRST[rng:NextInteger(1, #FIRST)] .. " " .. LAST[rng:NextInteger(1, #LAST)]
			if not used[name] then
				used[name] = true
				return name
			end
		end
	end

	for i, role in Pitch.ROLES do
		table.insert(squad, { name = uniqueName(), number = i, role = role })
	end
	for i, role in BENCH_ROLES do
		table.insert(squad, { name = uniqueName(), number = #Pitch.ROLES + i, role = role })
	end
	return squad
end

export type Sub = { out: number, ["in"]: number }

local MAX_SUBS = 3

-- Picks the next substitution: the most advanced remaining starter comes off
-- for the next unused bench player. TEMP: no fatigue/ratings yet, so the
-- order is fixed (11, 10, 9). Returns nil when no sub is possible.
function TeamGen.nextSub(squad: { Player }, made: { Sub }): Sub?
	if #made >= MAX_SUBS then
		return nil
	end
	local onBench = #Pitch.ROLES + #made + 1
	if not squad[onBench] then
		return nil
	end
	local subbedOut: { [number]: boolean } = {}
	for _, sub in made do
		subbedOut[sub.out] = true
	end
	for number = #Pitch.ROLES, 2, -1 do
		if not subbedOut[number] then
			return { out = number, ["in"] = onBench }
		end
	end
	return nil
end

return TeamGen
