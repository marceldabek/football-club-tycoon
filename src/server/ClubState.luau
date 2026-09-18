--!strict
-- The club's replicated state: attributes on ReplicatedStorage.ClubState.
-- One club per server, owned by the first player to join (OwnerUserId).
-- The scalar half of the save (cash, stadium, record, name) lives here;
-- squad / season / history are published by their own services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Finance = require(ReplicatedStorage.Shared.Finance) -- X299
local PlotContext = require(script.Parent.PlotContext)

local ClubState = {}

-- ReplicatedStorage.Clubs.PlotN for a plot's copy of this module, or the old
-- ReplicatedStorage.ClubState without plots (docs/PLOTS.md). Find-or-create so
-- a second Luau VM (Studio command bar / MCP) shares the same state.
local folder = PlotContext.stateFolder()
ClubState.Folder = folder

-- Keys that are part of the save; changing one marks the profile dirty.
local PERSISTED: { [string]: boolean } = {
	Cash = true,
	AmenityLevel = true,
	MatchesPlayed = true,
	Wins = true,
	Draws = true,
	Losses = true,
	ClubName = true,
	SettingMusic = true,
	SettingQuality = true,
}
-- one persisted key per stand plot: Stand_East, Stand_West, ...
for _, plot in Config.StandPlots do
	PERSISTED["Stand_" .. plot.key] = true
end

-- Set by Session once a profile is loaded; nil before that.
ClubState.onDirty = nil :: (() -> ())?

function ClubState.markDirty()
	local hook = ClubState.onDirty
	if hook then
		hook()
	end
end

function ClubState.get(key: string): any
	return folder:GetAttribute(key)
end

local finance: Finance.Ledger = Finance.new()

local function publishFinance()
	folder:SetAttribute("Finance", HttpService:JSONEncode(finance))
	ClubState.markDirty()
end

function ClubState.set(key: string, value: any)
	local changed = folder:GetAttribute(key) ~= value
	folder:SetAttribute(key, value)
	if changed and PERSISTED[key] then
		ClubState.markDirty()
	end
end

-- X299: money moves through here and nowhere else, so this is where the ledger
-- is kept. `category` is one of Finance.INCOME / Finance.SPEND; the few places
-- that move money for no reportable reason (the debug `cash` command) pass nil.
-- X350: a matchday can settle at a loss now, and `Profile.normalize` has
-- always clamped a *saved* balance at zero, so the live balance is clamped the
-- same way - a club can be skint but never in debt (TEMP, question 24). The
-- ledger records what actually moved, not what was asked for.
function ClubState.addCash(amount: number, category: string?)
	local before = (ClubState.get("Cash") :: number) or 0
	local after = math.max(before + amount, 0)
	ClubState.set("Cash", after)
	if category then
		Finance.record(finance, category, after - before)
		publishFinance()
	end
end

function ClubState.recordMatchFinance(row: Finance.MatchRow)
	Finance.recordMatch(finance, row)
	publishFinance()
end

function ClubState.financeSnapshot(): Finance.Ledger
	return Finance.normalize(finance)
end

-- Stand plots. Each side of the ground has its own level on the shared chain;
-- level 0 is an empty plot. `StandLevel` is kept as a mirror of the east (main)
-- stand so the HUD's onboarding hint has one number to look at.
local function plotKey(plot: any): string
	return "Stand_" .. plot.key
end

function ClubState.plotLevel(plot: any): number
	return (ClubState.get(plotKey(plot)) :: number?) or 0
end

function ClubState.setPlotLevel(plot: any, level: number)
	ClubState.set(plotKey(plot), level)
	if plot.key == "East" then
		ClubState.set("StandLevel", level)
	end
	ClubState.set("Capacity", ClubState.capacity())
end

-- Levels keyed by plot key, the shape WorldBuilder.buildStands wants.
function ClubState.plotLevels(): { [string]: number }
	local levels = {}
	for _, plot in Config.StandPlots do
		levels[plot.key] = ClubState.plotLevel(plot)
	end
	return levels
end

function ClubState.capacity(): number
	local total = 0
	for _, plot in Config.StandPlots do
		total += Config.plotCapacity(plot, ClubState.plotLevel(plot))
	end
	return total
end

function ClubState.isOwner(player: Player): boolean
	return (ClubState.get("OwnerUserId") :: number?) == player.UserId
end

-- The owning Player while they are in the server.
function ClubState.owner(): Player?
	local id = ClubState.get("OwnerUserId") :: number?
	return if id and id ~= 0 then game:GetService("Players"):GetPlayerByUserId(id) else nil
end

function ClubState.init()
	ClubState.set("Phase", "Loading") -- "Loading" | "Manage" | "PreMatch" | "Match"
	ClubState.set("OwnerUserId", 0)
	ClubState.set("NeedsName", false) -- onboarding: owner still has to name the club
	ClubState.set("Cash", Config.StartingCash)
	for _, plot in Config.StandPlots do
		ClubState.set("Stand_" .. plot.key, plot.start)
	end
	ClubState.set("StandLevel", 1)
	ClubState.set("Capacity", ClubState.capacity())
	ClubState.set("MatchesPlayed", 0)
	ClubState.set("Wins", 0)
	ClubState.set("Draws", 0)
	ClubState.set("Losses", 0)
	ClubState.set("HomeGoals", 0)
	ClubState.set("AwayGoals", 0)
	ClubState.set("TimeLeft", 0)
	ClubState.set("MatchDuration", Config.MatchDurationSeconds)
	ClubState.set("KickoffAt", 0)
	ClubState.set("Opponent", "")
	ClubState.set("Attendance", 0)
	ClubState.set("Evening", false) -- this fixture kicks off under the floodlights
	ClubState.set("Tactic", "Balanced") -- "Balanced" | "Attack" | "Defend"
	ClubState.set("Subs", "[]") -- JSON list of { out = number, in = number }
	ClubState.set("Timeline", "") -- JSON published at PreMatch for the client presenter
	-- X344: the only two match attributes that did not exist before kick-off
	ClubState.set("InjuryNews", "")
	ClubState.set("InjuryMinute", 0)
	ClubState.set("ClubName", Config.ClubName)
	ClubState.set("Club", "") -- JSON squad / lineup / staff / shortlist (ClubService)
	ClubState.set("CoachLevel", 0)
	ClubState.set("ScoutLevel", 0)
	ClubState.set("AutoSquad", true)
	-- Season (SeasonService)
	ClubState.set("Tier", 1)
	ClubState.set("DivisionName", "")
	ClubState.set("Season", 1)
	ClubState.set("Round", 0) -- matches played this season
	ClubState.set("Rounds", 10)
	ClubState.set("Position", 1)
	ClubState.set("Popularity", Config.StartingPopularity)
	ClubState.set("Demand", 0)
	ClubState.set("NextOpponent", "")
	ClubState.set("AtHome", true) -- X310
	ClubState.set("LeagueTable", "[]") -- JSON standings
	ClubState.set("AmenityLevel", 0)
	ClubState.set("History", "{}") -- JSON { seasons, servants, honours } (HistoryService)
	finance = Finance.new()
	publishFinance()
end

-- The scalar half of the profile.
function ClubState.restore(p: Profile.Profile)
	ClubState.set("ClubName", p.clubName)
	ClubState.set("NeedsName", not p.named)
	ClubState.set("Cash", p.cash)
	for _, plot in Config.StandPlots do
		ClubState.set("Stand_" .. plot.key, p.stands[plot.key] or plot.start)
	end
	ClubState.set("StandLevel", ClubState.plotLevel(Config.StandPlots[1]))
	ClubState.set("Capacity", ClubState.capacity())
	ClubState.set("AmenityLevel", p.amenityLevel)
	ClubState.set("MatchesPlayed", p.matchesPlayed)
	ClubState.set("Wins", p.wins)
	ClubState.set("SettingMusic", p.settings.music)
	ClubState.set("SettingQuality", p.settings.quality)
	ClubState.set("Draws", p.draws)
	ClubState.set("Losses", p.losses)
	finance = Finance.normalize((p :: any).finance) -- X299
	publishFinance()
end

export type Scalars = {
	clubName: string,
	named: boolean,
	cash: number,
	stands: { [string]: number },
	amenityLevel: number,
	matchesPlayed: number,
	wins: number,
	draws: number,
	losses: number,
}

function ClubState.serialize(): Scalars
	return {
		clubName = ClubState.get("ClubName") :: string,
		named = not (ClubState.get("NeedsName") :: boolean),
		cash = ClubState.get("Cash") :: number,
		stands = ClubState.plotLevels(),
		amenityLevel = (ClubState.get("AmenityLevel") :: number?) or 0,
		matchesPlayed = ClubState.get("MatchesPlayed") :: number,
		wins = ClubState.get("Wins") :: number,
		draws = ClubState.get("Draws") :: number,
		losses = ClubState.get("Losses") :: number,
	}
end

return ClubState
