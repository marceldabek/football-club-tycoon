--!strict
-- Drives the matchday presentation from the replicated club state:
--   PreMatch -> iris close, walkout under a scripted camera, iris open
--   Match    -> presenter plays the timeline synced to KickoffAt
--   Manage   -> presenter winds down
-- Late joiners get a presenter built straight into the current phase.
-- Spectators (I2.1): near another ground whose match is live, the same
-- presenter follows that club instead, without iris, camera or sky changes.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Iris = require(script.Parent.Iris)
local Presenter = require(script.Parent.MatchPresenter)
local MatchAudio = require(script.Parent.MatchAudio)
local Sky = require(script.Parent.Sky)
local ClubRef = require(script.Parent.ClubRef)
local Focus = require(script.Parent.Focus)

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

	Iris.close(0.6)
	local walkout = Config.WalkoutSeconds - 1.4
	task.spawn(cameraWalkout, walkout)
	task.spawn(function()
		task.wait(0.25)
		Iris.open(0.8)
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
		-- watching someone else: no iris, walkout camera or sky change
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
