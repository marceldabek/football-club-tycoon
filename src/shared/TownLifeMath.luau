--!strict
-- Pure maths for TownLife.client.luau (backlog F4.1 wind turbines, square
-- flags and chimney smoke, H1.1 club banners, G2.1 matchday bunting and busy
-- pubs). Kept separate from the LocalScript so the
-- geometry can be unit tested without building anything in the workspace,
-- same split as StreetDresser.stations / MatchdayRoutes.

local TownLifeMath = {}

export type Station = { position: Vector3, direction: Vector3 }
type Scored = { i: number, d: number }

-- Short label for a club banner: the full name if it's short enough to read
-- on a 1.6-stud-wide panel, otherwise its initials (one letter per word,
-- upper-cased). A name with no word characters at all just comes back as-is.
function TownLifeMath.bannerText(clubName: string): string
	if #clubName <= 12 then
		return clubName
	end
	local initials = {}
	for word in clubName:gmatch("%S+") do
		table.insert(initials, word:sub(1, 1):upper())
	end
	if #initials == 0 then
		return clubName
	end
	return table.concat(initials)
end

-- Points along a polyline every `spacing`, starting half a gap in, carrying
-- the remainder across bends -- the same semantics as StreetDresser.stations,
-- reused here so lamp scans and bunting strings land on the same spots a
-- street's lamps do.
function TownLifeMath.stationsAlong(points: { Vector3 }, spacing: number): { Station }
	local out: { Station } = {}
	local carry = spacing / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length < 1e-6 then
			continue
		end
		local dir = flat / length
		local s = carry
		while s <= length do
			table.insert(out, { position = Vector3.new(a.X, 0, a.Z) + dir * s, direction = dir })
			s += spacing
		end
		carry = s - length
	end
	return out
end

-- A wind turbine blade's world CFrame `angle` radians into its spin: `offset`
-- was captured once as the blade's CFrame relative to an unrotated frame at
-- `hub` (offset = CFrame.new(hub):Inverse() * blade.CFrame at build time), so
-- rotating a fresh frame at `hub` about world X and re-applying that offset
-- spins the blade rigidly about the axis through the hub without needing to
-- touch the blade's own orientation each frame.
function TownLifeMath.bladeCFrame(hub: Vector3, offset: CFrame, angle: number): CFrame
	return CFrame.new(hub) * CFrame.Angles(angle, 0, 0) * offset
end

-- ================================================================== flags

-- Flag wave (F4.1a). TEMP look values, tune in Studio.
TownLifeMath.FLAG_AMPLITUDE = 0.22 -- radians of yaw added at each hinge at the peak of the wave
TownLifeMath.FLAG_SPEED = 2.6 -- radians of wave phase per second
TownLifeMath.FLAG_WAVE = 0.9 -- phase lag between successive hinges, so the wave runs outwards

-- `count` points on a circle of `radius` round `centre` (y = centre.Y),
-- starting at angle `offset` radians and evenly spaced.
function TownLifeMath.ringPoints(centre: Vector3, radius: number, count: number, offset: number): { Vector3 }
	local out: { Vector3 } = {}
	for i = 0, count - 1 do
		local a = offset + i * 2 * math.pi / count
		table.insert(out, centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
	end
	return out
end

-- World CFrames of a flag's `count` segments at wave time `t` (seconds plus
-- any per-flag phase). `attach` is the hinge on the pole: its +X is the
-- direction the flag flies, +Y is up, and its position is the middle height
-- of the flag. Each segment is a box `segmentWidth` long along its own X; the
-- chain yaws a little about the vertical at every hinge, so segments stay
-- joined edge to edge and never leave the attach height.
function TownLifeMath.flagSegmentCFrames(attach: CFrame, segmentWidth: number, count: number, t: number): { CFrame }
	local out: { CFrame } = {}
	local hinge = attach
	for i = 1, count do
		local yaw = TownLifeMath.FLAG_AMPLITUDE * math.sin(t * TownLifeMath.FLAG_SPEED - (i - 1) * TownLifeMath.FLAG_WAVE)
		hinge = hinge * CFrame.Angles(0, yaw, 0)
		table.insert(out, hinge * CFrame.new(segmentWidth / 2, 0, 0))
		hinge = hinge * CFrame.new(segmentWidth, 0, 0)
	end
	return out
end

-- ================================================================== smoke

-- A stable pseudo-random bucket for a world position (rounded to whole studs
-- in XZ), so "every Nth chimney" picks the same chimneys whatever order they
-- stream in. Result is in 0..every-1. Every product stays below 2^53, so the
-- float maths is exact.
function TownLifeMath.positionBucket(p: Vector3, every: number): number
	local x = math.floor(p.X + 0.5)
	local z = math.floor(p.Z + 0.5)
	local h = bit32.bxor((x * 73856093) % 4294967296, (z * 19349663) % 4294967296)
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = (h * 1664525 + 1013904223) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h % every
end

-- Indices into `points` of the (at most) `n` points nearest `target` in XZ,
-- nearest first; points further than `radius` (if given) are skipped. Ties
-- keep the input order.
function TownLifeMath.nearestIndices(points: { Vector3 }, target: Vector3, n: number, radius: number?): { number }
	local scored: { Scored } = {}
	for i, p in points do
		local d = Vector3.new(p.X - target.X, 0, p.Z - target.Z).Magnitude
		if radius == nil or d <= radius then
			table.insert(scored, { i = i, d = d })
		end
	end
	table.sort(scored, function(a: Scored, b: Scored): boolean
		if a.d ~= b.d then
			return a.d < b.d
		end
		return a.i < b.i
	end)
	local out: { number } = {}
	for k = 1, math.min(n, #scored) do
		out[k] = scored[k].i
	end
	return out
end

-- Which chimney tops smoke (F4.1b): of the tops in bucket 0 of `every`
-- (about one in `every`) within `radius` of the camera, the `max` nearest.
-- Returns indices into `tops`.
function TownLifeMath.smokeChimneys(tops: { Vector3 }, camPos: Vector3, radius: number, every: number, max: number): { number }
	local candidates: { Vector3 } = {}
	local map: { number } = {}
	for i, p in tops do
		if TownLifeMath.positionBucket(p, every) == 0 then
			table.insert(candidates, p)
			table.insert(map, i)
		end
	end
	local out: { number } = {}
	for k, ci in TownLifeMath.nearestIndices(candidates, camPos, max, radius) do
		out[k] = map[ci]
	end
	return out
end

-- ================================================================ drinkers

TownLifeMath.PAVEMENT_TOP = 0.45 -- TownBuilder.Y.PAVEMENT; forecourt paving is 0.40
TownLifeMath.DRINKER_OUT = 6.4 -- huddle centres this far out from the shopfront face
TownLifeMath.DRINKER_GROUP = 3 -- at most this many to a huddle
TownLifeMath.DRINKER_RADIUS = 1.5 -- huddle radius for 3 (a pair uses 1.1)
TownLifeMath.DRINKER_GROUP_SPACING = 5 -- min distance between huddle centres along the frontage

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Feet CFrames (-Z = facing) for `count` standing drinkers outside a pub.
-- `front` / `frontSize` are a ShopBuilder Shopfront part: its local -X points
-- out of the building, its Z runs along the frontage (Size.Z = bay width) and
-- its bottom sits at the row's ground (y 0, under the pavement, so feet go on
-- PAVEMENT_TOP). Drinkers stand in huddles of up to 3 facing each other,
-- DRINKER_OUT studs out -- past ForecourtDresser's cafe set and A-board (both
-- end <= ~4.3 out) -- on the forecourt or the 8-stud pavement. Huddles spread
-- evenly along the frontage, spilling past it when the bay is too narrow.
-- Deterministic for a given `seed`.
function TownLifeMath.drinkerSpots(front: CFrame, frontSize: Vector3, count: number, seed: number): { CFrame }
	local out: { CFrame } = {}
	if count <= 0 then
		return out
	end
	local outward = flat(front:VectorToWorldSpace(Vector3.new(-1, 0, 0)))
	local along = flat(front:VectorToWorldSpace(Vector3.new(0, 0, 1)))
	if outward.Magnitude < 1e-6 or along.Magnitude < 1e-6 then
		return out
	end
	outward = outward.Unit
	along = along.Unit
	local groundY = math.max(front.Position.Y - frontSize.Y / 2, TownLifeMath.PAVEMENT_TOP)
	local faceCentre = Vector3.new(front.Position.X, groundY, front.Position.Z) + outward * (frontSize.X / 2)
	local rng = Random.new(seed)

	local groups = math.ceil(count / TownLifeMath.DRINKER_GROUP)
	local span = math.max(frontSize.Z * 0.9, groups * TownLifeMath.DRINKER_GROUP_SPACING)
	local placed = 0
	for g = 1, groups do
		local members = math.min(TownLifeMath.DRINKER_GROUP, count - placed)
		local z = ((g - 0.5) / groups - 0.5) * span
		local centre = faceCentre + outward * TownLifeMath.DRINKER_OUT + along * z
		if members == 1 then
			-- a lone drinker faces the pub window
			local pos = centre + along * (rng:NextNumber() - 0.5)
			table.insert(out, CFrame.lookAt(pos, pos - outward))
		else
			local radius = if members == 2 then 1.1 else TownLifeMath.DRINKER_RADIUS
			local a0 = rng:NextNumber() * 2 * math.pi
			for k = 0, members - 1 do
				local a = a0 + k * 2 * math.pi / members
				local pos = centre + (outward * math.cos(a) + along * math.sin(a)) * radius
				table.insert(out, CFrame.lookAt(pos, centre))
			end
		end
		placed += members
	end
	return out
end

-- The cheap standing figure (Pedestrians.client.luau's 6-part style).
TownLifeMath.FIGURE = {
	leg = Vector3.new(0.8, 2.1, 0.8),
	torso = Vector3.new(1.8, 2.0, 0.9),
	arm = Vector3.new(0.45, 1.9, 0.5),
	head = 1.1,
	pint = Vector3.new(0.75, 0.45, 0.45), -- cylinder: X is its length (up once placed)
}
TownLifeMath.PINT_ARM_RAISE = 1.1 -- radians the drinking arm swings forward

-- Part CFrames for a standing figure with feet at `feet` (-Z forward), in the
-- order torso, head, legL, legR, armL, armR. With `pint`, the right arm is
-- raised forward and a 7th CFrame is the upright pint glass in that hand (a
-- cylinder part, so its X axis is turned to point up).
function TownLifeMath.figureCFrames(feet: CFrame, pint: boolean): { CFrame }
	local F = TownLifeMath.FIGURE
	local hipY = F.leg.Y
	local shoulderY = hipY + F.torso.Y - 0.1
	local legX = 0.45
	local armX = F.torso.X / 2 + F.arm.X / 2 + 0.03
	local legHang = CFrame.new(0, -F.leg.Y / 2, 0)
	local armHang = CFrame.new(0, -F.arm.Y / 2 + 0.1, 0)

	local out: { CFrame } = {
		feet * CFrame.new(0, hipY + F.torso.Y / 2, 0),
		feet * CFrame.new(0, hipY + F.torso.Y + F.head / 2, 0),
		feet * CFrame.new(-legX, hipY, 0) * legHang,
		feet * CFrame.new(legX, hipY, 0) * legHang,
		feet * CFrame.new(-armX, shoulderY, 0) * armHang,
	}
	if pint then
		-- CFrame.Angles(+a, 0, 0) swings a hanging arm towards -Z (forward)
		local shoulder = feet * CFrame.new(armX, shoulderY, 0) * CFrame.Angles(TownLifeMath.PINT_ARM_RAISE, 0, 0)
		table.insert(out, shoulder * armHang)
		local hand = shoulder:PointToWorldSpace(Vector3.new(0, -F.arm.Y + 0.1, 0))
		-- the glass stands upright in the hand, turned with the figure rather than the arm
		local glass = feet.Rotation + hand + Vector3.new(0, F.pint.X / 2 - 0.1, 0)
		table.insert(out, glass * CFrame.Angles(0, 0, math.pi / 2))
	else
		table.insert(out, feet * CFrame.new(armX, shoulderY, 0) * armHang)
	end
	return out
end

-- H1.2: how many club murals this client paints in town. None until the club
-- has played MURAL_FIRST_MATCH matches, one after that, a second from tier 2.
TownLifeMath.MURAL_FIRST_MATCH = 3 -- TEMP

function TownLifeMath.muralCount(matchesPlayed: number, tier: number): number
	if matchesPlayed < TownLifeMath.MURAL_FIRST_MATCH then
		return 0
	end
	return if tier >= 2 then 2 else 1
end

-- X90: club scarves hung in the upstairs windows of terraces near the club's
-- ground. One scarf per SCARF_MATCHES matches played, up to SCARF_MAX (TEMP).
TownLifeMath.SCARF_MATCHES = 2
TownLifeMath.SCARF_MAX = 16
function TownLifeMath.scarfCount(matchesPlayed: number): number
	return math.clamp(math.floor(matchesPlayed / TownLifeMath.SCARF_MATCHES), 0, TownLifeMath.SCARF_MAX)
end

-- Pure: where a scarf hangs in house `house` (0-based) of a terrace row, in the
-- row Body's local frame: (z along the row, y from the wall's vertical centre).
-- tools/kit/make_facades.py draws the wide upstairs sash at u 252..362 and v
-- 52..184 of a 512 tile (front_b is mirrored); one tile is one house, and the
-- tiles start at the Body's local -Z end.
function TownLifeMath.scarfSpot(facade: string?, house: number, houseWidth: number, length: number, wallHeight: number): (number, number)
	local u0, u1 = 252 / 512, 362 / 512
	if facade == "front_b" then
		u0, u1 = 1 - u1, 1 - u0
	end
	local z = -length / 2 + (house + (u0 + u1) / 2) * houseWidth
	local v = (52 + 184) / 2 / 512 -- window centre, down from the wall top
	local y = wallHeight / 2 - v * wallHeight
	return z, y
end

-- Pure: which gable end (+1 = the body's local +Z face, -1 = local -Z) of a
-- terrace row faces `target` more, and the outward direction of that face.
function TownLifeMath.gableToward(body: CFrame, target: Vector3): (number, Vector3)
	local z = body.ZVector
	local toTarget = Vector3.new(target.X - body.Position.X, 0, target.Z - body.Position.Z)
	local sign = if toTarget:Dot(Vector3.new(z.X, 0, z.Z)) >= 0 then 1 else -1
	local outward = Vector3.new(z.X, 0, z.Z).Unit * sign
	return sign, outward
end

-- G2.2: how loud a live match sounds from `distance` studs away (0..1). Silent
-- up close (the stadium crowd itself takes over there), loudest a short walk
-- away, fading out across town.
TownLifeMath.CROWD_INSIDE = 220 -- TEMP: MatchAudio / spectating own this range
TownLifeMath.CROWD_PEAK = 420 -- TEMP
TownLifeMath.CROWD_SILENT = 1500 -- TEMP

function TownLifeMath.distantCrowdWeight(distance: number): number
	if distance <= TownLifeMath.CROWD_INSIDE or distance >= TownLifeMath.CROWD_SILENT then
		return 0
	end
	if distance <= TownLifeMath.CROWD_PEAK then
		return (distance - TownLifeMath.CROWD_INSIDE) / (TownLifeMath.CROWD_PEAK - TownLifeMath.CROWD_INSIDE)
	end
	return 1 - (distance - TownLifeMath.CROWD_PEAK) / (TownLifeMath.CROWD_SILENT - TownLifeMath.CROWD_PEAK)
end

-- F3.2: a seated figure for the cafe tables. `seat` is the centre of the seat
-- top with -Z facing the table. Returns CFrames in the order torso, head,
-- thighL, thighR, shinL, shinR, armL, armR, and the part sizes to use.
TownLifeMath.SEATED = {
	thigh = Vector3.new(0.75, 0.7, 1.5),
	shin = Vector3.new(0.75, 1.9, 0.75), -- feet stop 0.05 above the floor under a 1.6-high seat top
}

function TownLifeMath.seatedFigureCFrames(seat: CFrame): { CFrame }
	local F = TownLifeMath.FIGURE
	local S = TownLifeMath.SEATED
	local legX = 0.45
	local armX = F.torso.X / 2 + F.arm.X / 2 + 0.03
	local hipY = S.thigh.Y / 2 + 0.02 -- thighs rest on the seat
	local torsoY = S.thigh.Y + F.torso.Y / 2
	local shoulderY = S.thigh.Y + F.torso.Y - 0.1
	-- knees S.thigh.Z forward of the hip; shins hang from the knees to the floor
	local kneeZ = -S.thigh.Z + 0.35
	local shinY = S.thigh.Y / 2 - S.shin.Y / 2
	-- forearms resting towards the table: arms swung forward from the shoulder
	local armHang = CFrame.new(0, -F.arm.Y / 2 + 0.1, 0)
	return {
		seat * CFrame.new(0, torsoY, 0.2),
		seat * CFrame.new(0, torsoY + F.torso.Y / 2 + F.head / 2, 0.2),
		seat * CFrame.new(-legX, hipY, -S.thigh.Z / 2 + 0.35),
		seat * CFrame.new(legX, hipY, -S.thigh.Z / 2 + 0.35),
		seat * CFrame.new(-legX, shinY, kneeZ),
		seat * CFrame.new(legX, shinY, kneeZ),
		seat * CFrame.new(-armX, shoulderY, 0.2) * CFrame.Angles(0.55, 0, 0) * armHang,
		seat * CFrame.new(armX, shoulderY, 0.2) * CFrame.Angles(0.55, 0, 0) * armHang,
	}
end

return TownLifeMath
