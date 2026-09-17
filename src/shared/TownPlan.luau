--!strict
-- X324: the bus card was eleven place names in a list, so a first-timer
-- choosing "Riverside Park" or "Plot 3 (for sale)" had no idea which way, how
-- far, or whether they could have walked. This is the pure half of the little
-- plan drawn in the card: where a world point lands in a plan rectangle, and
-- how far a trip is in the units a person thinks in (metres and minutes).
--
-- Nothing here touches Instances, so it is tested directly
-- (tests/TownPlanTest.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local TownPlan = {}

-- How fast a player crosses town on foot. Roblox's default WalkSpeed; Sprint
-- (E7.1) is faster in bursts but nobody sprints the whole way. TEMP.
TownPlan.WALK_STUDS_PER_SECOND = 16
-- Anything under this is "you could walk it", which is the question the card is
-- really answering. TEMP: a minute on foot. Rivermere is only about 1.4 km
-- across at STUDS_PER_METRE, so a looser figure marked almost every row.
TownPlan.WALKABLE_STUDS = 960

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Plan = {
	width: number,
	height: number,
	scale: number, -- pixels per stud
	offsetX: number, -- pixels; centres the content in the rectangle
	offsetY: number,
	bounds: Bounds,
}

-- The box the plan draws: every bus stop and every club plot, with a margin so
-- a dot on the edge is not half off the paper. The river and the ring road run
-- past it and are clipped by the frame that holds them.
function TownPlan.bounds(margin: number): Bounds
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local function fold(p: Vector3)
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
	end
	for _, stop in TownLayout.BUS_STOPS do
		fold(stop.position)
	end
	for _, plot in TownLayout.PLOTS do
		fold(plot.centre)
	end
	return { minX = minX - margin, maxX = maxX + margin, minZ = minZ - margin, maxZ = maxZ + margin }
end

-- Fit those bounds into a width x height rectangle at one uniform scale, so the
-- town keeps its shape, and centre what is left over. North (-Z) is up.
function TownPlan.fit(width: number, height: number, margin: number?): Plan
	local bounds = TownPlan.bounds(margin or 150)
	local spanX = math.max(bounds.maxX - bounds.minX, 1)
	local spanZ = math.max(bounds.maxZ - bounds.minZ, 1)
	local scale = math.min(width / spanX, height / spanZ)
	return {
		width = width,
		height = height,
		scale = scale,
		offsetX = (width - spanX * scale) / 2,
		offsetY = (height - spanZ * scale) / 2,
		bounds = bounds,
	}
end

-- Pixels from the plan rectangle's top-left corner.
function TownPlan.project(plan: Plan, p: Vector3): Vector2
	return Vector2.new(
		plan.offsetX + (p.X - plan.bounds.minX) * plan.scale,
		plan.offsetY + (p.Z - plan.bounds.minZ) * plan.scale
	)
end

-- A polyline thinned to at most `keep` points (first and last always kept), so
-- the ring road is a dozen frames rather than twenty.
function TownPlan.simplify(points: { Vector3 }, keep: number): { Vector3 }
	local n = #points
	if n <= keep or keep < 2 then
		return points
	end
	local out = {}
	for i = 1, keep - 1 do
		local at = 1 + math.floor((i - 1) * (n - 1) / (keep - 1))
		table.insert(out, points[at])
	end
	table.insert(out, points[n])
	return out
end

-- ------------------------------------------------------------------ distance

function TownPlan.metres(studs: number): number
	return studs / TownLayout.STUDS_PER_METRE
end

-- "360 m" / "1.4 km", rounded the way a signpost rounds.
function TownPlan.distanceText(studs: number): string
	local m = TownPlan.metres(studs)
	if m >= 950 then
		return ("%.1f km"):format(m / 1000)
	end
	if m >= 100 then
		return ("%d m"):format(math.floor(m / 10 + 0.5) * 10)
	end
	return ("%d m"):format(math.floor(m + 0.5))
end

-- "2 min" on foot, or "<1 min" for anything inside a minute.
function TownPlan.walkTimeText(studs: number): string
	local seconds = studs / TownPlan.WALK_STUDS_PER_SECOND
	if seconds < 60 then
		return "<1 min"
	end
	return ("%d min"):format(math.floor(seconds / 60 + 0.5))
end

-- What goes beside a destination row: how far and how long on foot.
function TownPlan.walkLabel(studs: number): string
	return ("%s · %s"):format(TownPlan.distanceText(studs), TownPlan.walkTimeText(studs))
end

function TownPlan.isWalkable(studs: number): boolean
	return studs <= TownPlan.WALKABLE_STUDS
end

-- Flat distance between two world points (the bus is a straight line; so is the
-- answer to "how far is that").
function TownPlan.flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- name -> stop, for the card (which knows destination names, not positions).
local byName: { [string]: TownLayout.BusStop } = {}
for _, stop in TownLayout.BUS_STOPS do
	byName[stop.name] = stop
end

function TownPlan.stop(name: string): TownLayout.BusStop?
	return byName[name]
end

return TownPlan
