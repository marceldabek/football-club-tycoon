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
	publish()
	HistoryService.rebuildTrophies()
end

function HistoryService.serialize(): History.History
	return { seasons = table.clone(history.seasons) }
end

function HistoryService.record(record: History.SeasonRecord)
	History.recordSeason(history, record)
	publish()
	if History.isTitle(record) then
		HistoryService.rebuildTrophies()
	end
end

function HistoryService.honours(): History.Honours
	return History.honours(history)
end

function HistoryService.rebuildTrophies()
	WorldBuilder.buildTrophies(History.honours(history).titles)
end

return HistoryService
