--!strict
-- Mesh trees and bushes for the town and the club plots, from the oak pack the
-- vertical slice used (ServerStorage.Kit.Vegetation.OakPack6, six oaks of two
-- or three MeshParts each: a trunk with branches, and alpha-card leaf clumps).
-- Marcel, 2026-09-21: the ball-on-a-stick trees go; use the slice's trees and
-- put bushes down too.
--
-- The pack is binary and lives in the place file, so every call can miss:
-- `tree` and `bush` return nil when the pack isn't there and the caller builds
-- its old primitive instead (same contract as Assets.place / KitPlacer).
--
-- A bush is two of the spreading oaks' crowns on their own, scaled down, crossed
-- and sat in the ground, so bushes and trees share one look and no extra asset
-- is needed.

local ServerStorage = game:GetService("ServerStorage")

local TreeKit = {}

TreeKit.PACK = "OakPack6"
-- Oaks at most this wide (as stored) are the upright ones; kerbs, paths and
-- planters ask for these so a crown doesn't spread over the road or a roof.
TreeKit.SLIM_WIDTH = 25
local SINK = 0.3 -- the trunk flare goes this far into the ground
local BUSH_BURY = 0.35 -- share of a bush's crown that sits below the ground
local BUSH_TALL = 1.6 -- a bush's crowns are stretched this much upward

export type TreeOpts = {
	height: number?, -- bounding-box height in studs (default: as stored, ~27..44)
	slim: boolean?, -- only the upright oaks
	rng: Random?,
	name: string?,
	collide: boolean?, -- default true: an invisible post on the trunk line
}

export type BushOpts = {
	width: number?, -- default 5
	rng: Random?,
	name: string?,
}

type Variant = {
	template: Model,
	size: Vector3,
	trunk: MeshPart?,
	leaf: MeshPart?, -- the biggest leaf clump
}

local libraryOverride: Instance? = nil
local cache: { Variant }? = nil

-- Tests swap the pack for a stand-in (or for an empty folder, to force misses).
function TreeKit.setLibraryRoot(root: Instance?)
	libraryOverride = root
	cache = nil
end

local function isLeaf(p: MeshPart): boolean
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	return sa ~= nil and sa.AlphaMode == Enum.AlphaMode.Transparency
end

local function volume(v: Vector3): number
	return v.X * v.Y * v.Z
end

local function findPack(): Instance?
	if libraryOverride then
		return libraryOverride
	end
	local kit = ServerStorage:FindFirstChild("Kit")
	local veg = kit and kit:FindFirstChild("Vegetation")
	return veg and veg:FindFirstChild(TreeKit.PACK)
end

-- The pack's oaks (any Model whose direct children include a MeshPart), in a
-- stable order: the pack names them all "Model", so sort by stored size.
local function variants(): { Variant }
	if cache then
		return cache
	end
	local out: { Variant } = {}
	local pack = findPack()
	if pack then
		for _, d in pack:GetDescendants() do
			if not d:IsA("Model") or not d:FindFirstChildWhichIsA("MeshPart") then
				continue
			end
			local _, size = d:GetBoundingBox()
			local v: Variant = { template = d, size = size }
			for _, c in d:GetChildren() do
				if c:IsA("MeshPart") then
					if isLeaf(c) then
						if not v.leaf or volume(c.Size) > volume(v.leaf.Size) then
							v.leaf = c
						end
					elseif not v.trunk or c.Size.Y > v.trunk.Size.Y then
						v.trunk = c
					end
				end
			end
			table.insert(out, v)
		end
		table.sort(out, function(a, b)
			if a.size.Y ~= b.size.Y then
				return a.size.Y < b.size.Y
			end
			return a.size.X < b.size.X
		end)
	end
	if #out > 0 then
		cache = out -- a miss is not cached: the kit may load in later
	end
	return out
end

function TreeKit.available(): boolean
	return #variants() > 0
end

local function pick(list: { Variant }, rng: Random): Variant
	return list[rng:NextInteger(1, #list)]
end

local function quiet(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		end
	end
end

-- Moves `model` so `anchor` (a world point on it now) lands on `position`,
-- turned `yaw` about the vertical through it.
local function seat(model: Model, anchor: Vector3, position: Vector3, yaw: number)
	local rel = CFrame.new(anchor):ToObjectSpace(model:GetPivot())
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0) * rel)
end

-- An oak standing at `position` (its trunk on the point, whatever the crown does).
function TreeKit.tree(parent: Instance, position: Vector3, opts: TreeOpts?): Model?
	local o: TreeOpts = opts or {}
	local rng = o.rng or Random.new()
	local all = variants()
	if #all == 0 then
		return nil
	end
	local list = all
	if o.slim then
		list = {}
		for _, v in all do
			if v.size.X <= TreeKit.SLIM_WIDTH then
				table.insert(list, v)
			end
		end
		if #list == 0 then
			list = all
		end
	end
	local v = pick(list, rng)
	local model = v.template:Clone()
	local trunkName = if v.trunk then v.trunk.Name else ""
	quiet(model)
	local scale = if o.height then o.height / math.max(v.size.Y, 0.01) else 1
	if math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(scale)
	end
	local cf, size = model:GetBoundingBox()
	local trunk = model:FindFirstChild(trunkName)
	local foot = if trunk and trunk:IsA("BasePart") then trunk.Position else cf.Position
	local anchor = Vector3.new(foot.X, cf.Position.Y - size.Y / 2 + SINK * math.min(scale, 1), foot.Z)
	seat(model, anchor, position, rng:NextNumber(0, math.pi * 2))
	-- TownMotion sways a tree model's parts named Canopy
	for _, c in model:GetChildren() do
		if c:IsA("MeshPart") and isLeaf(c) then
			c.Name = "Canopy"
		end
	end
	model.Name = o.name or "Tree"
	model:SetAttribute("Kit", TreeKit.PACK)
	if o.collide ~= false then
		local h = size.Y * 0.4
		local post = Instance.new("Part")
		post.Name = "TrunkCollider"
		post.Anchored = true
		post.Transparency = 1
		post.CanTouch = false
		post.CastShadow = false
		post.Size = Vector3.new(math.max(1, 1.8 * scale), h, math.max(1, 1.8 * scale))
		post.CFrame = CFrame.new(position + Vector3.new(0, h / 2, 0))
		post.Parent = model
	end
	model.Parent = parent
	return model
end

-- A leafy bush about `width` across, sat on `position`.
function TreeKit.bush(parent: Instance, position: Vector3, opts: BushOpts?): Model?
	local o: BushOpts = opts or {}
	local rng = o.rng or Random.new()
	-- Only the spreading oaks' crowns: scaled down they are dense and low. The
	-- upright oaks' clumps are mostly twigs and read as litter, not as a bush.
	local withLeaf: { Variant } = {}
	local all = variants()
	for _, v in all do
		if v.leaf and v.size.X > TreeKit.SLIM_WIDTH then
			table.insert(withLeaf, v)
		end
	end
	if #withLeaf == 0 then
		for _, v in all do
			if v.leaf then
				table.insert(withLeaf, v)
			end
		end
	end
	if #withLeaf == 0 then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = o.name or "Bush"
	local width = o.width or 5
	-- Two crowns crossed, the second a little smaller, each stretched BUSH_TALL
	-- upward: one crown alone scaled down is a flat mat of scrub. A crown is
	-- hollow underneath (the branches went there), so its bottom is buried.
	for k = 1, 2 do
		local leaf = (pick(withLeaf, rng).leaf :: MeshPart):Clone()
		local s = width * (if k == 1 then 1 else 0.8) / math.max(leaf.Size.X, leaf.Size.Z, 0.01)
		leaf.Size = Vector3.new(leaf.Size.X * s, leaf.Size.Y * s * BUSH_TALL, leaf.Size.Z * s)
		leaf.CFrame = CFrame.new(position + Vector3.new(0, leaf.Size.Y * (0.5 - BUSH_BURY), 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		leaf.Name = "Leaves"
		leaf.CastShadow = k == 1
		leaf.Parent = model
		if k == 1 then
			model.PrimaryPart = leaf
		end
	end
	quiet(model)
	model:SetAttribute("Kit", TreeKit.PACK)
	model.Parent = parent
	return model
end

-- The slice's garden hedge (Kit.Vegetation.HedgeLong: alpha-card leaves over a
-- dark core, 4.2 thick, 10.6 high, 18.8 long as stored), laid end to end from
-- `from` to `to` on the ground. Sections are stretched to fill the run exactly
-- and cut down to `height`; one invisible box makes the whole run solid.
TreeKit.HEDGE = "HedgeLong"
local HEDGE_SECTION = 17 -- target length of one section

export type HedgeOpts = {
	height: number?, -- default 5.5
	thickness: number?, -- default 3.2
	name: string?,
}

local function findHedge(): Model?
	if libraryOverride then
		local h = libraryOverride:FindFirstChild(TreeKit.HEDGE)
		return if h and h:IsA("Model") then h else nil
	end
	local kit = ServerStorage:FindFirstChild("Kit")
	local veg = kit and kit:FindFirstChild("Vegetation")
	local h = veg and veg:FindFirstChild(TreeKit.HEDGE)
	return if h and h:IsA("Model") and h:FindFirstChildWhichIsA("MeshPart", true) then h else nil
end

function TreeKit.hedgeRun(parent: Instance, from: Vector3, to: Vector3, opts: HedgeOpts?): Model?
	local o: HedgeOpts = opts or {}
	local template = findHedge()
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if not template or length < 1 then
		return nil
	end
	local height, thickness = o.height or 5.5, o.thickness or 3.2
	local boxCf, boxSize = template:GetBoundingBox()
	-- the stored hedge runs along whichever horizontal axis is longer
	local alongZ = boxSize.Z >= boxSize.X
	local storedLen = if alongZ then boxSize.Z else boxSize.X
	local storedThick = if alongZ then boxSize.X else boxSize.Z
	local count = math.max(1, math.floor(length / HEDGE_SECTION + 0.5))
	local sectionLen = length / count
	local kLen, kThick, kY = sectionLen / storedLen, thickness / storedThick, height / boxSize.Y
	local k = if alongZ then Vector3.new(kThick, kY, kLen) else Vector3.new(kLen, kY, kThick)
	-- a frame on the run's start whose -Z looks along it; a stored-along-X hedge is turned onto it
	local dir = flat.Unit
	local runCf = CFrame.lookAt(from, from + dir) * (if alongZ then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0))
	local along = if alongZ then Vector3.new(0, 0, -1) else Vector3.new(1, 0, 0) -- the turned frame's +X is the run

	local model = Instance.new("Model")
	model.Name = o.name or "Hedge"
	for i = 1, count do
		local centre = runCf * CFrame.new(along * (i - 0.5) * sectionLen + Vector3.new(0, height / 2, 0))
		for _, d in template:GetDescendants() do
			if d:IsA("MeshPart") then
				local part = d:Clone()
				local rel = boxCf:ToObjectSpace(d.CFrame)
				part.Size = d.Size * k
				part.CFrame = centre * (rel.Rotation + rel.Position * k)
				part.Name = "HedgeLeaves"
				part.Parent = model
			end
		end
	end
	quiet(model)
	local solid = Instance.new("Part")
	solid.Name = "HedgeCollider"
	solid.Anchored = true
	solid.Transparency = 1
	solid.CanTouch = false
	solid.CanQuery = false
	solid.CastShadow = false
	solid.Size = Vector3.new(thickness * 0.6, height * 0.8, length)
	solid.CFrame = CFrame.lookAt(from, from + dir) * CFrame.new(0, height * 0.4, -length / 2)
	solid.Parent = model
	model.PrimaryPart = solid
	model:SetAttribute("Kit", TreeKit.HEDGE)
	model.Parent = parent
	return model
end

return TreeKit
