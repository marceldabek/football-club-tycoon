--!strict
-- Drives the matchday presentation from the replicated club state:
--   PreMatch -> fade to black, walkout under a scripted camera, fade back in
--   Match    -> presenter plays the timeline synced to KickoffAt
--   Manage   -> presenter winds down
-- Late joiners get a presenter built straight into the current phase.
-- Spectators (I2.1): near another ground whose match is live, the same
-- presenter follows that club instead, without a fade, camera or sky changes.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Fade = require(script.Parent.Fade)
local Presenter = require(script.Parent.MatchPresenter)
local MatchAudio = require(script.Parent.MatchAudio)
local Sky = require(script.Parent.Sky)
local ClubRef = require(script.Parent.ClubRef)
local Focus = require(script.Parent.Focus)
local Theme = require(script.Parent.Theme)
local PlayerCard = require(script.Parent.PlayerCard)

local PlotVisit = require(ReplicatedStorage.Shared.PlotVisit)

local Players = game:GetService("Players")

local own = ClubRef.waitState()
local state = own -- the club being presented: own, or the one being watched
local camera = workspace.CurrentCamera

local SPECTATE_RADIUS = 220 -- TEMP: studs from a pitch centre that count as "in its stands"

local presenter: Presenter.Presenter? = nil

local function get(key: string): any
	return state:GetAttribute(key)
end

local function loadTimeline(): Presenter.Timeline?
	local raw = get("Timeline")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	return HttpService:JSONDecode(raw)
end

-- Slow pan from the stand while the teams walk out. Ends early at kickoff.
local function cameraWalkout(seconds: number)
	camera.CameraType = Enum.CameraType.Scriptable
	-- intro close-up: keep the walkout sharp, soften the far stands
	Focus.push("walkout", { focusDistance = 45, inFocusRadius = 35, farIntensity = 0.3, nearIntensity = 0 })
	-- start low beside the tunnel looking down the line of players, rise to a
	-- stand-side view of the centre circle as they take their positions
	local plot = ClubRef.frame()
	local from = plot * CFrame.lookAt(Vector3.new(-70, 9, 30), Vector3.new(-100, 4, -2))
	local to = plot * CFrame.lookAt(Vector3.new(70, 34, 70), Vector3.new(0, 3, 0))
	local t0 = os.clock()
	while os.clock() - t0 < seconds and get("Phase") == "PreMatch" do
		camera.CFrame = from:Lerp(to, (os.clock() - t0) / seconds)
		RunService.RenderStepped:Wait()
	end
	Focus.pop("walkout")
	camera.CameraType = Enum.CameraType.Custom
end

-- Card size for `count` cards abreast: whichever of the strip's width and
-- height runs out first (PackOpening.slotSize solves the same problem for
-- the pack reveal row). A UIAspectRatioConstraint inside a UIListLayout does
-- not reliably keep 2:3 here, so the slot is sized in pixels up front.
local MEET_STRIP_W = 0.96
local MEET_STRIP_H = 0.26
local MEET_PAD = 4
local function meetSlotSize(count: number): UDim2
	local vp = camera.ViewportSize
	local room = (vp.X * MEET_STRIP_W - MEET_PAD * (count - 1)) / math.max(count, 1)
	local height = math.min(vp.Y * MEET_STRIP_H, room / Config.CardAspect)
	return UDim2.fromOffset(math.floor(height * Config.CardAspect), math.floor(height))
end

-- The very first walkout introduces the eleven as cards (the squad is never
-- "unpacked": the player meets them here, then opens their first pack after
-- the whistle). Presentation only, gone before kick-off.
-- Reads `own` directly, not the mutable `state`/`get()`: `state` can be
-- reassigned to a spectated club mid-walkout (repick() polls every second),
-- and this must only ever act on the owner's own match.
local function meetTheEleven(seconds: number)
	if ((own:GetAttribute("MatchesPlayed") :: number?) or 0) > 0 then
		return
	end
	local ok, club = pcall(function()
		return HttpService:JSONDecode(own:GetAttribute("Club") :: string)
	end)
	if not ok or type(club) ~= "table" or type(club.players) ~= "table" or type(club.lineup) ~= "table" then
		return
	end
	local byId = {}
	for _, p in club.players do
		byId[p.id] = p
	end
	-- a sparse XI decodes as a JSON object, not an array (X317): walk the
	-- fixed slot count in order rather than iterating the table directly
	local slots = club.lineup.xi :: any
	local starters = {}
	for slotIndex = 1, #Pitch.ROLES do
		local id = slots[slotIndex] or slots[tostring(slotIndex)]
		local p = if id then byId[id] else nil
		if p then
			table.insert(starters, p)
		end
	end
	if #starters == 0 then
		return
	end
	local clubName = own:GetAttribute("ClubName") :: string?

	local screen = Theme.screenGui("MeetTheEleven", 20)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.fromScale(0.5, 0.97)
	strip.Size = UDim2.fromScale(MEET_STRIP_W, MEET_STRIP_H)
	strip.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, MEET_PAD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip

	local size = meetSlotSize(#starters)
	local cards: { PlayerCard.Card } = {}
	local cleaned = false
	for i, p in starters do
		if cleaned then
			break -- the walkout ended while the strip was still being built
		end
		local holder = Instance.new("Frame")
		holder.Name = "Slot"
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = i
		holder.Size = size
		holder.Parent = strip
		-- compact: eleven cards across a phone leave the six stat rows a couple of
		-- pixels tall, so the strip shows art, bust, overall, role and the name
		local card = PlayerCard.new(holder, p, { signed = true, clubName = clubName, faceDown = true, compact = true })
		table.insert(cards, card)
		task.delay(0.4 + i * 0.18, function()
			if card.frame.Parent then
				card:flip()
			end
		end)
		-- one card a frame: eleven ViewportFrame busts built in a single frame is
		-- a visible hitch on a mid-range phone, right as the walkout starts
		task.wait()
	end

	local phaseConn: RBXScriptConnection? = nil
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		if phaseConn then
			phaseConn:Disconnect()
		end
		for _, card in cards do
			card:destroy() -- a wonderkid's shine tween outlives a plain Destroy
		end
		screen:Destroy()
	end
	-- a cut-short walkout (phase moves on before the timer below fires, or
	-- the match is abandoned) still has to clear the strip and its tweens
	phaseConn = own:GetAttributeChangedSignal("Phase"):Connect(function()
		if own:GetAttribute("Phase") ~= "PreMatch" then
			cleanup()
		end
	end)
	task.delay(seconds, cleanup)
end

local function beginPreMatch()
	if presenter then
		presenter:destroy()
		presenter = nil
	end
	local timeline = loadTimeline()
	if not timeline then
		return
	end
	local p = Presenter.new(timeline, get("MatchDuration") or Config.MatchDurationSeconds)
	presenter = p

	Fade.close(0.6)
	local walkout = Config.WalkoutSeconds - 1.4
	task.spawn(cameraWalkout, walkout)
	task.spawn(meetTheEleven, walkout)
	task.spawn(function()
		task.wait(0.25)
		Fade.open(0.8)
	end)
	p:walkout(walkout)
end

local function beginMatch()
	local p = presenter
	if not p then
		local timeline = loadTimeline()
		if not timeline then
			return
		end
		p = Presenter.new(timeline, get("MatchDuration") or Config.MatchDurationSeconds)
		presenter = p
	end
	p:setTactic(get("Tactic") or "Balanced")
	p:applySubs(HttpService:JSONDecode(get("Subs") or "[]"))
	p:start(get("KickoffAt") or workspace:GetServerTimeNow())
	MatchAudio.whistle()
	MatchAudio.duckMusic(true)
	MatchAudio.startCrowd((get("Attendance") or 0) / math.max(get("Capacity") or 1, 1))
end

local function endMatch()
	if presenter then
		MatchAudio.whistle()
		presenter:finish()
		presenter = nil
	end
	MatchAudio.stopCrowd()
	MatchAudio.duckMusic(false)
end

local function onPhase()
	local phase = get("Phase")
	if state ~= own then
		-- watching someone else: no fade, walkout camera or sky change
		if phase == "Match" then
			beginMatch()
		else
			endMatch()
		end
		return
	end
	if phase == "PreMatch" then
		Sky.setMatchday(true, get("Evening") == true)
		beginPreMatch()
	elseif phase == "Match" then
		-- X187: joining your own evening fixture mid-match still needs its sky
		Sky.setMatchday(true, get("Evening") == true)
		beginMatch()
	else
		endMatch()
	end
end

local stateConnections: { RBXScriptConnection } = {}

local function follow(folder: Folder)
	for _, c in stateConnections do
		c:Disconnect()
	end
	stateConnections = {}
	state = folder
	ClubRef.setPresented(if folder == own then nil else folder)
	-- local-only attribute for the spectator score pill (SpectatorPill)
	Players.LocalPlayer:SetAttribute("WatchingPlot", if folder == own then nil else folder:GetAttribute("PlotIndex"))
	table.insert(stateConnections, folder:GetAttributeChangedSignal("Phase"):Connect(onPhase))
	table.insert(stateConnections, folder:GetAttributeChangedSignal("Tactic"):Connect(function()
		if presenter then
			presenter:setTactic(get("Tactic") or "Balanced")
		end
	end))
	-- X271: a change of tactic replays the rest of the match, so the timeline
	-- can change while it is being shown
	table.insert(stateConnections, folder:GetAttributeChangedSignal("Timeline"):Connect(function()
		local timeline = if presenter and get("Phase") == "Match" then loadTimeline() else nil
		if presenter and timeline then
			presenter:setEvents(timeline.events)
		end
	end))
	table.insert(stateConnections, folder:GetAttributeChangedSignal("Subs"):Connect(function()
		if presenter then
			presenter:applySubs(HttpService:JSONDecode(get("Subs") or "[]"))
		end
	end))
	onPhase()
end

-- Own matchday always wins; otherwise watch the nearest live match in range.
local function pickFolder(): Folder
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not clubs or not root then
		return own
	end
	local grounds: { PlotVisit.Ground } = {}
	local byPlot: { [number]: Folder } = {}
	for _, folder in clubs:GetChildren() do
		local plot = folder:GetAttribute("PlotIndex")
		local cf = folder:GetAttribute("PlotCFrame")
		if folder ~= own and folder:IsA("Folder") and type(plot) == "number" and typeof(cf) == "CFrame" then
			byPlot[plot] = folder
			table.insert(grounds, { plot = plot, phase = folder:GetAttribute("Phase"), position = cf.Position })
		end
	end
	local target = PlotVisit.spectateTarget(own:GetAttribute("Phase"), grounds, root.Position, SPECTATE_RADIUS)
	return if target then byPlot[target] else own
end

local function repick()
	local folder = pickFolder()
	if folder ~= state then
		if presenter then
			presenter:destroy() -- switching grounds: drop the old match without a whistle
			presenter = nil
		end
		MatchAudio.stopCrowd()
		MatchAudio.duckMusic(false)
		follow(folder)
	end
end

own:GetAttributeChangedSignal("Phase"):Connect(repick)

Sky.start()
MatchAudio.startMusic()
follow(own)
task.spawn(function()
	while true do
		task.wait(1)
		repick()
	end
end)
