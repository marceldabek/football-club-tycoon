--!strict
-- While watching another club's live match (I2.1), a small pill at the top
-- shows its score and minute (X38). Match.client sets the local-only player
-- attribute WatchingPlot; the numbers come from ReplicatedStorage.Clubs.PlotN.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubCard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClubCard"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local player = Players.LocalPlayer

local gui = Theme.screenGui("SpectatorPill", 2)
local pill = Theme.pill(gui, "Watching", {
	Size = UDim2.fromOffset(460, 36),
	Position = UDim2.new(0.5, 0, 0, 106), -- under the PLAY MATCH button
	AnchorPoint = Vector2.new(0.5, 0),
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
})
gui.Parent = player:WaitForChild("PlayerGui")

local watchConnection: RBXScriptConnection? = nil

local function refresh(folder: Instance?)
	if folder and folder:GetAttribute("Phase") == "Match" then
		pill.Text = ClubCard.watchingLine(folder:GetAttributes())
		pill.Visible = true
	else
		pill.Visible = false
	end
end

local function onWatching()
	if watchConnection then
		watchConnection:Disconnect()
		watchConnection = nil
	end
	local plot = player:GetAttribute("WatchingPlot")
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local folder = if type(plot) == "number" and clubs then clubs:FindFirstChild("Plot" .. plot) else nil
	if folder then
		watchConnection = folder.AttributeChanged:Connect(function()
			refresh(folder)
		end)
	end
	refresh(folder)
end

player:GetAttributeChangedSignal("WatchingPlot"):Connect(onWatching)
onWatching()
