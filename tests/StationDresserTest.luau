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

return T
