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

-- Attendance (Milestone 4). demand = demandBase * (0.5 + popularity/100) * (1 + amenity bonus)
Config.StartingPopularity = 20
Config.PopularityDelta = { Win = 3, Draw = 1, Loss = -2, Promoted = 10, Relegated = -10, Champions = 15 }

-- The fictional pyramid, bottom to top. TEMP names and numbers (CLAUDE.md §25).
-- baseStrength is what the squad's average overall has to keep up with.
Config.Divisions = {
	{ name = "Sunday Parks League", baseStrength = 44, demandBase = 600, prizeMultiplier = 1 },
	{ name = "County League", baseStrength = 52, demandBase = 1400, prizeMultiplier = 2 },
	{ name = "Regional Premier", baseStrength = 60, demandBase = 3000, prizeMultiplier = 4 },
	{ name = "National League", baseStrength = 68, demandBase = 6000, prizeMultiplier = 8 },
	{ name = "Premier Division", baseStrength = 76, demandBase = 12000, prizeMultiplier = 16 },
}
Config.TeamsPerDivision = 6 -- double round robin = 10 matches
Config.PromotionSpots = 2
Config.RelegationSpots = 2
-- End-of-season prize by final position, times the division multiplier.
Config.PrizeByPosition = { 3000, 2000, 1200, 600, 500, 400 }

-- TEMP fictional opponent pools, one per division. 5 are drawn each season.
Config.TeamNamePools = {
	{ "Bramblewick Rovers", "Oakhollow United", "Fenmoor Athletic", "Kestrel Green FC", "Ashby Wanderers", "Millpond Town", "Sunday Legends", "Hedgerow FC" },
	{ "Thornbury Town", "Redcliffe Rangers", "Saltmarsh United", "Wexford Vale", "Brindle Heath", "Copperfield Celtic", "Norbury Athletic", "Larkspur Rovers" },
	{ "Harrowgate City", "Blackwater Albion", "Ironbridge FC", "Greyfriars United", "Stonemoor Town", "Kingsmere Rovers", "Eastwick Athletic", "Dunmore Wanderers" },
	{ "Northgate United", "Silverton City", "Marlow Park FC", "Whitcombe Town", "Ravensmoor", "Castlebridge Albion", "Ferndale Athletic", "Highfield Rovers" },
	{ "Royal Kingsbury", "Meridian City", "Old Aldgate", "Wentworth United", "Crownhill FC", "Lancaster Park", "Westbrook Athletic", "Sovereign Town" },
}

-- Squad (Milestone 3). All TEMP.
Config.StartingSquadOverall = 45
Config.SquadMax = 20
Config.SquadMin = 14
Config.BenchSize = 5
Config.InjuryChance = 0.04 -- per starter per match
Config.DevelopChance = 0.2 -- per eligible player per match, scaled by coach
Config.DeclineChance = 0.06 -- per player aged 31+ per match

-- Level 0 = no coach. Index = level + 1.
Config.CoachLevels = {
	{ name = "No coach", cost = 0, strengthBonus = 0, developMultiplier = 1 },
	{ name = "Volunteer Coach", cost = 800, strengthBonus = 2, developMultiplier = 1.5 },
	{ name = "Qualified Coach", cost = 4000, strengthBonus = 4, developMultiplier = 2 },
	{ name = "Pro Coach", cost = 10000, strengthBonus = 6, developMultiplier = 3 },
}
-- Level 0 = no scout. Index = level (no zero entry). Shortlist refreshes every match.
Config.ScoutLevels = {
	{ name = "Local Scout", cost = 600, prospects = 3, overallBonus = 2, potentialBoost = 3 },
	{ name = "Regional Scout", cost = 3000, prospects = 4, overallBonus = 4, potentialBoost = 6 },
	{ name = "Scouting Network", cost = 8000, prospects = 5, overallBonus = 6, potentialBoost = 10 },
}

-- Stand chain. Level 1 is the starting stand. TEMP costs.
Config.StandLevels = {
	{ name = "Bleachers", capacity = 150, cost = 0 },
	{ name = "Main Stand", capacity = 400, cost = 1500 },
	{ name = "Double-tier Stand", capacity = 1000, cost = 9000 },
	{ name = "Covered Grandstand", capacity = 2500, cost = 30000 },
}
-- Concourse amenities. Level 0 = nothing. Values are cumulative. TEMP.
Config.AmenityLevels = {
	{ name = "Nothing", cost = 0, perFan = 0, demandBonus = 0 },
	{ name = "Snack Bar", cost = 1200, perFan = 2, demandBonus = 0.1 },
	{ name = "Club Shop", cost = 6000, perFan = 4, demandBonus = 0.2 },
	{ name = "Fan Zone", cost = 15000, perFan = 6, demandBonus = 0.35 },
}

-- Opponent kit colours, assigned in order to each season's teams.
Config.AwayKits = {
	Color3.fromRGB(240, 220, 60),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(40, 160, 220),
	Color3.fromRGB(60, 170, 80),
	Color3.fromRGB(150, 60, 200),
}

Config.ClubName = "Your Club" -- TEMP: club naming flow is undecided
Config.HomeKit = Color3.fromRGB(200, 40, 50) -- TEMP: kit customisation later
Config.SeatColor = Color3.fromRGB(200, 40, 50) -- TEMP: seat colour customisation later (M4 §4)
-- Fictional pitch-side sponsors for the ad boards. Purely decorative for now.
Config.Sponsors = {
	{ text = "BLOXBANK", bg = Color3.fromRGB(20, 60, 140), fg = Color3.new(1, 1, 1) },
	{ text = "SUNDAY PIES", bg = Color3.fromRGB(230, 200, 60), fg = Color3.fromRGB(40, 30, 10) },
	{ text = "KICKR SPORTS", bg = Color3.fromRGB(240, 240, 240), fg = Color3.fromRGB(20, 20, 20) },
	{ text = "OAKHOLLOW MOTORS", bg = Color3.fromRGB(40, 40, 40), fg = Color3.fromRGB(240, 200, 60) },
	{ text = "FIZZ COLA", bg = Color3.fromRGB(200, 30, 40), fg = Color3.new(1, 1, 1) },
	{ text = "NOOB ENERGY", bg = Color3.fromRGB(60, 180, 90), fg = Color3.fromRGB(10, 30, 15) },
}
-- Fixed seed so the home squad's names stay the same match to match, so the
-- player can start recognising them. Real persistent squads arrive in Milestone 3.
Config.HomeSquadSeed = 1

Config.MaxSubs = 3

-- Persistence (Milestone 5). TEMP values.
Config.Save = {
	storeName = "ClubProfiles", -- DataStore name; bump to reset every save during prototyping
	autosaveSeconds = 30, -- save this often while something changed
	loadRetries = 3,
	retryBackoffSeconds = 1,
}
-- Club naming (onboarding). TEMP: the naming flow is an open question (CLAUDE.md §25).
Config.ClubNameMinLength = 3
Config.ClubNameMaxLength = 24
Config.DefaultClubNameSuffix = " FC" -- default name is "<DisplayName> FC"
-- How many title trophies fit on the office shelf.
Config.TrophiesShown = 8

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
Config.MusicVolume = 0.16
Config.MusicMatchVolume = 0.05

return Config
