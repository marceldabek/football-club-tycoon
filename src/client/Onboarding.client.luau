--!strict
-- First-visit onboarding: the owner names the club. Shown while
-- ClubState.NeedsName is true and the local player owns this club. The
-- server filters and applies the name (ClubName remote) and clears the flag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ClubState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local nameEvent = remotes:WaitForChild("ClubName") :: RemoteEvent

local function get(key: string): any
	return state:GetAttribute(key)
end

local gui = Theme.screenGui("Onboarding", 8)
gui.Parent = player:WaitForChild("PlayerGui")

local card = Theme.card(gui, "Card", "NAME YOUR CLUB", UDim2.fromOffset(480, 290), UDim2.fromScale(0.5, 0.45))
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

local hintText = ("%d to %d characters."):format(Config.ClubNameMinLength, Config.ClubNameMaxLength)
local hint = Theme.text(card.frame, hintText, "muted", {
	Name = "Hint",
	Size = UDim2.new(1, -40, 0, 20),
	Position = UDim2.fromOffset(20, 176),
	TextSize = 14,
})

local found = card.addButton("Found the club", "primary")
found.Name = "Found"

box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > Config.ClubNameMaxLength then
		box.Text = box.Text:sub(1, Config.ClubNameMaxLength)
	end
end)

local function submit()
	local name = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if #name < Config.ClubNameMinLength then
		hint.Text = ("Needs at least %d characters."):format(Config.ClubNameMinLength)
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
