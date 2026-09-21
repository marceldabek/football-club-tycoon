--!strict
-- The neighbourhood around each ground grows with its club (backlog X105,
-- WORLD_ROADMAP H1; CLAUDE.md s27: "The neighbourhood around each ground
-- changes for everyone as that club grows"). Runs on every client for every
-- claimed plot, like MatchdayLife: club banners on the footpath lamps, then a
-- club-name hoarding outside the entrance wall, then flags on the gate piers,
-- unlocked by the club folder's Tier (thresholds and spots in
-- Shared.GroundInfluence). At most 13 parts a plot; rebuilt only when the
-- tier, name or plot changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GroundInfluence = require(Shared:WaitForChild("GroundInfluence"))

local root = Instance.new("Folder")
root.Name = "GroundInfluence"
root.Parent = workspace

type Built = { key: string, model: Model? }
local built: { [Folder]: Built } = {}

local IRON = Color3.fromRGB(28, 30, 32)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function build(plot: CFrame, tier: number, clubName: string, parent: Instance): Model?
	local f = GroundInfluence.features(tier)
	if not (f.banners or f.hoarding or f.flags) then
		return nil
	end
	local kit, accent = Config.clubCrest(clubName, true)
	local m = Instance.new("Model")
	m.Name = "Influence"

	if f.banners then
		-- an arm off the post toward the path (+Z), a banner in club colours
		-- hanging from it, readable along the path
		for _, lamp in GroundInfluence.PATH_LAMPS do
			local armY = GroundInfluence.LAMP_HEIGHT - 1.4
			part("BannerArm", Vector3.new(0.15, 0.15, 1.8), plot * CFrame.new(lamp.X, armY, lamp.Z + 0.25 + 0.9), IRON, m)
			local bz = lamp.Z + 0.25 + 0.95
			part("Banner", Vector3.new(0.1, 4, 1.4), plot * CFrame.new(lamp.X, armY - 0.1 - 2, bz), kit, m)
			part("BannerStripe", Vector3.new(0.14, 0.6, 1.3), plot * CFrame.new(lamp.X, armY - 0.1 - 3.1, bz), accent, m)
		end
	end

	if f.hoarding then
		local h = GroundInfluence.HOARDING
		local height = h.top - h.bottom
		local board = part("Hoarding", Vector3.new(0.3, height, h.z1 - h.z0), plot * CFrame.new(h.x, h.bottom + height / 2, (h.z0 + h.z1) / 2), kit, m)
		for _, z in { h.z0 + 4, h.z1 - 4 } do
			part("HoardingLeg", Vector3.new(0.4, h.bottom + 0.5, 0.4), plot * CFrame.new(h.x + 0.35, (h.bottom + 0.5) / 2, z), IRON, m)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left -- plot -X, toward the town
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 16
		gui.LightInfluence = 1
		gui.MaxDistance = 400
		gui.Parent = board
		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = accent
		stripe.Size = UDim2.fromScale(1, 0.1)
		stripe.Position = UDim2.fromScale(0, 0.84)
		stripe.Parent = gui
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.9, 0.5)
		label.Position = UDim2.fromScale(0.05, 0.12)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = accent
		label.Text = string.upper(clubName)
		label.Parent = gui
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.fromScale(0.9, 0.18)
		sub.Position = UDim2.fromScale(0.05, 0.62)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = accent
		sub.Text = "HOME OF RIVERMERE FOOTBALL"
		sub.Parent = gui
	end

	if f.flags then
		for _, pier in GroundInfluence.GATE_PIERS do
			local poleH = GroundInfluence.FLAGPOLE_HEIGHT
			part("Flagpole", Vector3.new(0.25, poleH, 0.25), plot * CFrame.new(pier.X, pier.Y + poleH / 2, pier.Z), Color3.fromRGB(220, 220, 216), m)
			-- the flag flies out over the town side of the wall
			part("Flag", Vector3.new(3.6, 2.4, 0.1), plot * CFrame.new(pier.X - 0.125 - 1.8, pier.Y + poleH - 1.5, pier.Z), kit, m)
		end
	end

	m.Parent = parent
	return m
end

local function refresh(folder: Folder)
	local cf = folder:GetAttribute("PlotCFrame")
	local tier = folder:GetAttribute("Tier")
	local name = folder:GetAttribute("ClubName")
	local plot = if typeof(cf) == "CFrame" then cf else nil
	local t = if type(tier) == "number" then tier else 1
	local n = if type(name) == "string" and name ~= "" then name else Config.ClubName
	local crest = folder:GetAttribute("Crest") -- crest builder: the club's colours
	local key = if plot then ("%d|%s|%s|%s"):format(t, n, tostring(plot), tostring(crest)) else "none"
	local old = built[folder]
	if old and old.key == key then
		return
	end
	if old and old.model then
		old.model:Destroy()
	end
	built[folder] = { key = key, model = if plot then build(plot, t, n, root) else nil }
end

local function track(folder: Folder)
	refresh(folder)
	for _, attr in { "PlotCFrame", "Tier", "ClubName", "Crest" } do
		folder:GetAttributeChangedSignal(attr):Connect(function()
			refresh(folder)
		end)
	end
end

local function untrack(folder: Folder)
	local old = built[folder]
	if old and old.model then
		old.model:Destroy()
	end
	built[folder] = nil
end

task.spawn(function()
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	while not clubs do
		task.wait(2)
		clubs = ReplicatedStorage:FindFirstChild("Clubs")
	end
	for _, child in clubs:GetChildren() do
		if child:IsA("Folder") then
			track(child)
		end
	end
	clubs.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			track(child)
		end
	end)
	clubs.ChildRemoved:Connect(function(child)
		if child:IsA("Folder") then
			untrack(child)
		end
	end)
end)
