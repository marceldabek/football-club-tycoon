--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local TreeKit = require(ServerScriptService.Server.TreeKit)

local T = {}

-- A stand-in oak pack: two "oaks" of a trunk MeshPart (opaque overlay) and a
-- leaf MeshPart (alpha cards), stored well away from the origin like the real one.
local function oak(parent: Instance, at: Vector3, width: number, height: number)
	local m = Instance.new("Model")
	m.Name = "Model"
	local trunk = Instance.new("MeshPart")
	trunk.Name = "Trunk01"
	trunk.Size = Vector3.new(2, height * 0.7, 2)
	trunk.Position = at + Vector3.new(0, height * 0.35, 0)
	local bark = Instance.new("SurfaceAppearance")
	bark.AlphaMode = Enum.AlphaMode.Overlay
	bark.Parent = trunk
	trunk.Parent = m
	local leaf = Instance.new("MeshPart")
	leaf.Name = "Leaves01"
	leaf.Size = Vector3.new(width, height * 0.6, width)
	-- crown off-centre, as the real oaks' are
	leaf.Position = at + Vector3.new(width * 0.2, height * 0.7, 0)
	local cards = Instance.new("SurfaceAppearance")
	cards.AlphaMode = Enum.AlphaMode.Transparency
	cards.Parent = leaf
	leaf.Parent = m
	m.Parent = parent
end

local function withPack(fn: (parent: Folder) -> ())
	local pack = Instance.new("Folder")
	oak(pack, Vector3.new(100, 50, -40), 12, 30)
	oak(pack, Vector3.new(160, 50, -40), 50, 40)
	local parent = Instance.new("Folder")
	TreeKit.setLibraryRoot(pack)
	local ok, err = pcall(fn, parent)
	TreeKit.setLibraryRoot(nil)
	pack:Destroy()
	parent:Destroy()
	assert(ok, err)
end

function T.missingPackReturnsNilSoCallersFallBack()
	local empty = Instance.new("Folder")
	TreeKit.setLibraryRoot(empty)
	local parent = Instance.new("Folder")
	local tree = TreeKit.tree(parent, Vector3.zero)
	local bush = TreeKit.bush(parent, Vector3.zero)
	local available = TreeKit.available()
	TreeKit.setLibraryRoot(nil)
	assert(tree == nil and bush == nil and not available, "no pack, nothing placed")
	assert(#parent:GetChildren() == 0, "nothing parented")
end

function T.treeStandsItsTrunkOnThePointAtTheAskedHeight()
	withPack(function(parent)
		local at = Vector3.new(-300, 0.5, 220)
		for seed = 1, 6 do
			local tree = TreeKit.tree(parent, at, { height = 20, rng = Random.new(seed) })
			assert(tree, "placed")
			local _, size = (tree :: Model):GetBoundingBox()
			assert(math.abs(size.Y - 20) < 0.5, "height " .. size.Y)
			local trunk = (tree :: Model):FindFirstChild("Trunk01") :: BasePart
			assert(math.abs(trunk.Position.X - at.X) < 0.01 and math.abs(trunk.Position.Z - at.Z) < 0.01, "trunk on the point")
			local foot = trunk.Position.Y - trunk.Size.Y / 2
			assert(foot <= at.Y and foot > at.Y - 0.5, "rooted just under the ground: " .. foot)
			local post = (tree :: Model):FindFirstChild("TrunkCollider") :: BasePart
			assert(post and post.CanCollide and post.Transparency == 1, "invisible collider")
			for _, d in (tree :: Model):GetDescendants() do
				if d:IsA("MeshPart") then
					assert(d.Anchored and not d.CanCollide, d.Name .. " anchored, not solid")
				end
			end
			assert((tree :: Model):FindFirstChild("Canopy"), "leaves renamed for TownMotion's sway")
		end
	end)
end

function T.slimOnlyPicksTheUprightOaks()
	withPack(function(parent)
		for seed = 1, 12 do
			local tree = TreeKit.tree(parent, Vector3.zero, { slim = true, collide = false, rng = Random.new(seed) }) :: Model
			local _, size = tree:GetBoundingBox()
			assert(math.max(size.X, size.Z) <= TreeKit.SLIM_WIDTH, "slim oak is " .. size.X .. " wide")
			assert(tree:FindFirstChild("TrunkCollider") == nil, "collide = false adds no post")
		end
	end)
end

function T.bushIsTwoCrossedCrownsOfTheAskedWidthSatInTheGround()
	withPack(function(parent)
		local at = Vector3.new(40, 1, -90)
		local bush = TreeKit.bush(parent, at, { width = 5, rng = Random.new(3) }) :: Model
		assert(bush, "placed")
		local parts = bush:GetChildren()
		assert(#parts == 2, "two crowns, got " .. #parts)
		local widest = 0
		for _, p in parts do
			assert(p:IsA("MeshPart"), "leaf mesh")
			local leaf = p :: MeshPart
			widest = math.max(widest, leaf.Size.X, leaf.Size.Z)
			assert(not leaf.CanCollide and leaf.Anchored, "anchored, walk-through")
			local bottom, top = leaf.Position.Y - leaf.Size.Y / 2, leaf.Position.Y + leaf.Size.Y / 2
			assert(bottom < at.Y and top > at.Y + 1, ("underside buried, top showing: %g..%g"):format(bottom, top))
			assert(math.abs(leaf.Position.X - at.X) < 0.01 and math.abs(leaf.Position.Z - at.Z) < 0.01, "centred on the point")
		end
		assert(math.abs(widest - 5) < 0.05, "width " .. widest)
	end)
end

return T
