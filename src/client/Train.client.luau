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
for _ = 1, CARRIAGES do
	local pieces: { Piece } = {}
	local function add(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material)
		table.insert(pieces, { part = newPart(name, size, colour, material), offset = offset })
	end
	add("Underframe", Vector3.new(WIDTH - 1.4, 1.4, LENGTH - 3), CFrame.new(0, 0.9, 0), UNDER, Enum.Material.Metal)
	add("Body", Vector3.new(WIDTH, 6.4, LENGTH), CFrame.new(0, 1.6 + 3.2, 0), BODY, Enum.Material.SmoothPlastic)
	add("Windows", Vector3.new(WIDTH + 0.1, 1.8, LENGTH - 4), CFrame.new(0, 5.4, 0), WINDOWS, Enum.Material.Glass)
	add("Stripe", Vector3.new(WIDTH + 0.12, 0.7, LENGTH - 0.2), CFrame.new(0, 3.2, 0), STRIPE, Enum.Material.SmoothPlastic)
	table.insert(carriages, pieces)
end
for _, pieces in carriages do
	for _, piece in pieces do
		piece.part.CastShadow = piece.part.Name == "Body"
	end
end

-- start at the station heading away from the west end, dwelling
local direction = 1
local head = stationDistance + trainLength / 2
local wait = DWELL

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

RunService.Heartbeat:Connect(function(dt: number)
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
