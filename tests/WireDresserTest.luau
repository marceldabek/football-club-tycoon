--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WireDresser = require(ServerScriptService.Server.WireDresser)
local StreetDresser = require(ServerScriptService.Server.StreetDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local function roadNamed(name: string): TownLayout.Road?
	for _, r in TownLayout.ROADS do
		if r.name == name then
			return r
		end
	end
	return nil
end

function T.everyWiredStreetExistsAndGetsPoles()
	for _, spec in WireDresser.STREETS do
		local road = roadNamed(spec.name)
		assert(road, "no road " .. spec.name)
		assert(spec.side == 1 or spec.side == -1, spec.name .. " side")
		local spots = WireDresser.poleSpots(road, spec.side, StreetDresser.lampPositions(road))
		assert(#spots >= 3, ("%s: only %d pole spots"):format(spec.name, #spots))
	end
end

function T.polesStandInTheKerbSideOfThePavementClearOfJunctionsStopsAndLamps()
	for _, spec in WireDresser.STREETS do
		local road = roadNamed(spec.name) :: TownLayout.Road
		local lamps = StreetDresser.lampPositions(road)
		for _, spot in WireDresser.poleSpots(road, spec.side, lamps) do
			local p = spot.position
			local d = TownLayout.distanceToPolyline(p, road.points)
			assert(math.abs(d - (road.width / 2 + WireDresser.KERB_INSET)) < 0.05, ("%s: pole %.2f from the centre line"):format(spec.name, d))
			for _, other in TownLayout.ROADS do
				if other.name ~= road.name then
					assert(TownLayout.distanceToPolyline(p, other.points) > other.width / 2 + 1, spec.name .. " pole on " .. other.name)
				end
			end
			for _, stop in TownLayout.BUS_STOPS do
				local flat = Vector3.new(stop.position.X, 0, stop.position.Z)
				assert((flat - p).Magnitude >= WireDresser.BUS_STOP_CLEAR, spec.name .. " pole at a bus stop")
			end
			for _, lamp in lamps do
				assert((Vector3.new(lamp.X, 0, lamp.Z) - p).Magnitude >= WireDresser.LAMP_CLEAR, spec.name .. " pole at a lamp")
			end
		end
	end
end

function T.wireHalvesJoinBothEndsAndSag()
	local a, b = Vector3.new(0, 17, 0), Vector3.new(48, 17, 0)
	local halves = WireDresser.wireHalves(a, b, 1)
	assert(#halves == 2, "two halves")
	local ends = {}
	for _, h in halves do
		local cf, length = h[1] :: CFrame, h[2] :: number
		table.insert(ends, cf * Vector3.new(0, 0, length / 2))
		table.insert(ends, cf * Vector3.new(0, 0, -length / 2))
	end
	local function hit(p: Vector3): boolean
		for _, e in ends do
			if (e - p).Magnitude < 1e-3 then
				return true
			end
		end
		return false
	end
	assert(hit(a) and hit(b), "halves reach both poles")
	assert(hit(Vector3.new(24, 16, 0)), "low point mid-span, sag below the ends")
end

return T
