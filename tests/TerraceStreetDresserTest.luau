--!strict
-- Pure checks for TerraceStreetDresser (backlog X11); nothing is built.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TerraceStreetDresser = require(ServerScriptService.Server.TerraceStreetDresser)
local StreetDresser = require(ServerScriptService.Server.StreetDresser)

local T = {}

local function close(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end

local function road(name: string): TownLayout.Road
	for _, r in TownLayout.ROADS do
		if r.name == name then
			return r
		end
	end
	error("no road " .. name)
end

-- Two synthetic streets far outside town (no bus stops or roundabouts near):
-- A runs +X along z = 3000, B crosses it at x = 150.
local A: TownLayout.Road = { name = "Test A", kind = "residential", width = 20, points = { Vector3.new(0, 0, 3000), Vector3.new(300, 0, 3000) } }
local B: TownLayout.Road = { name = "Test B", kind = "residential", width = 20, points = { Vector3.new(150, 0, 2900), Vector3.new(150, 0, 3100) } }

function T.gateSegmentsCutGapsAndDropSlivers()
	local segs = TerraceStreetDresser.gateSegments(20, { 0 }, 4)
	assert(#segs == 2, "expected 2 segments, got " .. #segs)
	assert(close(segs[1].z0, -10) and close(segs[1].z1, -2), "first segment")
	assert(close(segs[2].z0, 2) and close(segs[2].z1, 10), "second segment")
	-- a gate hanging off the row end leaves no sliver in front of it
	local end_ = TerraceStreetDresser.gateSegments(20, { -9.5 }, 4)
	assert(#end_ == 1 and close(end_[1].z0, -7.5) and close(end_[1].z1, 10), "gate at the end")
end

function T.lightDoorsFollowTheFacadeTexture()
	local a = TerraceStreetDresser.lightDoorZs(128, "front_a")
	assert(#a == 8, "8 houses in a 128 row")
	assert(close(a[1], -64 + 16 * 83 / 512), "front_a door on the left of the bay: " .. a[1])
	assert(close(a[2] - a[1], 16), "one door per bay")
	local b = TerraceStreetDresser.lightDoorZs(128, "front_b")
	assert(close(b[1], -64 + 16 * (1 - 83 / 512)), "front_b door mirrored: " .. b[1])
end

function T.kitGatesSitOnEveryOtherPartyWall()
	local g = TerraceStreetDresser.kitGateZs(130)
	assert(#g == 4, "4 paired gates")
	assert(close(g[1], -48.75) and close(g[2], -16.25) and close(g[3], 16.25) and close(g[4], 48.75), "gate z")
end

function T.millStreetRowsHaveSixStudFrontGardens()
	local mill = road("Mill Street")
	local north = { centre = Vector3.new(100, 12, -164), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" }
	local fr = TerraceStreetDresser.frontage((StreetDresser.rowPlacement(north)), 130, 24, mill)
	assert(fr, "north row fronts Mill Street")
	assert(close(fr.gap, 6), "gap " .. fr.gap)
	assert(fr.cframe:VectorToWorldSpace(Vector3.new(-1, 0, 0)).Z < -0.99, "north row's garden faces -Z (the street)")
	local south = { centre = Vector3.new(100, 12, -236), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" }
	local fr2 = TerraceStreetDresser.frontage((StreetDresser.rowPlacement(south)), 130, 24, mill)
	assert(fr2, "south row fronts Mill Street")
	assert(close(fr2.gap, 6), "south row gap " .. fr2.gap)
	assert(fr2.cframe:VectorToWorldSpace(Vector3.new(-1, 0, 0)).Z > 0.99, "south row's garden faces +Z")
	assert(TerraceStreetDresser.frontage((StreetDresser.rowPlacement(north)), 130, 24, road("Weaver Street")) == nil, "north row does not front Weaver Street")
	-- a row that runs past the street's end is not a frontage
	local overhang = { centre = Vector3.new(860, 11, -164), size = Vector3.new(140, 22, 24), yaw = 0, use = "terraced row" }
	assert(TerraceStreetDresser.frontage(StreetDresser.lightRowPlacement(overhang), 140, 24, mill) == nil, "row past x 900")
end

function T.millStreetMeetsNorthRoadOnly()
	local js = TerraceStreetDresser.junctions(road("Mill Street"), TownLayout.ROADS)
	assert(#js == 1, "expected 1 junction, got " .. #js)
	local j = js[1]
	assert(j.other.name == "North Road", "junction with " .. j.other.name)
	assert((j.point - Vector3.new(0, 0, -200)).Magnitude < 1e-3, "point " .. tostring(j.point))
	assert(#j.dirs == 1 and j.dirs[1].X > 0.99, "Mill Street only leaves the junction eastwards")
	local weaver = TerraceStreetDresser.junctions(road("Weaver Street"), TownLayout.ROADS)
	local crossing = false
	for _, w in weaver do
		if w.other.name == "North Road" then
			crossing = #w.dirs == 2
		end
	end
	assert(crossing, "Weaver Street crosses North Road (two ways out)")
end

function T.signsStandOnTheCornersPastTheMouth()
	local mill = road("Mill Street")
	local spots = TerraceStreetDresser.signSpots(mill, TownLayout.ROADS)
	assert(#spots == 2, "expected 2 Mill Street signs, got " .. #spots)
	local x = 13 + 8 + TerraceStreetDresser.SIGN_GAP + TerraceStreetDresser.plateWidth("MILL STREET") / 2
	for _, cf in spots do
		local p = cf.Position
		assert(close(p.X, x), "sign x " .. p.X)
		assert(close(math.abs(p.Z + 200), 10 + 8 - TerraceStreetDresser.SIGN_BACK), "sign z " .. p.Z)
		assert(cf.LookVector.Z * (p.Z + 200) < 0, "plate faces the carriageway")
		assert(math.abs(cf.RightVector.X) > 0.99, "plate runs along the street")
	end
	-- Church Lane Ts into Weaver Street from +Z: signs only on that side
	local church = 0
	for _, cf in TerraceStreetDresser.signSpots(road("Weaver Street"), TownLayout.ROADS) do
		if math.abs(cf.Position.X + 360) < 40 then
			church += 1
			assert(cf.Position.Z > -330, "sign on the far side of the T at z " .. cf.Position.Z)
		end
	end
	assert(church == 2, "expected 2 signs at Church Lane, got " .. church)
end

function T.treesAvoidLampsAndJunctionMouths()
	local lamp = Vector3.new(50, 0, 3011.4)
	local spots = TerraceStreetDresser.treeSpots(A, 40, nil, { lamp }, { A, B })
	-- stations x = 10, 30, ..., 290; x 130/150/170 are in B's mouth, x 50 hits the lamp
	assert(#spots == 11, "expected 11 trees, got " .. #spots)
	for _, s in spots do
		assert(close(TownLayout.distanceToPolyline(s.position, A.points), 10 + TerraceStreetDresser.TREE_INSET), "tree off the kerb line")
		assert(TownLayout.distanceToPolyline(s.position, B.points) >= 18 + TerraceStreetDresser.JUNCTION_CLEAR, "tree in a junction mouth")
		assert((s.position - lamp).Magnitude >= TerraceStreetDresser.LAMP_CLEAR, "tree on a lamp")
	end
	assert(#TerraceStreetDresser.treeSpots(A, 40, { 0, 100 }, { lamp }, { A, B }) == 4, "x range")
	assert(#TerraceStreetDresser.treeSpots(A, 40, nil, {}, { A, B }, function(p: Vector3): boolean
		return p.X < 100
	end) == 7, "blocked callback")
end

function T.parkedCarsStayOffJunctionMouthsAndEnds()
	local spots = TerraceStreetDresser.carSpots(A, -1, nil, { A, B }, Random.new(7), 3, 22, 0)
	assert(#spots >= 5, "expected some cars, got " .. #spots)
	local lastX = -math.huge
	for _, s in spots do
		local p = s.position
		assert(close(p.Z, 3000 - (10 - 4.2)), "car not in the left kerb lane: " .. p.Z)
		assert(p.X - 6.5 >= 0 and p.X + 6.5 <= 300, "car past the street end at " .. p.X)
		assert(math.abs(p.X - 150) >= 18 + 1 + 6.5 - 1e-3, "car across B's mouth at " .. p.X)
		assert(p.X - lastX >= 13 + 3 - 1e-3, "cars overlap")
		lastX = p.X
	end
end

function T.lampPositionsMatchStreetDresser()
	local lamps = StreetDresser.lampPositions(road("Mill Street"))
	local function has(x: number, z: number): boolean
		for _, p in lamps do
			if close(p.X, x) and close(p.Z, z) then
				return true
			end
		end
		return false
	end
	assert(has(25, -211.4), "first kit lamp (side -1)")
	assert(has(475, -188.6), "light lamp beyond the showpiece (even station)")
	for _, p in lamps do
		assert(not close(p.X, 425), "odd station beyond the showpiece has no lamp")
	end
	local terraces = "Mill Street Terraces"
	assert(StreetDresser.isKitRow(terraces, { centre = Vector3.new(100, 12, -164), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" }), "kit row")
	assert(not StreetDresser.isKitRow(terraces, { centre = Vector3.new(235, 11, -128), size = Vector3.new(110, 22, 24), yaw = 0, use = "terraced row" }), "back row is light")
	assert(not StreetDresser.isKitRow("Northfields", { centre = Vector3.new(100, 12, -164), size = Vector3.new(130, 24, 24), yaw = 0, use = "terraced row" }), "not a kit district")
end

function T.distanceInRangeClipsThePolyline()
	local pts = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
	assert(close(TerraceStreetDresser.distanceInRange(Vector3.new(-50, 0, 0), pts, { 20, 1000 }), 70), "clipped")
	assert(close(TerraceStreetDresser.distanceInRange(Vector3.new(-50, 0, 0), pts, nil), 50), "whole")
	assert(TerraceStreetDresser.distanceInRange(Vector3.new(-50, 0, 0), pts, { 200, 300 }) == math.huge, "empty range")
end

function T.plateWidthGrowsWithTheName()
	assert(TerraceStreetDresser.plateWidth("ASH") == 5, "clamped low")
	assert(TerraceStreetDresser.plateWidth("NORTHFIELDS AVENUE") == 10, "clamped high")
	assert(close(TerraceStreetDresser.plateWidth("MILL STREET"), 1.6 + 0.55 * 11), "mid")
end

return T
