--!strict
-- Rivermere v3, Lane R: assembler test. Builds real districts into a throwaway
-- holder and checks the definition of done: no KitMissing, no untagged
-- primitives, one Model per district, tiles land where the pure plan says.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local RoadTiler = require(ServerScriptService.Server.RoadTiler)

local tests = {}

local function kitInstalled(): boolean
	local kit = ServerStorage:FindFirstChild("Kit")
	local meshes = kit and kit:FindFirstChild("Meshes")
	return meshes ~= nil and meshes:FindFirstChild(RoadTiles.PREFIX .. "Straight") ~= nil
end

local function withBuild(district: string?, check: (Model, { [string]: number }) -> ())
	local holder = Instance.new("Model")
	holder.Name = "RoadTilerTest"
	local ok, err = pcall(function()
		local counts = RoadTiler.build(holder, CFrame.new(0, 0, 0), { district = district })
		check(holder, counts)
	end)
	holder:Destroy()
	assert(ok, err)
end

function tests.everyPieceTheTilerUsesIsInTheKit()
	if not kitInstalled() then
		return
	end
	local meshes = ServerStorage.Kit.Meshes
	for id, def in RoadTiles.PIECES do
		assert(meshes:FindFirstChild(RoadTiles.PREFIX .. def.name), "kit lacks " .. def.name .. " (" .. id .. ")")
		if def.yellow then
			assert(meshes:FindFirstChild(RoadTiles.PREFIX .. def.yellow), "kit lacks " .. def.yellow)
		end
	end
end

function tests.pieceTableMatchesTheKitMeshes()
	if not kitInstalled() then
		return
	end
	-- the height column drives vertical alignment: check it against the real assets
	for _, def in RoadTiles.PIECES do
		local model = ServerStorage.Kit.Meshes[RoadTiles.PREFIX .. def.name] :: Model
		local _, size = model:GetBoundingBox()
		assert(math.abs(size.Y - def.height) < 0.01, ("%s height %.3f, table says %.3f"):format(def.name, size.Y, def.height))
	end
end

function tests.districtBuildHasNoMissingAndNoUntaggedPrimitives()
	if not kitInstalled() then
		return
	end
	-- Arterial has the ring road: roundabout stand-ins, 45 bends, tucks
	for _, district in { "Northfields", RoadTiles.ARTERIAL } do
		withBuild(district, function(holder, counts)
			assert(counts.tiles > 20, "built something: " .. counts.tiles)
			assert(counts.missing == 0, counts.missing .. " KitMissing")
			assert(counts.models == 1, "one Model per district, got " .. counts.models)
			local model = holder:FindFirstChild("Roads_" .. district) :: Model
			assert(model and model.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, "atomic district model")
			for _, d in holder:GetDescendants() do
				assert(d:GetAttribute("KitMissing") == nil, "KitMissing: " .. d.Name)
				if d:IsA("BasePart") and not d:IsA("MeshPart") then
					assert(d:GetAttribute("V3Exempt") == "E3", "untagged primitive " .. d:GetFullName())
				end
				assert(not d:IsA("LuaSourceContainer"), "script in output")
			end
			if district == RoadTiles.ARTERIAL then
				assert(counts.exempt > 0, "ring road has roundabout stand-ins")
			else
				assert(counts.exempt == 0, "no stand-ins in " .. district)
			end
		end)
	end
end

function tests.tilesSitAtThePlannedLevelAndLength()
	if not kitInstalled() then
		return
	end
	withBuild("Northfields", function(holder, _)
		local tileLen = 110 * 0.816
		for _, m in (holder:FindFirstChild("Roads_Northfields") :: Model):GetChildren() do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				local top = cf.Position.Y + size.Y / 2
				-- tucked tiles are pitched, so allow them to dip
				assert(top < RoadTiles.SURFACE_Y + 0.8 and top > RoadTiles.SURFACE_Y - 1, ("%s top at %.2f"):format(m.Name, top))
				if m:GetAttribute("TileKind") == "straight" then
					assert(size.Z > tileLen * 0.05 and size.Z < tileLen * 1.5, ("straight length %.1f"):format(size.Z))
					assert(math.abs(size.X - 44 * 0.816) < 0.2, ("straight width %.2f"):format(size.X))
				end
			end
		end
	end)
end

function tests.originMovesTheWholeBuild()
	if not kitInstalled() then
		return
	end
	local function centreOf(origin: CFrame): Vector3
		local holder = Instance.new("Model")
		RoadTiler.build(holder, origin, { district = "Hollingford" })
		local cf = holder:GetBoundingBox()
		holder:Destroy()
		return cf.Position
	end
	local a = centreOf(CFrame.new(0, 0, 0))
	local b = centreOf(CFrame.new(100, 0, 6000))
	assert((b - a - Vector3.new(100, 0, 6000)).Magnitude < 0.5, "origin offsets the build")
end

return tests
