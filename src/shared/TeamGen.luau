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

return TeamGen
