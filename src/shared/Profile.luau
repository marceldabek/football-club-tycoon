--!strict
-- The save schema: what a club looks like on disk. Pure and JSON-safe.
-- `new` builds a fresh profile; `normalize` takes whatever came back from the
-- DataStore and returns something every service can restore from, filling
-- gaps with defaults and dropping values of the wrong type. Deeper sections
-- (club, season, history) are only shape-checked here; the owning service
-- validates them on restore and regenerates on any problem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)

local Finance = require(script.Parent.Finance) -- X299
local ClubCrest = require(script.Parent.ClubCrest)

local Profile = {}

Profile.VERSION = 2

export type Profile = {
	version: number,
	clubName: string,
	named: boolean,
	cash: number,
	stands: { [string]: number }, -- level per Config.StandPlots key; 0 = empty plot
	amenityLevel: number,
	matchesPlayed: number,
	wins: number,
	draws: number,
	losses: number,
	club: any?, -- ClubService.serialize() shape, nil = generate fresh
	season: any?, -- SeasonService.serialize() shape, nil = new season at tier 1
	history: { seasons: { any }, servants: { any } }, -- X288 servants (review)
	-- X223: the owner's music switch and quality level ("" = pick by device)
	settings: { music: boolean, quality: string },
	finance: any, -- X299: Finance.Ledger, shape-checked by Finance.normalize
	crest: ClubCrest.Spec, -- the crest builder's pick; its colours are the club's kit
	createdAt: number,
	updatedAt: number,
	saveCount: number,
}

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function int(v: any, default: number, min: number?, max: number?): number
	local n = if isFiniteNumber(v) then math.floor(v) else default
	if min then
		n = math.max(n, min)
	end
	if max then
		n = math.min(n, max)
	end
	return n
end

-- A fresh ground: the east plot has the club's one bleacher, the rest are empty.
function Profile.newStands(): { [string]: number }
	local stands = {}
	for _, plot in Config.StandPlots do
		stands[plot.key] = plot.start
	end
	return stands
end

function Profile.new(clubName: string, now: number?): Profile
	local t = now or os.time()
	return {
		version = Profile.VERSION,
		clubName = clubName,
		named = false,
		cash = Config.StartingCash,
		stands = Profile.newStands(),
		amenityLevel = 0,
		matchesPlayed = 0,
		wins = 0,
		draws = 0,
		losses = 0,
		club = nil,
		season = nil,
		history = { seasons = {}, servants = {} },
		finance = Finance.new(),
		settings = { music = true, quality = "" },
		crest = ClubCrest.default(),
		createdAt = t,
		updatedAt = t,
		saveCount = 0,
	}
end

-- Lineup XIs are sparse when a slot is empty; DataStores reject holes.
function Profile.packXi(xi: { number }): { number }
	local packed = table.create(#Pitch.ROLES, 0)
	for slot = 1, #Pitch.ROLES do
		local id = xi[slot]
		packed[slot] = if type(id) == "number" and id ~= 0 then id else 0
	end
	return packed
end

function Profile.unpackXi(packed: { number }): { number }
	local xi: { number } = {}
	for slot = 1, #Pitch.ROLES do
		local id = packed[slot]
		if type(id) == "number" and id ~= 0 then
			xi[slot] = id
		end
	end
	return xi
end

-- Version upgrades. Each entry migrates from its index to index + 1.
local MIGRATIONS: { [number]: (any) -> () } = {}

-- v1 -> v2: one stand became four plots. The old level was the east stand.
-- A profile with no version at all also lands here, so leave an existing
-- `stands` table alone rather than overwriting it with defaults.
MIGRATIONS[1] = function(raw: any)
	if type(raw.stands) == "table" then
		raw.standLevel = nil
		return
	end
	local stands = Profile.newStands()
	if type(raw.standLevel) == "number" then
		stands.East = raw.standLevel
	end
	raw.stands = stands
	raw.standLevel = nil
end

-- Returns a profile every service can restore from, and whether anything
-- had to be changed (missing, invalid or migrated).
function Profile.normalize(raw: any, now: number?): (Profile, boolean)
	local t = now or os.time()
	local defaults = Profile.new(Config.ClubName, t)
	if type(raw) ~= "table" then
		return defaults, true
	end
	local changed = false

	local version = int(raw.version, 0, 0)
	while version < Profile.VERSION do
		local migrate = MIGRATIONS[version]
		if migrate then
			migrate(raw)
		end
		version += 1
		changed = true
	end

	local out: any = {}
	out.version = Profile.VERSION

	local name = raw.clubName
	if type(name) == "string" and #name > 0 then
		-- X190: trim by letters without splitting a multi-byte character
		if (utf8.len(name) or #name) > Config.ClubNameMaxLength then
			local cut = utf8.offset(name, Config.ClubNameMaxLength + 1)
			name = if cut then name:sub(1, cut - 1) else name:sub(1, Config.ClubNameMaxLength)
			changed = true
		end
		out.clubName = name
	else
		out.clubName = defaults.clubName
		changed = true
	end

	if type(raw.named) == "boolean" then
		out.named = raw.named
	else
		out.named = defaults.named
		changed = true
	end

	-- { key, default, min?, max? }
	local ints: { { any } } = {
		{ "cash", defaults.cash, 0, nil },
		{ "amenityLevel", 0, 0, #Config.AmenityLevels - 1 },
		{ "matchesPlayed", 0, 0, nil },
		{ "wins", 0, 0, nil },
		{ "draws", 0, 0, nil },
		{ "losses", 0, 0, nil },
		{ "createdAt", t, 0, nil },
		{ "updatedAt", t, 0, nil },
		{ "saveCount", 0, 0, nil },
	}
	for _, spec in ints do
		local key, default, min, max = spec[1], spec[2], spec[3], spec[4]
		local value = int(raw[key], default, min, max)
		out[key] = value
		if not isFiniteNumber(raw[key]) or value ~= raw[key] then
			changed = true
		end
	end

	-- stand plots: one level per side, clamped to the chain
	local rawStands = if type(raw.stands) == "table" then raw.stands else nil
	if not rawStands then
		changed = true
	end
	local stands = {}
	for _, plot in Config.StandPlots do
		local value = int(rawStands and rawStands[plot.key], plot.start, 0, #Config.StandLevels)
		stands[plot.key] = value
		if rawStands and value ~= rawStands[plot.key] then
			changed = true
		end
	end
	out.stands = stands

	if type(raw.club) == "table" then
		out.club = raw.club
	else
		out.club = nil
		if raw.club ~= nil then
			changed = true
		end
	end
	if type(raw.season) == "table" then
		out.season = raw.season
	else
		out.season = nil
		if raw.season ~= nil then
			changed = true
		end
	end

	-- settings are optional: saves from before X223 simply get the defaults
	local rawSettings = if type(raw.settings) == "table" then raw.settings else {}
	out.settings = {
		music = if type(rawSettings.music) == "boolean" then rawSettings.music else true,
		quality = if rawSettings.quality == "High" or rawSettings.quality == "Low" then rawSettings.quality else "",
	}

	-- crest is optional like settings: a save from before the crest builder
	-- gets the default (the old red and white), and an old save is not "changed"
	-- by merely lacking one
	local crest, crestChanged = ClubCrest.normalize(raw.crest)
	out.crest = crest
	if raw.crest ~= nil and crestChanged then
		changed = true
	end

	local seasons = {}
	if type(raw.history) == "table" and type(raw.history.seasons) == "table" then
		for _, record in ipairs(raw.history.seasons) do
			if type(record) == "table" then
				table.insert(seasons, record)
			else
				changed = true
			end
		end
	else
		changed = true
	end
	-- Review of X288: normalize rebuilt `history` from the seasons alone, so the
	-- club servants were thrown away by every single save. Shape-checked here
	-- the same way the season rows are; HistoryService re-sorts and re-caps.
	local servants = {}
	if type(raw.history) == "table" and type(raw.history.servants) == "table" then
		for _, s in ipairs(raw.history.servants) do
			if type(s) == "table" and type(s.name) == "string" and type(s.apps) == "number" then
				table.insert(servants, s)
			else
				changed = true
			end
		end
	end
	out.history = { seasons = seasons, servants = servants }
	-- X299: the ledger owns its own validation, so a save from an older build
	-- (or a corrupted one) comes back as an empty ledger rather than failing
	out.finance = Finance.normalize(raw.finance)

	return out :: Profile, changed
end

return Profile
