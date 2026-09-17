--!strict
-- Trade screen (I4.1c): opened from another club's office card. Two squad
-- lists (yours to give, theirs to take), up to Trade.MAX_PLAYERS_PER_SIDE
-- picks each, optional cash one way, then Send offer. The server checks
-- everything again (Trade.validate); this screen only helps build the offer.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Trade"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local ClubRef = require(script.Parent:WaitForChild("ClubRef"))

local TradePanel = {}

local player = Players.LocalPlayer
local C = Theme.colors

local gui = Theme.screenGui("TradePanel", 7)
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Theme.panel(gui, "Panel", {
	Size = UDim2.new(0, 760, 0, 520),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Visible = false,
})
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(760, 520)
sizeLimit.Parent = panel

local title = Theme.text(panel, "TRADE", "display", {
	Name = "Title",
	Size = UDim2.new(1, -80, 0, 36),
	Position = UDim2.fromOffset(20, 14),
})
local closeButton = Theme.closeButton(panel, { Position = UDim2.new(1, -48, 0, 16) })

local function column(name: string, heading: string, x: number): ScrollingFrame
	Theme.text(panel, heading, "title", {
		Name = name .. "Heading",
		Size = UDim2.new(0.5, -30, 0, 22),
		Position = UDim2.new(x, if x == 0 then 20 else 10, 0, 58),
	})
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.BackgroundColor3 = C.bg2
	list.BackgroundTransparency = 0.3
	list.BorderSizePixel = 0
	list.Size = UDim2.new(0.5, -30, 1, -200)
	list.Position = UDim2.new(x, if x == 0 then 20 else 10, 0, 84)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	Theme.corner(list, Theme.cardRadius)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	Theme.padding(list, 6)
	list.Parent = panel
	return list
end

local giveList = column("Give", "YOU GIVE (tap up to 3)", 0)
local takeList = column("Take", "YOU GET (tap up to 3)", 0.5)

Theme.text(panel, "Cash (optional)", "muted", {
	Size = UDim2.fromOffset(130, 34),
	Position = UDim2.new(0, 20, 1, -106),
})
local cashBox = Instance.new("TextBox")
cashBox.Name = "Cash"
cashBox.PlaceholderText = "£0"
cashBox.Text = ""
cashBox.ClearTextOnFocus = false
cashBox.Font = Theme.fonts.bold
cashBox.TextSize = 16
cashBox.TextColor3 = C.cash
cashBox.PlaceholderColor3 = C.muted
cashBox.BackgroundColor3 = C.bg2
cashBox.BorderSizePixel = 0
cashBox.Size = UDim2.fromOffset(150, 34)
cashBox.Position = UDim2.new(0, 150, 1, -106)
Theme.corner(cashBox, Theme.buttonRadius)
Theme.stroke(cashBox)
cashBox.Parent = panel

local payToggle = Theme.button(panel, "You pay", "ghost", {
	Name = "Direction",
	Size = UDim2.fromOffset(150, 34),
	Position = UDim2.new(0, 312, 1, -106),
})

local status = Theme.text(panel, "", "muted", {
	Name = "Status",
	Size = UDim2.new(1, -460, 0, 22), -- left of the Send / Cancel buttons
	Position = UDim2.new(0, 20, 1, -66),
	TextSize = 14,
})

local sendButton = Theme.button(panel, "Send offer", "primary", {
	Name = "Send",
	Size = UDim2.fromOffset(190, 40),
	Position = UDim2.new(1, -420, 1, -50),
	AnchorPoint = Vector2.new(0, 0.5),
})
local cancelButton = Theme.button(panel, "Cancel", "secondary", {
	Name = "Cancel",
	Size = UDim2.fromOffset(190, 40),
	Position = UDim2.new(1, -210, 1, -50),
	AnchorPoint = Vector2.new(0, 0.5),
})

local proposeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TradePropose") :: RemoteEvent

local targetPlot: number? = nil
local giving: { number } = {}
local taking: { number } = {}
local youPay = true

local function squadOf(folder: Instance?): { any }
	local raw = folder and folder:GetAttribute("Club")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, club = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(club) ~= "table" or type(club.players) ~= "table" then
		return {}
	end
	local players = table.clone(club.players)
	table.sort(players, function(a, b)
		return (a.number or 0) < (b.number or 0)
	end)
	return players
end

local function indexOf(list: { number }, id: number): number?
	for i, v in list do
		if v == id then
			return i
		end
	end
	return nil
end

local function refreshStatus()
	local cash = Trade.parseCash(cashBox.Text)
	if cash == nil then
		status.Text = "Cash must be a whole amount, like 2500."
		status.TextColor3 = C.bad
	elseif #giving == 0 and #taking == 0 then
		status.Text = "Pick at least one player. Cash can't be sent on its own."
		status.TextColor3 = C.muted
	else
		status.Text = ("Giving %d, getting %d%s"):format(
			#giving,
			#taking,
			if cash > 0 then (if youPay then ", you pay £" else ", they pay £") .. cash else ""
		)
		status.TextColor3 = C.text
	end
end

local function fill(list: ScrollingFrame, squad: { any }, picks: { number })
	for _, child in list:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for order, p in squad do
		local injured = type(p.injured) == "number" and p.injured > 0
		local row = Theme.button(list, "", "ghost", {
			Name = "P" .. tostring(p.id),
			Size = UDim2.new(1, -4, 0, 30),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 14,
			RichText = true,
		})
		Theme.padding(row, 0, 10)
		local function paint()
			local picked = indexOf(picks, p.id) ~= nil
			row.BackgroundColor3 = if picked then C.selected else C.bg2
			row.Text = ("<b>%d</b>  %s  <font color=\"#9ea6b2\">%s · %d · age %d%s</font>"):format(
				p.number or 0,
				tostring(p.name),
				tostring(p.role),
				p.overall or 0,
				p.age or 0,
				if injured then " · injured" else ""
			)
		end
		paint()
		row.Activated:Connect(function()
			local i = indexOf(picks, p.id)
			if i then
				table.remove(picks, i)
			elseif #picks < Trade.MAX_PLAYERS_PER_SIDE then
				table.insert(picks, p.id)
			end
			paint()
			refreshStatus()
		end)
	end
end

local function close()
	panel.Visible = false
	targetPlot = nil
end

function TradePanel.open(plot: number, clubName: string)
	local own = ClubRef.state()
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	local theirs = clubs and clubs:FindFirstChild("Plot" .. plot)
	if not own or not theirs then
		return
	end
	targetPlot = plot
	giving, taking = {}, {}
	cashBox.Text = ""
	youPay = true
	payToggle.Text = "You pay"
	title.Text = "TRADE WITH " .. string.upper(clubName)
	fill(giveList, squadOf(own), giving)
	fill(takeList, squadOf(theirs), taking)
	refreshStatus()
	panel.Visible = true
end

function TradePanel.isOpen(): boolean
	return panel.Visible
end

payToggle.Activated:Connect(function()
	youPay = not youPay
	payToggle.Text = if youPay then "You pay" else "They pay"
	refreshStatus()
end)
cashBox:GetPropertyChangedSignal("Text"):Connect(refreshStatus)
closeButton.Activated:Connect(close)
cancelButton.Activated:Connect(close)
sendButton.Activated:Connect(function()
	local plot = targetPlot
	local cash = Trade.parseCash(cashBox.Text)
	if not plot or cash == nil or (#giving == 0 and #taking == 0) then
		refreshStatus()
		return
	end
	proposeEvent:FireServer(plot, giving, taking, if youPay then cash else 0, if youPay then 0 else cash)
	close()
end)

return TradePanel
