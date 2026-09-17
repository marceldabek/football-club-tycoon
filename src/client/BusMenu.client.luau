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

-- Card sizing (X15). The card grows to fit every destination, up to 70% of
-- the screen height; past that the list scrolls. Rows are 44 tall (phone tap
-- size) with an 8 gap, the list starts 84 below the card top.
local CARD_W = 360
local HEADER_H = 84 -- title + "From:" line, where the list starts
local FOOTER_H = 16 -- space under the list
local ROW_H, ROW_GAP = 44, 8
local SCREEN_MARGIN = 12 -- never closer than this to a screen edge
local MAX_SCREEN_FRACTION = 0.7

-- One card, reused for every stop: showMenu just clears and rebuilds the list,
-- so there is never more than one on screen at once.
local card = Theme.panel(gui, "Card", {
	Size = UDim2.fromOffset(CARD_W, 460),
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
list.Position = UDim2.fromOffset(14, HEADER_H)
list.Size = UDim2.new(1, -28, 1, -(HEADER_H + FOOTER_H))
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 6
list.ScrollBarImageTransparency = 0.4
-- keep the bar beside the rows, not on top of their right edge
list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
-- Canvas height is set by hand from the layout below instead of
-- AutomaticCanvasSize, so it is always exactly the rows' height and the last
-- destinations can be scrolled fully into view (and so clicked: a button
-- clipped by the ScrollingFrame gets no input).
list.AutomaticCanvasSize = Enum.AutomaticSize.None
list.CanvasSize = UDim2.new()
list.Parent = card
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, ROW_GAP)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local function syncCanvas()
	list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y)
end
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncCanvas)

-- Fit the card to `rows` destinations and to the screen. Pure maths is in
-- cardHeight so the numbers are easy to check by hand:
--   1080p desktop: cap 756, 10 rows want 84 + 440 + 72 + 16 = 612 -> no scroll
--   720p window:   cap 504 -> list 404, ~7.5 rows visible, rest scroll
--   phone landscape (~390 tall): cap 273 -> list 173, ~3 rows, rest scroll
local function cardHeight(rows: number, viewportH: number): number
	local wanted = HEADER_H + rows * ROW_H + math.max(rows - 1, 0) * ROW_GAP + FOOTER_H
	local cap = math.floor(viewportH * MAX_SCREEN_FRACTION)
	-- always leave room for about two rows, unless the screen itself is shorter
	local floorH = math.min(HEADER_H + 2 * ROW_H + ROW_GAP + FOOTER_H, viewportH - 2 * SCREEN_MARGIN)
	return math.min(wanted, math.max(cap, floorH))
end

local rowCount = 0

local function layoutCard()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local width = math.min(CARD_W, math.floor(viewport.X) - 2 * SCREEN_MARGIN)
	card.Size = UDim2.fromOffset(width, cardHeight(rowCount, viewport.Y))
end

-- ------------------------------------------------------------------- state

local buttons: { TextButton } = {}
local traveling = false
-- X222: the server refuses travel away from a stop (20 studs) or within its 3 s
-- cooldown; mirror both so a refused trip never plays the fade
local WALK_AWAY_STUDS = 18 -- from the stop (server allows 20); from where it opened if unknown
local TRAVEL_COOLDOWN = 3.2
local openedAt: Vector3? = nil
local lastTravel = -math.huge

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function clearButtons()
	for _, b in buttons do
		b:Destroy()
	end
	table.clear(buttons)
	rowCount = 0
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
	openedAt = nil
	clearButtons()
end

local function travelTo(destinationName: string)
	if traveling then
		return
	end
	if os.clock() - lastTravel < TRAVEL_COOLDOWN then
		-- let the server say "Wait a moment." without fading the screen
		travelEvent:FireServer(destinationName)
		return
	end
	lastTravel = os.clock()
	traveling = true
	setInteractive(false)
	local ticket = Iris.close(0.35)
	task.wait(0.4)
	travelEvent:FireServer(destinationName)
	task.wait(0.6)
	-- re-checked here, not before the waits: a walkout can take the iris over
	-- during that second
	if Iris.owns(ticket) then
		Iris.open(0.5) -- X259: a walkout that took the iris over opens it itself
	end
	traveling = false
	closeCard()
end

-- Mobile-friendly: 44px minimum tall, full width, one tap to travel.
local function addDestinationButton(order: number, dest: Destination)
	local variant: Theme.ButtonVariant = if dest.kind == "club" then "info" else "secondary"
	local button = Theme.button(list, dest.label, variant, {
		Name = ("Dest%d"):format(order),
		Size = UDim2.new(1, 0, 0, ROW_H),
		LayoutOrder = order,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.padding(button, 0, 14)
	button.Activated:Connect(function()
		travelTo(dest.name)
	end)
	table.insert(buttons, button)
	rowCount += 1
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
	layoutCard()
	syncCanvas()
	list.CanvasPosition = Vector2.zero -- every new stop starts at the top
	setInteractive(true)
	card.Visible = true
	openedAt = if typeof(payload.stopPosition) == "Vector3" then payload.stopPosition else rootPosition()
end

-- close the card once the player walks away from the stop
task.spawn(function()
	while true do
		task.wait(0.5)
		if card.Visible and not traveling and openedAt then
			local at = rootPosition()
			if at and (at - (openedAt :: Vector3)).Magnitude > WALK_AWAY_STUDS then
				closeCard()
			end
		end
	end
end)

menuEvent.OnClientEvent:Connect(showMenu)

-- Refit when the window is resized or the phone rotates while the card is up.
local viewportConn: RBXScriptConnection? = nil
local function watchCamera()
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if card.Visible then
				layoutCard()
			end
		end)
	end
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
closeButton.Activated:Connect(closeCard)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or traveling then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and card.Visible then
		closeCard()
	end
end)
