--!strict
-- The club's replicated state: attributes on ReplicatedStorage.ClubState.
-- One club per server, owned by the first player to join (OwnerUserId).
-- The scalar half of the save (cash, stadium, record, name) lives here;
-- squad / season / history are published by their own services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(ReplicatedStorage.Shared.Profile)

local ClubState = {}

-- Find-or-create so a second Luau VM (Studio command bar / MCP) shares the same state.
local folder = ReplicatedStorage:FindFirstChild("ClubState") :: Folder
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ClubState"
	folder.Parent = ReplicatedStorage
end
ClubState.Folder = folder

-- Keys that are part of the save; changing one marks the profile dirty.
local PERSISTED: { [string]: boolean } = {
	Cash = true,
	StandLevel = true,
	AmenityLevel = true,
	MatchesPlayed = true,
	Wins = true,
	Draws = true,
	Losses = true,
	ClubName = true,
}

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

function ClubState.set(key: string, value: any)
	local changed = folder:GetAttribute(key) ~= value
	folder:SetAttribute(key, value)
	if changed and PERSISTED[key] then
		ClubState.markDirty()
	end
end

function ClubState.addCash(amount: number)
	ClubState.set("Cash", (ClubState.get("Cash") :: number) + amount)
end

function ClubState.capacity(): number
	local level = ClubState.get("StandLevel") :: number
	return Config.StandLevels[level].capacity
end

function ClubState.isOwner(player: Player): boolean
	return (ClubState.get("OwnerUserId") :: number?) == player.UserId
end

function ClubState.init()
	ClubState.set("Phase", "Loading") -- "Loading" | "Manage" | "PreMatch" | "Match"
	ClubState.set("OwnerUserId", 0)
	ClubState.set("NeedsName", false) -- onboarding: owner still has to name the club
	ClubState.set("Cash", Config.StartingCash)
	ClubState.set("StandLevel", 1)
	ClubState.set("Capacity", Config.StandLevels[1].capacity)
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
	ClubState.set("Tactic", "Balanced") -- "Balanced" | "Attack" | "Defend"
	ClubState.set("Subs", "[]") -- JSON list of { out = number, in = number }
	ClubState.set("Timeline", "") -- JSON published at PreMatch for the client presenter
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
	ClubState.set("LeagueTable", "[]") -- JSON standings
	ClubState.set("AmenityLevel", 0)
	ClubState.set("History", "{}") -- JSON { seasons, honours } (HistoryService)
end

-- The scalar half of the profile.
function ClubState.restore(p: Profile.Profile)
	ClubState.set("ClubName", p.clubName)
	ClubState.set("NeedsName", not p.named)
	ClubState.set("Cash", p.cash)
	ClubState.set("StandLevel", p.standLevel)
	ClubState.set("Capacity", Config.StandLevels[p.standLevel].capacity)
	ClubState.set("AmenityLevel", p.amenityLevel)
	ClubState.set("MatchesPlayed", p.matchesPlayed)
	ClubState.set("Wins", p.wins)
	ClubState.set("Draws", p.draws)
	ClubState.set("Losses", p.losses)
end

export type Scalars = {
	clubName: string,
	named: boolean,
	cash: number,
	standLevel: number,
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
		standLevel = ClubState.get("StandLevel") :: number,
		amenityLevel = (ClubState.get("AmenityLevel") :: number?) or 0,
		matchesPlayed = ClubState.get("MatchesPlayed") :: number,
		wins = ClubState.get("Wins") :: number,
		draws = ClubState.get("Draws") :: number,
		losses = ClubState.get("Losses") :: number,
	}
end

return ClubState
