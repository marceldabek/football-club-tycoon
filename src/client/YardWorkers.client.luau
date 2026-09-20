--!strict
-- Hi-vis workers in the industrial estate yards (backlog X147,
-- rivermer.industrialestate.png). Client-only, like PlayAreaLife: for sheds
-- within NEAR of the camera, a worker in a yellow vest and white hard hat
-- stands beside each forklift, and one walks slowly up and down beside each
-- parked lorry. At most MAX_WORKERS at once (4 parts each), gone on Quality
-- "Low". Reads the shed models EstateBuilder.shed builds (Yard, Trailer,
-- ForkliftYellow kit or the primitive ForkliftBody).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Townsfolk = require(script.Parent.Townsfolk)

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local NEAR = 260
local MAX_WORKERS = 6
local FORKLIFT_KIT = "ForkliftYellow" -- EstateBuilder.FORKLIFT_KIT
local PACE_HALF = 8 -- studs either side of the trailer's middle
local PACE_SPEED = 0.18 -- radians a second along the sine

local VEST = Color3.fromRGB(236, 214, 40)
local TROUSERS = Color3.fromRGB(40, 44, 56)
local SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }
local HAT_ABOVE_HEAD = 0.52 -- old figure had head at y=4.1, hat at y=4.62

type Worker = { fig: Townsfolk.Figure, hat: BasePart, base: CFrame, pace: boolean, phase: number }
type Yard = { folder: Folder, workers: { Worker } }
local yards: { [Model]: Yard } = {}

local function part(parent: Instance, name: string, size: Vector3, colour: Color3, shape: Enum.PartType?): BasePart
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
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- a standing worker with feet at `base` (base.Position is between the feet,
-- on the ground, base looks the way the figure faces). Returns nil when the
-- shared rig could not be built; the caller must skip this spot rather than
-- falling back to blocks.
local function worker(parent: Instance, base: CFrame, pace: boolean, i: number): Worker?
	local fig = Townsfolk.build(parent, {
		shirt = VEST,
		trousers = TROUSERS,
		skin = SKIN[(i % #SKIN) + 1],
	})
	if not fig then
		return nil
	end
	Townsfolk.pose(fig, base)
	-- a cylinder's axis is its local X: stand the hard hat up, just above the head
	local hat = part(parent, "HardHat", Vector3.new(0.35, 1.1, 1.1), Color3.fromRGB(245, 245, 240), Enum.PartType.Cylinder)
	hat.CFrame = base * CFrame.new(0, Townsfolk.HEAD_Y + HAT_ABOVE_HEAD, 0) * CFrame.Angles(0, 0, math.pi / 2)
	return { fig = fig, hat = hat, base = base, pace = pace, phase = i * 1.7 }
end

local function build(shed: Model, budget: number): Yard?
	local yardPart = shed:FindFirstChild("Yard")
	if not (yardPart and yardPart:IsA("BasePart")) or budget <= 0 then
		return nil
	end
	local ground = yardPart.Position.Y + yardPart.Size.Y / 2
	local spots: { { cf: CFrame, pace: boolean } } = {}
	local trailer = shed:FindFirstChild("Trailer")
	local kit = shed:FindFirstChild(FORKLIFT_KIT)
	local body = shed:FindFirstChild("ForkliftBody")
	if trailer and trailer:IsA("BasePart") then
		-- the lorry runs along the yard (local Z); walk its shed-side flank (+X)
		local side = trailer.CFrame * CFrame.new(trailer.Size.X / 2 + 2, 0, 0)
		table.insert(spots, { cf = CFrame.new(side.X, ground, side.Z) * trailer.CFrame.Rotation, pace = true })
	elseif kit and kit:IsA("Model") then
		-- the kit's pivot is far from its mesh, so use its bounding box, and stand
		-- on the yard's -Z side of it (the forklift parks near the +Z fence)
		local pivot = kit:GetBoundingBox()
		local at = pivot + yardPart.CFrame.LookVector * 4.5
		table.insert(spots, { cf = CFrame.lookAt(Vector3.new(at.X, ground, at.Z), Vector3.new(pivot.X, ground, pivot.Z)), pace = false })
	elseif body and body:IsA("BasePart") then
		local at = body.CFrame * CFrame.new(0, 0, 3)
		table.insert(spots, { cf = CFrame.lookAt(Vector3.new(at.X, ground, at.Z), Vector3.new(body.Position.X, ground, body.Position.Z)), pace = false })
	end
	if #spots == 0 then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "YardWorkers"
	folder.Parent = shed
	local workers = {}
	for i, spot in spots do
		if i > budget then
			break
		end
		-- seeded from the yard's position so neighbouring workers differ
		local w = worker(folder, spot.cf, spot.pace, i + math.floor(math.abs(yardPart.Position.X + yardPart.Position.Z)))
		if w then
			table.insert(workers, w)
		end
	end
	return { folder = folder, workers = workers }
end

local sheds: { [Model]: boolean } = {}
local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "Shed" then
		sheds[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

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
		local ranked = {}
		if not low then
			for shed in sheds do
				local yardPart = shed:FindFirstChild("Yard")
				if not shed.Parent then
					sheds[shed] = nil
				elseif yardPart and yardPart:IsA("BasePart") then
					local d = (yardPart.Position - cam).Magnitude
					if d < NEAR then
						table.insert(ranked, { shed = shed, d = d })
					end
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
		local seen: { [Model]: boolean } = {}
		local count = 0
		for _, entry in ranked do
			local y = yards[entry.shed]
			if not y then
				y = build(entry.shed, MAX_WORKERS - count)
				if y then
					yards[entry.shed] = y
				end
			end
			if y then
				if count + #y.workers > MAX_WORKERS then
					break
				end
				count += #y.workers
				seen[entry.shed] = true
			end
		end
		for shed, y in yards do
			if not seen[shed] or not shed.Parent then
				y.folder:Destroy()
				yards[shed] = nil
			end
		end
	end
	for _, y in yards do
		for _, w in y.workers do
			if w.pace then
				local s = math.sin(elapsed * PACE_SPEED + w.phase)
				-- figures face -Z, so walking toward +Z turns them round
				local heading = if math.cos(elapsed * PACE_SPEED + w.phase) >= 0 then math.pi else 0
				local base = w.base * CFrame.new(0, 0, s * PACE_HALF) * CFrame.Angles(0, heading, 0)
				Townsfolk.pose(w.fig, base)
				w.hat.CFrame = base * CFrame.new(0, Townsfolk.HEAD_Y + HAT_ABOVE_HEAD, 0) * CFrame.Angles(0, 0, math.pi / 2)
			end
		end
	end
end)
