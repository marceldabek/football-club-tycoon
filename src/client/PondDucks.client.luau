--!strict
-- Ducks on the Riverside Park pond (backlog X184, RivermereRiverside.png's
-- water birds). Client-only, like Swans: three ducks (2 parts each, a brown
-- body and a green head) paddle slow loops on the pond's "Water" disc while
-- the camera is within NEAR of it, and are gone on Quality "Low". The pond is
-- found by name, so nothing is built until ParkDresser's Pond streams in.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local NEAR = 250
local DUCKS = 3
local BODY = Vector3.new(1, 0.7, 1.6)
local HEAD = Vector3.new(0.55, 0.55, 0.6)

local folder = Instance.new("Folder")
folder.Name = "PondDucks"

local function part(name: string, size: Vector3, colour: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = folder
	return p
end

type Duck = { body: BasePart, head: BasePart, radius: number, period: number, phase: number, dir: number }
local ducks: { Duck } = {}
for i = 1, DUCKS do
	table.insert(ducks, {
		body = part("DuckBody", BODY, Color3.fromRGB(120, 96, 70)),
		head = part("DuckHead", HEAD, if i == 2 then Color3.fromRGB(130, 110, 84) else Color3.fromRGB(40, 100, 60)),
		radius = 0.35 + 0.18 * i, -- share of the pond radius
		period = 40 + i * 9,
		phase = i * 2.1,
		dir = if i % 2 == 0 then -1 else 1,
	})
end

local water: BasePart? = nil
local function isPondWater(d: Instance): boolean
	return d:IsA("BasePart") and d.Name == "Water" and d.Parent ~= nil and d.Parent.Name == "Pond"
end
for _, d in town:GetDescendants() do
	if isPondWater(d) then
		water = d :: BasePart
	end
end
town.DescendantAdded:Connect(function(d)
	if isPondWater(d) then
		water = d :: BasePart
	end
end)

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local check = 0
local visible = false

RunService.RenderStepped:Connect(function(dt: number)
	check -= dt
	if check <= 0 then
		check = 2
		if water and not water.Parent then
			water = nil
		end
		local camera = workspace.CurrentCamera
		local want = false
		if water and camera and player:GetAttribute("Quality") ~= "Low" then
			local p = camera.CFrame.Position
			want = Vector3.new(p.X - water.Position.X, 0, p.Z - water.Position.Z).Magnitude < NEAR
		end
		if want ~= visible then
			visible = want
			folder.Parent = if visible then workspace else nil
		end
	end
	local w = water
	if not visible or not w then
		return
	end
	-- the disc is a cylinder turned upright: its axis (height) is Size.X
	local top = w.Position.Y + w.Size.X / 2
	local pondR = w.Size.Y / 2 - 3
	local t = workspace:GetServerTimeNow()
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, duck in ducks do
		local angle = duck.dir * (t / duck.period * math.pi * 2) + duck.phase
		local r = pondR * duck.radius
		local pos = Vector3.new(w.Position.X + math.cos(angle) * r, top, w.Position.Z + math.sin(angle) * r)
		local heading = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * duck.dir
		local bob = math.sin(t * 2 + duck.phase) * 0.04
		local base = CFrame.lookAt(pos, pos + heading) * CFrame.new(0, bob, 0)
		table.insert(moveParts, duck.body)
		table.insert(moveCFrames, base * CFrame.new(0, 0.15, 0))
		table.insert(moveParts, duck.head)
		table.insert(moveCFrames, base * CFrame.new(0, 0.75, -0.75))
	end
	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
