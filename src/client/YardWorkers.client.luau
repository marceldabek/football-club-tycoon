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

type Worker = { parts: { BasePart }, offsets: { CFrame }, base: CFrame, pace: boolean, phase: number }
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

-- a standing worker with feet at the frame's origin, facing its -Z
local function worker(parent: Instance, base: CFrame, pace: boolean, i: number): Worker
	local head = part(parent, "Head", Vector3.one, SKIN[(i % #SKIN) + 1], Enum.PartType.Ball)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local parts = {
		part(parent, "Legs", Vector3.new(1.2, 1.8, 0.6), TROUSERS),
		part(parent, "Vest", Vector3.new(1.6, 1.8, 0.8), VEST),
		head,
		-- a cylinder's axis is its local X: stand the hat up
		part(parent, "HardHat", Vector3.new(0.35, 1.1, 1.1), Color3.fromRGB(245, 245, 240), Enum.PartType.Cylinder),
	}
	local offsets = {
		CFrame.new(0, 0.9, 0),
		CFrame.new(0, 2.7, 0),
		CFrame.new(0, 4.1, 0),
		CFrame.new(0, 4.62, 0) * CFrame.Angles(0, 0, math.pi / 2),
	}
	for k, p in parts do
		p.CFrame = base * offsets[k]
	end
	return { parts = parts, offsets = offsets, base = base, pace = pace, phase = i * 1.7 }
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
		table.insert(workers, worker(folder, spot.cf, spot.pace, i + math.floor(math.abs(yardPart.Position.X + yardPart.Position.Z))))
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

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
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
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, y in yards do
		for _, w in y.workers do
			if w.pace then
				local s = math.sin(elapsed * PACE_SPEED + w.phase)
				-- figures face -Z, so walking toward +Z turns them round
				local heading = if math.cos(elapsed * PACE_SPEED + w.phase) >= 0 then math.pi else 0
				local base = w.base * CFrame.new(0, 0, s * PACE_HALF) * CFrame.Angles(0, heading, 0)
				for k, p in w.parts do
					table.insert(moveParts, p)
					table.insert(moveCFrames, base * w.offsets[k])
				end
			end
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
