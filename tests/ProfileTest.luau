--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(ReplicatedStorage.Shared.Profile)
local Config = require(ReplicatedStorage.Shared.Config)
local Squad = require(ReplicatedStorage.Shared.Squad)
local League = require(ReplicatedStorage.Shared.League)

local T = {}

local function deepEqual(a: any, b: any, path: string?): (boolean, string?)
	local at = path or "root"
	if type(a) ~= type(b) then
		return false, ("%s: %s vs %s"):format(at, type(a), type(b))
	end
	if type(a) ~= "table" then
		if a ~= b then
			return false, ("%s: %s vs %s"):format(at, tostring(a), tostring(b))
		end
		return true
	end
	for k, v in a do
		local ok, err = deepEqual(v, b[k], at .. "." .. tostring(k))
		if not ok then
			return false, err
		end
	end
	for k in b do
		if a[k] == nil then
			return false, ("%s.%s missing on left"):format(at, tostring(k))
		end
	end
	return true
end

function T.newHasDefaults()
	local p = Profile.new("X FC", 100)
	assert(p.version == Profile.VERSION, "version")
	assert(p.clubName == "X FC", "name")
	assert(p.named == false, "named")
	assert(p.cash == Config.StartingCash, "cash")
	assert(p.standLevel == 1 and p.amenityLevel == 0, "levels")
	assert(p.club == nil and p.season == nil, "sections should start empty")
	assert(#p.history.seasons == 0, "history")
	assert(p.saveCount == 0 and p.createdAt == 100 and p.updatedAt == 100, "stamps")
end

function T.normalizeFillsMissing()
	local p, changed = Profile.normalize({ cash = 500 }, 7)
	assert(changed, "should report changes")
	assert(p.cash == 500, "cash kept")
	assert(p.standLevel == 1 and p.matchesPlayed == 0 and p.named == false, "defaults filled")
	assert(p.clubName == Config.ClubName, "default name")
	assert(p.version == Profile.VERSION, "version set")
	assert(#p.history.seasons == 0, "history filled")
end

function T.normalizeDropsWrongTypes()
	local p = Profile.normalize({ cash = "lots", standLevel = 99, amenityLevel = -1, clubName = 5, club = "junk", named = "yes" })
	assert(p.cash == Config.StartingCash, "string cash dropped")
	assert(p.standLevel == #Config.StandLevels, "stand level clamped")
	assert(p.amenityLevel == 0, "amenity clamped")
	assert(p.clubName == Config.ClubName, "numeric name dropped")
	assert(p.club == nil, "junk club dropped")
	assert(p.named == false, "string named dropped")
end

function T.normalizeKeepsValidUnchanged()
	local p = Profile.new("Keep FC", 50)
	p.named = true
	p.cash = 1234
	p.history.seasons = { { season = 1, tier = 1 } }
	local out, changed = Profile.normalize(p, 50)
	assert(not changed, "valid profile should not change")
	local ok, err = deepEqual(p, out)
	assert(ok, err)
end

function T.normalizeNonTable()
	local a, changedA = Profile.normalize(nil)
	local b, changedB = Profile.normalize("junk")
	assert(changedA and changedB, "should report change")
	assert(a.clubName == Config.ClubName and b.cash == Config.StartingCash, "should be defaults")
end

function T.packXiRoundTrip()
	local xi = { 5, 2, nil, 9, 1, 3, 4, 6, 7, 8, 10 }
	local packed = Profile.packXi(xi)
	assert(#packed == 11, "packed length")
	assert(packed[3] == 0, "hole becomes 0")
	local back = Profile.unpackXi(packed)
	assert(back[3] == nil, "0 becomes nil")
	for slot = 1, 11 do
		if slot ~= 3 then
			assert(back[slot] == xi[slot], "slot " .. slot)
		end
	end
end

function T.jsonRoundTrip()
	local p = Profile.new("Json FC", 1)
	local players = Squad.generate(3, 45)
	local lineup = Squad.autoLineup(players)
	p.club = {
		players = players,
		lineup = { xi = Profile.packXi(lineup.xi), bench = lineup.bench },
		autoSquad = true,
		coachLevel = 1,
		scoutLevel = 1,
		shortlist = Squad.prospects(4, 45, 1),
		nextId = 17,
	}
	p.season = { tier = 1, seasonNumber = 1, round = 0, popularity = 20, league = League.newSeason(1, 1, "Json FC", 1) }
	local back = HttpService:JSONDecode(HttpService:JSONEncode(p))
	local ok, err = deepEqual(p, back)
	assert(ok, err)
	local normalized, changed = Profile.normalize(back, 1)
	assert(not changed, "decoded profile should already be valid")
	assert(#normalized.club.players == 16, "players survived")
end

return T
