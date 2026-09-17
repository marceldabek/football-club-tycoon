--!strict
-- Small client-side motion for the town (backlog F4.2): tree canopies swaying
-- in the breeze and a few birds wheeling round the church spire. Pure maths
-- only; TownMotion.client.luau owns the parts and the budget.
--
-- Nothing here builds or moves server parts in a way the server sees: canopy
-- offsets are applied on the client to parts that already exist, and birds
-- are client-only parts.

local TownMotion = {}

TownMotion.SWAY_AMPLITUDE = 0.35 -- TEMP studs at the top of a crown
TownMotion.SWAY_PERIOD = 4.2 -- TEMP seconds
TownMotion.BIRD_RADIUS = 38 -- TEMP studs round the circling centre
TownMotion.BIRD_PERIOD = 14 -- TEMP seconds per lap

-- Pure: a stable per-tree phase in [0, 2pi) from its position, so trees
-- don't sway in lockstep and the same tree keeps its phase every run.
function TownMotion.phase(position: Vector3): number
	local h = math.abs(math.floor(position.X * 12.9898 + position.Z * 78.233)) % 997
	return h / 997 * math.pi * 2
end

-- Pure: horizontal sway offset for a canopy at time `t`. The gust direction
-- turns slowly so the town doesn't all lean one way.
function TownMotion.swayOffset(t: number, phase: number, amplitude: number?): Vector3
	local a = amplitude or TownMotion.SWAY_AMPLITUDE
	local s = math.sin(t * 2 * math.pi / TownMotion.SWAY_PERIOD + phase)
	local heading = t * 0.05 + phase * 0.3
	return Vector3.new(math.cos(heading), 0, math.sin(heading)) * (s * a)
end

-- Pure: position of bird `index` of `count` circling `centre` at height
-- `height` at time `t`, with a small bob so the flock doesn't look like a
-- ring on rails. Also returns the flight direction (unit, flat).
function TownMotion.birdPosition(centre: Vector3, height: number, index: number, count: number, t: number): (Vector3, Vector3)
	local lap = t * 2 * math.pi / TownMotion.BIRD_PERIOD
	local angle = lap + (index - 1) / math.max(count, 1) * 1.1 -- a loose group, not evenly spread
	local r = TownMotion.BIRD_RADIUS + math.sin(index * 1.7) * 6
	local bob = math.sin(t * 1.8 + index) * 1.5
	local pos = centre + Vector3.new(math.cos(angle) * r, height + bob + index * 0.8, math.sin(angle) * r)
	local dir = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return pos, dir
end

-- Pure: flap angle (radians) for a bird's wings at time `t`.
function TownMotion.flap(t: number, index: number): number
	return math.sin(t * 9 + index * 2.3) * 0.5
end

return TownMotion
