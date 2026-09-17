--!strict
-- Client-side time of day (CLAUDE.md s27: every player has their own sky).
-- The server creates the Lighting effect instances once; each client then
-- writes its own look into them, so two players can be at different points
-- in their day on the same server.
--   hero afternoon while managing
--   evening fixtures: tween to the floodlit look for the match
--   after a match / season: a skippable fast-forward back to the afternoon
-- Looks and tracks are data in Shared.DayCycle.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DayCycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DayCycle"))

local Sky = {}

local current: DayCycle.Look = DayCycle.LOOKS.HeroAfternoon
local playing = 0 -- bumped by every transition so an older one stops writing

local function effect(name: string, className: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	-- the server normally makes these; a local copy keeps the client working
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

-- Floodlight heads light up with the look (local only; the server switches
-- them for everyone on an evening matchday). The server tags every head
-- (Scenery.FLOOD_HEAD_TAG); heads streaming in later pick up the current state.
local FLOOD_HEAD_TAG = "FloodHead"
local floodsShown: boolean? = nil

local function paintHead(d: Instance, on: boolean)
	if d:IsA("BasePart") then
		d.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		d.Color = if on then Color3.fromRGB(255, 250, 225) else Color3.fromRGB(150, 145, 125)
	end
end

-- X237: a ground whose club is playing an evening match right now. The server
-- lit those heads for everyone; turning them off locally hides a live match.
local function inLiveEveningMatch(d: Instance): boolean
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return false
	end
	local plot: Instance? = d
	while plot and plot.Parent ~= plots do
		plot = plot.Parent
	end
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local state = plot and clubs and clubs:FindFirstChild(plot.Name)
	if not state then
		return false
	end
	local phase = state:GetAttribute("Phase")
	return state:GetAttribute("Evening") == true and (phase == "PreMatch" or phase == "Match")
end

local function setFloodHeads(on: boolean)
	for _, d in CollectionService:GetTagged(FLOOD_HEAD_TAG) do
		if on or not inLiveEveningMatch(d) then
			paintHead(d, on)
		end
	end
end

-- only light late arrivals: an unlit look must not switch off another
-- club's evening floodlights that the server has turned on for everyone
CollectionService:GetInstanceAddedSignal(FLOOD_HEAD_TAG):Connect(function(d: Instance)
	if floodsShown == true then
		paintHead(d, true)
	end
end)
-- X248: the one source of "is it dark for this player". Five scripts used to
-- each re-test Lighting.ClockTime on their own 1-2 s poll, but a fast-forward
-- sweeps the clock through the night in about 2.5 s, so lamps, lit windows,
-- headlights and train windows switched late or missed the night entirely.
local DARK_ATTRIBUTE = "SkyDark"
Sky.DARK_ATTRIBUTE = DARK_ATTRIBUTE

local function apply(look: DayCycle.Look)
	current = look
	local me = game:GetService("Players").LocalPlayer
	if me:GetAttribute(DARK_ATTRIBUTE) ~= look.streetLights then
		me:SetAttribute(DARK_ATTRIBUTE, look.streetLights)
	end
	Lighting.ClockTime = look.clock
	Lighting.Brightness = look.brightness
	Lighting.ExposureCompensation = look.exposure
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoorAmbient

	local atmosphere = effect("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = look.atmosphereDensity
	atmosphere.Offset = look.atmosphereOffset
	atmosphere.Color = look.atmosphereColor
	atmosphere.Decay = look.atmosphereDecay
	atmosphere.Glare = look.atmosphereGlare
	atmosphere.Haze = look.atmosphereHaze

	local bloom = effect("Bloom", "BloomEffect") :: BloomEffect
	bloom.Intensity = look.bloomIntensity
	local rays = effect("SunRays", "SunRaysEffect") :: SunRaysEffect
	rays.Intensity = look.sunRays
	local grade = effect("Grade", "ColorCorrectionEffect") :: ColorCorrectionEffect
	grade.Brightness = look.gradeBrightness
	grade.Contrast = look.gradeContrast
	grade.Saturation = look.gradeSaturation
	grade.TintColor = look.gradeTint

	if floodsShown ~= look.floodlights then
		floodsShown = look.floodlights
		setFloodHeads(look.floodlights)
	end
end

-- Runs `sampleAt(t)` into `apply` every frame for `duration` seconds. Any
-- click, tap or key skips to the end when `skippable`. Returns when finished
-- or when a newer transition takes over.
local function play(duration: number, sampleAt: (number) -> DayCycle.Look, skippable: boolean)
	playing += 1
	local mine = playing
	local skipped = false
	local conn: RBXScriptConnection? = nil
	if skippable then
		conn = UserInputService.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or t == Enum.UserInputType.Keyboard then
				skipped = true
			end
		end)
	end
	local t0 = os.clock()
	while playing == mine do
		local t = os.clock() - t0
		if skipped or t >= duration then
			apply(sampleAt(duration))
			break
		end
		apply(sampleAt(t))
		RunService.RenderStepped:Wait()
	end
	if conn then
		conn:Disconnect()
	end
end

local function tweenTo(lookName: string, seconds: number)
	local from, to = current, DayCycle.LOOKS[lookName]
	task.spawn(play, seconds, function(t: number): DayCycle.Look
		local k = math.clamp(t / seconds, 0, 1)
		return DayCycle.lerpLook(from, to, k * k * (3 - 2 * k))
	end, false)
end

function Sky.start()
	apply(DayCycle.LOOKS.HeroAfternoon)
end

-- Matchday: evening fixtures go floodlit, afternoon ones keep the hero look.
function Sky.setMatchday(on: boolean, evening: boolean)
	if on and evening then
		tweenTo("EveningMatch", 6)
	elseif on then
		tweenTo("HeroAfternoon", 2)
	end
end

-- "match" ~4 s after the summary, "season" ~10 s after the season card.
function Sky.fastForward(kind: "match" | "season")
	local track = DayCycle.fastForward(kind, current.floodlights)
	task.spawn(play, track.duration, function(t: number): DayCycle.Look
		return DayCycle.sample(track, t)
	end, true)
end

function Sky.look(): DayCycle.Look
	return current
end

return Sky
