--!strict
-- Life in the estates' play areas (backlog X139): a child swinging on the
-- left swing, another at the foot of the slide and a grown-up on the bench.
-- Client-only, like the café sitters. The swinging child moves the left seat
-- and its two chains with it (local-only CFrame changes on anchored parts).
-- Built when a PlayArea streams in near the camera; gone on Quality "Low".

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Townsfolk = require(script.Parent.Townsfolk)

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

-- a figure standing (or sitting, legs forward) at `base`, scaled by `scale`.
-- Standing: base.Position is between the feet, on the ground. Sitting: base
-- sits on the seat surface. Both face -Z. Returns nil when the shared rig
-- could not be built; the caller must skip this figure rather than falling
-- back to blocks.
--
-- ScaleTo shrinks the parts but not the pose offsets, so `scale` is passed
-- through to pose/poseSeated as well; without it a 0.6-scale child's feet
-- float clear of `base`.
local function personAt(parent: Instance, base: CFrame, scale: number, sitting: boolean, i: number): Townsfolk.Figure?
	local fig = Townsfolk.build(parent, {
		shirt = TOPS[(i % #TOPS) + 1],
		trousers = Color3.fromRGB(40, 44, 60),
		skin = SKIN[(i % #SKIN) + 1],
	})
	if not fig then
		return nil
	end
	if scale ~= 1 then
		fig.model:ScaleTo(scale)
	end
	if sitting then
		Townsfolk.poseSeated(fig, base, scale)
	else
		Townsfolk.pose(fig, base, nil, nil, scale)
	end
	return fig
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
	local swingChild = personAt(folder, swing * CFrame.new(-2.2, 1.9, 0), 0.6, true, 1)
	if swingChild then
		for _, p in swingChild.all do
			table.insert(swingParts, p)
			table.insert(parts, p)
		end
	end
	local rest = {}
	for _, p in swingParts do
		table.insert(rest, p.CFrame)
	end
	-- a child at the foot of the slide and a grown-up on the bench
	local slideChild = personAt(folder, cf * CFrame.new(-7, 0.3, -5.5) * CFrame.Angles(0, math.rad(200), 0), 0.6, false, 2)
	if slideChild then
		for _, p in slideChild.all do
			table.insert(parts, p)
		end
	end
	local benchSitter = personAt(folder, cf * CFrame.new(8, 1.65, -10) * CFrame.Angles(0, math.pi, 0), 1, true, 3)
	if benchSitter then
		for _, p in benchSitter.all do
			table.insert(parts, p)
		end
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
