--!strict
-- #27: the low-detail town stand-ins. Builds small fake lots in a detached
-- folder; nothing goes into workspace.
local ServerScriptService = game:GetService("ServerScriptService")
local TownStandIns = require(ServerScriptService.Server.TownStandIns)

local T = {}

local EPS = 1e-3

local function close(a: number, b: number): boolean
	return math.abs(a - b) <= EPS
end

local function part(name: string, parent: Instance, size: Vector3, cf: CFrame, className: string?): BasePart
	local p = Instance.new(className or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function lot(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

-- A 20-wide terrace: walls to y 20 (gables to 26), roof from 20 to 26, a
-- flat yard and a garden wall out front that must not widen the block.
local function terrace(parent: Instance, at: Vector3): Model
	local m = lot("Lot_Test Row", parent)
	local masonry = part("HOUSE__T01_plain__masonry", m, Vector3.new(20, 26, 10), CFrame.new(at + Vector3.new(0, 13, 0)), "MeshPart")
	local sa = Instance.new("SurfaceAppearance")
	sa.Name = "HouseBrick_ts1" -- the dark sheet
	sa.Parent = masonry
	part("HOUSE__T01_plain__roof", m, Vector3.new(22, 6, 12), CFrame.new(at + Vector3.new(0, 23, 0)))
	part("HOUSE__T01_plain__trim", m, Vector3.new(20, 26, 10.4), CFrame.new(at + Vector3.new(0, 13, 0)))
	part("YardGround", m, Vector3.new(60, 0.3, 40), CFrame.new(at + Vector3.new(0, 0.15, 30)))
	part("MEH__Wall_Low_A__ts1", m, Vector3.new(60, 2.8, 1), CFrame.new(at + Vector3.new(0, 1.4, 20)))
	return m
end

function T.classifyByChildName()
	local cases: { [string]: string? } = {
		["HOUSE__T01_plain__masonry"] = "body",
		["HOUSE__flats_x__masonry"] = "body",
		["HOUSE__T01_plain__roof"] = "roof",
		["HOUSE__T01_plain__trim"] = nil,
		["Core"] = "body",
		["ShopfrontPub"] = "body",
		["MEH__House_02_VAR1__ts3"] = "body",
		["MEH__Office_01_VAR01__ts1"] = "body",
		["MEH__Wall_Garage_A__ts1"] = "body",
		["MEH__Wall_WindowCentre_B__ts1"] = "body",
		["MEH__Wall_Low_A__ts1"] = nil,
		["MEH__Roof_A__ts1"] = "roof",
		["MEH__Roof_Wall_Full_A__ts1"] = "roof",
		["UKSP__CorrugatedFence__CorrugatedFenceA01"] = nil,
		["YardGround"] = nil,
		["FrontApron"] = nil,
		["ForkliftYellow"] = nil,
	}
	for name, want in cases do
		assert(TownStandIns.classify(name) == want, ("%s -> %s, want %s"):format(name, tostring(TownStandIns.classify(name)), tostring(want)))
	end
end

function T.terraceGetsWallsToTheEavesAndARoofSlab()
	local folder = Instance.new("Folder")
	local m = terrace(folder, Vector3.new(100, 0, 50))
	local blocks, key = TownStandIns.blocksFor(m)
	assert(#blocks == 2, "blocks " .. #blocks)
	assert(key == "dark", "palette by the SurfaceAppearance's name, got " .. key)
	local walls, roof = blocks[1], blocks[2]
	assert(walls.role == "body" and roof.role == "roof")
	-- the yard and garden wall don't widen it; the walls stop at the eaves and sink below ground
	local wx = math.min(walls.size.X, walls.size.Z)
	local wl = math.max(walls.size.X, walls.size.Z)
	assert(close(wx, 10) and close(wl, 20), "walls footprint " .. tostring(walls.size))
	local bottom = walls.cframe.Position.Y - walls.size.Y / 2
	local top = walls.cframe.Position.Y + walls.size.Y / 2
	assert(close(bottom, -TownStandIns.SINK), "walls bottom " .. bottom)
	assert(close(top, 20), "walls top " .. top)
	local rb = roof.cframe.Position.Y - roof.size.Y / 2
	local rt = roof.cframe.Position.Y + roof.size.Y / 2
	assert(close(rb, 20) and close(rt, 20 + 6 * TownStandIns.ROOF_FILL), ("roof %.2f..%.2f"):format(rb, rt))
	assert(close(math.max(roof.size.X, roof.size.Z), 22), "roof keeps the overhang " .. tostring(roof.size))
	assert(close(walls.cframe.Position.X, 100) and close(walls.cframe.Position.Z, 50), "centred " .. tostring(walls.cframe.Position))
	folder:Destroy()
end

function T.rotatedPrefabKeepsItsFootprint()
	local folder = Instance.new("Folder")
	local m = lot("Lot_Prefab", folder)
	-- a one-mesh house turned 30 degrees and tipped about X like the kit's imports
	local cf = CFrame.new(0, 12.5, 0) * CFrame.Angles(0, math.rad(30), 0) * CFrame.Angles(math.rad(-90), 0, 0)
	part("MEH__House_02_VAR1__ts3", m, Vector3.new(20, 31, 25), cf)
	local blocks = TownStandIns.blocksFor(m)
	assert(#blocks == 2, "blocks " .. #blocks)
	local walls = blocks[1]
	-- footprint 20 x 31 (the tipped part's Y is horizontal), not an axis-aligned blow-up
	local a, b = math.min(walls.size.X, walls.size.Z), math.max(walls.size.X, walls.size.Z)
	assert(close(a, 20) and close(b, 31), "footprint " .. tostring(walls.size))
	local top = walls.cframe.Position.Y + walls.size.Y / 2
	assert(close(top, 25 * TownStandIns.PREFAB_EAVES), "prefab eaves " .. top)
	assert(math.abs(walls.cframe.UpVector.Y - 1) < EPS, "stand-ins stay upright")
	folder:Destroy()
end

function T.industrialUnitIgnoresItsYardFence()
	local folder = Instance.new("Folder")
	local m = lot("Estate Road|left|1|1", folder)
	local wall = Instance.new("Model")
	wall.Name = "MEH__Wall_Garage_A__ts1"
	wall.Parent = m
	part("Plane.010", wall, Vector3.new(30, 12, 20), CFrame.new(0, 6, 0))
	local fence = Instance.new("Model")
	fence.Name = "UKSP__CorrugatedFence__CorrugatedFenceA01"
	fence.Parent = m
	part("Fence", fence, Vector3.new(60, 6, 1), CFrame.new(0, 3, 40))
	local blocks, key = TownStandIns.blocksFor(m)
	assert(key == "shed", "palette " .. key)
	assert(#blocks >= 1 and close(math.max(blocks[1].size.X, blocks[1].size.Z), 30), "fence widened it " .. tostring(blocks[1] and blocks[1].size))
	folder:Destroy()
end

function T.buildIsPersistentAndPairsIdsWithLots()
	local town = Instance.new("Folder")
	local district = Instance.new("Model")
	district.Name = "Housing_Test"
	district.Parent = town
	local a = terrace(district, Vector3.new(0, 0, 0))
	local b = terrace(district, Vector3.new(200, 0, 0))
	local front = lot("High Street|left|1|1|Front", district)
	part("FrontApron", front, Vector3.new(20, 0.3, 6), CFrame.new(0, 0.15, 20))
	local model, summary = TownStandIns.build(town)
	assert(model.Parent == town and model.Name == TownStandIns.MODEL_NAME)
	assert(model.ModelStreamingMode == Enum.ModelStreamingMode.Persistent, "stand-ins must always be loaded")
	assert(front:GetAttribute(TownStandIns.ATTRIBUTE) == nil, "no building, no stand-in")
	local ida, idb = a:GetAttribute(TownStandIns.ATTRIBUTE), b:GetAttribute(TownStandIns.ATTRIBUTE)
	assert(type(ida) == "number" and type(idb) == "number" and ida ~= idb, "ids")
	local byId: { [number]: number } = {}
	for _, p in model:GetChildren() do
		assert(p:IsA("Part"), p.ClassName)
		local bp = p :: Part
		assert(not bp.CanCollide and not bp.CanQuery and not bp.CanTouch and not bp.CastShadow and bp.Anchored, "cheap flags on " .. bp.Name)
		local id = bp:GetAttribute(TownStandIns.ATTRIBUTE) :: number
		byId[id] = (byId[id] or 0) + 1
	end
	assert(byId[ida] == 2 and byId[idb] == 2 and #model:GetChildren() == 4, "two blocks per building")
	assert(string.find(summary, "2 buildings of 3 lots, 4 parts", 1, true), summary)
	-- a rebuild replaces rather than stacks, and never counts its own model
	local again = TownStandIns.build(town)
	assert(#again:GetChildren() == 4 and #town:GetChildren() == 2, "rebuild stacked")
	town:Destroy()
end

-- Lane I (2026-09-23): Model.LevelOfDetail is Plugin-capability. A write from a
-- game script throws and took the whole town build down, while RunAll (on the
-- elevated MCP thread) stayed green. Keep it out of shipped code.
function T.noGameScriptWritesLevelOfDetail()
	local roots = { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst"), game:GetService("StarterPlayer") }
	for _, root in roots do
		for _, s in root:GetDescendants() do
			if s:IsA("LuaSourceContainer") then
				local src = (s :: any).Source :: string
				assert(not string.find(src, "LevelOfDetail%s*=[^=]"), s:GetFullName() .. " writes Model.LevelOfDetail (Plugin-only; see TownStandIns.luau)")
			end
		end
	end
end

return T
