--!strict
-- Lightweight HUD: cash, scoreboard during matches, post-match summary, hints.
-- Built in code so it lives in git. Deliberately plain for Milestone 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("ClubState")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local summaryEvent = remotes:WaitForChild("MatchSummary") :: RemoteEvent
local toastEvent = remotes:WaitForChild("Toast") :: RemoteEvent

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
toastEvent.OnClientEvent:Connect(function(message: string)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(2.5, function()
		if toastToken == myToken then
			toastLabel.Visible = false
		end
	end)
end)

local function refreshHint()
	if get("Phase") == "Match" then
		hintLabel.Text = "Match in progress. Walk around and watch."
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
	clockLabel.Text = ("%d'"):format(math.clamp(math.floor(elapsedFrac * 90), 0, 90))
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
