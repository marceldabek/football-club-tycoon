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
-- and the floodlight masts' reach. The west block is the tunnel, dressing
-- rooms, office and the north-west forecourt/turnstiles.
local ROWS_DEPTH = 16 * 4.5
local KEEP_OUT: { Rect } = {
	{
		name = "Stadium",
		min = Vector2.new(-(Pitch.SIDE_EDGE + ROWS_DEPTH + 20), -(Pitch.END_EDGE + ROWS_DEPTH + 10)),
		max = Vector2.new(Pitch.SIDE_EDGE + ROWS_DEPTH + 10, Pitch.END_EDGE + ROWS_DEPTH + 10),
	},
	{
		name = "WestBlock",
		min = Vector2.new(-(Pitch.SIDE_EDGE + 130), -(Pitch.END_EDGE + 50)),
		max = Vector2.new(-Pitch.SIDE_EDGE, 30),
	},
}

function T.footprintsHaveTheExpectedPieces()
	local names = {}
	for _, r in PlotGrounds.footprints() do
		names[r.name] = true
		assert(r.min.X < r.max.X and r.min.Y < r.max.Y, "degenerate " .. describe(r))
	end
	for _, want in { "CarPark", "ClubShop", "TrainingPitch1", "TrainingPitch2" } do
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

function T.footprintsClearTheStadiumAndWestBlock()
	for _, r in PlotGrounds.footprints() do
		for _, k in KEEP_OUT do
			assert(not overlaps(r, k), describe(r) .. " hits keep-out " .. describe(k))
		end
	end
end

return T
