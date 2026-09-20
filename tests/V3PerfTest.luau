--!strict
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local V3Perf = require(ServerScriptService.Server.V3Perf)

local T = {}

local function meshPart(parent: Instance, shadow: boolean): MeshPart
	-- An empty MeshPart is enough: count() only reads properties.
	local mp = Instance.new("MeshPart")
	mp.Anchored = true
	mp.CastShadow = shadow
	mp.Parent = parent
	return mp
end

local function fixture(): Model
	local root = Instance.new("Model")
	local a = Instance.new("Model")
	a.Parent = root
	meshPart(a, true)
	meshPart(a, false)
	local sa = Instance.new("SurfaceAppearance")
	sa.Parent = a:FindFirstChildWhichIsA("MeshPart") :: Instance
	local p = Instance.new("Part")
	p.Anchored = true
	p.Parent = root
	CollectionService:AddTag(p, "KitMissing")
	return root
end

function T.countsEveryCategory()
	local root = fixture()
	local c = V3Perf.count(root)
	root:Destroy()
	assert(c.instances == 5, "instances " .. c.instances)
	assert(c.meshParts == 2, "meshParts " .. c.meshParts)
	assert(c.parts == 1, "parts " .. c.parts)
	assert(c.models == 1, "models " .. c.models)
	assert(c.surfaceAppearances == 1, "surfaceAppearances " .. c.surfaceAppearances)
	assert(c.shadowCasters == 1, "shadowCasters " .. c.shadowCasters)
	assert(c.kitMissing == 1, "kitMissing " .. c.kitMissing)
	-- Both MeshParts share the (empty) MeshId, so they are one unique mesh.
	assert(c.uniqueMeshIds == 1, "uniqueMeshIds " .. c.uniqueMeshIds)
end

function T.trianglesAreOptIn()
	local root = fixture()
	local c = V3Perf.count(root)
	root:Destroy()
	assert(c.triangles == -1 and c.trianglesUnique == -1, "triangles must be -1 unless asked for")
end

function T.emptyModelIsAllZero()
	local root = Instance.new("Model")
	local c = V3Perf.count(root)
	root:Destroy()
	assert(c.instances == 0 and c.meshParts == 0 and c.uniqueMeshIds == 0 and c.kitMissing == 0)
end

function T.budgetCheckIsInclusive()
	local root = fixture()
	local c = V3Perf.count(root)
	root:Destroy()
	assert(V3Perf.withinBudget(c, 2))
	assert(not V3Perf.withinBudget(c, 1))
end

function T.formatCarriesTheBudgetedNumbers()
	local root = fixture()
	local s = V3Perf.format(V3Perf.count(root))
	root:Destroy()
	assert(s:find("meshParts=2", 1, true), s)
	assert(s:find("uniqueMeshIds=1", 1, true), s)
	assert(s:find("kitMissing=1", 1, true), s)
	assert(not s:find("triangles=", 1, true), "no triangles field unless measured: " .. s)
end

function T.propDefaultsDropShadowsOnShortProps()
	local root = Instance.new("Model")
	local short = meshPart(root, true)
	short.Size = Vector3.new(2, 3, 2)
	local tall = meshPart(root, true)
	tall.Size = Vector3.new(1, 25, 1)
	V3Perf.applyDefaults(root, "prop")
	local shortShadow, tallShadow, touch = short.CastShadow, tall.CastShadow, short.CanTouch
	root:Destroy()
	assert(shortShadow == false, "short prop must not cast a shadow")
	assert(tallShadow == true, "tall prop keeps its shadow")
	assert(touch == false, "CanTouch off")
end

function T.decorDefaultsDropCollision()
	local root = Instance.new("Model")
	local mp = meshPart(root, true)
	V3Perf.applyDefaults(root, "decor")
	local collide, query, shadow = mp.CanCollide, mp.CanQuery, mp.CastShadow
	root:Destroy()
	assert(not collide and not query and not shadow)
end

function T.structureDefaultsKeepShadowAndCollision()
	local root = Instance.new("Model")
	local mp = meshPart(root, true)
	V3Perf.applyDefaults(root, "structure")
	local collide, shadow = mp.CanCollide, mp.CastShadow
	root:Destroy()
	assert(collide and shadow)
end

function T.bakeRejectsUnknownKind()
	local root = Instance.new("Model")
	local ok = pcall(V3Perf.bake, root, "nonsense")
	root:Destroy()
	assert(not ok, "unknown kind must error rather than silently bake nothing")
end

function T.everyKindHasBoxOrHullCollision()
	for kind, f in V3Perf.FIDELITY :: any do
		local c = f.collision
		assert(c == Enum.CollisionFidelity.Box or c == Enum.CollisionFidelity.Hull, kind .. " must not use decomposition")
	end
end

return T
