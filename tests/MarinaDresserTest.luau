--!strict
-- Pure checks for MarinaDresser / RiverDresser.marinaSpan; nothing is built.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarinaDresser = require(ServerScriptService.Server.MarinaDresser)
local RiverDresser = require(ServerScriptService.Server.RiverDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local function marinaBlock(): TownLayout.Box
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use == RiverDresser.MARINA_USE then
				return block
			end
		end
	end
	error("TownLayout should have a marina block")
end

local function getSpan(): RiverDresser.Run
	local span = RiverDresser.marinaSpan()
	assert(span, "the marina block should interrupt the north-bank promenade")
	return span
end

function T.marinaSpanFrontsTheMarinaBlock()
	local span = getSpan()
	local block = marinaBlock()
	local length = (span.b - span.a).Magnitude
	assert(length > 60 and length < 220, ("span length %.1f"):format(length))
	assert(span.normal.Z < 0, "land normal must point north")
	local mid = (span.a + span.b) / 2
	assert(math.abs(mid.X - block.centre.X) < block.size.X / 2 + 20, "span should sit in front of the marina block")
	assert(math.abs(TownLayout.distanceToPolyline(mid, TownLayout.RIVER.points) - RiverDresser.EDGE) < 1.5, "span runs along the water's edge")
	-- the promenade is only interrupted there because of the marina
	assert(not RiverDresser.isClear(mid + span.normal * 8.75), "promenade probe blocked by the marina block")
	assert(RiverDresser.isClear(mid + span.normal * 8.75, 0, RiverDresser.MARINA_USE), "clear once the marina is ignored")
end

function T.isClearRadiusWidensTheClearance()
	local block = marinaBlock()
	-- 4 studs outside the block's x edge: clear of BLOCK_CLEAR (3) alone, not with radius 2
	local p = Vector3.new(block.centre.X + block.size.X / 2 + 4, 0, block.centre.Z)
	assert(RiverDresser.isClear(p, 0, RiverDresser.MARINA_USE) == RiverDresser.isClear(p, 0), "marina not involved at this point")
	if RiverDresser.isClear(p) then
		assert(not RiverDresser.isClear(p, 2), "radius should widen the block clearance")
	end
end

function T.railPiecesLeaveAGapAtEachGangway()
	local length = 128
	local pieces = MarinaDresser.railPieces(length)
	local gangways = MarinaDresser.gangways(length)
	assert(#pieces == #gangways + 1, "one more rail piece than gangways")
	for _, piece in pieces do
		assert(piece[1] < piece[2], "rail piece has positive length")
		assert(piece[1] > 0 and piece[2] < length, "rail stays inside the span")
		for _, g in gangways do
			assert(not (g > piece[1] and g < piece[2]), "a gangway is not railed off")
		end
	end
end

function T.fingersFitTheSpan()
	local fingers = MarinaDresser.fingers(128)
	assert(#fingers >= 6, "expected a row of finger pontoons")
	for i, s in fingers do
		assert(s >= 6 and s <= 122, "finger inside the span")
		if i > 1 then
			assert(s - fingers[i - 1] >= 12, "berths wide enough for a 6-wide boat")
		end
	end
end

function T.gardenClearRejectsPromenadeBridgesBuildingsAndQuay()
	local span = getSpan()
	local f = MarinaDresser.spanFrame(span)
	-- the promenade just west of the marina
	local runs = RiverDresser.bankRuns(-220, 1200, 10)
	local run = runs[1]
	local prom = (run.a + run.b) / 2 + run.normal * 8
	assert(not MarinaDresser.gardenClear(prom, 0, span), "promenade is not garden")
	for _, bridge in TownLayout.BRIDGES do
		assert(not MarinaDresser.gardenClear(bridge.from:Lerp(bridge.to, 0.5), 0, span), bridge.name .. " is not garden")
	end
	local building = TownLayout.DISTRICTS[1].blocks[1]
	assert(not MarinaDresser.gardenClear(building.centre, 0, span), "a building is not garden")
	local apron = f.origin + f.along * (f.length / 2) + f.inward * 20
	assert(not MarinaDresser.gardenClear(apron, 0, span), "the marina apron is not garden")
end

function T.gardenCellsSitClearBehindThePromenade()
	local span = getSpan()
	local cells = MarinaDresser.gardenCells(span)
	assert(#cells >= 10, "expected gardens along the north bank, got " .. #cells)
	local behindMarina = 0
	for _, cell in cells do
		local f = cell.frame
		assert(cell.depth >= 10, "cell too shallow")
		local half = f.length / 2 - 3
		for _, s in { -half, 0, half } do
			for _, t in { cell.start + 2, cell.start + cell.depth } do
				local p = f.origin + f.along * s + f.inward * t
				assert(MarinaDresser.gardenClear(p, 0.5, span), ("garden point (%.0f, %.0f) not clear"):format(p.X, p.Z))
				assert(TownLayout.riverSide(p) < 0, "gardens are on the north bank")
			end
		end
		if cell.start > RiverDresser.QUAY_W + RiverDresser.PROM_W + 10 then
			behindMarina += 1
		end
	end
	assert(behindMarina >= 1, "some gardens should sit behind the marina quay")
end

return T
