--!strict
-- First-visit onboarding: the owner names the club and designs its crest on
-- one page (CrestBuilder with its name section). Shown while
-- ClubState.NeedsName is true and the local player owns this club. "Found the
-- club" sends the crest (ClubCrest remote) and then the name; the server
-- filters and applies the name and clears the flag. A refused name keeps the
-- page open with the crest as it was.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ClubCrest = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClubCrest"))
local CrestBuilder = require(script.Parent.CrestBuilder)

local player = Players.LocalPlayer
local state = require(script.Parent.ClubRef).waitState()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local nameEvent = remotes:WaitForChild("ClubName") :: RemoteEvent
local crestEvent = remotes:WaitForChild("ClubCrest") :: RemoteEvent
local toastEvent = remotes:WaitForChild("Toast") :: RemoteEvent
local lastRefusal: string? = nil

local function get(key: string): any
	return state:GetAttribute(key)
end

local founding = false -- the designer is open for founding, not an office edit
local sending = false

-- X205: the server only accepts these characters (Session.applyName)
local function problemWith(name: string): string?
	if (utf8.len(name) or #name) < Config.ClubNameMinLength then
		return ("Needs at least %d characters."):format(Config.ClubNameMinLength)
	end
	if not name:match("^[%w%s'%-%.]+$") then
		return "Only letters, numbers, spaces and ' - . please."
	end
	return nil
end

local function confirm(spec: ClubCrest.Spec, raw: string?)
	if sending then
		return
	end
	local name = (raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local problem = problemWith(name)
	if problem then
		CrestBuilder.setNameHint(problem)
		return
	end
	CrestBuilder.setNameHint(nil)
	lastRefusal = nil
	sending = true
	CrestBuilder.setBusy("Founding…")
	crestEvent:FireServer(spec)
	nameEvent:FireServer(name)
	-- the server toasts why a name was refused; the page stays open so the
	-- player can try another (SL14: the reason is copied under the box too,
	-- since the toast is easy to miss behind the card)
	task.delay(3, function()
		sending = false
		if get("NeedsName") == true and founding then
			CrestBuilder.setNameHint((lastRefusal or "Try another name.") .. " Or tap Suggest one.")
		end
		CrestBuilder.setBusy(nil)
	end)
end

toastEvent.OnClientEvent:Connect(function(message: unknown, ok: unknown)
	if sending and type(message) == "string" and not ok then
		lastRefusal = message
	end
end)

local function refresh()
	local isOwner = get("OwnerUserId") == player.UserId
	local show = get("NeedsName") == true and get("Phase") == "Manage" and isOwner
	if show and not founding then
		founding = true
		CrestBuilder.open({
			name = get("ClubName") or "",
			confirmText = "Found the club",
			spec = ClubCrest.forFolder(state),
			onConfirm = confirm,
		})
	elseif not show and founding then
		founding = false
		CrestBuilder.close() -- founded
	end
end

for _, key in { "NeedsName", "Phase", "OwnerUserId" } do
	state:GetAttributeChangedSignal(key):Connect(refresh)
end
refresh()
