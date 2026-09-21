--!strict
-- First-visit onboarding: the owner names the club (step 1), then designs its
-- crest (step 2, CrestBuilder). Shown while ClubState.NeedsName is true and the
-- local player owns this club. "Found the club" sends the crest (ClubCrest
-- remote) and then the name; the server filters and applies the name and
-- clears the flag. A refused name comes back to step 1 with the crest kept.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ClubCrest = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClubCrest"))
local Theme = require(script.Parent.Theme)
local CrestBuilder = require(script.Parent.CrestBuilder)

local player = Players.LocalPlayer
local state = require(script.Parent.ClubRef).waitState()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local nameEvent = remotes:WaitForChild("ClubName") :: RemoteEvent
local crestEvent = remotes:WaitForChild("ClubCrest") :: RemoteEvent

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
	if keyboard <= 0 then
		card.frame.Position = UDim2.fromScale(0.5, 0.45)
		return
	end
	-- the card is centred in the height left above the keyboard. Both numbers
	-- are real screen pixels: the card's own Position is resolved by the
	-- ScreenGui, and its height already includes the fit scale. When there
	-- isn't room to centre it, pin its top to the top of the screen instead,
	-- so the title stays on screen and the button stays above the keyboard.
	local usable = math.max(viewport.Y - keyboard, 0)
	local height = card.frame.AbsoluteSize.Y
	local centre = usable / 2
	if height >= usable then
		centre = height / 2 + 8
	end
	card.frame.Position = UDim2.new(0.5, 0, 0, math.floor(centre))
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

local found = card.addButton("Next", "primary")
found.Name = "Found"

-- step 2's crest, kept across a trip back to step 1
local draft: ClubCrest.Spec? = nil
local pendingName = ""

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
	pendingName = name
	card.frame.Visible = false
	CrestBuilder.open({
		title = "DESIGN YOUR CREST",
		confirmText = "Found the club",
		backText = "Back",
		spec = draft or ClubCrest.forFolder(state),
		onBack = function()
			CrestBuilder.close()
			card.frame.Visible = true
		end,
		onConfirm = function(spec: ClubCrest.Spec)
			draft = spec
			CrestBuilder.setBusy("Founding…")
			crestEvent:FireServer(spec)
			nameEvent:FireServer(pendingName)
			-- the server toasts why a name was refused; the naming step comes
			-- back so the player can try another, with the crest kept
			task.delay(3, function()
				if get("NeedsName") == true and CrestBuilder.isOpen() then
					CrestBuilder.close()
					card.frame.Visible = true
					hint.Text = "Try another name."
					hint.TextColor3 = Theme.colors.bad
				end
				CrestBuilder.setBusy(nil)
			end)
		end,
	})
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
	if show and not card.frame.Visible and not CrestBuilder.isOpen() then
		box.Text = get("ClubName") or ""
		hint.Text = hintText
		hint.TextColor3 = Theme.colors.muted
	end
	if not show then
		if CrestBuilder.isOpen() and get("NeedsName") ~= true then
			CrestBuilder.close() -- founded
		end
		card.frame.Visible = false
	elseif not CrestBuilder.isOpen() then
		card.frame.Visible = true
	end
end

for _, key in { "NeedsName", "Phase", "OwnerUserId" } do
	state:GetAttributeChangedSignal(key):Connect(refresh)
end
refresh()
