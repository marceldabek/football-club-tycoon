--!strict
-- Generates fictional footballer names and throwaway opponent squads for the
-- matchday visuals. Pure and deterministic. The home club's persistent squad
-- with ratings lives in Squad.luau and reuses generateNames.

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

-- `count` distinct names drawn from the shared rng.
function TeamGen.generateNames(rng: Random, count: number): { string }
	local names: { string } = {}
	local used: { [string]: boolean } = {}
	while #names < count do
		local name = FIRST[rng:NextInteger(1, #FIRST)] .. " " .. LAST[rng:NextInteger(1, #LAST)]
		if not used[name] then
			used[name] = true
			table.insert(names, name)
		end
	end
	return names
end

-- Bench roles are always outfield. Fixed shape for opponents.
local BENCH_ROLES: { Pitch.Role } = { "DEF", "MID", "MID", "FWD", "DEF" }

-- An opponent's 16: starting XI in formation order plus a five-man bench.
function TeamGen.generate(seed: number): { Player }
	local rng = Random.new(seed)
	local names = TeamGen.generateNames(rng, #Pitch.ROLES + #BENCH_ROLES)
	local squad: { Player } = {}
	for i, role in Pitch.ROLES do
		table.insert(squad, { name = names[i], number = i, role = role })
	end
	for i, role in BENCH_ROLES do
		table.insert(squad, { name = names[#Pitch.ROLES + i], number = #Pitch.ROLES + i, role = role })
	end
	return squad
end

return TeamGen
