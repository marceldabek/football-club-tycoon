--!strict
-- Ambient town life that isn't tied to a match (backlog F4.1 wind turbines,
-- H1.1 club banners, G2.1 matchday bunting). CLAUDE.md s27: "Town-wide
-- banners ... show only on that player's screen" -- banners and bunting here
-- only ever show the LOCAL player's own club, never another player's.
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
	if #blades == 0 then
		return
	end
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

	for _, lamp in allLamps do
		local dist = (camPos - lamp.ground).Magnitude
		local hasBanner = activeBanners[lamp.model] ~= nil
		if hasBanner then
			if dist > BANNER_FAR then
				removeBanner(lamp.model)
			end
		elseif dist <= BANNER_NEAR and lamp.index % 2 == 0 and activeBannerCount < BANNER_BUDGET then
			activeBanners[lamp.model] = buildBanner(lamp, clubName)
			activeBannerCount += 1
		end
	end
end

-- ================================================================ bunting

local BUNTING_SPACING = 60
local BUNTING_HEIGHT = 14
local BUNTING_STRING_BUDGET = 40
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

	local built = 0
	for _, road in closestResidentialRoads(plotCFrame.Position) do
		if built >= BUNTING_STRING_BUDGET then
			break
		end
		local width = road.width + 16
		for _, station in TownLifeMath.stationsAlong(road.points, BUNTING_SPACING) do
			if built >= BUNTING_STRING_BUDGET then
				break
			end
			buildBuntingCrossing(folder, station, width, kit)
			built += 1
		end
	end

	folder.Parent = root
	buntingFolder = folder
end

-- ------------------------------------------------------- club-driven watcher

local function checkPhase(folder: Folder)
	local phase = folder:GetAttribute("Phase")
	if phase == "PreMatch" or phase == "Match" then
		if not buntingFolder then
			buildBunting(ClubRef.frame(), currentClubName())
		end
	elseif buntingFolder then
		clearBunting()
	end
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
		task.wait(BANNER_RESCAN_SECONDS)
	end
end
task.spawn(watchClub)
