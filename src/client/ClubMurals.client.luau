--!strict
-- Club murals (roadmap H1, backlog H1.2): once the player's club is
-- established, this client paints a mural in the club's colours on the gable
-- end of the terrace row nearest the market square (a second one from tier 2).
-- Client-only, like the lamp banners (CLAUDE.md s27: each player's screen shows
-- the town in their club's identity). Rows stream in and out, so a mural is
-- added when its row arrives and simply goes when the row streams away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))
local ClubRef = require(script.Parent:WaitForChild("ClubRef"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)
local SQUARE = TownLayout.SQUARE.centre
local MURAL_RADIUS = 360 -- TEMP: rows further than this from the square never get one

local rows: { [Model]: boolean } = {}
local murals: { [Model]: BasePart } = {}

local function clubState(): (string, number, number)
	local folder = ClubRef.state()
	local name = folder and folder:GetAttribute("ClubName")
	local played = folder and folder:GetAttribute("MatchesPlayed")
	local tier = folder and folder:GetAttribute("Tier")
	return if type(name) == "string" and name ~= "" then name else Config.ClubName,
		if type(played) == "number" then played else 0,
		if type(tier) == "number" then tier else 1
end

local function paint(row: Model, clubName: string): BasePart?
	local body = row:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then
		return nil
	end
	local _, outward = TownLifeMath.gableToward(body.CFrame, SQUARE)
	local pos = body.Position + outward * (body.Size.Z / 2 + 0.12)
	local kit, accent = Config.clubCrest(clubName, true)
	local panel = Instance.new("Part")
	panel.Name = "ClubMural"
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CastShadow = false
	panel.Size = Vector3.new(body.Size.X * 0.8, body.Size.Y * 0.72, 0.2)
	panel.CFrame = CFrame.lookAt(pos, pos + outward)
	panel.Color = kit
	panel.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = panel
	local stripe = Instance.new("Frame")
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = accent
	stripe.Size = UDim2.fromScale(1, 0.12)
	stripe.Position = UDim2.fromScale(0, 0.6)
	stripe.Parent = gui
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(0.9, 0.36)
	name.Position = UDim2.fromScale(0.05, 0.16)
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = accent
	name.Text = string.upper(clubName)
	name.Parent = gui
	local motto = Instance.new("TextLabel")
	motto.BackgroundTransparency = 1
	motto.Size = UDim2.fromScale(0.8, 0.14)
	motto.Position = UDim2.fromScale(0.1, 0.78)
	motto.Font = Enum.Font.GothamBold
	motto.TextScaled = true
	motto.TextColor3 = accent
	motto.Text = "OUR TOWN · OUR CLUB"
	motto.Parent = gui
	panel.Parent = row
	return panel
end

local function refresh()
	local clubName, played, tier = clubState()
	local want = TownLifeMath.muralCount(played, tier)
	-- rank the streamed-in rows by distance to the square
	local ranked = {}
	for row in rows do
		-- a streamed row can arrive before its Body (and its pivot is the origin
		-- until then), so rank by the Body and skip rows without one yet
		local body = row:FindFirstChild("Body")
		if row.Parent and body and body:IsA("BasePart") then
			local d = Vector3.new(body.Position.X - SQUARE.X, 0, body.Position.Z - SQUARE.Z).Magnitude
			if d <= MURAL_RADIUS then
				table.insert(ranked, { row = row, d = d })
			end
		elseif not row.Parent then
			rows[row] = nil
		end
	end
	table.sort(ranked, function(a, b)
		return a.d < b.d
	end)
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(want, #ranked) do
		keep[ranked[i].row] = true
	end
	for row, panel in murals do
		if not keep[row] or not row.Parent then
			panel:Destroy()
			murals[row] = nil
		end
	end
	for row in keep do
		local existing = murals[row]
		if existing and existing:GetAttribute("Club") ~= clubName then
			existing:Destroy()
			existing = nil
			murals[row] = nil
		end
		if not existing then
			local panel = paint(row, clubName)
			if panel then
				panel:SetAttribute("Club", clubName)
				murals[row] = panel
			end
		end
	end
end

local pending = false
local function schedule()
	if pending then
		return
	end
	pending = true
	task.delay(0.5, function()
		pending = false
		refresh()
	end)
end

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "TerraceRow" then
		rows[inst] = true
		schedule()
	elseif inst.Name == "Body" and inst.Parent and inst.Parent.Name == "TerraceRow" then
		schedule() -- the row's body streamed in after the row
	end
end

for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)
town.DescendantRemoving:Connect(function(inst)
	if inst:IsA("Model") and inst.Name == "TerraceRow" then
		rows[inst] = nil
		murals[inst] = nil
		schedule()
	end
end)

local folder = ClubRef.waitState()
for _, key in { "ClubName", "MatchesPlayed", "Tier", "Crest" } do
	folder:GetAttributeChangedSignal(key):Connect(schedule)
end
player:GetAttributeChangedSignal("ClubPlot"):Connect(schedule)
schedule()
