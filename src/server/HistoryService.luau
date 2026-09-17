--!strict
-- Owns the club's history (one record per completed season). Publishes it as
-- JSON on ClubState.History and keeps the office trophy shelf in step.
-- History maths lives in History.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local History = require(ReplicatedStorage.Shared.History)
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)

local HistoryService = {}

local history: History.History = History.new()

local function publish()
	ClubState.set("History", HttpService:JSONEncode({
		seasons = history.seasons,
		servants = history.servants,
		honours = History.honours(history),
	}))
	ClubState.markDirty()
end

function HistoryService.init()
	history = History.new()
end

local REQUIRED = { "season", "tier", "division", "position", "outcome", "played", "won", "drawn", "lost", "gf", "ga", "points", "prize" }

local function validRecord(r: any): boolean
	if type(r) ~= "table" then
		return false
	end
	for _, key in REQUIRED do
		local v = r[key]
		if key == "division" or key == "outcome" then
			if type(v) ~= "string" then
				return false
			end
		elseif type(v) ~= "number" then
			return false
		end
	end
	return true
end

local function validServant(s: any): boolean
	return type(s) == "table"
		and type(s.name) == "string"
		and s.name ~= ""
		and type(s.age) == "number"
		and type(s.apps) == "number"
		and type(s.goals) == "number"
		and type(s.season) == "number"
end

-- nil = fresh history. Invalid records are dropped, not fatal.
function HistoryService.restore(data: any?)
	history = History.new()
	if type(data) == "table" and type(data.seasons) == "table" then
		for _, r in ipairs(data.seasons) do
			if validRecord(r) then
				History.recordSeason(history, r)
			else
				warn("[FCT] dropping invalid history record")
			end
		end
	end
	if type(data) == "table" and type(data.servants) == "table" then
		for _, s in ipairs(data.servants) do
			if validServant(s) then
				History.recordRetirement(history, s)
			else
				warn("[FCT] dropping invalid club servant")
			end
		end
	end
	publish()
	HistoryService.rebuildTrophies()
end

function HistoryService.serialize(): History.History
	return { seasons = table.clone(history.seasons), servants = table.clone(history.servants) }
end

-- X288: the players who retired at the end of `season` (X277).
function HistoryService.recordRetirements(retired: { any }, season: number)
	if #retired == 0 then
		return
	end
	-- X291: a retirement can change who the framed shirt belongs to
	for _, p in retired do
		History.recordRetirement(history, {
			name = p.name,
			age = p.age,
			apps = p.apps or 0,
			goals = p.goals or 0,
			season = season,
			number = p.number, -- X291: the shirt the framed one shows
		})
	end
	publish()
	HistoryService.rebuildTrophies()
end

function HistoryService.record(record: History.SeasonRecord)
	History.recordSeason(history, record)
	publish()
	-- X291: a promotion changes the wall too, not just a title
	HistoryService.rebuildTrophies()
end

function HistoryService.honours(): History.Honours
	return History.honours(history)
end

function HistoryService.rebuildTrophies()
	local honours = History.honours(history)
	WorldBuilder.buildTrophies(honours.titles)
	-- X291: the shelf only counted titles, so a club promoted four times with no
	-- division win had a bare office and nothing for the players who got it there
	WorldBuilder.buildHonours(honours.promotions, History.topServant(history))
end

return HistoryService
