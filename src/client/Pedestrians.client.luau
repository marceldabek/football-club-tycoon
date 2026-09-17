--!strict
-- Ambient pedestrians on the town's pavements (backlog F3.1): cheap 6-part
-- figures stroll along main and residential road pavements near the camera,
-- turn round at road ends, and are recycled as the camera moves. Client-only
-- and purely visual, like Traffic.client.luau: geometry (pavement line, walk
-- cycle, bridge footway height, river check) is pure and lives in
-- Shared.PedestrianMath; this script only spawns/despawns near the camera and
-- moves every part through one workspace:BulkMoveTo per frame.
--
-- Known limits (TEMP): walkers keep walking straight through junction gaps
-- where TownBuilder clipped the pavement (they read as crossing the road),
-- and they can overlap each other since there is no avoidance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TrafficMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrafficMath"))
local PedestrianMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PedestrianMath"))

-- ------------------------------------------------------------------ tuning

local MAX_PEDESTRIANS = 30 -- TEMP mobile budget: 30 x 6 parts = 180 parts
local SPAWN_MIN_DIST = 60 -- TEMP: don't pop in right beside the camera (ignored on the first pass)
local SPAWN_MAX_DIST = 250 -- TEMP
local DESPAWN_DIST = 350 -- TEMP
local RECHECK_INTERVAL = 1 -- seconds between spawn/despawn passes
local SPAWN_ATTEMPTS_PER_RECHECK = 24
local MAX_SPAWNS_PER_RECHECK = 3 -- TEMP: trickle in so arrivals aren't all at once
local SPEED_MIN = 5 -- TEMP studs/s
local SPEED_MAX = 7 -- TEMP studs/s
local LATERAL_JITTER = 2 -- TEMP: +- studs across the 8-stud pavement so walkers don't share one line
local RIVER_BRIDGE_SLACK = 12 -- deck ends count as bridge this far out, see PedestrianMath.blockedByRiver

-- Figure (feet at ground, -Z forward): about 5.3 studs tall, like MatchdayLife fans.
local LEG_SIZE = Vector3.new(0.8, 2.1, 0.8)
local TORSO_SIZE = Vector3.new(1.8, 2.0, 0.9)
local ARM_SIZE = Vector3.new(0.45, 1.9, 0.5)
local HEAD_SIZE = 1.1
local HIP_Y = LEG_SIZE.Y
local TORSO_Y = HIP_Y + TORSO_SIZE.Y / 2
local SHOULDER_Y = HIP_Y + TORSO_SIZE.Y - 0.1
local HEAD_Y = HIP_Y + TORSO_SIZE.Y + HEAD_SIZE / 2
local LEG_X = 0.45
local ARM_X = TORSO_SIZE.X / 2 + ARM_SIZE.X / 2 + 0.03
local ARM_SWING_RATIO = 0.7 -- arms swing a little less than legs, opposite to them

local TORSO_OFFSET = CFrame.new(0, TORSO_Y, 0)
local HEAD_OFFSET = CFrame.new(0, HEAD_Y, 0)
local HIP_L = CFrame.new(-LEG_X, HIP_Y, 0)
local HIP_R = CFrame.new(LEG_X, HIP_Y, 0)
local SHOULDER_L = CFrame.new(-ARM_X, SHOULDER_Y, 0)
local SHOULDER_R = CFrame.new(ARM_X, SHOULDER_Y, 0)
local LEG_HANG = CFrame.new(0, -LEG_SIZE.Y / 2, 0)
local ARM_HANG = CFrame.new(0, -ARM_SIZE.Y / 2 + 0.1, 0)

-- A grey-day UK high street: dark coats, navy, denim, the odd bright jacket.
local TOPS = {
	Color3.fromRGB(35, 38, 50), -- navy
	Color3.fromRGB(28, 28, 30), -- black
	Color3.fromRGB(95, 97, 100), -- charcoal
	Color3.fromRGB(150, 150, 148), -- grey marl
	Color3.fromRGB(110, 30, 40), -- burgundy
	Color3.fromRGB(45, 70, 50), -- bottle green
	Color3.fromRGB(165, 140, 100), -- beige mac
	Color3.fromRGB(70, 95, 140), -- denim jacket
	Color3.fromRGB(200, 90, 40), -- orange rain jacket
	Color3.fromRGB(225, 225, 220), -- white top
}
local TROUSERS = {
	Color3.fromRGB(40, 50, 75), -- dark denim
	Color3.fromRGB(30, 30, 32), -- black
	Color3.fromRGB(85, 85, 88), -- grey joggers
	Color3.fromRGB(120, 105, 80), -- chinos
	Color3.fromRGB(70, 90, 125), -- light denim
}
local SKIN_TONES = {
	Color3.fromRGB(235, 200, 165),
	Color3.fromRGB(225, 185, 145),
	Color3.fromRGB(190, 140, 100),
	Color3.fromRGB(140, 100, 70),
	Color3.fromRGB(95, 65, 45),
}

-- ------------------------------------------------------------------ types

type Path = {
	points: { Vector3 },
	cumulative: { number },
	length: number,
	closed: boolean,
}

type Pedestrian = {
	model: Model,
	parts: { BasePart }, -- torso, head, legL, legR, armL, armR
	path: Path,
	kind: string,
	distance: number,
	direction: number, -- 1 or -1 along the path
	speed: number,
	lateral: number,
	phase: number, -- walk-cycle time offset so walkers aren't in step
	lastPos: Vector3,
}

-- ------------------------------------------------------------------ state

local root = Instance.new("Folder")
root.Name = "Pedestrians"
root.Parent = workspace

local pedestrians: { Pedestrian } = {}
local walkable = PedestrianMath.walkableRoadIndices(TownLayout.ROADS)
local pathCache: { [number]: { [number]: Path } } = {}
local recheckTimer = RECHECK_INTERVAL -- recheck on the first frame
local firstPass = true
local elapsed = 0

-- Reused every frame so the single BulkMoveTo call never allocates a fresh table.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

-- ------------------------------------------------------------------ helpers

local function currentCameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function pathFor(roadIndex: number, side: number): Path
	local bySide = pathCache[roadIndex]
	if not bySide then
		bySide = {}
		pathCache[roadIndex] = bySide
	end
	local cached = bySide[side]
	if cached then
		return cached
	end
	local road = TownLayout.ROADS[roadIndex]
	local points = PedestrianMath.offsetPolyline(road.points, road.width, side)
	local cumulative = PedestrianMath.cumulativeLengths(points)
	local path: Path = {
		points = points,
		cumulative = cumulative,
		length = cumulative[#cumulative] or 0,
		closed = TrafficMath.isClosed(points, 1e-3),
	}
	bySide[side] = path
	return path
end

-- Walker position (XZ, y = 0) and the path's forward direction at `distance`.
local function positionOn(path: Path, distance: number, lateral: number): (Vector3, Vector3)
	local point, pathDir = TrafficMath.pointAt(path.points, distance)
	local across = Vector3.new(-pathDir.Z, 0, pathDir.X)
	return Vector3.new(point.X, 0, point.Z) + across * lateral, pathDir
end

local function blocked(p: Vector3): boolean
	return PedestrianMath.blockedByRiver(p, TownLayout.RIVER, TownLayout.BRIDGES, RIVER_BRIDGE_SLACK)
end

local function part(name: string, size: Vector3, color: Color3, castShadow: boolean, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = castShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function buildFigure(parent: Instance): { BasePart }
	local top = pick(TOPS)
	local trousers = pick(TROUSERS)
	local skin = pick(SKIN_TONES)
	local torso = part("Torso", TORSO_SIZE, top, true, parent)
	local head = part("Head", Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE), skin, false, parent)
	head.Shape = Enum.PartType.Ball
	local legL = part("LegL", LEG_SIZE, trousers, false, parent)
	local legR = part("LegR", LEG_SIZE, trousers, false, parent)
	local armL = part("ArmL", ARM_SIZE, top, false, parent)
	local armR = part("ArmR", ARM_SIZE, top, false, parent)
	return { torso, head, legL, legR, armL, armR }
end

-- ------------------------------------------------------------------ spawn / despawn

local function spawnPedestrian(path: Path, kind: string, distance: number, lateral: number, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Pedestrian"
	local parts = buildFigure(model)
	model.Parent = root

	local ped: Pedestrian = {
		model = model,
		parts = parts,
		path = path,
		kind = kind,
		distance = distance,
		direction = if math.random() < 0.5 then 1 else -1,
		speed = SPEED_MIN + math.random() * (SPEED_MAX - SPEED_MIN),
		lateral = lateral,
		phase = math.random() * 10,
		lastPos = pos,
	}
	table.insert(pedestrians, ped)
end

local function despawnAt(index: number)
	local ped = table.remove(pedestrians, index)
	if ped then
		ped.model:Destroy()
	end
end

local function recheckDespawns(camPos: Vector3)
	for i = #pedestrians, 1, -1 do
		if flatDistance(pedestrians[i].lastPos, camPos) > DESPAWN_DIST then
			despawnAt(i)
		end
	end
end

local function recheckSpawns(camPos: Vector3)
	if #pedestrians >= MAX_PEDESTRIANS or #walkable == 0 then
		return
	end
	local refs = PedestrianMath.segmentsNear(TownLayout.ROADS, walkable, camPos, SPAWN_MAX_DIST)
	if #refs == 0 then
		return
	end
	-- Empty (join, or the camera just fast-travelled): fill up at once instead
	-- of trickling. Only the very first fill may place walkers right by the camera.
	local burst = #pedestrians == 0
	local minDist = if firstPass then 0 else SPAWN_MIN_DIST
	local maxSpawns = if burst then MAX_PEDESTRIANS else MAX_SPAWNS_PER_RECHECK
	local spawned = 0
	for _ = 1, (if burst then SPAWN_ATTEMPTS_PER_RECHECK * 4 else SPAWN_ATTEMPTS_PER_RECHECK) do
		if #pedestrians >= MAX_PEDESTRIANS or spawned >= maxSpawns then
			break
		end
		local ref = refs[math.random(1, #refs)]
		local road = TownLayout.ROADS[ref.roadIndex]
		local side = if math.random() < 0.5 then 1 else -1
		local path = pathFor(ref.roadIndex, side)
		local segStart = path.cumulative[ref.segment]
		local segEnd = path.cumulative[ref.segment + 1]
		if not (road and segStart and segEnd) or path.length <= 1 then
			continue
		end
		local distance = segStart + math.random() * (segEnd - segStart)
		local lateral = (math.random() * 2 - 1) * LATERAL_JITTER
		local pos = positionOn(path, distance, lateral)
		local d = flatDistance(pos, camPos)
		if d < minDist or d > SPAWN_MAX_DIST or blocked(pos) then
			continue
		end
		spawnPedestrian(path, road.kind, distance, lateral, pos)
		spawned += 1
	end
	if spawned > 0 then
		firstPass = false
	end
end

-- ------------------------------------------------------------------ movement

local function movePedestrian(ped: Pedestrian, dt: number)
	local path = ped.path
	local prevDistance = ped.distance
	local newDistance, newDirection =
		PedestrianMath.advance(ped.distance, ped.direction, ped.speed * dt, path.length, path.closed)
	local pos, pathDir = positionOn(path, newDistance, ped.lateral)
	if blocked(pos) then
		-- Would step into the river (no bridge here): turn round on the spot.
		ped.direction = -ped.direction
		pos, pathDir = positionOn(path, prevDistance, ped.lateral)
	else
		ped.distance = newDistance
		ped.direction = newDirection
	end
	ped.lastPos = pos

	local facing = pathDir * ped.direction
	local yaw = math.atan2(-facing.X, -facing.Z)
	local bob, swing = PedestrianMath.walkCycle(elapsed + ped.phase, ped.speed)
	local y = PedestrianMath.groundY(pos, ped.kind, TownLayout.BRIDGES) + bob
	local rootCFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, yaw, 0)
	local armSwing = swing * ARM_SWING_RATIO

	local parts = ped.parts
	table.insert(moveParts, parts[1])
	table.insert(moveCFrames, rootCFrame * TORSO_OFFSET)
	table.insert(moveParts, parts[2])
	table.insert(moveCFrames, rootCFrame * HEAD_OFFSET)
	table.insert(moveParts, parts[3])
	table.insert(moveCFrames, rootCFrame * HIP_L * CFrame.Angles(swing, 0, 0) * LEG_HANG)
	table.insert(moveParts, parts[4])
	table.insert(moveCFrames, rootCFrame * HIP_R * CFrame.Angles(-swing, 0, 0) * LEG_HANG)
	table.insert(moveParts, parts[5])
	table.insert(moveCFrames, rootCFrame * SHOULDER_L * CFrame.Angles(-armSwing, 0, 0) * ARM_HANG)
	table.insert(moveParts, parts[6])
	table.insert(moveCFrames, rootCFrame * SHOULDER_R * CFrame.Angles(armSwing, 0, 0) * ARM_HANG)
end

-- ------------------------------------------------------------------ main loop

RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	recheckTimer += dt
	if recheckTimer >= RECHECK_INTERVAL then
		recheckTimer = 0
		local camPos = currentCameraPosition()
		recheckDespawns(camPos)
		recheckSpawns(camPos)
	end

	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, ped in pedestrians do
		movePedestrian(ped, dt)
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
