--!strict
-- Lightweight HUD: cash, scoreboard during matches, post-match summary, hints.
-- Built in code so it lives in git. Deliberately plain for Milestone 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ClubState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local summaryEvent = remotes:WaitForChild("MatchSummary") :: RemoteEvent
local toastEvent = remotes:WaitForChild("Toast") :: RemoteEvent
local tacticEvent = remotes:WaitForChild("Tactic") :: RemoteEvent

local function money(n: number): string
	local s = tostring(math.floor(n))
	local withCommas = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return "£" .. withCommas
end

local function get(key: string): any
	return state:GetAttribute(key)
end

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name: string, parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

local function makePanel(name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = gui
	return frame
end

-- Cash (top-left)
local cashLabel = makeLabel("Cash", gui, {
	Size = UDim2.fromOffset(220, 40),
	Position = UDim2.fromOffset(20, 50),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 230, 120),
})

-- Hint (bottom-centre)
local hintLabel = makeLabel("Hint", gui, {
	Size = UDim2.new(0.6, 0, 0, 30),
	Position = UDim2.new(0.5, 0, 1, -40),
	AnchorPoint = Vector2.new(0.5, 1),
	TextColor3 = Color3.fromRGB(255, 230, 150),
})

-- Scoreboard (top-centre, only during matches)
local scoreboard = makePanel("Scoreboard", UDim2.fromOffset(420, 60), UDim2.new(0.5, 0, 0, 70))
local scoreLabel = makeLabel("Score", scoreboard, { Size = UDim2.new(1, -20, 0.6, 0), Position = UDim2.fromOffset(10, 2) })
local clockLabel = makeLabel("Clock", scoreboard, {
	Size = UDim2.new(1, -20, 0.35, 0),
	Position = UDim2.new(0, 10, 0.62, 0),
	TextColor3 = Color3.fromRGB(200, 200, 200),
})
scoreboard.Visible = false

-- Matchday banner (PreMatch only)
local banner = makePanel("Banner", UDim2.fromOffset(520, 90), UDim2.new(0.5, 0, 0, 90))
local bannerTitle = makeLabel("Title", banner, {
	Size = UDim2.new(1, -20, 0.45, 0),
	Position = UDim2.fromOffset(10, 6),
	TextColor3 = Color3.fromRGB(255, 230, 150),
})
bannerTitle.Text = "MATCHDAY"
local bannerBody = makeLabel("Body", banner, { Size = UDim2.new(1, -20, 0.45, 0), Position = UDim2.new(0, 10, 0.5, 0) })
banner.Visible = false

-- Big centre flash (GOAL! / KICK-OFF / FULL TIME)
local flashLabel = makeLabel("Flash", gui, {
	Size = UDim2.new(0.6, 0, 0, 90),
	Position = UDim2.fromScale(0.5, 0.3),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
})
local flashToken = 0
local function flash(text: string, color: Color3, seconds: number)
	flashToken += 1
	local myToken = flashToken
	flashLabel.Text = text
	flashLabel.TextColor3 = color
	flashLabel.Visible = true
	task.delay(seconds, function()
		if flashToken == myToken then
			flashLabel.Visible = false
		end
	end)
end

-- Tactics (bottom-right, Match only). Attack / Defend toggle back to Balanced.
local tactics = makePanel("Tactics", UDim2.fromOffset(170, 160), UDim2.new(1, -105, 1, -110))
tactics.Visible = false
local function makeButton(name: string, y: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, -20, 0, 42)
	b.Position = UDim2.new(0, 10, 0, y)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = name:upper()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Parent = tactics
	return b
end
local attackButton = makeButton("Attack", 10, Color3.fromRGB(200, 60, 60))
local defendButton = makeButton("Defend", 58, Color3.fromRGB(60, 100, 200))
local subButton = makeButton("Sub", 106, Color3.fromRGB(90, 90, 90))

local function refreshTacticButtons()
	local current = get("Tactic") or "Balanced"
	for _, pair in { { attackButton, "Attack" }, { defendButton, "Defend" } } do
		local button, name = pair[1] :: TextButton, pair[2] :: string
		local active = current == name
		button.BackgroundTransparency = active and 0 or 0.55
		button.Text = active and (name:upper() .. "  ✓") or name:upper()
	end
	local subs = HttpService:JSONDecode(get("Subs") or "[]")
	subButton.Text = ("SUB  (%d left)"):format(math.max(Config.MaxSubs - #subs, 0))
end
attackButton.Activated:Connect(function()
	tacticEvent:FireServer(get("Tactic") == "Attack" and "Balanced" or "Attack")
end)
defendButton.Activated:Connect(function()
	tacticEvent:FireServer(get("Tactic") == "Defend" and "Balanced" or "Defend")
end)
subButton.Activated:Connect(function()
	tacticEvent:FireServer("Sub")
end)

-- Post-match summary (centre)
local summary = makePanel("Summary", UDim2.fromOffset(420, 360), UDim2.fromScale(0.5, 0.5))
summary.Visible = false
local summaryTitle = makeLabel("Title", summary, { Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 10) })
local summaryBody = makeLabel("Body", summary, {
	Size = UDim2.new(1, -40, 1, -130),
	Position = UDim2.fromOffset(20, 60),
	Font = Enum.Font.Gotham,
	TextScaled = false,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	RichText = true,
})
local continueButton = Instance.new("TextButton")
continueButton.Name = "Continue"
continueButton.Size = UDim2.fromOffset(200, 44)
continueButton.Position = UDim2.new(0.5, 0, 1, -16)
continueButton.AnchorPoint = Vector2.new(0.5, 1)
continueButton.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
continueButton.Font = Enum.Font.GothamBold
continueButton.TextSize = 20
continueButton.TextColor3 = Color3.new(1, 1, 1)
continueButton.Text = "Continue"
continueButton.Parent = summary
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = continueButton
continueButton.Activated:Connect(function()
	summary.Visible = false
end)

-- Toast (just above the hint)
local toastLabel = makeLabel("Toast", gui, {
	Size = UDim2.new(0.6, 0, 0, 30),
	Position = UDim2.new(0.5, 0, 1, -80),
	AnchorPoint = Vector2.new(0.5, 1),
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Visible = false,
})
local toastToken = 0
local function showToast(message: string, color: Color3?)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = message
	toastLabel.TextColor3 = color or Color3.fromRGB(255, 120, 120)
	toastLabel.Visible = true
	task.delay(2.5, function()
		if toastToken == myToken then
			toastLabel.Visible = false
		end
	end)
end
toastEvent.OnClientEvent:Connect(function(message: string)
	showToast(message)
end)

local function refreshHint()
	local phase = get("Phase")
	if phase == "PreMatch" then
		hintLabel.Text = "Matchday! The teams are walking out."
		return
	elseif phase == "Match" then
		hintLabel.Text = "Match on. Walk around and watch, or use ATTACK / DEFEND / SUB."
		return
	end
	local played = get("MatchesPlayed") or 0
	local level = get("StandLevel") or 1
	if played == 0 then
		hintLabel.Text = "Head out to the MATCHDAY board and play your first match."
	elseif level == 1 then
		hintLabel.Text = "Fans were turned away. Expand the stand (yellow sign by the bleachers)."
	else
		hintLabel.Text = "Play the next match at the MATCHDAY board."
	end
end

local function refreshCash()
	cashLabel.Text = money(get("Cash") or 0)
end

local lastMinute = 0
local function refreshScoreboard()
	local inMatch = get("Phase") == "Match"
	scoreboard.Visible = inMatch
	if not inMatch then
		return
	end
	scoreLabel.Text = ("%s  %d - %d  %s"):format(get("ClubName") or "Home", get("HomeGoals") or 0, get("AwayGoals") or 0, get("Opponent") or "Away")
	local total = get("TimeLeft") or 0
	-- show a football minute rather than raw seconds; the real clock is hidden
	local elapsedFrac = 1 - (total / math.max(get("MatchDuration") or 90, 1))
	local minute = math.clamp(math.floor(elapsedFrac * 90), 0, 90)
	clockLabel.Text = ("%d'"):format(minute)
	if minute >= 45 and lastMinute < 45 then
		flash("HALF TIME", Color3.new(1, 1, 1), 2)
	end
	lastMinute = minute
end

for _, key in { "Cash" } do
	state:GetAttributeChangedSignal(key):Connect(refreshCash)
end
for _, key in { "Phase", "HomeGoals", "AwayGoals", "TimeLeft", "Opponent" } do
	state:GetAttributeChangedSignal(key):Connect(refreshScoreboard)
end
for _, key in { "Phase", "MatchesPlayed", "StandLevel" } do
	state:GetAttributeChangedSignal(key):Connect(refreshHint)
end

local function refreshPhasePanels()
	local phase = get("Phase")
	banner.Visible = phase == "PreMatch"
	tactics.Visible = phase == "Match"
	if phase == "PreMatch" then
		summary.Visible = false -- a lingering summary must never cover the next match
		bannerBody.Text = ("%s  vs  %s"):format(get("ClubName") or "Home", get("Opponent") or "Away")
	end
end

local lastPhase = get("Phase")
state:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = get("Phase")
	if lastPhase == "Match" and phase == "Manage" then
		flash("FULL TIME", Color3.new(1, 1, 1), 3)
	elseif phase == "Match" then
		lastMinute = 0
		flash("KICK-OFF", Color3.new(1, 1, 1), 1.5)
	end
	lastPhase = phase
	refreshPhasePanels()
	refreshTacticButtons()
end)
state:GetAttributeChangedSignal("Opponent"):Connect(refreshPhasePanels)
state:GetAttributeChangedSignal("Tactic"):Connect(refreshTacticButtons)

local function onGoal(team: string)
	if get("Phase") ~= "Match" then
		return
	end
	if team == "Home" then
		flash("GOAL!", Color3.fromRGB(255, 230, 80), 2.5)
	else
		flash(("%s score"):format(get("Opponent") or "They"), Color3.fromRGB(255, 120, 120), 2.5)
	end
end
-- Goals only ever go up during a match; the reset to 0 at kickoff is ignored.
state:GetAttributeChangedSignal("HomeGoals"):Connect(function()
	if (get("HomeGoals") or 0) > 0 then
		onGoal("Home")
	end
end)
state:GetAttributeChangedSignal("AwayGoals"):Connect(function()
	if (get("AwayGoals") or 0) > 0 then
		onGoal("Away")
	end
end)

state:GetAttributeChangedSignal("Subs"):Connect(function()
	refreshTacticButtons()
	local subs = HttpService:JSONDecode(get("Subs") or "[]")
	local raw = get("Timeline")
	if #subs == 0 or type(raw) ~= "string" or raw == "" then
		return
	end
	local sub = subs[#subs]
	local squad = HttpService:JSONDecode(raw).home.squad
	local outP, inP = squad[sub.out], squad[sub["in"]]
	if outP and inP then
		showToast(("SUB: %d %s on, %d %s off"):format(inP.number, inP.name, outP.number, outP.name), Color3.fromRGB(150, 220, 255))
	end
end)

refreshPhasePanels()
refreshTacticButtons()

summaryEvent.OnClientEvent:Connect(function(data)
	local outcomeText = data.outcome == "Win" and "WIN" or (data.outcome == "Draw" and "DRAW" or "LOSS")
	summaryTitle.Text = ("%s  %d - %d  %s   (%s)"):format(get("ClubName") or "Home", data.homeGoals, data.awayGoals, data.opponent, outcomeText)
	local lines = {
		("Attendance: <b>%d</b> / %d seats"):format(data.attendance, data.capacity),
	}
	if data.turnedAway > 0 then
		table.insert(lines, ("<font color=\"#ff8080\">Fans turned away: <b>%d</b></font>"):format(data.turnedAway))
	end
	table.insert(lines, "")
	table.insert(lines, ("Ticket revenue: %s"):format(money(data.ticketRevenue)))
	table.insert(lines, ("Result bonus: %s"):format(money(data.resultBonus)))
	table.insert(lines, ("<b>Total earned: %s</b>"):format(money(data.total)))
	table.insert(lines, "")
	table.insert(lines, ("Club cash: <b>%s</b>"):format(money(data.cash)))
	summaryBody.Text = table.concat(lines, "\n")
	summary.Visible = true
end)

refreshCash()
refreshScoreboard()
refreshHint()
