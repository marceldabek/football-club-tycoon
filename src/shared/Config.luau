--!strict
-- Game configuration.
-- TEMP: every number in this file is a placeholder chosen to make the first
-- two matches feel good. Real economy tuning is an open question (CLAUDE.md §25).

local ClubCrest = require(script.Parent.ClubCrest)

local Config = {}

Config.MatchDurationSeconds = 90
-- Time between pressing Play Match and kickoff: iris transition + walkout.
-- X314: how full the ground is before kick-off, how much of it is left while
-- the leavers walk home, and how long before the last of them go. TEMP.
Config.CrowdEarlyShare = 0.35
Config.CrowdLeavingShare = 0.3
Config.CrowdEmptySeconds = 40

Config.WalkoutSeconds = 10

-- TEMP economy
Config.StartingCash = 0
-- X361: raised from 8 when away fixtures stopped paying a gate, so a season
-- still lands near the pacing that was measured at 00:26 (about 30k and a
-- promotion from a standing start). TEMP, and part of question 19.
Config.TicketPrice = 12
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
	-- X272: `prizeMultiplier` used to be a hand-set 1/2/4/8/16 while the money a
	-- division actually generates goes 1/2.3/5/10/20 with `demandBase`, so a
	-- title was worth less and less the higher the club climbed. League.prizeFor
	-- derives the multiplier from demandBase now; the field is gone.
	{ name = "Sunday Parks League", baseStrength = 44, demandBase = 600 },
	{ name = "County League", baseStrength = 52, demandBase = 1400 },
	{ name = "Regional Premier", baseStrength = 60, demandBase = 3000 },
	{ name = "National League", baseStrength = 68, demandBase = 6000 },
	{ name = "Premier Division", baseStrength = 76, demandBase = 12000 },
}
Config.TeamsPerDivision = 6 -- double round robin = 10 matches
Config.PromotionSpots = 2
Config.RelegationSpots = 2
-- End-of-season prize by final position, times the division's own money (see
-- League.prizeFor). TEMP, and raised by about two thirds in X272: at the top
-- the old schedule paid £48,000 for a title against roughly £600,000 of gate
-- income and a £60,000-£150,000 stand, so winning a league changed nothing.
-- A champion now takes £5,000 in the Sunday Parks League and £100,000 in the
-- Premier Division. See Questions for Marcel.
Config.PrizeByPosition = { 5000, 3000, 1800, 900, 700, 500 }

-- TEMP fictional opponent pools, one per division. 5 are drawn each season.
--
-- Each club owns two colours: `kit` is the shirt and the crest fill, `accent`
-- is the crest stroke and initials. They belong to the club rather than to a
-- squad slot, so a club looks the same in every table it ever appears in and
-- no two clubs in a division collide. The prose descriptions these were mixed
-- from are in docs/CRESTS.md, alongside the crest art prompts. `crest` is the
-- uploaded crest art, made by tools/prep_crests.py (ids in
-- assets/ui/crests/asset_ids.json).
export type Club = { name: string, kit: { number }, accent: { number }, crest: string? }

Config.Clubs = {
	{ -- Sunday Parks League
		{ name = "Bramblewick Rovers", kit = { 94, 32, 48 }, accent = { 240, 232, 210 }, crest = "rbxassetid://80005649982051" },
		{ name = "Oakhollow United", kit = { 32, 78, 46 }, accent = { 224, 176, 48 }, crest = "rbxassetid://70710877850593" },
		{ name = "Fenmoor Athletic", kit = { 88, 64, 44 }, accent = { 176, 206, 226 }, crest = "rbxassetid://127635815616084" },
		{ name = "Kestrel Green FC", kit = { 58, 142, 62 }, accent = { 245, 245, 245 }, crest = "rbxassetid://133529044971674" },
		{ name = "Ashby Wanderers", kit = { 26, 42, 84 }, accent = { 240, 240, 240 }, crest = "rbxassetid://98675295190843" },
		{ name = "Millpond Town", kit = { 92, 100, 108 }, accent = { 150, 204, 198 }, crest = "rbxassetid://118215410297780" },
		{ name = "Sunday Legends", kit = { 196, 44, 44 }, accent = { 30, 30, 32 }, crest = "rbxassetid://134936231917712" },
		{ name = "Hedgerow FC", kit = { 46, 92, 52 }, accent = { 198, 48, 44 }, crest = "rbxassetid://84743077103799" },
	},
	{ -- County League
		{ name = "Thornbury Town", kit = { 112, 30, 52 }, accent = { 110, 186, 228 }, crest = "rbxassetid://114213435453133" },
		{ name = "Redcliffe Rangers", kit = { 170, 66, 44 }, accent = { 226, 202, 160 }, crest = "rbxassetid://102185941845550" },
		{ name = "Saltmarsh United", kit = { 104, 126, 106 }, accent = { 240, 240, 236 }, crest = "rbxassetid://86431092760259" },
		{ name = "Wexford Vale", kit = { 20, 72, 48 }, accent = { 212, 172, 60 }, crest = "rbxassetid://131558361135538" },
		{ name = "Brindle Heath", kit = { 108, 62, 130 }, accent = { 62, 60, 62 }, crest = "rbxassetid://93073668770639" },
		{ name = "Copperfield Celtic", kit = { 184, 96, 42 }, accent = { 26, 132, 84 }, crest = "rbxassetid://106518266628291" },
		{ name = "Norbury Athletic", kit = { 30, 66, 168 }, accent = { 242, 242, 242 }, crest = "rbxassetid://110432272484035" },
		{ name = "Larkspur Rovers", kit = { 72, 96, 186 }, accent = { 238, 230, 206 }, crest = "rbxassetid://98618619404588" },
	},
	{ -- Regional Premier
		{ name = "Harrowgate City", kit = { 32, 140, 140 }, accent = { 214, 178, 72 }, crest = "rbxassetid://89136781947470" },
		{ name = "Blackwater Albion", kit = { 26, 26, 28 }, accent = { 242, 242, 242 }, crest = "rbxassetid://137483410788992" },
		{ name = "Ironbridge FC", kit = { 38, 40, 44 }, accent = { 230, 118, 34 }, crest = "rbxassetid://80624236355605" },
		{ name = "Greyfriars United", kit = { 120, 118, 112 }, accent = { 102, 26, 44 }, crest = "rbxassetid://107926702587019" },
		{ name = "Stonemoor Town", kit = { 126, 124, 118 }, accent = { 84, 116, 62 }, crest = "rbxassetid://92471280324009" },
		{ name = "Kingsmere Rovers", kit = { 28, 54, 122 }, accent = { 196, 200, 208 }, crest = "rbxassetid://81259684266159" },
		{ name = "Eastwick Athletic", kit = { 106, 28, 50 }, accent = { 232, 172, 40 }, crest = "rbxassetid://75114112965825" },
		{ name = "Dunmore Wanderers", kit = { 26, 62, 44 }, accent = { 238, 238, 234 }, crest = "rbxassetid://80649590047065" },
	},
	{ -- National League
		{ name = "Northgate United", kit = { 58, 96, 138 }, accent = { 240, 240, 242 }, crest = "rbxassetid://96691531768758" },
		{ name = "Silverton City", kit = { 188, 192, 198 }, accent = { 22, 34, 68 }, crest = "rbxassetid://138770016688524" },
		{ name = "Marlow Park FC", kit = { 38, 96, 82 }, accent = { 240, 242, 240 }, crest = "rbxassetid://121509247915821" },
		{ name = "Whitcombe Town", kit = { 238, 236, 228 }, accent = { 124, 30, 32 }, crest = "rbxassetid://136003139644576" },
		{ name = "Ravensmoor", kit = { 24, 24, 28 }, accent = { 118, 124, 134 }, crest = "rbxassetid://121156442509192" },
		{ name = "Castlebridge Albion", kit = { 206, 176, 108 }, accent = { 132, 28, 34 }, crest = "rbxassetid://95565014231839" },
		{ name = "Ferndale Athletic", kit = { 46, 104, 58 }, accent = { 28, 28, 30 }, crest = "rbxassetid://90842001941503" },
		{ name = "Highfield Rovers", kit = { 86, 42, 136 }, accent = { 242, 242, 244 }, crest = "rbxassetid://85944504314060" },
	},
	{ -- Premier Division
		{ name = "Royal Kingsbury", kit = { 74, 34, 118 }, accent = { 198, 166, 96 }, crest = "rbxassetid://93733984887730" },
		{ name = "Meridian City", kit = { 20, 32, 72 }, accent = { 110, 226, 120 }, crest = "rbxassetid://93037926006920" },
		{ name = "Old Aldgate", kit = { 96, 24, 44 }, accent = { 238, 232, 216 }, crest = "rbxassetid://106237213633529" },
		{ name = "Wentworth United", kit = { 18, 18, 20 }, accent = { 214, 190, 138 }, crest = "rbxassetid://117483564005068" },
		{ name = "Crownhill FC", kit = { 188, 32, 48 }, accent = { 244, 244, 244 }, crest = "rbxassetid://90872577899741" },
		{ name = "Lancaster Park", kit = { 192, 44, 44 }, accent = { 72, 78, 88 }, crest = "rbxassetid://94742145790594" },
		{ name = "Westbrook Athletic", kit = { 104, 178, 228 }, accent = { 56, 58, 64 }, crest = "rbxassetid://139127742926599" },
		{ name = "Sovereign Town", kit = { 206, 172, 78 }, accent = { 20, 26, 56 }, crest = "rbxassetid://113243549323776" },
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

-- Crest builder: the player's club picks its own colours now, so the kit an
-- opponent is kept clear of is `home` -- the club it is playing. Callers that
-- know the club pass it; with none, a client uses its own club (the one the
-- player is looking at) and anything else falls back to the default red.
local function contextHome(): Color3
	local folder = ClubCrest.localFolder()
	if folder then
		return (ClubCrest.colours(ClubCrest.forFolder(folder)))
	end
	return Config.HomeKit
end

function Config.pitchKit(kit: Color3, home: Color3?): Color3
	local hue, sat, val = Color3.toHSV(kit)
	if sat < CREST_MIN_SATURATION or val < 0.2 then
		return kit -- greyscale or very dark: never confusable, and a hue shift is a no-op
	end
	local homeHue, homeSat, homeVal = Color3.toHSV(home or contextHome())
	if homeSat < CREST_MIN_SATURATION or homeVal < 0.2 then
		return kit -- a black or white home side clashes with no hue
	end
	local gap = math.abs(hue - homeHue)
	gap = math.min(gap, 1 - gap)
	if gap >= CREST_HUE_CLEARANCE or math.abs(val - homeVal) > CREST_VALUE_TOLERANCE then
		return kit
	end
	return Color3.fromHSV((hue + 0.5) % 1, sat, val)
end

-- `isPlayer`: `name` is a player club, whose colours come from its crest
-- (ClubCrest.forClub). `home`: see pitchKit.
function Config.clubCrest(name: string?, isPlayer: boolean?, home: Color3?): (Color3, Color3)
	if isPlayer or name == nil or name == "" then
		return ClubCrest.colours(ClubCrest.forClub(name))
	end
	local known = crestByName[name]
	if known then
		-- X263: the designed colour, moved only if it would read as the home side
		return Config.pitchKit(known.kit, home), known.accent
	end
	local hash = 0
	for i = 1, #name do
		hash = (hash * 31 + name:byte(i)) % 360
	end
	return Config.pitchKit(Color3.fromHSV(hash / 360, 0.55, 0.55), home), Color3.fromRGB(240, 240, 240)
end

-- League crest art by club name. The player's club never has league art (its
-- crest comes from the crest builder), and neither does an unknown name, so
-- both keep the drawn shield.
local crestImageByName: { [string]: string } = {}
for _, tierClubs in Config.Clubs do
	for _, club in tierClubs do
		if club.crest then
			crestImageByName[club.name] = club.crest
		end
	end
end

function Config.clubCrestImage(name: string?, isPlayer: boolean?): string?
	if isPlayer or name == nil then
		return nil
	end
	return crestImageByName[name]
end

-- Squad (Milestone 3). All TEMP.
Config.StartingSquadOverall = 45

-- Card rarity from the overall alone, FIFA-style. Ascending, and the names
-- match the six card backgrounds in docs/CARD_BACKGROUND_PROMPTS.md. TEMP
-- thresholds set against Config.Divisions: a new club is bronze, silver
-- arrives around the Regional Premier (60), the Premier Division (76) is gold
-- standard, and Rare (blue), Epic (purple) and Legend (pearl) are the players
-- better than any division.
Config.Rarity = {
	{ name = "Bronze", min = 0 },
	{ name = "Silver", min = 55 },
	{ name = "Gold", min = 70 },
	{ name = "Rare", min = 82 },
	{ name = "Epic", min = 88 },
	{ name = "Legend", min = 94 },
}
-- The wonderkid (shiny) version of a card: a teenager (or 20) who rolled near
-- the top of the headroom range, 6..18. TEMP: about 1 prospect in 12.
Config.WonderkidMaxAge = 20
Config.WonderkidHeadroom = 16
Config.SquadMax = 20
Config.SquadMin = 14
Config.BenchSize = 5
-- X334: one injury at most, rolled inside the match sim at a minute, instead
-- of a per-starter roll after the whistle. 0.3 a match is about what the old
-- 4%% per starter came to across eleven of them. TEMP.
Config.MatchInjuryChance = 0.3
Config.InjuryMatches = { 1, 3 } -- how long they are out for, TEMP
Config.DevelopChance = 0.2 -- per eligible player per match, scaled by coach
-- X292: a £10,000 Pro Coach used to stop paying the day the youngsters turned
-- 24, because only under-24s could improve. Players in their prime still get
-- better, just slowly, and it is the coach that makes the difference. TEMP.
Config.DevelopChancePeak = 0.06 -- per player aged PeakFrom..PeakTo per match
Config.PeakFrom = 24
Config.PeakTo = 27
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

-- X333: `autoSubs` is how many substitutions the coach will make on his own
-- during a match. The hint pill has always sold him as the man who "picks the
-- team and brings your young players on", and CLAUDE.md s9 gives him automatic
-- substitutions, but nothing ever made one without the SUB button. TEMP.
-- X352: `misjudge` is how many rating points a coach can be wrong about a
-- player by when he picks the team. CLAUDE.md s9 lists "automatic lineup
-- quality" first among what a coach influences and the hint pill sells him as
-- the man who "picks the team", but `Squad.autoLineup` took no coach argument
-- at all - a club with no coach picked a bit-for-bit identical XI to a
-- 10,000 pound Pro Coach. TEMP.
Config.CoachLevels = {
	{ name = "No coach", cost = 0, strengthBonus = 0, developMultiplier = 1, autoSubs = 0, misjudge = 6, tacticsFrom = math.huge },
	{ name = "Volunteer Coach", cost = 800, strengthBonus = 2, developMultiplier = 1.5, autoSubs = 1, misjudge = 4, tacticsFrom = 78 },
	{ name = "Qualified Coach", cost = 4000, strengthBonus = 4, developMultiplier = 2, autoSubs = 2, misjudge = 2, tacticsFrom = 68 },
	{ name = "Pro Coach", cost = 10000, strengthBonus = 6, developMultiplier = 3, autoSubs = 3, misjudge = 0, tacticsFrom = 58 },
}
-- X271: `tacticsFrom` is the minute a coach starts reading the score and
-- changing the tactic himself (ATTACK behind, DEFEND ahead). TEMP: a better
-- coach reacts sooner. Nothing can change after about 80' (MatchSim.lockMinutes).
-- The minutes a coach thinks about his first, second and third change. TEMP:
-- an hour in, then the last twenty, then the last ten.
Config.AutoSubMinutes = { 60, 72, 82 }
-- Level 0 = no scout. Index = level (no zero entry). A new pack after every match.
-- Every pack is Config.PackSize cards (Marcel, 2026-09-21): a better scout buys
-- quality, reach abroad and a tighter ceiling, never a longer list.
-- X337: `potentialDoubt` is how wide a band the scout will commit a player's
-- ceiling to, in potential points. TEMP: ten points of doubt down to none.
Config.PackSize = 3
Config.ScoutLevels = {
	{ name = "Local Scout", cost = 600, overallBonus = 2, potentialBoost = 3, potentialDoubt = 10 },
	{ name = "Regional Scout", cost = 3000, overallBonus = 4, potentialBoost = 6, potentialDoubt = 7 },
	{ name = "Scouting Network", cost = 8000, overallBonus = 6, potentialBoost = 10, potentialDoubt = 5 },
	-- The top two exist so a club with five figures spare has something worth
	-- buying: prospects are generated around the squad's own average, so a bigger
	-- overallBonus is the only way cash turns into a genuinely better XI.
	{ name = "National Network", cost = 22000, overallBonus = 9, potentialBoost = 14, potentialDoubt = 3 },
	{ name = "Continental Network", cost = 60000, overallBonus = 12, potentialBoost = 18, potentialDoubt = 0 },
}
-- With no scout the pack still comes: lads who turned up asking for a trial.
-- Worse than the squad on average, so the first scout is still worth hiring. TEMP.
Config.WalkInPack = { name = "Walk-in trialists", overallBonus = -4, potentialBoost = 0, potentialDoubt = 12 }
-- The match-1 pack holds one card this much better than the weakest starter in
-- his position (CLAUDE.md s3: early rigging, never shown). TEMP.
Config.TrialistBonus = { 4, 6 }
-- Tier odds per pack card for a squad averaging 60, index = scout level + 1
-- (first row is no scout). Measured by SquadTest.packOddsAreDocumented (400
-- seeds x Config.PackSize cards per level), which fails if balancing moves
-- them by more than 3 points - update both together. A tier that never
-- occurred at a level is simply absent, not a zero row. These are measured
-- from the TEMP balancing inputs above (Config.Rarity, WalkInPack,
-- ScoutLevels) and move whenever those do.
Config.PackOdds = {
	{ Bronze = 0.404, Silver = 0.596 }, -- level 0: walk-in trialists
	{ Silver = 1.000 }, -- level 1: Local Scout
	{ Silver = 0.919, Gold = 0.081 }, -- level 2: Regional Scout
	{ Silver = 0.769, Gold = 0.231 }, -- level 3: Scouting Network
	{ Silver = 0.547, Gold = 0.453 }, -- level 4: National Network
	{ Silver = 0.323, Gold = 0.677 }, -- level 5: Continental Network
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
-- X353: `merchPerFan` is the club shop's take per fan through the gate.
-- CLAUDE.md s11 lists merchandise third among revenues, and the shop X300
-- stocked, lit and fitted with a window display on every plot contained no
-- money code at all - the one shop the player can walk into never sold a
-- thing, while the 6,000 pound tier was already called "Merch Stand". TEMP.
Config.AmenityLevels = {
	{ name = "Nothing", cost = 0, perFan = 0, merchPerFan = 0, demandBonus = 0 },
	{ name = "Snack Bar", cost = 1200, perFan = 2, merchPerFan = 0.6, demandBonus = 0.1 },
	-- X300 (TEMP rename): the plot already has a Club Shop building, and having
	-- two different things called that made the upgrade read as a no-op
	{ name = "Merch Stand", cost = 6000, perFan = 4, merchPerFan = 1.4, demandBonus = 0.2 },
	{ name = "Fan Zone", cost = 15000, perFan = 6, merchPerFan = 2.2, demandBonus = 0.35 },
}

Config.ClubName = "Your Club" -- TEMP: club naming flow is undecided
-- The default club colour: ClubCrest's "red", worn by a club that has not
-- picked a crest. A club's real kit is ClubCrest.colours(its crest).
Config.HomeKit = ClubCrest.colour("red")
Config.SeatColor = Color3.fromRGB(200, 40, 50) -- TEMP: seat colour customisation later (M4 §4)
-- Fictional pitch-side sponsors for the ad boards. Purely decorative for now.
-- X156: half are TEMP Rivermere businesses already seen round town (the
-- industrial estate's shed signs, the high street café), half stay playful
-- X309: the boards round the pitch were "purely decorative", so the second
-- revenue CLAUDE.md s11 lists (sponsorship) did not exist and the FINANCE tab
-- had one real income line. A sponsor pays per match, more in a higher
-- division and more for a better-known club. TEMP numbers.
-- X316: the forecourt bronze. A grassroots club has no statue; it appears with
-- the brick and the seats, and only for a servant with real service. TEMP.
Config.StatueFromTier = 3
Config.StatueMinApps = 20

-- X350: the running costs of a club, per match. Until now every negative
-- addCash in the game was a one-off purchase, `Economy.settle` had no cost
-- side at all, and a matchday could only ever *add* money - so no investment
-- could ever be wrong and a Pro Coach paid for himself for ever, against
-- CLAUDE.md s5 ("eventually poor club management should produce losses").
-- All TEMP.
--   WageShare       what a squad rated at its division's own standard costs,
--                   as a share of that matchday's income. Wages have to be a
--                   share of the gate rather than an absolute figure for the
--                   division: a brand-new club plays its first match in front
--                   of 150 people, and a bill sized for the division cost it
--                   4,120 against 1,880 of income - bankrupt on match 1
--                   (caught at 00:18 by playing the numbers through a new club)
--   WagePerPoint    how much dearer each rating point above the division's
--                   standard is. A *ratio* (the first version) could not
--                   produce a loss in the top two divisions at all: at tier 5
--                   even a 99-rated squad of 20 only reached 73% of income,
--                   because (99/76) is a much smaller ratio than (65/44).
--                   Points are the same everywhere, so poor management can
--                   lose money at any level (review at 00:29)
--   WageMinRatio    the floor, so a cheap squad is cheap but not free
--   WageSquadSize   the squad size WageShare is quoted for
--   StaffUpkeepShare the share of a coach's and scout's purchase price they
--                   cost to keep, every match
Config.WageShare = 0.3
Config.WageSquadSize = 16
Config.WagePerPoint = 0.08
Config.WageMinRatio = 0.4
Config.StaffUpkeepShare = 0.02

-- X353: at 100 popularity the club shop sells half again as much per fan
Config.MerchPopularityShare = 0.5

-- X351: what a club gets back for a player it has just signed. `Squad.value`
-- was `fee * ageFactor` with ageFactor 1 for anyone 23 or under, and every
-- prospect a scout finds is 27 or younger - so signing a player and releasing
-- him the same second refunded the whole fee.
--   ResaleShare        of his value before he has kicked a ball for the club
--   ResaleSettled      of his value once he is established
--   ResaleAppearances  appearances to get there
-- TEMP.
Config.ResaleShare = 0.6
Config.ResaleSettled = 0.9
Config.ResaleAppearances = 5

Config.SponsorBase = 250
Config.SponsorPopularityShare = 0.6 -- at 100 popularity the fee is 1.6x

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
	-- DataStore name. FINAL (decided 2026-09-21, docs/SOFT_LAUNCH.md SL4): beta saves
	-- carry over to the full game, so never rename this once the place is public.
	-- Change the save shape through Profile.MIGRATIONS instead.
	storeName = "ClubProfiles",
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

-- Background music while managing the club: piano/melodic house, all free
-- licensed Creator Store tracks (APM and DistroKid catalogs). Shuffled; ducked
-- during matches so the crowd carries the atmosphere. Marcel's picks 2026-09-21.
Config.Music = {
	"rbxassetid://111278862247359", -- Warm Emotional Deep House Melodic Drift (DistroKid)
	"rbxassetid://84232634449169", -- 9:04 (Melodic Deep House) (DistroKid)
	"rbxassetid://1837844566", -- Piano In My House (APM)
	"rbxassetid://1836049199", -- Deep House Piano (APM)
}
-- Played instead of Config.Music while the player's sky is dark (Sky's
-- SkyDark attribute), e.g. after a floodlit evening fixture.
Config.MusicNight = {
	"rbxassetid://95834013772321", -- Warm Keys at Midnight (DistroKid)
}
Config.MusicVolume = 0.16
Config.MusicMatchVolume = 0.05

-- Player card art, keyed by Config.Rarity name. Sources are in
-- assets/ui/cards/keyed/ (tools/key_cards.py); 683x1024, one shared outline.
Config.CardArt = {
	Bronze = "rbxassetid://81502558155007",
	Silver = "rbxassetid://106662608867026",
	Gold = "rbxassetid://129688585969020",
	Rare = "rbxassetid://125371905323922",
	Epic = "rbxassetid://138957017665116",
	Legend = "rbxassetid://95222178381866",
	Back = "rbxassetid://111886688815403",
}
Config.CardAspect = 683 / 1024
-- The glow behind a card as it turns, and the ink that reads on its art.
-- Measured: bronze, gold, rare and epic are dark everywhere a label sits (14-101
-- luminance) and only silver and legend are light, so only those two take dark ink.
Config.CardTint = {
	Bronze = { glow = Color3.fromRGB(176, 110, 60), ink = Color3.fromRGB(255, 233, 205) },
	Silver = { glow = Color3.fromRGB(200, 208, 220), ink = Color3.fromRGB(24, 28, 36) },
	Gold = { glow = Color3.fromRGB(255, 204, 72), ink = Color3.fromRGB(255, 241, 203) },
	Rare = { glow = Color3.fromRGB(70, 150, 255), ink = Color3.fromRGB(240, 246, 255) },
	Epic = { glow = Color3.fromRGB(176, 90, 255), ink = Color3.fromRGB(248, 240, 255) },
	Legend = { glow = Color3.fromRGB(255, 240, 200), ink = Color3.fromRGB(30, 24, 12) },
}
-- a prospect is nobody's player yet: a plain grey training top on his card
Config.ProspectKit = Color3.fromRGB(120, 126, 136)
-- Pack-opening SFX. slide/flip are free Roblox Creator Store sound effects;
-- sting is a free APM Music riser (same catalog as Config.Music above).
Config.PackAudio = {
	slide = "rbxassetid://9117209855", -- "Paper Cup Lift Out Of A Stack 18": paper drawn from a stack
	flip = "rbxassetid://4839809962", -- "cardPlace2": short card-on-card flip
	sting = "rbxassetid://1843084040", -- "Speed Rise": pitched up for the better tiers
}

return Config
