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
-- lane. Cars follow RoadPaths.townRoads() (the layout with its corners rounded
-- to the kit bends), not the raw TownLayout polylines, and sit on the kit
-- carriageway's own top (RoadTiles.roadTop).
--
-- The place streams: a road only exists on this client near the streaming
-- focus (the character, or Player.ReplicationFocus during the plot picker).
-- Cars spawn round that focus, only where a road tile is really there, and are
-- removed when the ground under them streams out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TrafficMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrafficMath"))
local RoadTiles = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoadTiles"))
local RoadPaths = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoadPaths"))
local CarWheels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarWheels"))
local Townsfolk = require(script.Parent:WaitForChild("Townsfolk"))

-- ------------------------------------------------------------------ tuning

-- TEMP: 16, down from 24. StreetFurniture parks cars in the driving lane of 53 of
-- the 94 streets, so traffic keeps off them and 24 cars bunched on what was left.
local MAX_CARS = 16 -- mobile budget; raise/lower this alone to retune the pool
local MAX_CARS_LOW = 6 -- TEMP, Quality "Low"

-- C3.2: QualityController publishes "High" | "Low" on the LocalPlayer.
-- X92 (roadmap G1 "extra traffic"): a ground with a crowd arriving or a match
-- on within MATCHDAY_RADIUS of the camera adds MATCHDAY_EXTRA cars (TEMP).
local MATCHDAY_EXTRA = 8
local MATCHDAY_EXTRA_LOW = 3
local MATCHDAY_RADIUS = 900
local function nearLiveGround(): boolean
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local camera = workspace.CurrentCamera
	if not (clubs and camera) then
		return false
	end
	local p = camera.CFrame.Position
	for _, folder in clubs:GetChildren() do
		local phase = folder:GetAttribute("Phase")
		local cf = folder:GetAttribute("PlotCFrame")
		if (phase == "PreMatch" or phase == "Match") and typeof(cf) == "CFrame" then
			if Vector3.new(cf.X - p.X, 0, cf.Z - p.Z).Magnitude <= MATCHDAY_RADIUS then
				return true
			end
		end
	end
	return false
end

local function maxCars(): number
	local player = game:GetService("Players").LocalPlayer
	local low = player and player:GetAttribute("Quality") == "Low"
	local base = if low then MAX_CARS_LOW else MAX_CARS
	if nearLiveGround() then
		base += if low then MATCHDAY_EXTRA_LOW else MATCHDAY_EXTRA
	end
	return base
end
local BUS_EVERY = 8 -- 1 in 8 spawns is a bus
-- F2.2: buses pull up at the TownLayout bus stops on their road
local BUS_STOP_DWELL = 4 -- TEMP seconds stopped
local BUS_STOP_REACH = 40 -- a stop this close to the road centreline serves it (the Station stop is 36 out)
-- F3.3 cyclists: on residential streets only (lanes are too narrow to pass), by the kerb.
-- A lane is 7.9 wide and a car 6.9, so there is no room to pass: cars queue behind a cyclist.
local BIKE_EVERY = 8 -- TEMP: 1 in 8 spawns on a quiet street is a bike
local BIKE_SPEED = 14 -- TEMP studs/s (walkers 5 to 7, cars 20 on the same street)
local BIKE_KERB_INSET = 1.6 -- rider (1.3 wide) clears a car in the lane on a 20-wide residential street
-- Roundabouts: a car leaves its road for the ring (TrafficMath.ringArms) and drives the arc.
local RING_SPEED = 16 -- TEMP studs/s on the ring
local RING_SLOW_ZONE = 50 -- eases down to RING_SPEED over this much road before an arm, and back up after
local RING_BLEND = 8 -- studs of arc to swing from the road's heading onto the ring's, and off again
local RING_GIVE_WAY = 24 -- a car on the ring this many studs of arc upstream makes an entering car wait
local RING_WAIT = 0.3 -- seconds between looks while it waits
local BIKE_COLOURS = { Color3.fromRGB(40, 90, 170), Color3.fromRGB(190, 40, 40), Color3.fromRGB(30, 30, 34), Color3.fromRGB(220, 200, 60) }
local SPAWN_MIN_DIST = 150
local SPAWN_MAX_DIST = 700
local DESPAWN_DIST = 800
local RECHECK_INTERVAL = 1 -- seconds between spawn/despawn passes
local SPAWN_ATTEMPTS_PER_RECHECK = 40
local MAX_SPAWNS_PER_RECHECK = 4
local FOLLOW_CLEAR = 8 -- studs of daylight kept behind the vehicle ahead, same road + direction
local SPAWN_CLEAR = 40 -- no vehicle spawns this close to another
local LANDING_WAIT = 0.4 -- seconds a car holds at a junction while its place on the next road is taken
local TURN_TIME = 0.9 -- seconds a car takes to swing onto its new line at a junction or a dead end
local JOIN_TOLERANCE_EXTRA = 45 -- added to (own road width / 2) when hunting for the next road
local GIVE_WAY_CLEAR = 22 -- X88: another vehicle this close to the junction makes a car wait (TEMP)
local GIVE_WAY_WAIT = 1.4 -- seconds, once per junction
local SPEED_JITTER = 0.05 -- +/- fraction of a kind's base speed, per car (nobody can overtake, so more made platoons)

local SPEED_BY_KIND: { [TownLayout.RoadKind]: number } = { ring = 40, main = 32, residential = 20, lane = 14 }
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

-- Order matches buildBus's part list: Body, Windows, WheelF1, WheelF2, WheelR1, WheelR2, Destination, Windscreen.
local BUS_OFFSETS: { Vector3 } = {
	Vector3.new(0, BUS_BODY_Y, 0),
	Vector3.new(0, BUS_WINDOW_Y, 0),
	Vector3.new(-BUS_TRACK_X, BUS_WHEEL_Y, -BUS_AXLE_Z),
	Vector3.new(BUS_TRACK_X, BUS_WHEEL_Y, -BUS_AXLE_Z),
	Vector3.new(-BUS_TRACK_X, BUS_WHEEL_Y, BUS_AXLE_Z),
	Vector3.new(BUS_TRACK_X, BUS_WHEEL_Y, BUS_AXLE_Z),
	-- X118: destination board on the front, above the windscreen
	Vector3.new(0, BUS_BODY_Y + BUS_BODY_SIZE.Y / 2 - 0.35, -BUS_BODY_SIZE.Z / 2 - 0.06),
	-- windscreen under it (the side window band stops short of the front)
	Vector3.new(0, BUS_WINDOW_Y - 0.2, -BUS_BODY_SIZE.Z / 2 - 0.05),
}
-- X118 (RivermereCenter.png's "2 Town Centre" bus): TEMP route boards
local BUS_DESTINATIONS = { "21  TOWN CENTRE", "7  STATION", "12  RIVERSIDE", "23  NORTHFIELDS", "24  WESTDALE" }

-- ------------------------------------------------------------------ types

type Ring = { centre: Vector3, radius: number, top: number?, arms: { TrafficMath.RingArm } }
type RingRun = {
	ring: Ring,
	from: number, -- angle it joined at
	arc: number, -- studs of ring to drive
	travelled: number,
	inbound: Vector3, -- its heading as it arrived
	leave: TrafficMath.RingArm,
}

-- A cyclist. `parts` is the bike (kit mesh parts, or the primitive wheels and
-- frame) with `offsets` from the root; the rider's six limbs are posed each frame.
type BikeRig = {
	fig: Townsfolk.Figure,
	parts: { BasePart },
	offsets: { CFrame },
	pedal: number, -- crank angle, radians
	clock: number, -- os.clock() of the last draw
}

type Car = {
	ring: RingRun?, -- on a roundabout's ring, off its road
	model: Model,
	parts: { BasePart },
	meshOffsets: { Vector3 }?, -- X128: a kit mesh car's single offset (replaces CAR_OFFSETS)
	meshYaw: number, -- X128: turn so the kit mesh's front faces the root's -Z
	wheels: { CarWheels.Wheel }?, -- a kit car's turning wheels, laid over the ones baked into its mesh
	rolled: number, -- studs driven, for the wheels' turn
	isBus: boolean,
	isBike: boolean,
	bike: BikeRig?, -- a cyclist: the rider is posed and pedals (drawBike), not moved by fixed offsets
	roadIndex: number,
	direction: number, -- 1 or -1 along the road's polyline
	distance: number, -- studs along the current road
	length: number, -- cached TrafficMath.polylineLength of the current road
	kind: TownLayout.RoadKind,
	jitter: number, -- per-car multiplier on its kind's base speed
	speed: number, -- this frame's effective speed (after the leader check)
	lastPos: Vector3, -- last computed world XZ position (Y = road/deck top), for despawn checks
	halfLength: number, -- half the vehicle's length, for the follow gap
	shown: CFrame?, -- the root CFrame drawn last frame
	turnFrom: CFrame?, -- swinging from this CFrame onto its new line (junction, dead end)...
	turnT: number, -- ...this far through, 0..1
	dwell: number, -- seconds left stopped at a bus stop
	lastStop: number?, -- distance of the stop it last pulled up at on this road (not twice in a row)
	gaveWay: boolean, -- X88: already waited at the end of this road
}

-- ------------------------------------------------------------------ state

local root = Instance.new("Folder")
root.Name = "Traffic"
root.Parent = workspace

-- ROADS with the corners rounded to the kit bends; same indices
local ROADS = RoadPaths.townRoads()

-- One ring per roundabout, with the arms where roads cross it; and per road, its
-- rings (to find an arm reached) and its arms' distances (to slow on the approach).
local ringsByRoad: { [number]: { Ring } } = {}
local armDistancesByRoad: { [number]: { number } } = {}
-- per road, where each big roundabout's asphalt ramp is: { arm distance, gap from the
-- arm to the ramp's top, gap to its foot, the disc's top }
local rampsByRoad: { [number]: { { number } } } = {}
for _, rb in TownLayout.ROUNDABOUTS do
	local radius = RoadTiles.ringRadius(rb.radius)
	local arms = TrafficMath.ringArms(ROADS, rb.centre, radius, function(roadIndex: number): number
		return RoadTiles.carriagewayWidth(ROADS[roadIndex].kind) / 4
	end)
	local ring: Ring = { centre = rb.centre, radius = radius, top = RoadTiles.ringTop(rb.radius), arms = arms }
	for _, arm in arms do
		local rings = ringsByRoad[arm.roadIndex] or {}
		ringsByRoad[arm.roadIndex] = rings
		if not table.find(rings, ring) then
			table.insert(rings, ring)
		end
		local distances = armDistancesByRoad[arm.roadIndex] or {}
		armDistancesByRoad[arm.roadIndex] = distances
		table.insert(distances, arm.distance)
		if ring.top then
			local ramps = rampsByRoad[arm.roadIndex] or {}
			rampsByRoad[arm.roadIndex] = ramps
			local topGap = rb.radius - RoadTiles.RB_RAMP_INSIDE - radius
			table.insert(ramps, { arm.distance, topGap, topGap + RoadTiles.RB_RAMP, ring.top })
		end
	end
end

-- How far above its road's top a car rides at `distance`: up the asphalt ramp and
-- onto the disc of a big roundabout it is coming to, or has just left.
local function rampLift(roadIndex: number, distance: number, roadTop: number): number
	for _, ramp in rampsByRoad[roadIndex] or {} do
		local gap = math.abs(distance - ramp[1])
		if gap < ramp[3] then
			return (ramp[4] - roadTop) * math.clamp((ramp[3] - gap) / (ramp[3] - ramp[2]), 0, 1)
		end
	end
	return 0
end

-- Road distance from a car to the nearest roundabout arm on its road.
local function gapToArm(roadIndex: number, distance: number): number
	local best = math.huge
	for _, d in armDistancesByRoad[roadIndex] or {} do
		best = math.min(best, math.abs(d - distance))
	end
	return best
end

local function insideRoundabout(point: Vector3): boolean
	for _, rb in TownLayout.ROUNDABOUTS do
		if Vector3.new(point.X - rb.centre.X, 0, point.Z - rb.centre.Z).Magnitude <= rb.radius then
			return true
		end
	end
	return false
end

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
	return RoadTiles.roadTop(kind)
end

-- Where the world is streamed in round: the server's ReplicationFocus (plot
-- picker), else the character, else the camera.
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

-- What of the town is streamed in under `point`: "road" for a kit road tile,
-- "other" for anything else in the town (a bridge deck), nil for nothing.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(point: Vector3): string?
	local town = workspace:FindFirstChild("Town")
	if not town then
		return nil
	end
	groundParams.FilterDescendantsInstances = { town }
	local hit = workspace:Raycast(Vector3.new(point.X, 60, point.Z), Vector3.new(0, -120, 0), groundParams)
	if not hit then
		return nil
	end
	local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
	while model do
		if model.Name:sub(1, #RoadTiles.PREFIX) == RoadTiles.PREFIX then
			return "road"
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return "other"
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
	local board = part("Destination", Vector3.new(3.4, 0.55, 0.12), Color3.fromRGB(12, 12, 14), false, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.9)
	label.Position = UDim2.fromScale(0.03, 0.05)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 170, 30)
	label.Text = BUS_DESTINATIONS[math.random(1, #BUS_DESTINATIONS)]
	label.Parent = gui
	local windscreen = part("Windscreen", Vector3.new(3.8, 1.1, 0.1), BUS_WINDOW_COLOR, false, parent)
	return { body, windows, wheelF1, wheelF2, wheelR1, wheelR2, board, windscreen }
end

-- The primitive bike, used only when ClientKit has no Bicycle: 2 wheels and a frame.
-- X371: the rider is a real R6 figure (Townsfolk), 5 studs like everyone in town,
-- sat on a saddle 2.4 up and posed by drawBike.
local BIKE_WHEEL_RADIUS = 1.05
local BIKE_SADDLE_Y = 2.4
local BIKE_OFFSETS: { Vector3 } = {
	Vector3.new(0, 0.1 + BIKE_WHEEL_RADIUS, -1.35), -- front wheel
	Vector3.new(0, 0.1 + BIKE_WHEEL_RADIUS, 1.35), -- rear wheel
	Vector3.new(0, 1.55, 0), -- frame
}

-- The rider on the saddle, in root space (root -Z is the way the bike is going).
-- An R6 leg is one piece, so pedalling is each leg swinging forward and back from
-- the hip, half a turn apart, between nearly straight down and well forward.
-- The numbers fit the kit bicycle (tools/kit/install_bicycle.luau: saddle 2.43 up and
-- 0.77 behind the pivot, grips 2.8 up and 0.9 ahead, bottom bracket 0.83 up and 0.29
-- behind, cranks about 0.45): the hip-to-bracket line is 33 degrees forward of straight
-- down and a leg's length long, and a crank's throw either side of it is 14 degrees.
local BIKE_HIP = Vector3.new(0, BIKE_SADDLE_Y + 0.05, 0.77)
local BIKE_LEAN = math.rad(32) -- torso tipped forward to the bars
local BIKE_ARM_REACH = math.rad(60) -- arms forward of the (leant) torso, hands to the grips
local BIKE_LEG_MID, BIKE_LEG_SWING = math.rad(33), math.rad(14)
local BIKE_CRANK_PER_STUD = 0.55 -- radians of crank per stud travelled (one turn every ~11 studs)

local function kitBikeTemplate(): Instance?
	local clientKit = ReplicatedStorage:FindFirstChild("ClientKit")
	return clientKit and clientKit:FindFirstChild("Bicycle")
end

-- Returns nil when the shared rig is unavailable: a bike with no rider would
-- read worse than no bike, so the caller skips the spawn.
local function buildBike(parent: Instance, color: Color3): BikeRig?
	local fig = Townsfolk.build(parent)
	if not fig then
		return nil
	end
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local kitBike = kitBikeTemplate()
	if kitBike and kitBike:IsA("Model") then
		-- ClientKit.Bicycle: pivot on the ground under the bottom bracket, front wheel to -Z
		local copy = kitBike:Clone()
		local pivot = copy:GetPivot()
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Body" then
					d.Color = color -- the frame
				end
				table.insert(parts, d)
				table.insert(offsets, CFrame.new(0, 0.05, 0) * pivot:ToObjectSpace(d.CFrame))
			end
		end
		copy.Parent = parent
	else
		parts = { wheel("WheelF", BIKE_WHEEL_RADIUS, 0.15, parent), wheel("WheelR", BIKE_WHEEL_RADIUS, 0.15, parent),
			part("Frame", Vector3.new(0.18, 0.25, 2.7), color, false, parent) }
		for i = 1, 3 do
			offsets[i] = CFrame.new(BIKE_OFFSETS[i])
		end
	end
	return { fig = fig, parts = parts, offsets = offsets, pedal = math.random() * 2 * math.pi, clock = os.clock() }
end

-- X128: kit hatchbacks published by the server's ClientKit, if any, at the
-- town's one car size (parked cars use the same number).
local KIT_CAR_SCALE = RoadTiles.CAR_SCALE
local function kitCarTemplates(): { Instance }
	local clientKit = ReplicatedStorage:FindFirstChild("ClientKit")
	local cars = clientKit and clientKit:FindFirstChild("Cars")
	return if cars then cars:GetChildren() else {}
end

-- X372: the double-decker from ClientKit. Stored at real-bus size it is 8.3
-- wide, wider than a 7.9 lane, so it is drawn at RoadTiles.BUS_SCALE: still
-- over ten studs tall beside a 5-stud townsperson.
local function kitBusTemplate(): Instance?
	local clientKit = ReplicatedStorage:FindFirstChild("ClientKit")
	return clientKit and clientKit:FindFirstChild("Bus")
end

-- ------------------------------------------------------------------ spawn / despawn

local function spawnCar(roadIndex: number, distance: number, direction: number)
	local road = ROADS[roadIndex]
	local quiet = road.kind == "residential"
	local isBike = quiet and math.random(1, BIKE_EVERY) == 1
	local isBus = not isBike and math.random(1, BUS_EVERY) == 1
	local color = if isBike then BIKE_COLOURS[math.random(1, #BIKE_COLOURS)] else PALETTE[math.random(1, #PALETTE)]

	local model = Instance.new("Model")
	model.Name = if isBike then "Bike" elseif isBus then "Bus" else "Car"
	model.Parent = root

	local parts: { BasePart }
	local meshOffsets: { Vector3 }? = nil
	local meshYaw = 0
	local bike: BikeRig? = nil
	local wheels: { CarWheels.Wheel }? = nil
	local kitCars = kitCarTemplates()
	local kitBus = if isBus then kitBusTemplate() else nil
	if kitBus then
		local mesh = (kitBus:FindFirstChildWhichIsA("BasePart", true) :: BasePart):Clone()
		mesh.Size *= RoadTiles.BUS_SCALE
		mesh.CastShadow = true
		mesh.Parent = model
		parts = { mesh }
		meshOffsets = { Vector3.new(0, mesh.Size.Y / 2 + 0.05, 0) }
		local yaw = kitBus:GetAttribute("FrontYaw")
		meshYaw = if type(yaw) == "number" then yaw else 0
	elseif not isBike and not isBus and #kitCars > 0 then
		-- X128: one of the town's hatchback meshes (ClientKit.Cars; pivot Z is
		-- the length, -Z the front, like the root), scaled to traffic size
		local template = kitCars[math.random(1, #kitCars)]
		local mesh = (template:FindFirstChildWhichIsA("BasePart", true) :: BasePart):Clone()
		mesh.Size *= KIT_CAR_SCALE
		mesh.CastShadow = true
		mesh.Parent = model
		parts = { mesh }
		meshOffsets = { Vector3.new(0, mesh.Size.Y / 2 + 0.05, 0) }
		local yaw = template:GetAttribute("FrontYaw")
		meshYaw = if type(yaw) == "number" then yaw else 0
		local clientKit = ReplicatedStorage:FindFirstChild("ClientKit")
		local face = clientKit and clientKit:FindFirstChild("WheelFace")
		wheels = CarWheels.build(mesh, template.Name, if face and face:IsA("BasePart") then face else nil, model)
	elseif isBike then
		-- X371: buildBike needs the shared rig for its rider and returns nil
		-- without it; a riderless bike would look worse than no bike at all
		bike = buildBike(model, color)
		if not bike then
			model:Destroy()
			return
		end
		parts = bike.parts
	else
		parts = if isBus then buildBus(model, color) else buildCar(model, color)
	end

	-- a kit mesh's length is its longer side (FrontYaw only ever turns it half round)
	local halfLength = if meshOffsets then math.max(parts[1].Size.X, parts[1].Size.Z) / 2
		elseif isBike then 2.4
		elseif isBus then BUS_BODY_SIZE.Z / 2
		else BODY_SIZE.Z / 2

	local car: Car = {
		ring = nil,
		model = model,
		parts = parts,
		meshOffsets = meshOffsets,
		meshYaw = meshYaw,
		wheels = wheels,
		rolled = 0,
		isBus = isBus,
		isBike = isBike,
		bike = bike,
		roadIndex = roadIndex,
		direction = direction,
		distance = distance,
		length = TrafficMath.polylineLength(road.points),
		kind = road.kind,
		jitter = 1 + (math.random() * 2 - 1) * SPEED_JITTER,
		speed = 0,
		-- the real spot, not zero: the next spawn this pass checks its distance to it
		lastPos = TrafficMath.pointAt(road.points, distance),
		halfLength = halfLength,
		shown = nil,
		turnFrom = nil,
		turnT = 0,
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
	-- v3: StreetFurniture parks the cars now and publishes the same attribute on its holder
	for _, folderName in { "TerraceStreets", "V3Furniture" } do
		local folder = town and town:FindFirstChild(folderName)
		local list = folder and folder:GetAttribute("ParkedStreets")
		if type(list) == "string" then
			for name in list:gmatch("[^|]+") do
				out[name] = true
			end
		end
	end
	return out
end

-- Roads traffic may use, with the running sum of their lengths so a spawn lands
-- on a road in proportion to its length. (Picking by index gave a 120-stud
-- close the same share of the cars as the 8,400-stud ring road.) Rebuilt when
-- the list of parked streets changes.
local eligibleKey: string? = nil
local eligibleRoads: { number } = {}
local eligibleCumulative: { number } = {}
local function refreshEligible(parked: { [string]: boolean })
	local names = {}
	for name in parked do
		table.insert(names, name)
	end
	table.sort(names)
	local key = table.concat(names, "|")
	if key == eligibleKey then
		return
	end
	eligibleKey = key
	table.clear(eligibleRoads)
	table.clear(eligibleCumulative)
	local total = 0
	for roadIndex, road in ROADS do
		if #road.points < 2 or parked[road.name] or road.kind == "alley" then
			continue
		end
		local length = TrafficMath.polylineLength(road.points)
		if length > 1 then
			total += length
			table.insert(eligibleRoads, roadIndex)
			table.insert(eligibleCumulative, total)
		end
	end
end

local function randomSpawnCandidate(focus: Vector3): (number?, number?, number?)
	refreshEligible(parkedStreets())
	local taken = {}
	for _, car in cars do
		table.insert(taken, car.lastPos)
	end
	for _ = 1, SPAWN_ATTEMPTS_PER_RECHECK do
		local pick = TrafficMath.weightedIndex(eligibleCumulative, math.random())
		if not pick then
			return nil, nil, nil
		end
		local roadIndex = eligibleRoads[pick]
		local road = ROADS[roadIndex]
		local distance = math.random() * TrafficMath.polylineLength(road.points)
		local point = TrafficMath.pointAt(road.points, distance)
		local dist = flatDistance(point, focus)
		if dist < SPAWN_MIN_DIST or dist > SPAWN_MAX_DIST or insideRoundabout(point) then
			continue
		end
		-- room for it, and a road really streamed in under it
		if TrafficMath.crowded(point, taken, SPAWN_CLEAR) or groundAt(point) ~= "road" then
			continue
		end
		local direction = if math.random() < 0.5 then 1 else -1
		return roadIndex, distance, direction
	end
	return nil, nil, nil
end

local function recheckSpawns(focus: Vector3)
	local spawned = 0
	while #cars < maxCars() and spawned < MAX_SPAWNS_PER_RECHECK do
		local roadIndex, distance, direction = randomSpawnCandidate(focus)
		if not roadIndex then
			break
		end
		spawnCar(roadIndex, distance :: number, direction :: number)
		spawned += 1
	end
end

local function recheckDespawns(focus: Vector3)
	for i = #cars, 1, -1 do
		local car = cars[i]
		-- too far, or the town under it has streamed out (it would drive over bare terrain)
		if flatDistance(car.lastPos, focus) > DESPAWN_DIST or groundAt(car.lastPos) == nil then
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

-- Slows a vehicle towards the speed of the one ahead of it on the same road and
-- travelling the same direction (TrafficMath.followSpeed), keeping FOLLOW_CLEAR
-- studs of daylight between them whatever their lengths. Bikes count: a lane is
-- too narrow to pass one. On a closed road the front vehicle follows the back
-- one across the seam. Assumes `car.speed` already holds each car's free-flow
-- speed for this frame.
local function ringAngle(run: RingRun): number
	return run.from + run.travelled / run.ring.radius
end

local function applyLeaderGaps()
	local groups: { [string]: { Car } } = {}
	for _, car in cars do
		if car.ring then
			continue
		end
		local key = car.roadIndex .. "|" .. car.direction
		local list = groups[key]
		if not list then
			list = {}
			groups[key] = list
		end
		table.insert(list, car)
	end

	local function follow(follower: Car, leader: Car, gap: number)
		local minGap = TrafficMath.followGap(leader.halfLength, follower.halfLength, FOLLOW_CLEAR)
		follower.speed = TrafficMath.followSpeed(follower.speed, leader.speed, gap, minGap)
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
			follow(list[i], list[i + 1], math.abs(list[i + 1].distance - list[i].distance))
		end
		local front, back = list[#list], list[1]
		if #list > 1 and TrafficMath.isClosed(ROADS[front.roadIndex].points, 1e-3) then
			follow(front, back, front.length - math.abs(front.distance - back.distance))
		end
	end

	-- on a ring: behind the nearest car ahead (the way traffic circulates) on the same ring
	for _, car in cars do
		local run = car.ring
		if run then
			local leader: Car? = nil
			local leaderGap = math.huge
			for _, other in cars do
				local otherRun = other.ring
				if other ~= car and otherRun and otherRun.ring == run.ring then
					local gap = ((ringAngle(otherRun) - ringAngle(run)) % (2 * math.pi)) * run.ring.radius
					if gap < leaderGap then
						leader, leaderGap = other, gap
					end
				end
			end
			if leader then
				follow(car, leader, leaderGap)
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
		cached = TrafficMath.stopDistances(ROADS[roadIndex].points, stopPositions, BUS_STOP_REACH)
		stopsByRoad[roadIndex] = cached
	end
	return cached
end

-- ------------------------------------------------------------------ movement

local function switchRoad(car: Car, connection: TrafficMath.Connection, leftover: number)
	local road = ROADS[connection.roadIndex]
	car.roadIndex = connection.roadIndex
	car.direction = connection.direction
	car.kind = road.kind
	car.length = TrafficMath.polylineLength(road.points)
	car.distance = math.clamp(connection.distance + connection.direction * leftover, 0, car.length)
	car.lastStop = nil
	car.gaveWay = false
	-- swing onto the new line instead of snapping to it
	car.turnFrom = car.shown
	car.turnT = 0
end

-- Is the spot a car would land on (joining `connection`) already taken by a
-- vehicle going the same way on that road?
local function landingTaken(car: Car, connection: TrafficMath.Connection): boolean
	for _, other in cars do
		if other ~= car and other.roadIndex == connection.roadIndex and other.direction == connection.direction then
			local need = TrafficMath.followGap(other.halfLength, car.halfLength, FOLLOW_CLEAR)
			if math.abs(other.distance - connection.distance) < need then
				return true
			end
		end
	end
	return false
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

-- A cyclist: the bike at its offsets, the rider leant to the bars with the legs
-- going round as fast as the bike is moving.
local function drawBike(car: Car, bike: BikeRig, rootCFrame: CFrame)
	local now = os.clock()
	bike.pedal += car.speed * math.min(now - bike.clock, 0.1) * BIKE_CRANK_PER_STUD
	bike.clock = now
	for i, p in bike.parts do
		table.insert(moveParts, p)
		table.insert(moveCFrames, rootCFrame * bike.offsets[i])
	end
	local hip = rootCFrame * CFrame.new(BIKE_HIP)
	local back = hip * CFrame.Angles(-BIKE_LEAN, 0, 0)
	local torsoH = Townsfolk.TORSO_SIZE.Y
	local halfLeg, halfArm = Townsfolk.LEG_SIZE.Y / 2, Townsfolk.ARM_SIZE.Y / 2
	local swing = math.sin(bike.pedal) * BIKE_LEG_SWING
	local fig = bike.fig
	local cfs = {
		back * CFrame.new(0, torsoH / 2, 0), -- torso
		back * CFrame.new(0, torsoH + 0.5, 0) * CFrame.Angles(BIKE_LEAN * 0.8, 0, 0), -- head, looking up the road
		-- a positive turn about X swings a hanging limb forward (-Z)
		hip * CFrame.new(-Townsfolk.LEG_X, 0, 0) * CFrame.Angles(BIKE_LEG_MID + swing, 0, 0) * CFrame.new(0, -halfLeg, 0),
		hip * CFrame.new(Townsfolk.LEG_X, 0, 0) * CFrame.Angles(BIKE_LEG_MID - swing, 0, 0) * CFrame.new(0, -halfLeg, 0),
		back * CFrame.new(-Townsfolk.ARM_X, torsoH - 0.1, 0) * CFrame.Angles(BIKE_ARM_REACH, 0, 0) * CFrame.new(0, -halfArm, 0),
		back * CFrame.new(Townsfolk.ARM_X, torsoH - 0.1, 0) * CFrame.Angles(BIKE_ARM_REACH, 0, 0) * CFrame.new(0, -halfArm, 0),
	}
	for i = 1, 6 do
		table.insert(moveParts, fig.all[i])
		table.insert(moveCFrames, cfs[i])
	end
end

-- Queues the car's parts at `rootCFrame` for this frame's BulkMoveTo.
local function draw(car: Car, rootCFrame: CFrame)
	car.shown = rootCFrame
	if car.bike then
		drawBike(car, car.bike, rootCFrame)
		return
	end
	local offsets = if car.meshOffsets then car.meshOffsets elseif car.isBike then BIKE_OFFSETS elseif car.isBus then BUS_OFFSETS else CAR_OFFSETS
	local parts = car.parts
	for i = 1, #parts do
		table.insert(moveParts, parts[i])
		local cf = rootCFrame * CFrame.new(offsets[i])
		table.insert(moveCFrames, if car.meshYaw ~= 0 then cf * CFrame.Angles(0, car.meshYaw, 0) else cf)
	end
	local wheels = car.wheels
	if wheels then
		local meshCFrame = moveCFrames[#moveCFrames]
		-- rolling towards the mesh's -Z is a negative turn about its X; a mesh
		-- turned half round (meshYaw) is driving towards its own +Z
		local way = if car.meshYaw ~= 0 then 1 else -1
		for _, wheel in wheels do
			table.insert(moveParts, wheel.part)
			table.insert(moveCFrames, CarWheels.cframe(wheel, meshCFrame, way * car.rolled / wheel.radius))
		end
	end
end

-- Give way to the ring: is a car on it coming up to this arm's entry, or sitting just past it?
local function ringBusy(car: Car, ring: Ring, arm: TrafficMath.RingArm): boolean
	for _, other in cars do
		local run = other.ring
		if other ~= car and run and run.ring == ring then
			local upstream = ((arm.entryAngle - ringAngle(run)) % (2 * math.pi)) * ring.radius
			local downstream = 2 * math.pi * ring.radius - upstream
			if upstream < RING_GIVE_WAY or downstream < TrafficMath.followGap(other.halfLength, car.halfLength, FOLLOW_CLEAR) then
				return true
			end
		end
	end
	return false
end

-- Leaves the road at `arm` for the ring, bound for a random other arm (any but a
-- parked street or an alley; its own arm only if there is no other).
local function joinRing(car: Car, ring: Ring, arm: TrafficMath.RingArm, leftover: number): RingRun
	local parked = parkedStreets()
	local exits: { TrafficMath.RingArm } = {}
	for _, other in ring.arms do
		local road = ROADS[other.roadIndex]
		if other ~= arm and not parked[road.name] and road.kind ~= "alley" then
			table.insert(exits, other)
		end
	end
	local leave = if #exits > 0 then exits[math.random(1, #exits)] else arm
	local run: RingRun = {
		ring = ring,
		from = arm.entryAngle,
		arc = TrafficMath.ringSweep(arm, leave) * ring.radius,
		travelled = leftover,
		inbound = -arm.heading,
		leave = leave,
	}
	car.ring = run
	car.distance = arm.distance
	return run
end

-- One frame on the ring; at the end of its arc the car is back on a road.
local function driveRing(car: Car, run: RingRun, dt: number)
	run.travelled += car.speed * dt
	if run.travelled >= run.arc then
		local leave = run.leave
		local road = ROADS[leave.roadIndex]
		car.ring = nil
		car.roadIndex = leave.roadIndex
		car.direction = leave.outward
		car.kind = road.kind
		car.length = TrafficMath.polylineLength(road.points)
		car.distance = math.clamp(leave.distance + leave.outward * (run.travelled - run.arc), 0, car.length)
		car.lastStop = nil
		car.gaveWay = false
	end
	local travelled = math.min(run.travelled, run.arc)
	local pos, tangent = TrafficMath.ringPose(run.ring.centre, run.ring.radius, run.from + travelled / run.ring.radius)
	local heading = TrafficMath.ringHeading(tangent, run.inbound, run.leave.heading, travelled, run.arc, RING_BLEND)
	car.lastPos = pos
	-- a big roundabout's disc lies over the arms (the ramp up to it is out on the road: rampLift)
	local y = run.ring.top or roadTopFor(car.kind)
	draw(car, CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.atan2(-heading.X, -heading.Z), 0))
end

local function moveCar(car: Car, dt: number)
	local road = ROADS[car.roadIndex]
	if not road then
		return
	end

	if car.dwell > 0 then
		car.dwell -= dt
		car.speed = 0
	end
	if car.ring then
		driveRing(car, car.ring, dt)
		return
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
	local closed = TrafficMath.isClosed(road.points, 1e-3)
	local reached: TrafficMath.RingArm? = nil
	local reachedRing: Ring? = nil
	for _, ring in ringsByRoad[car.roadIndex] or {} do
		reached = TrafficMath.armReached(ring.arms, car.roadIndex, car.distance, newDistance, car.direction, if closed then car.length else nil)
		if reached then
			reachedRing = ring
			break
		end
	end
	if reached and reachedRing then
		if ringBusy(car, reachedRing, reached) then
			-- give way to the ring: hold at the line and look again shortly
			car.dwell = RING_WAIT
		else
			driveRing(car, joinRing(car, reachedRing, reached, math.abs(newDistance - reached.distance) % math.max(car.length, 1e-6)), 0)
			return
		end
	elseif closed then
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
		local options = TrafficMath.connections(ROADS, car.roadIndex, atEnd, tolerance)
		local parked = parkedStreets()
		for i = #options, 1, -1 do
			local option = ROADS[options[i].roadIndex]
			if parked[option.name] or option.kind == "alley" then
				table.remove(options, i)
			end
		end
		if #options > 0 then
			local option = options[math.random(1, #options)]
			if landingTaken(car, option) then
				-- hold at the mouth until there is room (it re-rolls its turn then)
				car.distance = math.clamp(newDistance, 0, car.length)
				car.dwell = LANDING_WAIT
			else
				switchRoad(car, option, overshoot)
			end
		else
			-- Dead end: turn round rather than driving off the road.
			car.direction = -car.direction
			car.distance = math.clamp(newDistance, 0, car.length)
			car.turnFrom = car.shown
			car.turnT = 0
		end
	else
		car.distance = newDistance
	end

	local currentRoad = ROADS[car.roadIndex]
	local point, lineDirection = TrafficMath.pointAt(currentRoad.points, car.distance)
	-- X128: face (and keep left for) the way the car is actually travelling. The
	-- polyline's own direction put cars going the other way in the same lane,
	-- driving backwards, which the old box cars hid.
	local direction = lineDirection * car.direction
	-- the kit carriageway, not TownLayout's nominal road width (26 on a main road
	-- put cars on the kerb of the narrower kit street)
	local carriageway = RoadTiles.carriagewayWidth(currentRoad.kind)
	local flatPos = point
		+ (if car.isBike
			then TrafficMath.kerbOffset(direction, carriageway, BIKE_KERB_INSET)
			else TrafficMath.laneOffset(direction, carriageway, -1))
	car.lastPos = flatPos

	local roadTop = roadTopFor(car.kind)
	local y = bridgeDeckY(flatPos, car.kind) or (roadTop + rampLift(car.roadIndex, car.distance, roadTop))
	local yaw = math.atan2(-direction.X, -direction.Z)
	local rootCFrame = CFrame.new(flatPos.X, y, flatPos.Z) * CFrame.Angles(0, yaw, 0)
	-- at a junction or a dead end the car's line jumps (new road, other lane,
	-- new heading): ease from where it was drawn onto the new line
	local turnFrom = car.turnFrom
	if turnFrom then
		car.turnT += dt / TURN_TIME
		if car.turnT >= 1 then
			car.turnFrom = nil
		else
			local t = car.turnT
			rootCFrame = turnFrom:Lerp(rootCFrame, t * t * (3 - 2 * t))
		end
	end
	draw(car, rootCFrame)
end

-- ------------------------------------------------------------------ headlights

-- X160: after dark the nearest cars and buses get a forward SpotLight on an
-- Attachment in their first part (no parts). The Attachment turns back by the
-- mesh yaw so it faces the root's -Z, the way the car is travelling.
local HEADLIGHT_MAX = 8 -- TEMP
local HEADLIGHT_RADIUS = 200
local headlights: { [Model]: Attachment } = {}

-- X248: Sky publishes this for the player's own look
local function skyIsDark(): boolean
	return game:GetService("Players").LocalPlayer:GetAttribute("SkyDark") == true
end

-- X165: bus windows glow warm after dark, like the train's
local BUS_WINDOWS_LIT = Color3.fromRGB(255, 222, 160)

local function refreshHeadlights()
	local want: { [Model]: Car } = {}
	local player = game:GetService("Players").LocalPlayer
	local dark = skyIsDark()
	for _, car in cars do
		local windows = car.parts[2]
		if car.isBus and windows and windows.Name == "Windows" then
			windows.Color = if dark then BUS_WINDOWS_LIT else BUS_WINDOW_COLOR
			windows.Material = if dark then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	if dark and not (player and player:GetAttribute("Quality") == "Low") then
		local camPos = currentCameraPosition()
		local ranked = {}
		for _, car in cars do
			if not car.isBike then
				local d = flatDistance(car.lastPos, camPos)
				if d <= HEADLIGHT_RADIUS then
					table.insert(ranked, { car = car, d = d })
				end
			end
		end
		table.sort(ranked, function(x, y)
			return x.d < y.d
		end)
		for i = 1, math.min(HEADLIGHT_MAX, #ranked) do
			want[ranked[i].car.model] = ranked[i].car
		end
	end
	for model, a in headlights do
		if not want[model] or not model.Parent then
			a:Destroy()
			headlights[model] = nil
		end
	end
	for model, car in want do
		local host = car.parts[1]
		if not headlights[model] and host then
			local reach = math.max(host.Size.X, host.Size.Z) / 2
			local a = Instance.new("Attachment")
			a.Name = "Headlights"
			a.CFrame = CFrame.Angles(0, -car.meshYaw, 0) * CFrame.new(0, 0, -reach)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Front
			light.Angle = 60
			light.Range = 40
			light.Brightness = 2
			light.Color = Color3.fromRGB(255, 244, 220)
			light.Shadows = false
			light.Parent = a
			a.Parent = host
			headlights[model] = a
		end
	end
end

-- X248 (review): Traffic had only the poll, so headlights and lit bus windows
-- could still miss much of a fast-forward night
game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("SkyDark"):Connect(refreshHeadlights)

task.spawn(function()
	while true do
		refreshHeadlights()
		task.wait(1)
	end
end)

-- ------------------------------------------------------------------ main loop

RunService.RenderStepped:Connect(function(dt: number)
	recheckTimer += dt
	local doRecheck = recheckTimer >= RECHECK_INTERVAL
	if doRecheck then
		recheckTimer = 0
	end

	if doRecheck then
		local focus = streamingFocus()
		recheckDespawns(focus)
		recheckSpawns(focus)
	end

	for _, car in cars do
		-- a bus dwelling at a stop counts as stopped before the leader-gap pass,
		-- so the cars behind it queue instead of driving through it
		local free = if car.isBike then BIKE_SPEED * car.jitter else (SPEED_BY_KIND[car.kind] or SPEED_BY_KIND.lane) * car.jitter
		local ringSpeed = math.min(free, RING_SPEED * car.jitter)
		car.speed = if car.dwell > 0 then 0
			elseif car.ring then ringSpeed
			else TrafficMath.easeNear(free, ringSpeed, gapToArm(car.roadIndex, car.distance), RING_SLOW_ZONE)
	end
	applyLeaderGaps()

	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, car in cars do
		car.rolled += car.speed * dt
		moveCar(car, dt)
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
