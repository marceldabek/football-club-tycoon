--!strict
-- Rivermere v3, Lane P: shared measurement helpers. See docs/TOWN_V3_PERF.md.
--
-- Every builder lane reports the SAME numbers in its `[FCT]` line:
--
--   local counts = V3Perf.count(districtModelOrFolder)
--   print("[FCT] Housing: " .. V3Perf.format(counts))
--   assert(V3Perf.withinBudget(counts, M.PART_BUDGET))
--
-- The budgets in docs/TOWN_V3_BUILD.md section 9 are counted in `meshParts`.
-- Triangles are opt-in (`{ triangles = true }`): they need EditableMesh, which
-- works from the Studio command bar / MCP in Edit mode but not reliably in a
-- running server, so tests and runtime code must not depend on them.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local V3Perf = {}

export type Counts = {
	instances: number, -- every descendant
	meshParts: number, -- the budgeted number
	parts: number, -- non-mesh BaseParts (primitives; should be ~0 outside V3Exempt)
	models: number,
	uniqueMeshIds: number, -- distinct geometry; drives memory and draw batching
	surfaceAppearances: number,
	uniqueTextures: number, -- distinct ColorMap / TextureID; drives texture memory
	shadowCasters: number, -- MeshParts with CastShadow on
	preciseCollision: number, -- MeshParts NOT on Box/Hull collision
	kitMissing: number, -- tagged KitMissing; must be 0 for a finished lane
	triangles: number, -- -1 unless opts.triangles and EditableMesh worked
	trianglesUnique: number, -- sum over distinct MeshIds (what memory pays for); -1 likewise
}

export type CountOpts = { triangles: boolean? }

-- MeshId -> face count; -1 when the lookup failed. Shared across calls so a
-- whole-town count only pays for each distinct mesh once.
local triCache: { [string]: number } = {}

local function trianglesFor(meshId: string): number
	local cached = triCache[meshId]
	if cached ~= nil then
		return cached
	end
	local ok, n = pcall(function()
		local em = (AssetService :: any):CreateEditableMeshAsync((Content :: any).fromUri(meshId))
		local faces = #em:GetFaces()
		em:Destroy()
		return faces
	end)
	local result = if ok and type(n) == "number" then n else -1
	triCache[meshId] = result
	return result
end

function V3Perf.count(root: Instance, opts: CountOpts?): Counts
	local wantTris = opts ~= nil and opts.triangles == true
	local c: Counts = {
		instances = 0,
		meshParts = 0,
		parts = 0,
		models = 0,
		uniqueMeshIds = 0,
		surfaceAppearances = 0,
		uniqueTextures = 0,
		shadowCasters = 0,
		preciseCollision = 0,
		kitMissing = 0,
		triangles = if wantTris then 0 else -1,
		trianglesUnique = if wantTris then 0 else -1,
	}
	local meshIds: { [string]: boolean } = {}
	local textures: { [string]: boolean } = {}
	local function noteTexture(id: string)
		if id ~= "" and not textures[id] then
			textures[id] = true
			c.uniqueTextures += 1
		end
	end
	for _, d in root:GetDescendants() do
		c.instances += 1
		if CollectionService:HasTag(d, "KitMissing") then
			c.kitMissing += 1
		end
		if d:IsA("MeshPart") then
			c.meshParts += 1
			if d.CastShadow then
				c.shadowCasters += 1
			end
			local cf = d.CollisionFidelity
			if cf ~= Enum.CollisionFidelity.Box and cf ~= Enum.CollisionFidelity.Hull then
				c.preciseCollision += 1
			end
			noteTexture(d.TextureID)
			local id = d.MeshId
			local first = not meshIds[id]
			if first then
				meshIds[id] = true
				c.uniqueMeshIds += 1
			end
			if wantTris then
				local t = trianglesFor(id)
				if t >= 0 then
					c.triangles += t
					if first then
						c.trianglesUnique += t
					end
				end
			end
		elseif d:IsA("BasePart") then
			c.parts += 1
		elseif d:IsA("Model") then
			c.models += 1
		elseif d:IsA("SurfaceAppearance") then
			c.surfaceAppearances += 1
			noteTexture(d.ColorMap)
		end
	end
	return c
end

-- One stable string for `[FCT]` lines so Lane P can grep and compare them.
function V3Perf.format(c: Counts): string
	local s = ("meshParts=%d uniqueMeshIds=%d instances=%d parts=%d textures=%d shadows=%d preciseCollision=%d kitMissing=%d"):format(
		c.meshParts,
		c.uniqueMeshIds,
		c.instances,
		c.parts,
		c.uniqueTextures,
		c.shadowCasters,
		c.preciseCollision,
		c.kitMissing
	)
	if c.triangles >= 0 then
		s ..= (" triangles=%d"):format(c.triangles)
	end
	return s
end

function V3Perf.withinBudget(c: Counts, meshPartBudget: number): boolean
	return c.meshParts <= meshPartBudget
end

-- Section 9 defaults applied to one placed kit model. Call right after
-- KitPlacer.place. `kind`:
--   "structure" -- houses, shops, walls a player can walk into: keeps its collision
--                  fidelity and shadows.
--   "road"      -- road tiles: Box collision (flat slab), no shadow (they lie on the ground).
--   "prop"      -- street furniture, fences, bins, signs: Box collision, no shadow
--                  unless its bounding box is taller than TALL_PROP studs (lamp posts, poles).
--   "decor"     -- small clutter nobody should trip over: no collision, no query, no shadow.
V3Perf.TALL_PROP = 12

function V3Perf.applyDefaults(model: Instance, kind: "structure" | "road" | "prop" | "decor")
	local list = model:GetDescendants()
	if model:IsA("BasePart") then
		table.insert(list, model)
	end
	for _, d in list do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			if kind == "road" then
				d.CastShadow = false
			elseif kind == "prop" then
				d.CastShadow = d.Size.Y > V3Perf.TALL_PROP
			elseif kind == "decor" then
				d.CastShadow = false
				d.CanCollide = false
				d.CanQuery = false
			end
			if d:IsA("MeshPart") and kind ~= "structure" then
				-- CollisionFidelity is plugin/command-bar writable only; in a running
				-- server this throws, so runtime builds rely on the template already
				-- being Box (see TOWN_V3_PERF.md "Bake the templates").
				pcall(function()
					(d :: any).CollisionFidelity = Enum.CollisionFidelity.Box
				end)
			end
		end
	end
end

return V3Perf
