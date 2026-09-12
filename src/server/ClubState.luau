--!strict
-- Single club state for the Milestone 1 prototype, replicated to clients as
-- attributes on ReplicatedStorage.ClubState.
-- TEMP: one shared club per server. Per-player clubs come with persistence (Milestone 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local ClubState = {}

-- Find-or-create so a second Luau VM (Studio command bar / MCP) shares the same state.
local folder = ReplicatedStorage:FindFirstChild("ClubState") :: Folder
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ClubState"
	folder.Parent = ReplicatedStorage
end
ClubState.Folder = folder

function ClubState.get(key: string): any
	return folder:GetAttribute(key)
end

function ClubState.set(key: string, value: any)
	folder:SetAttribute(key, value)
end

function ClubState.addCash(amount: number)
	ClubState.set("Cash", (ClubState.get("Cash") :: number) + amount)
end

function ClubState.capacity(): number
	local level = ClubState.get("StandLevel") :: number
	return Config.StandLevels[level].capacity
end

function ClubState.init()
	ClubState.set("Cash", Config.StartingCash)
	ClubState.set("StandLevel", 1)
	ClubState.set("Capacity", Config.StandLevels[1].capacity)
	ClubState.set("MatchesPlayed", 0)
	ClubState.set("Wins", 0)
	ClubState.set("Draws", 0)
	ClubState.set("Losses", 0)
	ClubState.set("Phase", "Manage") -- "Manage" | "Match"
	ClubState.set("HomeGoals", 0)
	ClubState.set("AwayGoals", 0)
	ClubState.set("TimeLeft", 0)
	ClubState.set("Opponent", "")
	ClubState.set("ClubName", Config.ClubName)
end

return ClubState
