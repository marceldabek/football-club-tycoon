--!strict
-- X279: a player who joins a server with all four grounds taken never gets a
-- HUD — HUD.client.luau yields on ClubRef.waitState() forever — so they had no
-- music switch, no quality switch and, worse, no toast layer: every message the
-- server sent them (including the visitor-only refusals, "Get to a bus stop
-- first", a friendly declined, a trade cancelled) went nowhere while they stood
-- in the heaviest part of the map.
--
-- This screen carries those three things for a visitor only. It appears once
-- the picker has finished and the player still has no ground, and destroys
-- itself the moment they do get one (the real HUD takes over).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local MatchAudio = require(script.Parent.MatchAudio)

local player = Players.LocalPlayer
local C = Theme.colors
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local toastEvent = remotes:WaitForChild("Toast") :: RemoteEvent

local gui: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}

local function teardown()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	local g = gui
	gui = nil
	if g then
		g:Destroy()
	end
end

local function build()
	if gui then
		return
	end
	local screen = Theme.screenGui("VisitorOverlay", 2)
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen

	-- same place and style as the HUD's, so the town looks the same either way
	local musicButton = Theme.button(screen, "", "ghost", {
		Name = "MusicToggle",
		Size = UDim2.fromOffset(130, 34),
		Position = UDim2.new(1, -20, 0, 52),
		AnchorPoint = Vector2.new(1, 0),
	})
	local function refreshMusic()
		local on = MatchAudio.isMusicEnabled()
		musicButton.Text = on and "♪  Music on" or "♪  Music off"
		musicButton.TextColor3 = on and C.text or C.muted
	end
	table.insert(connections, musicButton.Activated:Connect(function()
		MatchAudio.setMusicEnabled(not MatchAudio.isMusicEnabled())
		refreshMusic()
	end))
	refreshMusic()

	local toastLabel = Theme.pill(screen, "Toast", {
		Size = UDim2.new(0.6, 0, 0, 36),
		Position = UDim2.new(0.5, 0, 1, -72),
		AnchorPoint = Vector2.new(0.5, 1),
		TextColor3 = C.bad,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Visible = false,
	})
	local sizeCap = Instance.new("UITextSizeConstraint")
	sizeCap.MaxTextSize = 17
	sizeCap.Parent = toastLabel
	local widthCap = Instance.new("UISizeConstraint")
	widthCap.MaxSize = Vector2.new(760, 36)
	widthCap.Parent = toastLabel

	local token = 0
	table.insert(connections, toastEvent.OnClientEvent:Connect(function(message: string, ok: boolean?)
		token += 1
		local mine = token
		toastLabel.Text = message
		toastLabel.TextColor3 = if ok then C.good else C.bad
		toastLabel.Visible = true
		task.delay(2.5, function()
			if token == mine and toastLabel.Parent then
				toastLabel.Visible = false
			end
		end)
	end))
end

local function hasGround(): boolean
	return player:GetAttribute("ClubPlot") ~= nil
end

player:GetAttributeChangedSignal("ClubPlot"):Connect(function()
	if hasGround() then
		teardown()
	end
end)

task.spawn(function()
	-- give the picker its turn: it owns the screen while a ground can still be
	-- claimed, and a claim clears this anyway
	task.wait(6)
	while true do
		if hasGround() then
			teardown()
			break -- the club's own HUD owns the screen from here on
		elseif not player.PlayerGui:FindFirstChild("PlotPicker") then
			build()
		end
		task.wait(2)
	end
end)
