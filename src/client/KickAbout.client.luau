--!strict
-- A kickabout at the Community Sports Centre (backlog X181, RivermereAImap.png).
-- Client-only: on the nearest "grass pitch" slab within NEAR of the camera,
-- six people in a loose ring pass a ball between them, each turning to face
-- the ball. 3 parts a figure plus the ball (19 parts); off on Quality "Low".
-- The pitch is the greybox slab SportsCentreDresser recolours in place.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local NEAR = 300
local PEOPLE = 6
local RING = 11
local PASS_TIME = 1.3
local SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }
local SHIRTS = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 210), Color3.fromRGB(250, 200, 60), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 150, 90), Color3.fromRGB(30, 30, 34) }

local folder = Instance.new("Folder")
folder.Name = "KickAbout"

local function part(name: string, size: Vector3, colour: Color3, ball: boolean?, face: boolean?): BasePart
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
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	if face then
		local d = Instance.new("Decal")
		d.Name = "Face"
		d.Face = Enum.NormalId.Front
		d.Texture = "rbxasset://textures/face.png"
		d.Parent = p
	end
	p.Parent = folder
	return p
end

local people: { { BasePart } } = {}
for i = 1, PEOPLE do
	table.insert(people, {
		part("Legs", Vector3.new(1.2, 1.8, 0.6), Color3.fromRGB(40, 44, 60)),
		part("Torso", Vector3.new(1.6, 1.8, 0.8), SHIRTS[i]),
		part("Head", Vector3.one, SKIN[(i % #SKIN) + 1], true, true),
	})
end
local ball = part("Football", Vector3.one * 0.9, Color3.fromRGB(245, 245, 245), true)

local pitches: { BasePart } = {}
for _, d in town:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "grass pitch" then
		table.insert(pitches, d)
	end
end
town.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") and d.Name == "grass pitch" then
		table.insert(pitches, d)
	end
end)

local pitch: BasePart? = nil
local from, to = 1, 2
local passT = 0
local rng = Random.new(7)

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local check = 0
local elapsed = 0

RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	check -= dt
	if check <= 0 then
		check = 2
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		local best: BasePart? = nil
		local bestD = NEAR
		for i = #pitches, 1, -1 do
			if not pitches[i].Parent then
				table.remove(pitches, i)
			end
		end
		if player:GetAttribute("Quality") ~= "Low" then
			for _, p in pitches do
				if p.Parent then
					local d = Vector3.new(p.Position.X - cam.X, 0, p.Position.Z - cam.Z).Magnitude
					if d < bestD then
						best, bestD = p, d
					end
				end
			end
		end
		pitch = best
		folder.Parent = if best then workspace else nil
	end
	local p = pitch
	if not p then
		return
	end
	local top = p.Position.Y + p.Size.Y / 2
	-- spots round the ring, off-centre so the centre circle stays clear
	local centre = Vector3.new(p.Position.X, top, p.Position.Z) + Vector3.new(RING * 3, 0, 0)
	local spots: { Vector3 } = {}
	for i = 1, PEOPLE do
		local a = (i / PEOPLE) * math.pi * 2
		table.insert(spots, centre + Vector3.new(math.cos(a) * RING, 0, math.sin(a) * RING))
	end
	passT += dt
	if passT >= PASS_TIME then
		passT = 0
		from = to
		to = rng:NextInteger(1, PEOPLE - 1)
		if to >= from then
			to += 1
		end
	end
	local k = passT / PASS_TIME
	local a, b = spots[from], spots[to]
	local ballPos = a:Lerp(b, k) + Vector3.new(0, 0.45 + math.sin(k * math.pi) * 1.2, 0)
	table.clear(moveParts)
	table.clear(moveCFrames)
	for i, parts in people do
		local s = spots[i]
		local look = Vector3.new(ballPos.X, s.Y, ballPos.Z)
		if (look - s).Magnitude < 0.1 then
			look = centre
		end
		local root = CFrame.lookAt(s, look)
		table.insert(moveParts, parts[1])
		table.insert(moveCFrames, root * CFrame.new(0, 0.9, 0))
		table.insert(moveParts, parts[2])
		table.insert(moveCFrames, root * CFrame.new(0, 2.7, 0))
		table.insert(moveParts, parts[3])
		table.insert(moveCFrames, root * CFrame.new(0, 4.1, 0))
	end
	table.insert(moveParts, ball)
	table.insert(moveCFrames, CFrame.new(ballPos))
	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
