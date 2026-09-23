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

-- #7/#14 (lane A2): the stand shapes per Config.StandLevels level, shared with
-- WorldBuilder (its STAND_SPECS read lengthFrac/rows from here), so the
-- concourse and the fan routes know where every stand's back wall and end
-- stairs are without building one. Stand-local frame as above.
StandAccess.STEP_DEPTH = 3 -- one row of seats (WorldBuilder STEP_DEPTH)
StandAccess.X0 = 0.6 -- the front row starts this far behind the wall line (WorldBuilder STAND_X0)
StandAccess.SHAPES = {
	{ lengthFrac = 0.21, rows = 3, roof = false },
	{ lengthFrac = 0.66, rows = 8, roof = false },
	{ lengthFrac = 0.82, rows = 12, roof = false },
	{ lengthFrac = 0.94, rows = 16, roof = true },
}
StandAccess.CLUBHOUSE_GAP = 41 -- Clubhouse.GAP_Z: the west wings stop here
-- the longest a stand can be along each side (WorldBuilder CORNER_Z / CORNER_X * 2)
StandAccess.MAX_LENGTH = { Z = 310, X = 210 }

-- The runs of terrace along the stand (local z) at `level`, like WorldBuilder's
-- plotGeometry: one centred run, or the west stand's two wings out from the
-- clubhouse. `axis` is Config.StandPlots' ("Z" = east/west side).
function StandAccess.spans(plotKey: string, axis: string, level: number): { { number } }
	if level < 1 then
		return {}
	end
	local shape = StandAccess.SHAPES[math.clamp(level, 1, #StandAccess.SHAPES)]
	local maxLength = if axis == "Z" then StandAccess.MAX_LENGTH.Z else StandAccess.MAX_LENGTH.X
	local half = math.floor(maxLength * shape.lengthFrac) / 2
	if plotKey == "West" then
		local g = StandAccess.CLUBHOUSE_GAP
		local far = math.min(g + half, maxLength / 2)
		return { { -far, -g }, { g, far } }
	end
	return { { -half, half } }
end

-- How far behind the wall line the stand reaches on the ground: the outer face
-- of the back wall (WorldBuilder backX + 0.5), and with a roof the pillars
-- centred 1.5 behind the wall's middle (1.5 square), so 1.75 further out.
function StandAccess.backFace(level: number): number
	if level < 1 then
		return 0
	end
	local shape = StandAccess.SHAPES[math.clamp(level, 1, #StandAccess.SHAPES)]
	return StandAccess.X0 + StandAccess.STEP_DEPTH * shape.rows + 1
end
function StandAccess.outward(level: number): number
	if level < 1 then
		return 0
	end
	local shape = StandAccess.SHAPES[math.clamp(level, 1, #StandAccess.SHAPES)]
	return StandAccess.backFace(level) + (if shape.roof then 1.75 else 0)
end

-- Roof pillar positions along one run of a roofed stand (local z), about six
-- bays to a full-length stand (WorldBuilder). A pillar that would stand in
-- front of a rear gate / vomitory steps aside to just past the opening's edge:
-- the west wings' openings are mid-run, exactly where their middle pillar fell.
function StandAccess.pillarZs(run: { number }, standLength: number, openings: { { number } }): { number }
	local length = run[2] - run[1]
	local bays = math.max(1, math.floor(length / (standLength / 6) + 0.5))
	local out: { number } = {}
	for i = 0, bays do
		local z = run[1] + (length / bays) * i
		for _, o in openings do
			if z > o[1] - 1 and z < o[2] + 1 then
				z = if z < (o[1] + o[2]) / 2 then o[1] - 1 else o[2] + 1
			end
		end
		table.insert(out, z)
	end
	return out
end

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
