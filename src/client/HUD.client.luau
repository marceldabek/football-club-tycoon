--!strict
-- Lightweight HUD: cash, season line, hints, scoreboard and tactics during
-- matches, post-match / season / welcome cards, loading cover, toasts.
-- Every widget comes from Theme so the whole game shares one look.

local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local MatchAudio = require(script.Parent.MatchAudio)
local MatchSummary = require(script.Parent.MatchSummary)
local Crest = require(script.Parent.Crest)
local Sky = require(script.Parent.Sky)

local player = Players.LocalPlayer
local state = require(script.Parent.ClubRef).waitState()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local summaryEvent = remotes:WaitForChild("MatchSummary") :: RemoteEvent
local toastEvent = remotes:WaitForChild("Toast") :: RemoteEvent
local tacticEvent = remotes:WaitForChild("Tactic") :: RemoteEvent
local playMatchEvent = remotes:WaitForChild("PlayMatch") :: RemoteEvent
local goHomeEvent = remotes:WaitForChild("GoHome") :: RemoteEvent

local money, ordinal, rich = Theme.money, Theme.ordinal, Theme.rich
local C = Theme.colors

local function get(key: string): any
	return state:GetAttribute(key)
end

local gui = Theme.screenGui("TycoonHUD", 1)
gui.Parent = player:WaitForChild("PlayerGui")

-- ------------------------------------------------------------ top-left stack

local cashLabel = Theme.pill(gui, "Cash", {
	Size = UDim2.fromOffset(220, 38),
	Position = UDim2.fromOffset(20, 50),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 20,
	TextColor3 = C.cash,
})

-- (the CLUB button lives in ClubPanel at y = 96)

-- GO TO MY CLUB (B4.2): teleports the owner home from anywhere in town.
-- Sits under the CLUB OFFICE button; the season line below it is wide, so
-- this row sits below that instead of squeezing beside it.
local goHomeButton = Theme.button(gui, "GO TO MY CLUB", "info", {
	Name = "GoHome",
	Size = UDim2.fromOffset(140, 34),
	Position = UDim2.fromOffset(20, 164),
	TextSize = 14,
})
goHomeButton.Activated:Connect(function()
	goHomeEvent:FireServer()
end)

local seasonLabel = Theme.text(gui, "", "muted", {
	Name = "Season",
	Size = UDim2.fromOffset(560, 22),
	Position = UDim2.fromOffset(24, 136),
	Font = Theme.fonts.bold,
	TextSize = 15,
	TextStrokeTransparency = 0.6,
})

local function refreshSeason()
	local round, rounds = get("Round") or 0, get("Rounds") or 10
	local division = get("DivisionName") or ""
	if round == 0 then
		seasonLabel.Text = ("%s   ·   Season %d   ·   Match 1 of %d next"):format(division, get("Season") or 1, rounds)
	else
		seasonLabel.Text = ("%s   ·   Match %d of %d played   ·   %s"):format(division, round, rounds, ordinal(get("Position") or 1))
	end
end
for _, key in { "Round", "Position", "DivisionName", "Season" } do
	state:GetAttributeChangedSignal(key):Connect(refreshSeason)
end
refreshSeason()

-- --------------------------------------------------------------- top-right

local musicButton = Theme.button(gui, "", "ghost", {
	Name = "MusicToggle",
	Size = UDim2.fromOffset(130, 34),
	Position = UDim2.new(1, -20, 0, 52),
	AnchorPoint = Vector2.new(1, 0),
})
local function refreshMusicButton()
	local on = MatchAudio.isMusicEnabled()
	musicButton.Text = on and "♪  Music on" or "♪  Music off"
	musicButton.TextColor3 = on and C.text or C.muted
end
musicButton.Activated:Connect(function()
	MatchAudio.setMusicEnabled(not MatchAudio.isMusicEnabled())
	refreshMusicButton()
end)
refreshMusicButton()

-- -------------------------------------------------------------- top-centre

-- PLAY MATCH (Manage only, owner only). The world board still works; this is
-- the always-visible way to start the next fixture.
local playButton = Theme.button(gui, "PLAY MATCH", "primary", {
	Name = "PlayMatch",
	Size = UDim2.fromOffset(300, 48),
	Position = UDim2.new(0.5, 0, 0, 48),
	AnchorPoint = Vector2.new(0.5, 0),
	TextSize = 18,
	-- the button grows with its label, so the text can never outrun the box
	AutomaticSize = Enum.AutomaticSize.X,
	Visible = false,
})
Theme.padding(playButton, 0, 26)
local playSize = Instance.new("UISizeConstraint")
playSize.MinSize = Vector2.new(300, 48)
playSize.Parent = playButton
local playCooldown = false
playButton.Activated:Connect(function()
	if playCooldown then
		return
	end
	playCooldown = true
	playMatchEvent:FireServer()
	task.delay(1.5, function()
		playCooldown = false
	end)
end)
local function refreshPlayButton()
	local show = get("Phase") == "Manage" and get("OwnerUserId") == player.UserId and get("NeedsName") ~= true
	playButton.Visible = show
	if not show then
		return
	end
	local nextOpp = get("NextOpponent") or ""
	if (get("MatchesPlayed") or 0) == 0 then
		playButton.Text = "PLAY YOUR FIRST MATCH"
	elseif nextOpp ~= "" then
		playButton.Text = ("PLAY MATCH  ·  vs %s"):format(nextOpp)
	else
		playButton.Text = "PLAY MATCH"
	end
end

-- Scoreboard (Match only): club names either side of the score, clock below
local scoreboard = Theme.panel(gui, "Scoreboard", {
	Size = UDim2.fromOffset(460, 68),
	Position = UDim2.new(0.5, 0, 0, 44),
	AnchorPoint = Vector2.new(0.5, 0),
	Visible = false,
})
-- Both crests sit on the scoreboard so a glance up mid-match says who is who
-- without reading the names.
local homeCrest = Crest.draw(scoreboard, Config.ClubName, 34, { isPlayer = true, position = UDim2.fromOffset(14, 8) })
local awayCrest = Crest.draw(scoreboard, nil, 34, { position = UDim2.new(1, -48, 0, 8) })
local scoreLabel = Theme.text(scoreboard, "", "body", {
	Name = "Score",
	Size = UDim2.new(1, -112, 0, 34),
	Position = UDim2.fromOffset(56, 6),
	Font = Theme.fonts.display,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
})
-- X189: two long club names shrink to fit one line instead of wrapping and
-- clipping (TextScaled can't be used without wrapping, so size by hand)
scoreLabel.TextWrapped = false
local function fitScoreText()
	local width = scoreLabel.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local size = 24
	while size > 10 and TextService:GetTextSize(scoreLabel.Text, size, scoreLabel.Font, Vector2.new(10000, 100)).X > width do
		size -= 1
	end
	scoreLabel.TextSize = size
end
scoreLabel:GetPropertyChangedSignal("Text"):Connect(fitScoreText)
scoreLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScoreText)
local clockLabel = Theme.text(scoreboard, "", "muted", {
	Name = "Clock",
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.fromOffset(12, 42),
	Font = Theme.fonts.bold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- Matchday banner (PreMatch only)
local banner = Theme.panel(gui, "Banner", {
	Size = UDim2.fromOffset(520, 84),
	Position = UDim2.new(0.5, 0, 0, 60),
	AnchorPoint = Vector2.new(0.5, 0),
	Visible = false,
})
Theme.text(banner, "MATCHDAY", "display", {
	Name = "Title",
	Size = UDim2.new(1, -24, 0, 36),
	Position = UDim2.fromOffset(12, 8),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local bannerBody = Theme.text(banner, "", "body", {
	Name = "Body",
	Size = UDim2.new(1, -24, 0, 26),
	Position = UDim2.fromOffset(12, 46),
	Font = Theme.fonts.bold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- Big centre flash (GOAL! / KICK-OFF / FULL TIME)
local flashLabel = Theme.text(gui, "", "display", {
	Name = "Flash",
	Size = UDim2.new(0.6, 0, 0, 90),
	Position = UDim2.fromScale(0.5, 0.3),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.5,
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

-- ------------------------------------------------------------ bottom-right

-- Tactics (Match only). Attack / Defend toggle back to Balanced.
local tactics = Theme.panel(gui, "Tactics", {
	Size = UDim2.fromOffset(180, 166),
	Position = UDim2.new(1, -20, 1, -30),
	AnchorPoint = Vector2.new(1, 1),
	Visible = false,
})
local function tacticButton(name: string, y: number, variant: Theme.ButtonVariant): TextButton
	return Theme.button(tactics, name:upper(), variant, {
		Name = name,
		Size = UDim2.new(1, -20, 0, 42),
		Position = UDim2.fromOffset(10, y),
		TextSize = 17,
	})
end
local attackButton = tacticButton("Attack", 10, "danger")
local defendButton = tacticButton("Defend", 60, "info")
local subButton = tacticButton("Sub", 110, "secondary")

local function refreshTacticButtons()
	local current = get("Tactic") or "Balanced"
	for _, pair in { { attackButton, "Attack" }, { defendButton, "Defend" } } do
		local button, name = pair[1] :: TextButton, pair[2] :: string
		local active = current == name
		button.BackgroundTransparency = active and 0 or 0.6
		button.Text = active and (name:upper() .. "  ·  ON") or name:upper()
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

-- ------------------------------------------------------------------- cards

local summary = MatchSummary.new(gui)
local summaryContinue = summary.continueButton

local seasonCard = Theme.card(gui, "SeasonOver", "SEASON OVER", UDim2.fromOffset(480, 330))
local seasonContinue = seasonCard.addButton("Next season", "primary")
-- depth of field behind the full-screen cards
local Focus = require(script.Parent.Focus)
Focus.watch(summary.frame)
Focus.watch(seasonCard.frame)
seasonContinue.Activated:Connect(function()
	seasonCard.frame.Visible = false
	Sky.fastForward("season") -- the long night between seasons
end)

local pendingSeason: any = nil
local function showSeason(data)
	seasonCard.title.Text = ("SEASON %d OVER"):format(data.season)
	local headline
	if data.outcome == "Promoted" then
		headline = rich(("PROMOTED to the %s!"):format(data.nextDivision), C.good, true)
	elseif data.outcome == "Relegated" then
		headline = rich(("Relegated to the %s."):format(data.nextDivision), C.bad, true)
	elseif data.outcome == "Champions" then
		headline = rich("CHAMPIONS of the top flight!", C.accent, true)
	else
		headline = ("Staying in the %s."):format(data.nextDivision)
	end
	seasonCard.body.Text = table.concat({
		("Finished <b>%s</b> in the %s."):format(ordinal(data.position), data.division),
		headline,
		"",
		("Prize money: %s"):format(rich(money(data.prize), C.cash, true)),
		"Every player is a year older. New fixtures are ready.",
	}, "\n")
	seasonCard.frame.Visible = true
end
summaryContinue.Activated:Connect(function()
	summary.frame.Visible = false
	refreshPlayButton()
	if pendingSeason then
		local data = pendingSeason
		pendingSeason = nil
		showSeason(data)
	else
		Sky.fastForward("match") -- a week passes
	end
end)

-- Welcome back (returning owner, once per visit)
local welcome = Theme.card(gui, "Welcome", "WELCOME BACK", UDim2.fromOffset(480, 320), UDim2.fromScale(0.5, 0.45))
local welcomeGo = welcome.addButton("Let's go", "primary")
welcomeGo.Activated:Connect(function()
	welcome.frame.Visible = false
end)
local welcomeDecided = false
local function maybeWelcome()
	if welcomeDecided or get("Phase") ~= "Manage" then
		return
	end
	welcomeDecided = true
	-- the naming card is the greeting when the club still needs a name; never stack both
	if (get("MatchesPlayed") or 0) == 0 or get("OwnerUserId") ~= player.UserId or get("NeedsName") == true then
		return
	end
	local round, rounds = get("Round") or 0, get("Rounds") or 10
	local nextOpp = get("NextOpponent") or ""
	welcome.body.Text = table.concat({
		rich(get("ClubName") or "Your club", C.accent, true),
		("%s  ·  Season %d"):format(get("DivisionName") or "", get("Season") or 1),
		if round > 0 then ("Currently %s after %d of %d matches."):format(ordinal(get("Position") or 1), round, rounds) else "A new season is about to start.",
		if nextOpp ~= "" then ("Next up: <b>%s</b>"):format(nextOpp) else "",
		"",
		("Record: %d played, %d won, %d drawn, %d lost"):format(get("MatchesPlayed") or 0, get("Wins") or 0, get("Draws") or 0, get("Losses") or 0),
		("Club cash: %s"):format(rich(money(get("Cash") or 0), C.cash, true)),
	}, "\n")
	welcome.frame.Visible = true
end

-- Loading cover: the club is being fetched for the owner; nothing else is real yet
local loadingCover = Instance.new("Frame")
loadingCover.Name = "Loading"
loadingCover.Size = UDim2.fromScale(1, 1)
loadingCover.BackgroundColor3 = C.bg
loadingCover.BorderSizePixel = 0
loadingCover.ZIndex = 20
loadingCover.Visible = false
loadingCover.Parent = gui
Theme.text(loadingCover, "FOOTBALL CLUB TYCOON", "display", {
	Size = UDim2.new(0.8, 0, 0, 44),
	Position = UDim2.fromScale(0.5, 0.44),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TextSize = 34,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
})
Theme.text(loadingCover, "Loading your club…", "muted", {
	Name = "Text",
	Size = UDim2.new(0.8, 0, 0, 30),
	Position = UDim2.fromScale(0.5, 0.52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
})

-- ----------------------------------------------------------- bottom-centre

local hintLabel = Theme.pill(gui, "Hint", {
	Size = UDim2.new(0.6, 0, 0, 36),
	Position = UDim2.new(0.5, 0, 1, -28),
	AnchorPoint = Vector2.new(0.5, 1),
	TextColor3 = C.accent,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextScaled = true,
})
local hintSize = Instance.new("UITextSizeConstraint")
hintSize.MaxTextSize = 17
hintSize.Parent = hintLabel
local hintWidth = Instance.new("UISizeConstraint")
hintWidth.MaxSize = Vector2.new(760, 36)
hintWidth.Parent = hintLabel

local toastLabel = Theme.pill(gui, "Toast", {
	Size = UDim2.new(0.6, 0, 0, 36),
	Position = UDim2.new(0.5, 0, 1, -72),
	AnchorPoint = Vector2.new(0.5, 1),
	TextColor3 = C.bad,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextScaled = true,
	Visible = false,
})
local toastSize = Instance.new("UITextSizeConstraint")
toastSize.MaxTextSize = 17
toastSize.Parent = toastLabel
local toastWidth = Instance.new("UISizeConstraint")
toastWidth.MaxSize = Vector2.new(760, 36)
toastWidth.Parent = toastLabel
local toastToken = 0
local function showToast(message: string, color: Color3?)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = message
	toastLabel.TextColor3 = color or C.bad
	toastLabel.Visible = true
	task.delay(2.5, function()
		if toastToken == myToken then
			toastLabel.Visible = false
		end
	end)
end
toastEvent.OnClientEvent:Connect(function(message: string, ok: boolean?)
	showToast(message, if ok then C.good else nil)
end)

-- ---------------------------------------------------------------- refreshes

local refreshHintText: () -> ()

local function refreshHint()
	refreshHintText()
	-- the summary and season cards own the bottom of the screen (their buttons sit there)
	hintLabel.Visible = hintLabel.Text ~= "" and not summary.frame.Visible and not seasonCard.frame.Visible
end

function refreshHintText()
	local phase = get("Phase")
	if phase == "Loading" then
		hintLabel.Text = ""
		return
	elseif get("NeedsName") == true then
		hintLabel.Text = "Give your club a name to get started."
		return
	elseif phase == "PreMatch" then
		hintLabel.Text = "Matchday! The teams are walking out."
		return
	elseif phase == "Match" then
		hintLabel.Text = "Match on. Walk around and watch, or use ATTACK / DEFEND / SUB."
		return
	end
	-- Onboarding only: the pill teaches the first few upgrades, then goes away.
	-- Starting a match is the PLAY MATCH button at the top, so it is never hinted here.
	local played = get("MatchesPlayed") or 0
	local level = get("StandLevel") or 1
	if played == 0 then
		hintLabel.Text = "Welcome to your club. Have a look around, then hit PLAY MATCH at the top."
	elseif level == 1 then
		-- X193: only say fans were turned away when they were
		hintLabel.Text = if (get("Demand") or 0) > (get("Capacity") or math.huge)
			then "Fans were turned away. Expand the East Stand (yellow sign in front of it)."
			else "Grow your ground: expand the East Stand (yellow sign in front of it)."
	elseif (get("ScoutLevel") or 0) == 0 then
		hintLabel.Text = "Hire a scout to find new players: the office computer, or the CLUB OFFICE button."
	elseif (get("AmenityLevel") or 0) == 0 then
		hintLabel.Text = "Fans spend money too: build a Snack Bar at the CONCOURSE sign on the forecourt."
	else
		hintLabel.Text = ""
	end
end

local function refreshCash()
	cashLabel.Text = money(get("Cash") or 0)
end

-- X186: nil until the first scoreboard refresh of a match, so joining mid-match
-- doesn't flash HALF TIME for a half that already started
local lastMinute: number? = nil
local function refreshScoreboard()
	local inMatch = get("Phase") == "Match"
	scoreboard.Visible = inMatch
	if not inMatch then
		lastMinute = nil
		return
	end
	local homeName, awayName = get("ClubName") or "Home", get("Opponent") or "Away"
	Crest.update(homeCrest, homeName, true)
	Crest.update(awayCrest, awayName)
	scoreLabel.Text = ("%s   %d - %d   %s"):format(homeName, get("HomeGoals") or 0, get("AwayGoals") or 0, awayName)
	local total = get("TimeLeft") or 0
	-- show a football minute rather than raw seconds; the real clock is hidden
	local elapsedFrac = 1 - (total / math.max(get("MatchDuration") or 90, 1))
	local minute = math.clamp(math.floor(elapsedFrac * 90), 0, 90)
	clockLabel.Text = ("%d'   ·   %s"):format(minute, if minute < 45 then "First half" else "Second half")
	if minute >= 45 and lastMinute ~= nil and (lastMinute :: number) < 45 then
		flash("HALF TIME", C.text, 2)
	end
	lastMinute = minute
end

local function refreshLoading()
	local loading = get("Phase") == "Loading"
	loadingCover.Visible = loading
	cashLabel.Visible = not loading
	seasonLabel.Visible = not loading
	musicButton.Visible = not loading
	goHomeButton.Visible = not loading
	if not loading then
		maybeWelcome()
	end
end

local function refreshPhasePanels()
	local phase = get("Phase")
	banner.Visible = phase == "PreMatch"
	tactics.Visible = phase == "Match"
	if phase == "PreMatch" then
		summary.frame.Visible = false -- a lingering card must never cover the next match
		seasonCard.frame.Visible = false
		welcome.frame.Visible = false
		bannerBody.Text = if get("Friendly") == true
			then ("%s  vs  %s   ·   Friendly"):format(get("ClubName") or "Home", get("Opponent") or "Away")
			else ("%s  vs  %s   ·   Match %d of %d"):format(get("ClubName") or "Home", get("Opponent") or "Away", (get("Round") or 0) + 1, get("Rounds") or 10)
	end
end

state:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
for _, key in { "Phase", "HomeGoals", "AwayGoals", "TimeLeft", "Opponent" } do
	state:GetAttributeChangedSignal(key):Connect(refreshScoreboard)
end
for _, key in { "Phase", "MatchesPlayed", "StandLevel", "ScoutLevel", "AmenityLevel", "Round", "NeedsName", "Demand", "Capacity" } do
	state:GetAttributeChangedSignal(key):Connect(refreshHint)
end
for _, key in { "Phase", "OwnerUserId", "NeedsName", "NextOpponent", "Round", "Rounds", "MatchesPlayed" } do
	state:GetAttributeChangedSignal(key):Connect(refreshPlayButton)
end
state:GetAttributeChangedSignal("Phase"):Connect(refreshLoading)

local lastPhase = get("Phase")
state:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = get("Phase")
	if lastPhase == "Match" and phase == "Manage" then
		flash("FULL TIME", C.text, 3)
	elseif phase == "Match" and lastPhase == "PreMatch" then
		-- X186: a real kick-off, not joining or reconnecting mid-match
		lastMinute = 0
		flash("KICK-OFF", C.text, 1.5)
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
		flash("GOAL!", C.accent, 2.5)
	else
		flash(("%s score"):format(get("Opponent") or "They"), C.bad, 2.5)
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
		showToast(("SUB: %d %s on, %d %s off"):format(inP.number, inP.name, outP.number, outP.name), C.info)
	end
end)

summaryEvent.OnClientEvent:Connect(function(data)
	summary.show(data)
	playButton.Visible = false -- the card owns the screen until Back to Club
	pendingSeason = data.season
end)

summary.frame:GetPropertyChangedSignal("Visible"):Connect(refreshHint)
seasonCard.frame:GetPropertyChangedSignal("Visible"):Connect(refreshHint)

refreshCash()
refreshScoreboard()
refreshHint()
refreshPlayButton()
refreshLoading()
refreshPhasePanels()
refreshTacticButtons()
