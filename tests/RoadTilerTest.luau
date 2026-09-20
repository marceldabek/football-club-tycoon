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
			-- TOWN_V3_BUILD.md s9 rule 1 (Lane P): districts are grouping models, never Atomic
			assert(model and model.ModelStreamingMode == Enum.ModelStreamingMode.Default, "district model must not be Atomic")
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

-- The verge is found by shape because ColorMap cannot be read in a running server;
-- here (Edit mode) it can, so check the rule against the real grass texture.
function tests.vergeOfFindsTheGrassLayerOfEveryKitRoadPiece()
	if not kitInstalled() then
		return
	end
	local GRASS = "rbxassetid://135371299103691"
	local meshes = (ServerStorage :: any).Kit.Meshes
	local checked = 0
	for _, piece in meshes:GetChildren() do
		if piece.Name:sub(1, #RoadTiles.PREFIX) == RoadTiles.PREFIX then
			local verge = RoadTiler.vergeOf(piece)
			assert(verge, piece.Name .. ": no verge found")
			local sa = (verge :: MeshPart):FindFirstChildOfClass("SurfaceAppearance")
			assert(sa and sa.ColorMap == GRASS, piece.Name .. ": vergeOf picked " .. (verge :: MeshPart).Name .. ", not the grass layer")
			checked += 1
		end
	end
	assert(checked >= 40, "expected the 44 ModularRoads pieces, saw " .. checked)
end

function tests.builtTilesCarryTheVergeTint()
	if not kitInstalled() then
		return
	end
	withBuild("Northfields", function(holder, _counts)
		local tinted, tiles = 0, 0
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("TileKind") ~= nil then
				tiles += 1
				local verge = RoadTiler.vergeOf(d)
				local sa = verge and verge:FindFirstChildOfClass("SurfaceAppearance")
				if sa and sa.Color == RoadTiler.VERGE_TINT then
					tinted += 1
				end
			end
		end
		assert(tiles > 0 and tinted == tiles, ("%d of %d tiles tinted"):format(tinted, tiles))
	end)
end

-- Lane I stage 3: inside the centre box the verge is a paving stand-in (E4), and
-- nowhere else.
function tests.centreTilesGetAPavedVerge()
	if not kitInstalled() then
		return
	end
	withBuild("Town Centre", function(holder, _counts)
		local paved, grass = 0, 0
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("TileKind") ~= nil then
				local verge = RoadTiler.vergeOf(d) :: MeshPart
				assert(verge, "no verge on " .. d.Name)
				local sa = verge:FindFirstChildOfClass("SurfaceAppearance")
				local at = d:GetPivot().Position
				local c = RoadTiles.CENTRE
				local deepInside = at.X > c.minX + 60 and at.X < c.maxX - 60 and at.Z > c.minZ + 60 and at.Z < c.maxZ - 60
				local wellOutside = at.X < c.minX - 60 or at.X > c.maxX + 60 or at.Z < c.minZ - 60 or at.Z > c.maxZ + 60
				assert(not (deepInside and d:GetAttribute("PavedVerge") ~= true), "centre tile not paved: " .. tostring(d:GetAttribute("Road")))
				assert(not (wellOutside and d:GetAttribute("PavedVerge") == true), "paved tile outside the centre: " .. tostring(d:GetAttribute("Road")))
				if d:GetAttribute("PavedVerge") == true then
					assert(sa == nil and verge.Material == RoadTiler.PAVED_VERGE.material, "paved verge keeps no grass texture")
					assert(verge:GetAttribute("V3Exempt") == "E4", "paved verge is registered as E4")
					paved += 1
				else
					assert(sa and sa.Color == RoadTiler.VERGE_TINT, "grass verge outside the centre is tinted")
					grass += 1
				end
			end
		end
		assert(paved > 0, "the Town Centre has paved verges")
	end)
end

return tests
