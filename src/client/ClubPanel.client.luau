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
	Size = UDim2.new(0.86, 0, 0.8, 0),
	Position = UDim2.fromScale(0.5, 0.52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
})
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(760, 540)
sizeLimit.Parent = panel

local title = Theme.text(panel, "CLUB OFFICE", "display", {
	TextSize = 24,
	Position = UDim2.fromOffset(18, 12),
	Size = UDim2.new(1, -300, 0, 30),
})

local closeButton = button(panel, "✕", Color3.fromRGB(70, 70, 80), {
	Name = "Close",
	Size = UDim2.fromOffset(36, 30),
	Position = UDim2.new(1, -46, 0, 12),
})

local cashLine = Theme.pill(panel, "CashLine", {
	Position = UDim2.new(1, -56, 0, 10),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(170, 34),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Theme.colors.cash,
	BackgroundColor3 = Theme.colors.bg2,
})

-- tabs
local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(18, 52)
tabs.Size = UDim2.new(1, -36, 0, 34)
tabs.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(18, 96)
content.Size = UDim2.new(1, -36, 1, -110)
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

for i, name in { "Squad", "League", "History", "Scouting", "Staff" } do
	local b = button(tabs, name:upper(), ROW_BG, { Name = name .. "Tab", Size = UDim2.fromOffset(118, 32), LayoutOrder = i, TextSize = 14 })
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
		f.BackgroundColor3 = Theme.colors.selected
	end
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	canRelease = canRelease and canManage()
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
		if not canManage() then
			return
		end
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
	if canManage() then
		local toggle = button(head, if club.autoSquad then "AUTO SQUAD: ON" else "AUTO SQUAD: OFF", if club.autoSquad then GREEN else Color3.fromRGB(90, 90, 100), {
			Size = UDim2.fromOffset(170, 28),
			Position = UDim2.fromOffset(0, 1),
		})
		toggle.Activated:Connect(function()
			actionEvent:FireServer("setAutoSquad", not club.autoSquad)
		end)
		cell(head, if club.autoSquad then "The best fit XI is picked for you." else "Tap two players to swap them.", 180, 400, { TextColor3 = GREY })
	else
		cell(head, if club.autoSquad then "Auto Squad is on." else "The owner picks the team by hand.", 0, 400, { TextColor3 = GREY })
	end

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
	if nextLevel and canManage() then
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
			if canManage() then
				local sign = button(f, ("Sign  %s"):format(money(p.fee or 0)), GREEN, {
					Size = UDim2.fromOffset(150, 24),
					Position = UDim2.new(1, -156, 0, 3),
					TextSize = 13,
				})
				sign.Activated:Connect(function()
					actionEvent:FireServer("sign", p.id)
				end)
			else
				cell(f, money(p.fee or 0), 450, 100, { TextColor3 = GREY })
			end
		end
		note("POT = potential. Young players with headroom improve over time, faster with a coach.")
	end
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
