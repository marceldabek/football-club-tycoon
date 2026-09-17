--!strict
-- Town ambience that follows the camera (backlog F1.1, Q28: Roblox's licensed
-- library first). Four looping beds crossfade by where you are:
--   town      busy street near the market square and High Street
--   birds     homes, the park and the edge of town (the default bed)
--   river     within earshot of the River Lune
--   industry  the industrial estate
--   crowd     a muffled crowd from any ground with a live match, heard across
--             town (G2.2); silent inside the ground, where MatchAudio plays
-- All clips are Pro Sound Effects (the Roblox licensed library). Weights are
-- recomputed four times a second; volumes glide towards them every frame.
-- Match audio (MatchAudio) plays on top and is not touched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

type Bed = { id: string, volume: number, sound: Sound?, target: number }

local BEDS: { [string]: Bed } = {
	town = { id = "rbxassetid://9112866852", volume = 0.22, target = 0 }, -- San Francisco 1: traffic, voices, wind
	birds = { id = "rbxassetid://9112831284", volume = 0.3, target = 0 }, -- Morning Birds 1
	river = { id = "rbxassetid://9118187543", volume = 0.35, target = 0 }, -- River Water 1
	industry = { id = "rbxassetid://9112796599", volume = 0.12, target = 0 }, -- Industrial Ambience 1
	crowd = { id = Config.Sounds.crowdAmbient, volume = 0.22, target = 0 }, -- the stadium crowd, low-passed below
}

local TOWN_RADIUS = 520 -- full town bed inside this distance of the square
local TOWN_FADE = 380
local RIVER_NEAR = 60 -- beyond the river's half width
local RIVER_FADE = 180
local INDUSTRY_FADE = 160

for _, bed in BEDS do
	local sound = Instance.new("Sound")
	sound.SoundId = bed.id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	bed.sound = sound
end
do
	-- distance: cut the highs so the far crowd reads as a roar, not a stand
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -30
	eq.MidGain = -8
	eq.LowGain = 2
	eq.Parent = BEDS.crowd.sound
end

-- the nearest ground whose match is live, as a distance (math.huge if none)
local function nearestLiveGround(p: Vector3): number
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local best = math.huge
	if clubs then
		for _, folder in clubs:GetChildren() do
			local cf = folder:GetAttribute("PlotCFrame")
			if folder:GetAttribute("Phase") == "Match" and typeof(cf) == "CFrame" then
				best = math.min(best, Vector3.new(cf.X - p.X, 0, cf.Z - p.Z).Magnitude)
			end
		end
	end
	return best
end

-- 1 inside `near`, fading to 0 over `fade` beyond it.
local function falloff(distance: number, near: number, fade: number): number
	return math.clamp(1 - (distance - near) / fade, 0, 1)
end

local industrialBox: { number }? = nil
for _, district in TownLayout.DISTRICTS do
	if district.kind == "industrial" then
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, block in district.blocks do
			minX = math.min(minX, block.centre.X - block.size.X / 2)
			maxX = math.max(maxX, block.centre.X + block.size.X / 2)
			minZ = math.min(minZ, block.centre.Z - block.size.Z / 2)
			maxZ = math.max(maxZ, block.centre.Z + block.size.Z / 2)
		end
		industrialBox = { minX, maxX, minZ, maxZ }
	end
end

local function boxDistance(p: Vector3, box: { number }): number
	local dx = math.max(box[1] - p.X, 0, p.X - box[2])
	local dz = math.max(box[3] - p.Z, 0, p.Z - box[4])
	return math.sqrt(dx * dx + dz * dz)
end

local function retarget()
	local p = workspace.CurrentCamera.CFrame.Position
	local square = TownLayout.SQUARE.centre
	local town = falloff((Vector3.new(p.X, 0, p.Z) - square).Magnitude, TOWN_RADIUS, TOWN_FADE)
	local river = falloff(TownLayout.distanceToPolyline(p, TownLayout.RIVER.points), TownLayout.RIVER.width / 2 + RIVER_NEAR, RIVER_FADE)
	local industry = if industrialBox then falloff(boxDistance(p, industrialBox), 0, INDUSTRY_FADE) else 0
	-- birds fill whatever the busier beds leave, never silent outdoors
	local birds = math.clamp(1 - math.max(town * 0.7, industry), 0.25, 1)
	-- high above town (the picker camera) everything is quieter
	local height = math.clamp(1 - (p.Y - 60) / 300, 0.3, 1)
	BEDS.town.target = town * height
	BEDS.river.target = river * height
	BEDS.industry.target = industry * height
	BEDS.birds.target = birds * height
	BEDS.crowd.target = TownLifeMath.distantCrowdWeight(nearestLiveGround(p)) * height
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= 0.25 then
		elapsed = 0
		retarget()
	end
	local k = math.clamp(dt * 1.5, 0, 1)
	for _, bed in BEDS do
		local sound = bed.sound
		if sound then
			local goal = bed.target * bed.volume
			sound.Volume += (goal - sound.Volume) * k
		end
	end
end)
