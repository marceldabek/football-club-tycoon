--!strict
-- Life in the estates' play areas (backlog X139): a child swinging on the
-- left swing, another at the foot of the slide and a grown-up on the bench.
-- Client-only, like the café sitters. The swinging child moves the left seat
-- and its two chains with it (local-only CFrame changes on anchored parts).
-- Built when a PlayArea streams in near the camera; gone on Quality "Low".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local NEAR = 260
local SWING_PERIOD = 2.6
local SWING_ANGLE = math.rad(28)
local PIVOT_Y = 8 -- EstateDresser: the swing bar's height above the play area frame

local SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }
local TOPS = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 210), Color3.fromRGB(250, 200, 60), Color3.fromRGB(90, 170, 90) }

type Area = { model: Model, parts: { BasePart }, swingParts: { BasePart }, swingRest: { CFrame }, pivot: CFrame, phase: number }
local areas: { [Model]: Area } = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, ball: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	if ball then
		p.Shape = Enum.PartType.Ball
		local face = Instance.new("Decal")
		face.Name = "Face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = p
	end
	p.Parent = parent
	return p
end

-- a figure standing (or sitting, legs forward) at `base` (feet level, facing -Z)
local function figure(parent: Instance, base: CFrame, scale: number, sitting: boolean, i: number): { BasePart }
	local s = scale
	local top = TOPS[(i % #TOPS) + 1]
	local out = {}
	if sitting then
		table.insert(out, part(parent, "Legs", Vector3.new(1.2, 0.5, 1.4) * s, base * CFrame.new(0, 0.25 * s, -0.55 * s), Color3.fromRGB(40, 44, 60)))
		table.insert(out, part(parent, "Torso", Vector3.new(1.6, 1.8, 0.8) * s, base * CFrame.new(0, 1.4 * s, 0), top))
		table.insert(out, part(parent, "Head", Vector3.one * 1.0 * s, base * CFrame.new(0, 2.8 * s, 0), SKIN[(i % #SKIN) + 1], true))
	else
		table.insert(out, part(parent, "Legs", Vector3.new(1.2, 1.8, 0.6) * s, base * CFrame.new(0, 0.9 * s, 0), Color3.fromRGB(40, 44, 60)))
		table.insert(out, part(parent, "Torso", Vector3.new(1.6, 1.8, 0.8) * s, base * CFrame.new(0, 2.7 * s, 0), top))
		table.insert(out, part(parent, "Head", Vector3.one * 1.0 * s, base * CFrame.new(0, 4.1 * s, 0), SKIN[(i % #SKIN) + 1], true))
	end
	return out
end

local function build(area: Model): Area?
	local surface = area:FindFirstChild("Surface")
	if not (surface and surface:IsA("BasePart")) then
		return nil
	end
	-- EstateDresser's play-area frame: origin at ground under Surface, -Z to the gate
	local cf = surface.CFrame * CFrame.new(0, -0.15, 0)
	local folder = Instance.new("Folder")
	folder.Name = "PlayAreaLife"
	folder.Parent = area
	-- X174: children playing, heard near the area (Pro Sound Effects, licensed
	-- library: "Park Playgrounds 1"); removed in teardown
	local sound = Instance.new("Sound")
	sound.Name = "Playground"
	sound.SoundId = "rbxassetid://9112841549"
	sound.Looped = true
	sound.Volume = 0.35
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 20
	sound.RollOffMaxDistance = 140
	sound.TimePosition = math.random() * 20
	sound.Parent = surface
	sound:Play()
	local parts: { BasePart } = {}
	-- the left swing's seat and chains (x -2.2 in the swing frame at (6, 0, 7))
	local swing = cf * CFrame.new(6, 0, 7)
	local swingParts: { BasePart } = {}
	for _, d in area:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "SwingSeat" or d.Name == "Chain") then
			local lx = swing:PointToObjectSpace(d.Position).X
			if lx < 0 then
				table.insert(swingParts, d)
			end
		end
	end
	-- a child sitting on that seat, facing the gate (-Z)
	for _, p in figure(folder, swing * CFrame.new(-2.2, 1.9, 0), 0.6, true, 1) do
		table.insert(swingParts, p)
		table.insert(parts, p)
	end
	local rest = {}
	for _, p in swingParts do
		table.insert(rest, p.CFrame)
	end
	-- a child at the foot of the slide and a grown-up on the bench
	for _, p in figure(folder, cf * CFrame.new(-7, 0.3, -5.5) * CFrame.Angles(0, math.rad(200), 0), 0.6, false, 2) do
		table.insert(parts, p)
	end
	for _, p in figure(folder, cf * CFrame.new(8, 1.65, -10) * CFrame.Angles(0, math.pi, 0), 1, true, 3) do
		table.insert(parts, p)
	end
	return {
		model = area,
		parts = parts,
		swingParts = swingParts,
		swingRest = rest,
		pivot = swing * CFrame.new(-2.2, PIVOT_Y, 0),
		phase = math.random() * math.pi * 2,
	}
end

local function teardown(area: Area)
	for i, p in area.swingParts do
		if p.Parent and area.swingRest[i] then
			p.CFrame = area.swingRest[i]
		end
	end
	local f = area.model:FindFirstChild("PlayAreaLife")
	if f then
		f:Destroy()
	end
	local surface = area.model:FindFirstChild("Surface")
	local sound = surface and surface:FindFirstChild("Playground")
	if sound then
		sound:Destroy()
	end
end

local elapsed = 0
local recheck = 0
RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	recheck -= dt
	if recheck <= 0 then
		recheck = 1.5
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		local low = player:GetAttribute("Quality") == "Low"
		local estates = town:FindFirstChild("Estates")
		local seen: { [Model]: boolean } = {}
		if estates and not low then
			for _, d in estates:GetChildren() do
				if d:IsA("Model") and d.Name == "PlayArea" then
					local surface = d:FindFirstChild("Surface")
					if surface and surface:IsA("BasePart") and (surface.Position - cam).Magnitude < NEAR then
						seen[d] = true
						if not areas[d] then
							local a = build(d)
							if a then
								areas[d] = a
							end
						end
					end
				end
			end
		end
		for model, a in areas do
			if not seen[model] or not model.Parent then
				teardown(a)
				areas[model] = nil
			end
		end
	end
	for _, a in areas do
		local angle = math.sin(elapsed * math.pi * 2 / SWING_PERIOD + a.phase) * SWING_ANGLE
		local turn = a.pivot * CFrame.Angles(angle, 0, 0) * a.pivot:Inverse()
		for i, p in a.swingParts do
			p.CFrame = turn * a.swingRest[i]
		end
	end
end)
