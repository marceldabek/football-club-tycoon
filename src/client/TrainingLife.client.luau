--!strict
-- A training session on each club's training pitches (backlog X180, X289).
-- Client-only: while a club is between matches (Phase "Manage") and its
-- pitch is within NEAR of the camera, six players in the home kit jog a slow
-- loop round cones inside the pitch and a coach in a navy tracksuit watches
-- from the touchline. 3 parts a player, 4 a cone set; off on Quality "Low".
-- The pitches are PlotGrounds' TrainingPitch1/2 "Grass" parts; the plot's club
-- state is ReplicatedStorage.Clubs[<plot name>]. X289: pitch 2 is the
-- academy's - smaller figures, and only as many as this season's intake.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService") -- X289: the academy intake

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

local NEAR = 300
local PLAYERS = 6
local SPEED = 7 -- studs a second along the loop
local LOOP_SHARE = Vector2.new(0.32, 0.3) -- loop half-size as a share of the grass size (X, Z), inside the coach
local SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }

type Session = { folder: Folder, grass: BasePart, runners: { { BasePart } }, phase: number, scale: number }
local sessions: { [BasePart]: Session } = {}

local function part(parent: Instance, name: string, size: Vector3, colour: Color3, cf: CFrame?, ball: boolean?): BasePart
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
	if cf then
		p.CFrame = cf
	end
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

-- the loop in the grass's frame: a rectangle (half sizes hx, hz), distance s
local function loopPoint(hx: number, hz: number, s: number): (Vector3, Vector3)
	local perim = 4 * (hx + hz)
	s = s % perim
	if s < 2 * hx then
		return Vector3.new(-hx + s, 0, -hz), Vector3.new(1, 0, 0)
	elseif s < 2 * hx + 2 * hz then
		return Vector3.new(hx, 0, -hz + (s - 2 * hx)), Vector3.new(0, 0, 1)
	elseif s < 4 * hx + 2 * hz then
		return Vector3.new(hx - (s - 2 * hx - 2 * hz), 0, hz), Vector3.new(-1, 0, 0)
	end
	return Vector3.new(-hx, 0, hz - (s - 4 * hx - 2 * hz)), Vector3.new(0, 0, -1)
end

-- How many academy players the club has brought up this season (X289).
local function intakeCount(state: Instance?): number
	local raw = if state then state:GetAttribute("Academy") else nil
	if type(raw) ~= "string" or raw == "" then
		return 0
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(list) ~= "table" then
		return 0
	end
	local n = 0
	for _, line in list do
		if type(line) == "string" then
			n += 1
		end
	end
	return n
end

-- X289: pitch 2 is the academy's — the same session with smaller figures, and
-- only as many of them as this season's intake, so the youth setup the academy
-- hut advertises is actually out there training.
local function build(grass: BasePart, youth: boolean, count: number): Session
	local folder = Instance.new("Folder")
	folder.Name = "TrainingLife"
	folder.Parent = workspace
	local top = grass.CFrame * CFrame.new(0, grass.Size.Y / 2, 0)
	local hx, hz = grass.Size.X * LOOP_SHARE.X, grass.Size.Z * LOOP_SHARE.Y
	-- cones at the loop's corners
	for _, c in { Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz) } do
		part(folder, "Cone", Vector3.new(0.9, 1.1, 0.9), Color3.fromRGB(240, 120, 30), top * CFrame.new(c + Vector3.new(0, 0.55, 0)))
	end
	local scale = if youth then 0.82 else 1
	local runners = {}
	for i = 1, math.max(count, 1) do
		table.insert(runners, {
			part(folder, "Legs", Vector3.new(1.2, 1.8, 0.6) * scale, Color3.fromRGB(245, 245, 245)),
			part(folder, "Torso", Vector3.new(1.6, 1.8, 0.8) * scale, Config.HomeKit),
			part(folder, "Head", Vector3.one * scale, SKIN[(i % #SKIN) + 1], nil, true),
		})
	end
	-- the coach on the touchline, watching the middle
	local coachAt = top * CFrame.new(grass.Size.X / 2 - 3, 0, 0)
	local coach = CFrame.lookAt(coachAt.Position, top.Position)
	part(folder, "CoachLegs", Vector3.new(1.2, 1.8, 0.6), Color3.fromRGB(24, 32, 60), coach * CFrame.new(0, 0.9, 0))
	part(folder, "CoachTorso", Vector3.new(1.6, 1.8, 0.8), Color3.fromRGB(24, 32, 60), coach * CFrame.new(0, 2.7, 0))
	part(folder, "CoachHead", Vector3.one, SKIN[1], coach * CFrame.new(0, 4.1, 0), true)
	return { folder = folder, grass = grass, runners = runners, phase = math.random() * 50, scale = scale }
end

type Pitch = { plot: string, youth: boolean }
local pitches: { [BasePart]: Pitch } = {}
local function consider(inst: Instance)
	local parentName = inst.Parent and inst.Parent.Name
	if inst:IsA("BasePart") and inst.Name == "Grass" and (parentName == "TrainingPitch1" or parentName == "TrainingPitch2") then
		local node: Instance? = inst
		while node and not (node.Parent and node.Parent.Name == "Plots") do
			node = node.Parent
		end
		if node then
			pitches[inst] = { plot = node.Name, youth = parentName == "TrainingPitch2" }
		end
	end
end
task.spawn(function()
	local plots = workspace:WaitForChild("Plots", math.huge)
	for _, d in plots:GetDescendants() do
		consider(d)
	end
	plots.DescendantAdded:Connect(consider)
end)

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local recheck = 0
local elapsed = 0

RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	recheck -= dt
	if recheck <= 0 then
		recheck = 2
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		local low = player:GetAttribute("Quality") == "Low"
		local clubs = ReplicatedStorage:FindFirstChild("Clubs")
		local want: { [BasePart]: boolean } = {}
		if not low and clubs then
			for grass, pitch in pitches do
				if not grass.Parent then
					pitches[grass] = nil
					continue
				end
				local state = clubs:FindFirstChild(pitch.plot)
				if grass.Parent and state and state:GetAttribute("Phase") == "Manage" and (grass.Position - cam).Magnitude < NEAR then
					-- X289: the academy pitch only has a session on it when the
					-- academy has actually produced somebody this season
					want[grass] = if pitch.youth then intakeCount(state) > 0 else true
				end
			end
		end
		for grass, s in sessions do
			if not want[grass] then
				s.folder:Destroy()
				sessions[grass] = nil
			end
		end
		for grass in want do
			if not sessions[grass] then
				local pitch = pitches[grass]
				local youth = pitch ~= nil and pitch.youth
				local count = if youth then intakeCount(clubs:FindFirstChild((pitch :: Pitch).plot)) else PLAYERS
				sessions[grass] = build(grass, youth, math.clamp(count, 1, PLAYERS))
			end
		end
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, s in sessions do
		local g = s.grass
		local top = g.CFrame * CFrame.new(0, g.Size.Y / 2, 0)
		local hx, hz = g.Size.X * LOOP_SHARE.X, g.Size.Z * LOOP_SHARE.Y
		for i, parts in s.runners do
			local dist = (elapsed + s.phase) * SPEED + (i - 1) * 7
			local p, dir = loopPoint(hx, hz, dist)
			-- a jogger's bounce
			local bob = math.abs(math.sin((elapsed + i) * 7)) * 0.2
			local root = top * CFrame.lookAt(p, p + dir) * CFrame.new(0, bob, 0)
			local k = s.scale or 1
			table.insert(moveParts, parts[1])
			table.insert(moveCFrames, root * CFrame.new(0, 0.9 * k, 0))
			table.insert(moveParts, parts[2])
			table.insert(moveCFrames, root * CFrame.new(0, 2.7 * k, 0))
			table.insert(moveParts, parts[3])
			table.insert(moveCFrames, root * CFrame.new(0, 4.1 * k, 0))
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
