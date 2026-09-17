--!strict
-- First-visit onboarding: the owner names the club. Shown while
-- ClubState.NeedsName is true and the local player owns this club. The
-- server filters and applies the name (ClubName remote) and clears the flag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local state = require(script.Parent.ClubRef).waitState()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local nameEvent = remotes:WaitForChild("ClubName") :: RemoteEvent

local function get(key: string): any
	return state:GetAttribute(key)
end

local gui = Theme.screenGui("Onboarding", 8)
gui.Parent = player:WaitForChild("PlayerGui")

local card = Theme.card(gui, "Card", "NAME YOUR CLUB", UDim2.fromOffset(480, 290), UDim2.fromScale(0.5, 0.45))

-- X252: on a phone the on-screen keyboard covers the bottom of the card, and
-- "Found the club" sits on its bottom edge. Keep the card centred in whatever
-- height is left above the keyboard.
local function placeCard()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local keyboard = if UserInputService.OnScreenKeyboardVisible then UserInputService.OnScreenKeyboardSize.Y else 0
	local usable = math.max(viewport.Y - keyboard, 240)
	if keyboard <= 0 then
		card.frame.Position = UDim2.fromScale(0.5, 0.45)
		return
	end
	card.frame.Position = UDim2.new(0.5, 0, 0, math.floor(usable / 2))
end
UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(placeCard)
UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(placeCard)
placeCard()
card.body.Text = "This is your club now. Give it a name, or keep the one we picked."
card.body.Size = UDim2.new(1, -40, 0, 44)

local box = Instance.new("TextBox")
box.Name = "NameBox"
box.Size = UDim2.new(1, -40, 0, 46)
box.Position = UDim2.fromOffset(20, 124)
box.BackgroundColor3 = Theme.colors.bg2
box.BorderSizePixel = 0
box.Font = Theme.fonts.bold
box.TextSize = 20
box.TextColor3 = Theme.colors.text
box.PlaceholderColor3 = Theme.colors.muted
box.PlaceholderText = "Club name"
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = card.frame
Theme.corner(box, Theme.buttonRadius)
Theme.stroke(box)
Theme.padding(box, 0, 12)

-- X205: the server only accepts these characters (Session.applyName)
local hintText = ("%d to %d characters: letters, numbers, spaces, ' - ."):format(Config.ClubNameMinLength, Config.ClubNameMaxLength)
local hint = Theme.text(card.frame, hintText, "muted", {
	Name = "Hint",
	Size = UDim2.new(1, -40, 0, 20),
	Position = UDim2.fromOffset(20, 176),
	TextSize = 14,
})

local found = card.addButton("Found the club", "primary")
found.Name = "Found"

box:GetPropertyChangedSignal("Text"):Connect(function()
	-- X190: count letters, not bytes (an accented letter is two bytes)
	local length = utf8.len(box.Text) or #box.Text
	if length > Config.ClubNameMaxLength then
		local cut = utf8.offset(box.Text, Config.ClubNameMaxLength + 1)
		box.Text = if cut then box.Text:sub(1, cut - 1) else box.Text:sub(1, Config.ClubNameMaxLength)
	end
end)

local function submit()
	local name = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if (utf8.len(name) or #name) < Config.ClubNameMinLength then
		hint.Text = ("Needs at least %d characters."):format(Config.ClubNameMinLength)
		hint.TextColor3 = Theme.colors.bad
		return
	end
	if not name:match("^[%w%s'%-%.]+$") then
		hint.Text = "Only letters, numbers, spaces and ' - . please."
		hint.TextColor3 = Theme.colors.bad
		return
	end
	found.Text = "Founding…"
	nameEvent:FireServer(name)
	task.delay(3, function()
		found.Text = "Found the club"
	end)
end
found.Activated:Connect(submit)
box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submit()
	end
end)

local function refresh()
	local isOwner = get("OwnerUserId") == player.UserId
	local show = get("NeedsName") == true and get("Phase") == "Manage" and isOwner
	if show and not card.frame.Visible then
		box.Text = get("ClubName") or ""
		hint.Text = hintText
		hint.TextColor3 = Theme.colors.muted
	end
	card.frame.Visible = show
end

for _, key in { "NeedsName", "Phase", "OwnerUserId" } do
	state:GetAttributeChangedSignal(key):Connect(refresh)
end
refresh()
