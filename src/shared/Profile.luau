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

local Profile = {}

Profile.VERSION = 1

export type Profile = {
	version: number,
	clubName: string,
	named: boolean,
	cash: number,
	standLevel: number,
	amenityLevel: number,
	matchesPlayed: number,
	wins: number,
	draws: number,
	losses: number,
	club: any?, -- ClubService.serialize() shape, nil = generate fresh
	season: any?, -- SeasonService.serialize() shape, nil = new season at tier 1
	history: { seasons: { any } },
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

function Profile.new(clubName: string, now: number?): Profile
	local t = now or os.time()
	return {
		version = Profile.VERSION,
		clubName = clubName,
		named = false,
		cash = Config.StartingCash,
		standLevel = 1,
		amenityLevel = 0,
		matchesPlayed = 0,
		wins = 0,
		draws = 0,
		losses = 0,
		club = nil,
		season = nil,
		history = { seasons = {} },
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
		if #name > Config.ClubNameMaxLength then
			name = name:sub(1, Config.ClubNameMaxLength)
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
		{ "standLevel", 1, 1, #Config.StandLevels },
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
	out.history = { seasons = seasons }

	return out :: Profile, changed
end

return Profile
