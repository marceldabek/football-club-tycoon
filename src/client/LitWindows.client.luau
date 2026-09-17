--!strict
-- Lit upstairs windows after dark (backlog X137). When this player's sky is
-- dark (evening fixtures, the fast-forward), the terrace rows nearest the
-- camera get a warm glowing pane in some of their upstairs windows, so the
-- streets under the lamp lights look lived-in. Client-only; which houses are
-- lit comes from TownLifeMath.litHouses (stable per row), the pane from
-- TownLifeMath.windowPane. Nothing is built in daylight.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
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

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "TerraceRow" then
		rows[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

-- same test as TownLife's lamp lights
local function skyIsDark(): boolean
	local t = Lighting.ClockTime
	return t >= 17.8 or t <= 6.2
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
end

while true do
	refresh()
	task.wait(RECHECK)
end
