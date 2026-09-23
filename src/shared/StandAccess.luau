--!strict
-- How fans get from the concourse into a stand (playtest #13 / #15, ground
-- plan spec s3). Pure geometry in WorldBuilder's stand-local frame: +X away
-- from the pitch (origin on the wall line), +Z along the stand, heights from
-- the ground. No Roblox services, so the tests and the builder share it.
--
--   end stairs     at both ends of every stand at every level, 6 wide, beside
--                  the terrace on the concourse side, climbing from the front
--                  to the top row with a side railing on the open side. The
--                  west wings' clubhouse ends have the clubhouse there instead,
--                  so they get a side railing along the terrace end.
--   rear gates /   level 2 ("rear gates") and 3+ ("vomitories"): a 6-wide
--   vomitories     opening at the foot of the back wall, then a ramp up under
--                  the back rows that comes out on the middle row. Rows over
--                  the ramp with head room are carried across it as slabs;
--                  the rest are cut, leaving the mouth open to the sky.

local StandAccess = {}

StandAccess.STAIR_W = 6
StandAccess.OPENING_W = 6
StandAccess.CLEAR_H = 7 -- head room in a rear gate / vomitory
StandAccess.SLAB_MIN = 1 -- thinnest a carried row may be
StandAccess.RAIL_H = 3.4 -- waist height on a standing character (WorldBuilder RAIL_H)
StandAccess.RAIL_FROM_STEP = 3 -- the low steps stay open at the side, so fans can step on

export type Step = { x0: number, x1: number, top: number }
export type StandEnd = { z: number, dir: number, kind: string } -- dir: +1 = the stair lies at z > zEnd

-- Two steps a row plus one, so no rise is much over 0.75 and the top step is
-- level with the back row.
function StandAccess.stairSteps(rows: number, stepDepth: number, stepHeight: number, x0: number, deckY: number): { Step }
	local n = 2 * rows + 1
	local height = deckY + stepHeight * rows
	local run = stepDepth * rows / n
	local out: { Step } = {}
	for k = 1, n do
		table.insert(out, { x0 = x0 + (k - 1) * run, x1 = x0 + k * run, top = height * k / n })
	end
	return out
end

-- Every end of every span: a stair, or (a west wing's clubhouse end) a rail.
function StandAccess.ends(plotKey: string, spans: { { number } }): { StandEnd }
	local out: { StandEnd } = {}
	for _, span in spans do
		for i, z in { span[1], span[2] } do
			local dir = if i == 1 then -1 else 1
			-- the west wings run out from the clubhouse gap: their inner ends face it
			local inner = plotKey == "West" and math.abs(z) < math.abs(if i == 1 then span[2] else span[1])
			table.insert(out, { z = z, dir = dir, kind = if inner then "rail" else "stair" })
		end
	end
	return out
end

-- Local z centres of the rear gates / vomitories on a stand (spec s3: East at
-- z +-70, each west wing at its centre, North/South at x +-40). None on bleachers.
function StandAccess.openingCentres(plotKey: string, level: number, spans: { { number } }): { number }
	if level < 2 then
		return {}
	end
	local out: { number } = {}
	if plotKey == "West" then
		for _, span in spans do
			table.insert(out, (span[1] + span[2]) / 2)
		end
		return out
	end
	local c = if plotKey == "East" then 70 else 40
	for _, span in spans do
		for _, z in { -c, c } do
			if z - StandAccess.OPENING_W / 2 > span[1] + 4 and z + StandAccess.OPENING_W / 2 < span[2] - 4 then
				table.insert(out, z)
			end
		end
	end
	return out
end

export type Ramp = { xMouth: number, xBack: number, hMouth: number, mouthRow: number }

-- The ramp from the foot of the back wall up to the back edge of the middle row.
function StandAccess.ramp(rows: number, stepDepth: number, stepHeight: number, x0: number, deckY: number): Ramp
	local m = math.floor(rows / 2)
	return {
		xMouth = x0 + stepDepth * m,
		xBack = x0 + stepDepth * rows,
		hMouth = deckY + stepHeight * m,
		mouthRow = m,
	}
end

-- Floor height of the ramp at x.
function StandAccess.rampFloor(r: Ramp, x: number): number
	if x <= r.xMouth then
		return r.hMouth
	end
	return math.max(0, r.hMouth * (r.xBack - x) / (r.xBack - r.xMouth))
end

-- What row `i` does where it crosses an opening: "none" (in front of the
-- mouth, untouched), "carried" (a slab from `under` to its top), or "cut".
function StandAccess.rowOverOpening(i: number, rows: number, stepDepth: number, stepHeight: number, x0: number, deckY: number): (string, number?)
	local r = StandAccess.ramp(rows, stepDepth, stepHeight, x0, deckY)
	if i <= r.mouthRow then
		return "none", nil
	end
	local front = x0 + stepDepth * (i - 1)
	local floor = StandAccess.rampFloor(r, front) -- highest point of the ramp under this row
	local top = deckY + stepHeight * i
	local under = floor + StandAccess.CLEAR_H
	if top - under >= StandAccess.SLAB_MIN then
		return "carried", under
	end
	return "cut", nil
end

return StandAccess
