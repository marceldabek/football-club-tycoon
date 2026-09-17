--!strict
-- Bus-stop fast travel menu (backlog E7.2). BusService fires BusMenu when the
-- player triggers a stop's ProximityPrompt; this shows one small card with the
-- destinations it sent (already ordered: clubs first, then town stops,
-- alphabetical within each group — see BusService.destinationsFor). Picking
-- one closes the iris, asks the server to teleport, then opens it again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Iris = require(script.Parent.Iris)

type Destination = { name: string, kind: string, label: string }

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local menuEvent = remotes:WaitForChild("BusMenu") :: RemoteEvent
local travelEvent = remotes:WaitForChild("BusTravel") :: RemoteEvent

local gui = Theme.screenGui("BusMenu", 7)
gui.Parent = player:WaitForChild("PlayerGui")

-- One card, reused for every stop: showMenu just clears and rebuilds the list,
-- so there is never more than one on screen at once.
local card = Theme.panel(gui, "Card", {
	Size = UDim2.fromOffset(360, 460),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
})

Theme.text(card, "RIVERMERE BUSES", "display", {
	Name = "Title",
	Size = UDim2.new(1, -70, 0, 32),
	Position = UDim2.fromOffset(20, 16),
})

local fromLabel = Theme.text(card, "", "muted", {
	Name = "From",
	Size = UDim2.new(1, -70, 0, 20),
	Position = UDim2.fromOffset(20, 50),
	TextSize = 14,
})

local closeButton = Theme.closeButton(card, {
	Position = UDim2.new(1, -44, 0, 12),
})

local list = Instance.new("ScrollingFrame")
list.Name = "Destinations"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(14, 84)
list.Size = UDim2.new(1, -28, 1, -100)
list.ScrollBarThickness = 5
list.ScrollBarImageTransparency = 0.4
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = card
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- ------------------------------------------------------------------- state

local buttons: { TextButton } = {}
local traveling = false

local function clearButtons()
	for _, b in buttons do
		b:Destroy()
	end
	table.clear(buttons)
end

local function setInteractive(enabled: boolean)
	closeButton.Active = enabled
	closeButton.AutoButtonColor = enabled
	for _, b in buttons do
		b.Active = enabled
		b.AutoButtonColor = enabled
	end
end

local function closeCard()
	card.Visible = false
	clearButtons()
end

local function travelTo(destinationName: string)
	if traveling then
		return
	end
	traveling = true
	setInteractive(false)
	Iris.close(0.35)
	task.wait(0.4)
	travelEvent:FireServer(destinationName)
	task.wait(0.6)
	Iris.open(0.5)
	traveling = false
	closeCard()
end

-- Mobile-friendly: 44px minimum tall, full width, one tap to travel.
local function addDestinationButton(order: number, dest: Destination)
	local variant: Theme.ButtonVariant = if dest.kind == "club" then "info" else "secondary"
	local button = Theme.button(list, dest.label, variant, {
		Name = ("Dest%d"):format(order),
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.padding(button, 0, 14)
	button.Activated:Connect(function()
		travelTo(dest.name)
	end)
	table.insert(buttons, button)
end

local function showMenu(payload: any)
	if traveling or type(payload) ~= "table" or type(payload.from) ~= "string" then
		return
	end
	clearButtons()
	fromLabel.Text = ("From: %s"):format(payload.from)
	local destinations = payload.destinations
	if type(destinations) == "table" then
		for i, dest in destinations :: { any } do
			if type(dest) == "table" and type(dest.name) == "string" and type(dest.kind) == "string" and type(dest.label) == "string" then
				addDestinationButton(i, dest :: Destination)
			end
		end
	end
	setInteractive(true)
	card.Visible = true
end

menuEvent.OnClientEvent:Connect(showMenu)
closeButton.Activated:Connect(closeCard)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or traveling then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and card.Visible then
		closeCard()
	end
end)
