--!strict
-- Pitch geometry and formation zones shared by the world builder (server) and
-- the match presenter (client). Pure: no instances.
--
-- World layout: pitch centred on the origin, long axis along Z.
-- Home defends the SOUTH goal (+Z) and attacks NORTH (-Z); Away the reverse.
-- Scale: ~2.75 studs per metre, so a 105m x 68m pitch is 290 x 190 studs.

local Pitch = {}

export type Team = "Home" | "Away"
export type Tactic = "Balanced" | "Attack" | "Defend"
export type Role = "GK" | "DEF" | "MID" | "FWD"

Pitch.WIDTH = 190
Pitch.LENGTH = 290
Pitch.SURFACE_Y = 1 -- top of the grass part, and of the hardstanding around it
Pitch.GOAL_WIDTH = 20
Pitch.GOAL_HEIGHT = 7

-- Hardstanding: the paved ring between the touchline and the stands. Fans
-- walk on it, the dugouts sit on it, and every stand fronts onto it. Its outer
-- edge is the stand line, so a plot's front wall replaces the perimeter wall.
Pitch.SIDE_MARGIN = 26 -- beside a touchline (~9.5 m)
Pitch.END_MARGIN = 34 -- behind a goal; the nets alone are 6 deep
Pitch.SIDE_EDGE = Pitch.WIDTH / 2 + Pitch.SIDE_MARGIN
Pitch.END_EDGE = Pitch.LENGTH / 2 + Pitch.END_MARGIN

-- The players' tunnel: a mouth in the middle of the west side. Separate from
-- the turnstiles the human player walks through (those are at a corner).
Pitch.TUNNEL_GAP = 16 -- width of the mouth, along Z
Pitch.TUNNEL = Vector3.new(-(Pitch.SIDE_EDGE - 4), Pitch.SURFACE_Y, 0)

-- Starting XI role order. TeamGen and formationSlots both follow it.
local ROLES: { Role } = { "GK", "DEF", "DEF", "DEF", "DEF", "MID", "MID", "MID", "MID", "FWD", "FWD" }
Pitch.ROLES = ROLES

-- 4-4-2. x is a fraction of half the pitch width (-1 left .. 1 right),
-- depth is a fraction of the pitch length measured from the team's own goal.
local FORMATION = {
	{ x = 0, depth = 0.04 }, -- GK
	{ x = -0.7, depth = 0.2 },
	{ x = -0.25, depth = 0.17 },
	{ x = 0.25, depth = 0.17 },
	{ x = 0.7, depth = 0.2 },
	{ x = -0.7, depth = 0.45 },
	{ x = -0.25, depth = 0.42 },
	{ x = 0.25, depth = 0.42 },
	{ x = 0.7, depth = 0.45 },
	{ x = -0.2, depth = 0.68 },
	{ x = 0.2, depth = 0.68 },
}
Pitch.FORMATION = FORMATION -- read-only; the lineup board draws slots from it

-- TEMP: how far Attack / Defend push the outfield line (fraction of pitch length).
local TACTIC_SHIFT = 0.1
local X_SCALE = 0.85 -- keep wide players off the touchline

local function sign(team: Team): number
	return team == "Home" and -1 or 1 -- direction of attack along Z
end

-- Z of the goal line that `team` attacks.
function Pitch.goalZ(team: Team): number
	return sign(team) * Pitch.LENGTH / 2
end

-- Converts (x fraction, depth from own goal) into a world position for `team`.
function Pitch.toWorld(team: Team, x: number, depth: number): Vector3
	local dir = sign(team)
	local ownGoalZ = -dir * Pitch.LENGTH / 2
	return Vector3.new(
		dir * -x * (Pitch.WIDTH / 2) * X_SCALE, -- mirrored so both teams "see" the same left/right
		Pitch.SURFACE_Y,
		ownGoalZ + dir * depth * Pitch.LENGTH
	)
end

function Pitch.formationSlots(team: Team, tactic: Tactic): { Vector3 }
	local shift = tactic == "Attack" and TACTIC_SHIFT or (tactic == "Defend" and -TACTIC_SHIFT or 0)
	local slots = {}
	for i, slot in FORMATION do
		local depth = slot.depth
		if i > 1 then
			depth += shift
		end
		table.insert(slots, Pitch.toWorld(team, slot.x, depth))
	end
	return slots
end

return Pitch
