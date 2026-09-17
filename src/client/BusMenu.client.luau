--!strict
-- Bus-stop fast travel menu (backlog E7.2). BusService fires BusMenu when the
-- player triggers a stop's ProximityPrompt; this shows one small card with the
-- destinations it sent (already ordered: clubs first, then town stops,
-- alphabetical within each group — see BusService.destinationsFor). Picking
-- one closes the iris, asks the server to teleport, then opens it again.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Iris = require(script.Parent.Iris)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownPlan = require(ReplicatedStorage.Shared.TownPlan)

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
local HEADER_H = 84 -- title + "From:" line, where the plan starts
local FOOTER_H = 16 -- space under the list
local ROW_H, ROW_GAP = 44, 8
local SCREEN_MARGIN = 12 -- never closer than this to a screen edge
local MAX_SCREEN_FRACTION = 0.7
-- X324: the plan above the list. Dropped on a short screen (phone landscape is
-- about 390 tall), where the rows matter more than the map.
local PLAN_H, PLAN_GAP = 148, 12
local PLAN_MIN_SCREEN_H = 520

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

-- ------------------------------------------------------------------- the plan

-- X324: eleven place names told a first-time player nothing about which way
-- "Riverside Park" was, how far it was, or whether they could have walked it.
-- The plan is the town the way the map at a real stop draws it: the river, the
-- ring road, the four grounds, every stop as a dot, the stop you are standing
-- at in gold, and the one under your finger ringed and named. The static parts
-- are drawn once; only the two highlights move.
local plan = Instance.new("Frame")
plan.Name = "Plan"
plan.BackgroundColor3 = Theme.colors.bg2
plan.BorderSizePixel = 0
plan.ClipsDescendants = true -- the river and the ring road run off the paper
plan.Position = UDim2.fromOffset(14, HEADER_H)
plan.Size = UDim2.new(1, -28, 0, PLAN_H)
plan.Parent = card
Theme.corner(plan, Theme.cardRadius)
Theme.stroke(plan)

local PLAN_RIVER = Color3.fromRGB(58, 96, 132)
local PLAN_ROAD = Color3.fromRGB(86, 96, 110)
local PLAN_GROUND = Color3.fromRGB(64, 104, 72)
local DOT = 7
local planLayout = TownPlan.fit(CARD_W - 28, PLAN_H)

local function drawLine(a: Vector2, b: Vector2, thickness: number, colour: Color3, order: number)
	local d = b - a
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	line.Size = UDim2.fromOffset(d.Magnitude + thickness, thickness)
	line.Rotation = math.deg(math.atan2(d.Y, d.X))
	line.BackgroundColor3 = colour
	line.BorderSizePixel = 0
	line.ZIndex = order
	line.Parent = plan
end

local function drawPolyline(points: { Vector3 }, keep: number, thickness: number, colour: Color3, order: number)
	local thin = TownPlan.simplify(points, keep)
	for i = 1, #thin - 1 do
		drawLine(TownPlan.project(planLayout, thin[i]), TownPlan.project(planLayout, thin[i + 1]), thickness, colour, order)
	end
end

local function drawDot(at: Vector2, size: number, colour: Color3, order: number): Frame
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(at.X, at.Y)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = colour
	dot.BorderSizePixel = 0
	dot.ZIndex = order
	dot.Parent = plan
	Theme.corner(dot, size)
	return dot
end

do
	drawPolyline(TownLayout.RIVER.points, 8, 5, PLAN_RIVER, 1)
	for _, road in TownLayout.ROADS do
		if road.kind == "ring" then
			drawPolyline(road.points, 12, 2, PLAN_ROAD, 2)
		end
	end
	-- the four grounds: a little pitch-green square each, under its stop
	for _, plot in TownLayout.PLOTS do
		local at = TownPlan.project(planLayout, plot.centre)
		local square = Instance.new("Frame")
		square.Name = "Ground"
		square.AnchorPoint = Vector2.new(0.5, 0.5)
		square.Position = UDim2.fromOffset(at.X, at.Y)
		square.Size = UDim2.fromOffset(13, 13)
		square.BackgroundColor3 = PLAN_GROUND
		square.BorderSizePixel = 0
		square.ZIndex = 3
		square.Parent = plan
		Theme.corner(square, 3)
	end
	for _, stop in TownLayout.BUS_STOPS do
		drawDot(TownPlan.project(planLayout, stop.position), DOT, Theme.colors.muted, 4)
	end
end

-- "you are here" and "that one", the only two things that move
local here = drawDot(Vector2.zero, DOT + 6, Theme.colors.accent, 5)
here.Name = "Here"
here.Visible = false
local there = drawDot(Vector2.zero, DOT + 4, Theme.colors.info, 6)
there.Name = "There"
there.Visible = false
local LABEL_SIZE = 13
local thereLabel = Theme.text(plan, "", "bold", {
	Name = "ThereLabel",
	Size = UDim2.fromOffset(60, 18),
	TextSize = LABEL_SIZE,
	TextXAlignment = Enum.TextXAlignment.Center,
	BackgroundColor3 = Theme.colors.bg,
	BackgroundTransparency = 0.25,
	ZIndex = 7,
	Visible = false,
})
Theme.corner(thereLabel, 6)

-- which way is up, since the plan has no street names on it
Theme.text(plan, "N", "bold", {
	Name = "North",
	Size = UDim2.fromOffset(16, 16),
	Position = UDim2.fromOffset(6, 4),
	TextSize = 12,
	TextColor3 = Theme.colors.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})
Theme.text(plan, "\u{2191}", "bold", {
	Name = "NorthArrow",
	Size = UDim2.fromOffset(16, 14),
	Position = UDim2.fromOffset(6, 18),
	TextSize = 12,
	TextColor3 = Theme.colors.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- Keeps the name on the paper: centred above its dot, below it instead when the
-- dot is at the top edge, and never hanging off either side. (It sat beside the
-- dot at first and ran straight across the "you are here" gold.)
local function pointAt(name: string?)
	local stop = if name then TownPlan.stop(name) else nil
	if not stop then
		there.Visible = false
		thereLabel.Visible = false
		return
	end
	local at = TownPlan.project(planLayout, stop.position)
	there.Position = UDim2.fromOffset(at.X, at.Y)
	there.Visible = true
	-- centred above its dot, below it at the top edge, never off either side
	-- (it sat beside the dot at first and ran across the "you are here" gold).
	-- Measured rather than a fixed 150 wide, or the backing reads as a bar
	-- across the map instead of a label on it.
	thereLabel.Text = name :: string
	local measured = TextService:GetTextSize(name :: string, LABEL_SIZE, Theme.fonts.bold, Vector2.new(planLayout.width, 40))
	local w = math.min(measured.X + 12, planLayout.width - 4)
	thereLabel.Size = UDim2.fromOffset(w, 18)
	local x = math.clamp(at.X - w / 2, 2, math.max(planLayout.width - w - 2, 2))
	local above = at.Y - 24
	thereLabel.Position = UDim2.fromOffset(x, if above >= 2 then above else at.Y + 8)
	thereLabel.Visible = true
end

local function markHere(name: string?)
	local stop = if name then TownPlan.stop(name) else nil
	if not stop then
		here.Visible = false
		return
	end
	local at = TownPlan.project(planLayout, stop.position)
	here.Position = UDim2.fromOffset(at.X, at.Y)
	here.Visible = true
end

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
--   1080p desktop: cap 756, 10 rows want 244 + 440 + 72 + 16 = 772 -> scrolls a row
--   720p window:   cap 504 -> list 244, ~4.5 rows visible, rest scroll
--   phone landscape (~390 tall): no plan, cap 273 -> list 173, ~3 rows, rest scroll
-- X324: the plan is only drawn where there is room for it; the list starts
-- under the header plus whatever the plan took.
local function planFor(viewportH: number): number
	return if viewportH >= PLAN_MIN_SCREEN_H then PLAN_H + PLAN_GAP else 0
end

local function cardHeight(rows: number, viewportH: number): number
	local top = HEADER_H + planFor(viewportH)
	local wanted = top + rows * ROW_H + math.max(rows - 1, 0) * ROW_GAP + FOOTER_H
	local cap = math.floor(viewportH * MAX_SCREEN_FRACTION)
	-- always leave room for about two rows, unless the screen itself is shorter
	local floorH = math.min(top + 2 * ROW_H + ROW_GAP + FOOTER_H, viewportH - 2 * SCREEN_MARGIN)
	return math.min(wanted, math.max(cap, floorH))
end

local rowCount = 0

local function layoutCard()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local width = math.min(CARD_W, math.floor(viewport.X) - 2 * SCREEN_MARGIN)
	card.Size = UDim2.fromOffset(width, cardHeight(rowCount, viewport.Y))
	-- X324: the plan comes and goes with the room for it, and the list follows
	local planBlock = planFor(viewport.Y)
	plan.Visible = planBlock > 0
	local top = HEADER_H + planBlock
	list.Position = UDim2.fromOffset(14, top)
	list.Size = UDim2.new(1, -28, 1, -(top + FOOTER_H))
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
	pointAt(nil) -- X324: nothing is under the finger once the card is shut
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
-- X324: with how far it is on foot from the stop you are standing at, and the
-- plan above pointing at it while the row is under the pointer.
local function addDestinationButton(order: number, dest: Destination, fromStop: Vector3?)
	local variant: Theme.ButtonVariant = if dest.kind == "club" then "info" else "secondary"
	local button = Theme.button(list, dest.label, variant, {
		Name = ("Dest%d"):format(order),
		Size = UDim2.new(1, 0, 0, ROW_H),
		LayoutOrder = order,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.padding(button, 0, 14)
	local to = TownPlan.stop(dest.name)
	if fromStop and to then
		local studs = TownPlan.flatDistance(fromStop, to.position)
		-- the row's own text is left-aligned inside 14 of padding; the distance
		-- sits at the right-hand end of the same row, in cash green when it is
		-- close enough to walk
		local away = Theme.text(button, TownPlan.walkLabel(studs), "muted", {
			Name = "Away",
			Size = UDim2.new(0, 112, 1, 0),
			Position = UDim2.new(1, -112, 0, 0),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			-- muted grey vanished on the blue club rows
			TextColor3 = if TownPlan.isWalkable(studs) then Theme.colors.cash else Color3.fromRGB(214, 222, 232),
		})
		away.ZIndex = 2
		-- and a long club name gives way to it rather than running underneath
		button.TextTruncate = Enum.TextTruncate.AtEnd
	end
	button.MouseEnter:Connect(function()
		pointAt(dest.name)
	end)
	button.SelectionGained:Connect(function()
		pointAt(dest.name)
	end)
	button.Activated:Connect(function()
		pointAt(dest.name) -- a tap on a phone sends no MouseEnter first
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
	-- X324: distances are measured from the stop the card was opened at, not
	-- from the character, so they do not drift while it is open
	local fromStop = TownPlan.stop(payload.from)
	local fromPosition = if fromStop
		then fromStop.position
		elseif typeof(payload.stopPosition) == "Vector3" then payload.stopPosition
		else nil
	markHere(payload.from)
	pointAt(nil)
	local destinations = payload.destinations
	if type(destinations) == "table" then
		for i, dest in destinations :: { any } do
			if type(dest) == "table" and type(dest.name) == "string" and type(dest.kind) == "string" and type(dest.label) == "string" then
				addDestinationButton(i, dest :: Destination, fromPosition)
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
