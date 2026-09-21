--!strict
-- Wider pavements for the streets people walk on (register row E4). The kit road
-- piece's own paving is 3.7 studs wide and a townsperson is 4 across the arms, so
-- a strip of plain paving is laid along the back of it, out to
-- RoadTiles.PAVEMENT_OUTER: a 6.9-stud pavement with 2.5 of grass left before the
-- garden fences of a residential street.
--
-- PURE: roads in, a list of boxes out. RoadTiler.buildPavements turns them into
-- Parts. The strips follow RoadPaths (corners rounded like the kit bends), stop
-- at the mouth of every road that crosses or joins (where the kit junction piece
-- has its own rounded corner), short of a turning head's bulb, and are left out
-- (a blunt-ended street, road.closed, also gets a paved apron across its end)
-- on roundabouts, bridges, over the river and inside the Town Centre box (whose
-- whole verge is already paving).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local RoadTiles = require(ReplicatedStorage.Shared.RoadTiles)
local RoadPaths = require(ReplicatedStorage.Shared.RoadPaths)
local PedestrianMath = require(ReplicatedStorage.Shared.PedestrianMath)

local PavingStrips = {}

export type Strip = { cframe: CFrame, size: Vector3, road: string }

PavingStrips.UNDERLAP = 1.2 -- the strip starts this far under the kit paving, so no grass shows between them on a bend
PavingStrips.TUCK = 0.02 -- its top sits this far under the kit paving's (not one plane)
PavingStrips.THICKNESS = 0.3
PavingStrips.CHUNK = 160 -- longest single Part, so a street streams in pieces
PavingStrips.MIN_LENGTH = 2
PavingStrips.JOINT = 0.4 -- each piece runs this far past its ends to close the wedge at a bend's joints

local function scaleOf(kind: string): number
	return RoadTiles.SCALE[kind] or RoadTiles.STREET_SCALE
end

-- Half the gap a `kind` road cuts in a pavement it crosses: out to where its
-- junction piece's rounded corner has finished (a strip laid nearer than that
-- lies on the corner's asphalt). An alley just butts in, so its own width.
local function halfMouth(kind: string): number
	return PedestrianMath.junctionCorner(kind) or RoadTiles.KIT_HALF_WIDTH * RoadTiles.ALLEY_SCALE
end

-- How far short of a `kind` road's centreline a side street's strip stops: clear
-- of the junction piece's corner at a T, and at the back of that road's widened
-- pavement where the two only meet end to end (no junction piece there).
local function endMargin(kind: string, endToEnd: boolean): number
	if kind == "alley" then
		return RoadTiles.KIT_HALF_WIDTH * RoadTiles.ALLEY_SCALE
	end
	if endToEnd then
		return RoadTiles.pavementOuter(kind)
	end
	return math.max(RoadTiles.pavementOuter(kind), PedestrianMath.junctionCorner(kind) :: number)
end

local function inCentre(p: Vector3): boolean
	local c = RoadTiles.CENTRE
	return p.X >= c.minX and p.X <= c.maxX and p.Z >= c.minZ and p.Z <= c.maxZ
end

local function skipped(p: Vector3, roundabouts: { TownLayout.Roundabout }, bridges: { TownLayout.Bridge }, river: TownLayout.River?): boolean
	if inCentre(p) or PedestrianMath.onRoundabout(p, roundabouts) then
		return true
	end
	if PedestrianMath.roadBridgeAt(p, bridges, 12) then
		return true
	end
	return river ~= nil and PedestrianMath.inRiver(p, river, 4)
end

-- `roads` are RoadPaths-style (already filleted); indices must match the list
-- junctions are looked up in, so pass the whole town, not a subset.
function PavingStrips.plan(
	roads: { TownLayout.Road },
	roundabouts: { TownLayout.Roundabout },
	bridges: { TownLayout.Bridge },
	river: TownLayout.River?
): { Strip }
	local out: { Strip } = {}
	for index, road in roads do
		if not PedestrianMath.isWalkableKind(road.kind) or #road.points < 2 then
			continue
		end
		local s = scaleOf(road.kind)
		local inner = RoadTiles.KIT_PAVING_OUTER * s - PavingStrips.UNDERLAP
		local outer = RoadTiles.pavementOuter(road.kind)
		local width = outer - inner
		local top = RoadTiles.SURFACE_Y - PavingStrips.TUCK
		for _, side in { 1, -1 } do
			local path = PedestrianMath.offsetPolyline(road.points, road.width, side, (inner + outer) / 2)
			local cumulative = PedestrianMath.cumulativeLengths(path)
			local length = cumulative[#cumulative] or 0
			local zones = PedestrianMath.junctionZones(path, cumulative, roads, index, halfMouth, endMargin)
			if road.head then
				table.insert(zones, { from = length - RoadTiles.PIECES.head.legA * s, to = length + 1 })
			end
			for i = 1, #path - 1 do
				local a, b = path[i], path[i + 1]
				local segLen = cumulative[i + 1] - cumulative[i]
				if segLen < 1e-3 then
					continue
				end
				local dir = (b - a) / segLen
				-- walk the segment in chunks, keeping the stretches outside every zone
				local pieces = math.max(1, math.ceil(segLen / PavingStrips.CHUNK))
				local step = segLen / pieces
				for k = 0, pieces - 1 do
					local from, to = k * step, (k + 1) * step
					-- trim the chunk's ends out of any zone (a zone inside a chunk splits it at 1-stud steps)
					local runStart: number? = nil
					local function flush(runEnd: number)
						if runStart and runEnd - runStart >= PavingStrips.MIN_LENGTH then
							local mid = a + dir * ((runStart + runEnd) / 2)
							if not skipped(mid, roundabouts, bridges, river) then
								local len = runEnd - runStart + 2 * PavingStrips.JOINT
								local centre = Vector3.new(mid.X, top - PavingStrips.THICKNESS / 2, mid.Z)
								table.insert(out, {
									cframe = CFrame.lookAt(centre, centre + Vector3.new(dir.X, 0, dir.Z)),
									size = Vector3.new(width, PavingStrips.THICKNESS, len),
									road = road.name,
								})
							end
						end
						runStart = nil
					end
					local t = from
					while t < to do
						local nextT = math.min(t + 1, to)
						local blocked = PedestrianMath.inZones(zones, cumulative[i] + (t + nextT) / 2)
						if blocked then
							flush(t)
						elseif not runStart then
							runStart = t
						end
						t = nextT
					end
					flush(to)
				end
			end
		end
		if road.closed then
			-- a blunt end: the kit straight just stops, so pave from it to the garden line
			-- of the terrace across the end, as wide as the two pavements
			local n = #road.points
			local tip = road.points[n]
			local dir = (tip - road.points[n - 1]).Unit
			local depth = road.width / 2 + TownLayout.PAVEMENT_WIDTH
			local mid = tip + dir * (depth / 2)
			if not skipped(mid, roundabouts, bridges, river) then
				local centre = Vector3.new(mid.X, top - PavingStrips.THICKNESS / 2, mid.Z)
				table.insert(out, {
					cframe = CFrame.lookAt(centre, centre + Vector3.new(dir.X, 0, dir.Z)),
					size = Vector3.new(2 * outer, PavingStrips.THICKNESS, depth),
					road = road.name,
				})
			end
		end
	end
	return out
end

-- The town's strips.
function PavingStrips.town(): { Strip }
	return PavingStrips.plan(RoadPaths.townRoads(), TownLayout.ROUNDABOUTS, TownLayout.BRIDGES, TownLayout.RIVER)
end

return PavingStrips
