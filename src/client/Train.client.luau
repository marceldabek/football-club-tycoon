--!strict
-- The town train (backlog X82): one three-carriage unit running the whole
-- railway, over the Lune Viaduct, stopping at Rivermere Station and turning
-- back at either end of the line. Client-only parts moved with BulkMoveTo.
-- Geometry lives in Shared.TrainMath.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TownLayout = require(Shared:WaitForChild("TownLayout"))
local TrafficMath = require(Shared:WaitForChild("TrafficMath"))
local TrainMath = require(Shared:WaitForChild("TrainMath"))

local SPEED = 45 -- TEMP studs / s
local DWELL = 10 -- TEMP seconds at the station
local END_PAUSE = 4 -- seconds at each end of the line
local CARRIAGES = 3
local LENGTH = 30
local GAP = 1.5
local WIDTH = 7.4
local LATERAL = 4 -- centre of the left-hand track (rails at 2.05..5.95)
local BODY = Color3.fromRGB(236, 238, 242)
local STRIPE = Color3.fromRGB(24, 40, 78)
local WINDOWS = Color3.fromRGB(40, 52, 64)
local UNDER = Color3.fromRGB(40, 40, 44)

local points = TownLayout.RAIL.points
local bridges = TownLayout.BRIDGES
local lineLength = TrafficMath.polylineLength(points)
local trainLength = CARRIAGES * LENGTH + (CARRIAGES - 1) * GAP

-- where the middle of the train stops: the line's nearest point to the station
local stationDistance = 0
do
	local best, walked = math.huge, 0
	local c = TownLayout.RAIL.station.centre
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = ab.Magnitude
		local t = if len > 0 then math.clamp(Vector3.new(c.X - a.X, 0, c.Z - a.Z):Dot(ab) / (len * len), 0, 1) else 0
		local q = Vector3.new(a.X, 0, a.Z) + ab * t
		local d = Vector3.new(c.X - q.X, 0, c.Z - q.Z).Magnitude
		if d < best then
			best, stationDistance = d, walked + t * len
		end
		walked += len
	end
end

local folder = Instance.new("Folder")
folder.Name = "Train"
folder.Parent = workspace

local function newPart(name: string, size: Vector3, colour: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- per carriage: parts and their offsets from the rail-top centre frame
type Piece = { part: BasePart, offset: CFrame }
local carriages: { { Piece } } = {}

-- X394 (playtest #36): reuse one generated carriage mesh for all 3 carriages
-- if ClientKit published it. Its length already runs along its Z with a cab
-- at both ends, so it takes the frame as it is (TrainMath.carriageFrames:
-- -Z forward); the first cut turned it 90 degrees, running every carriage
-- sideways down the line. The old 4-piece primitive stays as the fallback.
-- Night glow (X158): the mesh's windows are baked into its texture, so a thin
-- band over them is shown only after dark. KIT_WINDOWS_Y/H were measured off
-- the mesh side-on with marker bars (window glass 3.45..5.1 above the rails).
local KIT_WINDOWS_Y, KIT_WINDOWS_H, KIT_WINDOWS_LENGTH = 4.3, 1.4, LENGTH - 6
-- The server publishes ClientKit after the town build, which can be well after
-- this script starts (the first cut waited 5 s and then kept the primitive for
-- the whole session): build with what is there now, rebuild when it lands.
local clientKit: Instance? = ReplicatedStorage:FindFirstChild("ClientKit")
local function kitCarriageMesh(): BasePart?
	local template = clientKit and clientKit:FindFirstChild("TrainCarriage")
	return template and template:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
end

-- X172: a rolling rumble on the middle carriage while the train moves (Pro
-- Sound Effects, licensed library: "L Pass Bys 1"), faded out while it waits.
-- By name, not index: the kit-mesh carriage (X394) has only one piece.
local function pieceNamed(pieces: { Piece }, name: string): BasePart
	for _, piece in pieces do
		if piece.part.Name == name then
			return piece.part
		end
	end
	return pieces[1].part
end
local rumble = Instance.new("Sound")
rumble.Name = "TrainRumble"
rumble.SoundId = "rbxassetid://9116330273"
rumble.Looped = true
rumble.Volume = 0
rumble.RollOffMode = Enum.RollOffMode.InverseTapered
rumble.RollOffMinDistance = 40
rumble.RollOffMaxDistance = 400

local function buildCarriages(carriageMesh: BasePart?)
	rumble.Parent = nil
	for _, pieces in carriages do
		for _, piece in pieces do
			piece.part:Destroy()
		end
	end
	table.clear(carriages)
	for _ = 1, CARRIAGES do
		local pieces: { Piece } = {}
		local function add(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material)
			table.insert(pieces, { part = newPart(name, size, colour, material), offset = offset })
		end
		if carriageMesh then
			local mesh = carriageMesh:Clone()
			mesh.Name = "Body"
			mesh.Parent = folder
			table.insert(pieces, { part = mesh, offset = CFrame.new(0, mesh.Size.Y / 2, 0) })
			add("Windows", Vector3.new(mesh.Size.X + 0.1, KIT_WINDOWS_H, KIT_WINDOWS_LENGTH), CFrame.new(0, KIT_WINDOWS_Y, 0), WINDOWS, Enum.Material.Glass)
			local band = pieces[#pieces].part
			band.Transparency = 1
			band:SetAttribute("NightOnly", true)
		else
			add("Underframe", Vector3.new(WIDTH - 1.4, 1.4, LENGTH - 3), CFrame.new(0, 0.9, 0), UNDER, Enum.Material.Metal)
			add("Body", Vector3.new(WIDTH, 6.4, LENGTH), CFrame.new(0, 1.6 + 3.2, 0), BODY, Enum.Material.SmoothPlastic)
			add("Windows", Vector3.new(WIDTH + 0.1, 1.8, LENGTH - 4), CFrame.new(0, 5.4, 0), WINDOWS, Enum.Material.Glass)
			add("Stripe", Vector3.new(WIDTH + 0.12, 0.7, LENGTH - 0.2), CFrame.new(0, 3.2, 0), STRIPE, Enum.Material.SmoothPlastic)
		end
		for _, piece in pieces do
			piece.part.CastShadow = piece.part.Name == "Body"
		end
		table.insert(carriages, pieces)
	end
	rumble.Parent = pieceNamed(carriages[math.ceil(CARRIAGES / 2)], "Body")
end
buildCarriages(kitCarriageMesh())
rumble:Play()
local RUMBLE_VOLUME = 0.6

-- start at the station heading away from the west end, dwelling
local direction = 1
local head = stationDistance + trainLength / 2
local wait = DWELL

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

-- Quality "Low": the train keeps its timetable but leaves the workspace
local player = game:GetService("Players").LocalPlayer
local function applyQuality()
	folder.Parent = if player:GetAttribute("Quality") == "Low" then nil else workspace
end
player:GetAttributeChangedSignal("Quality"):Connect(applyQuality)
applyQuality()

-- X158: after dark (this player's sky, same test as TownLife's lamps) the
-- carriage windows glow warm, like a lit train crossing the viaduct
local LIT_WINDOWS = Color3.fromRGB(255, 214, 150)
-- X248: driven by Sky's published dark flag, not a clock poll
local windowsLit: boolean? = nil
local function refreshWindows()
	local dark = player:GetAttribute("SkyDark") == true
	if dark == windowsLit then
		return
	end
	windowsLit = dark
	for _, pieces in carriages do
		for _, piece in pieces do
			if piece.part.Name == "Windows" then
				piece.part.Color = if dark then LIT_WINDOWS else WINDOWS
				piece.part.Material = if dark then Enum.Material.Neon else Enum.Material.Glass
				if piece.part:GetAttribute("NightOnly") then
					piece.part.Transparency = if dark then 0 else 1
				end
			end
		end
	end
end
player:GetAttributeChangedSignal("SkyDark"):Connect(refreshWindows)
refreshWindows()

-- the kit carriage published after this script started: swap it in
local function swapInKit()
	local mesh = kitCarriageMesh()
	if mesh and not carriages[1][1].part:IsA("MeshPart") then
		buildCarriages(mesh)
		windowsLit = nil
		refreshWindows()
	end
end
task.spawn(function()
	local kit = ReplicatedStorage:WaitForChild("ClientKit")
	clientKit = kit
	kit.ChildAdded:Connect(function(child: Instance)
		if child.Name == "TrainCarriage" then
			task.defer(swapInKit)
		end
	end)
	swapInKit()
end)

RunService.Heartbeat:Connect(function(dt: number)
	local wantVolume = if wait > 0 then 0 else RUMBLE_VOLUME
	rumble.Volume += (wantVolume - rumble.Volume) * math.min(1, dt * 1.5)
	if wait > 0 then
		wait -= dt
	else
		local middleBefore = head - direction * trainLength / 2
		head += direction * SPEED * dt
		local middleAfter = head - direction * trainLength / 2
		if TrafficMath.passedStop(middleBefore, middleAfter, { stationDistance }) then
			head = stationDistance + direction * trainLength / 2
			wait = DWELL
		elseif head > lineLength or head < 0 then
			-- the far end of the line: turn round, the tail becomes the head
			head = math.clamp(head, 0, lineLength) - direction * trainLength
			direction = -direction
			wait = END_PAUSE
		end
	end

	if folder.Parent == nil then
		return
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
	local frames = TrainMath.carriageFrames(points, bridges, head, direction, CARRIAGES, LENGTH, GAP, LATERAL)
	for k, frame in frames do
		for _, piece in carriages[k] do
			table.insert(moveParts, piece.part)
			table.insert(moveCFrames, frame * piece.offset)
		end
	end
	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
