--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local SquareDresser = require(ServerScriptService.Server.SquareDresser)
local TownLayout = require(game:GetService("ReplicatedStorage").Shared.TownLayout)

local T = {}

function T.bladePointsFlatAtTheDestination()
	local from, to = Vector3.new(51, 0, 0), Vector3.new(-740, 0, -355)
	local cf = SquareDresser.bladeFrame(from, to, 9, 6)
	local want = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
	assert((cf.LookVector - want).Magnitude < 1e-4, "points at the destination")
	assert(math.abs(cf.Position.Y - 9) < 1e-6, "at the blade height")
	local startOffset = Vector3.new(cf.Position.X - from.X, 0, cf.Position.Z - from.Z).Magnitude
	assert(math.abs(startOffset - 3.2) < 1e-4, "starts just off the post")
end

function T.fingerPostDestinationsExist()
	for _, name in { "Station", "Riverside", "Lune Bridge", "Church Spire" } do
		assert(SquareDresser.destination(name) ~= nil, name .. " is not a bus stop or landmark")
	end
	assert(SquareDresser.destination("Atlantis") == nil, "unknown names are nil")
end

function T.basketLampsAreTheNearestInRange()
	local centre = Vector3.zero
	local positions = { Vector3.new(300, 0, 0), Vector3.new(50, 0, 0), Vector3.new(0, 0, -20), Vector3.new(0, 5, 100) }
	local picks = SquareDresser.basketLamps(centre, positions, 200, 2)
	assert(#picks == 2 and picks[1] == 3 and picks[2] == 2, "nearest two in range, nearest first")
	assert(#SquareDresser.basketLamps(centre, positions, 200, 10) == 3, "out-of-range lamps are skipped")
	assert(#SquareDresser.basketLamps(centre, {}, 200, 10) == 0, "no lamps")
end

-- X112: the phone box stands on the square's paving clear of the stall,
-- bollard, lamp and finger-post rings' items and of the four road mouths.
function T.phoneBoxStandsClearOnTheSquare()
	local centre = TownLayout.SQUARE.centre
	local box = SquareDresser.ring(centre, SquareDresser.PHONE_BOX_RING, 1, SquareDresser.PHONE_BOX_ANGLE)[1].Position
	assert((box - centre).Magnitude < TownLayout.SQUARE.radius - 4, "on the square")
	local others = {}
	for _, spec in { { 43, 10, math.pi / 10, 6 }, { 57, 24, 0, 2.5 }, { 54, 4, math.pi / 4, 3 }, { 51, 1, 0, 3 } } do
		for _, cf in SquareDresser.ring(centre, spec[1], spec[2], spec[3]) do
			table.insert(others, { cf.Position, spec[4] })
		end
	end
	for _, o in others do
		assert((o[1] - box).Magnitude > o[2] + 2, "phone box crowds something at " .. tostring(o[1]))
	end
	for _, road in TownLayout.ROADS do
		assert(TownLayout.distanceToPolyline(box, road.points) > road.width / 2 + 2, "phone box in " .. road.name)
	end
end

return T
