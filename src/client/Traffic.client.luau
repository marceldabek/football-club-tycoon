--!strict
-- Ambient road traffic for the shared town (backlog F2.1): low-part primitive
-- cars and the occasional bus drive the TownLayout road network so Rivermere
-- doesn't feel dead between the plots. Geometry (following a road, picking a
-- lane, finding the next road at a junction) is pure and lives in
-- Shared.TrafficMath so it can be unit-tested without Roblox services; this
-- script only decides what to spawn/despawn near the camera and moves parts
-- every frame, the same cheap-crowd approach as BlockFootballer/MatchdayLife
-- (one RenderStepped connection, one workspace:BulkMoveTo per frame).
--
-- UK traffic drives on the left: TrafficMath.laneOffset(direction, width, -1)
-- puts each car a quarter-carriageway to the left of the centreline for the
-- direction it is travelling, so opposite-direction traffic never shares a
-- lane. Road top heights and the bridge deck offset mirror TownBuilder's Y
-- table (ring 0.20 / main 0.21 / residential 0.22 / lane 0.23, deck +0.5)
-- since this client script cannot require the server-only TownBuilder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TrafficMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrafficMath"))

-- ------------------------------------------------------------------ tuning

local MAX_CARS = 24 -- mobile budget; raise/lower this alone to retune the pool
local MAX_CARS_LOW = 8 -- TEMP, Quality "Low" (mirrors Shared.Quality.BUDGETS.Low.maxCars)

-- C3.2: QualityController publishes "High" | "Low" on the LocalPlayer.
local function maxCars(): number
	local player = game:GetService("Players").LocalPlayer
	return if player and player:GetAttribute("Quality") == "Low" then MAX_CARS_LOW else MAX_CARS
end
local BUS_EVERY = 8 -- 1 in 8 spawns is a bus
-- F2.2: buses pull up at the TownLayout bus stops on their road
local BUS_STOP_DWELL = 4 -- TEMP seconds stopped
local BUS_STOP_REACH = 40 -- a stop this close to the road centreline serves it (the Station stop is 36 out)
-- F3.3 cyclists: on residential streets only (lanes are too narrow to pass), by the kerb.
-- Cars don't queue behind them (they're left out of the leader-gap check).
local BIKE_EVERY = 5 -- TEMP: 1 in 5 spawns on a quiet street is a bike
local BIKE_SPEED = 11 -- TEMP studs/s
local BIKE_KERB_INSET = 1.6 -- rider (1.3 wide) clears a car in the lane on a 20-wide residential street
local ISLAND_CLEAR = 4.5 -- X79: vehicle centre from a roundabout island's edge (cars ~6 wide)
local ISLAND_CLEAR_BUS = 5.5
local BIKE_COLOURS = { Color3.fromRGB(40, 90, 170), Color3.fromRGB(190, 40, 40), Color3.fromRGB(30, 30, 34), Color3.fromRGB(220, 200, 60) }
local SPAWN_MIN_DIST = 150
local SPAWN_MAX_DIST = 700
local DESPAWN_DIST = 800
local RECHECK_INTERVAL = 1 -- seconds between spawn/despawn passes
local SPAWN_ATTEMPTS_PER_RECHECK = 40
local MAX_SPAWNS_PER_RECHECK = 4
local MIN_GAP = 14 -- studs kept behind the car ahead, same road + direction
local JOIN_TOLERANCE_EXTRA = 45 -- added to (own road width / 2) when hunting for the next road
local GIVE_WAY_CLEAR = 22 -- X88: another vehicle this close to the junction makes a car wait (TEMP)
local GIVE_WAY_WAIT = 1.4 -- seconds, once per junction
local SPEED_JITTER = 0.15 -- +/- fraction of a kind's base speed, per car

local SPEED_BY_KIND: { [TownLayout.RoadKind]: number } = { ring = 40, main = 32, residential = 20, lane = 14 }
local ROAD_TOP: { [TownLayout.RoadKind]: number } = { ring = 0.20, main = 0.21, residential = 0.22, lane = 0.23 }
local DECK_ABOVE_ROAD = 0.5

local PALETTE = {
	Color3.fromRGB(196, 196, 201), -- silver
	Color3.fromRGB(120, 120, 124), -- grey
	Color3.fromRGB(233, 233, 228), -- white
	Color3.fromRGB(25, 25, 28), -- black
	Color3.fromRGB(30, 45, 90), -- dark blue
	Color3.fromRGB(140, 25, 25), -- red
	Color3.fromRGB(30, 70, 40), -- green
}

-- Car rig: Body, Cabin, 4 wheels, 2 tail lights = 8 parts.
local BODY_SIZE = Vector3.new(4.2, 1.3, 7.6)
local CABIN_SIZE = Vector3.new(3.4, 1.0, 3.6)
local WHEEL_RADIUS = 0.85
local WHEEL_WIDTH = 0.5
local TAILLIGHT_SIZE = Vector3.new(0.35, 0.3, 0.12)
local TAILLIGHT_COLOR = Color3.fromRGB(150, 20, 20) -- Neon-free red

-- Bus rig: Body, window band, 4 wheels = 6 parts.
local BUS_BODY_SIZE = Vector3.new(4.4, 3.0, 13.5)
local BUS_WINDOW_SIZE = Vector3.new(4.5, 1.0, 11.5)
local BUS_WHEEL_RADIUS = 1.0
local BUS_WHEEL_WIDTH = 0.6
local BUS_WINDOW_COLOR = Color3.fromRGB(140, 170, 185)

-- Root-local offsets (root sits at road-top height, yawed so -Z is forward),
-- computed once since each vehicle type's silhouette is fixed.
local CAR_WHEEL_Y = 0.1 + WHEEL_RADIUS
local CAR_BODY_Y = CAR_WHEEL_Y + WHEEL_RADIUS * 0.5 + BODY_SIZE.Y / 2
local CAR_CABIN_Y = CAR_BODY_Y + BODY_SIZE.Y / 2 + CABIN_SIZE.Y / 2 - 0.2
local CAR_TAIL_Y = CAR_WHEEL_Y + WHEEL_RADIUS * 0.6
local CAR_TRACK_X = BODY_SIZE.X / 2 + WHEEL_WIDTH * 0.2
local CAR_AXLE_Z = BODY_SIZE.Z / 2 - WHEEL_RADIUS - 0.5
local CAR_TAIL_X = BODY_SIZE.X / 2 - 0.4
local CAR_TAIL_Z = BODY_SIZE.Z / 2 - 0.05

-- Order matches buildCar's part list: Body, Cabin, WheelFL, WheelFR, WheelRL, WheelRR, TailL, TailR.
local CAR_OFFSETS: { Vector3 } = {
	Vector3.new(0, CAR_BODY_Y, 0),
	Vector3.new(0, CAR_CABIN_Y, 0),
	Vector3.new(-CAR_TRACK_X, CAR_WHEEL_Y, -CAR_AXLE_Z),
	Vector3.new(CAR_TRACK_X, CAR_WHEEL_Y, -CAR_AXLE_Z),
	Vector3.new(-CAR_TRACK_X, CAR_WHEEL_Y, CAR_AXLE_Z),
	Vector3.new(CAR_TRACK_X, CAR_WHEEL_Y, CAR_AXLE_Z),
	Vector3.new(-CAR_TAIL_X, CAR_TAIL_Y, CAR_TAIL_Z),
	Vector3.new(CAR_TAIL_X, CAR_TAIL_Y, CAR_TAIL_Z),
}

local BUS_WHEEL_Y = 0.1 + BUS_WHEEL_RADIUS
local BUS_BODY_Y = BUS_WHEEL_Y + BUS_WHEEL_RADIUS * 0.3 + BUS_BODY_SIZE.Y / 2
local BUS_WINDOW_Y = BUS_BODY_Y + BUS_BODY_SIZE.Y * 0.15
local BUS_TRACK_X = BUS_BODY_SIZE.X / 2 + BUS_WHEEL_WIDTH * 0.2
local BUS_AXLE_Z = BUS_BODY_SIZE.Z / 2 - BUS_WHEEL_RADIUS - 1.2

-- Order matches buildBus's part list: Body, Windows, WheelF1, WheelF2, WheelR1, WheelR2.
local BUS_OFFSETS: { Vector3 } = {
	Vector3.new(0, BUS_BODY_Y, 0),
	Vector3.new(0, BUS_WINDOW_Y, 0),
	Vector3.new(-BUS_TRACK_X, BUS_WHEEL_Y, -BUS_AXLE_Z),
	Vector3.new(BUS_TRACK_X, BUS_WHEEL_Y, -BUS_AXLE_Z),
	Vector3.new(-BUS_TRACK_X, BUS_WHEEL_Y, BUS_AXLE_Z),
	Vector3.new(BUS_TRACK_X, BUS_WHEEL_Y, BUS_AXLE_Z),
}

-- ------------------------------------------------------------------ types

type Car = {
	model: Model,
	parts: { BasePart },
	isBus: boolean,
	isBike: boolean,
	roadIndex: number,
	direction: number, -- 1 or -1 along the road's polyline
	distance: number, -- studs along the current road
	length: number, -- cached TrafficMath.polylineLength of the current road
	kind: TownLayout.RoadKind,
	jitter: number, -- per-car multiplier on its kind's base speed
	speed: number, -- this frame's effective speed (after the leader check)
	lastPos: Vector3, -- last computed world XZ position (Y = road/deck top), for despawn checks
	dwell: number, -- seconds left stopped at a bus stop
	lastStop: number?, -- distance of the stop it last pulled up at on this road (not twice in a row)
	gaveWay: boolean, -- X88: already waited at the end of this road
}

-- ------------------------------------------------------------------ state

local root = Instance.new("Folder")
root.Name = "Traffic"
root.Parent = workspace

local cars: { Car } = {}
local recheckTimer = 0

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

local function roadTopFor(kind: TownLayout.RoadKind): number
	return ROAD_TOP[kind] or ROAD_TOP.lane
end

-- If `point` falls within a road bridge's deck rectangle, the deck top;
-- otherwise nil (stay at the ordinary road top).
local function bridgeDeckY(point: Vector3, kind: TownLayout.RoadKind): number?
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind ~= "road" then
			continue
		end
		local a, b = bridge.from, bridge.to
		local seg = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local segLen = seg.Magnitude
		if segLen < 1e-6 then
			continue
		end
		local ap = Vector3.new(point.X - a.X, 0, point.Z - a.Z)
		local t = ap:Dot(seg) / (segLen * segLen)
		if t < 0 or t > 1 then
			continue
		end
		local closest = a:Lerp(b, t)
		if flatDistance(point, closest) <= bridge.width / 2 then
			-- humped decks (X31): ramps up from each end, level over the water
			return roadTopFor(kind) + DECK_ABOVE_ROAD + TownLayout.bridgeRise(bridge, t * segLen)
		end
	end
	return nil
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

-- Cylinder axis is the part's local X by default; with only a yaw applied to
-- the root, that lands sideways (an axle), so wheels need no extra rotation.
-- Wheels do not spin (no per-frame rotation), per the low-part budget.
local function wheel(name: string, radius: number, width: number, parent: Instance): BasePart
	local p = part(name, Vector3.new(width, radius * 2, radius * 2), Color3.fromRGB(20, 20, 20), false, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function buildCar(parent: Instance, color: Color3): { BasePart }
	local body = part("Body", BODY_SIZE, color, true, parent)
	local cabin = part("Cabin", CABIN_SIZE, color:Lerp(Color3.new(0, 0, 0), 0.15), false, parent)
	local wheelFL = wheel("WheelFL", WHEEL_RADIUS, WHEEL_WIDTH, parent)
	local wheelFR = wheel("WheelFR", WHEEL_RADIUS, WHEEL_WIDTH, parent)
	local wheelRL = wheel("WheelRL", WHEEL_RADIUS, WHEEL_WIDTH, parent)
	local wheelRR = wheel("WheelRR", WHEEL_RADIUS, WHEEL_WIDTH, parent)
	local tailL = part("TailLightL", TAILLIGHT_SIZE, TAILLIGHT_COLOR, false, parent)
	local tailR = part("TailLightR", TAILLIGHT_SIZE, TAILLIGHT_COLOR, false, parent)
	return { body, cabin, wheelFL, wheelFR, wheelRL, wheelRR, tailL, tailR }
end

local function buildBus(parent: Instance, color: Color3): { BasePart }
	local body = part("Body", BUS_BODY_SIZE, color, true, parent)
	local windows = part("Windows", BUS_WINDOW_SIZE, BUS_WINDOW_COLOR, false, parent)
	local wheelF1 = wheel("WheelF1", BUS_WHEEL_RADIUS, BUS_WHEEL_WIDTH, parent)
	local wheelF2 = wheel("WheelF2", BUS_WHEEL_RADIUS, BUS_WHEEL_WIDTH, parent)
	local wheelR1 = wheel("WheelR1", BUS_WHEEL_RADIUS, BUS_WHEEL_WIDTH, parent)
	local wheelR2 = wheel("WheelR2", BUS_WHEEL_RADIUS, BUS_WHEEL_WIDTH, parent)
	return { body, windows, wheelF1, wheelF2, wheelR1, wheelR2 }
end

-- Bike rig: 2 wheels, frame, rider torso, head, 2 legs = 7 parts.
local BIKE_WHEEL_RADIUS = 1.05
local BIKE_OFFSETS: { Vector3 } = {
	Vector3.new(0, 0.1 + BIKE_WHEEL_RADIUS, -1.35), -- front wheel
	Vector3.new(0, 0.1 + BIKE_WHEEL_RADIUS, 1.35), -- rear wheel
	Vector3.new(0, 1.55, 0), -- frame
	Vector3.new(0, 3.05, 0.25), -- torso
	Vector3.new(0, 4.3, -0.05), -- head
	Vector3.new(-0.35, 1.9, 0.05), -- leg
	Vector3.new(0.35, 1.9, 0.05), -- leg
}

local function buildBike(parent: Instance, color: Color3): { BasePart }
	local front = wheel("WheelF", BIKE_WHEEL_RADIUS, 0.15, parent)
	local rear = wheel("WheelR", BIKE_WHEEL_RADIUS, 0.15, parent)
	local frame = part("Frame", Vector3.new(0.18, 0.25, 2.7), color, false, parent)
	local torso = part("Rider", Vector3.new(1.3, 1.7, 0.7), PALETTE[math.random(1, #PALETTE)], false, parent)
	local head = part("Head", Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(200, 160, 120), false, parent)
	head.Shape = Enum.PartType.Ball
	local legL = part("LegL", Vector3.new(0.45, 1.5, 0.45), Color3.fromRGB(40, 44, 60), false, parent)
	local legR = part("LegR", Vector3.new(0.45, 1.5, 0.45), Color3.fromRGB(40, 44, 60), false, parent)
	return { front, rear, frame, torso, head, legL, legR }
end

-- ------------------------------------------------------------------ spawn / despawn

local function spawnCar(roadIndex: number, distance: number, direction: number)
	local road = TownLayout.ROADS[roadIndex]
	local quiet = road.kind == "residential"
	local isBike = quiet and math.random(1, BIKE_EVERY) == 1
	local isBus = not isBike and math.random(1, BUS_EVERY) == 1
	local color = if isBike then BIKE_COLOURS[math.random(1, #BIKE_COLOURS)] else PALETTE[math.random(1, #PALETTE)]

	local model = Instance.new("Model")
	model.Name = if isBike then "Bike" elseif isBus then "Bus" else "Car"
	model.Parent = root

	local parts = if isBike then buildBike(model, color) elseif isBus then buildBus(model, color) else buildCar(model, color)

	local car: Car = {
		model = model,
		parts = parts,
		isBus = isBus,
		isBike = isBike,
		roadIndex = roadIndex,
		direction = direction,
		distance = distance,
		length = TrafficMath.polylineLength(road.points),
		kind = road.kind,
		jitter = 1 + (math.random() * 2 - 1) * SPEED_JITTER,
		speed = 0,
		lastPos = Vector3.zero,
		dwell = 0,
		gaveWay = false,
		lastStop = nil,
	}
	table.insert(cars, car)
end

local function despawnCarAt(index: number)
	local car = table.remove(cars, index)
	if car then
		car.model:Destroy()
	end
end

-- Finds one road point that is currently far enough from the camera to be
-- unobtrusive but close enough to soon come into view. Returns nil (three
-- times, so the call site's tuple arity is stable) if nothing qualifies in
-- a bounded number of tries -- including when there are no roads at all.
-- X36: TerraceStreetDresser parks cars on both kerbs of the streets it lists in
-- the TerraceStreets folder's "ParkedStreets" attribute; one lane each way
-- would drive through them, so traffic keeps off those streets.
local function parkedStreets(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local town = workspace:FindFirstChild("Town")
	local folder = town and town:FindFirstChild("TerraceStreets")
	local list = folder and folder:GetAttribute("ParkedStreets")
	if type(list) == "string" then
		for name in list:gmatch("[^|]+") do
			out[name] = true
		end
	end
	return out
end

local function randomSpawnCandidate(camPos: Vector3): (number?, number?, number?)
	local roads = TownLayout.ROADS
	if #roads == 0 then
		return nil, nil, nil
	end
	local parked = parkedStreets()
	for _ = 1, SPAWN_ATTEMPTS_PER_RECHECK do
		local roadIndex = math.random(1, #roads)
		local road = roads[roadIndex]
		if #road.points < 2 or parked[road.name] then
			continue
		end
		local length = TrafficMath.polylineLength(road.points)
		if length <= 1 then
			continue
		end
		local distance = math.random() * length
		local point = TrafficMath.pointAt(road.points, distance)
		local dist = flatDistance(point, camPos)
		if dist >= SPAWN_MIN_DIST and dist <= SPAWN_MAX_DIST then
			local direction = if math.random() < 0.5 then 1 else -1
			return roadIndex, distance, direction
		end
	end
	return nil, nil, nil
end

local function recheckSpawns(camPos: Vector3)
	local spawned = 0
	while #cars < maxCars() and spawned < MAX_SPAWNS_PER_RECHECK do
		local roadIndex, distance, direction = randomSpawnCandidate(camPos)
		if not roadIndex then
			break
		end
		spawnCar(roadIndex, distance :: number, direction :: number)
		spawned += 1
	end
end

local function recheckDespawns(camPos: Vector3)
	for i = #cars, 1, -1 do
		local car = cars[i]
		if flatDistance(car.lastPos, camPos) > DESPAWN_DIST then
			despawnCarAt(i)
		end
	end
	-- quality dropped to Low: shed the newest cars over the budget
	local limit = maxCars()
	while #cars > limit do
		despawnCarAt(#cars)
	end
end

-- ------------------------------------------------------------------ minimum gap

-- Slows a car towards (never below 0) the speed of the car ahead of it on
-- the same road and travelling the same direction, once the gap between
-- them drops under MIN_GAP. Assumes `car.speed` already holds each car's
-- free-flow speed for this frame.
local function applyLeaderGaps()
	local groups: { [string]: { Car } } = {}
	for _, car in cars do
		if car.isBike then
			continue -- cars pass cyclists; bikes don't hold up the queue
		end
		local key = car.roadIndex .. "|" .. car.direction
		local list = groups[key]
		if not list then
			list = {}
			groups[key] = list
		end
		table.insert(list, car)
	end

	for _, list in groups do
		-- Ascending distance-along for forward travel, descending for
		-- backward travel: either way, list[i + 1] is the car ahead of
		-- list[i] in its direction of travel.
		table.sort(list, function(a, b)
			if a.direction == 1 then
				return a.distance < b.distance
			end
			return a.distance > b.distance
		end)
		-- Walk from the front backwards so a follower always sees its
		-- leader's already-finalised speed for this frame.
		for i = #list - 1, 1, -1 do
			local follower, leader = list[i], list[i + 1]
			local gap = math.abs(leader.distance - follower.distance)
			if gap < MIN_GAP then
				local ratio = math.clamp(gap / MIN_GAP, 0, 1)
				follower.speed = math.min(follower.speed, leader.speed * ratio)
			end
		end
	end
end

-- ------------------------------------------------------------------ bus stops

local stopPositions: { Vector3 } = {}
for _, stop in TownLayout.BUS_STOPS do
	table.insert(stopPositions, stop.position)
end
local stopsByRoad: { [number]: { number } } = {}
local function stopsOn(roadIndex: number): { number }
	local cached = stopsByRoad[roadIndex]
	if not cached then
		cached = TrafficMath.stopDistances(TownLayout.ROADS[roadIndex].points, stopPositions, BUS_STOP_REACH)
		stopsByRoad[roadIndex] = cached
	end
	return cached
end

-- ------------------------------------------------------------------ movement

local function switchRoad(car: Car, connection: TrafficMath.Connection, leftover: number)
	local road = TownLayout.ROADS[connection.roadIndex]
	car.roadIndex = connection.roadIndex
	car.direction = connection.direction
	car.kind = road.kind
	car.length = TrafficMath.polylineLength(road.points)
	car.distance = math.clamp(connection.distance + connection.direction * leftover, 0, car.length)
	car.lastStop = nil
	car.gaveWay = false
end

-- X88: is another vehicle (not on this car's road) near the end this car is reaching?
local function junctionBusy(car: Car, road: TownLayout.Road): boolean
	local endPoint = if car.direction == 1 then road.points[#road.points] else road.points[1]
	local others = {}
	for _, other in cars do
		if other ~= car and other.roadIndex ~= car.roadIndex then
			table.insert(others, other.lastPos)
		end
	end
	return TrafficMath.junctionBusy(endPoint, others, GIVE_WAY_CLEAR)
end

local function moveCar(car: Car, dt: number)
	local road = TownLayout.ROADS[car.roadIndex]
	if not road then
		return
	end

	if car.dwell > 0 then
		car.dwell -= dt
		car.speed = 0
	end
	local newDistance = car.distance + car.direction * car.speed * dt
	if car.isBus and car.speed > 0 then
		local stop = TrafficMath.passedStop(car.distance, newDistance, stopsOn(car.roadIndex))
		if stop and stop ~= car.lastStop then
			newDistance = stop
			car.dwell = BUS_STOP_DWELL
			car.lastStop = stop
		end
	end
	if TrafficMath.isClosed(road.points, 1e-3) then
		local length = math.max(car.length, 1e-6)
		car.distance = newDistance % length
	elseif (newDistance > car.length or newDistance < 0) and not car.gaveWay and junctionBusy(car, road) then
		-- X88: give way once at the junction mouth while another vehicle is crossing it
		car.gaveWay = true
		car.distance = math.clamp(newDistance, 0, car.length)
		car.dwell = GIVE_WAY_WAIT
	elseif newDistance > car.length or newDistance < 0 then
		local atEnd = car.direction == 1
		local overshoot = if atEnd then newDistance - car.length else -newDistance
		local tolerance = road.width / 2 + JOIN_TOLERANCE_EXTRA
		local options = TrafficMath.connections(TownLayout.ROADS, car.roadIndex, atEnd, tolerance)
		local parked = parkedStreets()
		for i = #options, 1, -1 do
			if parked[TownLayout.ROADS[options[i].roadIndex].name] then
				table.remove(options, i)
			end
		end
		if #options > 0 then
			switchRoad(car, options[math.random(1, #options)], overshoot)
		else
			-- Dead end: U-turn in place rather than driving off the road.
			car.direction = -car.direction
			car.distance = math.clamp(newDistance, 0, car.length)
		end
	else
		car.distance = newDistance
	end

	local currentRoad = TownLayout.ROADS[car.roadIndex]
	local point, direction = TrafficMath.pointAt(currentRoad.points, car.distance)
	local flatPos = point
		+ (if car.isBike
			then TrafficMath.kerbOffset(direction, currentRoad.width, BIKE_KERB_INSET)
			else TrafficMath.laneOffset(direction, currentRoad.width, -1))
	-- X79: round roundabout islands, not over them
	flatPos, direction = TrafficMath.aroundIslands(flatPos, direction, TownLayout.ROUNDABOUTS, if car.isBus then ISLAND_CLEAR_BUS else ISLAND_CLEAR)
	car.lastPos = flatPos

	local y = bridgeDeckY(flatPos, car.kind) or roadTopFor(car.kind)
	local yaw = math.atan2(-direction.X, -direction.Z)
	local rootCFrame = CFrame.new(flatPos.X, y, flatPos.Z) * CFrame.Angles(0, yaw, 0)

	local offsets = if car.isBike then BIKE_OFFSETS elseif car.isBus then BUS_OFFSETS else CAR_OFFSETS
	local parts = car.parts
	for i = 1, #parts do
		table.insert(moveParts, parts[i])
		table.insert(moveCFrames, rootCFrame * CFrame.new(offsets[i]))
	end
end

-- ------------------------------------------------------------------ main loop

RunService.RenderStepped:Connect(function(dt: number)
	recheckTimer += dt
	local doRecheck = recheckTimer >= RECHECK_INTERVAL
	if doRecheck then
		recheckTimer = 0
	end

	if doRecheck then
		local camPos = currentCameraPosition()
		recheckDespawns(camPos)
		recheckSpawns(camPos)
	end

	for _, car in cars do
		-- a bus dwelling at a stop counts as stopped before the leader-gap pass,
		-- so the cars behind it queue instead of driving through it
		car.speed = if car.dwell > 0 then 0
			elseif car.isBike then BIKE_SPEED * car.jitter
			else (SPEED_BY_KIND[car.kind] or SPEED_BY_KIND.lane) * car.jitter
	end
	applyLeaderGaps()

	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, car in cars do
		moveCar(car, dt)
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
