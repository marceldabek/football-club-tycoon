--!strict
-- Drives the matchday presentation from the replicated club state:
--   PreMatch -> iris close, walkout under a scripted camera, iris open
--   Match    -> presenter plays the timeline synced to KickoffAt
--   Manage   -> presenter winds down
-- Late joiners get a presenter built straight into the current phase.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Iris = require(script.Parent.Iris)
local Presenter = require(script.Parent.MatchPresenter)
local MatchAudio = require(script.Parent.MatchAudio)

local state = ReplicatedStorage:WaitForChild("ClubState")
local camera = workspace.CurrentCamera

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
	-- start low beside the tunnel looking down the line of players, rise to a
	-- stand-side view of the centre circle as they take their positions
	local from = CFrame.lookAt(Vector3.new(-70, 9, 30), Vector3.new(-100, 4, -2))
	local to = CFrame.lookAt(Vector3.new(70, 34, 70), Vector3.new(0, 3, 0))
	local t0 = os.clock()
	while os.clock() - t0 < seconds and get("Phase") == "PreMatch" do
		camera.CFrame = from:Lerp(to, (os.clock() - t0) / seconds)
		RunService.RenderStepped:Wait()
	end
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
	MatchAudio.startCrowd((get("Attendance") or 0) / math.max(get("Capacity") or 1, 1))
end

local function endMatch()
	if presenter then
		MatchAudio.whistle()
		presenter:finish()
		presenter = nil
	end
	MatchAudio.stopCrowd()
end

local function onPhase()
	local phase = get("Phase")
	if phase == "PreMatch" then
		beginPreMatch()
	elseif phase == "Match" then
		beginMatch()
	else
		endMatch()
	end
end

state:GetAttributeChangedSignal("Phase"):Connect(onPhase)
state:GetAttributeChangedSignal("Tactic"):Connect(function()
	if presenter then
		presenter:setTactic(get("Tactic") or "Balanced")
	end
end)
state:GetAttributeChangedSignal("Subs"):Connect(function()
	if presenter then
		presenter:applySubs(HttpService:JSONDecode(get("Subs") or "[]"))
	end
end)

onPhase()
