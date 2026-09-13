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
}
type Club = {
	players: { Player },
	lineup: { xi: { number }, bench: { number } },
	autoSquad: boolean,
	coachLevel: number,
	scoutLevel: number,
	shortlist: { Player },
}

local ROLE_ORDER = { "GK", "DEF", "DEF", "DEF", "DEF", "MID", "MID", "MID", "MID", "FWD", "FWD" }

local function money(n: number): string
	local s = tostring(math.floor(n))
	local withCommas = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return "£" .. withCommas
end

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

local gui = Instance.new("ScreenGui")
gui.Name = "ClubPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local PANEL_BG = Color3.fromRGB(22, 27, 34)
local ROW_BG = Color3.fromRGB(34, 41, 50)
local ROW_ALT = Color3.fromRGB(40, 48, 58)
local ACCENT = Color3.fromRGB(255, 210, 90)
local GREEN = Color3.fromRGB(70, 170, 90)
local RED = Color3.fromRGB(200, 70, 70)
local GREY = Color3.fromRGB(150, 150, 150)

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, 24)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 15
	b.Text = text
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(160, 32)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	corner(b, 6)
	b.Parent = parent
	return b
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0.86, 0, 0.8, 0)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = PANEL_BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 12)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(720, 520)
sizeLimit.Parent = panel

local title = label(panel, "CLUB OFFICE", {
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = ACCENT,
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -120, 0, 30),
})

local closeButton = button(panel, "X", Color3.fromRGB(70, 70, 80), {
	Name = "Close",
	Size = UDim2.fromOffset(36, 30),
	Position = UDim2.new(1, -46, 0, 10),
})

local cashLine = label(panel, "", {
	Position = UDim2.new(1, -260, 0, 14),
	Size = UDim2.fromOffset(200, 24),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(120, 230, 120),
	Font = Enum.Font.GothamBold,
})

-- tabs
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(16, 48)
tabs.Size = UDim2.new(1, -32, 0, 34)
tabs.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(16, 90)
content.Size = UDim2.new(1, -32, 1, -104)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = panel
local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 4)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local currentTab = "Squad"
local selectedId: number? = nil
local tabButtons: { [string]: TextButton } = {}

local render: () -> ()

for i, name in { "Squad", "Scouting", "Staff" } do
	local b = button(tabs, name:upper(), ROW_BG, { Name = name .. "Tab", Size = UDim2.fromOffset(120, 32), LayoutOrder = i })
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
	corner(f, 6)
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

local function statusText(p: Player): (string, Color3)
	if p.injured > 0 then
		return ("INJ %d"):format(p.injured), RED
	end
	return "", GREY
end

-- ------------------------------------------------------------------ Squad tab

local function playerRow(p: Player, slotLabel: string, alt: boolean, club: Club, canRelease: boolean)
	local f = row(alt)
	local isSelected = selectedId == p.id
	if isSelected then
		f.BackgroundColor3 = Color3.fromRGB(80, 70, 30)
	end
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.new(1, if canRelease then -90 else 0, 1, 0)
	hit.Parent = f
	cell(f, slotLabel, 10, 46, { TextColor3 = GREY, Font = Enum.Font.GothamBold })
	cell(f, ("%d"):format(p.number), 58, 30, { TextColor3 = GREY })
	cell(f, p.name, 90, 190, { Font = Enum.Font.GothamBold })
	cell(f, p.role, 285, 40, { TextColor3 = GREY })
	cell(f, ("age %d"):format(p.age), 330, 60, { TextColor3 = GREY })
	cell(f, ("%d"):format(p.overall), 395, 40, { Font = Enum.Font.GothamBold, TextColor3 = ACCENT })
	cell(f, ("%dA %dG"):format(p.apps, p.goals), 440, 80, { TextColor3 = GREY })
	local st, stColor = statusText(p)
	cell(f, st, 525, 70, { TextColor3 = stColor, Font = Enum.Font.GothamBold })

	hit.Activated:Connect(function()
		-- with Auto Squad on the server refuses the swap and explains why
		if selectedId == nil then
			selectedId = p.id
			render()
		elseif selectedId == p.id then
			selectedId = nil
			render()
		else
			actionEvent:FireServer("swap", selectedId, p.id)
			selectedId = nil
		end
	end)

	if canRelease then
		local rel = button(f, "Release", Color3.fromRGB(90, 60, 60), {
			Size = UDim2.fromOffset(80, 24),
			Position = UDim2.new(1, -86, 0, 3),
			TextSize = 13,
		})
		rel.Activated:Connect(function()
			actionEvent:FireServer("release", p.id)
		end)
	end
end

local function renderSquad(club: Club)
	local byId: { [number]: Player } = {}
	for _, p in club.players do
		byId[p.id] = p
	end

	local head = row(false)
	head.BackgroundColor3 = PANEL_BG
	local toggle = button(head, if club.autoSquad then "AUTO SQUAD: ON" else "AUTO SQUAD: OFF", if club.autoSquad then GREEN else Color3.fromRGB(90, 90, 100), {
		Size = UDim2.fromOffset(170, 28),
		Position = UDim2.fromOffset(0, 1),
	})
	toggle.Activated:Connect(function()
		actionEvent:FireServer("setAutoSquad", not club.autoSquad)
	end)
	cell(head, if club.autoSquad then "The best fit XI is picked for you." else "Tap two players to swap them.", 180, 400, { TextColor3 = GREY })

	section("STARTING XI")
	local used: { [number]: boolean } = {}
	for slot, role in ROLE_ORDER do
		local id = club.lineup.xi[slot]
		local p = if id then byId[id] else nil
		if p then
			used[p.id] = true
			playerRow(p, role, slot % 2 == 0, club, false)
		else
			local f = row(slot % 2 == 0)
			cell(f, role, 10, 46, { TextColor3 = GREY, Font = Enum.Font.GothamBold })
			cell(f, "— empty —", 90, 200, { TextColor3 = RED })
		end
	end

	section("BENCH")
	for i, id in club.lineup.bench do
		local p = byId[id]
		if p then
			used[p.id] = true
			playerRow(p, "SUB", i % 2 == 0, club, false)
		end
	end

	local reserves = {}
	for _, p in club.players do
		if not used[p.id] then
			table.insert(reserves, p)
		end
	end
	if #reserves > 0 then
		section(("RESERVES (%d)"):format(#reserves))
		for i, p in reserves do
			playerRow(p, "", i % 2 == 0, club, true)
		end
	end
	note(("Squad: %d / %d players.  OVR = overall rating.  A = appearances, G = goals."):format(#club.players, Config.SquadMax))
end

-- --------------------------------------------------------------- Scouting tab

local function renderScouting(club: Club)
	local played = (get("MatchesPlayed") or 0) :: number
	if played < 1 then
		section("SCOUTING")
		note("Scouting opens after your first match. Play it from the MATCHDAY board.")
		return
	end
	local level = Config.ScoutLevels[club.scoutLevel]
	local nextLevel = Config.ScoutLevels[club.scoutLevel + 1]
	section("SCOUT")
	if not level then
		note("No scout yet. A scout brings you a short list of players you can sign, refreshed after every match.")
	else
		note(("%s — finds %d prospects after every match."):format(level.name, level.prospects))
	end
	if nextLevel then
		local hire = button(content, ("%s %s — %s"):format(if level then "Upgrade to" else "Hire", nextLevel.name, money(nextLevel.cost)), GREEN, {
			Size = UDim2.fromOffset(340, 34),
			LayoutOrder = nextOrder(),
		})
		hire.Activated:Connect(function()
			actionEvent:FireServer(if level then "upgradeScout" else "hireScout")
		end)
	end

	if level then
		section(("SHORTLIST (%d)"):format(#club.shortlist))
		if #club.shortlist == 0 then
			note("Nobody left on the list. New prospects arrive after the next match.")
		end
		for i, p in club.shortlist do
			local f = row(i % 2 == 0)
			cell(f, p.name, 10, 190, { Font = Enum.Font.GothamBold })
			cell(f, p.role, 205, 40, { TextColor3 = GREY })
			cell(f, ("age %d"):format(p.age), 250, 60, { TextColor3 = GREY })
			cell(f, ("OVR %d"):format(p.overall), 315, 60, { Font = Enum.Font.GothamBold, TextColor3 = ACCENT })
			cell(f, ("POT %d"):format(p.potential), 380, 60, { TextColor3 = Color3.fromRGB(150, 220, 255) })
			local sign = button(f, ("Sign  %s"):format(money(p.fee or 0)), GREEN, {
				Size = UDim2.fromOffset(150, 24),
				Position = UDim2.new(1, -156, 0, 3),
				TextSize = 13,
			})
			sign.Activated:Connect(function()
				actionEvent:FireServer("sign", p.id)
			end)
		end
		note("POT = potential. Young players with headroom improve over time, faster with a coach.")
	end
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
	if nextLevel then
		local hire = button(content, ("%s %s — %s"):format(if club.coachLevel == 0 then "Hire" else "Upgrade to", nextLevel.name, money(nextLevel.cost)), GREEN, {
			Size = UDim2.fromOffset(340, 34),
			LayoutOrder = nextOrder(),
		})
		hire.Activated:Connect(function()
			actionEvent:FireServer(if club.coachLevel == 0 then "hireCoach" else "upgradeCoach")
		end)
		note(("Next: +%d team strength, %.1fx development."):format(nextLevel.strengthBonus, nextLevel.developMultiplier), GREY)
	else
		note("Coaching is fully upgraded.", GREY)
	end
end

render = function()
	if not panel.Visible then
		return
	end
	clearContent()
	order = 0
	cashLine.Text = money(get("Cash") or 0)
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then ACCENT else ROW_BG
		b.TextColor3 = if name == currentTab then Color3.fromRGB(30, 30, 30) else Color3.new(1, 1, 1)
	end
	local club = loadClub()
	if not club then
		note("Loading club…")
		return
	end
	if currentTab == "Squad" then
		renderSquad(club)
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
local openButton = button(gui, "CLUB", Color3.fromRGB(40, 50, 65), {
	Name = "Open",
	Size = UDim2.fromOffset(90, 32),
	Position = UDim2.fromOffset(20, 96),
	TextSize = 16,
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

for _, key in { "Club", "Cash", "MatchesPlayed" } do
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
