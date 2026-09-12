--!strict
-- Milestone 1 configuration.
-- TEMP: every number in this file is a placeholder chosen to make the first
-- two matches feel good. Real economy tuning is an open question (CLAUDE.md §25).

local Config = {}

Config.MatchDurationSeconds = 90

-- TEMP economy
Config.StartingCash = 0
Config.TicketPrice = 8
Config.WinBonus = 400
Config.DrawBonus = 150
Config.LossBonus = 0

-- TEMP: flat fan demand. Later driven by popularity / performance / amenities.
Config.BaseDemand = 420

-- TEMP: strength values feed the hidden sim. Squad system arrives in Milestone 3.
Config.HomeStrength = 50
Config.AwayStrength = 50

-- The one Milestone 1 upgrade. Level 1 is the starting stand.
Config.StandLevels = {
	{ name = "Bleachers", capacity = 150, cost = 0 },
	{ name = "North Stand", capacity = 400, cost = 1500 }, -- TEMP cost
}

-- TEMP fictional opponents. Cycled by match index.
Config.OpponentNames = {
	"Bramblewick Rovers",
	"Oakhollow United",
	"Fenmoor Athletic",
	"Kestrel Green FC",
	"Ashby Wanderers",
}

Config.ClubName = "Your Club" -- TEMP: club naming flow is undecided

return Config
