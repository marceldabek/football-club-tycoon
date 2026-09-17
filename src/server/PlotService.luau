--!strict
-- The four club plots on this server (CLAUDE.md s27, docs/PLOTS.md).
--   join   -> the player picks a free plot (TEMP: auto-assigned until the
--             picker lands) -> the club services are cloned for that plot ->
--             their club loads and builds -> they are sent to their office
--   leave  -> save, despawn the club, the plot goes back to a for-sale lot
-- Global: never cloned per plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotRegistry = require(ReplicatedStorage.Shared.PlotRegistry)
local RemoteRouter = require(script.Parent.RemoteRouter)

local PlotService = {}

local PLOT_COUNT = 4
local PLOT_SIZE = 760 -- TEMP, matches docs/BACKLOG.md world frame

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
}

-- TEMP plot sites until Shared.TownLayout exists: the four corners of the
-- town, entrances (pitch-local -X) facing the middle.
local FALLBACK_SITES = {
	CFrame.new(1500, 0, 1100) * CFrame.Angles(0, math.rad(180), 0), -- 1 SE
	CFrame.new(1500, 0, -1100) * CFrame.Angles(0, math.rad(180), 0), -- 2 NE
	CFrame.new(2000, 0, 0) * CFrame.Angles(0, math.rad(180), 0), -- 3 E
	CFrame.new(-1500, 0, -1100), -- 4 NW
}

type Runtime = {
	folder: Folder,
	owner: Player,
	session: any,
	match: any,
}

local registry = PlotRegistry.new(PLOT_COUNT)
local runtimes: { [number]: Runtime } = {}
local runtimeRoot: Folder

function PlotService.plotCFrame(plot: number): CFrame
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local layoutModule = shared and shared:FindFirstChild("TownLayout")
	if layoutModule and layoutModule:IsA("ModuleScript") then
		local ok, layout = pcall(require, layoutModule)
		if ok and type(layout) == "table" and type((layout :: any).plotCFrame) == "function" then
			return (layout :: any).plotCFrame(plot)
		end
	end
	return FALLBACK_SITES[plot]
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
		lotPart(lot, "Trunk", Vector3.new(2, h, 2), frame * CFrame.new(x, h / 2, z), Color3.fromRGB(95, 70, 50), Enum.Material.Wood)
		local crown = lotPart(lot, "Crown", Vector3.new(1, 1, 1) * rng:NextNumber(14, 22), frame * CFrame.new(x, h + 4, z),
			Color3.fromRGB(70, 110, 55), Enum.Material.Grass)
		crown.Shape = Enum.PartType.Ball
		if i % 2 == 0 then
			local r = rng:NextNumber(3, 7)
			lotPart(lot, "Rock", Vector3.new(r * 1.4, r, r), frame * CFrame.new(x + 20, r / 2 - 0.5, z + 12) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2),
				Color3.fromRGB(120, 118, 112), Enum.Material.Slate)
		end
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
	-- office spawns are not random spawn points; owners are placed by hand
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
	if runtime then
		local ok, err = pcall(runtime.session.stop)
		if not ok then
			warn("[FCT] session stop failed: " .. tostring(err))
		end
	end
	task.spawn(function()
		local deadline = os.clock() + 180
		while runtime and runtime.match.isRunning() and os.clock() < deadline do
			task.wait(1)
		end
		if runtime then
			runtime.folder:Destroy()
		end
		local stale = plotModel(plot):FindFirstChild("Club")
		if stale then
			stale:Destroy()
		end
		registry:release(player.UserId)
		buildLot(plot)
	end)
end

function PlotService.plotOf(player: Player): number?
	return registry:plotOf(player.UserId)
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
	spawn.CFrame = CFrame.new(0, 0.5, 0) -- TEMP: market square, until the picker owns the camera
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace
end

function PlotService.start()
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "ClubRuntime"
	runtimeRoot.Parent = ServerScriptService
	townSpawn()
	for plot = 1, PLOT_COUNT do
		buildLot(plot)
	end

	local function onJoin(player: Player)
		-- owners respawn in their office
		player.CharacterAdded:Connect(function()
			task.defer(PlotService.sendHome, player)
		end)
		-- TEMP until the plot picker (backlog B2.2): first free plot
		local plot = registry:firstFree()
		if not plot then
			return -- server full of clubs: a visitor
		end
		local ok, why = PlotService.claim(player, plot)
		if not ok then
			warn(("[FCT] could not claim plot %d for %s: %s"):format(plot, player.Name, tostring(why)))
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(PlotService.release)
	game:BindToClose(function()
		for _, runtime in runtimes do
			runtime.session.stop()
		end
	end)
end

return PlotService
