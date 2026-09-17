--!strict
-- Ambient town life (backlog F4.1 wind turbines, square flags and chimney
-- smoke, H1.1 club banners, G2.1 matchday bunting and busy pubs). CLAUDE.md
-- s27: "Town-wide banners and busy pubs show only on that player's screen" --
-- banners, flags, bunting and pub drinkers here only ever show the LOCAL
-- player's own club, never another player's.
--
-- Geometry is pure and lives in TownLifeMath; this script only decides what
-- to build/move and when, following the cheap-crowd pattern already used by
-- MatchdayLife (BulkMoveTo, a throttled RenderStepped tick, near/far radii
-- with a part budget).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))
local ClubRef = require(script.Parent.ClubRef)

-- ------------------------------------------------------------------ shared

local root = Instance.new("Folder")
root.Name = "TownLife"
root.Parent = workspace

local bannersFolder = Instance.new("Folder")
bannersFolder.Name = "Banners"
bannersFolder.Parent = root

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- C3.2: QualityController publishes "High" | "Low" on the LocalPlayer.
local function isLowQuality(): boolean
	local player = game:GetService("Players").LocalPlayer
	return player ~= nil and player:GetAttribute("Quality") == "Low"
end

local function currentCameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

-- ================================================================ turbines

local TURBINE_RADIUS = 5000 -- studs from the camera; skip animating anything further out
local TURBINE_SPEED = 0.9 -- rad/s about world X, through the hub
local TURBINE_HZ = 20 -- max pose pushes per second

type TurbineBlade = { part: BasePart, offset: CFrame }
type Turbine = { hub: Vector3, phase: number, blades: { TurbineBlade } }

local turbines: { Turbine } = {}
local trackedTurbines: { [Model]: boolean } = {}

-- Backdrop.buildTurbines makes the nacelle axis-aligned, so the hub is simply
-- 8 studs along world +X from it (CLAUDE.md task brief / Backdrop.luau).
local function trackTurbine(inst: Instance)
	if not (inst:IsA("Model") and inst.Name == "WindTurbine") then
		return
	end
	local model = inst :: Model
	if model:GetAttribute("Spin") ~= true then
		return
	end
	local nacelle = model:FindFirstChild("Nacelle")
	if not (nacelle and nacelle:IsA("BasePart")) then
		return
	end
	local hub = nacelle.Position + Vector3.new(8, 0, 0)
	local hubFrame = CFrame.new(hub)
	local blades: { TurbineBlade } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Blade" then
			table.insert(blades, { part = child, offset = hubFrame:Inverse() * child.CFrame })
		end
	end
	if #blades == 0 or trackedTurbines[model] then
		return
	end
	trackedTurbines[model] = true
	table.insert(turbines, { hub = hub, phase = math.random() * math.pi * 2, blades = blades })
end

local function watchTurbines()
	local backdrop = workspace:FindFirstChild("Backdrop")
	while not backdrop do
		task.wait(2)
		backdrop = workspace:FindFirstChild("Backdrop")
	end
	local container = backdrop:FindFirstChild("Turbines")
	while not container do
		task.wait(2)
		container = backdrop:FindFirstChild("Turbines")
	end
	for _, child in container:GetChildren() do
		trackTurbine(child)
	end
	container.ChildAdded:Connect(trackTurbine)
	-- parts can stream in after their model; retry once the blades arrive
	container.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Parent then
			trackTurbine(d.Parent)
		end
	end)
end
task.spawn(watchTurbines)

local turbineAge = 0
local turbineTimer = 0
local turbineMoveParts: { BasePart } = {}
local turbineMoveCFrames: { CFrame } = {}

RunService.RenderStepped:Connect(function(dt: number)
	turbineAge += dt
	turbineTimer += dt
	if turbineTimer < 1 / TURBINE_HZ then
		return
	end
	turbineTimer = 0

	if #turbines == 0 then
		return
	end

	table.clear(turbineMoveParts)
	table.clear(turbineMoveCFrames)
	local camPos = currentCameraPosition()

	for _, turbine in turbines do
		if (camPos - turbine.hub).Magnitude > TURBINE_RADIUS then
			continue
		end
		local angle = turbine.phase + turbineAge * TURBINE_SPEED
		for _, blade in turbine.blades do
			table.insert(turbineMoveParts, blade.part)
			table.insert(turbineMoveCFrames, TownLifeMath.bladeCFrame(turbine.hub, blade.offset, angle))
		end
	end

	if #turbineMoveParts > 0 then
		workspace:BulkMoveTo(turbineMoveParts, turbineMoveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- ================================================================= banners

local BANNER_HEIGHT = 9
local BANNER_FORWARD = 0.9
local BANNER_WIDTH = 1.6
local BANNER_TALL = 3.2
local BANNER_THICK = 0.1
local BANNER_NEAR = 700
local BANNER_FAR = 900
local BANNER_BUDGET = 60
local BANNER_BUDGET_LOW = 20 -- TEMP, Quality "Low" (mirrors Shared.Quality.BUDGETS.Low.banners)
local BANNER_RESCAN_SECONDS = 5

type LampEntry = { model: Model, ground: Vector3, roadDir: Vector3, index: number }
type BannerEntry = { model: Model, labels: { TextLabel } }

local allLamps: { LampEntry } = {}
local seenLamps: { [Model]: boolean } = {}
local lampCounter = 0
local activeBanners: { [Model]: BannerEntry } = {}
local activeBannerCount = 0

-- Where a lamp model's post meets the ground, and the horizontal direction
-- its arm/lantern leans towards the road ("the road side").
--
-- TerraceLamp's PrimaryPart (Post) carries an axis-swap CFrame --
-- TerraceBuilder.lamp rotates it 90 degrees about the placement CFrame's own
-- Z axis so the cylinder shape's X axis points up -- so Post's own Y/X
-- columns are not simply "up" and "forward". A rotation about Z leaves Z
-- alone though, and Post's local -Z is exactly the arm's lean direction
-- ("post top at ~13.8, arm toward local -Z"), so this rebuilds from the post
-- directly rather than trusting the model's pivot.
--
-- Kit lamps (attribute Kit == "LampVictorian") are placed by
-- KitPlacer.place, which ends with model:PivotTo(target * offset:Inverse())
-- where `target` keeps the placement CFrame's rotation -- so their pivot can
-- be used directly.
local function lampPlacement(model: Model): (Vector3?, Vector3?)
	if model.Name == "TerraceLamp" then
		local post = model:FindFirstChild("Post")
		if not (post and post:IsA("BasePart")) then
			return nil, nil
		end
		local ground = post.Position - Vector3.new(0, 7.5, 0)
		local roadDir = post.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1))
		return ground, roadDir
	elseif model:GetAttribute("Kit") == "LampVictorian" then
		local pivot = model:GetPivot()
		return pivot.Position, pivot:VectorToWorldSpace(Vector3.new(0, 0, -1))
	end
	return nil, nil
end

local function registerLamp(inst: Instance)
	-- StreamingEnabled: a lamp model can arrive before its Post, so a part
	-- arriving later retries its parent model
	if inst:IsA("BasePart") and inst.Parent then
		inst = inst.Parent
	end
	if not inst:IsA("Model") then
		return
	end
	local model = inst :: Model
	if seenLamps[model] then
		return
	end
	local isLamp = model.Name == "TerraceLamp" or model:GetAttribute("Kit") == "LampVictorian"
	if not isLamp then
		return
	end
	local ground, roadDir = lampPlacement(model)
	if not (ground and roadDir) then
		return
	end
	seenLamps[model] = true
	lampCounter += 1
	table.insert(allLamps, { model = model, ground = ground :: Vector3, roadDir = roadDir :: Vector3, index = lampCounter })
end

local function watchLampDressing()
	local town = workspace:FindFirstChild("Town")
	while not town do
		task.wait(2)
		town = workspace:FindFirstChild("Town")
	end
	local dressing = town:FindFirstChild("Dressing")
	while not dressing do
		task.wait(2)
		dressing = town:FindFirstChild("Dressing")
	end
	for _, d in dressing:GetDescendants() do
		registerLamp(d)
	end
	dressing.DescendantAdded:Connect(registerLamp)
end
task.spawn(watchLampDressing)

local function currentClubName(): string
	local folder = ClubRef.state()
	local name = folder and folder:GetAttribute("ClubName")
	if type(name) == "string" and name ~= "" then
		return name
	end
	return Config.ClubName
end

local function buildBanner(lamp: LampEntry, clubName: string): BannerEntry
	local bannerPos = lamp.ground + Vector3.new(0, BANNER_HEIGHT, 0) + lamp.roadDir * BANNER_FORWARD
	local cframe = CFrame.lookAt(bannerPos, bannerPos + lamp.roadDir)
	local kit, accent = Config.clubCrest(clubName, true)

	local banner = Instance.new("Model")
	banner.Name = "ClubBanner"

	local panel = newPart("Panel", Vector3.new(BANNER_WIDTH, BANNER_TALL, BANNER_THICK), cframe, kit, banner)
	banner.PrimaryPart = panel

	local labels: { TextLabel } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Face"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 36
		gui.Parent = panel

		local label = Instance.new("TextLabel")
		label.Name = "Name"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = accent
		label.TextStrokeTransparency = 0.5
		label.Text = TownLifeMath.bannerText(clubName)
		label.Parent = gui
		table.insert(labels, label)
	end

	banner.Parent = bannersFolder
	return { model = banner, labels = labels }
end

local function removeBanner(lampModel: Model)
	local entry = activeBanners[lampModel]
	if not entry then
		return
	end
	entry.model:Destroy()
	activeBanners[lampModel] = nil
	activeBannerCount -= 1
end

local function renameBanners()
	local text = TownLifeMath.bannerText(currentClubName())
	for _, entry in activeBanners do
		for _, label in entry.labels do
			label.Text = text
		end
	end
end

-- "Every other lamp" so a whole street isn't wall-to-wall banners: alternates
-- on each lamp's stable scan order, which stays fixed for the session since
-- StreetDresser only builds the town once.
local function rescanBanners()
	local camPos = currentCameraPosition()
	local clubName = currentClubName()
	local budget = if isLowQuality() then BANNER_BUDGET_LOW else BANNER_BUDGET

	-- quality dropped to Low: take down banners over the new budget
	if activeBannerCount > budget then
		for lampModel in activeBanners do
			if activeBannerCount <= budget then
				break
			end
			removeBanner(lampModel)
		end
	end

	for _, lamp in allLamps do
		local dist = (camPos - lamp.ground).Magnitude
		local hasBanner = activeBanners[lamp.model] ~= nil
		if hasBanner then
			if dist > BANNER_FAR then
				removeBanner(lamp.model)
			end
		elseif dist <= BANNER_NEAR and lamp.index % 2 == 0 and activeBannerCount < budget then
			activeBanners[lamp.model] = buildBanner(lamp, clubName)
			activeBannerCount += 1
		end
	end
end

-- ================================================================ bunting

local BUNTING_SPACING = 60
local BUNTING_HEIGHT = 14
local BUNTING_STRING_BUDGET = 40
local BUNTING_STRING_BUDGET_LOW = 12 -- TEMP, Quality "Low" (mirrors Shared.Quality.BUDGETS.Low.buntingStrings)
local BUNTING_ROAD_COUNT = 3
local BUNTING_FLAG_COUNT = 8
local BUNTING_FLAG_SIZE = Vector3.new(1, 1.2, 0.1)
local BUNTING_FLAG_DROP = 0.9
local BUNTING_WHITE = Color3.fromRGB(240, 240, 240)
local BUNTING_STRING_COLOR = Color3.fromRGB(40, 40, 40)

local buntingFolder: Folder? = nil

-- The 3 residential streets whose polyline is nearest the plot, closest first.
local function closestResidentialRoads(plotPos: Vector3): { TownLayout.Road }
	local scored: { { road: TownLayout.Road, dist: number } } = {}
	for _, road in TownLayout.ROADS do
		if road.kind == "residential" then
			table.insert(scored, { road = road, dist = TownLayout.distanceToPolyline(plotPos, road.points) })
		end
	end
	table.sort(scored, function(a, b)
		return a.dist < b.dist
	end)
	local out: { TownLayout.Road } = {}
	for i = 1, math.min(BUNTING_ROAD_COUNT, #scored) do
		table.insert(out, scored[i].road)
	end
	return out
end

-- One bunting string across the carriageway at `station`, plus its hanging
-- flags. `kit` alternates with white along the string.
local function buildBuntingCrossing(parent: Instance, station: TownLifeMath.Station, width: number, kit: Color3)
	local model = Instance.new("Model")
	model.Name = "Bunting"

	local pos = Vector3.new(station.position.X, BUNTING_HEIGHT, station.position.Z)
	local rightDir = Vector3.new(-station.direction.Z, 0, station.direction.X)
	local stringCFrame = CFrame.fromMatrix(pos, rightDir, Vector3.new(0, 1, 0))

	local strand = newPart("String", Vector3.new(width, 0.15, 0.15), stringCFrame, BUNTING_STRING_COLOR, model)
	model.PrimaryPart = strand

	for i = 1, BUNTING_FLAG_COUNT do
		local t = (i - 0.5) / BUNTING_FLAG_COUNT - 0.5 -- spread evenly across the string, centred on 0
		local color = if i % 2 == 0 then kit else BUNTING_WHITE
		newPart("Flag", BUNTING_FLAG_SIZE, stringCFrame * CFrame.new(t * width, -BUNTING_FLAG_DROP, 0), color, model)
	end

	model.Parent = parent
end

local function clearBunting()
	if buntingFolder then
		buntingFolder:Destroy()
		buntingFolder = nil
	end
end

local function buildBunting(plotCFrame: CFrame, clubName: string)
	clearBunting()
	local folder = Instance.new("Folder")
	folder.Name = "Bunting"
	local kit = Config.clubCrest(clubName, true)
	local stringBudget = if isLowQuality() then BUNTING_STRING_BUDGET_LOW else BUNTING_STRING_BUDGET

	local built = 0
	for _, road in closestResidentialRoads(plotCFrame.Position) do
		if built >= stringBudget then
			break
		end
		local width = road.width + 16
		for _, station in TownLifeMath.stationsAlong(road.points, BUNTING_SPACING) do
			if built >= stringBudget then
				break
			end
			buildBuntingCrossing(folder, station, width, kit)
			built += 1
		end
	end

	folder.Parent = root
	buntingFolder = folder
end

-- =================================================================== flags
-- F4.1a: club flags on poles round the market square, waving. Entirely
-- client-side (poles too), so each player sees their own club's colours.

local FLAG_POLES = 4
local FLAG_RING = 51 -- inside the square's lamps (54) and bollards (57), behind the stalls (<= ~46)
local FLAG_RING_OFFSET = math.pi / 8 -- 22.5 deg: clear of the road mouths (0/90/180/270) and lamps (45 + 90k)
local FLAG_RADIUS = 400 -- only animate flags this close to the camera
local FLAG_HZ = 20
local SQUARE_TOP = 0.25 -- TownBuilder.Y.SQUARE
local POLE_HEIGHT = 22
local POLE_SINK = 0.1 -- pole foot sinks this far into the square so no plane is shared
local POLE_THICK = 0.4
local FINIAL_SIZE = 0.7
local FLAG_SEGMENTS = 3
local FLAG_SEGMENT_WIDTH = 1.7
local FLAG_TALL = 2.8
local FLAG_THICK = 0.08
local POLE_COLOR = Color3.fromRGB(225, 225, 222)
local FINIAL_COLOR = Color3.fromRGB(200, 165, 60)
local WIND = Vector3.new(0.8, 0, 0.6).Unit -- TEMP prevailing wind: flags fly and smoke drifts this way

type Flag = { base: Vector3, attach: CFrame, phase: number, segments: { BasePart } }

local flags: { Flag } = {}

local function buildFlags()
	local folder = Instance.new("Folder")
	folder.Name = "Flags"
	local kit, accent = Config.clubCrest(currentClubName(), true)
	local centre = TownLayout.SQUARE.centre
	for i, p in TownLifeMath.ringPoints(Vector3.new(centre.X, SQUARE_TOP, centre.Z), FLAG_RING, FLAG_POLES, FLAG_RING_OFFSET) do
		local model = Instance.new("Model")
		model.Name = "Flagpole"
		local bottom = p.Y - POLE_SINK
		local top = bottom + POLE_HEIGHT
		local pole = newPart("Pole", Vector3.new(POLE_HEIGHT, POLE_THICK, POLE_THICK), CFrame.new(p.X, bottom + POLE_HEIGHT / 2, p.Z) * CFrame.Angles(0, 0, math.pi / 2), POLE_COLOR, model);
		(pole :: any).Shape = Enum.PartType.Cylinder
		pole.CastShadow = true
		local finial = newPart("Finial", Vector3.one * FINIAL_SIZE, CFrame.new(p.X, top + FINIAL_SIZE / 2 - 0.15, p.Z), FINIAL_COLOR, model);
		(finial :: any).Shape = Enum.PartType.Ball

		-- hinge just off the pole's surface, flag top 0.4 under the pole top
		local attachPos = Vector3.new(p.X, top - 0.4 - FLAG_TALL / 2, p.Z) + WIND * (POLE_THICK / 2 + 0.05)
		local attach = CFrame.fromMatrix(attachPos, WIND, Vector3.yAxis)
		local phase = i * 1.7
		local segments: { BasePart } = {}
		local cfs = TownLifeMath.flagSegmentCFrames(attach, FLAG_SEGMENT_WIDTH, FLAG_SEGMENTS, phase)
		for s, cf in cfs do
			local color = if s == 2 then accent else kit
			table.insert(segments, newPart("Flag" .. s, Vector3.new(FLAG_SEGMENT_WIDTH, FLAG_TALL, FLAG_THICK), cf, color, model))
		end
		model.PrimaryPart = pole
		model.Parent = folder
		table.insert(flags, { base = p, attach = attach, phase = phase, segments = segments })
	end
	folder.Parent = root
end

local flagAge = 0
local flagTimer = 0
local flagMoveParts: { BasePart } = {}
local flagMoveCFrames: { CFrame } = {}

RunService.RenderStepped:Connect(function(dt: number)
	flagAge += dt
	flagTimer += dt
	if flagTimer < 1 / FLAG_HZ or #flags == 0 then
		return
	end
	flagTimer = 0
	table.clear(flagMoveParts)
	table.clear(flagMoveCFrames)
	local camPos = currentCameraPosition()
	for _, flag in flags do
		if (camPos - flag.base).Magnitude > FLAG_RADIUS then
			continue
		end
		local cfs = TownLifeMath.flagSegmentCFrames(flag.attach, FLAG_SEGMENT_WIDTH, #flag.segments, flagAge + flag.phase)
		for s, part in flag.segments do
			table.insert(flagMoveParts, part)
			table.insert(flagMoveCFrames, cfs[s])
		end
	end
	if #flagMoveParts > 0 then
		workspace:BulkMoveTo(flagMoveParts, flagMoveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- =================================================================== smoke
-- F4.1b: soft grey smoke from about one chimney stack in eight near the
-- camera. Emitters hang off Attachments on workspace.Terrain at each stack
-- top (recorded as a position when the stack streams in), so no extra parts
-- and nothing to lose when the house streams out; a stack that has streamed
-- out simply stops being a candidate. Off entirely on Quality "Low".

local SMOKE_RADIUS = 300
local SMOKE_EVERY = 8
local SMOKE_MAX = 12
local SMOKE_RESCAN_SECONDS = 2
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built into the client, no upload

type StackEntry = { part: BasePart, top: Vector3 }

local stacks: { [string]: StackEntry } = {} -- keyed by rounded top position, never by Instance
local smokes: { [string]: Attachment } = {}

local function positionKey(p: Vector3): string
	return ("%d,%d,%d"):format(math.floor(p.X + 0.5), math.floor(p.Y + 0.5), math.floor(p.Z + 0.5))
end

local function registerStack(part: BasePart)
	local top = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2, 0))
	stacks[positionKey(top)] = { part = part, top = top }
end

local function newSmoke(top: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "TownLifeSmoke"
	a.Position = top + Vector3.new(0, 1, 0) -- Terrain's frame is the world frame; just above the pots
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(Color3.fromRGB(215, 215, 212), Color3.fromRGB(175, 175, 172))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Rate = 2
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(1.2, 2.2)
	e.SpreadAngle = Vector2.new(10, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = WIND * 0.35 + Vector3.new(0, 0.1, 0)
	e.Drag = 0.15
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-12, 12)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.6),
		NumberSequenceKeypoint.new(0.6, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = a
	a.Parent = workspace.Terrain
	return a
end

local function clearSmoke()
	for key, a in smokes do
		a:Destroy()
		smokes[key] = nil
	end
end

local function rescanSmoke()
	if isLowQuality() then
		clearSmoke()
		return
	end
	local keys: { string } = {}
	local tops: { Vector3 } = {}
	for key, entry in stacks do
		if entry.part.Parent == nil then
			stacks[key] = nil -- streamed out; it re-registers if it streams back in
		else
			table.insert(keys, key)
			table.insert(tops, entry.top)
		end
	end
	local wanted: { [string]: Vector3 } = {}
	for _, i in TownLifeMath.smokeChimneys(tops, currentCameraPosition(), SMOKE_RADIUS, SMOKE_EVERY, SMOKE_MAX) do
		wanted[keys[i]] = tops[i]
	end
	for key, a in smokes do
		if not wanted[key] then
			a:Destroy()
			smokes[key] = nil
		end
	end
	for key, top in wanted do
		if not smokes[key] then
			smokes[key] = newSmoke(top)
		end
	end
end

-- ==================================================================== pubs
-- G2.1: while the local club's Phase is PreMatch or Match, a few drinkers in
-- the club's colours stand outside the 2 pubs nearest the player's plot.
-- Pub fronts are recorded as plain data (CFrame + size) as their Shopfront
-- parts stream in, so a pub that later streams out keeps its drinkers.
-- Known limit: only pubs that have streamed in at least once are candidates,
-- so if a nearer pub arrives mid-matchday the drinkers move to it.

local PUB_COUNT = 2
local PUB_MIN_APART = 30 -- two chosen pub fronts must be this far apart (not neighbouring bays)
local PUB_DRINKERS = 10 -- TEMP total across both pubs
local PUB_DRINKERS_LOW = 5 -- TEMP, Quality "Low"
local PUB_PART_BUDGET = 80
local PUB_PART_BUDGET_LOW = 40
local PINT_CHANCE = 0.55
local PINT_COLOR = Color3.fromRGB(196, 132, 40)
local DRINKER_SKIN = {
	Color3.fromRGB(235, 200, 165),
	Color3.fromRGB(225, 185, 145),
	Color3.fromRGB(190, 140, 100),
	Color3.fromRGB(140, 100, 70),
	Color3.fromRGB(95, 65, 45),
}
local DRINKER_TROUSERS = {
	Color3.fromRGB(40, 50, 75),
	Color3.fromRGB(30, 30, 32),
	Color3.fromRGB(85, 85, 88),
	Color3.fromRGB(70, 90, 125),
}

type PubFront = { key: string, cframe: CFrame, size: Vector3, seed: number }

local pubFronts: { PubFront } = {}
local pubFrontKeys: { [string]: boolean } = {}
local pubFolder: Folder? = nil
local pubChoice = ""

local function registerPub(part: BasePart)
	local key = positionKey(part.Position)
	if pubFrontKeys[key] then
		return
	end
	pubFrontKeys[key] = true
	local p = part.Position
	local seed = (math.floor(math.abs(p.X)) * 92821 + math.floor(math.abs(p.Z)) * 31 + 7) % 2147483647
	table.insert(pubFronts, { key = key, cframe = part.CFrame, size = part.Size, seed = seed })
end

local function onTownDescendant(inst: Instance)
	if inst:IsA("BasePart") then
		local part = inst :: BasePart
		local name = part.Name
		if name:match("^Stack%d*$") then
			registerStack(part)
		elseif name:match("^Shopfront") and part:GetAttribute("Front") == "shop_front_pub" then
			registerPub(part)
		end
	end
end

local function clearPubs()
	if pubFolder then
		pubFolder:Destroy()
		pubFolder = nil
	end
	pubChoice = ""
end

-- Builds up to `count` drinkers outside `pub`; returns the parts used.
local function buildDrinkers(parent: Instance, pub: PubFront, count: number, kit: Color3, budgetLeft: number): number
	local F = TownLifeMath.FIGURE
	local rng = Random.new(pub.seed + 1)
	local used = 0
	for _, feet in TownLifeMath.drinkerSpots(pub.cframe, pub.size, count, pub.seed) do
		local pint = rng:NextNumber() < PINT_CHANCE
		if used + (if pint then 7 else 6) > budgetLeft then
			pint = false
		end
		if used + 6 > budgetLeft then
			break
		end
		local cfs = TownLifeMath.figureCFrames(feet, pint)
		local skin = DRINKER_SKIN[rng:NextInteger(1, #DRINKER_SKIN)]
		local trousers = DRINKER_TROUSERS[rng:NextInteger(1, #DRINKER_TROUSERS)]
		local sleeves = if rng:NextNumber() < 0.35 then skin else kit -- some in short sleeves

		local model = Instance.new("Model")
		model.Name = "Drinker"
		newPart("Torso", F.torso, cfs[1], kit, model).CastShadow = true
		local head = newPart("Head", Vector3.one * F.head, cfs[2], skin, model);
		(head :: any).Shape = Enum.PartType.Ball
		-- X136: a face, like the other town figures
		local face = Instance.new("Decal")
		face.Name = "Face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = head
		newPart("LegL", F.leg, cfs[3], trousers, model)
		newPart("LegR", F.leg, cfs[4], trousers, model)
		newPart("ArmL", F.arm, cfs[5], sleeves, model)
		newPart("ArmR", F.arm, cfs[6], sleeves, model)
		used += 6
		if pint then
			local glass = newPart("Pint", F.pint, cfs[7], PINT_COLOR, model);
			(glass :: any).Shape = Enum.PartType.Cylinder
			glass.Transparency = 0.15
			used += 1
		end
		model.Parent = parent
	end
	return used
end

local function refreshPubs()
	local folder = ClubRef.state()
	local phase = if folder then folder:GetAttribute("Phase") else nil
	if not (phase == "PreMatch" or phase == "Match") then
		clearPubs()
		return
	end

	local plotPos = ClubRef.frame().Position
	local points: { Vector3 } = {}
	for _, pub in pubFronts do
		table.insert(points, pub.cframe.Position)
	end
	local chosen: { PubFront } = {}
	for _, i in TownLifeMath.nearestIndices(points, plotPos, #points) do
		local pub = pubFronts[i]
		local clear = true
		for _, other in chosen do
			local d = pub.cframe.Position - other.cframe.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude < PUB_MIN_APART then
				clear = false
				break
			end
		end
		if clear then
			table.insert(chosen, pub)
			if #chosen >= PUB_COUNT then
				break
			end
		end
	end

	local low = isLowQuality()
	local keyParts = { if low then "Low" else "High" }
	for _, pub in chosen do
		table.insert(keyParts, pub.key)
	end
	local choice = table.concat(keyParts, "|")
	if pubFolder and choice == pubChoice then
		return
	end
	clearPubs()
	if #chosen == 0 then
		return -- no pub has streamed in yet; the next rescan tries again
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "PubDrinkers"
	local kit = Config.clubCrest(currentClubName(), true)
	local total = if low then PUB_DRINKERS_LOW else PUB_DRINKERS
	local budget = if low then PUB_PART_BUDGET_LOW else PUB_PART_BUDGET
	local used = 0
	local placed = 0
	for n, pub in chosen do
		-- split the total evenly, the first pub taking any odd one
		local count = math.ceil((total - placed) / (#chosen - n + 1))
		used += buildDrinkers(newFolder, pub, count, kit, budget - used)
		placed += count
	end
	newFolder.Parent = root
	pubFolder = newFolder
	pubChoice = choice
end

local function watchTown()
	local town = workspace:FindFirstChild("Town")
	while not town do
		task.wait(2)
		town = workspace:FindFirstChild("Town")
	end
	buildFlags()
	town.DescendantAdded:Connect(onTownDescendant)
	for _, d in town:GetDescendants() do
		onTownDescendant(d)
	end
	while true do
		rescanSmoke()
		task.wait(SMOKE_RESCAN_SECONDS)
	end
end
task.spawn(watchTown)

-- ------------------------------------------------------- club-driven watcher

-- ============================================================ evening lamps

-- X37: street lamps glow (Neon glass) but light nothing, so evening fixtures
-- leave the streets black. When this player's sky is dark, the nearest lamps
-- get a PointLight on an Attachment in Terrain (cheap to add/remove, no parts).
local LAMP_LIGHT_MAX = 16
local LAMP_LIGHT_MAX_LOW = 6 -- TEMP, Quality "Low"
local LAMP_LIGHT_RADIUS = 260
local LAMP_LIGHT_RESCAN_SECONDS = 2
local lampLights: { [Model]: Attachment } = {}

-- X248: Sky publishes this for the player's own look
local function skyIsDark(): boolean
	return game:GetService("Players").LocalPlayer:GetAttribute("SkyDark") == true
end


local function newLampLight(lamp: LampEntry): Attachment
	local a = Instance.new("Attachment")
	a.Name = "TownLifeLampLight"
	a.Position = lamp.ground + Vector3.new(0, 13.5, 0) + lamp.roadDir * 2.3
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Brightness = 1.6
	light.Range = 32
	light.Shadows = false
	light.Parent = a
	a.Parent = workspace.Terrain
	return a
end

local function rescanLampLights()
	local wanted: { [Model]: LampEntry } = {}
	if skyIsDark() then
		local camPos = currentCameraPosition()
		local points: { Vector3 } = {}
		for _, lamp in allLamps do
			table.insert(points, lamp.ground)
		end
		local max = if isLowQuality() then LAMP_LIGHT_MAX_LOW else LAMP_LIGHT_MAX
		for _, i in TownLifeMath.nearestIndices(points, camPos, max, LAMP_LIGHT_RADIUS) do
			local lamp = allLamps[i]
			if lamp.model.Parent then
				wanted[lamp.model] = lamp
			end
		end
	end
	for model, a in lampLights do
		if not wanted[model] then
			a:Destroy()
			lampLights[model] = nil
		end
	end
	for model, lamp in wanted do
		if not lampLights[model] then
			lampLights[model] = newLampLight(lamp)
		end
	end
end

game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("SkyDark"):Connect(rescanLampLights)

task.spawn(function()
	while true do
		rescanLampLights()
		task.wait(LAMP_LIGHT_RESCAN_SECONDS)
	end
end)

local function checkPhase(folder: Folder)
	local phase = folder:GetAttribute("Phase")
	if phase == "PreMatch" or phase == "Match" then
		if not buntingFolder then
			buildBunting(ClubRef.frame(), currentClubName())
		end
	elseif buntingFolder then
		clearBunting()
	end
	refreshPubs()
end

local function watchClub()
	local folder = ClubRef.waitState()

	folder:GetAttributeChangedSignal("ClubName"):Connect(renameBanners)
	folder:GetAttributeChangedSignal("Phase"):Connect(function()
		checkPhase(folder)
	end)
	checkPhase(folder)

	while true do
		rescanBanners()
		refreshPubs() -- picks up pubs that stream in and Quality changes mid-matchday
		task.wait(BANNER_RESCAN_SECONDS)
	end
end
task.spawn(watchClub)
