--!strict
-- Visible-to-everyone matchday crowd (backlog G1.1): fans walking from the
-- town / car park to the turnstiles, plus stewards at fixed spots, for every
-- claimed plot whose match is live and whose ground is near the camera.
-- CLAUDE.md s27: "Fans and stewards around the playing club's ground are
-- visible to everyone" -- this watches every ReplicatedStorage.Clubs.PlotN
-- folder, not just the local player's own plot.
--
-- Geometry is pure and lives in MatchdayRoutes (pitch-local); this script
-- only decides when to spawn/despawn per plot and moves the parts every
-- frame. One RenderStepped connection drives every plot's fans through a
-- single workspace:BulkMoveTo call, the same cheap-crowd approach as
-- BlockFootballer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MatchdayRoutes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MatchdayRoutes"))

-- ------------------------------------------------------------------ tuning

local NEAR_RADIUS = 900 -- start showing a plot's crowd once the camera is this close
local FAR_RADIUS = 1000 -- stop showing it once the camera is this far (hysteresis)
local RECHECK_INTERVAL = 2 -- seconds between camera-distance / fan-count rechecks
local MAX_FANS_PER_PLOT = 48

local LEG = Vector3.new(0.7, 2, 0.7)
local TORSO = Vector3.new(2, 2.2, 1)
local HEAD_SIZE = 1.2
local SCARF = Vector3.new(2.1, 0.5, 1.1) -- stands in for either a scarf or a hat

local SKIN_TONES = {
	Color3.fromRGB(230, 190, 150),
	Color3.fromRGB(190, 140, 100),
	Color3.fromRGB(120, 85, 60),
}
local NEUTRAL_KITS = {
	Color3.fromRGB(60, 60, 65),
	Color3.fromRGB(230, 230, 225),
	Color3.fromRGB(40, 70, 130),
	Color3.fromRGB(90, 90, 40),
}
local DARK_TROUSERS = Color3.fromRGB(40, 40, 45)
local HI_VIS = Color3.fromRGB(255, 235, 20) -- bright yellow, no Neon (mobile-friendly)

-- ------------------------------------------------------------------ types

type Fan = {
	model: Model,
	parts: { BasePart }, -- legs, torso, head, [scarf]
	route: MatchdayRoutes.Route,
	distance: number,
	length: number,
	speed: number,
	lateral: number,
	phase: number,
	loopsInMatch: boolean,
}

type PlotCrowd = {
	folder: Folder,
	model: Folder,
	fans: { Fan },
	stewards: { Model },
	cars: { Model },
	queue: { Model },
	near: boolean,
	alive: boolean,
	plotCFrame: CFrame,
	phaseConn: RBXScriptConnection,
}

-- ------------------------------------------------------------------ state

local root = Instance.new("Folder")
root.Name = "MatchdayLife"
root.Parent = workspace

local crowds: { [Folder]: PlotCrowd } = {}
local ROUTE_LIST = { MatchdayRoutes.ROUTES.fromTown, MatchdayRoutes.ROUTES.fromCarPark }

-- Reused every frame so the single BulkMoveTo call never allocates a fresh table.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

-- ------------------------------------------------------------------ helpers

local function part(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function plotCFrameOf(folder: Folder): CFrame
	local cf = folder:GetAttribute("PlotCFrame")
	return if typeof(cf) == "CFrame" then cf else CFrame.identity
end

local function numberAttribute(folder: Folder, name: string): number
	local v = folder:GetAttribute(name)
	return if type(v) == "number" then v else 0
end

local function targetFanCount(folder: Folder): number
	return MatchdayRoutes.fanCount(numberAttribute(folder, "Attendance"), numberAttribute(folder, "Capacity"))
end

local function lateralOffset(direction: Vector3, amount: number): Vector3
	-- perpendicular to the walking direction, in the XZ plane
	return Vector3.new(-direction.Z, 0, direction.X) * amount
end

-- ------------------------------------------------------------------ fans

local function makeFan(parent: Instance, route: MatchdayRoutes.Route, startDistance: number, loopsInMatch: boolean): Fan
	local model = Instance.new("Model")
	model.Name = "Fan"

	local legs = part("Legs", LEG, DARK_TROUSERS, model)
	local kit = if math.random() < 0.4 then Config.HomeKit else NEUTRAL_KITS[math.random(1, #NEUTRAL_KITS)]
	local torso = part("Torso", TORSO, kit, model)
	local head = part("Head", Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE), SKIN_TONES[math.random(1, #SKIN_TONES)], model)
	head.Shape = Enum.PartType.Ball

	local parts: { BasePart } = { legs, torso, head }
	if math.random() < 0.5 then
		table.insert(parts, part("Scarf", SCARF, Config.HomeKit, model))
	end

	model.Parent = parent

	return {
		model = model,
		parts = parts,
		route = route,
		distance = startDistance,
		length = MatchdayRoutes.length(route),
		speed = 5 + math.random() * 3,
		lateral = math.random() * 5 - 2.5,
		phase = math.random() * math.pi * 2,
		loopsInMatch = loopsInMatch,
	}
end

local function addFan(crowd: PlotCrowd, index: number, total: number)
	local route = ROUTE_LIST[(index % 2) + 1]
	local length = MatchdayRoutes.length(route)
	local startDistance = (index / math.max(total, 1)) * length
	table.insert(crowd.fans, makeFan(crowd.model, route, startDistance, math.random() < 0.5))
end

local function removeFan(crowd: PlotCrowd, index: number)
	local fan = table.remove(crowd.fans, index)
	if fan then
		fan.model:Destroy()
	end
end

-- Appends this frame's part CFrames for one fan to the shared move buffers.
local function appendFanPose(fan: Fan, plotCFrame: CFrame)
	local point, direction = MatchdayRoutes.pointAt(fan.route, fan.distance)
	local offset = lateralOffset(direction, fan.lateral)
	local bob = math.abs(math.sin(fan.phase)) * 0.15
	local yaw = math.atan2(-direction.X, -direction.Z)
	local root3 = plotCFrame * CFrame.new(point + offset + Vector3.new(0, bob, 0)) * CFrame.Angles(0, yaw, 0)

	local legsY = LEG.Y / 2
	local torsoY = LEG.Y + TORSO.Y / 2
	local headY = LEG.Y + TORSO.Y + HEAD_SIZE / 2
	local scarfY = LEG.Y + TORSO.Y * 0.85

	local parts = fan.parts
	table.insert(moveParts, parts[1])
	table.insert(moveCFrames, root3 * CFrame.new(0, legsY, 0))
	table.insert(moveParts, parts[2])
	table.insert(moveCFrames, root3 * CFrame.new(0, torsoY, 0))
	table.insert(moveParts, parts[3])
	table.insert(moveCFrames, root3 * CFrame.new(0, headY, 0))
	if parts[4] then
		table.insert(moveParts, parts[4])
		table.insert(moveCFrames, root3 * CFrame.new(0, scarfY, 0.1))
	end
end

-- ------------------------------------------------------------------ stewards

local function buildStewards(crowd: PlotCrowd)
	for i, spot in MatchdayRoutes.STEWARD_SPOTS do
		local model = Instance.new("Model")
		model.Name = "Steward" .. i

		local legs = part("Legs", LEG, DARK_TROUSERS, model)
		local torso = part("Torso", TORSO, HI_VIS, model)
		local head = part("Head", Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE), SKIN_TONES[math.random(1, #SKIN_TONES)], model)
		head.Shape = Enum.PartType.Ball

		local base = crowd.plotCFrame * spot
		legs.CFrame = base * CFrame.new(0, LEG.Y / 2, 0)
		torso.CFrame = base * CFrame.new(0, LEG.Y + TORSO.Y / 2, 0)
		head.CFrame = base * CFrame.new(0, LEG.Y + TORSO.Y + HEAD_SIZE / 2, 0)

		model.Parent = crowd.model
		table.insert(crowd.stewards, model)
	end
end

-- X91: grey crowd-control barriers either side of the last walk to the
-- turnstiles, up for as long as the crowd is. Each section: two feet, a top
-- rail and a mesh infill (4 parts).
local BARRIER_GREY = Color3.fromRGB(150, 154, 160)
local function buildBarriers(crowd: PlotCrowd)
	local half = MatchdayRoutes.BARRIER_LENGTH / 2
	for _, cf in MatchdayRoutes.barrierSections() do
		local model = Instance.new("Model")
		model.Name = "Barrier"
		local base = crowd.plotCFrame * cf * CFrame.new(0, 0.3, 0) -- on the forecourt paving
		part("Rail", Vector3.new(0.2, 0.2, MatchdayRoutes.BARRIER_LENGTH), BARRIER_GREY, model).CFrame = base * CFrame.new(0, 3.3, 0)
		local mesh = part("Mesh", Vector3.new(0.08, 2.4, MatchdayRoutes.BARRIER_LENGTH - 0.4), BARRIER_GREY, model)
		mesh.CFrame = base * CFrame.new(0, 1.95, 0)
		mesh.Transparency = 0.45
		for _, z in { -half + 0.4, half - 0.4 } do
			part("Foot", Vector3.new(1.6, 0.25, 0.3), BARRIER_GREY, model).CFrame = base * CFrame.new(0, 0.125, z)
		end
		model.Parent = crowd.model
		table.insert(crowd.stewards, model) -- torn down with the stewards
	end
end

-- X93: an outside-broadcast van with a dish and a mast once the club draws a
-- crowd (MatchdayRoutes.hasMedia). 7 parts, torn down with the stewards.
local function buildMediaVan(crowd: PlotCrowd)
	if not MatchdayRoutes.hasMedia(numberAttribute(crowd.folder, "Tier"), numberAttribute(crowd.folder, "Attendance")) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "MediaVan"
	local base = crowd.plotCFrame * MatchdayRoutes.MEDIA_VAN * CFrame.new(0, 0.3, 0) -- forecourt paving; nose to local -Z
	local white = Color3.fromRGB(232, 234, 238)
	part("Body", Vector3.new(6.4, 6.8, 11), white, model).CFrame = base * CFrame.new(0, 4.4, 1.5)
	part("Cab", Vector3.new(6.4, 4.6, 3.6), white, model).CFrame = base * CFrame.new(0, 3.3, -5.8)
	part("Windscreen", Vector3.new(5.8, 2, 0.2), Color3.fromRGB(40, 52, 64), model).CFrame = base * CFrame.new(0, 4.4, -7.65)
	part("Livery", Vector3.new(6.5, 1.2, 10.6), Color3.fromRGB(180, 30, 40), model).CFrame = base * CFrame.new(0, 2.6, 1.5)
	part("Mast", Vector3.new(0.4, 7, 0.4), Color3.fromRGB(150, 152, 156), model).CFrame = base * CFrame.new(1.8, 11.3, 4)
	local dish = part("Dish", Vector3.new(0.3, 4.2, 4.2), Color3.fromRGB(245, 245, 245), model)
	dish.Shape = Enum.PartType.Cylinder
	dish.CFrame = base * CFrame.new(-1.2, 9.4, -1) * CFrame.Angles(0, 0, math.rad(55))
	part("Wheels", Vector3.new(6.8, 2.2, 9), Color3.fromRGB(24, 24, 26), model).CFrame = base * CFrame.new(0, 1.1, 0)
	model.Parent = crowd.model
	table.insert(crowd.stewards, model)
end

-- ------------------------------------------------------------------ queues

-- X104: fans standing in line at the turnstiles before kick-off
-- (MatchdayRoutes.queueSpots), a little turned and shuffled so the lines don't
-- look drilled. Static parts; rebuilt when the wanted count changes (Phase ->
-- Match empties them).
local function rebuildQueue(crowd: PlotCrowd)
	for _, fan in crowd.queue do
		fan:Destroy()
	end
	table.clear(crowd.queue)
	local want = MatchdayRoutes.queueCount(numberAttribute(crowd.folder, "Attendance"), numberAttribute(crowd.folder, "Capacity"), crowd.folder:GetAttribute("Phase"))
	for i, spot in MatchdayRoutes.queueSpots(want) do
		local model = Instance.new("Model")
		model.Name = "QueueFan" .. i
		local kit = if math.random() < 0.5 then Config.HomeKit else NEUTRAL_KITS[math.random(1, #NEUTRAL_KITS)]
		local base = crowd.plotCFrame
			* spot
			* CFrame.new(math.random() * 0.6 - 0.3, 0.3, math.random() * 0.6 - 0.3) -- on the forecourt paving
			* CFrame.Angles(0, math.rad(math.random(-20, 20)), 0)
		part("Legs", LEG, DARK_TROUSERS, model).CFrame = base * CFrame.new(0, LEG.Y / 2, 0)
		part("Torso", TORSO, kit, model).CFrame = base * CFrame.new(0, LEG.Y + TORSO.Y / 2, 0)
		local head = part("Head", Vector3.new(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE), SKIN_TONES[math.random(1, #SKIN_TONES)], model)
		head.Shape = Enum.PartType.Ball
		head.CFrame = base * CFrame.new(0, LEG.Y + TORSO.Y + HEAD_SIZE / 2, 0)
		if math.random() < 0.5 then
			part("Scarf", SCARF, Config.HomeKit, model).CFrame = base * CFrame.new(0, LEG.Y + TORSO.Y * 0.85, 0.1)
		end
		model.Parent = crowd.model
		table.insert(crowd.queue, model)
	end
end

-- ------------------------------------------------------------------ parked cars

-- G1.2: the club car park fills with supporters' cars on matchday. Bays come
-- from MatchdayRoutes (they match PlotGrounds' bay lines); which bays fill is
-- seeded by the plot so a ground looks the same every matchday.
local BAYS = MatchdayRoutes.carParkBays()
local CAR_COLOURS = {
	Color3.fromRGB(40, 48, 62),
	Color3.fromRGB(150, 152, 156),
	Color3.fromRGB(128, 28, 30),
	Color3.fromRGB(236, 236, 232),
	Color3.fromRGB(26, 26, 28),
	Color3.fromRGB(60, 90, 70),
}
local ASPHALT_TOP = 0.2 -- PlotGrounds car park asphalt

local function buildCars(crowd: PlotCrowd)
	local count = MatchdayRoutes.parkedCars(numberAttribute(crowd.folder, "Attendance"), #BAYS)
	local plotIndex = crowd.folder:GetAttribute("PlotIndex")
	local rng = Random.new(if type(plotIndex) == "number" then plotIndex * 131 else 7)
	local order = {}
	for i = 1, #BAYS do
		table.insert(order, i)
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for k = 1, count do
		local bay = BAYS[order[k]]
		local model = Instance.new("Model")
		model.Name = "ParkedCar"
		local base = crowd.plotCFrame * CFrame.new(bay.X + rng:NextNumber(-0.6, 0.6), ASPHALT_TOP + 0.02, bay.Z)
		local colour = CAR_COLOURS[rng:NextInteger(1, #CAR_COLOURS)]
		part("Body", Vector3.new(8.4, 1.9, 4.2), colour, model).CFrame = base * CFrame.new(0, 0.95 + 0.35, 0)
		part("Cabin", Vector3.new(4.6, 1.5, 3.8), Color3.fromRGB(34, 40, 48), model).CFrame = base * CFrame.new(-0.4, 1.9 + 0.35 + 0.7, 0)
		model.Parent = crowd.model
		table.insert(crowd.cars, model)
	end
end

-- ------------------------------------------------------------------ spawn / despawn

local function adjustFanCount(crowd: PlotCrowd)
	local target = math.min(targetFanCount(crowd.folder), MAX_FANS_PER_PLOT)
	if crowd.folder:GetAttribute("Phase") == "Match" then
		-- once the game is on most fans are inside; don't top the queue back up
		target = math.min(target, #crowd.fans, math.ceil(target / 2))
	end
	while #crowd.fans > target do
		removeFan(crowd, #crowd.fans)
	end
	local total = math.max(target, #crowd.fans)
	for i = #crowd.fans + 1, target do
		addFan(crowd, i, total)
	end
end

local function spawnCrowd(crowd: PlotCrowd)
	crowd.plotCFrame = plotCFrameOf(crowd.folder)
	buildStewards(crowd)
	buildBarriers(crowd)
	buildMediaVan(crowd)
	buildCars(crowd)
	rebuildQueue(crowd)
	adjustFanCount(crowd)
end

local function despawnCrowd(crowd: PlotCrowd)
	for i = #crowd.fans, 1, -1 do
		removeFan(crowd, i)
	end
	for _, steward in crowd.stewards do
		steward:Destroy()
	end
	table.clear(crowd.stewards)
	for _, car in crowd.cars do
		car:Destroy()
	end
	table.clear(crowd.cars)
	for _, fan in crowd.queue do
		fan:Destroy()
	end
	table.clear(crowd.queue)
end

local function recheckCrowd(crowd: PlotCrowd, camPos: Vector3)
	local folder = crowd.folder
	local phase = folder:GetAttribute("Phase")
	local wantsLife = phase == "PreMatch" or phase == "Match"

	if wantsLife then
		local dist = (camPos - plotCFrameOf(folder).Position).Magnitude
		if crowd.near then
			if dist > FAR_RADIUS then
				crowd.near = false
			end
		elseif dist <= NEAR_RADIUS then
			crowd.near = true
		end
	else
		crowd.near = false
	end

	local shouldBeAlive = wantsLife and crowd.near
	if shouldBeAlive and not crowd.alive then
		crowd.alive = true
		spawnCrowd(crowd)
	elseif not shouldBeAlive and crowd.alive then
		crowd.alive = false
		despawnCrowd(crowd)
	elseif shouldBeAlive and crowd.alive then
		adjustFanCount(crowd)
		local wantQueue = MatchdayRoutes.queueCount(numberAttribute(folder, "Attendance"), numberAttribute(folder, "Capacity"), phase)
		if wantQueue ~= #crowd.queue then
			rebuildQueue(crowd)
		end
	end
end

local function currentCameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

-- ------------------------------------------------------------------ tracking plots

local function trackPlot(folder: Folder)
	if crowds[folder] then
		return
	end

	local model = Instance.new("Folder")
	model.Name = folder.Name
	model.Parent = root

	-- Forward-declared so the Phase connection's closure can capture it as an
	-- upvalue; the callback only ever runs after this function returns, by
	-- which point `crowd` is fully assigned.
	local crowd: PlotCrowd
	crowd = {
		folder = folder,
		model = model,
		fans = {},
		stewards = {},
		cars = {},
		queue = {},
		near = false,
		alive = false,
		plotCFrame = CFrame.identity,
		phaseConn = folder:GetAttributeChangedSignal("Phase"):Connect(function()
			recheckCrowd(crowd, currentCameraPosition())
		end),
	}
	crowds[folder] = crowd

	recheckCrowd(crowd, currentCameraPosition())
end

local function untrackPlot(folder: Folder)
	local crowd = crowds[folder]
	if not crowd then
		return
	end
	crowd.phaseConn:Disconnect()
	despawnCrowd(crowd)
	crowd.model:Destroy()
	crowds[folder] = nil
end

local function watchClubs()
	-- Clubs appears when the first plot on the server is claimed, which may be long after join
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	while not clubs do
		task.wait(2)
		clubs = ReplicatedStorage:FindFirstChild("Clubs")
	end
	for _, child in clubs:GetChildren() do
		if child:IsA("Folder") then
			trackPlot(child)
		end
	end
	clubs.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			trackPlot(child)
		end
	end)
	clubs.ChildRemoved:Connect(function(child)
		if child:IsA("Folder") then
			untrackPlot(child)
		end
	end)
end

task.spawn(watchClubs)

-- ------------------------------------------------------------------ main loop

local recheckTimer = 0

RunService.RenderStepped:Connect(function(dt: number)
	recheckTimer += dt
	local doRecheck = recheckTimer >= RECHECK_INTERVAL
	if doRecheck then
		recheckTimer = 0
	end

	table.clear(moveParts)
	table.clear(moveCFrames)

	local camPos = if doRecheck then currentCameraPosition() else Vector3.zero

	for _, crowd in crowds do
		if doRecheck then
			recheckCrowd(crowd, camPos)
		end
		if not crowd.alive then
			continue
		end

		local phase = crowd.folder:GetAttribute("Phase")
		local i = 1
		while i <= #crowd.fans do
			local fan = crowd.fans[i]
			fan.distance += fan.speed * dt
			fan.phase += dt * 2.2
			if fan.distance >= fan.length then
				if phase == "Match" and not fan.loopsInMatch then
					removeFan(crowd, i)
					continue
				end
				fan.distance = fan.distance % fan.length
			end
			appendFanPose(fan, crowd.plotCFrame)
			i += 1
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
