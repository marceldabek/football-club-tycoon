--!strict
-- Places kit models (bought/downloaded meshes plus Roblox Creator Store
-- freebies) from layout data. Every lookup can miss -- a fresh clone of the
-- repo has no `assets/kit/` output uploaded yet, and even a populated place
-- may be missing one name -- so every miss falls back to a grey block. This
-- keeps town-building code (which reads layout data, not the asset kit)
-- oblivious to whether the kit is actually installed.
--
-- Search order for a name (see assets/kit/MANIFEST.md and
-- assets/kit/_export/kit_ids.luau for what is actually uploaded):
--   ServerStorage.Kit.Meshes.<name>  -- uploaded kit GLBs (Rojo can't own these, they're binary)
--   ServerStorage.Kit.<name>         -- Creator Store models, stripped of scripts on import
--   ServerStorage.Kit.<Folder>.<name> -- the same, sorted into category folders (Town, Vehicles, ...)
--   ServerStorage.Assets.<dotted.path> -- generic asset library, see Assets.luau

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CarWheels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarWheels"))

local KitPlacer = {}

export type PlaceOpts = {
	fallbackSize: Vector3?,
	fallbackColor: Color3?,
	fallbackMaterial: Enum.Material?,
	snapToGround: boolean?,
	groundY: number?,
	yawJitter: number?, -- radians
	rng: Random?,
	scale: number?,
	-- X45: repaint a textured kit (the one-mesh hatchback ignores Color while its
	-- TextureID is set): clears every MeshPart's texture and sets this colour.
	-- The window and light detail goes with the texture.
	tint: Color3?,
}

local FALLBACK_SIZE = Vector3.new(4, 4, 4)
local FALLBACK_COLOR = Color3.fromRGB(150, 150, 150)

-- Swapped in by tests so they don't depend on ServerStorage.Kit existing (or
-- on polluting it). Callers must restore it to nil when done.
local libraryOverride: Instance? = nil

local warnedMissing: { [string]: boolean } = {}
local footprintCache: { [string]: Vector3 } = {}
local footprintMissing: { [string]: boolean } = {}

function KitPlacer.setLibraryRoot(folder: Instance?)
	libraryOverride = folder
	-- caches key on name only, so a stale entry from one root would leak into
	-- the next if we didn't clear them here
	table.clear(footprintCache)
	table.clear(footprintMissing)
	table.clear(warnedMissing)
end

local function kitRoot(): Instance?
	if libraryOverride then
		return libraryOverride
	end
	return ServerStorage:FindFirstChild("Kit")
end

-- Looks up `name`, returning the template instance itself (never a clone).
function KitPlacer.find(name: string): Instance?
	local root = kitRoot()
	if root then
		local meshes = root:FindFirstChild("Meshes")
		if meshes then
			local found = meshes:FindFirstChild(name)
			if found then
				return found
			end
		end
		local direct = root:FindFirstChild(name)
		if direct then
			return direct
		end
		-- category folders one level down (Kit.Town, Kit.Vehicles, Kit.Vegetation, ...)
		for _, folder in root:GetChildren() do
			if folder:IsA("Folder") then
				local found = folder:FindFirstChild(name)
				if found then
					return found
				end
			end
		end
	end

	-- same dotted-path traversal Assets.luau uses for ServerStorage.Assets
	local assetsRoot = ServerStorage:FindFirstChild("Assets")
	if assetsRoot then
		local node: Instance? = assetsRoot
		for segment in name:gmatch("[^%.]+") do
			if not node then
				return nil
			end
			node = node:FindFirstChild(segment)
		end
		if node and node ~= assetsRoot then
			return node
		end
	end

	return nil
end

-- Bounding-box size of the template, cached per name. nil if `name` resolves
-- to nothing (checked again next call in case the kit loads in later).
function KitPlacer.footprint(name: string): Vector3?
	local cached = footprintCache[name]
	if cached then
		return cached
	end
	if footprintMissing[name] then
		return nil
	end

	local template = KitPlacer.find(name)
	if not template then
		footprintMissing[name] = true
		return nil
	end

	local size: Vector3
	if template:IsA("BasePart") then
		size = (template :: BasePart).Size
	elseif template:IsA("Model") then
		local _, s = (template :: Model):GetBoundingBox()
		size = s
	else
		footprintMissing[name] = true
		return nil
	end

	footprintCache[name] = size
	return size
end

-- Pure geometry: given a model's current world bounding box (`bboxCFrame`,
-- `bboxSize`) and its current world pivot, returns the CFrame such that
-- `pivot * bottomCentreOffset(...) == bboxCFrame's bottom centre`. Kept free
-- of instances so the algebra can be unit tested directly.
function KitPlacer.bottomCentreOffset(bboxCFrame: CFrame, bboxSize: Vector3, pivot: CFrame): CFrame
	local relative = pivot:ToObjectSpace(bboxCFrame)
	return relative * CFrame.new(0, -bboxSize.Y / 2, 0)
end

local function stripDisallowed(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ClickDetector") then
			d:Destroy()
		end
	end
end

-- Applies yawJitter and snapToGround to the caller's target CFrame.
local function resolveTarget(cframe: CFrame, o: PlaceOpts): CFrame
	local rotation = cframe.Rotation
	local yawJitter = o.yawJitter
	if yawJitter and yawJitter ~= 0 then
		local rng = o.rng or Random.new()
		local jitter = rng:NextNumber(-yawJitter, yawJitter)
		rotation = rotation * CFrame.Angles(0, jitter, 0)
	end
	local pos = cframe.Position
	local y = if o.snapToGround then (o.groundY or 0) else pos.Y
	return CFrame.new(pos.X, y, pos.Z) * rotation
end

local function buildFallback(name: string, cframe: CFrame, parent: Instance, o: PlaceOpts): Model
	if not warnedMissing[name] then
		warnedMissing[name] = true
		warn(("KitPlacer: no kit asset named %q, using a fallback block"):format(name))
	end

	local size = o.fallbackSize or FALLBACK_SIZE
	local part = Instance.new("Part")
	part.Name = "Fallback"
	part.Anchored = true
	part.Size = size
	part.Material = o.fallbackMaterial or Enum.Material.SmoothPlastic
	part.Color = o.fallbackColor or FALLBACK_COLOR
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local target = resolveTarget(cframe, o)
	part.CFrame = target * CFrame.new(0, size.Y / 2, 0)

	local model = Instance.new("Model")
	model.Name = name
	part.Parent = model
	model.PrimaryPart = part
	model:SetAttribute("KitMissing", name)
	model:SetAttribute("Kit", name)
	model.Parent = parent
	return model
end

-- Clones `name` at `cframe` (bounding-box bottom centre at cframe's position,
-- rotated to cframe's rotation), parented under `parent`. Falls back to a
-- grey block (attribute KitMissing = name) if `name` isn't found.
function KitPlacer.place(name: string, cframe: CFrame, parent: Instance, opts: PlaceOpts?): Model
	local o: PlaceOpts = opts or {}

	local template = KitPlacer.find(name)
	if not template then
		return buildFallback(name, cframe, parent, o)
	end

	local clone = template:Clone()
	stripDisallowed(clone)

	local model: Model
	if clone:IsA("Model") then
		model = clone
	elseif clone:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = clone.Name
		clone.Parent = model
		model.PrimaryPart = clone :: BasePart
	else
		-- e.g. a Folder of parts with no Model wrapper
		model = Instance.new("Model")
		model.Name = clone.Name
		clone.Parent = model
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
		if o.tint and d:IsA("MeshPart") then
			d.TextureID = ""
			d.Color = o.tint
		end
	end

	local scale = o.scale
	if scale and math.abs(scale - 1) > 1e-4 then
		model:ScaleTo(scale)
	end

	local pivot = model:GetPivot()
	local bboxCFrame, bboxSize = model:GetBoundingBox()
	local offset = KitPlacer.bottomCentreOffset(bboxCFrame, bboxSize, pivot)
	local target = resolveTarget(cframe, o)
	model:PivotTo(target * offset:Inverse())

	-- `offset` was measured against the template's own (usually unrotated)
	-- pose, so a world-axis-aligned bounding box can shift a little once the
	-- model is actually rotated to face `target`. Recompute once and nudge the
	-- model so the bottom centre lands on `target` exactly (same trick as
	-- Assets.place's fix-up pass).
	local cf2, size2 = model:GetBoundingBox()
	local actualBottom = cf2.Position - Vector3.new(0, size2.Y / 2, 0)
	local correction = target.Position - actualBottom
	if correction.Magnitude > 1e-5 then
		model:PivotTo(model:GetPivot() + correction)
	end

	-- after the bounding-box placement, so the wheels cannot shift it
	if CarWheels.SPEC[name] then
		local faceKit = KitPlacer.find(CarWheels.FACE_KIT)
		local face = faceKit and faceKit:FindFirstChild(CarWheels.FACE_PART, true)
		CarWheels.fitParked(model, name, if face and face:IsA("BasePart") then face else nil)
	end

	model:SetAttribute("Kit", name)
	model.Parent = parent
	return model
end

-- Places `count` copies of `name` starting at `from`, marching along
-- `from.RightVector` (so `from`'s facing/rotation is preserved for every
-- copy). `spacing` defaults to the template's footprint width plus a gap.
function KitPlacer.row(name: string, from: CFrame, count: number, spacing: number?, parent: Instance, opts: PlaceOpts?): { Model }
	local o: PlaceOpts = opts or {}
	local step = spacing
	if not step then
		local footprint = KitPlacer.footprint(name)
		local fallbackX = if o.fallbackSize then o.fallbackSize.X else FALLBACK_SIZE.X
		step = (if footprint then footprint.X else fallbackX) + 0.2
	end

	local rotation = from.Rotation
	local models: { Model } = {}
	for i = 0, count - 1 do
		local pos = from.Position + from.RightVector * (step * i)
		local cf = CFrame.new(pos) * rotation
		table.insert(models, KitPlacer.place(name, cf, parent, o))
	end
	return models
end

return KitPlacer
