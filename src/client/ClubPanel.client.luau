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
local Squad = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Squad")) -- X331: what a bid is actually for
local Finance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Finance")) -- X299
local Theme = require(script.Parent.Theme)
local LineupBoard = require(script.Parent.LineupBoard)
local Headshot = require(script.Parent.Headshot)
local Crest = require(script.Parent.Crest)

local player = Players.LocalPlayer
local state = require(script.Parent.ClubRef).waitState()
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
	-- X337: a prospect's ceiling arrives as the band his scout will commit to
	potentialLow: number?,
	potentialHigh: number?,
}
type Club = {
	players: { Player },
	lineup: { xi: { number }, bench: { number } },
	autoSquad: boolean,
	coachLevel: number,
	scoutLevel: number,
	shortlist: { Player },
	shortlistMatchesLeft: number?, -- X276: matches before it is re-scouted
}

local money = Theme.money

local function get(key: string): any
	return state:GetAttribute(key)
end

-- X232: a purchase the club can't afford yet looks unavailable and says what's
-- missing (the panel re-renders when Cash changes). Still tappable; the server
-- answers with the same message.
local function markAffordable(b: TextButton, cost: number, shortLabel: string?)
	local cash = (get("Cash") :: number?) or 0
	if cash >= cost then
		return
	end
	b.BackgroundColor3 = Theme.colors.bg3
	b.TextColor3 = Theme.colors.muted
	local need = ("Need %s more"):format(money(cost - cash))
	b.Text = if shortLabel then need .. "  ·  " .. shortLabel else b.Text .. "  ·  " .. need
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
require(script.Parent.Focus).watch(panel) -- the town softens behind the office menu

-- club crest: the player's own club, so it wears the home kit
local crest = Crest.draw(panel, Config.ClubName, 44, { isPlayer = true, position = UDim2.fromOffset(18, 10) })

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
(cashLine:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0, 10)

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

-- The Squad tab has its own page that never scrolls: the board fills the space
-- above a fixed bar, and the only scrolling region is the bench list inside it.
local squadPage = Instance.new("Frame")
squadPage.Name = "SquadPage"
squadPage.BackgroundTransparency = 1
squadPage.Position = content.Position
squadPage.Size = content.Size
squadPage.Visible = false
squadPage.Parent = panel

local currentTab = "Squad"
local selectedId: number? = nil
local tabButtons: { [string]: TextButton } = {}

local render: () -> ()

-- Five tabs share the row: each takes a fifth of the width minus its share of the gaps.
-- X299 added FINANCE; the row divides itself by #TAB_NAMES
local TAB_NAMES = { "Squad", "League", "Finance", "History", "Scouting", "Staff" }
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
	Theme.corner(f, Theme.chipRadius)
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

-- A cell pinned to the right-hand end of its row, so it survives a narrow
-- screen (review of X325).
local function rightCell(parent: Instance, text: string, w: number, props: { [string]: any }?)
	local l = label(parent, text, {
		Position = UDim2.new(1, -(w + 10), 0, 0),
		Size = UDim2.fromOffset(w, 30),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
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

-- Everything below the board: Auto Squad on the left, squad capacity in the
-- middle, the current hint on the right. Built once, then only its text moves.
local SQUAD_BAR_H = 56

-- X323: the standing approach from another club, across the top of the squad
-- screen. Hidden (and the board full height) when nobody has come in.
local BID_H = 64

local bidCard = Instance.new("Frame")
bidCard.Name = "Bid"
bidCard.BackgroundColor3 = Color3.fromRGB(38, 32, 16)
bidCard.BorderSizePixel = 0
bidCard.Size = UDim2.new(1, 0, 0, BID_H)
bidCard.Visible = false
bidCard.Parent = squadPage
Theme.corner(bidCard, Theme.cardRadius)
Theme.stroke(bidCard, "selected")

local bidTitle = Theme.text(bidCard, "", "body", {
	Name = "Title",
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -300, 0, 22),
	TextSize = 17,
	Font = Theme.fonts.bold,
	TextColor3 = Theme.colors.accent,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local bidDetail = Theme.text(bidCard, "", "muted", {
	Name = "Detail",
	Position = UDim2.fromOffset(16, 32),
	Size = UDim2.new(1, -300, 0, 20),
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local bidAccept = Theme.button(bidCard, "ACCEPT", "primary", {
	Name = "Accept",
	Position = UDim2.new(1, -274, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(130, 40),
	TextSize = 15,
})
local bidDecline = Theme.button(bidCard, "KEEP HIM", "secondary", {
	Name = "Decline",
	Position = UDim2.new(1, -136, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.fromOffset(120, 40),
	TextSize = 15,
})
bidAccept.Activated:Connect(function()
	actionEvent:FireServer("acceptBid")
end)
bidDecline.Activated:Connect(function()
	actionEvent:FireServer("declineBid")
end)

local boardHolder = Instance.new("Frame")
boardHolder.Name = "Board"
boardHolder.BackgroundTransparency = 1
boardHolder.Size = UDim2.new(1, 0, 1, -SQUAD_BAR_H - 8)
boardHolder.Parent = squadPage

local squadBar = Instance.new("Frame")
squadBar.Name = "Bar"
squadBar.BackgroundColor3 = Color3.fromRGB(23, 30, 44)
squadBar.BorderSizePixel = 0
squadBar.Position = UDim2.new(0, 0, 1, -SQUAD_BAR_H)
squadBar.Size = UDim2.new(1, 0, 0, SQUAD_BAR_H)
squadBar.Parent = squadPage
Theme.corner(squadBar, Theme.radius)
Theme.stroke(squadBar)

-- Auto Squad: a compact switch, no longer a whole row of its own.
local autoToggle = Theme.button(squadBar, "AUTO SQUAD", "secondary", {
	Name = "AutoToggle",
	Size = UDim2.fromOffset(196, 36),
	Position = UDim2.new(0, 10, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	TextSize = 14,
	Font = Theme.fonts.display,
	TextXAlignment = Enum.TextXAlignment.Left,
})
Theme.padding(autoToggle, 0, 12)
local autoTrack = Instance.new("Frame")
autoTrack.Name = "Switch"
autoTrack.Size = UDim2.fromOffset(44, 22)
autoTrack.Position = UDim2.new(1, 0, 0.5, 0)
autoTrack.AnchorPoint = Vector2.new(1, 0.5)
autoTrack.BorderSizePixel = 0
autoTrack.Parent = autoToggle
Theme.corner(autoTrack, 11)
local autoKnob = Instance.new("Frame")
autoKnob.Size = UDim2.fromOffset(16, 16)
autoKnob.BackgroundColor3 = Color3.new(1, 1, 1)
autoKnob.BorderSizePixel = 0
autoKnob.Parent = autoTrack
Theme.corner(autoKnob, 8)
autoToggle.Activated:Connect(function()
	local club = loadClub()
	if club and canManage() then
		actionEvent:FireServer("setAutoSquad", not club.autoSquad)
	end
end)

local capacityLabel = Theme.text(squadBar, "", "body", {
	Name = "Capacity",
	-- X287: wide enough for "Squad 16 / 20 · avg age 29.9" on one line
	-- X356: and now the squad's rating against the division's as well
	Size = UDim2.fromOffset(470, SQUAD_BAR_H),
	Position = UDim2.fromOffset(218, 0),
	TextSize = 15,
	Font = Theme.fonts.bold,
	TextYAlignment = Enum.TextYAlignment.Center,
})
local capacityTrack = Instance.new("Frame")
capacityTrack.Name = "Track"
capacityTrack.Position = UDim2.new(0, 462, 0.5, 0)
capacityTrack.AnchorPoint = Vector2.new(0, 0.5)
capacityTrack.Size = UDim2.new(0, 150, 0, 12)
capacityTrack.BackgroundColor3 = Theme.colors.bg3
capacityTrack.BorderSizePixel = 0
capacityTrack.Parent = squadBar
Theme.corner(capacityTrack, 6)
local capacityFill = Instance.new("Frame")
capacityFill.Name = "Fill"
capacityFill.Size = UDim2.fromScale(0, 1)
capacityFill.BackgroundColor3 = Theme.colors.cash
capacityFill.BorderSizePixel = 0
capacityFill.Parent = capacityTrack
Theme.corner(capacityFill, 6)

local squadHint = Theme.text(squadBar, "", "muted", {
	Name = "Hint",
	Size = UDim2.new(1, -636, 0, SQUAD_BAR_H), -- X287 (review): clear of the wider bar
	Position = UDim2.new(1, -14, 0, 0),
	AnchorPoint = Vector2.new(1, 0),
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextTruncate = Enum.TextTruncate.AtEnd,
})

local board: LineupBoard.Board? = nil

local function renderSquad(club: Club)
	if not board then
		board = LineupBoard.new(boardHolder, {
			kit = Config.HomeKit,
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
		})
	end
	local manage = canManage()
	-- X323: an approach for one of your players, if there is one standing
	local offer: any = club.bid
	local showBid = manage and type(offer) == "table" and type(offer.fee) == "number"
	bidCard.Visible = showBid
	boardHolder.Position = UDim2.fromOffset(0, if showBid then BID_H + 8 else 0)
	boardHolder.Size = UDim2.new(1, 0, 1, -SQUAD_BAR_H - 8 - (if showBid then BID_H + 8 else 0))
	if showBid then
		-- X331: "they want Alfie Skyward" is not a decision until you know who he
		-- is and what he is worth, and the card is usually read without the
		-- squad board in front of you
		local wanted = nil
		for _, p in club.players do
			if p.id == offer.playerId then
				wanted = p
			end
		end
		bidTitle.Text = ("%s want %s"):format(tostring(offer.club), tostring(offer.playerName))
		if wanted then
			local value = Squad.value(wanted)
			local premium = if value > 0 then math.floor((offer.fee / value - 1) * 100 + 0.5) else 0
			bidDetail.Text = ("%s %s, %d OVR (%d potential), aged %d  ·  worth %s  ·  they offer %s, %d%% over"):format(
				wanted.role, if wanted.injured > 0 then "injured" else "fit", wanted.overall, wanted.potential, wanted.age,
				money(value), money(offer.fee), premium)
		else
			bidDetail.Text = ("%s now, and he leaves today. The offer is off at your next match."):format(money(offer.fee))
		end
	end
	;(board :: LineupBoard.Board).update(club :: any, selectedId, manage and not club.autoSquad, manage)

	local on = club.autoSquad
	autoToggle.Text = if on then "AUTO SQUAD: ON" else "AUTO SQUAD: OFF"
	autoToggle.BackgroundColor3 = if on then GREEN else Theme.colors.bg3
	autoToggle.Visible = manage
	autoTrack.BackgroundColor3 = if on then Color3.fromRGB(28, 120, 60) else Theme.colors.bg
	autoKnob.Position = if on then UDim2.new(1, -3, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
	autoKnob.AnchorPoint = if on then Vector2.new(1, 0.5) else Vector2.new(0, 0.5)

	local count, max = #club.players, Config.SquadMax
	-- X287: the average age says whether the squad is about to fall off a cliff
	local years = 0
	for _, p in club.players do
		years += p.age
	end
	local average = if count > 0 then years / count else 0
	-- X356: the hidden number that decides every result, next to the standard
	-- the division expects and what that means
	local rating = Squad.average(club.players :: any)
	local division = Config.Divisions[(get("Tier") :: number?) or 1] or Config.Divisions[1]
	capacityLabel.Text = ("Squad %d / %d   ·   avg age %.1f   ·   %d OVR v %d: %s"):format(
		count, max, average, math.floor(rating + 0.5), division.baseStrength,
		Squad.divisionVerdict(rating, division.baseStrength))
	capacityLabel.Position = UDim2.fromOffset(if manage then 218 else 14, 0)
	capacityTrack.Position = UDim2.new(0, if manage then 462 else 258, 0.5, 0)
	capacityFill.Size = UDim2.fromScale(math.clamp(count / max, 0, 1), 1)

	if not manage then
		squadHint.Text = ("You are visiting %s. Only the owner can make changes."):format(get("ClubName") or "this club")
	elseif on then
		squadHint.Text = "Auto Squad picks your best XI. Turn it off to pick the team yourself."
	else
		squadHint.Text = "Drag a player onto another to swap them, or tap one then the other."
	end
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
	Theme.corner(f, Theme.cardRadius)
	Theme.stroke(f)
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
	-- X337: what this scout is worth beyond the size of his list
	local doubt = if level then (level.potentialDoubt or 0) else 0
	local precision = if doubt == 0
		then "He names a ceiling exactly."
		else ("He puts a ceiling within %d."):format(doubt)
	local desc = if level
		then ("Finds %d prospects after every match. %s"):format(level.prospects, precision)
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
			markAffordable(hire, nextLevel.cost, nextLevel.name)
			hire.Activated:Connect(function()
				actionEvent:FireServer(if level then "upgradeScout" else "hireScout")
			end)
		else
			cell(head, ("Next: %s  ·  %s"):format(nextLevel.name, money(nextLevel.cost)), 0, 280, { Position = UDim2.new(1, -12, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(280, 64), TextColor3 = GREY, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center })
		end
	end
	if not level then
		infoFooter("Hire a scout to start receiving prospects. Better scouts find more players, with higher ceilings, and can tell you more precisely how high.")
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
		Theme.corner(r, Theme.cardRadius)
		Theme.stroke(r)
		local face = Instance.new("Frame")
		face.Name = "Face"
		face.Size = UDim2.fromOffset(ROW_H - 18, ROW_H - 18)
		face.Position = UDim2.fromOffset(10, 9)
		face.BackgroundTransparency = 1
		face.ClipsDescendants = true
		face.Parent = r
		Theme.corner(face, Theme.chipRadius)
		Theme.stroke(face)
		Headshot.attach(face, p.look or p.id, Config.HomeKit, 0, { shoulders = true })
		cell(r, p.name, 96, 320, { Font = Theme.fonts.display, TextSize = 19, Size = UDim2.fromOffset(320, 30), Position = UDim2.fromOffset(96, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		cell(r, ("%s  ·  Age %d"):format(p.role, p.age), 96, 320, { TextColor3 = BLUE_LINE, TextSize = 14, Size = UDim2.fromOffset(320, 22), Position = UDim2.fromOffset(96, 46) })
		cell(r, tostring(p.overall), 0, 90, { Position = UDim2.new(COL_OVR, -12, 0, 0), Size = UDim2.fromOffset(90, ROW_H), Font = Theme.fonts.display, TextSize = 32, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		-- X337: a band, unless the scout is good enough to name the number
		local low, high = p.potentialLow, p.potentialHigh
		local band = low ~= nil and high ~= nil and low ~= high
		local potText = if band
			then ("%d-%d"):format(low :: number, high :: number)
			else tostring(p.potential or high or low or "?")
		cell(r, potText, 0, 110, { Position = UDim2.new(COL_POT, -12, 0, 0), Size = UDim2.fromOffset(110, ROW_H), Font = Theme.fonts.display, TextSize = if band then 24 else 32, TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		if canManage() then
			local sign = Theme.button(r, ("Sign %s"):format(money(p.fee or 0)), "primary", {
				Size = UDim2.new(1 - COL_FEE, -36, 0, 48),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 18,
				Font = Theme.fonts.display,
			})
			markAffordable(sign, p.fee or 0, money(p.fee or 0))
			sign.Activated:Connect(function()
				actionEvent:FireServer("sign", p.id)
			end)
		else
			cell(r, money(p.fee or 0), 0, 200, { Position = UDim2.new(COL_FEE, 0, 0, 0), Size = UDim2.new(1 - COL_FEE, -12, 0, ROW_H), TextColor3 = GREY, Font = Theme.fonts.bold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
		end
	end

	-- X276: the list keeps for a few matches now, so say how long it has left
	local left = club.shortlistMatchesLeft
	local keeps = if type(left) == "number" and left > 0
		then ("This list keeps for %d more match%s, so you can save up for someone."):format(left, if left == 1 then "" else "es")
		else "A new list is scouted after your next match."
	-- X337: the band is the scout's opinion, so say whose opinion it is
	local trust = if doubt == 0
		then "Your scouting network reports a ceiling exactly. "
		else ("Potential is your scout's estimate, and a better scout narrows it (within %d today). "):format(doubt)
	infoFooter("Potential shows how far a player can develop. Young players improve faster with a coach. " .. trust .. keeps)
end

-- ----------------------------------------------------------------- League tab

local ordinal = Theme.ordinal

local function renderLeague()
	local raw = get("LeagueTable")
	local rows = if type(raw) == "string" and raw ~= "" then HttpService:JSONDecode(raw) else {}
	section(("%s  ·  SEASON %d"):format(string.upper(get("DivisionName") or "LEAGUE"), get("Season") or 1))
	local played, rounds = get("Round") or 0, get("Rounds") or 10
	local nextOpp = get("NextOpponent") or ""
	if nextOpp ~= "" then
		-- Both crests side by side, so the next opponent is recognisable at a
		-- glance before the name is read.
		local fixture = Instance.new("Frame")
		fixture.Name = "NextFixture"
		fixture.Size = UDim2.new(1, -10, 0, 46)
		fixture.BackgroundColor3 = ROW_BG
		fixture.BorderSizePixel = 0
		fixture.LayoutOrder = nextOrder()
		Theme.corner(fixture, Theme.chipRadius)
		fixture.Parent = content
		Crest.draw(fixture, get("ClubName") or Config.ClubName, 30, { isPlayer = true, position = UDim2.fromOffset(10, 8) })
		label(fixture, "v", {
			Position = UDim2.fromOffset(46, 8),
			Size = UDim2.fromOffset(14, 30),
			TextSize = 15,
			TextColor3 = GREY,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Crest.draw(fixture, nextOpp, 30, { position = UDim2.fromOffset(64, 8) })
		-- X261: home or away decides who gets the home advantage in the sim
		local venue = if get("NextAtHome") == false then "away at" else "at home to"
		label(fixture, ("Match %d of %d next: %s %s.  You are %s."):format(played + 1, rounds, venue, nextOpp, ordinal(get("Position") or 1)), {
			Position = UDim2.fromOffset(106, 8),
			Size = UDim2.new(1, -116, 0, 30),
			TextSize = 15,
		})
	end
	local head = row(false)
	head.BackgroundColor3 = PANEL_BG
	cell(head, "#", 10, 30, { TextColor3 = GREY })
	cell(head, "Team", 76, 184, { TextColor3 = GREY })
	cell(head, "P", 270, 30, { TextColor3 = GREY })
	cell(head, "W", 305, 30, { TextColor3 = GREY })
	cell(head, "D", 340, 30, { TextColor3 = GREY })
	cell(head, "L", 375, 30, { TextColor3 = GREY })
	cell(head, "GD", 410, 40, { TextColor3 = GREY })
	cell(head, "Pts", 460, 40, { TextColor3 = GREY })
	local promo, releg = Config.PromotionSpots, Config.RelegationSpots
	-- X202: colour by what the places mean in this division (League.outcome):
	-- the top flight has only a champion, and nobody goes down from tier 1
	local tier = get("Tier") or 1
	local topFlight = tier >= #Config.Divisions
	for i, r in rows do
		local f = row(i % 2 == 0)
		if r.isPlayer then
			f.BackgroundColor3 = Theme.colors.playerRow
		end
		local goesUp = if topFlight then i == 1 else i <= promo
		local goesDown = tier > 1 and i > #rows - releg
		local posColor = if goesUp then Color3.fromRGB(120, 230, 120) elseif goesDown then Color3.fromRGB(240, 110, 110) else Color3.new(1, 1, 1)
		-- X266: promotion and relegation places were signalled by colour only.
		-- Drawn from rotated bars (like MatchSummary's chevron), so it needs no
		-- font glyph.
		cell(f, tostring(r.position), 10, 30, { TextColor3 = posColor, Font = Enum.Font.GothamBold })
		if goesUp or goesDown then
			local mark = Instance.new("Frame")
			mark.Name = if goesUp then "UpMark" else "DownMark"
			mark.BackgroundTransparency = 1
			mark.Size = UDim2.fromOffset(14, 14)
			mark.Position = UDim2.fromOffset(30, 8)
			mark.Parent = f
			for _, side in { -1, 1 } do
				local bar = Instance.new("Frame")
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Size = UDim2.fromOffset(9, 2)
				bar.BackgroundColor3 = posColor
				bar.BorderSizePixel = 0
				bar.Position = UDim2.fromScale(0.5 + side * 0.2, 0.5)
				bar.Rotation = if goesUp then side * 45 else -side * 45
				bar.Parent = mark
			end
		end
		-- X266: the promotion/relegation mark sits at x 30-44, so the crest moves right
		Crest.draw(f, r.name, 24, { isPlayer = r.isPlayer, position = UDim2.fromOffset(48, 3) })
		-- X258: a long club name used to wrap inside the one-line row
		cell(f, r.name, 76, 184, {
			Font = if r.isPlayer then Enum.Font.GothamBold else Enum.Font.Gotham,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		cell(f, tostring(r.played), 270, 30)
		cell(f, tostring(r.won), 305, 30)
		cell(f, tostring(r.drawn), 340, 30)
		cell(f, tostring(r.lost), 375, 30)
		cell(f, ("%+d"):format(r.gd), 410, 40)
		cell(f, tostring(r.points), 460, 40, { Font = Enum.Font.GothamBold, TextColor3 = ACCENT })
	end
	local up = if not topFlight then ("Top %d go up to the %s."):format(promo, Config.Divisions[tier + 1].name) else "This is the top flight: 1st are champions."
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
		markAffordable(hire, nextLevel.cost)
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

-- ---------------------------------------------------------------- Finance tab

-- X299: the panel had five tabs and none of them was money, so after ten
-- matches the only number in the game was the balance. Every movement is
-- recorded by category in ClubState (Finance.luau); this reads it back.
local FINANCE_LABELS: { [string]: string } = {
	gate = "Tickets",
	concessions = "Concessions",
	merch = "Merchandise", -- X353
	bonus = "Result bonuses",
	sponsor = "Shirt sponsor",
	prize = "Season prizes",
	sales = "Players sold",
	friendly = "Friendlies",
	transfers = "Transfers in",
	stands = "Stands",
	amenities = "Amenities",
	staff = "Coach & scouting",
	wages = "Wages", -- X350
	upkeep = "Staff upkeep",
	tradesIn = "Trades in",
	trades = "Trades out",
}

local function renderFinance()
	local raw = get("Finance")
	local ok, data = pcall(function()
		return if type(raw) == "string" and raw ~= "" then HttpService:JSONDecode(raw) else {}
	end)
	local ledger = if ok and type(data) == "table" then data else {}
	local income = if type(ledger.income) == "table" then ledger.income else {}
	local spend = if type(ledger.spend) == "table" then ledger.spend else {}
	local matches = if type(ledger.matches) == "table" then ledger.matches else {}

	local function total(t: { [string]: number }): number
		local sum = 0
		for _, v in t do
			sum += if type(v) == "number" then v else 0
		end
		return sum
	end
	local earned, spent = total(income), total(spend)

	section("CLUB BALANCE")
	note(("In: %s   ·   Out: %s   ·   Now: %s"):format(money(earned), money(spent), money(get("Cash") or 0)))
	if earned == 0 and spent == 0 then
		note("Nothing recorded yet. Play a match and it starts adding up.", GREY)
		return
	end

	local function table_(title: string, t: { [string]: number }, keys: { string }, colour: Color3)
		section(title)
		local any = false
		for i, key in keys do
			local amount = t[key]
			if type(amount) == "number" and amount > 0 then
				any = true
				local f = row(i % 2 == 0)
				cell(f, FINANCE_LABELS[key] or key, 10, 220)
				cell(f, money(amount), 240, 120, { TextColor3 = colour, Font = Enum.Font.GothamBold })
			end
		end
		if not any then
			note("Nothing yet.", GREY)
		end
	end
	table_("MONEY IN", income, Finance.INCOME, Theme.colors.cash)
	table_("MONEY OUT", spend, Finance.SPEND, Theme.colors.bad)

	if #matches > 0 then
		section(if #matches == 1 then "LAST MATCHDAY" else ("LAST %d MATCHDAYS"):format(#matches))
		-- Review of X325: six money columns need a 621-wide row, and a phone in
		-- portrait gives about 310 - so Sponsor and Total, the two the sponsor
		-- column was added to reconcile, fell off the right-hand edge of a
		-- ScrollingFrame that does not scroll sideways. Total is pinned to the
		-- row's right edge, and a narrow row drops the two middle columns
		-- (which are both spelled out in MONEY IN just above).
		-- X353 (review of my own): this row carries seven columns now, and
		-- Total is pinned to the right edge - at the old 560 threshold it
		-- started at 446 and sat on top of Costs at 435..505. A row needs
		-- 620 for all seven, so that is the threshold, and the columns are
		-- packed a little tighter.
		local wide = content.AbsoluteSize.X >= 620
		local head = row(false)
		head.BackgroundColor3 = PANEL_BG
		cell(head, "Match", 10, 60, { TextColor3 = GREY })
		cell(head, "Tickets", 75, 85, { TextColor3 = GREY })
		if wide then
			-- X353: the shop's take rides with the kiosks in one column, and is
			-- its own line in MONEY IN above
			cell(head, "Kiosks & shop", 165, 105, { TextColor3 = GREY })
			cell(head, "Bonus", 265, 65, { TextColor3 = GREY })
			cell(head, "Sponsor", 335, 75, { TextColor3 = GREY })
			cell(head, "Costs", 415, 70, { TextColor3 = GREY }) -- X350
		else
			cell(head, "Shop", 165, 80, { TextColor3 = GREY })
		end
		rightCell(head, "Total", 90, { TextColor3 = GREY })
		for i = #matches, 1, -1 do
			local m = matches[i]
			local f = row(i % 2 == 0)
			cell(f, ("%d"):format(m.round or 0), 10, 60, { TextColor3 = GREY })
			cell(f, money(m.gate or 0), 75, 85)
			local kiosks = (m.concessions or 0) + (m.merch or 0) -- X353
			if wide then
				cell(f, money(kiosks), 165, 105)
				cell(f, money(m.bonus or 0), 265, 65)
				cell(f, money(m.sponsor or 0), 335, 75)
				-- X350: shown as what it took off, so the row adds up
				cell(f, money(-(m.costs or 0)), 415, 70, { TextColor3 = Theme.colors.bad })
			else
				cell(f, money(kiosks), 165, 80)
			end
			local net = m.total or 0
			rightCell(f, money(net), 90, {
				TextColor3 = if net < 0 then Theme.colors.bad else Theme.colors.cash,
				Font = Enum.Font.GothamBold,
			})
		end
		if not wide then
			note("Bonus, sponsor and the matchday's costs are in the tables above.", GREY)
		end
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
	local promotionWord = if honours.promotions == 1 then "promotion" else "promotions"
	local relegationWord = if honours.relegations == 1 then "relegation" else "relegations"
	note(("%d league %s  ·  %d %s  ·  %d %s  ·  Highest level: %s"):format(
		honours.titles, titleWord, honours.promotions, promotionWord, honours.relegations, relegationWord,
		Config.Divisions[math.clamp(math.max(honours.bestTier, get("Tier") or 1), 1, #Config.Divisions)].name))
	note(("All-time record: %d played, %d won, %d drawn, %d lost."):format(
		get("MatchesPlayed") or 0, get("Wins") or 0, get("Draws") or 0, get("Losses") or 0), GREY)
	if honours.titles > 0 then
		note("Every title puts a trophy on the office shelf.", GREY)
	end

	-- X288: who played for the club. Retired players (X277) plus the current
	-- squad, so the appearance record does not vanish with the man who set it.
	local servants = data.servants or {}
	local club = loadClub()
	local topApps, topGoals = nil, nil
	local function consider(name: string, apps: number, goals: number)
		if not topApps or apps > topApps.n then
			topApps = { name = name, n = apps }
		end
		if not topGoals or goals > topGoals.n then
			topGoals = { name = name, n = goals }
		end
	end
	for _, s in servants do
		consider(s.name, s.apps or 0, s.goals or 0)
	end
	for _, p in (club and club.players or {}) do
		consider(p.name, p.apps or 0, p.goals or 0)
	end
	-- Review of X288: the goals half used to ride on the appearance guard, so a
	-- club whose first retiree never scored read "Most goals: <name> (0)".
	local parts = {}
	if topApps and topApps.n > 0 then
		table.insert(parts, ("Most appearances: %s (%d)"):format(topApps.name, topApps.n))
	end
	if topGoals and (topGoals :: any).n > 0 then
		table.insert(parts, ("Most goals: %s (%d)"):format((topGoals :: any).name, (topGoals :: any).n))
	end
	if #parts > 0 then
		note(table.concat(parts, "  ·  "))
	end

	if #servants > 0 then
		section(("CLUB SERVANTS (%d)"):format(#servants))
		note("Players who saw out their career here.", GREY)
		local shead = row(false)
		shead.BackgroundColor3 = PANEL_BG
		cell(shead, "Player", 10, 180, { TextColor3 = GREY })
		cell(shead, "Retired", 195, 90, { TextColor3 = GREY })
		cell(shead, "Apps", 290, 60, { TextColor3 = GREY })
		cell(shead, "Goals", 355, 60, { TextColor3 = GREY })
		for i, s in servants do
			local f = row(i % 2 == 0)
			cell(f, s.name, 10, 180, { Font = Enum.Font.GothamBold })
			cell(f, ("S%d, aged %d"):format(s.season, s.age), 195, 90, { TextColor3 = GREY })
			cell(f, tostring(s.apps), 290, 60)
			cell(f, tostring(s.goals), 355, 60)
		end
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

-- X294: last week's other results, under the table. The season only felt like
-- a league on the summary card; the tab that shows the table never said who
-- beat whom.
local function renderLastRound()
	local raw = get("LastRound")
	if type(raw) ~= "string" or raw == "" then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" or type(data.results) ~= "table" or #data.results == 0 then
		return
	end
	section(("MATCH %d ELSEWHERE"):format(data.round or 0))
	for i, r in data.results do
		local f = row(i % 2 == 0)
		cell(f, tostring(r.home), 10, 190, { TextXAlignment = Enum.TextXAlignment.Right })
		cell(f, ("%d - %d"):format(r.hg, r.ag), 205, 60, { Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
		cell(f, tostring(r.away), 270, 190)
	end
end

render = function()
	if not panel.Visible then
		return
	end
	cashLine.Text = money(get("Cash") or 0)
	Crest.update(crest, get("ClubName") or Config.ClubName, true)
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then ACCENT else Theme.colors.bg3
		b.TextColor3 = if name == currentTab then Theme.colors.bg else Theme.colors.text
	end
	local club = loadClub()
	-- The squad board updates in place, so it is never torn down and rebuilt.
	local onSquad = currentTab == "Squad" and club ~= nil
	squadPage.Visible = onSquad
	content.Visible = not onSquad
	if onSquad then
		renderSquad(club :: Club)
		return
	end
	clearContent()
	order = 0
	if not club then
		note("Loading club…")
		return
	end
	if not canManage() then
		note(("You are visiting %s. Only the owner can make changes."):format(get("ClubName") or "this club"), ACCENT)
	end
	if currentTab == "League" then
		renderLeague()
		renderLastRound() -- X294
	elseif currentTab == "Finance" then
		renderFinance()
	elseif currentTab == "History" then
		renderHistory()
	elseif currentTab == "Scouting" then
		renderScouting(club)
	else
		renderStaff(club)
	end
end

local function setOpen(open: boolean)
	-- X339: squad, transfers, scouting and finance are not the first thing a
	-- new player should meet. The naming card is up while `NeedsName` is true
	-- and `Phase` is already "Manage", so gating on the phase alone let the
	-- whole office render underneath it at second five - the front-loading
	-- CLAUDE.md s12 rules out. X250 made the same call for the matchday board.
	if open and (get("Phase") ~= "Manage" or get("NeedsName") == true) then
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

for _, key in { "Club", "Cash", "MatchesPlayed", "LeagueTable", "LastRound", "Demand", "History", "Finance", "ClubName", "OwnerUserId" } do
	state:GetAttributeChangedSignal(key):Connect(render)
end
-- X339: the button hides while the naming card is up as well as during a match
local function refreshOpenButton()
	local usable = get("Phase") == "Manage" and get("NeedsName") ~= true
	openButton.Visible = usable
	if not usable then
		setOpen(false)
	end
end
for _, key in { "Phase", "NeedsName" } do
	state:GetAttributeChangedSignal(key):Connect(refreshOpenButton)
end
refreshOpenButton()
