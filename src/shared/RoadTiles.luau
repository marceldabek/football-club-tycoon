--!strict
-- Rivermere v3, Lane R: PURE road tiling maths. Roads in, a list of kit tiles out.
-- No Instances are created or read here, so everything is testable headless.
-- The assembler that turns tiles into kit models is src/server/RoadTiler.luau.
--
-- HOW THE KIT PIECES WORK (measured in Studio 2026-09-20, see PIECES below)
--   Every UKSP__ModularRoads piece is carriageway (15.9 wide) + kerb + pavement,
--   44 studs across in total, so the kit brings its own pavements (register row
--   E4 is not needed by this lane). Piece coordinates below are in the piece's
--   own bounding-box-centre frame at identity rotation, unscaled: +X right,
--   +Z "down" on a top-down screenshot. The pavement top is the bbox top on every
--   piece, but heights differ (0.43 to 0.76), so tiles are aligned by their TOP.
--
-- SCALE PER KIND (uniform, markings stay in proportion)
--   residential / lane 0.816 : 44 -> 35.9, the 36-stud corridor (20 road + 16 pavement).
--   main / ring        0.93  : 44 -> 40.9. Main's corridor is 42 (half a stud of
--     verge each side); the ring's is 48 (3.5-stud grass verge each side, right for
--     a ring road). 0.93 is the largest scale at which the ring's tightest pair of
--     45-degree bends (113 studs apart, north of Northfields) still fits two kit
--     bends leg to leg, and it keeps ring, main and their junctions one width so
--     nothing steps where they meet. A true 48-wide ring would need bends scaled
--     1.09, which do not fit the approved layout.
--
-- JUNCTION RULES
--   2 arms, collinear      -> nothing (the run passes through)
--   2 arms, 90 / 45 bend   -> DegreeLeft2/DegreeRight, DegreeLeft45/Right45Degree
--   3 arms, T at 90        -> TJunctionRight
--   4 arms, all 90         -> Crossroads
--   head road's last point -> CulDeSac (bulb centred on the point)
--   big roundabout         -> arms trimmed short, E3 stand-in disc on top
--   anything else (45-degree T, skew cross, the High Street / Station Road split)
--                          -> the best pair of arms becomes the through line or a
--                             bend, and the other arms TUCK: their last straight
--                             is pitched down a fraction so its end slides under
--                             the through road. The kit has no 45-degree T, and its
--                             Fork has branches 90 degrees apart (each 135 from the
--                             stem) while the layout's split is a through line plus
--                             a 45-degree spur, so Fork cannot be placed there
--                             without moving Station Road 60 studs off its houses.
--   Junction pieces that do not fit between their neighbours (the layout has T's
--   10 to 70 studs apart; a T piece is 90 long) are DOWNGRADED to a tuck as well.
--   CulDeSac_Left/Right90Degree are a 90 bend with a bulb on the corner and TWO
--   mouths, so they are not a terminal head; no v3 road needs one.

local RoadTiles = {}

export type RoadIn = {
	name: string,
	kind: string,
	points: { Vector3 },
	head: boolean?,
	district: string?,
}
export type RoundaboutIn = { name: string?, centre: Vector3, radius: number }
export type Tile = {
	piece: string, -- full kit name
	cframe: CFrame, -- centre of the piece's bounding-box TOP face (pavement level)
	scale: number, -- uniform scale
	stretch: number, -- extra factor along the piece's local Z (straights only), 1 otherwise
	kind: string, -- "straight" | "bend90" | "bend45" | "tee" | "cross" | "head"
	road: string,
	district: string,
	yellow: boolean,
	tucked: boolean,
}
export type BridgeIn = { from: Vector3, to: Vector3, kind: string? }
export type Exempt = { id: string, shape: string, centre: Vector3, radius: number, height: number, look: string }
export type Plan = { tiles: { Tile }, exempt: { Exempt }, stats: { [string]: number } }

local PREFIX = "UKSP__ModularRoads__"
RoadTiles.PREFIX = PREFIX
RoadTiles.SURFACE_Y = 0.35 -- pavement top above ground
RoadTiles.SCALE = { ring = 0.93, main = 0.93, residential = 0.816, lane = 0.816 } :: { [string]: number }
RoadTiles.RANK = { ring = 4, main = 3, residential = 2, lane = 1 } :: { [string]: number }
RoadTiles.ARTERIAL = "Arterial"
-- TEMP: the Town Centre box (yellow lines, and the district for roads with none).
RoadTiles.CENTRE = { minX = -520, maxX = 520, minZ = -340, maxZ = 340 }
RoadTiles.BIG_ROUNDABOUT = 25 -- radius at or above this trims the arms; below is a mini island
RoadTiles.END_OVERSHOOT = 10 -- a tee / cross arm may run this far past a plain dead end
local ROUNDABOUT_INSET = 8
local OVERSHOOT = 12 -- a tucked arm runs this far past its node, under the through road
local S = math.sqrt(0.5)

-- x, z pairs are { x, z }. `node` is the point where the arms' centrelines meet.
-- dirA/dirB point OUT of the piece along each arm; legA/legB are node-to-mouth.
RoadTiles.PIECES = {
	straight = { name = "Straight", yellow = "StraightYellowLines", height = 0.433, length = 110, width = 44 },
	cross = { name = "Crossroads", yellow = "CrossroadsYellowLines", height = 0.433, node = { 0, 0 }, arm = 55 },
	-- through road along Z at x = 16.5, branch leaves towards -X
	tee = { name = "TJunctionRight", yellow = "TJunctionRightYellowLines", height = 0.433, node = { 16.5, 0 }, branch = { -1, 0 }, arm = 55 },
	bend90L = { name = "DegreeLeft2", yellow = "DegreeLeft90YellowLines", height = 0.433, node = { -35.74, 37.12 }, dirA = { 0, -1 }, dirB = { 1, 0 }, legA = 96.23, legB = 93.48 },
	bend90R = { name = "DegreeRight", yellow = "DegreeRight90YellowLines", height = 0.433, node = { 35.74, 37.12 }, dirA = { 0, -1 }, dirB = { -1, 0 }, legA = 96.23, legB = 93.48 },
	bend45L = { name = "DegreeLeft45Degree", yellow = "DegreeLeft45DegreeYellowLines", height = 0.715, node = { -21.49, -2.23 }, dirA = { 0, -1 }, dirB = { S, S }, legA = 60.52, legB = 69.89 },
	bend45R = { name = "DegreeRight45Degree", yellow = "DegreeRight45DegreeYellowLines", height = 0.715, node = { 21.49, -2.23 }, dirA = { 0, -1 }, dirB = { -S, S }, legA = 60.52, legB = 69.89 },
	-- node = centre of the turning bulb
	head = { name = "CulDeSac", height = 0.761, node = { -16.39, 0 }, dirA = { 1, 0 }, legA = 75.26 },
	headYellow = { name = "CulDeSacYellowLines", height = 0.761, node = { 0, 16.57 }, dirA = { 0, -1 }, legA = 75.44 },
} :: { [string]: any }

-- Recorded for completeness; not placed (see the header for why).
RoadTiles.UNUSED = {
	Fork = "stem (0,-60) facing -Z; branches at (+-44, 44.4) facing (+-1,1)/sqrt2; branches 90 apart",
	CulDeSac_Right90Degree = "90 bend with a bulb on the corner, two mouths",
	CulDeSac_Left90Degree = "90 bend with a bulb on the corner, two mouths",
	RoadLeftTurn = "gentle S-curve lane shift, not a 45 or 90",
	DegreeLeft = "shallow bend (not 45), 128 x 80",
}

----------------------------------------------------------------------------------------------------

local function yawOf(x: number, z: number): number
	-- CFrame.Angles(0, t, 0) takes a vector of yaw a to yaw a + t with this convention
	return math.atan2(-z, x)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function keyOf(v: Vector3): string
	return string.format("%d|%d", math.round(v.X), math.round(v.Z))
end

local function sepDeg(a: Vector3, b: Vector3): number
	return math.round(math.deg(math.acos(math.clamp(a:Dot(b), -1, 1))))
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= 3
end

local function inCentre(p: Vector3): boolean
	local c = RoadTiles.CENTRE
	return p.X >= c.minX and p.X <= c.maxX and p.Z >= c.minZ and p.Z <= c.maxZ
end

function RoadTiles.districtOf(road: RoadIn): string
	if road.district then
		return road.district
	end
	for _, p in road.points do
		if not inCentre(p) then
			return RoadTiles.ARTERIAL
		end
	end
	return "Town Centre"
end

-- Proper intersection of segments ab and cd (interiors only), or nil.
local function intersect(a: Vector3, b: Vector3, c: Vector3, d: Vector3): Vector3?
	local rX, rZ = b.X - a.X, b.Z - a.Z
	local sX, sZ = d.X - c.X, d.Z - c.Z
	local den = rX * sZ - rZ * sX
	if math.abs(den) < 1e-9 then
		return nil
	end
	local t = ((c.X - a.X) * sZ - (c.Z - a.Z) * sX) / den
	local u = ((c.X - a.X) * rZ - (c.Z - a.Z) * rX) / den
	if t > 1e-6 and t < 1 - 1e-6 and u > 1e-6 and u < 1 - 1e-6 then
		return Vector3.new(a.X + rX * t, 0, a.Z + rZ * t)
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Graph

local function buildGraph(roads: { RoadIn }, roundabouts: { RoundaboutIn })
	local segs = {}
	for _, road in roads do
		for i = 1, #road.points - 1 do
			local a, b = flat(road.points[i]), flat(road.points[i + 1])
			if (b - a).Magnitude > 0.5 then
				table.insert(segs, { road = road, a = a, b = b, len = (b - a).Magnitude, dir = (b - a).Unit, last = i == #road.points - 1 })
			end
		end
	end

	local nodes: { [string]: any } = {}
	local nodeList = {}
	local function nodeAt(p: Vector3)
		local k = keyOf(p)
		local n = nodes[k]
		if not n then
			n = { pos = p, arms = {}, kind = "end", scale = 1, shrink = 1, downgraded = false, rb = nil }
			nodes[k] = n
			table.insert(nodeList, n)
		end
		return n
	end
	for _, s in segs do
		nodeAt(s.a)
		nodeAt(s.b)
	end
	for i = 1, #segs do
		for j = i + 1, #segs do
			if segs[i].road ~= segs[j].road then
				local p = intersect(segs[i].a, segs[i].b, segs[j].a, segs[j].b)
				if p then
					nodeAt(p)
				end
			end
		end
	end
	for _, rb in roundabouts do
		local n = nodes[keyOf(flat(rb.centre))]
		if n then
			n.rb = rb
		end
	end

	local edges = {}
	for _, s in segs do
		local on = {}
		for _, n in nodeList do
			local rel = n.pos - s.a
			local t = rel:Dot(s.dir)
			local off = (rel - s.dir * t).Magnitude
			if off < 0.75 and t > -0.75 and t < s.len + 0.75 then
				table.insert(on, { t = math.clamp(t, 0, s.len), node = n })
			end
		end
		table.sort(on, function(x, y)
			return x.t < y.t
		end)
		for i = 1, #on - 1 do
			local A, B = on[i], on[i + 1]
			if B.t - A.t > 0.5 then
				local edge = { road = s.road, len = B.t - A.t }
				local armA = { node = A.node, dir = s.dir, road = s.road, edge = edge, run = s.len - A.t, trim = 0, tuck = false, pass = false, crit = 0 }
				local armB = { node = B.node, dir = -s.dir, road = s.road, edge = edge, run = B.t, trim = 0, tuck = false, pass = false, crit = 0 }
				-- the road's head sits on the far end of its last segment
				armB.isHead = s.road.head == true and s.last and math.abs(B.t - s.len) < 0.5
				edge.armA, edge.armB = armA, armB
				table.insert(A.node.arms, armA)
				table.insert(B.node.arms, armB)
				table.insert(edges, edge)
			end
		end
	end
	return nodeList, edges
end

----------------------------------------------------------------------------------------------------
-- Node classification: decides each arm's trim / tuck / pass and the node's piece.

local function scaleOf(arm): number
	return RoadTiles.SCALE[arm.road.kind] or 0.816
end
local function rankOf(arm): number
	return RoadTiles.RANK[arm.road.kind] or 1
end

local function setTuck(node, arm, throughScale: number, angleDeg: number)
	arm.tuck = true
	arm.trim = -OVERSHOOT
	local sinA = math.max(0.5, math.sin(math.rad(angleDeg)))
	local cotA = math.abs(math.cos(math.rad(angleDeg))) / sinA
	-- distance from the node, along the arm, inside which the arm must sit below the through carriageway
	arm.crit = OVERSHOOT + 12.25 * throughScale / sinA + 22 * scaleOf(arm) * cotA
end

local function classify(node)
	local arms = node.arms
	for _, a in arms do
		a.trim, a.tuck, a.pass, a.partner, a.crit = 0, false, false, nil, 0
	end
	node.piece = nil
	local n = #arms
	local maxScale = 0
	for _, a in arms do
		maxScale = math.max(maxScale, scaleOf(a))
	end
	node.scale = maxScale

	if node.rb and node.rb.radius >= RoadTiles.BIG_ROUNDABOUT then
		node.kind = "roundabout"
		for _, a in arms do
			a.trim = node.rb.radius - ROUNDABOUT_INSET
		end
		return
	end

	if n == 1 then
		local a = arms[1]
		if a.isHead then
			node.kind = "head"
			node.scale = scaleOf(a) * node.shrink
			a.trim = RoadTiles.PIECES.head.legA * node.scale
		else
			node.kind = "end"
		end
		return
	end

	if not node.downgraded then
		if n == 3 then
			for i = 1, 3 do
				local j, k = i % 3 + 1, (i + 1) % 3 + 1
				if near(sepDeg(arms[j].dir, arms[k].dir), 180) and near(sepDeg(arms[i].dir, arms[j].dir), 90) then
					node.kind = "tee"
					node.branch = arms[i]
					node.scale = math.max(scaleOf(arms[j]), scaleOf(arms[k]))
					for _, a in arms do
						a.trim = RoadTiles.PIECES.tee.arm * node.scale
					end
					return
				end
			end
		elseif n == 4 then
			local ok = true
			for i = 1, 4 do
				local opposite, square = 0, 0
				for j = 1, 4 do
					if j ~= i then
						local s = sepDeg(arms[i].dir, arms[j].dir)
						if near(s, 180) then
							opposite += 1
						elseif near(s, 90) then
							square += 1
						end
					end
				end
				ok = ok and opposite == 1 and square == 2
			end
			if ok then
				node.kind = "cross"
				for _, a in arms do
					a.trim = RoadTiles.PIECES.cross.arm * node.scale
				end
				return
			end
		end
	end

	-- General case: pick the best pair, everything else tucks under it.
	local best, bestScore, bestSep = nil, -1, 0
	for i = 1, n do
		for j = i + 1, n do
			local s = sepDeg(arms[i].dir, arms[j].dir)
			local same = arms[i].road == arms[j].road
			local score = -1
			if near(s, 180) then
				score = same and 200 or 100
			elseif near(s, 135) or near(s, 90) then
				score = same and 150 or 10
			end
			if score >= 0 then
				score += rankOf(arms[i]) + rankOf(arms[j])
				if score > bestScore then
					best, bestScore, bestSep = { arms[i], arms[j] }, score, s
				end
			end
		end
	end
	if not best then
		node.kind = "end"
		return
	end
	local p, q = best[1], best[2]
	local throughScale = math.max(scaleOf(p), scaleOf(q))
	if near(bestSep, 180) then
		node.kind = "through"
		if math.abs(scaleOf(p) - scaleOf(q)) < 1e-3 then
			p.pass, q.pass = true, true
			p.partner, q.partner = q, p
		end
	else
		local is90 = near(bestSep, 90)
		node.kind = is90 and "bend90" or "bend45"
		node.scale = throughScale * node.shrink
		local armA, armB = p, q
		if q.run < p.run then
			armA, armB = q, p -- the short leg goes on the shorter stretch of road
		end
		local cross = armA.dir.X * armB.dir.Z - armA.dir.Z * armB.dir.X
		local id = (is90 and "bend90" or "bend45") .. (cross > 0 and "L" or "R")
		node.piece = id
		node.armA = armA
		armA.trim = RoadTiles.PIECES[id].legA * node.scale
		armB.trim = RoadTiles.PIECES[id].legB * node.scale
	end
	for _, a in arms do
		if a ~= p and a ~= q then
			local angle = math.min(sepDeg(a.dir, p.dir), sepDeg(a.dir, q.dir))
			if node.kind ~= "through" then
				angle = 45 -- under a bend: assume the worst case
			end
			setTuck(node, a, throughScale, angle)
		end
	end
end

local function buildRuns(nodeList)
	local runs = {}
	local seen = {}
	for _, node in nodeList do
		for _, arm in node.arms do
			if not arm.pass and not seen[arm.edge] then
				local cur, len = arm, 0
				local far
				while true do
					local e = cur.edge
					seen[e] = true
					len += e.len
					far = if e.armA == cur then e.armB else e.armA
					if far.pass and far.partner and not seen[far.partner.edge] then
						cur = far.partner
					else
						break
					end
				end
				table.insert(runs, { from = arm, to = far, len = len })
			end
		end
	end
	return runs
end

----------------------------------------------------------------------------------------------------
-- Tile emission

local function topAt(pos: Vector3): Vector3
	return Vector3.new(pos.X, RoadTiles.SURFACE_Y, pos.Z)
end

local function pieceName(def, yellow: boolean): string
	return PREFIX .. ((yellow and def.yellow) or def.name)
end

local function anchored(pos: Vector3, def, worldDir: Vector3, localDir: { number }): CFrame
	local theta = yawOf(worldDir.X, worldDir.Z) - yawOf(localDir[1], localDir[2])
	return CFrame.new(topAt(pos)) * CFrame.Angles(0, theta, 0) * CFrame.new(-def.node[1], 0, -def.node[2])
end

local function nodeRoad(node)
	local bestArm = node.arms[1]
	for _, a in node.arms do
		if rankOf(a) > rankOf(bestArm) then
			bestArm = a
		end
	end
	return bestArm.road
end

local function emitNode(node, tiles: { Tile }, exempt: { Exempt })
	local kind = node.kind
	local road = nodeRoad(node)
	local yellow = inCentre(node.pos) or road.kind == "lane"
	local function add(def, cf: CFrame, tileKind: string, r)
		table.insert(tiles, {
			piece = pieceName(def, yellow), cframe = cf, scale = node.scale, stretch = 1, kind = tileKind,
			road = r.name, district = RoadTiles.districtOf(r), yellow = yellow, tucked = false,
		})
	end
	if kind == "bend90" or kind == "bend45" then
		local def = RoadTiles.PIECES[node.piece]
		local s = node.scale
		local scaled = { node = { def.node[1] * s, def.node[2] * s } }
		add(def, anchored(node.pos, scaled, node.armA.dir, def.dirA), kind, node.armA.road)
	elseif kind == "tee" then
		local def = RoadTiles.PIECES.tee
		local s = node.scale
		add(def, anchored(node.pos, { node = { def.node[1] * s, def.node[2] * s } }, node.branch.dir, def.branch), kind, road)
	elseif kind == "cross" then
		add(RoadTiles.PIECES.cross, anchored(node.pos, { node = { 0, 0 } }, node.arms[1].dir, { 0, -1 }), kind, road)
	elseif kind == "head" then
		local def = yellow and RoadTiles.PIECES.headYellow or RoadTiles.PIECES.head
		local s = node.scale
		local arm = node.arms[1]
		table.insert(tiles, {
			piece = PREFIX .. def.name, cframe = anchored(node.pos, { node = { def.node[1] * s, def.node[2] * s } }, arm.dir, def.dirA),
			scale = s, stretch = 1, kind = "head", road = arm.road.name, district = RoadTiles.districtOf(arm.road),
			yellow = yellow, tucked = false,
		})
	end
	if node.rb then
		local r = node.rb.radius
		local big = r >= RoadTiles.BIG_ROUNDABOUT
		local top = RoadTiles.SURFACE_Y
		if big then
			table.insert(exempt, { id = "E3", shape = "disc", centre = Vector3.new(node.pos.X, top + 0.04, node.pos.Z), radius = r, height = 0.12, look = "asphalt" })
		end
		local ir = if big then r * 0.45 else 5
		local ih = if big then 1.2 else 0.16
		table.insert(exempt, { id = "E3", shape = "disc", centre = Vector3.new(node.pos.X, top + 0.1 + ih / 2, node.pos.Z), radius = ir, height = ih, look = big and "island" or "paint" })
	end
end

local function emitRun(run, tiles: { Tile }, stats: { [string]: number }, bridges: { BridgeIn }?, skipBridges: boolean?)
	local from, to = run.from, run.to
	local dir: Vector3 = from.dir
	local startT = from.trim
	local endT = run.len - to.trim
	local rem = endT - startT
	if rem < 1 then
		if rem > 0 then
			stats.maxGap = math.max(stats.maxGap, rem)
		end
		return
	end
	-- Bridge spans lying on this run: the bridge deck is the road there, so the
	-- straights stop at one end of the span and start again at the other.
	if bridges and not skipBridges then
		local origin: Vector3 = from.node.pos
		local normal = Vector3.new(-dir.Z, 0, dir.X)
		for _, bridge in bridges do
			local a = Vector3.new(bridge.from.X - origin.X, 0, bridge.from.Z - origin.Z)
			local b = Vector3.new(bridge.to.X - origin.X, 0, bridge.to.Z - origin.Z)
			if math.abs(a:Dot(normal)) < 2 and math.abs(b:Dot(normal)) < 2 then
				local t0 = math.min(a:Dot(dir), b:Dot(dir))
				local t1 = math.max(a:Dot(dir), b:Dot(dir))
				if t0 < endT - 1 and t1 > startT + 1 then
					stats.bridged = (stats.bridged or 0) + 1
					local function piece(s: number, e: number, fromArm, toArm)
						if e - s >= 1 then
							emitRun({
								from = { node = from.node, dir = dir, road = from.road, trim = s, tuck = fromArm and fromArm.tuck, crit = fromArm and fromArm.crit },
								to = { node = to.node, road = to.road, trim = run.len - e, tuck = toArm and toArm.tuck, crit = toArm and toArm.crit },
								len = run.len,
							}, tiles, stats, nil, true)
						end
					end
					piece(startT, math.max(startT, t0), from, nil)
					piece(math.min(endT, t1), endT, nil, to)
					return
				end
			end
		end
	end
	local road = from.road
	local scale = scaleOf(from)
	local def = RoadTiles.PIECES.straight
	local tileLen = def.length * scale
	local n = math.max(1, math.round(rem / tileLen))
	if from.tuck and to.tuck and n < 2 then
		n = 2
	end
	local each = rem / n
	local district = RoadTiles.districtOf(road)
	for i = 1, n do
		local t0 = startT + each * (i - 1)
		local t1 = t0 + each
		local p0 = topAt(from.node.pos + dir * t0)
		local p1 = topAt(from.node.pos + dir * t1)
		local tucked = false
		local function drop(arm): number
			local span = each - arm.crit
			if span < each * 0.2 then
				return 1.5
			end
			return math.min(1.5, 0.34 * each / span)
		end
		if i == 1 and from.tuck then
			p0 -= Vector3.new(0, drop(from), 0)
			tucked = true
		end
		if i == n and to.tuck then
			p1 -= Vector3.new(0, drop(to), 0)
			tucked = true
		end
		local mid = (p0 + p1) / 2
		local axis = (p1 - p0).Unit
		local yellow = road.kind == "lane" or inCentre(mid)
		table.insert(tiles, {
			piece = pieceName(def, yellow), cframe = CFrame.lookAt(mid, mid - axis), scale = scale,
			stretch = each / tileLen, kind = "straight", road = road.name, district = district,
			yellow = yellow, tucked = tucked,
		})
	end
end

local function canDowngrade(nd): boolean
	return (nd.kind == "tee" or nd.kind == "cross") and not nd.downgraded
end

-- A run whose two junction pieces want more road than there is between them.
-- Tolerated: under a big roundabout (the E3 disc hides the overlap), and a bend or
-- head next to a plain dead end (the piece simply runs a little past the end, which
-- only happens on the plot lanes, where it runs into the plot's own entrance).
local function inConflict(run): boolean
	local a, b = run.from.node, run.to.node
	if run.len - run.from.trim - run.to.trim >= -0.5 then
		return false
	end
	if a.kind == "roundabout" or b.kind == "roundabout" then
		return false
	end
	if (a.kind == "end" or b.kind == "end") and not canDowngrade(a) and not canDowngrade(b) then
		return false
	end
	-- A tee or crossroads whose arm runs a few studs past a plain dead end keeps
	-- its piece: downgrading it to a bend swaps a small overshoot for a bend leg
	-- that runs ~38 studs into the plot (Plot 2 Lane, Lane I stage 3).
	if (a.kind == "end" or b.kind == "end") and run.from.trim + run.to.trim - run.len <= RoadTiles.END_OVERSHOOT then
		return false
	end
	return true
end

-- The whole job: roads (and roundabouts) in, tiles and exempt stand-ins out.
function RoadTiles.plan(roads: { RoadIn }, roundabouts: { RoundaboutIn }?, bridges: { BridgeIn }?): Plan
	local nodeList, _ = buildGraph(roads, roundabouts or {})
	local stats: { [string]: number } = { downgraded = 0, shrunk = 0, maxGap = 0, unresolved = 0 }
	for _, node in nodeList do
		classify(node)
	end
	local runs = buildRuns(nodeList)
	for _ = 1, 16 do
		local conflicts = 0
		for _, run in runs do
			local a, b = run.from.node, run.to.node
			if inConflict(run) then
				conflicts += 1
				local pick = nil
				if canDowngrade(a) and canDowngrade(b) then
					pick = if a.scale < b.scale then a else b
				elseif canDowngrade(a) then
					pick = a
				elseif canDowngrade(b) then
					pick = b
				end
				if pick then
					pick.downgraded = true
					stats.downgraded += 1
					classify(pick)
				else
					local total = math.max(run.from.trim, 0) + math.max(run.to.trim, 0)
					local f = math.max(0.4, run.len / total) * 0.999
					for _, nd in { a, b } do
						if (nd.kind == "bend90" or nd.kind == "bend45" or nd.kind == "head") and nd.shrink > 0.3 then
							nd.shrink *= f
							stats.shrunk += 1
							classify(nd)
						end
					end
				end
			end
		end
		if conflicts == 0 then
			break
		end
		runs = buildRuns(nodeList)
		stats.unresolved = conflicts
	end
	-- recount what is still in conflict after the loop
	stats.unresolved = 0
	for _, run in runs do
		if inConflict(run) then
			stats.unresolved += 1
		end
	end

	local tiles: { Tile } = {}
	local exempt: { Exempt } = {}
	for _, node in nodeList do
		emitNode(node, tiles, exempt)
	end
	for _, run in runs do
		emitRun(run, tiles, stats, bridges)
	end
	for _, t in tiles do
		stats[t.kind] = (stats[t.kind] or 0) + 1
		if t.tucked then
			stats.tucked = (stats.tucked or 0) + 1
		end
	end
	stats.tiles = #tiles
	stats.exempt = #exempt
	return { tiles = tiles, exempt = exempt, stats = stats }
end

-- Height of a piece (unscaled), so the assembler can convert a tile's top-centre
-- CFrame into KitPlacer's bottom-centre one.
local heightByName: { [string]: number } = {}
local defByName: { [string]: any } = {}
for _, def in RoadTiles.PIECES do
	heightByName[PREFIX .. def.name] = def.height
	defByName[PREFIX .. def.name] = def
	if def.yellow then
		heightByName[PREFIX .. def.yellow] = def.height
		defByName[PREFIX .. def.yellow] = def
	end
end
function RoadTiles.heightOf(piece: string): number
	return heightByName[piece] or 0.433
end

-- World positions of a tile's connection mouths (ground plane). Used by the tests
-- to prove tiles meet end to end.
function RoadTiles.mouths(tile: Tile): { Vector3 }
	local def = defByName[tile.piece]
	local s = tile.scale
	local out = {}
	local function push(x: number, z: number)
		local p = tile.cframe * Vector3.new(x * s, 0, z * s)
		table.insert(out, Vector3.new(p.X, 0, p.Z))
	end
	if tile.kind == "straight" then
		push(0, -55 * tile.stretch)
		push(0, 55 * tile.stretch)
	elseif tile.kind == "cross" then
		push(55, 0)
		push(-55, 0)
		push(0, 55)
		push(0, -55)
	elseif tile.kind == "tee" then
		push(16.5, 55)
		push(16.5, -55)
		push(-38.5, 0)
	else
		push(def.node[1] + def.dirA[1] * def.legA, def.node[2] + def.dirA[2] * def.legA)
		if def.dirB then
			push(def.node[1] + def.dirB[1] * def.legB, def.node[2] + def.dirB[2] * def.legB)
		end
	end
	return out
end

return RoadTiles
