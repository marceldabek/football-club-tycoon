--!strict
-- A planted top for a planter (backlog X130, RivermereStation.png: planters
-- overflowing with flowers). A low leafy bed sunk into the planter, with
-- small round flower heads poking out of it. Every part is named "Flowers",
-- which Quality already treats as decoration.
--
-- A Ball renders at its smallest axis, so flower heads are uniform balls
-- (the X65/X69/X70 lesson), laid out on a grid inside the bed so none hangs
-- over the planter's edge.

local Planting = {}

Planting.HEAD = 1.3 -- flower head diameter
Planting.BED_H = 0.7
Planting.SPACING = 1.9

-- Pure: flower head centres in the bed's local XZ (bed centred on 0, size x by
-- z), jittered but always at least HEAD / 2 inside the edges.
function Planting.headSpots(x: number, z: number, rng: Random): { Vector2 }
	local out: { Vector2 } = {}
	local r = Planting.HEAD / 2
	local nx = math.max(1, math.floor((x - Planting.HEAD) / Planting.SPACING) + 1)
	local nz = math.max(1, math.floor((z - Planting.HEAD) / Planting.SPACING) + 1)
	local stepX = if nx > 1 then (x - Planting.HEAD) / (nx - 1) else 0
	local stepZ = if nz > 1 then (z - Planting.HEAD) / (nz - 1) else 0
	local jitter = 0.25
	-- a bed no wider than a head (float32 sizes can make these a hair negative)
	local hx, hz = math.max(x / 2 - r, 0), math.max(z / 2 - r, 0)
	for i = 0, nx - 1 do
		for k = 0, nz - 1 do
			local px = if nx > 1 then -x / 2 + r + i * stepX else 0
			local pz = if nz > 1 then -z / 2 + r + k * stepZ else 0
			px = math.clamp(px + rng:NextNumber(-jitter, jitter), -hx, hx)
			pz = math.clamp(pz + rng:NextNumber(-jitter, jitter), -hz, hz)
			table.insert(out, Vector2.new(px, pz))
		end
	end
	return out
end

-- Builds the bed with its top at `top` (a CFrame at the bed's top centre,
-- level), x by z, flowers mostly `colour` with a few paler heads.
function Planting.bloom(parent: Instance, top: CFrame, x: number, z: number, colour: Color3, rng: Random)
	local function part(size: Vector3, cf: CFrame, c: Color3, ball: boolean)
		local p = Instance.new("Part")
		p.Name = "Flowers"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = Enum.Material.LeafyGrass
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = parent
	end
	part(Vector3.new(x, Planting.BED_H, z), top * CFrame.new(0, -Planting.BED_H / 2, 0), Color3.fromRGB(70, 110, 52), false)
	local pale = colour:Lerp(Color3.new(1, 1, 1), 0.35)
	for i, spot in Planting.headSpots(x, z, rng) do
		local lift = rng:NextNumber(0.05, 0.3)
		part(Vector3.one * Planting.HEAD, top * CFrame.new(spot.X, lift, spot.Y), if i % 3 == 0 then pale else colour, true)
	end
end

return Planting
