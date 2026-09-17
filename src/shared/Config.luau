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

-- Attendance (Milestone 4). demand = demandBase * (0.75 + popularity/60) * (1 + amenity bonus)
Config.StartingPopularity = 20
Config.PopularityDelta = { Win = 3, Draw = 1, Loss = -2, Promoted = 10, Relegated = -10, Champions = 15 }
-- X262 (TEMP): popularity used to reach 100 by about season 3 and stay there,
-- so wins stopped mattering and demand became a fixed number per division. At
-- each season end it drifts a quarter of the way toward a baseline for the
-- division it is now in, so a club has to keep winning to stay full.
Config.PopularityBaseline = { 24, 36, 48, 58, 66 }
Config.PopularitySeasonDrift = 0.25
-- How far this season's form can move demand, at ±1 per point of (wins - losses)
Config.FormDemandPerNet = 0.015
-- a 10-match season can reach ±10 net, so ±0.15 is the real ceiling
Config.FormDemandCap = 0.15

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
--
-- Each club owns two colours: `kit` is the shirt and the crest fill, `accent`
-- is the crest stroke and initials. They belong to the club rather than to a
-- squad slot, so a club looks the same in every table it ever appears in and
-- no two clubs in a division collide. The prose descriptions these were mixed
-- from are in docs/CRESTS.md, alongside the crest art prompts.
export type Club = { name: string, kit: { number }, accent: { number } }

Config.Clubs = {
	{ -- Sunday Parks League
		{ name = "Bramblewick Rovers", kit = { 94, 32, 48 }, accent = { 240, 232, 210 } },
		{ name = "Oakhollow United", kit = { 32, 78, 46 }, accent = { 224, 176, 48 } },
		{ name = "Fenmoor Athletic", kit = { 88, 64, 44 }, accent = { 176, 206, 226 } },
		{ name = "Kestrel Green FC", kit = { 58, 142, 62 }, accent = { 245, 245, 245 } },
		{ name = "Ashby Wanderers", kit = { 26, 42, 84 }, accent = { 240, 240, 240 } },
		{ name = "Millpond Town", kit = { 92, 100, 108 }, accent = { 150, 204, 198 } },
		{ name = "Sunday Legends", kit = { 196, 44, 44 }, accent = { 30, 30, 32 } },
		{ name = "Hedgerow FC", kit = { 46, 92, 52 }, accent = { 198, 48, 44 } },
	},
	{ -- County League
		{ name = "Thornbury Town", kit = { 112, 30, 52 }, accent = { 110, 186, 228 } },
		{ name = "Redcliffe Rangers", kit = { 170, 66, 44 }, accent = { 226, 202, 160 } },
		{ name = "Saltmarsh United", kit = { 104, 126, 106 }, accent = { 240, 240, 236 } },
		{ name = "Wexford Vale", kit = { 20, 72, 48 }, accent = { 212, 172, 60 } },
		{ name = "Brindle Heath", kit = { 108, 62, 130 }, accent = { 62, 60, 62 } },
		{ name = "Copperfield Celtic", kit = { 184, 96, 42 }, accent = { 26, 132, 84 } },
		{ name = "Norbury Athletic", kit = { 30, 66, 168 }, accent = { 242, 242, 242 } },
		{ name = "Larkspur Rovers", kit = { 72, 96, 186 }, accent = { 238, 230, 206 } },
	},
	{ -- Regional Premier
		{ name = "Harrowgate City", kit = { 32, 140, 140 }, accent = { 214, 178, 72 } },
		{ name = "Blackwater Albion", kit = { 26, 26, 28 }, accent = { 242, 242, 242 } },
		{ name = "Ironbridge FC", kit = { 38, 40, 44 }, accent = { 230, 118, 34 } },
		{ name = "Greyfriars United", kit = { 120, 118, 112 }, accent = { 102, 26, 44 } },
		{ name = "Stonemoor Town", kit = { 126, 124, 118 }, accent = { 84, 116, 62 } },
		{ name = "Kingsmere Rovers", kit = { 28, 54, 122 }, accent = { 196, 200, 208 } },
		{ name = "Eastwick Athletic", kit = { 106, 28, 50 }, accent = { 232, 172, 40 } },
		{ name = "Dunmore Wanderers", kit = { 26, 62, 44 }, accent = { 238, 238, 234 } },
	},
	{ -- National League
		{ name = "Northgate United", kit = { 58, 96, 138 }, accent = { 240, 240, 242 } },
		{ name = "Silverton City", kit = { 188, 192, 198 }, accent = { 22, 34, 68 } },
		{ name = "Marlow Park FC", kit = { 38, 96, 82 }, accent = { 240, 242, 240 } },
		{ name = "Whitcombe Town", kit = { 238, 236, 228 }, accent = { 124, 30, 32 } },
		{ name = "Ravensmoor", kit = { 24, 24, 28 }, accent = { 118, 124, 134 } },
		{ name = "Castlebridge Albion", kit = { 206, 176, 108 }, accent = { 132, 28, 34 } },
		{ name = "Ferndale Athletic", kit = { 46, 104, 58 }, accent = { 28, 28, 30 } },
		{ name = "Highfield Rovers", kit = { 86, 42, 136 }, accent = { 242, 242, 244 } },
	},
	{ -- Premier Division
		{ name = "Royal Kingsbury", kit = { 74, 34, 118 }, accent = { 198, 166, 96 } },
		{ name = "Meridian City", kit = { 20, 32, 72 }, accent = { 110, 226, 120 } },
		{ name = "Old Aldgate", kit = { 96, 24, 44 }, accent = { 238, 232, 216 } },
		{ name = "Wentworth United", kit = { 18, 18, 20 }, accent = { 214, 190, 138 } },
		{ name = "Crownhill FC", kit = { 188, 32, 48 }, accent = { 244, 244, 244 } },
		{ name = "Lancaster Park", kit = { 192, 44, 44 }, accent = { 72, 78, 88 } },
		{ name = "Westbrook Athletic", kit = { 104, 178, 228 }, accent = { 56, 58, 64 } },
		{ name = "Sovereign Town", kit = { 206, 172, 78 }, accent = { 20, 26, 56 } },
	},
}

-- Name -> colours, built once. Any UI holding only a club name can draw that
-- club's crest without the colours being threaded through its payload.
local crestByName: { [string]: { kit: Color3, accent: Color3 } } = {}
for _, tierClubs in Config.Clubs do
	for _, club in tierClubs do
		crestByName[club.name] = {
			kit = Color3.fromRGB(club.kit[1], club.kit[2], club.kit[3]),
			accent = Color3.fromRGB(club.accent[1], club.accent[2], club.accent[3]),
		}
	end
end

-- The player's club is named at runtime, so it is never in the table above and
-- falls through to the home kit. Any other unknown name gets a stable colour
-- derived from the name itself rather than a shared default, so a club added
-- later still reads as its own side until it is given real colours.
-- X263: every player club wears HomeKit, so an opponent whose colour sits on
-- the same hue puts two near-identical sides on the pitch for 90 seconds.
--
-- The review of the first attempt caught the real trap: the shirt was shifted
-- but the crest beside the club's name was not, which breaks the invariant in
-- League.luau ("the shirt in the 3D match has to agree with the crest drawn
-- beside its name in the table"). So there is one rule here, and both the crest
-- and the shirt go through it.
--
-- Only a kit that really could be mistaken for HomeKit is moved: close in hue
-- AND similarly bright and saturated. A dark claret or a brown is left alone.
local CREST_HUE_CLEARANCE = 0.09
local CREST_VALUE_TOLERANCE = 0.35
local CREST_MIN_SATURATION = 0.45

function Config.pitchKit(kit: Color3): Color3
	local hue, sat, val = Color3.toHSV(kit)
	if sat < CREST_MIN_SATURATION or val < 0.2 then
		return kit -- greyscale or very dark: never confusable, and a hue shift is a no-op
	end
	local homeHue, _, homeVal = Color3.toHSV(Config.HomeKit)
	local gap = math.abs(hue - homeHue)
	gap = math.min(gap, 1 - gap)
	if gap >= CREST_HUE_CLEARANCE or math.abs(val - homeVal) > CREST_VALUE_TOLERANCE then
		return kit
	end
	return Color3.fromHSV((hue + 0.5) % 1, sat, val)
end

function Config.clubCrest(name: string?, isPlayer: boolean?): (Color3, Color3)
	if isPlayer or name == nil or name == "" then
		return Config.HomeKit, Color3.fromRGB(245, 245, 245)
	end
	local known = crestByName[name]
	if known then
		-- X263: the designed colour, moved only if it would read as our own red
		return Config.pitchKit(known.kit), known.accent
	end
	local hash = 0
	for i = 1, #name do
		hash = (hash * 31 + name:byte(i)) % 360
	end
	return Config.pitchKit(Color3.fromHSV(hash / 360, 0.55, 0.55)), Color3.fromRGB(240, 240, 240)
end

-- Squad (Milestone 3). All TEMP.
Config.StartingSquadOverall = 45
Config.SquadMax = 20
Config.SquadMin = 14
Config.BenchSize = 5
Config.InjuryChance = 0.04 -- per starter per match
Config.DevelopChance = 0.2 -- per eligible player per match, scaled by coach
Config.DeclineChance = 0.06 -- per player aged 31+ per match

-- Level 0 = no coach. Index = level + 1.
-- X277: veterans retire at the end of a season. Nothing used to leave a squad:
-- ageing only counted up and decline floors at 30 OVR, so after a few seasons
-- the 20 shirts were full of 36-year-olds the player had to spot and release one
-- at a time. TEMP window: the first chance comes at RetireAge and nobody plays
-- on past RetireMaxAge.
Config.RetireAge = 34
Config.RetireChancePerYear = 0.3 -- 34 -> 30%, 35 -> 60%, 36 -> 90%
Config.RetireMaxAge = 37

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
	-- The top two exist so a club with five figures spare has something worth
	-- buying: prospects are generated around the squad's own average, so a bigger
	-- overallBonus is the only way cash turns into a genuinely better XI.
	{ name = "National Network", cost = 22000, prospects = 5, overallBonus = 9, potentialBoost = 14 },
	{ name = "Continental Network", cost = 60000, prospects = 6, overallBonus = 12, potentialBoost = 18 },
}

-- Stand chain, shared by every plot. Level 0 is an empty plot: open
-- hardstanding behind the perimeter wall, no seats. TEMP costs.
Config.StandLevels = {
	{ name = "Bleachers", capacity = 150, cost = 0 },
	{ name = "Main Stand", capacity = 400, cost = 1500 },
	{ name = "Double-tier Stand", capacity = 1000, cost = 9000 },
	{ name = "Covered Grandstand", capacity = 2500, cost = 30000 },
}

-- The four sides of the ground. Each is an independent plot on the same chain,
-- so the ground grows asymmetrically like a real lower-league ground.
-- `key` is the ClubState attribute suffix and the Profile field suffix.
-- `share` scales the chain's capacity: the ends are shallower than the sides.
-- East starts at level 1 (the club's one bleacher); the rest start empty.
Config.StandPlots = {
	{ key = "East", label = "East Stand", axis = "Z", sign = 1, share = 1, start = 1 },
	{ key = "West", label = "West Stand", axis = "Z", sign = -1, share = 1, start = 0 },
	{ key = "North", label = "North Terrace", axis = "X", sign = -1, share = 0.6, start = 0 },
	{ key = "South", label = "South Terrace", axis = "X", sign = 1, share = 0.6, start = 0 },
}

-- Seats a plot holds at a given level. Level 0 is an empty plot.
function Config.plotCapacity(plot: any, level: number): number
	if level < 1 then
		return 0
	end
	local entry = Config.StandLevels[math.min(level, #Config.StandLevels)]
	return math.floor(entry.capacity * plot.share + 0.5)
end

-- Concourse amenities. Level 0 = nothing. Values are cumulative. TEMP.
Config.AmenityLevels = {
	{ name = "Nothing", cost = 0, perFan = 0, demandBonus = 0 },
	{ name = "Snack Bar", cost = 1200, perFan = 2, demandBonus = 0.1 },
	{ name = "Club Shop", cost = 6000, perFan = 4, demandBonus = 0.2 },
	{ name = "Fan Zone", cost = 15000, perFan = 6, demandBonus = 0.35 },
}

Config.ClubName = "Your Club" -- TEMP: club naming flow is undecided
Config.HomeKit = Color3.fromRGB(200, 40, 50) -- TEMP: kit customisation later
Config.SeatColor = Color3.fromRGB(200, 40, 50) -- TEMP: seat colour customisation later (M4 §4)
-- Fictional pitch-side sponsors for the ad boards. Purely decorative for now.
-- X156: half are TEMP Rivermere businesses already seen round town (the
-- industrial estate's shed signs, the high street café), half stay playful
Config.Sponsors = {
	{ text = "DALETEK ENGINEERING", bg = Color3.fromRGB(20, 60, 140), fg = Color3.new(1, 1, 1) },
	{ text = "SUNDAY PIES", bg = Color3.fromRGB(230, 200, 60), fg = Color3.fromRGB(40, 30, 10) },
	{ text = "KICKR SPORTS", bg = Color3.fromRGB(240, 240, 240), fg = Color3.fromRGB(20, 20, 20) },
	{ text = "MILL LANE MOTORS", bg = Color3.fromRGB(40, 40, 40), fg = Color3.fromRGB(240, 200, 60) },
	{ text = "THE DAILY BEAN", bg = Color3.fromRGB(30, 44, 74), fg = Color3.fromRGB(236, 206, 124) },
	{ text = "NOOB ENERGY", bg = Color3.fromRGB(60, 180, 90), fg = Color3.fromRGB(10, 30, 15) },
}
-- Fixed seed so the home squad's names stay the same match to match, so the
-- player can start recognising them. Real persistent squads arrive in Milestone 3.
Config.HomeSquadSeed = 1

Config.MaxSubs = 3

-- Persistence (Milestone 5). TEMP values.
Config.Save = {
	storeName = "ClubProfiles", -- DataStore name; bump to reset every save during prototyping
	-- TEMP (overnight 2026-09-17, question 1 in docs/OVERNIGHT_LOG.md): Studio
	-- playtests use their own DataStore so agent tests never touch the live club.
	-- Set to "" to load your real club in Studio again.
	studioStoreSuffix = "_Studio",
	autosaveSeconds = 30, -- save this often while something changed
	-- TEMP: refresh the save lock this often; must stay well under lockMaxWaitSeconds
	-- so a waiting server sees this one's final save before it gives up waiting
	heartbeatSeconds = 10,
	loadRetries = 3,
	retryBackoffSeconds = 1,
	-- TEMP: save-lock timing (backlog B3.2, CLAUDE.md s27 "Save lock"). Tune once
	-- real servers show how long a stale session actually takes to notice.
	lockStaleSeconds = 90, -- a holder silent this long is treated as dead
	lockMaxWaitSeconds = 30, -- longest a new server waits before stealing anyway
	lockPollSeconds = 3, -- how often a waiting server rechecks the lock
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
