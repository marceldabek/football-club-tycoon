--!strict
-- First-visit onboarding: the owner names the club. Shown while
-- ClubState.NeedsName is true and the local player owns this club. The
-- server filters and applies the name (ClubName remote) and clears the flag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ClubState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local nameEvent = remotes:WaitForChild("ClubName") :: RemoteEvent

local function get(key: string): any
	return state:GetAttribute(key)
end

local gui = Instance.new("ScreenGui")
gui.Name = "Onboarding"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.Size = UDim2.fromOffset(460, 250)
card.Position = UDim2.fromScale(0.5, 0.45)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
card.BackgroundTransparency = 0.05
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = card

local function label(name: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = 17
	l.TextWrapped = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = card
	return l
end

label("Title", {
	Text = "NAME YOUR CLUB",
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextColor3 = Color3.fromRGB(255, 230, 150),
	Size = UDim2.new(1, -40, 0, 36),
	Position = UDim2.fromOffset(20, 16),
})
label("Body", {
	Text = "This is your club now. Give it a name (you can keep the one we picked).",
	TextColor3 = Color3.fromRGB(210, 210, 210),
	Size = UDim2.new(1, -40, 0, 44),
	Position = UDim2.fromOffset(20, 54),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})

local box = Instance.new("TextBox")
box.Name = "NameBox"
box.Size = UDim2.new(1, -40, 0, 44)
box.Position = UDim2.fromOffset(20, 108)
box.BackgroundColor3 = Color3.fromRGB(40, 48, 58)
box.BorderSizePixel = 0
box.Font = Enum.Font.GothamBold
box.TextSize = 20
box.TextColor3 = Color3.new(1, 1, 1)
box.PlaceholderText = "Club name"
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = card
local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 8)
boxCorner.Parent = box

local hint = label("Hint", {
	Text = ("%d to %d characters."):format(Config.ClubNameMinLength, Config.ClubNameMaxLength),
	TextSize = 14,
	TextColor3 = Color3.fromRGB(160, 160, 160),
	Size = UDim2.new(1, -40, 0, 20),
	Position = UDim2.fromOffset(20, 156),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local found = Instance.new("TextButton")
found.Name = "Found"
found.Size = UDim2.fromOffset(220, 44)
found.Position = UDim2.new(0.5, 0, 1, -16)
found.AnchorPoint = Vector2.new(0.5, 1)
found.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
found.Font = Enum.Font.GothamBold
found.TextSize = 20
found.TextColor3 = Color3.new(1, 1, 1)
found.Text = "Found the club"
found.Parent = card
local foundCorner = Instance.new("UICorner")
foundCorner.CornerRadius = UDim.new(0, 8)
foundCorner.Parent = found

-- keep the box within the limit as the player types
box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > Config.ClubNameMaxLength then
		box.Text = box.Text:sub(1, Config.ClubNameMaxLength)
	end
end)

local function submit()
	local name = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if #name < Config.ClubNameMinLength then
		hint.Text = ("Needs at least %d characters."):format(Config.ClubNameMinLength)
		hint.TextColor3 = Color3.fromRGB(255, 120, 120)
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
	if show and not card.Visible then
		box.Text = get("ClubName") or ""
		hint.Text = ("%d to %d characters."):format(Config.ClubNameMinLength, Config.ClubNameMaxLength)
		hint.TextColor3 = Color3.fromRGB(160, 160, 160)
	end
	card.Visible = show
end

for _, key in { "NeedsName", "Phase", "OwnerUserId" } do
	state:GetAttributeChangedSignal(key):Connect(refresh)
end
refresh()
