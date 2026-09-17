--!strict
-- Plot picker (backlog B2.2, CLAUDE.md s27 "the player switches between the
-- free plots and picks one"). Runs once at join, before the player has a
-- ClubPlot attribute. Every other client script (HUD, Match, ClubPanel,
-- Onboarding) calls ClubRef.waitState() and simply yields until the plot is
-- claimed, so this script is the only one that has to move the camera around
-- an unclaimed town and talk to PlotService directly.
--
-- Server contract (PlotService.luau):
--   ReplicatedStorage.Remotes.ClaimPlot   (client -> server, plot number)
--   ReplicatedStorage.Remotes.PlotsChanged (server -> all, { free, owners })
--   ReplicatedStorage.Plots (Folder): Free / Owners (JSON strings, for a late
--     joiner), View1..View4 (CFrame attributes, the picker's camera spots)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Iris = require(script.Parent.Iris)

local PLOT_COUNT = 4 -- matches PlotService.PLOT_COUNT
local CLAIM_TIMEOUT = 20 -- seconds

local player = Players.LocalPlayer

-- Already have a ground (e.g. a future reconnect-to-same-plot path): nothing to do.
if player:GetAttribute("ClubPlot") ~= nil then
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local claimEvent = remotes:WaitForChild("ClaimPlot") :: RemoteEvent
local plotsChangedEvent = remotes:WaitForChild("PlotsChanged") :: RemoteEvent
local toastEvent = remotes:WaitForChild("Toast") :: RemoteEvent
local plotsFolder = ReplicatedStorage:WaitForChild("Plots") :: Folder

local function decodeNumberList(raw: unknown): { number }
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw :: string)
	end)
	if not ok or type(decoded) ~= "table" then
		return {}
	end
	local list = {}
	for _, v in decoded :: { any } do
		if type(v) == "number" then
			table.insert(list, v)
		end
	end
	return list
end

local function decodeOwners(raw: unknown): { [number]: string }
	local owners: { [number]: string } = {}
	if type(raw) ~= "string" or raw == "" then
		return owners
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw :: string)
	end)
	if not ok or type(decoded) ~= "table" then
		return owners
	end
	for k, v in decoded :: { [string]: any } do
		local n = tonumber(k)
		if n and type(v) == "string" then
			owners[n] = v
		end
	end
	return owners
end

local free: { number } = decodeNumberList(plotsFolder:GetAttribute("Free"))
local owners: { [number]: string } = decodeOwners(plotsFolder:GetAttribute("Owners"))

-- The server only lets a picker exist when there is something to pick: if the
-- server is already full of clubs, stay a visitor with no picker at all.
if #free == 0 then
	return
end

local function viewpointOf(plot: number): CFrame
	local cf = plotsFolder:GetAttribute("View" .. plot)
	return if typeof(cf) == "CFrame" then cf else CFrame.new()
end

-- ------------------------------------------------------------------ camera

local camera = workspace.CurrentCamera :: Camera
camera.CameraType = Enum.CameraType.Scriptable
local flyTween: Tween? = nil
local picking = true
-- the default camera scripts put the camera back on the character when it
-- spawns; keep it on the picker's viewpoints until a ground is chosen
local cameraTypeConn = camera:GetPropertyChangedSignal("CameraType"):Connect(function()
	if picking and camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
end)

local function flyTo(plot: number)
	if flyTween then
		flyTween:Cancel()
	end
	local tween = TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = viewpointOf(plot),
	})
	flyTween = tween
	tween:Play()
end

local function restoreCamera()
	picking = false
	cameraTypeConn:Disconnect()
	if flyTween then
		flyTween:Cancel()
		flyTween = nil
	end
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- --------------------------------------------------------------------- HUD

-- HUD.client.luau yields on ClubRef.waitState() until a plot is claimed, so
-- in practice TycoonHUD does not exist yet here. Handled anyway per spec.
local playerGui = player:WaitForChild("PlayerGui")
local hudGui = playerGui:FindFirstChild("TycoonHUD") :: ScreenGui?
if hudGui then
	hudGui.Enabled = false
end

-- --------------------------------------------------------------------- UI

local gui = Theme.screenGui("PlotPicker", 6)
gui.Parent = playerGui

local panel = Theme.panel(gui, "Panel", {
	Size = UDim2.fromOffset(560, 190),
	Position = UDim2.new(0.5, 0, 1, -40),
	AnchorPoint = Vector2.new(0.5, 1),
})

local title = Theme.text(panel, "CHOOSE YOUR GROUND", "display", {
	Name = "Title",
	Size = UDim2.new(1, -40, 0, 34),
	Position = UDim2.fromOffset(20, 14),
	TextXAlignment = Enum.TextXAlignment.Center,
})

local subtitle = Theme.text(panel, "", "muted", {
	Name = "Subtitle",
	Size = UDim2.new(1, -40, 0, 24),
	Position = UDim2.fromOffset(20, 52),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 16,
})

local messageLabel = Theme.text(panel, "", "body", {
	Name = "Message",
	Size = UDim2.new(1, -40, 0, 20),
	Position = UDim2.fromOffset(20, 78),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextSize = 14,
	TextColor3 = Theme.colors.bad,
	Visible = false,
})

local prevButton = Theme.button(panel, "‹", "secondary", {
	Name = "Prev",
	Size = UDim2.fromOffset(50, 44),
	Position = UDim2.fromOffset(20, 110),
	TextSize = 26,
})
local buildButton = Theme.button(panel, "BUILD MY CLUB HERE", "primary", {
	Name = "Build",
	Size = UDim2.new(1, -160, 0, 44),
	Position = UDim2.fromOffset(80, 110),
	TextSize = 16,
})
local nextButton = Theme.button(panel, "›", "secondary", {
	Name = "Next",
	Size = UDim2.fromOffset(50, 44),
	Position = UDim2.new(1, -70, 0, 110),
	TextSize = 26,
})

-- ------------------------------------------------------------------- state

local currentPlot: number = free[1]
local building = false
local lastToast: string? = nil
local destroyed = false

local function refreshLabels()
	local ownerName = owners[currentPlot]
	subtitle.Text = ("Ground %d of %d — %s"):format(currentPlot, PLOT_COUNT, if ownerName then ("Taken by " .. ownerName) else "for sale")
end

local function cyclePlot(direction: number)
	if building or #free == 0 then
		return
	end
	local idx = table.find(free, currentPlot)
	if not idx then
		currentPlot = free[1]
	else
		idx = ((idx - 1 + direction) % #free) + 1
		currentPlot = free[idx]
	end
	flyTo(currentPlot)
	refreshLabels()
end

local function finish()
	if destroyed then
		return
	end
	destroyed = true
	-- close the iris over the picker, swap to the player's own camera behind
	-- it (they are already standing in their office), then open on the club
	Iris.close(0.4)
	task.wait(0.45)
	restoreCamera()
	if hudGui then
		hudGui.Enabled = true
	end
	gui:Destroy()
	Iris.open(0.6)
end

-- X221: a visitor who joined a full server is offered the picker again when
-- a ground frees up. The picker runs top to bottom once, so it restarts by
-- running a fresh copy of this script.
local function watchForFreeGround()
	local offer: ScreenGui? = nil
	local conn: RBXScriptConnection? = nil
	local function clearOffer()
		if offer then
			offer:Destroy()
			offer = nil
		end
	end
	local function update(freeNow: { number })
		if player:GetAttribute("ClubPlot") ~= nil then
			clearOffer()
			if conn then
				conn:Disconnect()
			end
			return
		end
		if #freeNow == 0 then
			clearOffer()
			return
		end
		if offer then
			return
		end
		local offerGui = Theme.screenGui("GroundFree", 8)
		local button = Theme.button(offerGui, "A ground is free: tap to choose it", "primary", {
			Name = "Choose",
			Size = UDim2.fromOffset(320, 48),
			Position = UDim2.new(0.5, -160, 0, 16),
			TextSize = 16,
		})
		button.Activated:Connect(function()
			if conn then
				conn:Disconnect()
			end
			clearOffer()
			local copy = script:Clone()
			copy.Parent = script.Parent
			script:Destroy()
		end)
		offerGui.Parent = playerGui
		offer = offerGui
	end
	conn = plotsChangedEvent.OnClientEvent:Connect(function(payload: any)
		local list = {}
		for _, v in (payload and payload.free) or {} do
			if type(v) == "number" then
				table.insert(list, v)
			end
		end
		update(list)
	end)
	update(decodeNumberList(plotsFolder:GetAttribute("Free")))
end

local function showAllTaken()
	if destroyed then
		return
	end
	title.Text = "CHOOSE YOUR GROUND"
	subtitle.Text = "All grounds are taken — you're visiting."
	messageLabel.Visible = false
	prevButton.Visible = false
	nextButton.Visible = false
	buildButton.Visible = false
	destroyed = true -- stop reacting to further PlotsChanged events
	task.delay(2.5, function()
		restoreCamera()
		if hudGui then
			hudGui.Enabled = true
		end
		gui:Destroy()
		watchForFreeGround()
	end)
end

local function waitForClaim(timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if player:GetAttribute("ClubPlot") ~= nil then
			return true
		end
		task.wait(0.1)
	end
	return player:GetAttribute("ClubPlot") ~= nil
end

local function onBuild()
	if building or #free == 0 or destroyed then
		return
	end
	building = true
	messageLabel.Visible = false
	buildButton.Text = "BUILDING…"
	buildButton.Active = false
	buildButton.AutoButtonColor = false
	prevButton.Active = false
	nextButton.Active = false
	claimEvent:FireServer(currentPlot)
	task.spawn(function()
		local claimed = waitForClaim(CLAIM_TIMEOUT)
		if claimed then
			finish()
			return
		end
		building = false
		buildButton.Text = "BUILD MY CLUB HERE"
		buildButton.Active = true
		buildButton.AutoButtonColor = true
		prevButton.Active = true
		nextButton.Active = true
		messageLabel.Text = lastToast or "That didn't work. Try again."
		messageLabel.Visible = true
	end)
end

prevButton.Activated:Connect(function()
	cyclePlot(-1)
end)
nextButton.Activated:Connect(function()
	cyclePlot(1)
end)
buildButton.Activated:Connect(onBuild)

local toastConn = toastEvent.OnClientEvent:Connect(function(message: string)
	lastToast = message
end)

local plotsConn = plotsChangedEvent.OnClientEvent:Connect(function(payload: any)
	if destroyed then
		return
	end
	free = (payload and payload.free) or {}
	owners = {}
	for k, v in (payload and payload.owners) or {} do
		local n = tonumber(k)
		if n and type(v) == "string" then
			owners[n] = v
		end
	end
	if table.find(free, currentPlot) then
		refreshLabels()
		return
	end
	if #free == 0 then
		showAllTaken()
		return
	end
	currentPlot = free[1]
	flyTo(currentPlot)
	refreshLabels()
end)

local inputConn = UserInputService.InputBegan:Connect(function(input, processed)
	if processed or destroyed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Left then
		cyclePlot(-1)
	elseif input.KeyCode == Enum.KeyCode.Right then
		cyclePlot(1)
	elseif input.KeyCode == Enum.KeyCode.Return then
		onBuild()
	end
end)
gui.Destroying:Connect(function()
	inputConn:Disconnect()
	toastConn:Disconnect()
	plotsConn:Disconnect()
end)

refreshLabels()
flyTo(currentPlot)
