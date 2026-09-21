--!strict
-- The four club plots on this server (CLAUDE.md s27, docs/PLOTS.md).
--   join   -> the client's PlotPicker shows the free plots -> ClaimPlot ->
--             the club services are cloned for that plot -> their club loads
--             and builds -> they are sent to their office
--   leave  -> save, despawn the club, the plot goes back to a for-sale lot
-- Global: never cloned per plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local PlotRegistry = require(ReplicatedStorage.Shared.PlotRegistry)
local RemoteRouter = require(script.Parent.RemoteRouter)
local TreeKit = require(script.Parent.TreeKit)

local PlotService = {}

local PLOT_COUNT = 4
local PLOT_SIZE = 760 -- TEMP, matches docs/BACKLOG.md world frame
local GO_HOME_COOLDOWN = 5 -- TEMP seconds (backlog B4.2)

-- Everything a club needs its own copy of. Order does not matter.
local PER_CLUB = {
	"PlotContext",
	"ClubState",
	"WorldBuilder",
	"MatchService",
	"UpgradeService",
	"ClubService",
	"SeasonService",
	"HistoryService",
	"Session",
	"Assets",
	"SaveService",
	"SaveLock",
	"Scenery",
	"PlotGrounds",
	-- X369: PlotGrounds builds the entrance wall from the kit. Every module here
	-- reaches its neighbours as script.Parent.<name>, which resolves against the
	-- per-plot folder, so anything a cloned module requires must be cloned too.
	-- PerClubModulesTest checks that; it is not obvious from reading PlotGrounds.
	"KitPlacer",
	"TreeKit", -- PlotGrounds' pathside oaks and bushes
	"GroundsPlanting", -- PlotGrounds' hedges, groves and boulders
	"Clubhouse", -- WorldBuilder builds the office and dressing rooms through it
}

-- exposed so PerClubModulesTest can check the list against what the cloned
-- modules actually require
PlotService.PER_CLUB = PER_CLUB

type Runtime = {
	folder: Folder,
	owner: Player,
	session: any,
	match: any,
}

local registry = PlotRegistry.new(PLOT_COUNT)
local runtimes: { [number]: Runtime } = {}
local runtimeRoot: Folder
-- Guards a double ClaimPlot fire (double-click, laggy client) while a claim
-- for that player is still in flight (session.start yields on the save load).
local claiming: { [number]: boolean } = {}
-- X208: clubs whose owner left mid-match; the match finishes (and saves)
-- before the session stops. BindToClose still stops them.
local finishing: { [Runtime]: boolean } = {}
local lastGoHome: { [number]: number } = {}

local function findOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function remote(name: string): RemoteEvent
	local remotes = findOrCreate(ReplicatedStorage, "Remotes", "Folder")
	return findOrCreate(remotes, name, "RemoteEvent") :: RemoteEvent
end

local function toast(player: Player, message: string, ok: boolean?)
	remote("Toast"):FireClient(player, message, ok)
end

local function plotsFolder(): Folder
	return findOrCreate(ReplicatedStorage, "Plots", "Folder") :: Folder
end

-- Shared.TownLayout if it is present and loads, else nil.
local function townLayout(): any
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local layoutModule = shared and shared:FindFirstChild("TownLayout")
	if layoutModule and layoutModule:IsA("ModuleScript") then
		local ok, layout = pcall(require, layoutModule)
		if ok and type(layout) == "table" then
			return layout
		end
	end
	return nil
end

function PlotService.plotCFrame(plot: number): CFrame
	local layout = townLayout()
	if layout and type(layout.plotCFrame) == "function" then
		return layout.plotCFrame(plot)
	end
	-- v3 Lane I stage 2: the v1 corner-of-town fallback sites are gone (Plot 3 moved
	-- to the south-west); the plots live in Shared.TownLayout.PLOTS and nowhere else.
	error("PlotService.plotCFrame: Shared.TownLayout is missing or failed to load")
end

-- Where the picker's camera looks at this plot from: outside the entrance
-- side (pitch-local -X), low enough to read the FOR SALE board, looking in.
function PlotService.viewpoint(plot: number): CFrame
	return PlotService.plotCFrame(plot) * CFrame.lookAt(Vector3.new(-600, 120, -220), Vector3.new(-220, 0, 40))
end

-- Tells every client which plots are free/taken, and mirrors it as attributes
-- on ReplicatedStorage.Plots so a late joiner can read it before any event
-- has fired.
local function broadcastPlots()
	local free = registry:freePlots()
	local owners: { [string]: string } = {}
	for plot = 1, PLOT_COUNT do
		local userId = registry:ownerOf(plot)
		local ownerPlayer = userId and Players:GetPlayerByUserId(userId)
		if ownerPlayer then
			owners[tostring(plot)] = ownerPlayer.DisplayName
		end
	end
	remote("PlotsChanged"):FireAllClients({ free = free, owners = owners })
	local folder = plotsFolder()
	folder:SetAttribute("Free", HttpService:JSONEncode(free))
	folder:SetAttribute("Owners", HttpService:JSONEncode(owners))
end

local function plotModel(plot: number): Model
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		plots = Instance.new("Folder")
		plots.Name = "Plots"
		plots.Parent = workspace
	end
	local model = plots:FindFirstChild("Plot" .. plot) :: Model?
	if not model then
		model = Instance.new("Model")
		;(model :: Model).Name = "Plot" .. plot
		;(model :: Model).Parent = plots
	end
	return model :: Model
end

-- Streaming follows the character, which stands in the town square while the
-- picker's camera looks at a plot 1,400+ studs away. Terrain that has not
-- streamed in is drawn as a coarse stand-in several studs too low, so the
-- (Persistent) lot and the client's walkers looked like they were floating.
-- While a player is picking, their streaming centre is this anchor instead:
-- on the ground where the viewpoint looks, so the default target radius
-- covers everything from under the camera to the far edge of the plot.
local function pickerFocus(plot: number): Part
	local model = plotModel(plot)
	local focus = model:FindFirstChild("PickerFocus") :: Part?
	if not focus then
		local p = Instance.new("Part")
		p.Name = "PickerFocus"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.CFrame = PlotService.plotCFrame(plot) * CFrame.new(-220, 0, 40)
		p.Parent = model
		focus = p
	end
	return focus :: Part
end

-- ------------------------------------------------------------- for-sale lot

local function lotPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- An empty plot: rough grass, a council "for sale" board, a few trees and
-- rocks and a line of fence posts along the road side (Q16).
local function buildLot(plot: number)
	local model = plotModel(plot)
	local old = model:FindFirstChild("Lot")
	if old then
		old:Destroy()
	end
	local lot = Instance.new("Model")
	lot.Name = "Lot"
	-- ~30 parts; always streamed so the picker's camera can see every free plot
	lot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local frame = PlotService.plotCFrame(plot)
	local half = PLOT_SIZE / 2
	local rng = Random.new(plot * 97)

	lotPart(lot, "Scrub", Vector3.new(PLOT_SIZE - 40, 0.2, PLOT_SIZE - 40), frame * CFrame.new(0, 0.1, 0),
		Color3.fromRGB(116, 128, 74), Enum.Material.Grass)

	-- fence posts on the entrance side (pitch-local -X faces the road)
	for z = -half + 30, half - 30, 24 do
		lotPart(lot, "Post", Vector3.new(0.8, 4, 0.8), frame * CFrame.new(-half + 16, 2, z),
			Color3.fromRGB(110, 85, 60), Enum.Material.Wood)
	end

	-- the sign, facing the road
	local board = lotPart(lot, "ForSaleBoard", Vector3.new(0.6, 9, 16), frame * CFrame.new(-half + 30, 9, 0),
		Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic)
	for _, zSide in { -6, 6 } do
		lotPart(lot, "SignLeg", Vector3.new(0.6, 9, 0.6), frame * CFrame.new(-half + 30.6, 4.5, zSide),
			Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(245, 245, 240)
	label.TextColor3 = Color3.fromRGB(30, 50, 110)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.RichText = true
	label.Text = ("FOR SALE\n<font size=\"30\">Club ground %d\nRivermere Borough Council</font>"):format(plot)
	label.Parent = gui

	-- trees and rocks
	for i = 1, 9 do
		local x = rng:NextNumber(-half + 80, half - 60)
		local z = rng:NextNumber(-half + 60, half - 60)
		local h = rng:NextNumber(14, 24)
		local crownSize = rng:NextNumber(14, 22)
		-- the slice's oaks, full size; the trunk and ball crown only when the place
		-- has no oak pack. Its own stream, so the rocks stay where they were.
		if not TreeKit.tree(lot, (frame * CFrame.new(x, 0, z)).Position, { height = h + 14, rng = Random.new(plot * 977 + i) }) then
			lotPart(lot, "Trunk", Vector3.new(2, h, 2), frame * CFrame.new(x, h / 2, z), Color3.fromRGB(95, 70, 50), Enum.Material.Wood)
			local crown = lotPart(lot, "Crown", Vector3.new(1, 1, 1) * crownSize, frame * CFrame.new(x, h + 4, z),
				Color3.fromRGB(70, 110, 55), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
		if i % 2 == 0 then
			local r = rng:NextNumber(3, 7)
			lotPart(lot, "Rock", Vector3.new(r * 1.4, r, r), frame * CFrame.new(x + 20, r / 2 - 0.5, z + 12) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2),
				Color3.fromRGB(120, 118, 112), Enum.Material.Slate)
		end
	end

	-- X85: overgrown waste ground rather than a mown lawn: a worn footpath from
	-- the sign across the lot, patches of long rough grass, bramble clumps.
	-- Tops step 0.2 (scrub) < 0.26 (path) < 0.32 (patches) so no faces share a plane.
	-- A separate random stream keeps the trees and rocks where they were.
	local rough = Random.new(plot * 131)
	lotPart(lot, "Footpath", Vector3.new(PLOT_SIZE - 120, 0.26, 5), frame * CFrame.new(-half + 60 + (PLOT_SIZE - 120) / 2, 0.13, 8) * CFrame.Angles(0, 0.08, 0),
		Color3.fromRGB(128, 112, 86), Enum.Material.Ground).CastShadow = false
	-- each patch is two overlapping discs (X86: rectangles read as hard-edged),
	-- the second 0.02 higher so their tops never share a plane
	for _ = 1, 6 do
		local cx, cz = rough:NextNumber(-half + 90, half - 90), rough:NextNumber(-half + 80, half - 80)
		for k = 0, 1 do
			local d = rough:NextNumber(50, 100)
			local top = 0.32 + k * 0.02
			local patch = lotPart(lot, "RoughGrass", Vector3.new(top, d, d),
				frame * CFrame.new(cx + k * rough:NextNumber(-35, 35), top / 2, cz + k * rough:NextNumber(-35, 35)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(84, 104, 46), Enum.Material.LeafyGrass)
			patch.Shape = Enum.PartType.Cylinder
			patch.CastShadow = false
			patch.CanCollide = false
		end
	end
	for _ = 1, 12 do
		local r = rough:NextNumber(9, 16)
		local bx, bz = rough:NextNumber(-half + 50, half - 30), rough:NextNumber(-half + 30, half - 30)
		if TreeKit.bush(lot, (frame * CFrame.new(bx, 0, bz)).Position, { width = r, rng = Random.new(plot * 613 + math.floor(bx)), name = "Bramble" }) then
			continue
		end
		local bramble = lotPart(lot, "Bramble", Vector3.one * r, frame * CFrame.new(bx, r * 0.25, bz),
			Color3.fromRGB(58, 80, 42), Enum.Material.LeafyGrass)
		bramble.Shape = Enum.PartType.Ball
		bramble.CastShadow = false
	end
	lot.Parent = model
end

local function removeLot(plot: number)
	local lot = plotModel(plot):FindFirstChild("Lot")
	if lot then
		lot:Destroy()
	end
end

-- ------------------------------------------------------------------- clubs

local function officeSpawn(plot: number): SpawnLocation?
	local club = plotModel(plot):FindFirstChild("Club")
	local spawn = club and club:FindFirstChild("OfficeSpawn", true)
	return if spawn and spawn:IsA("SpawnLocation") then spawn else nil
end

-- Puts an owner's character in their office.
function PlotService.sendHome(player: Player)
	local plot = registry:plotOf(player.UserId)
	local spawn = plot and officeSpawn(plot)
	local character = player.Character
	if spawn and character then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
	end
end

function PlotService.claim(player: Player, plot: number): (boolean, string?)
	local ok, why = registry:claim(player.UserId, plot)
	if not ok then
		return false, why
	end
	if runtimes[plot] then
		return true, "already running"
	end
	player:SetAttribute("ClubPlot", plot)
	player.ReplicationFocus = nil -- picking is over: streaming follows the character again
	removeLot(plot)

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. plot
	folder:SetAttribute("PlotIndex", plot)
	folder:SetAttribute("PlotCFrame", PlotService.plotCFrame(plot))
	folder:SetAttribute("OwnerUserId", player.UserId)
	local source = script.Parent
	for _, name in PER_CLUB do
		local original = source:FindFirstChild(name)
		assert(original, "PlotService: missing module " .. name)
		original:Clone().Parent = folder
	end
	folder.Parent = runtimeRoot

	-- a module error while loading must not leave the plot half-claimed
	local loaded, result = pcall(function()
		local session = require(folder:FindFirstChild("Session") :: ModuleScript) :: any
		local match = require(folder:FindFirstChild("MatchService") :: ModuleScript) :: any
		local runtime: Runtime = { folder = folder, owner = player, session = session, match = match }
		runtimes[plot] = runtime
		return session.start(player)
	end)
	if not loaded or not result then
		warn(("[FCT] plot %d failed to start for %s: %s"):format(plot, player.Name, tostring(result)))
		if not runtimes[plot] then
			folder:Destroy()
			player:SetAttribute("ClubPlot", nil)
			registry:release(player.UserId)
			buildLot(plot)
			return false, "load failed"
		end
		PlotService.release(player)
		return false, "load failed"
	end
	-- office spawns are not random spawn points; owners are placed by hand.
	-- WorldBuilder now creates it disabled (X278); this stays as a belt and braces.
	local spawn = officeSpawn(plot)
	if spawn then
		spawn.Enabled = false
	end
	PlotService.sendHome(player)
	return true
end

-- Despawn: save, remove the club, give the plot back once any match still
-- running in the old copy has wound down (it keeps writing to its own state).
function PlotService.release(player: Player)
	local plot = registry:plotOf(player.UserId)
	if not plot then
		return
	end
	if player.Parent then
		player:SetAttribute("ClubPlot", nil)
	end
	local runtime = runtimes[plot]
	runtimes[plot] = nil
	RemoteRouter.unbindPlot(plot)
	claiming[player.UserId] = nil
	lastGoHome[player.UserId] = nil
	if runtime then
		finishing[runtime] = true
	end
	task.spawn(function()
		-- X208: a match still in progress plays out and settles (result, cash,
		-- injuries, table) and is saved before the session stops; stopping first
		-- dropped it from the save, so quitting a losing match dodged the result
		local deadline = os.clock() + 180
		while runtime and runtime.match.isRunning() and os.clock() < deadline do
			task.wait(1)
		end
		if runtime then
			local ok, err = pcall(runtime.session.stop)
			if not ok then
				warn("[FCT] session stop failed: " .. tostring(err))
			end
			finishing[runtime] = nil
			runtime.folder:Destroy()
		end
		local stale = plotModel(plot):FindFirstChild("Club")
		if stale then
			stale:Destroy()
		end
		registry:release(player.UserId)
		buildLot(plot)
		broadcastPlots()
	end)
end

function PlotService.plotOf(player: Player): number?
	return registry:plotOf(player.UserId)
end

-- The running club a player owns: plot index, owner and its MatchService copy.
-- Cross-club features (friendlies) go through this rather than reaching into
-- another plot's modules themselves.
function PlotService.clubOf(userId: number): (number?, Player?, any)
	local plot = registry:plotOf(userId)
	local runtime = plot and runtimes[plot]
	if not runtime then
		return nil, nil, nil
	end
	return plot, runtime.owner, runtime.match
end

-- The per-club module copies a cross-club feature needs (trades), or nil.
function PlotService.modulesFor(userId: number): { [string]: any }?
	local plot = registry:plotOf(userId)
	local runtime = plot and runtimes[plot]
	if not runtime then
		return nil
	end
	local folder = runtime.folder
	return {
		plot = plot,
		owner = runtime.owner,
		session = runtime.session,
		match = runtime.match,
		club = require(folder:FindFirstChild("ClubService") :: ModuleScript),
		state = require(folder:FindFirstChild("ClubState") :: ModuleScript),
	}
end

-- Same as clubOf, looked up by plot index.
function PlotService.clubAt(plot: number): (Player?, any)
	local runtime = runtimes[plot]
	if not runtime then
		return nil, nil
	end
	return runtime.owner, runtime.match
end

-- The required module copies of the first running club, for Studio debug commands.
function PlotService.debugModules(plot: number?): { [string]: any }?
	local runtime: Runtime? = nil
	if plot then
		runtime = runtimes[plot]
	else
		for i = 1, PLOT_COUNT do
			if runtimes[i] then
				runtime = runtimes[i]
				break
			end
		end
	end
	if not runtime then
		return nil
	end
	local modules = {}
	for _, name in PER_CLUB do
		modules[name] = require(runtime.folder:FindFirstChild(name) :: ModuleScript)
	end
	return modules
end

-- ------------------------------------------------------------------- boot

local function townSpawn()
	if workspace:FindFirstChild("TownSpawn") then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	-- TEMP: market square, until the picker owns the camera
	local layout = townLayout()
	local centre = if layout and type(layout.SQUARE) == "table" and typeof(layout.SQUARE.centre) == "Vector3"
		then layout.SQUARE.centre :: Vector3
		else Vector3.zero
	-- between the clock tower planters (r 17) and the market stalls (r 43)
	spawn.CFrame = CFrame.new(centre.X + 30, 1, centre.Z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace
end

-- ClaimPlot (client -> server, arg: plot number). The client's PlotPicker
-- calls this once the player has chosen a free ground.
local function onClaimPlot(player: Player, rawPlot: unknown)
	local ownPlot = registry:plotOf(player.UserId)
	if ownPlot then
		-- X206: a rejoin while the last visit's club is still finishing its match
		-- and saving; say so instead of silently ignoring the click
		if not runtimes[ownPlot] then
			toast(player, "Your club is still finishing its last match. Try again in a moment.")
		end
		return -- already owns a plot: ignore (idempotent-ish, no toast needed)
	end
	if claiming[player.UserId] then
		return -- a claim for this player is already in flight
	end
	local plot = tonumber(rawPlot)
	if not plot then
		return
	end
	plot = math.floor(plot)
	claiming[player.UserId] = true
	local ok, why = PlotService.claim(player, plot)
	claiming[player.UserId] = nil
	if not ok then
		toast(player, why or "Could not claim that ground")
	end
	broadcastPlots()
end

-- PickerView (client -> server, arg: the plot the picker's camera is on, or
-- nil when the picker closes without a claim). See pickerFocus.
local function onPickerView(player: Player, rawPlot: unknown)
	local plot = tonumber(rawPlot)
	plot = plot and math.floor(plot)
	if not plot or plot < 1 or plot > PLOT_COUNT or registry:plotOf(player.UserId) then
		player.ReplicationFocus = nil
		return
	end
	player.ReplicationFocus = pickerFocus(plot)
end

-- GoHome (client -> server, no args): "Go to my club" HUD button (B4.2).
local function onGoHome(player: Player)
	local plot = registry:plotOf(player.UserId)
	if not plot then
		return -- visitor: nothing to go home to
	end
	-- X251: the walkout and the match own the camera; a teleport home mid-match
	-- dropped the owner in the office while the pitch kept panning
	local modules = PlotService.modulesFor(player.UserId)
	local phase = modules and modules.state.get("Phase")
	if phase == "PreMatch" or phase == "Match" then
		toast(player, "Your match is on. You're already at your ground.")
		return
	end
	local now = os.clock()
	local last = lastGoHome[player.UserId]
	if last and now - last < GO_HOME_COOLDOWN then
		toast(player, "Wait a moment")
		return
	end
	lastGoHome[player.UserId] = now
	PlotService.sendHome(player)
end

function PlotService.start()
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "ClubRuntime"
	runtimeRoot.Parent = ServerScriptService
	townSpawn()
	-- new arrivals start in the town square; other spawn points in the place
	-- (the vertical slice's review spawn) must not steal them
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d.Name ~= "TownSpawn" then
			d.Enabled = false
		end
	end
	-- the picker listens for toasts before any club has created the remote
	remote("Toast")
	for plot = 1, PLOT_COUNT do
		buildLot(plot)
	end

	local folder = plotsFolder()
	for plot = 1, PLOT_COUNT do
		folder:SetAttribute("View" .. plot, PlotService.viewpoint(plot))
	end
	broadcastPlots()

	remote("ClaimPlot").OnServerEvent:Connect(onClaimPlot)
	remote("GoHome").OnServerEvent:Connect(onGoHome)
	remote("PickerView").OnServerEvent:Connect(onPickerView)

	local function onJoin(player: Player)
		-- owners respawn in their office; everyone else spawns at TownSpawn
		-- and picks a ground through the client's PlotPicker (backlog B2.2)
		player.CharacterAdded:Connect(function()
			task.defer(PlotService.sendHome, player)
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(PlotService.release)
	game:BindToClose(function()
		for _, runtime in runtimes do
			-- one club failing to save must not skip the others
			pcall(runtime.session.stop)
		end
		for runtime in finishing do
			pcall(runtime.session.stop)
		end
	end)
end

return PlotService
