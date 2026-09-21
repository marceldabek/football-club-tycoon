--!strict
-- Ambient pedestrians on the town's pavements (backlog F3.1): Townsfolk
-- figures stroll along main and residential road pavements near the camera,
-- turn round at road ends, and are recycled as the camera moves. Client-only
-- and purely visual, like Traffic.client.luau: geometry (pavement line, walk
-- cycle, bridge footway height, river check) is pure and lives in
-- Shared.PedestrianMath; this script only spawns/despawns near the camera and
-- poses each figure (Shared.Townsfolk) plus, for the dog, one
-- workspace:BulkMoveTo per frame.
--
-- Walkers follow RoadPaths.townRoads() (corners rounded to the kit bends) and
-- keep to the pavement (the kit paving plus the PavingStrips behind it, 6.9 wide). They
-- turn round at junction mouths (PedestrianMath.junctionZones) rather than
-- stroll across open asphalt, step aside for a walker coming the other way, and
-- fall in behind a slower one. They spawn round the streaming focus, spaced
-- out, with the budget capped by how much pavement is actually nearby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TrafficMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrafficMath"))
local PedestrianMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PedestrianMath"))
local RoadTiles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoadTiles"))
local RoadPaths = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoadPaths"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Townsfolk = require(script.Parent:WaitForChild("Townsfolk"))

-- Arms swing at 0.7 of the legs' amplitude: matching them exactly reads as a
-- march rather than a walk.
local ARM_SWING_RATIO = 0.7

-- ------------------------------------------------------------------ tuning

local MAX_PEDESTRIANS = 30 -- TEMP mobile budget: 30 x 6 parts = 180 parts (+4 per dog, about 1 in 6 on residential streets)
local MAX_PEDESTRIANS_LOW = 12 -- TEMP, Quality "Low" (mirrors Shared.Quality.BUDGETS.Low.pedestrians)

-- C3.2: QualityController publishes "High" | "Low" on the LocalPlayer.
local function maxPedestrians(): number
	local player = game:GetService("Players").LocalPlayer
	return if player and player:GetAttribute("Quality") == "Low" then MAX_PEDESTRIANS_LOW else MAX_PEDESTRIANS
end
local SPAWN_MIN_DIST = 60 -- TEMP: don't pop in right beside the camera (ignored on the first pass)
local SPAWN_MAX_DIST = 250 -- TEMP
local DESPAWN_DIST = 350 -- TEMP
local RECHECK_INTERVAL = 1 -- seconds between spawn/despawn passes
local SPAWN_ATTEMPTS_PER_RECHECK = 24
local MAX_SPAWNS_PER_RECHECK = 3 -- TEMP: trickle in so arrivals aren't all at once
local SPEED_MIN = 5 -- TEMP studs/s
local SPEED_MAX = 7 -- TEMP studs/s
local RIVER_BRIDGE_SLACK = 12 -- deck ends count as bridge this far out, see PedestrianMath.blockedByRiver
local SPAWN_CLEAR = 12 -- TEMP: no walker spawns this close to another
local PAVEMENT_PER_WALKER = 45 -- TEMP: studs of nearby pavement (both sides counted) per walker; caps the budget where few streets are in range
local MOUTH_EXTRA = 3 -- a side road's mouth is its kerb-to-kerb width plus this much corner each side
local SIDESTEP = 1.3 -- TEMP studs a walker moves over for one coming the other way
local SIDESTEP_AHEAD = 7 -- ...when they are this close
local SIDESTEP_RATE = 2 -- studs/s
local FOLLOW_AHEAD = 8 -- a walker this close behind another going the same way drops below its pace, so the gap opens to this

-- Figure: Townsfolk's shared R6 rig. Metrics and palettes live there now, so
-- the walk cycle and the rig itself cannot drift apart.

-- X142: some walkers on residential streets have a dog on a lead
-- (RivermereNorthfields.png): body, head, tail and lead, trotting at heel on
-- the walker's right. 4 more parts per dog.
local DOG_CHANCE = 1 / 6
local DOG_KINDS: { [string]: boolean } = { residential = true, lane = true }
local DOG_SIDE = CFrame.new(1.9, 0, -1.4)
local DOG_BODY = CFrame.new(0, 0.6, 0)
local DOG_HEAD = CFrame.new(0, 1.15, -1.2)
local DOG_TAIL = CFrame.new(0, 0.95, 1.25) * CFrame.Angles(math.rad(-35), 0, 0)
local DOG_COLLAR = CFrame.new(0, 1.0, -0.8)
local HAND_R = CFrame.new(Townsfolk.ARM_X, Townsfolk.SHOULDER_Y - Townsfolk.ARM_SIZE.Y + 0.2, 0)
local LEAD_LENGTH = ((DOG_SIDE * DOG_COLLAR).Position - HAND_R.Position).Magnitude
local DOG_COLOURS = {
	Color3.fromRGB(60, 44, 30),
	Color3.fromRGB(196, 160, 100),
	Color3.fromRGB(30, 30, 32),
	Color3.fromRGB(235, 232, 225),
}

-- ------------------------------------------------------------------ types

type Path = {
	points: { Vector3 },
	cumulative: { number },
	length: number,
	closed: boolean,
	zones: { PedestrianMath.Zone }, -- junction mouths: not pavement
}

type Pedestrian = {
	model: Model,
	figure: Townsfolk.Figure,
	dogParts: { BasePart }?, -- body, head, tail, lead (X142); nil when this walker has no dog
	path: Path,
	kind: string,
	distance: number,
	direction: number, -- 1 or -1 along the path
	speed: number,
	pace: number, -- this frame's speed (its own, or a slower walker's just ahead)
	home: number, -- the line it keeps across the pavement
	lateral: number, -- where it is now (home, or stepped aside)
	phase: number, -- walk-cycle time offset so walkers aren't in step
	lastPos: Vector3,
}

-- ------------------------------------------------------------------ state

local root = Instance.new("Folder")
root.Name = "Pedestrians"
root.Parent = workspace

local pedestrians: { Pedestrian } = {}
-- TownLayout.ROADS with the corners rounded to the kit bends; same indices
local ROADS = RoadPaths.townRoads()
local walkable = PedestrianMath.walkableRoadIndices(ROADS)
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

-- Where the world is streamed in round: the server's ReplicationFocus (plot
-- picker), else the character, else the camera. (Same rule as Traffic.)
local function streamingFocus(): Vector3
	local player = game:GetService("Players").LocalPlayer
	local focus = player and player.ReplicationFocus
	if focus and focus:IsA("BasePart") then
		return focus.Position
	end
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end
	return currentCameraPosition()
end

-- Is any of the town streamed in under `point`? (No: the walker would stand on
-- the low stand-in terrain, floating.)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function townUnder(point: Vector3): boolean
	local town = workspace:FindFirstChild("Town")
	if not town then
		return false
	end
	groundParams.FilterDescendantsInstances = { town }
	return workspace:Raycast(Vector3.new(point.X, 60, point.Z), Vector3.new(0, -120, 0), groundParams) ~= nil
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
	local road = ROADS[roadIndex]
	local points = PedestrianMath.offsetPolyline(road.points, road.width, side, PedestrianMath.kitPavementDistance(road.kind))
	local cumulative = PedestrianMath.cumulativeLengths(points)
	local path: Path
	path = {
		points = points,
		cumulative = cumulative,
		length = cumulative[#cumulative] or 0,
		closed = TrafficMath.isClosed(points, 1e-3),
		zones = PedestrianMath.junctionZones(points, cumulative, ROADS, roadIndex, function(kind: string): number
			return RoadTiles.kerbDistance(kind) + MOUTH_EXTRA
		end, function(kind: string): number
			-- stop on the other road's paved strip, clear of its kerb
			return PedestrianMath.kitPavementDistance(kind)
		end),
	}
	if road.head then
		-- the last point is the middle of a turning head's bulb, not pavement
		local scale = RoadTiles.SCALE[road.kind] or RoadTiles.STREET_SCALE
		table.insert(path.zones, { from = path.length - RoadTiles.PIECES.head.legA * scale, to = path.length + 1 })
	end
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
		or PedestrianMath.onRoundabout(p, TownLayout.ROUNDABOUTS)
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

-- X162: on matchday (a ground within MATCHDAY_RADIUS of the spawn is in
-- PreMatch or Match) about a third of new walkers wear the home kit colour
local MATCHDAY_RADIUS = 900 -- plots sit on the edge of town; the nearest pavement to a plot centre is ~490 away
local MATCHDAY_KIT_SHARE = 1 / 3
local function matchdayNear(p: Vector3): boolean
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	if not clubs then
		return false
	end
	for _, folder in clubs:GetChildren() do
		local phase = folder:GetAttribute("Phase")
		local cf = folder:GetAttribute("PlotCFrame")
		if (phase == "PreMatch" or phase == "Match") and typeof(cf) == "CFrame" and flatDistance(cf.Position, p) <= MATCHDAY_RADIUS then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------ spawn / despawn

-- Townsfolk.build can fail to produce a rig (e.g. the avatar pipeline is
-- unavailable); the caller must skip spawning rather than falling back to parts.
local function spawnPedestrian(path: Path, kind: string, distance: number, lateral: number, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Pedestrian"
	local kit = if math.random() < MATCHDAY_KIT_SHARE and matchdayNear(pos) then Config.HomeKit else nil
	local figure = Townsfolk.build(model, { shirt = kit })
	if not figure then
		model:Destroy()
		return
	end

	-- no dogs on Low (walkers already spawned with one keep it until they despawn)
	local wantsDog = DOG_KINDS[kind] == true and math.random() < DOG_CHANCE and maxPedestrians() == MAX_PEDESTRIANS
	local dogParts: { BasePart }? = nil
	if wantsDog then
		local coat = pick(DOG_COLOURS)
		dogParts = {
			part("DogBody", Vector3.new(0.8, 0.9, 2), coat, true, model),
			part("DogHead", Vector3.new(0.7, 0.7, 0.8), coat, false, model),
			part("DogTail", Vector3.new(0.15, 0.15, 0.8), coat, false, model),
			part("DogLead", Vector3.new(0.08, 0.08, LEAD_LENGTH), Color3.fromRGB(180, 30, 40), false, model),
		}
	end
	model.Parent = root

	local ped: Pedestrian = {
		model = model,
		figure = figure,
		dogParts = dogParts,
		path = path,
		kind = kind,
		distance = distance,
		direction = if math.random() < 0.5 then 1 else -1,
		speed = SPEED_MIN + math.random() * (SPEED_MAX - SPEED_MIN),
		pace = 0,
		home = lateral,
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
	-- quality dropped to Low: shed walkers over the budget
	local limit = maxPedestrians()
	while #pedestrians > limit do
		despawnAt(#pedestrians)
	end
end

local function recheckSpawns(focus: Vector3)
	if #walkable == 0 then
		return
	end
	local refs = PedestrianMath.segmentsNear(ROADS, walkable, focus, SPAWN_MAX_DIST)
	if #refs == 0 then
		return
	end
	-- Pick a segment in proportion to its length (picking by index crowded the
	-- short ones), and let the pavement in range set the budget: out by a plot only
	-- one road is near, and all 30 walkers used to pile onto it.
	local cumulative: { number } = {}
	local total = 0
	for i, ref in refs do
		local points = ROADS[ref.roadIndex].points
		total += (points[ref.segment + 1] - points[ref.segment]).Magnitude
		cumulative[i] = total
	end
	local cap = math.min(maxPedestrians(), math.floor(total * 2 / PAVEMENT_PER_WALKER))
	if #pedestrians >= cap then
		return
	end
	-- Empty (join, or the camera just fast-travelled): fill up at once instead
	-- of trickling. Only the very first fill may place walkers right by the camera.
	local burst = #pedestrians == 0
	local minDist = if firstPass then 0 else SPAWN_MIN_DIST
	local maxSpawns = if burst then cap else MAX_SPAWNS_PER_RECHECK
	local spawned = 0
	local taken: { Vector3 } = {}
	for _, ped in pedestrians do
		table.insert(taken, ped.lastPos)
	end
	for _ = 1, (if burst then SPAWN_ATTEMPTS_PER_RECHECK * 4 else SPAWN_ATTEMPTS_PER_RECHECK) do
		if #pedestrians >= cap or spawned >= maxSpawns then
			break
		end
		local ref = refs[TrafficMath.weightedIndex(cumulative, math.random()) or 1]
		local road = ROADS[ref.roadIndex]
		local side = if math.random() < 0.5 then 1 else -1
		local path = pathFor(ref.roadIndex, side)
		local segStart = path.cumulative[ref.segment]
		local segEnd = path.cumulative[ref.segment + 1]
		if not (road and segStart and segEnd) or path.length <= 1 then
			continue
		end
		local distance = segStart + math.random() * (segEnd - segStart)
		local lateral = (math.random() * 2 - 1) * PedestrianMath.kitPavementJitter(road.kind)
		local pos = positionOn(path, distance, lateral)
		local d = flatDistance(pos, focus)
		if d < minDist or d > SPAWN_MAX_DIST or blocked(pos) or PedestrianMath.inZones(path.zones, distance) then
			continue
		end
		if TrafficMath.crowded(pos, taken, SPAWN_CLEAR) or not townUnder(pos) then
			continue
		end
		spawnPedestrian(path, road.kind, distance, lateral, pos)
		table.insert(taken, pos)
		spawned += 1
	end
	if spawned > 0 then
		firstPass = false
	end
end

-- ------------------------------------------------------------------ movement

-- Walkers sharing a pavement line: one coming the other way close ahead makes
-- this walker step aside (each to its own side, so they pass shoulder to
-- shoulder instead of through each other); one close ahead going the same way
-- holds this walker back until there is a gap. Writes ped.pace and returns the lateral it wants.
local function mindOthers(ped: Pedestrian): number
	ped.pace = ped.speed
	local want = ped.home
	for _, other in pedestrians do
		if other == ped or other.path ~= ped.path then
			continue
		end
		local ahead = (other.distance - ped.distance) * ped.direction
		if ahead <= 0 then
			continue
		end
		if other.direction ~= ped.direction then
			if ahead < SIDESTEP_AHEAD then
				-- each to its own side, but never off the pavement
				local reach = PedestrianMath.kitPavementJitter(ped.kind) + 0.5
				want = math.clamp(ped.home + ped.direction * SIDESTEP, -reach, reach)
			end
		elseif ahead < FOLLOW_AHEAD then
			ped.pace = math.min(ped.pace, other.speed * 0.85)
		end
	end
	return want
end

local function movePedestrian(ped: Pedestrian, dt: number)
	local path = ped.path
	local prevDistance = ped.distance
	local want = mindOthers(ped)
	ped.lateral += math.clamp(want - ped.lateral, -SIDESTEP_RATE * dt, SIDESTEP_RATE * dt)
	local newDistance, newDirection =
		PedestrianMath.advance(ped.distance, ped.direction, ped.pace * dt, path.length, path.closed)
	local pos, pathDir = positionOn(path, newDistance, ped.lateral)
	-- a junction mouth ahead counts like the river, unless the walker is somehow
	-- already inside one (then it just keeps going until it is out)
	local mouth = PedestrianMath.inZones(path.zones, newDistance) and not PedestrianMath.inZones(path.zones, prevDistance)
	if blocked(pos) or mouth then
		-- Would step into the river (no bridge here) or out across a side road: turn round on the spot.
		ped.direction = -ped.direction
		pos, pathDir = positionOn(path, prevDistance, ped.lateral)
	else
		ped.distance = newDistance
		ped.direction = newDirection
	end
	ped.lastPos = pos

	local facing = pathDir * ped.direction
	local yaw = math.atan2(-facing.X, -facing.Z)
	local bob, swing = PedestrianMath.walkCycle(elapsed + ped.phase, ped.pace)
	local y = PedestrianMath.groundY(pos, ped.kind, TownLayout.BRIDGES) + bob
	-- Townsfolk.pose wants base.Position between the feet, on the ground --
	-- exactly what rootCFrame already was before the limb offsets were applied.
	local rootCFrame = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, yaw, 0)

	-- X371: arms at 0.7 of the leg amplitude, as before the shared rig landed
	Townsfolk.pose(ped.figure, rootCFrame, swing, ARM_SWING_RATIO)

	local dogParts = ped.dogParts
	if dogParts then
		-- a quicker, smaller bounce than the walker's
		local trot = math.abs(math.sin((elapsed + ped.phase) * 9)) * 0.12
		local dogRoot = CFrame.new(pos.X, y - bob + trot, pos.Z) * CFrame.Angles(0, yaw, 0) * DOG_SIDE
		table.insert(moveParts, dogParts[1])
		table.insert(moveCFrames, dogRoot * DOG_BODY)
		table.insert(moveParts, dogParts[2])
		table.insert(moveCFrames, dogRoot * DOG_HEAD)
		table.insert(moveParts, dogParts[3])
		table.insert(moveCFrames, dogRoot * DOG_TAIL * CFrame.Angles(0, math.sin((elapsed + ped.phase) * 12) * 0.4, 0))
		local hand = (rootCFrame * HAND_R).Position
		local collar = (dogRoot * DOG_COLLAR).Position
		table.insert(moveParts, dogParts[4])
		table.insert(moveCFrames, CFrame.lookAt((hand + collar) / 2, collar))
	end
end

-- ------------------------------------------------------------------ main loop

RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	recheckTimer += dt
	if recheckTimer >= RECHECK_INTERVAL then
		recheckTimer = 0
		local focus = streamingFocus()
		recheckDespawns(focus)
		recheckSpawns(focus)
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
