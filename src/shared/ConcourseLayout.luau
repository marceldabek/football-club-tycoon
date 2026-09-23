--!strict
-- The concourse inside the ground wall (playtest #7, ground plan spec s4):
-- where the catering stands at each catering tier, pure geometry shared by
-- PlotGrounds (which builds it) and MatchdayRoutes / MatchdayLife (the hatch
-- queue, and the fan routes that have to walk round it). Pitch-local studs
-- like PlotGrounds: origin the pitch centre, +X east, -X the street, -Z north.
--
-- Catering is one club-wide track (spec s1/s4), the existing amenity upgrade
-- (Config.AmenityLevels). TEMP mapping, question A2-Q1:
--   level 0 Nothing       grass; portaloos until the ground has toilet blocks
--   level 1 Snack Bar     tier 1: a burger van and a gravel strip along the backs of the built stands
--   level 2 Merch Stand   tier 2: the concourse paved; a kiosk behind every stand at map tier 2,
--                         a catering counter set into the back wall of every stand at map tier 3
--   level 3 Fan Zone      tier 3: more counters under the big stands, and the fan zone's
--                         picnic benches on the west side
-- Spec positions (s4) are kept where they fit. Two places they can't, handled here:
--   * a covered grandstand's back reaches z 230.4 at the ends, over the spec's
--     end kiosks (z +-232), so a stand at map tier 3 serves from its undercroft
--     from catering tier 2 instead of a kiosk (spec: undercroft only at tier 3)
--   * the burger van's spot (-153, -105) is inside the west stand's north wing
--     once that reaches map tier 3, so it moves to the west strip then

local Config = require(script.Parent.Config)
local Pitch = require(script.Parent.Pitch)
local StandAccess = require(script.Parent.StandAccess)

local ConcourseLayout = {}

export type Rect = { name: string, x0: number, x1: number, z0: number, z1: number }
export type Levels = { [string]: number }
-- a prop on the ground: bottom centre, and the way its front (hatch, door) faces
export type Spot = { name: string, at: Vector3, face: Vector3, rect: Rect }

local SIDE_EDGE, END_EDGE = Pitch.SIDE_EDGE, Pitch.END_EDGE -- 121, 179
-- the perimeter wall's inner faces (GroundEnvelope: lines x +-201, z +-259, 1.2 thick)
ConcourseLayout.WALL = { x0 = -200.4, x1 = 200.4, z0 = -258.4, z1 = 258.4 }

-- ------------------------------------------------------------------ tiers

-- TEMP (A2-Q1): the amenity level is the catering tier.
function ConcourseLayout.cateringTier(amenityLevel: number?): number
	return math.clamp(math.floor(amenityLevel or 0), 0, 3)
end

function ConcourseLayout.mapTier(level: number): number
	if level < 1 then
		return 0
	end
	return Config.StandMapTier[math.min(level, #Config.StandMapTier)]
end

-- Stand_<key> attributes off a ClubState / replicated plot folder.
function ConcourseLayout.levelsFrom(inst: Instance?): Levels
	local out: Levels = {}
	for _, plot in Config.StandPlots do
		local v = if inst then inst:GetAttribute("Stand_" .. plot.key) else nil
		out[plot.key] = if type(v) == "number" then v else 0
	end
	return out
end

-- ------------------------------------------------------------------ stands

local function plotOf(key: string): any
	for _, plot in Config.StandPlots do
		if plot.key == key then
			return plot
		end
	end
	error("no stand plot " .. key)
end

-- A stand-local box (x out from the wall line, z along the stand) as a
-- pitch-local rect. The west stand's frame is turned half round and the
-- north/south ones a quarter, but every stand is symmetric about its middle.
local function standRect(key: string, name: string, x0: number, x1: number, a0: number, a1: number): Rect
	if key == "East" then
		return { name = name, x0 = SIDE_EDGE + x0, x1 = SIDE_EDGE + x1, z0 = a0, z1 = a1 }
	elseif key == "West" then
		return { name = name, x0 = -SIDE_EDGE - x1, x1 = -SIDE_EDGE - x0, z0 = -a1, z1 = -a0 }
	elseif key == "North" then
		return { name = name, x0 = a0, x1 = a1, z0 = -END_EDGE - x1, z1 = -END_EDGE - x0 }
	end
	return { name = name, x0 = -a1, x1 = -a0, z0 = END_EDGE + x0, z1 = END_EDGE + x1 }
end
ConcourseLayout.standRect = standRect

-- Pitch-local footprint of a stand on the ground: terrace, back wall, roof
-- pillars and the 6-wide end stairs (StandAccess.ends).
function ConcourseLayout.standRects(key: string, level: number): { Rect }
	local plot = plotOf(key)
	local out: { Rect } = {}
	local reach = StandAccess.outward(level)
	for _, span in StandAccess.spans(key, plot.axis, level) do
		local a0, a1 = span[1], span[2]
		for _, e in StandAccess.ends(key, { span }) do
			if e.kind == "stair" then
				if e.dir < 0 then
					a0 -= StandAccess.STAIR_W
				else
					a1 += StandAccess.STAIR_W
				end
			end
		end
		table.insert(out, standRect(key, "Stand" .. key, 0, reach, a0, a1))
	end
	return out
end

-- Where a stand's rear gate / vomitory mouths are: pitch-local points on the
-- outer face of the back wall, and the unit direction out of the stand.
function ConcourseLayout.openings(key: string, level: number): { { at: Vector3, out: Vector3 } }
	local plot = plotOf(key)
	local spans = StandAccess.spans(key, plot.axis, level)
	local back = StandAccess.backFace(level)
	local out = {}
	for _, c in StandAccess.openingCentres(key, level, spans) do
		local r = standRect(key, "", back, back, c, c)
		local dir = if key == "East" then Vector3.new(1, 0, 0)
			elseif key == "West" then Vector3.new(-1, 0, 0)
			elseif key == "North" then Vector3.new(0, 0, -1)
			else Vector3.new(0, 0, 1)
		table.insert(out, { at = Vector3.new(r.x0, 0, r.z0), out = dir })
	end
	return out
end

-- ------------------------------------------------------------------ catering

-- Kit footprints (tools/kit/install_concourse.luau), ground plan across x / z
-- with the prop facing +Z: the burger van's hatch is on its -X side.
ConcourseLayout.KIOSK_SIZE = Vector2.new(8.4, 5.8)
ConcourseLayout.VAN_SIZE = Vector2.new(7.4, 12.7)
ConcourseLayout.LOO_SIZE = Vector2.new(3.5, 3.6)
ConcourseLayout.LOO_STEP = 3.9

local function footprint(name: string, at: Vector3, face: Vector3, size: Vector2): Spot
	-- size.X across the front, size.Y front to back
	local across, deep = size.X / 2, size.Y / 2
	local hx, hz = if math.abs(face.X) > 0.5 then deep else across, if math.abs(face.X) > 0.5 then across else deep
	return { name = name, at = at, face = face, rect = { name = name, x0 = at.X - hx, x1 = at.X + hx, z0 = at.Z - hz, z1 = at.Z + hz } }
end

-- The burger van (catering tier 1+): spec s4 (-153, -105), hatch facing the
-- open concourse to the west. Once the west stand's north wing reaches map
-- tier 3 its back (x -158.6, pillars -160.4..-172.4) covers that spot, so the
-- van parks in the west strip north of the forecourt, hatch to the east.
ConcourseLayout.VAN_SPOT = Vector3.new(-153, 0, -105)
ConcourseLayout.VAN_SPOT_WEST = Vector3.new(-186, 0, -50)
function ConcourseLayout.vanMoved(levels: Levels): boolean
	return ConcourseLayout.mapTier(levels.West or 0) >= 3
end
function ConcourseLayout.van(levels: Levels, tier: number): Spot?
	if tier < 1 then
		return nil
	end
	-- `face` is the hatch side; the van's length runs along Z either way
	if ConcourseLayout.vanMoved(levels) then
		local s = footprint("BurgerVan", ConcourseLayout.VAN_SPOT_WEST, Vector3.new(0, 0, 1), ConcourseLayout.VAN_SIZE)
		s.face = Vector3.new(1, 0, 0)
		return s
	end
	local s = footprint("BurgerVan", ConcourseLayout.VAN_SPOT, Vector3.new(0, 0, 1), ConcourseLayout.VAN_SIZE)
	s.face = Vector3.new(-1, 0, 0)
	return s
end

-- The catering upgrade's sign (WorldBuilder's AmenitySign, the world purchase
-- point): beside the van's spot, facing the way fans come from the NW block.
function ConcourseLayout.signSpot(levels: Levels): (Vector3, Vector3)
	if ConcourseLayout.vanMoved(levels) then
		return Vector3.new(-186, 0, -63), Vector3.new(0, 0, -1)
	end
	return Vector3.new(-153, 0, -118), Vector3.new(-1, 0, 0)
end

-- Portaloos (spec s4 (-154, 106)), doors to the west: only until the ground
-- tier brings the proper toilet blocks (Config.ToiletsFromTier), which also
-- means the west wing is never big enough to reach them.
function ConcourseLayout.loos(levels: Levels): { Spot }
	if Config.groundTier(levels) >= Config.ToiletsFromTier then
		return {}
	end
	local out: { Spot } = {}
	for i = -1, 1 do
		local at = Vector3.new(-154, 0, 106 + i * ConcourseLayout.LOO_STEP)
		table.insert(out, footprint("Portaloo", at, Vector3.new(-1, 0, 0), ConcourseLayout.LOO_SIZE))
	end
	return out
end

-- Spec s4 kiosk spots behind each side, facing the stand.
local KIOSK_SPOTS = {
	{ key = "North", at = Vector3.new(0, 0, -232), face = Vector3.new(0, 0, 1) },
	{ key = "South", at = Vector3.new(0, 0, 232), face = Vector3.new(0, 0, -1) },
	{ key = "East", at = Vector3.new(188, 0, -60), face = Vector3.new(-1, 0, 0) },
	{ key = "East", at = Vector3.new(188, 0, 60), face = Vector3.new(-1, 0, 0) },
	{ key = "West", at = Vector3.new(-185, 0, -110), face = Vector3.new(1, 0, 0) },
	{ key = "West", at = Vector3.new(-185, 0, 110), face = Vector3.new(1, 0, 0) },
}

-- Freestanding kiosks (catering tier 2+) behind the stands at map tier 2. The
-- north-west one gives way to the fan zone at tier 3.
function ConcourseLayout.kiosks(levels: Levels, tier: number): { Spot }
	local out: { Spot } = {}
	if tier < 2 then
		return out
	end
	for _, k in KIOSK_SPOTS do
		if ConcourseLayout.mapTier(levels[k.key] or 0) ~= 2 then
			continue
		end
		if tier >= 3 and k.key == "West" and k.at.Z < 0 then
			continue
		end
		table.insert(out, footprint("Kiosk" .. k.key, k.at, k.face, ConcourseLayout.KIOSK_SIZE))
	end
	return out
end

-- Undercroft catering (a stand at map tier 3, catering tier 2+): counters set
-- into the back wall between roof pillars, in bays with no vomitory. Two to a
-- stand (one to a west wing) at tier 2, twice that at tier 3.
ConcourseLayout.COUNTER_LENGTH = 10
ConcourseLayout.COUNTER_DEPTH = 1.2 -- proud of the back wall
export type Counter = { key: string, at: Vector3, out: Vector3, along: Vector3, rect: Rect }
function ConcourseLayout.counters(levels: Levels, tier: number): { Counter }
	local out: { Counter } = {}
	if tier < 2 then
		return out
	end
	for _, plot in Config.StandPlots do
		local level = levels[plot.key] or 0
		if ConcourseLayout.mapTier(level) < 3 then
			continue
		end
		local spans = StandAccess.spans(plot.key, plot.axis, level)
		-- the whole stand's length, as WorldBuilder spaces the pillars by it
		local maxLength = if plot.axis == "Z" then StandAccess.MAX_LENGTH.Z else StandAccess.MAX_LENGTH.X
		local standLength = math.floor(maxLength * StandAccess.SHAPES[math.min(level, #StandAccess.SHAPES)].lengthFrac)
		local holes: { { number } } = {}
		for _, c in StandAccess.openingCentres(plot.key, level, spans) do
			table.insert(holes, { c - StandAccess.OPENING_W / 2, c + StandAccess.OPENING_W / 2 })
		end
		local back = StandAccess.backFace(level)
		local perSpan = if tier >= 3 then 4 else 2
		if plot.key == "West" then
			perSpan = if tier >= 3 then 2 else 1
		end
		for _, span in spans do
			-- bay centres, nearest the middle of the run first, skipping any bay
			-- with a vomitory in it
			local zs = StandAccess.pillarZs(span, standLength, holes)
			local bays: { number } = {}
			for i = 1, #zs - 1 do
				local a, b = zs[i], zs[i + 1]
				local blocked = b - a < ConcourseLayout.COUNTER_LENGTH + 4
				for _, h in holes do
					if h[2] > a and h[1] < b then
						blocked = true
					end
				end
				if not blocked then
					table.insert(bays, (a + b) / 2)
				end
			end
			local mid = (span[1] + span[2]) / 2
			table.sort(bays, function(p, q)
				return math.abs(p - mid) < math.abs(q - mid)
			end)
			for i = 1, math.min(perSpan, #bays) do
				local c = bays[i]
				local h = ConcourseLayout.COUNTER_LENGTH / 2
				local r = standRect(plot.key, "Counter" .. plot.key, back, back + ConcourseLayout.COUNTER_DEPTH, c - h, c + h)
				local centre = standRect(plot.key, "", back, back, c, c)
				local dir = if plot.key == "East" then Vector3.new(1, 0, 0)
					elseif plot.key == "West" then Vector3.new(-1, 0, 0)
					elseif plot.key == "North" then Vector3.new(0, 0, -1)
					else Vector3.new(0, 0, 1)
				table.insert(out, {
					key = plot.key,
					at = Vector3.new(centre.x0, 0, centre.z0),
					out = dir,
					along = Vector3.new(-dir.Z, 0, dir.X),
					rect = r,
				})
			end
		end
	end
	return out
end

-- Fan zone (catering tier 3): paved, picnic benches, a tea cart. Spec s4.
ConcourseLayout.FAN_ZONE = { name = "FanZone", x0 = -198, x1 = -176, z0 = -150, z1 = -70 } :: Rect
function ConcourseLayout.fanZone(tier: number): Rect?
	return if tier >= 3 then ConcourseLayout.FAN_ZONE else nil
end
function ConcourseLayout.benchSpots(): { Vector3 }
	local out: { Vector3 } = {}
	for _, z in { -140, -126, -112, -98 } do
		for _, x in { -192, -182 } do
			table.insert(out, Vector3.new(x, 0, z))
		end
	end
	return out
end
ConcourseLayout.TEA_CART = Vector3.new(-187, 0, -80) -- faces +Z, toward the forecourt

-- ------------------------------------------------------------------ surface

-- Catering tier 1: a gravel strip along the back of every built stand.
ConcourseLayout.GRAVEL_W = 6
function ConcourseLayout.gravel(levels: Levels, tier: number): { Rect }
	local out: { Rect } = {}
	if tier ~= 1 then
		return out
	end
	for _, plot in Config.StandPlots do
		local level = levels[plot.key] or 0
		local back = StandAccess.outward(level)
		for _, r in ConcourseLayout.standRects(plot.key, level) do
			-- the stand's own rect re-cut to the strip behind it
			local a0, a1 = if plot.axis == "Z" then r.z0 else r.x0, if plot.axis == "Z" then r.z1 else r.x1
			if plot.key == "West" or plot.key == "South" then
				a0, a1 = -a1, -a0
			end
			table.insert(out, standRect(plot.key, "Gravel" .. plot.key, back, back + ConcourseLayout.GRAVEL_W, a0, a1))
		end
	end
	return out
end

-- Catering tier 2+: the whole concourse paved, wall to stand line, in four
-- slabs (the ends run the full width so the corners are covered).
function ConcourseLayout.paving(tier: number): { Rect }
	if tier < 2 then
		return {}
	end
	local W = ConcourseLayout.WALL
	return {
		{ name = "PavingNorth", x0 = W.x0, x1 = W.x1, z0 = W.z0, z1 = -END_EDGE },
		{ name = "PavingSouth", x0 = W.x0, x1 = W.x1, z0 = END_EDGE, z1 = W.z1 },
		{ name = "PavingEast", x0 = SIDE_EDGE, x1 = W.x1, z0 = -END_EDGE, z1 = END_EDGE },
		{ name = "PavingWest", x0 = W.x0, x1 = -SIDE_EDGE, z0 = -END_EDGE, z1 = END_EDGE },
	}
end

-- ------------------------------------------------------------------ hatch queue

-- X318's matchday queue at the snack hatch, now the burger van's: where the
-- first fan stands, the way the line runs back, and the way they all face.
function ConcourseLayout.hatchQueue(levels: Levels): (Vector3, Vector3, Vector3)
	if ConcourseLayout.vanMoved(levels) then
		-- the hatch faces the west wing's back; the line runs north along it
		local v = ConcourseLayout.VAN_SPOT_WEST
		return Vector3.new(v.X + ConcourseLayout.VAN_SIZE.X / 2 + 2.2, 0, v.Z + 1), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0)
	end
	local v = ConcourseLayout.VAN_SPOT
	return Vector3.new(v.X - ConcourseLayout.VAN_SIZE.X / 2 - 2.2, 0, v.Z + 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)
end

-- Where people stand about on the concourse while the match is on: on the
-- grass/paving north of the van, or the reception forecourt once the van has
-- moved into the west strip.
function ConcourseLayout.millingBox(levels: Levels): Rect
	if ConcourseLayout.vanMoved(levels) then
		return { name = "Milling", x0 = -196, x1 = -172, z0 = 10, z1 = 33 }
	end
	return { name = "Milling", x0 = -174, x1 = -156, z0 = -138, z1 = -114 }
end

-- ------------------------------------------------------------------ obstacles

-- Everything a fan route inside the wall has to walk round, pitch-local, for
-- the tests: stands, huts, toilets, masts, clubhouse, memorial, scoreboard,
-- the low wall, the team coach and TV van's current spots, and the catering.
function ConcourseLayout.obstacles(levels: Levels, tier: number): { Rect }
	local out: { Rect } = {}
	local function add(name: string, x0: number, x1: number, z0: number, z1: number)
		table.insert(out, { name = name, x0 = x0, x1 = x1, z0 = z0, z1 = z1 })
	end
	for _, plot in Config.StandPlots do
		for _, r in ConcourseLayout.standRects(plot.key, levels[plot.key] or 0) do
			table.insert(out, r)
		end
	end
	-- GroundEnvelope.HUTS inside the wall, its compound and its toilet blocks
	add("Stewards", -197, -183, -224, -212)
	add("FirstAid", -197, -183, -248, -236)
	add("Compound", 172, 199, 232, 257)
	if Config.groundTier(levels) >= Config.ToiletsFromTier then
		for _, t in { { 186, -222 }, { -170, 250 }, { 60, 250 }, { -60, -250 } } do
			add("Toilets", t[1] - 9, t[1] + 9, t[2] - 6, t[2] + 6)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add("Mast", sx * 140 - 4, sx * 140 + 4, sz * 200 - 4, sz * 200 + 4)
		end
	end
	add("Clubhouse", -169, -121, -40, 40) -- shell and its front doors' apron
	add("MemorialGarden", -198, -178, 34, 48)
	add("Statue", -189, -183, -3, 3)
	add("Scoreboard", 93, 107, -169, -161)
	add("LowWallEast", 107.6, 108.4, -158.4, 158.4)
	add("LowWallWestN", -108.4, -107.6, -158.4, -55)
	add("LowWallWestS", -108.4, -107.6, 55, 158.4)
	add("LowWallNorth", -108.4, 108.4, -158.4, -157.6)
	add("LowWallSouth", -108.4, 108.4, 157.6, 158.4)
	-- the team coach (PlotGrounds.COACH_BAY) and the TV van (MatchdayRoutes.MEDIA_VAN)
	-- park outside the wall since #25, so nothing of theirs stands in here
	local van = ConcourseLayout.van(levels, tier)
	if van then
		table.insert(out, van.rect)
	end
	for _, s in ConcourseLayout.loos(levels) do
		table.insert(out, s.rect)
	end
	for _, s in ConcourseLayout.kiosks(levels, tier) do
		table.insert(out, s.rect)
	end
	for _, c in ConcourseLayout.counters(levels, tier) do
		table.insert(out, c.rect)
	end
	local zone = ConcourseLayout.fanZone(tier)
	if zone then
		table.insert(out, zone)
	end
	return out
end

return ConcourseLayout
