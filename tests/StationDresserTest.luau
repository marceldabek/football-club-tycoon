--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StationDresser = require(ServerScriptService.Server.StationDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.frontFacesAwayFromTheRailway()
	local f = StationDresser.frontFrame()
	local station = TownLayout.RAIL.station
	local centre = Vector3.new(station.centre.X, 0, station.centre.Z)
	assert(math.abs((f.Position - centre).Magnitude - station.size.Z / 2) < 0.01, "origin should sit on a long wall")
	local out = f.LookVector * -1 -- +Z of the frame
	local near = TownLayout.distanceToPolyline(f.Position + out * 20, TownLayout.RAIL.points)
	local far = TownLayout.distanceToPolyline(f.Position - out * 20, TownLayout.RAIL.points)
	assert(near > far, "the forecourt should be further from the rails than the building")
end

function T.platformFrameSitsOnTheRearWall()
	local f = StationDresser.frontFrame()
	local size = TownLayout.RAIL.station.size
	local p = StationDresser.platformFrame(f, size)
	assert(math.abs((p.Position - f.Position).Magnitude - size.Z) < 0.01, "rear wall is one depth behind the front")
	assert(p.LookVector:Dot(f.LookVector) < -0.99, "platform frame faces the other way")
	local towardsRails = p.LookVector * -1
	local near = TownLayout.distanceToPolyline(p.Position + towardsRails * 5, TownLayout.RAIL.points)
	local far = TownLayout.distanceToPolyline(p.Position - towardsRails * 5, TownLayout.RAIL.points)
	assert(near < far, "platform +Z should point at the rails")
end

function T.footbridgeClearsTheTracks()
	local f = StationDresser.frontFrame()
	local size = TownLayout.RAIL.station.size
	local p = StationDresser.platformFrame(f, size)
	local x, _, nearZ1, farZ0 = StationDresser.footbridgeExtents(11.5, TownLayout.RAIL.width)
	local near = p * Vector3.new(x, 0, nearZ1)
	local far = p * Vector3.new(x, 0, farZ0)
	local half = TownLayout.RAIL.width / 2
	assert(TownLayout.distanceToPolyline(near, TownLayout.RAIL.points) > half, "near tower sits off the track")
	assert(TownLayout.distanceToPolyline(far, TownLayout.RAIL.points) > half, "far tower sits off the track")
	assert(TownLayout.distanceToPolyline(near:Lerp(far, 0.5), TownLayout.RAIL.points) < half, "the span crosses the line")
end

function T.carParkBaysFitTheBlockAndLeaveTheEntrance()
	local block: TownLayout.Box = { centre = Vector3.new(0, 0.5, 0), size = Vector3.new(120, 1, 60), yaw = 0, use = "station car park" }
	local bays = StationDresser.carParkBays(block, 30)
	assert(#bays > 10, "rows of bays, got " .. #bays)
	for _, bay in bays do
		local p = bay.Position
		assert(math.abs(p.X) + 5.5 <= 60 + 1e-3 and math.abs(p.Z) + 10 <= 30 + 1e-3, "inside the slab")
		assert(math.abs(bay.LookVector.Z) > 0.99 and bay.LookVector.Z * p.Z < 0, "looks out towards the aisle")
		if p.Z > 0 then
			assert(p.X + 5.5 <= 60 - 30 + 1e-3, "near row stays clear of the entrance")
		end
	end
end

function T.farPlatformIsOffTheTrackAndUnderTheFarTower()
	local f = StationDresser.frontFrame()
	local p = StationDresser.platformFrame(f, TownLayout.RAIL.station.size)
	local depth = 11.5
	local z0, z1 = StationDresser.farPlatformZ(depth, TownLayout.RAIL.width)
	local half = TownLayout.RAIL.width / 2
	for _, x in { -100, 0, 100 } do
		assert(TownLayout.distanceToPolyline(p * Vector3.new(x, 0, z0), TownLayout.RAIL.points) >= half, "track-side edge clear of the rail bed at x " .. x)
	end
	local _, _, _, farZ0, farZ1 = StationDresser.footbridgeExtents(depth, TownLayout.RAIL.width)
	assert(farZ0 >= z0 and farZ1 <= z1, "the far stair tower stands on platform 2")
end

local function close(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-3
end

function T.roofWedgesRiseToTheRidge()
	for _, eaveZ in { 1.5, -41.5 } do
		local cf, size = StationDresser.roofWedge(-20, eaveZ, 23, 10.5, 242)
		assert(math.abs(size.Z - 21.5) < 1e-6 and size.Y == 10.5 and size.X == 242, "size (length, rise, run)")
		-- WedgePart: bottom edge at local -Z has no height; top edge at (+h/2, +l/2)
		local h, l = size.Y, size.Z
		assert(close(cf * Vector3.new(0, -h / 2, -l / 2), Vector3.new(0, 23, eaveZ)), "thin edge on the eave")
		assert(close(cf * Vector3.new(0, h / 2, l / 2), Vector3.new(0, 33.5, -20)), "full height at the ridge")
		assert(cf.XVector:Cross(cf.YVector):Dot(cf.ZVector) > 0.99, "right-handed frame")
	end
end

function T.gableWedgesMeetAtTheApex()
	for _, side in { -1, 1 } do
		local cf, size = StationDresser.gableWedge(side, 22, 9.5, 23.3, 0, 2.5)
		local h, l = size.Y, size.Z
		assert(close(cf * Vector3.new(0, -h / 2, l / 2), Vector3.new(0, 23.3, 1.25)), "right angle under the apex")
		assert(close(cf * Vector3.new(0, h / 2, l / 2), Vector3.new(0, 32.8, 1.25)), "apex on the centre line")
		assert(close(cf * Vector3.new(0, -h / 2, -l / 2), Vector3.new(side * 22, 23.3, 1.25)), "low corner at the side")
		assert(close(cf * Vector3.new(size.X / 2, -h / 2, l / 2), Vector3.new(0, 23.3, 1.25 + side * 1.25)), "extruded along z")
		assert(cf.XVector:Cross(cf.YVector):Dot(cf.ZVector) > 0.99, "right-handed frame")
	end
end

function T.forecourtReachStopsAtARoadPavement()
	local f = StationDresser.frontFrame()
	local nearRoad = false
	for x = -120, 112, 8 do
		local reach = StationDresser.forecourtReach(f, x + 4, 22, 70, 1)
		assert(reach >= 22 and reach <= 70, "reach stays in range at x " .. x)
		if reach < 70 then
			nearRoad = true
			local p = f * Vector3.new(x + 4, 0, reach)
			local onPavement = false
			for _, road in TownLayout.ROADS do
				if TownLayout.distanceToPolyline(p, road.points) <= road.width / 2 + TownLayout.PAVEMENT_WIDTH then
					onPavement = true
				end
			end
			assert(onPavement, "reach ends on a road's pavement at x " .. x)
		end
	end
	assert(nearRoad, "Station Road should come within reach of the front")
	-- nowhere near a road: the whole run is grass
	assert(StationDresser.forecourtReach(CFrame.new(99999, 0, 99999), 0, 22, 70, 1) == 70, "no road -> zMax")
end

function T.laybyMeetsTheForecourtAndOpensOntoStationRoad()
	local f = StationDresser.frontFrame()
	local l = StationDresser.laybyLocal(f)
	assert(math.abs(l.z0 - 22) < 1e-3, "inner edge on the forecourt edge (local z 22), got " .. l.z0)
	assert(l.x1 - l.x0 > 60, "long enough for two taxis and a free bay")
	local road
	for _, r in TownLayout.ROADS do
		if r.name == "Station Road" then
			road = r
		end
	end
	assert(road, "Station Road exists")
	-- along the lay-by, its outer edge sits on the carriageway edge: no pavement between
	for x = l.x0, l.x1, 8 do
		local outer = f * Vector3.new(x, 0, l.z1)
		local d = TownLayout.distanceToPolyline(outer, road.points)
		assert(math.abs(d - road.width / 2) < 0.5, ("outer edge %.2f from the centreline at local x %d"):format(d, x))
		local inner = f * Vector3.new(x, 0, l.z0)
		assert(TownLayout.distanceToPolyline(inner, road.points) > road.width / 2, "the lay-by itself is off the carriageway")
	end
end

function T.busBayIsOnTheCarriagewayInFrontOfTheStationStop()
	local f = StationDresser.frontFrame()
	local bay = StationDresser.busBay(f)
	assert(bay, "the Station stop exists")
	local road
	for _, r in TownLayout.ROADS do
		if r.name == "Station Road" then
			road = r
		end
	end
	assert(road, "Station Road")
	for _, corner in { Vector3.new(bay.x0, 0, bay.z0), Vector3.new(bay.x1, 0, bay.z0), Vector3.new(bay.x0, 0, bay.z1), Vector3.new(bay.x1, 0, bay.z1) } do
		local d = TownLayout.distanceToPolyline(f * corner, road.points)
		assert(d < road.width / 2, ("bay corner %.2f from the centreline, off the carriageway"):format(d))
	end
	for _, stop in TownLayout.BUS_STOPS do
		if stop.name == "Station" then
			local p = f:PointToObjectSpace(stop.position)
			assert(math.abs((bay.x0 + bay.x1) / 2 - p.X) < 1e-3, "centred on the stop")
		end
	end
end

function T.yellowLinesRunInsideTheKerbsAndSkipTheBayAndLayby()
	local f = StationDresser.frontFrame()
	local layby = StationDresser.laybyLocal(f)
	local bay = StationDresser.busBay(f)
	local runs = StationDresser.yellowLineRuns(f, layby, bay)
	assert(#runs >= 2, "a far-side run and at least one station-side run")
	local road
	for _, r in TownLayout.ROADS do
		if r.name == "Station Road" then
			road = r
		end
	end
	for _, run in runs do
		assert(run.x1 - run.x0 >= 2, "no stubs")
		for _, offset in { 0.35, 0.85 } do
			local mid = f * Vector3.new((run.x0 + run.x1) / 2, 0, run.kerb + run.inward * offset)
			local d = TownLayout.distanceToPolyline(mid, road.points)
			assert(d < road.width / 2 and d > road.width / 2 - 1.2, ("line %.2f from the centreline, not just inside the kerb"):format(d))
		end
		if run.inward == 1 then
			for _, gap in { { layby.x0, layby.x1 }, { bay.x0, bay.x1 } } do
				assert(run.x1 <= gap[1] + 1e-3 or run.x0 >= gap[2] - 1e-3, "station-side run crosses the bay or lay-by")
			end
		end
	end
end

-- X73: the raised terrace beside the building keeps off every road and its
-- pavements, and off the railway.
function T.platformTerraceKeepsOffRoadsAndTheRailway()
	local f = StationDresser.frontFrame()
	local station = TownLayout.RAIL.station
	local x0, x1, z0, z1 = StationDresser.terraceExtents(station.size)
	assert(x0 > station.size.X / 2 and x1 > x0 and z0 < z1 and z1 < 0, "terrace sits beside the building, behind the front line")
	-- the steps stand out in front of the wall line
	for x = x0, x1, 5 do
		for z = z0, z1 + 0.2 + StationDresser.TERRACE_STAIR_DEPTH, 5 do
			local p = f * Vector3.new(x, 0, z)
			for _, road in TownLayout.ROADS do
				local clear = road.width / 2 + TownLayout.PAVEMENT_WIDTH
				assert(TownLayout.distanceToPolyline(p, road.points) > clear, ("terrace (%g, %g) is on %s"):format(x, z, road.name))
			end
			assert(TownLayout.distanceToPolyline(p, TownLayout.RAIL.points) > TownLayout.RAIL.width / 2 + 1, "terrace on the railway")
		end
	end
end

-- X152: the recycling point takes the westmost near-row bay (not the entrance end)
function T.recyclingPointTakesTheWestNearBay()
	local block = { centre = Vector3.new(-1000, 0.5, -350), size = Vector3.new(120, 1, 60), yaw = 0, use = "station car park" } :: any
	local bays = StationDresser.carParkBays(block, 30)
	local i = StationDresser.recyclingBay(bays)
	assert(i, "a recycling bay")
	local bay = bays[i :: number]
	assert(bay.LookVector.Z < 0, "near row")
	for _, other in bays do
		if other.LookVector.Z < 0 then
			assert(other.X >= bay.X, "westmost of the near row")
		end
	end
	assert(bay.X < block.centre.X, "away from the +X entrance")
end

return T
