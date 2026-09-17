--!strict
-- Lamps inside the club plots light up after dark (backlog X154). TownLife
-- lights the town's street lamps for evening fixtures, but the plots' own
-- lamps (the turnstile lamp post and walk-in lamps' "Lantern" glass, the car
-- park's "LampLens") stayed dark, so the way into the ground was black.
-- Client-only and part-free: while this player's sky is dark, the nearest
-- lamps get a PointLight and glow (Neon, local only); both go when it's day.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("Plots", math.huge)

local MAX_LIT = 10 -- TEMP
local MAX_LIT_LOW = 4 -- TEMP, Quality "Low"
local RADIUS = 260
local RECHECK = 2
local NAMES: { [string]: boolean } = { Lantern = true, LampLens = true }

type Lit = { light: PointLight, material: Enum.Material }
local lamps: { [BasePart]: boolean } = {}
local lit: { [BasePart]: Lit } = {}

local function consider(inst: Instance)
	if inst:IsA("BasePart") and NAMES[inst.Name] then
		lamps[inst] = true
	end
end
for _, d in plots:GetDescendants() do
	consider(d)
end
plots.DescendantAdded:Connect(consider)

-- same test as TownLife's lamp lights
local function skyIsDark(): boolean
	local t = Lighting.ClockTime
	return t >= 17.8 or t <= 6.2
end

local function turnOff(part: BasePart)
	local entry = lit[part]
	if entry then
		entry.light:Destroy()
		if part.Parent then
			part.Material = entry.material
		end
		lit[part] = nil
	end
end

local function refresh()
	local want: { [BasePart]: boolean } = {}
	local camera = workspace.CurrentCamera
	if skyIsDark() and camera then
		local cam = camera.CFrame.Position
		local ranked = {}
		for part in lamps do
			if not part.Parent then
				lamps[part] = nil
			else
				local d = (part.Position - cam).Magnitude
				if d <= RADIUS then
					table.insert(ranked, { part = part, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
		local max = if player:GetAttribute("Quality") == "Low" then MAX_LIT_LOW else MAX_LIT
		for i = 1, math.min(max, #ranked) do
			want[ranked[i].part] = true
		end
	end
	for part in lit do
		if not want[part] then
			turnOff(part)
		end
	end
	for part in want do
		if not lit[part] then
			local light = Instance.new("PointLight")
			light.Name = "PlotLampLight"
			light.Color = Color3.fromRGB(255, 214, 160)
			light.Brightness = 1.6
			light.Range = 30
			light.Shadows = false
			light.Parent = part
			lit[part] = { light = light, material = part.Material }
			part.Material = Enum.Material.Neon
		end
	end
end

while true do
	refresh()
	task.wait(RECHECK)
end
