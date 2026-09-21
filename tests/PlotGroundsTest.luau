--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local PlotGrounds = require(ServerScriptService.Server.PlotGrounds)

local T = {}

local HALF = 380 -- TownLayout.PLOT_SIZE / 2

type Rect = { name: string, min: Vector2, max: Vector2 }

-- Touching edges count as apart.
local function overlaps(a: Rect, b: Rect): boolean
	return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Y < b.max.Y and b.min.Y < a.max.Y
end

local function describe(r: Rect): string
	return ("%s x %g..%g z %g..%g"):format(r.name, r.min.X, r.max.X, r.min.Y, r.max.Y)
end

-- Hardcoded keep-outs (pitch-local XZ). The stadium one assumes a cautious 4.5
-- studs per stand row (WorldBuilder uses 3) for 16 rows, plus room for roofs
-- and the floodlight masts' reach. The west block is the clubhouse on the west
-- touchline with its two door aprons (Clubhouse.luau: x -169..-121, z -40..46)
-- and the north-west forecourt/turnstiles (x -190..-121).
local ROWS_DEPTH = 16 * 4.5
local KEEP_OUT: { Rect } = {
	{
		name = "Stadium",
		min = Vector2.new(-(Pitch.SIDE_EDGE + ROWS_DEPTH + 20), -(Pitch.END_EDGE + ROWS_DEPTH + 10)),
		max = Vector2.new(Pitch.SIDE_EDGE + ROWS_DEPTH + 10, Pitch.END_EDGE + ROWS_DEPTH + 10),
	},
	{
		name = "WestBlock",
		min = Vector2.new(-(Pitch.SIDE_EDGE + 70), -(Pitch.END_EDGE + 50)),
		max = Vector2.new(-Pitch.SIDE_EDGE, 47),
	},
}

function T.footprintsHaveTheExpectedPieces()
	local names = {}
	for _, r in PlotGrounds.footprints() do
		names[r.name] = true
		assert(r.min.X < r.max.X and r.min.Y < r.max.Y, "degenerate " .. describe(r))
	end
	for _, want in { "CarPark", "SupportersBar", "Kiosk", "ClubShop", "TrainingPitch1", "TrainingPitch2" } do
		assert(names[want], "missing footprint " .. want)
	end
end

function T.footprintsInsidePlot()
	for _, r in PlotGrounds.footprints() do
		assert(r.min.X >= -HALF and r.max.X <= HALF and r.min.Y >= -HALF and r.max.Y <= HALF,
			"outside the plot: " .. describe(r))
	end
end

function T.footprintsDoNotOverlapEachOther()
	local rects = PlotGrounds.footprints()
	for i = 1, #rects do
		for j = i + 1, #rects do
			assert(not overlaps(rects[i], rects[j]), describe(rects[i]) .. " overlaps " .. describe(rects[j]))
		end
	end
end

-- X9: the car park used to be 100 x 300 and ran most of the way down the
-- entrance (-X) side. It must now stay compact (no more than 160 along the
-- entrance side, TEMP limit) and still take the road from the vehicle gate:
-- the gate's z range (60..100, TownLayout.PLOT_LANE_END sits outside it) must
-- land on the car park's west edge, which must be near the wall.
local VEHICLE_GATE_Z0, VEHICLE_GATE_Z1 = 60, 100

local function carPark(): Rect
	for _, r in PlotGrounds.footprints() do
		if r.name == "CarPark" then
			return r
		end
	end
	error("missing footprint CarPark")
end

function T.carParkIsCompactAlongTheEntranceSide()
	local r = carPark()
	local alongEntrance = r.max.Y - r.min.Y
	assert(alongEntrance <= 160, ("car park runs %g along the entrance side (limit 160): %s"):format(alongEntrance, describe(r)))
	assert((r.max.X - r.min.X) * alongEntrance <= 100 * 160, "car park area grew: " .. describe(r))
end

function T.carParkReachableFromVehicleGate()
	local r = carPark()
	assert(r.min.Y <= VEHICLE_GATE_Z0 and r.max.Y >= VEHICLE_GATE_Z1,
		"vehicle gate z 60..100 does not face the car park: " .. describe(r))
	assert(r.min.X >= -HALF and r.min.X <= -HALF + 40, "car park west edge too far from the gate: " .. describe(r))
end

function T.footprintsClearTheStadiumAndWestBlock()
	for _, r in PlotGrounds.footprints() do
		for _, k in KEEP_OUT do
			assert(not overlaps(r, k), describe(r) .. " hits keep-out " .. describe(k))
		end
	end
end

function T.pathsideTreesAndLampsKeepOffThePathAndBuildings()
	local trees, lamps = PlotGrounds.pathsideSpots()
	assert(#trees >= 6 and #lamps >= 2, ("trees %d lamps %d"):format(#trees, #lamps))
	local footprints = PlotGrounds.footprints()
	for _, list in { trees, lamps } do
		for _, p in list do
			assert(math.abs(p.Z - -12) >= 5, "clear of the 8-wide footpath at z " .. p.Z)
			assert(p.X > -370 and p.X < -265, "along the gate leg, inside the wall")
			for _, fp in footprints do
				if fp.name == "Kiosk" then
					continue -- checked separately below: trees may stand beside it
				end
				local inside = p.X >= fp.min.X - 4 and p.X <= fp.max.X + 4 and p.Z >= fp.min.Y - 4 and p.Z <= fp.max.Y + 4
				assert(not inside, "clear of " .. fp.name)
			end
		end
	end
end

function T.kioskStandsBesideTheFootpathClearOfTrees()
	local kiosk
	for _, fp in PlotGrounds.footprints() do
		if fp.name == "Kiosk" then
			kiosk = fp
		end
	end
	assert(kiosk, "kiosk footprint")
	assert(kiosk.min.Y > -12 + 4, "south of the 8-wide footpath at z -12")
	assert(kiosk.min.Y < -12 + 16, "close enough to serve from the path (the south trees stand between)")
	local trees, lamps = PlotGrounds.pathsideSpots()
	for _, list in { trees, lamps } do
		for _, p in list do
			local inside = p.X >= kiosk.min.X - 4 and p.X <= kiosk.max.X + 4 and p.Z >= kiosk.min.Y - 4 and p.Z <= kiosk.max.Y + 4
			assert(not inside, ("a tree or lamp at (%g, %g) stands in the kiosk"):format(p.X, p.Z))
		end
	end
end

-- X95: planted borders inside the entrance wall keep off both gate openings
-- (and their piers), the footpath, the access road and every footprint.
function T.borderBedsKeepClearOfGatesPathAndFootprints()
	local beds = PlotGrounds.borderBeds()
	assert(#beds >= 3, "beds " .. #beds)
	local keepOut: { Rect } = {
		{ name = "PedestrianGate", min = Vector2.new(-HALF, -22), max = Vector2.new(-HALF + 30, -2) },
		{ name = "VehicleGate", min = Vector2.new(-HALF, 58), max = Vector2.new(-HALF + 30, 102) },
		{ name = "Footpath", min = Vector2.new(-HALF, -16), max = Vector2.new(-261, -8) },
		{ name = "WallW", min = Vector2.new(-HALF, -HALF), max = Vector2.new(-HALF + 1, HALF) },
	}
	for _, fp in PlotGrounds.footprints() do
		table.insert(keepOut, fp)
	end
	for _, bed in beds do
		assert(bed.min.X < bed.max.X and bed.min.Y < bed.max.Y, "degenerate " .. describe(bed))
		assert(bed.min.X >= -HALF and bed.min.Y >= -HALF and bed.max.Y <= HALF, "outside the plot: " .. describe(bed))
		for _, k in keepOut do
			assert(not overlaps(bed, k), describe(bed) .. " hits " .. describe(k))
		end
	end
end

-- X97: the supporters' bar stands between the entrance wall's border beds and
-- the path, with its patio stopping short of the footpath.
function T.supportersBarSitsBesideTheGateClearOfTheFootpath()
	local bar
	for _, fp in PlotGrounds.footprints() do
		if fp.name == "SupportersBar" then
			bar = fp
		end
	end
	assert(bar, "bar footprint")
	assert(bar.max.Y < -12 - 4, "north of the 8-wide footpath at z -12")
	assert(bar.min.X > -HALF + 1 + PlotGrounds.BORDER_DEPTH + 0.1, "clear of the border beds inside the wall")
	assert(bar.min.X < -HALF + 40, "near the pedestrian gate")
end

return T
