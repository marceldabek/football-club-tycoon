--!strict
-- The very first thing a player sees (docs/SOFT_LAUNCH.md SL13). A fresh
-- server spends 10+ seconds building the town before PlotService exists, and
-- a player who joined in that window stood in an unbuilt town with no UI.
-- ReplicatedFirst runs before anything else replicates, so this cover is up
-- from the first frame and comes down when the server stamps TownReady.
-- Kept dependency-free on purpose: Shared may not have replicated yet.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local READY_ATTRIBUTE = "TownReady" -- set by Main.server once PlotService is up
local MAX_WAIT = 90 -- never trap a player behind the cover if the server is stuck

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "FirstLoad"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000

local cover = Instance.new("Frame")
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.fromRGB(16, 20, 26) -- Theme.colors.bg
cover.BorderSizePixel = 0
cover.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.9, 0, 0, 44)
title.Position = UDim2.fromScale(0.5, 0.44)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 34
title.TextColor3 = Color3.fromRGB(255, 205, 80) -- Theme.colors.accent
title.Text = "FOOTBALL CLUB TYCOON"
title.TextScaled = true
title.Parent = cover

local line = Instance.new("TextLabel")
line.Size = UDim2.new(0.9, 0, 0, 30)
line.Position = UDim2.fromScale(0.5, 0.52)
line.AnchorPoint = Vector2.new(0.5, 0.5)
line.BackgroundTransparency = 1
line.Font = Enum.Font.Gotham
line.TextSize = 18
line.TextColor3 = Color3.fromRGB(158, 166, 178) -- Theme.colors.muted
line.Text = "Welcome to Rivermere…"
line.Parent = cover

local beta = Instance.new("TextLabel")
beta.Size = UDim2.new(1, -24, 0, 20)
beta.Position = UDim2.new(0, 12, 1, -28)
beta.BackgroundTransparency = 1
beta.Font = Enum.Font.Gotham
beta.TextSize = 14
beta.TextXAlignment = Enum.TextXAlignment.Left
beta.TextColor3 = Color3.fromRGB(158, 166, 178)
beta.Text = "BETA - your club is saved and carries over"
beta.Parent = cover

gui.Parent = playerGui

-- the build number, once Shared has replicated (it need not have yet)
task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 30)
	local module = shared and shared:WaitForChild("Build", 30)
	if module and beta.Parent then
		local ok, build = pcall(require, module)
		if ok then
			beta.Text = ("%s - your club is saved and carries over"):format(build.label())
		end
	end
end)

-- the town build is the long part on a cold server; a warm one is ready at once
local started = os.clock()
local dots = 0
while ReplicatedStorage:GetAttribute(READY_ATTRIBUTE) ~= true do
	if os.clock() - started > MAX_WAIT then
		warn("[FCT] loading screen gave up waiting for TownReady")
		break
	end
	local waited = os.clock() - started
	if waited > 4 then
		dots = (dots + 1) % 4
		line.Text = "The town is still being built" .. string.rep(".", dots)
	end
	task.wait(0.5)
end

local fade = TweenService:Create(cover, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
for _, label in { title, line, beta } do
	TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
end
fade:Play()
fade.Completed:Wait()
gui:Destroy()
