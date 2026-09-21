--!strict
-- Greenery all over a claimed plot (Marcel, 2026-09-21: "take the trees from the
-- vertical slice, oaks shrubs rocks, all greenery, and add it everywhere": the
-- entrance road, near the club building, round the practice pitches and the
-- dead open space). The slice's greenery is the oak pack and the garden hedge,
-- both through TreeKit; bushes are cut from the oaks' crowns there. The slice has
-- no rocks, so those are the for-sale lot's slate boulders.
--
-- Two layers, both pitch-local (north -Z, entrance -X, plot 760 square):
--   planted    hand-set lines: an oak and a low hedge each side of the access
--              road, a hedge round the car park, bushes against the clubhouse
--              and oaks on its lawn, oak rows and a hedge round the training fence
--   scattered  seeded groves (2-3 oaks, bushes, maybe a boulder) dropped into
--              whatever is left, by rejection against PlotGrounds' keep-out
--
-- `plan` is pure, so the test can check every spot without a kit or a world.
-- Nothing here is per-club state; the seed only varies the scatter per plot.

local TreeKit = require(script.Parent.TreeKit)

local GroundsPlanting = {}

export type Rect = { name: string, min: Vector2, max: Vector2, solid: boolean? }
export type TreeSpot = { at: Vector3, height: number, slim: boolean }
export type BushSpot = { at: Vector3, width: number }
export type RockSpot = { at: Vector3, size: number }
export type HedgeRun = { from: Vector3, to: Vector3, height: number }
-- `foundation` bushes stand against the clubhouse wall, inside the stadium keep-out on purpose
export type Plan = { trees: { TreeSpot }, bushes: { BushSpot }, foundation: { BushSpot }, rocks: { RockSpot }, hedges: { HedgeRun } }

local HALF = 380
local WALL_CLEAR = 14 -- a scattered trunk stays this far inside the boundary wall
-- how far a scattered thing keeps from a keep-out: `solid` is a building, the
-- stadium, a fence or the car park; the rest are paths, the road and flower beds
GroundsPlanting.CLEAR = {
	tree = { solid = 14, flat = 6 },
	small = { solid = 5, flat = 3 }, -- bushes and rocks
}
GroundsPlanting.FOUNDATION_X = -160 -- 3 off the clubhouse's front wall (x -157)
local GROVES = 14 -- TEMP: ~35 scattered oaks a plot on top of 22 planted; phone cost unmeasured
local GROVE_SPACING = 52
local TREE_SPACING = 17

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

-- Distance from a point to a rectangle (0 inside it).
function GroundsPlanting.distance(p: Vector3, r: Rect): number
	local dx = math.max(r.min.X - p.X, 0, p.X - r.max.X)
	local dz = math.max(r.min.Y - p.Z, 0, p.Z - r.max.Y)
	return math.sqrt(dx * dx + dz * dz)
end

local function clearOf(p: Vector3, keepOut: { Rect }, kind: { solid: number, flat: number }): boolean
	for _, r in keepOut do
		if GroundsPlanting.distance(p, r) < (if r.solid then kind.solid else kind.flat) then
			return false
		end
	end
	return true
end

-- ------------------------------------------------------------------- planted

local function planted(plan: Plan)
	local function tree(x: number, z: number, height: number, slim: boolean)
		table.insert(plan.trees, { at = v(x, z), height = height, slim = slim })
	end
	local function bush(x: number, z: number, width: number)
		table.insert(plan.bushes, { at = v(x, z), width = width })
	end
	local function rock(x: number, z: number, size: number)
		table.insert(plan.rocks, { at = v(x, z), size = size })
	end
	local function hedge(x0: number, z0: number, x1: number, z1: number, height: number)
		table.insert(plan.hedges, { from = v(x0, z0), to = v(x1, z1), height = height })
	end

	-- entrance road (x -381..-349, z 80, paving out to z 67.7 / 92.3): a low hedge
	-- along each pavement and an oak behind it. The south side stops short of the
	-- MATCHDAY PARKING board (x -355, z 96..110), and its oak stands past it.
	hedge(-374, 64.5, -352, 64.5, 3.4)
	hedge(-374, 95.5, -360, 95.5, 3.4)
	tree(-366, 56, 23, true)
	tree(-368, 116, 24, true)
	bush(-356, 58, 4.5)
	bush(-372, 106, 4)

	-- car park (x -350..-250, z 40..190): hedged round outside the kerb. Gaps: the
	-- road mouth and the sign on the west, the office path at the north-east
	-- corner (z 40..46), and one to walk through in the south side.
	hedge(-353.5, 36.5, -250, 36.5, 4.5) -- north
	hedge(-353.5, 40, -353.5, 61, 4.5) -- west, north of the road
	hedge(-353.5, 114, -353.5, 193.5, 4.5) -- west, south of the sign
	hedge(-350, 193.5, -306, 193.5, 4.5) -- south, with a gap
	hedge(-294, 193.5, -246.5, 193.5, 4.5)
	hedge(-246.5, 50, -246.5, 190, 4.5) -- east, from the office path down

	-- club building (x -157..-121, z -40..40; front doors' apron z -16..16, side
	-- door apron z 40..46): bushes against the front wall either side of the doors,
	-- two oaks framing the walk up to them and two big ones on the lawn beyond
	for _, z in { -35, -29.5, -24, 24, 29.5, 35 } do
		table.insert(plan.foundation, { at = v(GroundsPlanting.FOUNDATION_X, z), width = 4.2 })
	end
	tree(-200, -34, 24, true)
	tree(-200, 14, 24, true)
	tree(-226, -62, 34, false)
	tree(-222, 78, 36, false)
	bush(-214, -58, 5.5)
	bush(-232, -50, 5)
	bush(-212, 86, 5.5)
	bush(-228, 92, 4.5)
	rock(-236, 70, 4.5)
	rock(-208, -74, 3.5)

	-- training pitches (fence x 222..338, z -178..178, gate on the west at z -6..6;
	-- academy hut outside the east side at z 82..98): a hedge along the stadium
	-- side, oak rows round the other three and bushes on the corners
	hedge(217.5, -178, 217.5, -12, 5)
	hedge(217.5, 12, 217.5, 178, 5)
	for _, x in { 236, 268, 300, 332 } do
		tree(x, -194, 22 + (x % 3), true)
		tree(x, 194, 23 - (x % 3), true)
	end
	for _, z in { -160, -120, -80, -40, 0, 40, 124, 162 } do
		tree(362, z, 22 + (z % 4), true)
	end
	for _, corner in { { 346, -186 }, { 346, 186 } } do
		bush(corner[1], corner[2], 5.5)
		bush(corner[1] + 5, corner[2] * 0.97, 4.5)
		bush(corner[1] - 2, corner[2] * 1.03, 4)
	end
	for _, x in { 252, 284, 316 } do
		bush(x, -190, 4.5)
		bush(x, 190, 4.5)
	end
	rock(350, 60, 4)
	rock(352, -100, 3)
end

-- ----------------------------------------------------------------- scattered

local function scattered(plan: Plan, keepOut: { Rect }, seed: number)
	local rng = Random.new(seed)
	local CLEAR = GroundsPlanting.CLEAR
	local reach = HALF - WALL_CLEAR
	local function spaced(p: Vector3, gap: number): boolean
		for _, t in plan.trees do
			if (t.at - p).Magnitude < gap then
				return false
			end
		end
		return true
	end
	local function near(centre: Vector3, r0: number, r1: number): Vector3
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(r0, r1)
		return centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	local function inside(p: Vector3, margin: number): boolean
		return math.abs(p.X) <= HALF - margin and math.abs(p.Z) <= HALF - margin
	end

	local centres: { Vector3 } = {}
	local tries = 0
	while #centres < GROVES and tries < 600 do
		tries += 1
		local c = v(rng:NextNumber(-reach, reach), rng:NextNumber(-reach, reach))
		local ok = clearOf(c, keepOut, CLEAR.tree) and spaced(c, TREE_SPACING + 6)
		for _, other in centres do
			if (other - c).Magnitude < GROVE_SPACING then
				ok = false
			end
		end
		if not ok then
			continue
		end
		table.insert(centres, c)
		-- the grove's big oak on the centre, one or two lesser ones round it
		table.insert(plan.trees, { at = c, height = rng:NextNumber(31, 40), slim = false })
		for _ = 1, rng:NextInteger(1, 2) do
			for _ = 1, 8 do
				local p = near(c, 18, 28)
				if inside(p, WALL_CLEAR) and clearOf(p, keepOut, CLEAR.tree) and spaced(p, TREE_SPACING) then
					table.insert(plan.trees, { at = p, height = rng:NextNumber(21, 30), slim = rng:NextNumber() < 0.5 })
					break
				end
			end
		end
		for _ = 1, rng:NextInteger(3, 4) do
			local p = near(c, 7, 20)
			if inside(p, 6) and clearOf(p, keepOut, CLEAR.small) and spaced(p, 5) then
				table.insert(plan.bushes, { at = p, width = rng:NextNumber(4, 6.5) })
			end
		end
		if rng:NextNumber() < 0.7 then
			local p = near(c, 9, 22)
			if inside(p, 6) and clearOf(p, keepOut, CLEAR.small) and spaced(p, 6) then
				table.insert(plan.rocks, { at = p, size = rng:NextNumber(3, 6) })
			end
		end
	end
end

-- Every spot, pitch-local on the ground plane. `keepOut` is PlotGrounds.plantingKeepOut().
function GroundsPlanting.plan(keepOut: { Rect }, seed: number?): Plan
	local plan: Plan = { trees = {}, bushes = {}, foundation = {}, rocks = {}, hedges = {} }
	planted(plan)
	scattered(plan, keepOut, seed or 1)
	return plan
end

-- --------------------------------------------------------------------- build

local ROCK = Color3.fromRGB(120, 118, 112)

local function boulder(parent: Instance, spot: RockSpot, rng: Random)
	local m = Instance.new("Model")
	m.Name = "Rock"
	-- a main slab and a smaller one leaning on it, both tilted and part buried
	for k = 1, 2 do
		local r = spot.size * (if k == 1 then 1 else rng:NextNumber(0.45, 0.65))
		local p = Instance.new("Part")
		p.Name = "Boulder"
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.Slate
		p.Color = ROCK:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12))
		p.Size = Vector3.new(r * 1.4, r * 0.9, r)
		local off = if k == 1 then Vector3.zero else Vector3.new(spot.size * 0.8, 0, spot.size * rng:NextNumber(-0.4, 0.4))
		p.CFrame = CFrame.new(spot.at + off + Vector3.new(0, r * 0.2, 0))
			* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.25))
		p.CastShadow = k == 1
		p.Parent = m
	end
	m.Parent = parent
end

-- Builds `Planting` under `parent` in pitch-local coordinates (the caller moves
-- it into the plot with everything else). Without the kit in the place the oaks,
-- bushes and hedges fall back to plain primitives, as everywhere TreeKit is used.
function GroundsPlanting.build(parent: Instance, keepOut: { Rect }, seed: number?): Model
	local m = Instance.new("Model")
	m.Name = "Planting"
	m.Parent = parent
	local plan = GroundsPlanting.plan(keepOut, seed)
	local rng = Random.new((seed or 1) * 7 + 3)
	local leaf = Color3.fromRGB(70, 112, 54)

	for _, h in plan.hedges do
		if TreeKit.hedgeRun(m, h.from, h.to, { height = h.height }) then
			continue
		end
		local len = (h.to - h.from).Magnitude
		local p = Instance.new("Part")
		p.Name = "Hedge"
		p.Anchored = true
		p.Material = Enum.Material.Grass
		p.Color = leaf
		p.Size = Vector3.new(2.6, h.height, len)
		p.CFrame = CFrame.lookAt(h.from, h.to) * CFrame.new(0, h.height / 2, -len / 2)
		p.Parent = m
	end
	for _, t in plan.trees do
		if TreeKit.tree(m, t.at, { height = t.height, slim = t.slim, rng = rng }) then
			continue
		end
		local trunkH = t.height * 0.45
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Anchored = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(92, 72, 54)
		trunk.Size = Vector3.new(1.4, trunkH, 1.4)
		trunk.CFrame = CFrame.new(t.at + Vector3.new(0, trunkH / 2, 0))
		trunk.Parent = m
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Shape = Enum.PartType.Ball
		crown.Anchored = true
		crown.CanCollide = false
		crown.CastShadow = false
		crown.Material = Enum.Material.Grass
		crown.Color = leaf
		crown.Size = Vector3.one * t.height * (if t.slim then 0.5 else 0.7)
		crown.CFrame = CFrame.new(t.at + Vector3.new(0, trunkH + crown.Size.Y * 0.35, 0))
		crown.Parent = m
	end
	local bushes = table.clone(plan.bushes)
	table.move(plan.foundation, 1, #plan.foundation, #bushes + 1, bushes)
	for _, b in bushes do
		if TreeKit.bush(m, b.at, { width = b.width, rng = rng }) then
			continue
		end
		local ball = Instance.new("Part")
		ball.Name = "Bush"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = true
		ball.CanCollide = false
		ball.CastShadow = false
		ball.Material = Enum.Material.LeafyGrass
		ball.Color = leaf
		ball.Size = Vector3.one * b.width * 0.8
		ball.CFrame = CFrame.new(b.at + Vector3.new(0, b.width * 0.25, 0))
		ball.Parent = m
	end
	for _, r in plan.rocks do
		boulder(m, r, rng)
	end
	m:SetAttribute("Trees", #plan.trees)
	m:SetAttribute("Bushes", #bushes)
	m:SetAttribute("Rocks", #plan.rocks)
	m:SetAttribute("Hedges", #plan.hedges)
	return m
end

return GroundsPlanting
