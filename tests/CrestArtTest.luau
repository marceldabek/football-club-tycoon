--!strict
-- League crest art: every designed club has an uploaded crest, looked up by
-- name, and the drawn crest swaps between art and the plain shield in place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

local function crestModule()
	return require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Crest) :: any
end

function T.everyLeagueClubHasArt()
	local n = 0
	for _, tier in Config.Clubs do
		for _, club in tier do
			n += 1
			assert(type(club.crest) == "string" and (club.crest :: string):match("^rbxassetid://%d+$"), club.name .. " has no crest id")
			assert(Config.clubCrestImage(club.name) == club.crest, club.name .. " lookup")
		end
	end
	assert(n == 40, "40 clubs, got " .. n)
end

function T.noArtForPlayerOrUnknown()
	local first = Config.Clubs[1][1].name
	assert(Config.clubCrestImage(first, true) == nil, "player never gets league art")
	assert(Config.clubCrestImage(nil) == nil, "nil name")
	assert(Config.clubCrestImage("") == nil, "empty name")
	assert(Config.clubCrestImage("Nowhere Athletic") == nil, "unknown club")
end

function T.drawShowsArtForLeagueClub()
	local Crest = crestModule()
	local holder = Instance.new("Frame")
	local name = Config.Clubs[3][1].name
	local shield = Crest.draw(holder, name, 34)
	local art = shield:FindFirstChild("Art") :: ImageLabel
	assert(art and art.Visible and art.Image == Config.clubCrestImage(name), "art shown")
	assert(shield.BackgroundTransparency == 1, "fill hidden")
	local letters = shield:FindFirstChild("Initials") :: TextLabel
	assert(letters and not letters.Visible, "initials hidden")
	holder:Destroy()
end

function T.updateSwapsArtAndShield()
	local Crest = crestModule()
	local holder = Instance.new("Frame")
	local name = Config.Clubs[5][2].name
	local shield = Crest.draw(holder, name, 34)
	Crest.update(shield, "Rivermere Nobodies", true)
	local art = shield:FindFirstChild("Art") :: ImageLabel?
	assert(art == nil or not art.Visible, "art hidden for the player")
	assert(shield.BackgroundTransparency == 0, "fill back")
	assert((shield:FindFirstChild("Initials") :: TextLabel).Visible, "initials back")
	assert((shield:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled, "ring back")
	Crest.update(shield, name, false)
	assert((shield:FindFirstChild("Art") :: ImageLabel).Visible, "art again")
	local arts = 0
	for _, c in shield:GetChildren() do
		if c.Name == "Art" then
			arts += 1
		end
	end
	assert(arts == 1, "one Art child")
	holder:Destroy()
end

return T
