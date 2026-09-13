--!strict
-- Asset library: Creator Store / generated models kept in the place file under
-- ServerStorage.Assets (not on disk, see README "Assets"). Every caller must
-- cope with a missing asset and fall back to primitives, so a fresh clone of
-- the repo still builds a complete (uglier) world.

local ServerStorage = game:GetService("ServerStorage")

local Assets = {}

local function library(): Folder?
	return ServerStorage:FindFirstChild("Assets") :: Folder?
end

-- A fresh clone of ServerStorage.Assets.<path> (dots allowed), or nil.
function Assets.clone(path: string): Instance?
	local node: Instance? = library()
	for segment in path:gmatch("[^%.]+") do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	if not node then
		return nil
	end
	local copy = node:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- never run store scripts (CLAUDE.md agent rule 9)
		end
	end
	return copy
end

function Assets.has(path: string): boolean
	local node: Instance? = library()
	for segment in path:gmatch("[^%.]+") do
		if not node then
			return false
		end
		node = node:FindFirstChild(segment)
	end
	return node ~= nil
end

-- Names of the models in a folder (for random picks), or {}.
function Assets.list(path: string): { string }
	local node: Instance? = library()
	for segment in path:gmatch("[^%.]+") do
		if not node then
			return {}
		end
		node = node:FindFirstChild(segment)
	end
	local names = {}
	if node then
		for _, c in node:GetChildren() do
			if c:IsA("Model") then
				table.insert(names, c.Name)
			end
		end
	end
	table.sort(names)
	return names
end

export type Placed = { model: Model, size: Vector3 }

-- Clone, scale so the bounding box height matches `height` (or by `scale`),
-- stand it on the ground at `position` facing `lookAt` (XZ only), parent it.
-- `yawOffset` (radians) corrects models whose own front is not their -Z.
function Assets.place(path: string, position: Vector3, parent: Instance, opts: { height: number?, scale: number?, lookAt: Vector3?, name: string?, flip: boolean?, yawOffset: number? }?): Placed?
	local o = opts or {}
	local inst = Assets.clone(path)
	if not inst or not inst:IsA("Model") then
		if inst then
			inst:Destroy()
		end
		return nil
	end
	local model = inst :: Model
	local _, size0 = model:GetBoundingBox()
	local scale = o.scale or (if o.height then o.height / math.max(size0.Y, 0.01) else 1)
	if math.abs(scale - 1) > 0.001 then
		model:ScaleTo(scale)
	end
	local cf, size = model:GetBoundingBox()
	-- rotate to face lookAt (flat), then drop so the box bottom sits on position.Y
	local yaw = 0
	if o.lookAt then
		local d = o.lookAt - position
		yaw = math.atan2(-d.X, -d.Z)
		if o.flip then
			yaw += math.pi
		end
	end
	yaw += o.yawOffset or 0
	local target = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	-- move so the bounding-box centre sits at target, then lift by half the height
	local pivotToBox = model:GetPivot():ToObjectSpace(cf)
	model:PivotTo(target * pivotToBox:Inverse() * CFrame.new(0, size.Y / 2, 0))
	-- fix up: recompute and align the bottom exactly
	local cf2, size2 = model:GetBoundingBox()
	local dy = (position.Y) - (cf2.Position.Y - size2.Y / 2)
	model:PivotTo(model:GetPivot() + Vector3.new(0, dy, 0))
	if o.name then
		model.Name = o.name
	end
	model.Parent = parent
	return { model = model, size = size2 }
end

return Assets
