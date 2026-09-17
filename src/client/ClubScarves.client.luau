--!strict
-- Club scarves in town windows (roadmap H1, backlog X90): as the player's club
-- plays matches, scarves in its colours appear in the upstairs windows of the
-- terrace rows nearest its ground. Client-only, like the murals and lamp
-- banners (CLAUDE.md s27). Placement maths in TownLifeMath.scarfSpot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))
local ClubRef = require(script.Parent:WaitForChild("ClubRef"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)
local RADIUS = 1400 -- TEMP: rows further than this from the club's ground never get one
local RECHECK = 5

local rows: { [Model]: boolean } = {}
local hung: { [Model]: { BasePart } } = {}
local hungClub: { [Model]: string } = {}

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "TerraceRow" then
		rows[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

local function clubState(): (string, number, Vector3?)
	local folder = ClubRef.state()
	local name = folder and folder:GetAttribute("ClubName")
	local played = folder and folder:GetAttribute("MatchesPlayed")
	local plot = player:GetAttribute("ClubPlot")
	local ground = if type(plot) == "number" then TownLayout.plotCFrame(plot).Position else nil
	return if type(name) == "string" and name ~= "" then name else Config.ClubName, if type(played) == "number" then played else 0, ground
end

local function scarf(row: Model, body: BasePart, house: number, kit: Color3, accent: Color3): BasePart
	local houses = row:GetAttribute("Houses")
	local count = if type(houses) == "number" and houses > 0 then houses else 1
	local facade = row:GetAttribute("Facade")
	local z, y = TownLifeMath.scarfSpot(if type(facade) == "string" then facade else nil, house, body.Size.Z / count, body.Size.Z, body.Size.Y)
	-- the street front is the Body's local -X face; hang 0.06 proud of it
	local p = Instance.new("Part")
	p.Name = "ClubScarf"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(0.08, 2.6, 1.1)
	p.CFrame = body.CFrame * CFrame.new(-body.Size.X / 2 - 0.1, y, z)
	p.Color = kit
	p.Material = Enum.Material.Fabric
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 1
	gui.Parent = p
	for _, v in { 0.25, 0.65 } do
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.BackgroundColor3 = accent
		band.Size = UDim2.fromScale(1, 0.1)
		band.Position = UDim2.fromScale(0, v)
		band.Parent = gui
	end
	p.Parent = row
	return p
end

local function clear(row: Model)
	for _, p in hung[row] or {} do
		p:Destroy()
	end
	hung[row] = nil
	hungClub[row] = nil
end

local function refresh()
	local clubName, played, ground = clubState()
	local want = if ground then TownLifeMath.scarfCount(played) else 0
	local ranked = {}
	for row in rows do
		local body = row:FindFirstChild("Body")
		if not row.Parent then
			rows[row] = nil
			hung[row] = nil
		elseif body and body:IsA("BasePart") and ground then
			local d = Vector3.new(body.Position.X - ground.X, 0, body.Position.Z - ground.Z).Magnitude
			if d <= RADIUS then
				table.insert(ranked, { row = row, body = body, d = d })
			end
		end
	end
	table.sort(ranked, function(a, b)
		return a.d < b.d
	end)
	-- every other house of the nearest rows, until `want` scarves are placed
	local plan: { [Model]: number } = {}
	local left = want
	for _, item in ranked do
		if left <= 0 then
			break
		end
		local houses = item.row:GetAttribute("Houses")
		local slots = math.ceil((if type(houses) == "number" then houses else 1) / 2)
		plan[item.row] = math.min(slots, left)
		left -= plan[item.row]
	end
	local kit, accent = Config.clubCrest(clubName, true)
	for row in hung do
		if plan[row] ~= #hung[row] or hungClub[row] ~= clubName then
			clear(row)
		end
	end
	for _, item in ranked do
		local n = plan[item.row]
		if n and not hung[item.row] then
			local parts = {}
			for k = 0, n - 1 do
				table.insert(parts, scarf(item.row, item.body, k * 2, kit, accent))
			end
			hung[item.row] = parts
			hungClub[item.row] = clubName
		end
	end
end

while true do
	refresh()
	task.wait(RECHECK)
end
