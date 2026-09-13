--!strict
-- Game configuration.
-- TEMP: every number in this file is a placeholder chosen to make the first
-- two matches feel good. Real economy tuning is an open question (CLAUDE.md §25).

local Config = {}

Config.MatchDurationSeconds = 90
-- Time between pressing Play Match and kickoff: iris transition + walkout.
Config.WalkoutSeconds = 10

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

-- TEMP fictional opponents. Cycled by match index. Kit colours line up by index.
Config.OpponentNames = {
	"Bramblewick Rovers",
	"Oakhollow United",
	"Fenmoor Athletic",
	"Kestrel Green FC",
	"Ashby Wanderers",
}
Config.AwayKits = {
	Color3.fromRGB(240, 220, 60),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(40, 160, 220),
	Color3.fromRGB(60, 170, 80),
	Color3.fromRGB(150, 60, 200),
}

Config.ClubName = "Your Club" -- TEMP: club naming flow is undecided
Config.HomeKit = Color3.fromRGB(200, 40, 50) -- TEMP: kit customisation later
-- Fixed seed so the home squad's names stay the same match to match, so the
-- player can start recognising them. Real persistent squads arrive in Milestone 3.
Config.HomeSquadSeed = 1

Config.MaxSubs = 3

-- Matchday audio. All three are free Pro Sound Effects assets from Roblox's
-- licensed Creator Store library. An empty string disables that sound.
Config.Sounds = {
	crowdAmbient = "rbxassetid://9119562527", -- "Stadium Crowd 2": idling, cheering, walla (74s loop)
	goalCheer = "rbxassetid://9120973900", -- "Wrestling Crowd 2": short punchy cheers
	whistle = "rbxassetid://9118113825", -- "Referee Whistle 2": exterior single blast
}
Config.CrowdVolume = 0.35

-- Background music while managing the club (APM Music, free on the Creator
-- Store). Shuffled; ducked during matches so the crowd carries the atmosphere.
Config.Music = {
	"rbxassetid://1839272911", -- Easy Friends
	"rbxassetid://1846700210", -- Spirits High B
	"rbxassetid://1846690930", -- High Above B
}
Config.MusicVolume = 0.25
Config.MusicMatchVolume = 0.06

return Config
