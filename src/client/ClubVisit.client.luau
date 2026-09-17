--!strict
-- Visiting another club (I1.1): its office computer gets a local "View club"
-- prompt that opens a read-only card (standing, record, ground, best players).
-- Everything comes from ReplicatedStorage.Clubs.PlotN, which every client
-- already receives. From the card an owner can challenge the club to a
-- friendly (I3.1) or open the trade screen (I4.1, TradePanel).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClubCard = require(Shared:WaitForChild("ClubCard"))
local PlotVisit = require(Shared:WaitForChild("PlotVisit"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local TradePanel = require(script.Parent:WaitForChild("TradePanel"))

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("Plots", math.huge) :: Instance
local C = Theme.colors

local CLOSE_DISTANCE = 24

local gui = Theme.screenGui("ClubVisit", 6)
local card = Theme.card(gui, "Card", "VISITING", UDim2.fromOffset(460, 390), UDim2.fromScale(0.5, 0.48))
local closeButton = card.addButton("Close", "secondary")
local challengeButton = card.addButton("Challenge", "primary")
challengeButton.Text = "Play a friendly"
local tradeButton = card.addButton("Trade", "info")
tradeButton.Text = "Trade players"
challengeButton.LayoutOrder = 1
tradeButton.LayoutOrder = 2
closeButton.LayoutOrder = 3
for _, b in { challengeButton, tradeButton, closeButton } do
	b.Size = UDim2.fromOffset(134, 44)
	b.TextSize = 15
end
gui.Parent = player:WaitForChild("PlayerGui")
local challengeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FriendlyChallenge") :: RemoteEvent

local openAt: BasePart? = nil
local openPlot: number? = nil
local openName = ""

local function close()
	card.frame.Visible = false
	openAt = nil
	openPlot = nil
end

local function clubFolder(plot: number): Folder?
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local folder = clubs and clubs:FindFirstChild("Plot" .. plot)
	return if folder and folder:IsA("Folder") then folder else nil
end

local function open(plot: number, at: BasePart)
	local folder = clubFolder(plot)
	if not folder then
		return
	end
	local attrs = folder:GetAttributes()
	local club = nil
	if type(attrs.Club) == "string" and attrs.Club ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, attrs.Club)
		club = if ok then decoded else nil
	end
	local s = ClubCard.summary(attrs, club)
	card.title.Text = string.upper(s.clubName)
	local lines = {
		Theme.rich(s.league, C.accent, true),
		s.standing,
		s.record,
		s.ground,
		"",
		Theme.rich("Best players", C.accent, true),
	}
	if #s.stars == 0 then
		table.insert(lines, "No squad yet.")
	end
	for _, p in s.stars do
		table.insert(lines, ("<b>%d</b>  %s  <font transparency=\"0.4\">%s · %d goals</font>"):format(p.overall, p.name, p.role, p.goals))
	end
	card.body.Text = table.concat(lines, "\n")
	-- friendlies (I3.1) and trades (I4.1): you need your own club, and they need an owner
	local canDeal = type(player:GetAttribute("ClubPlot")) == "number" and type(attrs.OwnerUserId) == "number"
	challengeButton.Visible = canDeal
	tradeButton.Visible = canDeal
	openName = s.clubName
	card.frame.Visible = true
	openAt = at
	openPlot = plot
end

local function attach(clubPrompt: ProximityPrompt)
	local part = clubPrompt.Parent
	local plot = PlotVisit.plotOf(clubPrompt, plots)
	if not (part and part:IsA("BasePart")) or plot == nil or part:FindFirstChild("VisitPrompt") then
		return
	end
	local visit = Instance.new("ProximityPrompt")
	visit.Name = "VisitPrompt"
	visit.ObjectText = "Visiting"
	visit.ActionText = "View club"
	visit.HoldDuration = 0
	visit.MaxActivationDistance = clubPrompt.MaxActivationDistance
	visit.RequiresLineOfSight = false
	local function refresh()
		visit.Enabled = PlotVisit.hidePrompt(plot, player:GetAttribute("ClubPlot"))
	end
	refresh()
	player:GetAttributeChangedSignal("ClubPlot"):Connect(refresh)
	visit.Triggered:Connect(function()
		open(plot :: number, part :: BasePart)
	end)
	visit.Parent = part
end

local function track(inst: Instance)
	if inst:IsA("ProximityPrompt") and inst.Name == "ClubPrompt" then
		attach(inst)
	end
end

for _, inst in plots:GetDescendants() do
	track(inst)
end
plots.DescendantAdded:Connect(track)

closeButton.Activated:Connect(close)
challengeButton.Activated:Connect(function()
	local plot = openPlot
	if plot then
		challengeEvent:FireServer(plot)
		close()
	end
end)
tradeButton.Activated:Connect(function()
	local plot = openPlot
	if plot then
		local name = openName
		close()
		TradePanel.open(plot, name)
	end
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and card.frame.Visible then
		close()
	end
end)

-- walking away closes the card, like leaving the office
RunService.Heartbeat:Connect(function()
	local at = openAt
	if not at then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not at.Parent or not root or (root.Position - at.Position).Magnitude > CLOSE_DISTANCE then
		close()
	end
end)
