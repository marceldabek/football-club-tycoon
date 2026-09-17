--!strict
-- Lit upstairs windows after dark (backlog X137). When this player's sky is
-- dark (evening fixtures, the fast-forward), the terrace rows nearest the
-- camera get a warm glowing pane in some of their upstairs windows, so the
-- streets under the lamp lights look lived-in. Client-only; which houses are
-- lit comes from TownLifeMath.litHouses (stable per row), the pane from
-- TownLifeMath.windowPane. Nothing is built in daylight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local MAX_ROWS = 14 -- TEMP
local MAX_ROWS_LOW = 5 -- TEMP, Quality "Low"
local RADIUS = 360
local RECHECK = 2
local GLOW = Color3.fromRGB(240, 150, 70) -- Neon lifts it to a warm amber

local rows: { [Model]: boolean } = {}
local lit: { [Model]: { BasePart } } = {}

-- X159: shopfronts glow onto the pavement after dark (RivermereCenter.png's
-- lit pub and café fronts): a warm SurfaceLight on the street face of the
-- nearest "Shopfront*" parts. No parts; lights come and go with the camera.
local MAX_SHOPS = 12 -- TEMP
local MAX_SHOPS_LOW = 4 -- TEMP, Quality "Low"
local SHOP_RADIUS = 300
local SHOP_GLOW = Color3.fromRGB(255, 208, 150)
local shopfronts: { [BasePart]: boolean } = {}
local shopLights: { [BasePart]: SurfaceLight } = {}

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "TerraceRow" then
		rows[inst] = true
	elseif inst:IsA("BasePart") and string.sub(inst.Name, 1, 9) == "Shopfront" then
		shopfronts[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

-- X248: Sky publishes this for the player's own look
local function skyIsDark(): boolean
	return player:GetAttribute("SkyDark") == true
end

local function light(row: Model, body: BasePart): { BasePart }
	local houses = row:GetAttribute("Houses")
	local count = if type(houses) == "number" and houses > 0 then houses else 1
	local facade = row:GetAttribute("Facade")
	local out: { BasePart } = {}
	for _, house in TownLifeMath.litHouses(body.Position, count) do
		local z, y, w, h = TownLifeMath.windowPane(if type(facade) == "string" then facade else nil, house, body.Size.Z / count, body.Size.Z, body.Size.Y)
		local p = Instance.new("Part")
		p.Name = "LitWindow"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(0.05, h, w)
		-- the street front is the Body's local -X face; 0.005-0.055 proud, behind
		-- a scarf (0.1 proud) if one hangs there
		p.CFrame = body.CFrame * CFrame.new(-body.Size.X / 2 - 0.03, y, z)
		p.Color = GLOW
		p.Material = Enum.Material.Neon
		p.Transparency = 0.15
		p.Parent = row
		table.insert(out, p)
	end
	return out
end

local function clear(row: Model)
	for _, p in lit[row] or {} do
		p:Destroy()
	end
	lit[row] = nil
end

local function refresh()
	local want: { [Model]: BasePart } = {}
	local camera = workspace.CurrentCamera
	if skyIsDark() and camera then
		local cam = camera.CFrame.Position
		local ranked = {}
		for row in rows do
			local body = row:FindFirstChild("Body")
			if not row.Parent then
				rows[row] = nil
				lit[row] = nil
			elseif body and body:IsA("BasePart") then
				local d = Vector3.new(body.Position.X - cam.X, 0, body.Position.Z - cam.Z).Magnitude
				if d <= RADIUS then
					table.insert(ranked, { row = row, body = body, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
		local max = if player:GetAttribute("Quality") == "Low" then MAX_ROWS_LOW else MAX_ROWS
		for i = 1, math.min(max, #ranked) do
			want[ranked[i].row] = ranked[i].body
		end
	end
	for row in lit do
		if not want[row] then
			clear(row)
		end
	end
	for row, body in want do
		if not lit[row] then
			lit[row] = light(row, body)
		end
	end

	local wantShops: { [BasePart]: boolean } = {}
	if skyIsDark() and camera then
		local cam = camera.CFrame.Position
		local ranked = {}
		for front in shopfronts do
			if not front.Parent then
				shopfronts[front] = nil
			else
				local d = Vector3.new(front.Position.X - cam.X, 0, front.Position.Z - cam.Z).Magnitude
				if d <= SHOP_RADIUS then
					table.insert(ranked, { front = front, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
		local max = if player:GetAttribute("Quality") == "Low" then MAX_SHOPS_LOW else MAX_SHOPS
		for i = 1, math.min(max, #ranked) do
			wantShops[ranked[i].front] = true
		end
	end
	for front, l in shopLights do
		if not wantShops[front] then
			l:Destroy()
			shopLights[front] = nil
		end
	end
	for front in wantShops do
		if not shopLights[front] then
			local l = Instance.new("SurfaceLight")
			l.Name = "ShopGlow"
			l.Face = Enum.NormalId.Left -- ShopBuilder's shopfronts face the street on local -X
			l.Color = SHOP_GLOW
			l.Brightness = 1.4
			l.Range = 14
			l.Angle = 100
			l.Shadows = false
			l.Parent = front
			shopLights[front] = l
		end
	end
end

player:GetAttributeChangedSignal("SkyDark"):Connect(refresh)

while true do
	refresh()
	task.wait(RECHECK)
end
