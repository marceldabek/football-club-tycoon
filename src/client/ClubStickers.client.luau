--!strict
-- X340: nothing in town carried a club sticker. The club's mark reached the
-- streets as murals (X90/H1.2), scarves in terrace windows (X90) and banners on
-- lamp posts at the ground (X105), but WORLD_VISION s4 names "posters, club
-- stickers" as how football actually shows through a normal town - and the
-- town's own flyposting is fifteen fictional jumble-sale bills.
--
-- So: round club stickers and pasted-up home-match bills on the street
-- furniture nearest the ground - bus-stop poles, litter bins and lamp posts -
-- spreading as the club plays matches and gets promoted. Client-only, like the
-- murals and the scarves (CLAUDE.md s27: the town wears *your* club's identity
-- on your screen). One part each, at most TownLifeMath.STICKER_MAX of them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))
local ClubRef = require(script.Parent:WaitForChild("ClubRef"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local RADIUS = 1100 -- TEMP: further out than this and it is somebody else's neighbourhood
local RECHECK = 5

-- What a sticker can go on. `kind` decides where its street side is: a bus
-- stop pole and bin are built facing the pavement (TownBuilder), and a lamp
-- post's lantern hangs over the carriageway (TerraceBuilder), so neither has
-- to be guessed from the geometry. The direction is worked out when the
-- sticker is placed, because a lamp's Lantern may not have streamed in yet
-- when its Post does.
type Spot = { part: BasePart, kind: "furniture" | "lamp", host: Model }

local spots: { Spot } = {}
local placed: { BasePart } = {}
local shown = "" -- the club and count already on the streets

-- the lantern of a terrace lamp hangs over the carriageway, so it points at
-- the street: a sticker on the post faces the same way
local function lampFacing(lamp: Model, post: BasePart): Vector3?
	local lantern = lamp:FindFirstChild("Lantern")
	if not (lantern and lantern:IsA("BasePart")) then
		return nil
	end
	local flat = Vector3.new(lantern.Position.X - post.Position.X, 0, lantern.Position.Z - post.Position.Z)
	return if flat.Magnitude > 0.5 then flat.Unit else nil
end

-- The height and street direction of a spot, once its model is fully there.
local function aim(spot: Spot): (number?, Vector3?)
	if spot.kind == "lamp" then
		-- the post is a cylinder laid on its side (axis X -> Y), so its own
		-- height is Size.X, not Size.Y
		return spot.part.Size.X, lampFacing(spot.host, spot.part)
	end
	-- Front (-Z, the LookVector) is the pavement side of a pole or a bin
	return spot.part.Size.Y, spot.part.CFrame.LookVector
end

local function consider(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local host = inst.Parent
	if not (host and host:IsA("Model")) then
		return
	end
	if (inst.Name == "Pole" or inst.Name == "Bin") and host.Name:find("BusStop") then
		table.insert(spots, { part = inst, kind = "furniture" :: "furniture" | "lamp", host = host })
		shown = "" -- place again now there is somewhere new to paste
	elseif inst.Name == "Post" and host.Name == "TerraceLamp" then
		table.insert(spots, { part = inst, kind = "lamp" :: "furniture" | "lamp", host = host })
		shown = ""
	end
end

local function clubState(): (string, number, number, Vector3?, string?)
	local folder = ClubRef.state()
	local name = folder and folder:GetAttribute("ClubName")
	local played = folder and folder:GetAttribute("MatchesPlayed")
	local tier = folder and folder:GetAttribute("Tier")
	local opponent = folder and folder:GetAttribute("NextOpponent")
	local plot = player:GetAttribute("ClubPlot")
	local ground = if type(plot) == "number" then TownLayout.plotCFrame(plot).Position else nil
	return if type(name) == "string" and name ~= "" then name else Config.ClubName,
		if type(played) == "number" then played else 0,
		if type(tier) == "number" then tier else 1,
		ground,
		if type(opponent) == "string" then opponent else nil
end

local function initials(clubName: string): string
	local letters = {}
	for word in clubName:gmatch("%S+") do
		local first = word:sub(1, 1):upper()
		if first:match("%a") then
			table.insert(letters, first)
		end
	end
	local text = table.concat(letters)
	return if #text > 0 then text:sub(1, 3) else "FC"
end

-- A round sticker: the club's initials on a disc in its colours.
local function sticker(spot: Spot, height: number, facing: Vector3, kit: Color3, accent: Color3, clubName: string): BasePart
	local y = TownLifeMath.stickerHeight(height, false)
	local at = Vector3.new(spot.part.Position.X, spot.part.Position.Y - height / 2 + y, spot.part.Position.Z)
		+ facing * 0.32
	local p = Instance.new("Part")
	p.Name = "ClubSticker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(1.5, 1.5, 0.06)
	p.CFrame = CFrame.lookAt(at, at + facing)
	p.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = 220
	gui.LightInfluence = 1
	gui.Parent = p
	local disc = Instance.new("Frame")
	disc.BackgroundColor3 = kit
	disc.BorderSizePixel = 0
	disc.Size = UDim2.fromScale(1, 1)
	disc.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
	local ring = Instance.new("UIStroke")
	ring.Color = accent
	ring.Thickness = 3
	ring.Parent = disc
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.8, 0.5)
	label.Position = UDim2.fromScale(0.1, 0.25)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = accent
	label.Text = initials(clubName)
	label.Parent = disc
	p.Parent = spot.host
	return p
end

-- A pasted-up bill: the club's name and its next home match, slightly askew.
local function bill(spot: Spot, height: number, facing: Vector3, kit: Color3, accent: Color3, clubName: string, opponent: string?, lean: number): BasePart
	local y = TownLifeMath.stickerHeight(height, true)
	local at = Vector3.new(spot.part.Position.X, spot.part.Position.Y - height / 2 + y, spot.part.Position.Z)
		+ facing * 0.32
	local p = Instance.new("Part")
	p.Name = "ClubBill"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(2, 2.8, 0.06)
	-- nobody pastes a bill on straight
	p.CFrame = CFrame.lookAt(at, at + facing) * CFrame.Angles(0, 0, math.rad(lean))
	p.Color = Color3.fromRGB(238, 234, 226)
	p.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = 220
	gui.LightInfluence = 1
	gui.Parent = p
	local head = Instance.new("Frame")
	head.BackgroundColor3 = kit
	head.BorderSizePixel = 0
	head.Size = UDim2.fromScale(1, 0.34)
	head.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, 0.8)
	title.Position = UDim2.fromScale(0.05, 0.1)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = accent
	title.Text = clubName:upper()
	title.Parent = head
	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(0.9, 0.5)
	body.Position = UDim2.fromScale(0.05, 0.4)
	body.Font = Enum.Font.GothamBold
	body.TextScaled = true
	body.TextColor3 = Color3.fromRGB(28, 28, 32)
	body.Text = if opponent then ("HOME MATCH\nv %s"):format(opponent:upper()) else "HOME MATCH\nTHIS WEEK"
	body.Parent = gui
	p.Parent = spot.host
	return p
end

local function clear()
	for _, p in placed do
		p:Destroy()
	end
	placed = {}
end

local function refresh()
	local clubName, played, tier, ground, opponent = clubState()
	local want = if ground then TownLifeMath.stickerCount(played, tier) else 0
	local key = ("%s|%d|%s"):format(clubName, want, tostring(opponent))
	if key == shown and #placed > 0 then
		return -- nothing has changed since the last pass
	end
	shown = key
	clear()
	if want == 0 or not ground then
		return
	end
	local near = {}
	local live: { Spot } = {}
	for _, spot in spots do
		if not spot.part.Parent then
			continue -- streamed out, or the prop was rebuilt
		end
		table.insert(live, spot)
		local d = Vector3.new(spot.part.Position.X - ground.X, 0, spot.part.Position.Z - ground.Z).Magnitude
		if d <= RADIUS then
			local height, facing = aim(spot)
			if height and facing then
				table.insert(near, { spot = spot, d = d, height = height, facing = facing })
			end
		end
	end
	spots = live
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	local kit, accent = Config.clubCrest(clubName, true)
	local rng = Random.new(#near + want)
	for i = 1, math.min(want, #near) do
		local item = near[i]
		if TownLifeMath.isBill(i) then
			table.insert(placed, bill(item.spot, item.height, item.facing, kit, accent, clubName, opponent, rng:NextNumber(-4, 4)))
		else
			table.insert(placed, sticker(item.spot, item.height, item.facing, kit, accent, clubName))
		end
	end
end

-- one full pass over the town, then keep up with what streams in - never a
-- second full scan (21,000 parts)
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

while true do
	local ok, err = pcall(refresh)
	if not ok then
		warn("[FCT] club stickers:", err)
	end
	task.wait(RECHECK)
end
