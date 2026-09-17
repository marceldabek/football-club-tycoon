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
	station = { id = "rbxassetid://9114300983", volume = 0.25, target = 0 }, -- X173: Elevated New York City Subway 1 (exterior platform, P.A., brakes)
	crowd = { id = Config.Sounds.crowdAmbient, volume = 0.22, target = 0 }, -- the stadium crowd, low-passed below
}

local TOWN_RADIUS = 520 -- full town bed inside this distance of the square
local TOWN_FADE = 380
local RIVER_NEAR = 60 -- beyond the river's half width
local RIVER_FADE = 180
local INDUSTRY_FADE = 160
local STATION_NEAR = 40 -- beyond the station building's footprint
local STATION_FADE = 160
local INDOOR_GAIN = 0.3 -- X175: outdoor beds inside the office and dressing rooms

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

-- X173: the station's footprint as a box
local stationBox: { number }
do
	local st = TownLayout.RAIL.station
	stationBox = { st.centre.X - st.size.X / 2, st.centre.X + st.size.X / 2, st.centre.Z - st.size.Z / 2, st.centre.Z + st.size.Z / 2 }
end

-- X175: the camera is inside a club's office or dressing rooms (their models'
-- oriented bounding boxes, refreshed every few seconds as plots come and go)
type RoomBox = { cf: CFrame, half: Vector3 }
local rooms: { RoomBox } = {}
local roomsAge = math.huge
local roomModels: { [Model]: boolean } = {}
task.spawn(function()
	local plots = workspace:WaitForChild("Plots", math.huge)
	local function consider(d: Instance)
		if d:IsA("Model") and (d.Name == "Office" or d.Name == "DressingRooms") then
			roomModels[d] = true
		end
	end
	for _, d in plots:GetDescendants() do
		consider(d)
	end
	plots.DescendantAdded:Connect(consider)
end)
local function refreshRooms()
	table.clear(rooms)
	for model in roomModels do
		if model.Parent then
			local cf, size = model:GetBoundingBox()
			table.insert(rooms, { cf = cf, half = size / 2 })
		else
			roomModels[model] = nil
		end
	end
end
local function indoors(p: Vector3): boolean
	for _, room in rooms do
		local q = room.cf:PointToObjectSpace(p)
		if math.abs(q.X) < room.half.X and math.abs(q.Y) < room.half.Y and math.abs(q.Z) < room.half.Z then
			return true
		end
	end
	return false
end

local function retarget()
	local p = workspace.CurrentCamera.CFrame.Position
	roomsAge += 0.25
	if roomsAge > 4 then
		roomsAge = 0
		refreshRooms()
	end
	local square = TownLayout.SQUARE.centre
	local town = falloff((Vector3.new(p.X, 0, p.Z) - square).Magnitude, TOWN_RADIUS, TOWN_FADE)
	local river = falloff(TownLayout.distanceToPolyline(p, TownLayout.RIVER.points), TownLayout.RIVER.width / 2 + RIVER_NEAR, RIVER_FADE)
	local industry = if industrialBox then falloff(boxDistance(p, industrialBox), 0, INDUSTRY_FADE) else 0
	local station = falloff(boxDistance(p, stationBox), STATION_NEAR, STATION_FADE)
	-- birds fill whatever the busier beds leave, never silent outdoors
	local birds = math.clamp(1 - math.max(town * 0.7, industry, station * 0.7), 0.25, 1)
	-- high above town (the picker camera) everything is quieter, and indoors
	-- the outdoor beds are muffled
	local height = math.clamp(1 - (p.Y - 60) / 300, 0.3, 1) * (if indoors(p) then INDOOR_GAIN else 1)
	BEDS.station.target = station * height
	BEDS.town.target = town * height
	BEDS.river.target = river * height
	BEDS.industry.target = industry * height
	BEDS.birds.target = birds * height
	BEDS.crowd.target = TownLifeMath.distantCrowdWeight(nearestLiveGround(p)) * height
end

-- X87: the church bell tolls from the spire every BELL_EVERY seconds (TEMP:
-- normal play holds one afternoon, so there is no real hour to ring). A 3D
-- sound on an invisible client-only part, fading out across town.
local BELL_ID = "rbxassetid://9113804436" -- Church Bell Tolling 1 (Pro Sound Effects)
local BELL_EVERY = 300
local BELL_FIRST = 45
do
	local spire = Vector3.new(0, 0, 0)
	local height = 100
	for _, landmark in TownLayout.LANDMARKS do
		if landmark.name == "Church Spire" then
			spire = landmark.position
			height = landmark.height * 0.8
		end
	end
	local emitter = Instance.new("Part")
	emitter.Name = "ChurchBell"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.one
	emitter.Position = spire + Vector3.new(0, height, 0)
	emitter.Parent = workspace
	local bell = Instance.new("Sound")
	bell.SoundId = BELL_ID
	bell.Volume = 0.9
	bell.RollOffMode = Enum.RollOffMode.InverseTapered
	bell.RollOffMinDistance = 120
	bell.RollOffMaxDistance = 1400
	bell.Parent = emitter
	task.delay(BELL_FIRST, function()
		while emitter.Parent do
			bell:Play()
			task.wait(BELL_EVERY)
		end
	end)
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
