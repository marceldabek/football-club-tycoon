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
	assert(p.stands.East == 1 and p.stands.North == 0, "east plot starts built, the rest empty")
	assert(p.amenityLevel == 0, "amenity level")
	assert(p.club == nil and p.season == nil, "sections should start empty")
	assert(#p.history.seasons == 0, "history")
	assert(p.saveCount == 0 and p.createdAt == 100 and p.updatedAt == 100, "stamps")
end

function T.normalizeFillsMissing()
	local p, changed = Profile.normalize({ cash = 500 }, 7)
	assert(changed, "should report changes")
	assert(p.cash == 500, "cash kept")
	assert(p.stands.East == 1 and p.matchesPlayed == 0 and p.named == false, "defaults filled")
	assert(p.clubName == Config.ClubName, "default name")
	assert(p.version == Profile.VERSION, "version set")
	assert(#p.history.seasons == 0, "history filled")
end

function T.normalizeDropsWrongTypes()
	local p = Profile.normalize({ cash = "lots", stands = { East = 99, West = -3 }, amenityLevel = -1, clubName = 5, club = "junk", named = "yes" })
	assert(p.cash == Config.StartingCash, "string cash dropped")
	assert(p.stands.East == #Config.StandLevels, "stand level clamped up")
	assert(p.stands.West == 0, "stand level clamped down")
	assert(p.amenityLevel == 0, "amenity clamped")
	assert(p.clubName == Config.ClubName, "numeric name dropped")
	assert(p.club == nil, "junk club dropped")
	assert(p.named == false, "string named dropped")
end

function T.migratesV1StandLevel()
	-- v1 had a single stand; it becomes the east plot and the rest start empty
	local p, changed = Profile.normalize({ version = 1, standLevel = 3, cash = 10 })
	assert(changed, "migration counts as a change")
	assert(p.version == Profile.VERSION, "version bumped")
	assert(p.stands.East == 3, "old level moved to the east plot")
	assert(p.stands.West == 0 and p.stands.North == 0 and p.stands.South == 0, "other plots empty")
	assert(p.cash == 10, "rest of the profile survives")
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

-- X190: a long accented name is trimmed by letters, never mid-character
function T.longAccentedNameTrimsByLetters()
	local name = string.rep("é", Config.ClubNameMaxLength + 5)
	local p = Profile.normalize({ clubName = name })
	assert(utf8.len(p.clubName) == Config.ClubNameMaxLength, "trimmed to the letter limit, got " .. tostring(utf8.len(p.clubName)))
end

function T.settingsDefaultAndValidate()
	local p = Profile.new("Set FC", 1)
	assert(p.settings.music == true and p.settings.quality == "", "settings defaults")
	local raw: any = Profile.new("Set FC", 1)
	raw.settings = nil
	local out, changed = Profile.normalize(raw, 1)
	assert(out.settings.music == true and out.settings.quality == "", "missing settings get defaults")
	assert(not changed, "an older save without settings is not a repair")
	raw.settings = { music = false, quality = "Ultra" }
	out = Profile.normalize(raw, 1)
	assert(out.settings.music == false, "music choice kept")
	assert(out.settings.quality == "", "unknown quality dropped")
end

return T
