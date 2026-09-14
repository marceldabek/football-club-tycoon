--!strict
-- Club Office panel: Squad / Scouting / Staff. Opened from the office computer
-- prompt or the CLUB button. Reads ClubState.Club (JSON) and sends actions over
-- the ClubAction remote; the server replies with toasts. Built in code,
-- deliberately plain. Closes itself when a matchday starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local LineupBoard = require(script.Parent.LineupBoard)
local Headshot = require(script.Parent.Headshot)

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ClubState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionEvent = remotes:WaitForChild("ClubAction") :: RemoteEvent

type Player = {
	id: number,
	name: string,
	number: number,
	role: string,
	age: number,
	overall: number,
	potential: number,
	injured: number,
	apps: number,
	goals: number,
	fee: number?,
	look: number?,
}
type Club = {
	players: { Player },
	lineup: { xi: { number }, bench: { number } },
	autoSquad: boolean,
	coachLevel: number,
	scoutLevel: number,
	shortlist: { Player },
}

local money = Theme.money

local function get(key: string): any
	return state:GetAttribute(key)
end

local function loadClub(): Club?
	local raw = get("Club")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local club = HttpService:JSONDecode(raw)
	-- JSON turns sparse arrays into objects with string keys; normalise the XI
	local xi = {}
	for k, v in club.lineup.xi do
		xi[tonumber(k) :: number] = v
	end
	club.lineup.xi = xi
	return club
end

-- ---------------------------------------------------------------- widgets

local gui = Theme.screenGui("ClubPanel", 5)
gui.Parent = player:WaitForChild("PlayerGui")

local PANEL_BG = Theme.colors.bg
local ROW_BG = Theme.colors.bg2
local ROW_ALT = Theme.colors.bg3
local ACCENT = Theme.colors.accent
local GREEN = Theme.colors.good
local RED = Theme.colors.bad
local GREY = Theme.colors.muted

local function label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	return Theme.text(parent, text, "body", props)
end

-- Colour picks the variant so the call sites read the same as before.
local function button(parent: Instance, text: string, color: Color3, props: { [string]: any }?): TextButton
	local variant: Theme.ButtonVariant = "secondary"
	if color == GREEN then
		variant = "primary"
	elseif color == RED or color == Color3.fromRGB(90, 60, 60) then
		variant = "danger"
	elseif color == Theme.colors.info then
		variant = "info"
	end
	local merged: { [string]: any } = { Size = UDim2.fromOffset(160, 32) }
	if props then
		for k, v in props do
			merged[k] = v
		end
	end
	return Theme.button(parent, text, variant, merged)
end

local panel = Theme.panel(gui, "Panel", {
	Size = UDim2.new(0.92, 0, 0.9, 0),
	Position = UDim2.fromScale(0.5, 0.52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(14, 20, 34),
	BackgroundTransparency = 0.02,
	Visible = false,
})
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(1040, 800)
sizeLimit.Parent = panel

-- club crest: rounded shield in the kit colour with the club initials
local crest = Instance.new("Frame")
crest.Name = "Crest"
crest.Size = UDim2.fromOffset(44, 44)
crest.Position = UDim2.fromOffset(18, 10)
crest.BackgroundColor3 = Config.HomeKit
crest.BorderSizePixel = 0
crest.Parent = panel
Theme.corner(crest, 12)
Theme.stroke(crest, 0.3, Color3.new(1, 1, 1))
local crestInitials = Theme.text(crest, "", "display", {
	Name = "Initials",
	Size = UDim2.fromScale(1, 1),
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
})
local function initials(name: string): string
	local out = ""
	for word in name:gmatch("%S+") do
		if word:upper() ~= "FC" or out == "" then
			out ..= word:sub(1, 1):upper()
		end
		if #out >= 2 then
			break
		end
	end
	return if out == "" then "?" else out
end

local title = Theme.text(panel, "CLUB OFFICE", "display", {
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(72, 10),
	Size = UDim2.new(1, -340, 0, 44),
	TextYAlignment = Enum.TextYAlignment.Center,
})

local closeButton = Theme.closeButton(panel, {
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.new(1, -54, 0, 10),
	BackgroundColor3 = Color3.fromRGB(23, 30, 44),
	BackgroundTransparency = 0,
})

local cashLine = Theme.pill(panel, "CashLine", {
	Position = UDim2.new(1, -62, 0, 10),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(190, 44),
	Font = Theme.fonts.display,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Theme.colors.cash,
	BackgroundColor3 = Color3.fromRGB(23, 30, 44),
	BackgroundTransparency = 0,
});
(cashLine:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 10);
(cashLine:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0.5

-- tabs
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(18, 64)
tabs.Size = UDim2.new(1, -36, 0, 38)
tabs.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(18, 112)
content.Size = UDim2.new(1, -36, 1, -126)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = panel
local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local currentTab = "Squad"
local selectedId: number? = nil
local tabButtons: { [string]: TextButton } = {}

local render: () -> ()

-- Five tabs share the row: each takes a fifth of the width minus its share of the gaps.
local TAB_NAMES = { "Squad", "League", "History", "Scouting", "Staff" }
local tabGapShare = math.ceil(8 * (#TAB_NAMES - 1) / #TAB_NAMES)
for i, name in TAB_NAMES do
	local b = button(tabs, name:upper(), ROW_BG, { Name = name .. "Tab", Size = UDim2.new(1 / #TAB_NAMES, -tabGapShare, 0, 38), LayoutOrder = i, TextSize = 16, Font = Theme.fonts.display })
	tabButtons[name] = b
	b.Activated:Connect(function()
		currentTab = name
		selectedId = nil
		render()
	end)
end

local function clearContent()
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function section(text: string)
	label(content, text, {
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = ACCENT,
		Size = UDim2.new(1, -10, 0, 26),
		LayoutOrder = nextOrder(),
	})
end

local function note(text: string, color: Color3?)
	label(content, text, {
		TextSize = 15,
		TextColor3 = color or Color3.fromRGB(210, 210, 210),
		TextWrapped = true,
		Size = UDim2.new(1, -10, 0, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
	})
end

local function row(alt: boolean): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -10, 0, 30)
	f.BackgroundColor3 = if alt then ROW_ALT else ROW_BG
	f.BorderSizePixel = 0
	f.LayoutOrder = nextOrder()
	Theme.corner(f, 6)
	f.Parent = content
	return f
end

local function cell(parent: Instance, text: string, x: number, w: number, props: { [string]: any }?)
	local l = label(parent, text, { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 30), TextSize = 15 })
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
end

-- Visitors (anyone but the owner) can look but not touch.
local function canManage(): boolean
	return get("OwnerUserId") == player.UserId
end

-- ------------------------------------------------------------------ Squad tab

-- Auto Squad row: green switch pill on the left, explanation on the right.
local function autoSquadRow(club: Club)
	local head = row(false)
	head.Size = UDim2.new(1, -10, 0, 48)
	head.BackgroundColor3 = Color3.fromRGB(23, 30, 44)
	Theme.stroke(head, 0.88)
	local on = club.autoSquad
	if canManage() then
		local toggle = Theme.button(head, if on then "AUTO SQUAD: ON" else "AUTO SQUAD: OFF", if on then "primary" else "secondary", {
			Name = "AutoToggle",
			Size = UDim2.fromOffset(236, 34),
			Position = UDim2.fromOffset(8, 7),
			TextSize = 15,
			Font = Theme.fonts.display,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Theme.padding(toggle, 0, 14)
		local track = Instance.new("Frame")
		track.Name = "Switch"
		track.Size = UDim2.fromOffset(46, 24)
		track.Position = UDim2.new(1, 0, 0.5, 0)
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.BackgroundColor3 = if on then Color3.fromRGB(28, 120, 60) else Theme.colors.bg
		track.BorderSizePixel = 0
		track.Parent = toggle
		Theme.corner(track, 12)
		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(18, 18)
		knob.Position = if on then UDim2.new(1, -3, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
		knob.AnchorPoint = if on then Vector2.new(1, 0.5) else Vector2.new(0, 0.5)
		knob.BackgroundColor3 = Color3.new(1, 1, 1)
		knob.BorderSizePixel = 0
		knob.Parent = track
		Theme.corner(knob, 9)
		toggle.Activated:Connect(function()
			actionEvent:FireServer("setAutoSquad", not club.autoSquad)
		end)
		cell(head, if on then "Your best XI is selected automatically." else "Drag a card onto another to swap, or tap two cards.", 260, 600, { TextColor3 = GREY, Size = UDim2.fromOffset(600, 48), TextYAlignment = Enum.TextYAlignment.Center })
	else
		cell(head, if on then "Auto Squad is on." else "The owner picks the team by hand.", 12, 500, { TextColor3 = GREY, Size = UDim2.fromOffset(500, 48), TextYAlignment = Enum.TextYAlignment.Center })
	end
end

-- Bottom bar: squad capacity meter on the left, selection details on the right.
local function capacityBar(club: Club)
	local bar = row(false)
	bar.Size = UDim2.new(1, -10, 0, 48)
	bar.BackgroundColor3 = Color3.fromRGB(23, 30, 44)
	Theme.stroke(bar, 0.88)
	local count, max = #club.players, Config.SquadMax
	cell(bar, "Squad capacity", 14, 130, { TextColor3 = GREY, Size = UDim2.fromOffset(130, 48), TextYAlignment = Enum.TextYAlignment.Center })
	cell(bar, ("%d / %d players"):format(count, max), 150, 170, { Font = Theme.fonts.display, TextSize = 18, Size = UDim2.fromOffset(170, 48), TextYAlignment = Enum.TextYAlignment.Center })
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 330, 0.5, 0)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Size = UDim2.new(0.3, 0, 0, 16)
	track.BackgroundColor3 = Theme.colors.bg3
	track.BorderSizePixel = 0
	track.Parent = bar
	Theme.corner(track, 8)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(count / max, 0, 1), 1)
	fill.BackgroundColor3 = Theme.colors.cash
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, 8)
	cell(bar, ("%d%%"):format(math.floor(count / max * 100 + 0.5)), 0, 60, {
		Position = UDim2.new(0.3, 344, 0, 0),
		Size = UDim2.fromOffset(60, 48),
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Theme.fonts.bold,
	})
	local detail = "Select a player to view details"
	if selectedId then
		for _, p in club.players do
			if p.id == selectedId then
				detail = ("%s  ·  %s  ·  OVR %d  ·  POT %d  ·  age %d  ·  %d apps, %d goals"):format(p.name, p.role, p.overall, p.potential, p.age, p.apps, p.goals)
			end
		end
	end
	cell(bar, detail, 0, 420, {
		Position = UDim2.new(1, -14, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.new(0.36, 0, 0, 48),
		TextColor3 = if selectedId then Theme.colors.text else GREY,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function renderSquad(club: Club)
	autoSquadRow(club)
	LineupBoard.render(content, {
		club = club :: any,
		kit = Config.HomeKit,
		canDrag = canManage() and not club.autoSquad,
		canRelease = canManage(),
		selectedId = selectedId,
		layoutOrder = nextOrder(),
		onSwap = function(a: number, b: number)
			selectedId = nil
			actionEvent:FireServer("swap", a, b)
		end,
		onSelect = function(id: number?)
			selectedId = id
			render()
		end,
		onSell = function(id: number)
			selectedId = nil
			actionEvent:FireServer("release", id)
		end,
		lockScroll = function(locked: boolean)
			content.ScrollingEnabled = not locked
		end,
	})
	capacityBar(club)
end

-- --------------------------------------------------------------- Scouting tab

local SCOUT_BG = Color3.fromRGB(23, 30, 44)
local ROW_CARD = Color3.fromRGB(16, 24, 44)
local CYAN = Color3.fromRGB(90, 220, 255)
local BLUE_LINE = Color3.fromRGB(120, 150, 210)

-- Dark rounded card the scouting sections sit in.
local function scoutPanel(height: number): Frame
	local f = row(false)
	f.Size = UDim2.new(1, -10, 0, height)
	f.BackgroundColor3 = SCOUT_BG
	Theme.corner(f, 10)
	Theme.stroke(f, 0.88)
	return f
end

-- Binoculars drawn from two circles, so no icon asset or glyph is needed.
local function binoculars(parent: Instance, x: number, y: number)
	for _, dx in { 0, 14 } do
		local lens = Instance.new("Frame")
		lens.Size = UDim2.fromOffset(16, 16)
		lens.Position = UDim2.fromOffset(x + dx, y)
		lens.BackgroundColor3 = CYAN
		lens.BorderSizePixel = 0
		lens.Parent = parent
		Theme.corner(lens, 8)
		local pupil = Instance.new("Frame")
		pupil.Size = UDim2.fromOffset(8, 8)
		pupil.Position = UDim2.fromOffset(4, 4)
		pupil.BackgroundColor3 = SCOUT_BG
		pupil.BorderSizePixel = 0
		pupil.Parent = lens
		Theme.corner(pupil, 4)
	end
end

local function infoFooter(text: string)
	local f = scoutPanel(48)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(26, 26)
	dot.Position = UDim2.new(0, 16, 0.5, 0)
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.BackgroundColor3 = Theme.colors.info
	dot.BorderSizePixel = 0
	dot.Parent = f
	Theme.corner(dot, 13)
	Theme.text(dot, "i", "display", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	cell(f, text, 56, 800, { TextColor3 = Color3.fromRGB(210, 215, 225), Size = UDim2.new(1, -70, 0, 48), TextYAlignment = Enum.TextYAlignment.Center })
end

local function renderScouting(club: Club)
	local played = (get("MatchesPlayed") or 0) :: number
	if played < 1 then
		local f = scoutPanel(64)
		binoculars(f, 18, 24)
		cell(f, "Scouting opens after your first match. Press PLAY MATCH at the top.", 56, 800, { Size = UDim2.new(1, -70, 0, 64), TextYAlignment = Enum.TextYAlignment.Center })
		return
	end
	local level = Config.ScoutLevels[club.scoutLevel]
	local nextLevel = Config.ScoutLevels[club.scoutLevel + 1]

	-- scout row: icon, level name, what it does, hire / upgrade on the right
	local head = scoutPanel(64)
	binoculars(head, 18, 24)
	local title = Theme.text(head, string.upper(if level then level.name else "NO SCOUT"), "display", {
		Size = UDim2.fromOffset(300, 64),
		Position = UDim2.fromOffset(58, 0),
		TextSize = 22,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local textW = 0
	pcall(function()
		textW = game:GetService("TextService"):GetTextSize(title.Text, 22, Theme.fonts.display, Vector2.new(400, 64)).X
	end)
	cell(head, "|", 58 + textW + 14, 12, { TextColor3 = GREY, Size = UDim2.fromOffset(12, 64), TextYAlignment = Enum.TextYAlignment.Center })
	local desc = if level
		then ("Finds %d prospects after every match."):format(level.prospects)
		else "A scout brings you a short list of players you can sign, refreshed after every match."
	cell(head, desc, 58 + textW + 32, 520, { TextColor3 = Color3.fromRGB(210, 215, 225), Size = UDim2.new(1, -(58 + textW + 32) - 300, 0, 64), TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
	if nextLevel then
		if canManage() then
			local hire = Theme.button(head, ("%s %s  ·  %s"):format(if level then "Upgrade to" else "Hire", nextLevel.name, money(nextLevel.cost)), "primary", {
				Size = UDim2.fromOffset(280, 40),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 15,
				Font = Theme.fonts.display,
			})
			hire.Activated:Connect(function()
				actionEvent:FireServer(if level then "upgradeScout" else "hireScout")
			end)
		else
			cell(head, ("Next: %s  ·  %s"):format(nextLevel.name, money(nextLevel.cost)), 0, 280, { Position = UDim2.new(1, -12, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(280, 64), TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center })
		end
	end
	if not level then
		infoFooter("Hire a scout to start receiving prospects. Better scouts find more players with higher potential.")
		return
	end

	-- shortlist panel: title, column headers, one row per prospect
	local ROW_H, ROW_GAP = 78, 8
	local n = #club.shortlist
	local listH = 92 + (if n == 0 then 40 else n * ROW_H + (n - 1) * ROW_GAP) + 16
	local list = scoutPanel(listH)
	Theme.text(list, "SHORTLIST", "display", {
		Size = UDim2.fromOffset(300, 40),
		Position = UDim2.fromOffset(18, 10),
		TextSize = 26,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	cell(list, ("%d prospect%s"):format(n, if n == 1 then "" else "s"), 0, 200, { Position = UDim2.new(1, -20, 0, 10), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(200, 40), TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center })
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Color3.new(1, 1, 1)
	rule.BackgroundTransparency = 0.88
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.Position = UDim2.fromOffset(0, 56)
	rule.Parent = list
	-- column x positions (scale of the panel width)
	local COL_OVR, COL_POT, COL_FEE = 0.44, 0.58, 0.72
	local function header(text: string, x: UDim2, w: UDim2)
		cell(list, text, 0, 100, { Position = x, Size = w, TextColor3 = BLUE_LINE, Font = Theme.fonts.bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	end
	header("PLAYER", UDim2.fromOffset(110, 60), UDim2.fromOffset(100, 28))
	header("OVR", UDim2.new(COL_OVR, 0, 0, 60), UDim2.fromOffset(90, 28))
	header("POTENTIAL", UDim2.new(COL_POT, 0, 0, 60), UDim2.fromOffset(110, 28))
	header("TRANSFER FEE", UDim2.new(COL_FEE, 0, 0, 60), UDim2.new(1 - COL_FEE, -12, 0, 28))
	if n == 0 then
		cell(list, "Nobody left on the list. New prospects arrive after the next match.", 18, 700, { Position = UDim2.fromOffset(18, 92), Size = UDim2.new(1, -36, 0, 40), TextColor3 = GREY })
	end
	for i, p in club.shortlist do
		local r = Instance.new("Frame")
		r.Name = ("Prospect%d"):format(p.id)
		r.BackgroundColor3 = ROW_CARD
		r.BorderSizePixel = 0
		r.Position = UDim2.new(0, 12, 0, 92 + (i - 1) * (ROW_H + ROW_GAP))
		r.Size = UDim2.new(1, -24, 0, ROW_H)
		r.Parent = list
		Theme.corner(r, 8)
		Theme.stroke(r, 0.7, BLUE_LINE)
		local face = Instance.new("Frame")
		face.Name = "Face"
		face.Size = UDim2.fromOffset(ROW_H - 18, ROW_H - 18)
		face.Position = UDim2.fromOffset(10, 9)
		face.BackgroundTransparency = 1
		face.ClipsDescendants = true
		face.Parent = r
		Theme.corner(face, 8)
		Theme.stroke(face, 0.3, BLUE_LINE)
		Headshot.attach(face, p.look or p.id, Config.HomeKit, 0, { shoulders = true })
		cell(r, p.name, 96, 320, { Font = Theme.fonts.display, TextSize = 19, Size = UDim2.fromOffset(320, 30), Position = UDim2.fromOffset(96, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		cell(r, ("%s  ·  Age %d"):format(p.role, p.age), 96, 320, { TextColor3 = BLUE_LINE, TextSize = 14, Size = UDim2.fromOffset(320, 22), Position = UDim2.fromOffset(96, 46) })
		cell(r, tostring(p.overall), 0, 90, { Position = UDim2.new(COL_OVR, -12, 0, 0), Size = UDim2.fromOffset(90, ROW_H), Font = Theme.fonts.display, TextSize = 32, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		cell(r, tostring(p.potential), 0, 110, { Position = UDim2.new(COL_POT, -12, 0, 0), Size = UDim2.fromOffset(110, ROW_H), Font = Theme.fonts.display, TextSize = 32, TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		if canManage() then
			local sign = Theme.button(r, ("Sign %s"):format(money(p.fee or 0)), "primary", {
				Size = UDim2.new(1 - COL_FEE, -36, 0, 48),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 18,
				Font = Theme.fonts.display,
			})
			sign.Activated:Connect(function()
				actionEvent:FireServer("sign", p.id)
			end)
		else
			cell(r, money(p.fee or 0), 0, 200, { Position = UDim2.new(COL_FEE, 0, 0, 0), Size = UDim2.new(1 - COL_FEE, -12, 0, ROW_H), TextColor3 = GREY, Font = Theme.fonts.bold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		end
	end

	infoFooter("Potential shows how far a player can develop. Young players improve faster with a coach.")
end

-- ----------------------------------------------------------------- League tab

local function ordinal(n: number): string
	local suffix = "th"
	local last = n % 10
	if n % 100 < 11 or n % 100 > 13 then
		suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	end
	return ("%d%s"):format(n, suffix)
end

local function renderLeague()
	local raw = get("LeagueTable")
	local rows = if type(raw) == "string" and raw ~= "" then HttpService:JSONDecode(raw) else {}
	section(("%s  ·  SEASON %d"):format(string.upper(get("DivisionName") or "LEAGUE"), get("Season") or 1))
	local played, rounds = get("Round") or 0, get("Rounds") or 10
	local nextOpp = get("NextOpponent") or ""
	if nextOpp ~= "" then
		note(("Match %d of %d next: vs %s.  You are %s."):format(played + 1, rounds, nextOpp, ordinal(get("Position") or 1)))
	end
	local head = row(false)
	head.BackgroundColor3 = PANEL_BG
	cell(head, "#", 10, 30, { TextColor3 = GREY })
	cell(head, "Team", 40, 220, { TextColor3 = GREY })
	cell(head, "P", 270, 30, { TextColor3 = GREY })
	cell(head, "W", 305, 30, { TextColor3 = GREY })
	cell(head, "D", 340, 30, { TextColor3 = GREY })
	cell(head, "L", 375, 30, { TextColor3 = GREY })
	cell(head, "GD", 410, 40, { TextColor3 = GREY })
	cell(head, "Pts", 460, 40, { TextColor3 = GREY })
	local promo, releg = Config.PromotionSpots, Config.RelegationSpots
	for i, r in rows do
		local f = row(i % 2 == 0)
		if r.isPlayer then
			f.BackgroundColor3 = Theme.colors.playerRow
		end
		local posColor = if i <= promo then Color3.fromRGB(120, 230, 120) elseif i > #rows - releg then Color3.fromRGB(240, 110, 110) else Color3.new(1, 1, 1)
		cell(f, tostring(r.position), 10, 30, { TextColor3 = posColor, Font = Enum.Font.GothamBold })
		cell(f, r.name, 40, 220, { Font = if r.isPlayer then Enum.Font.GothamBold else Enum.Font.Gotham })
		cell(f, tostring(r.played), 270, 30)
		cell(f, tostring(r.won), 305, 30)
		cell(f, tostring(r.drawn), 340, 30)
		cell(f, tostring(r.lost), 375, 30)
		cell(f, ("%+d"):format(r.gd), 410, 40)
		cell(f, tostring(r.points), 460, 40, { Font = Enum.Font.GothamBold, TextColor3 = ACCENT })
	end
	local tier = get("Tier") or 1
	local up = if tier < #Config.Divisions then ("Top %d go up to the %s."):format(promo, Config.Divisions[tier + 1].name) else "This is the top flight."
	local down = if tier > 1 then ("Bottom %d go down to the %s."):format(releg, Config.Divisions[tier - 1].name) else "Nobody goes down from here."
	note(up .. "  " .. down, GREY)
	note(("Popularity %d / 100 — wins raise it, losses lower it. Fan demand right now: %d."):format(get("Popularity") or 0, get("Demand") or 0), GREY)
end

-- ------------------------------------------------------------------ Staff tab

local function renderStaff(club: Club)
	local level = Config.CoachLevels[club.coachLevel + 1]
	local nextLevel = Config.CoachLevels[club.coachLevel + 2]
	section("COACH")
	if club.coachLevel == 0 then
		note("No coach. A coach adds team strength on matchday and speeds up player development.")
	else
		note(("%s — +%d team strength, %.1fx development."):format(level.name, level.strengthBonus, level.developMultiplier))
	end
	if nextLevel and canManage() then
		local hire = button(content, ("%s %s — %s"):format(if club.coachLevel == 0 then "Hire" else "Upgrade to", nextLevel.name, money(nextLevel.cost)), GREEN, {
			Size = UDim2.fromOffset(340, 34),
			LayoutOrder = nextOrder(),
		})
		hire.Activated:Connect(function()
			actionEvent:FireServer(if club.coachLevel == 0 then "hireCoach" else "upgradeCoach")
		end)
		note(("Next: +%d team strength, %.1fx development."):format(nextLevel.strengthBonus, nextLevel.developMultiplier), GREY)
	elseif nextLevel then
		note(("Next: %s — %s."):format(nextLevel.name, money(nextLevel.cost)), GREY)
	else
		note("Coaching is fully upgraded.", GREY)
	end
end

-- ---------------------------------------------------------------- History tab

local function renderHistory()
	local raw = get("History")
	local data = if type(raw) == "string" and raw ~= "" then HttpService:JSONDecode(raw) else {}
	local honours = data.honours or { seasons = 0, titles = 0, promotions = 0, relegations = 0, bestTier = 0 }
	local seasons = data.seasons or {}

	section(("%s  ·  HONOURS"):format(string.upper(get("ClubName") or "CLUB")))
	local titleWord = if honours.titles == 1 then "title" else "titles"
	note(("%d league %s  ·  %d promotions  ·  %d relegations  ·  Highest level: %s"):format(
		honours.titles, titleWord, honours.promotions, honours.relegations,
		if honours.bestTier > 0 then Config.Divisions[honours.bestTier].name else "-"))
	note(("All-time record: %d played, %d won, %d drawn, %d lost."):format(
		get("MatchesPlayed") or 0, get("Wins") or 0, get("Draws") or 0, get("Losses") or 0), GREY)
	if honours.titles > 0 then
		note("Every title puts a trophy on the office shelf.", GREY)
	end

	section(("PAST SEASONS (%d)"):format(#seasons))
	if #seasons == 0 then
		note("Nothing yet. Finish a season and it goes in the book.", GREY)
		return
	end
	local head = row(false)
	head.BackgroundColor3 = PANEL_BG
	cell(head, "S", 10, 30, { TextColor3 = GREY })
	cell(head, "Division", 40, 180, { TextColor3 = GREY })
	cell(head, "Pos", 225, 40, { TextColor3 = GREY })
	cell(head, "W-D-L", 270, 70, { TextColor3 = GREY })
	cell(head, "GF-GA", 345, 70, { TextColor3 = GREY })
	cell(head, "Pts", 420, 40, { TextColor3 = GREY })
	cell(head, "Result", 465, 120, { TextColor3 = GREY })
	for i = #seasons, 1, -1 do
		local r = seasons[i]
		local f = row(i % 2 == 0)
		local color = if r.position == 1 then ACCENT elseif r.outcome == "Promoted" then Color3.fromRGB(120, 230, 120) elseif r.outcome == "Relegated" then Color3.fromRGB(240, 110, 110) else Color3.new(1, 1, 1)
		cell(f, tostring(r.season), 10, 30, { TextColor3 = GREY })
		cell(f, r.division, 40, 180, { Font = Enum.Font.GothamBold })
		cell(f, ordinal(r.position), 225, 40, { TextColor3 = color, Font = Enum.Font.GothamBold })
		cell(f, ("%d-%d-%d"):format(r.won, r.drawn, r.lost), 270, 70)
		cell(f, ("%d-%d"):format(r.gf, r.ga), 345, 70)
		cell(f, tostring(r.points), 420, 40, { Font = Enum.Font.GothamBold })
		local result = if r.position == 1 then "Champions" elseif r.outcome == "Promoted" then "Promoted" elseif r.outcome == "Relegated" then "Relegated" else "Stayed up"
		cell(f, result, 465, 120, { TextColor3 = color })
	end
end

render = function()
	if not panel.Visible then
		return
	end
	clearContent()
	order = 0
	cashLine.Text = money(get("Cash") or 0)
	crestInitials.Text = initials(get("ClubName") or Config.ClubName)
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then ACCENT else Theme.colors.bg3
		b.TextColor3 = if name == currentTab then Theme.colors.bg else Theme.colors.text
	end
	local club = loadClub()
	if not club then
		note("Loading club…")
		return
	end
	if not canManage() then
		note(("You are visiting %s. Only the owner can make changes."):format(get("ClubName") or "this club"), ACCENT)
	end
	if currentTab == "Squad" then
		renderSquad(club)
	elseif currentTab == "League" then
		renderLeague()
	elseif currentTab == "History" then
		renderHistory()
	elseif currentTab == "Scouting" then
		renderScouting(club)
	else
		renderStaff(club)
	end
end

local function setOpen(open: boolean)
	if open and get("Phase") ~= "Manage" then
		return
	end
	panel.Visible = open
	selectedId = nil
	if open then
		render()
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)

-- Office computer prompt (client side; the prompt is also visible to the server but unused there)
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who == player and prompt.Name == "ClubPrompt" then
		setOpen(true)
	end
end)

-- CLUB button (top-left under cash), handy on mobile and away from the office
local openButton = button(gui, "CLUB OFFICE", Theme.colors.info, {
	Name = "Open",
	Size = UDim2.fromOffset(140, 34),
	Position = UDim2.fromOffset(20, 96),
	TextSize = 15,
})
openButton.Activated:Connect(function()
	setOpen(not panel.Visible)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		setOpen(not panel.Visible)
	end
end)

for _, key in { "Club", "Cash", "MatchesPlayed", "LeagueTable", "Demand", "History", "ClubName", "OwnerUserId" } do
	state:GetAttributeChangedSignal(key):Connect(render)
end
state:GetAttributeChangedSignal("Phase"):Connect(function()
	local manage = get("Phase") == "Manage"
	openButton.Visible = manage
	if not manage then
		setOpen(false)
	end
end)
openButton.Visible = get("Phase") == "Manage"
