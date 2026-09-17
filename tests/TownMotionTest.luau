--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownMotion = require(ReplicatedStorage.Shared.TownMotion)

local T = {}

function T.phaseIsStableAndInRange()
	local p = Vector3.new(120.5, 0, -40.25)
	local a, b = TownMotion.phase(p), TownMotion.phase(p)
	assert(a == b, "same position, same phase")
	assert(a >= 0 and a < math.pi * 2, "in range")
	assert(TownMotion.phase(Vector3.new(0, 0, 0)) ~= TownMotion.phase(Vector3.new(37, 0, 11)), "different trees differ")
end

function T.swayIsSmallFlatAndMoves()
	for _, t in { 0, 0.7, 1.9, 5.3, 40 } do
		local o = TownMotion.swayOffset(t, 1.2)
		assert(o.Y == 0, "flat")
		assert(o.Magnitude <= TownMotion.SWAY_AMPLITUDE + 1e-6, "within amplitude")
	end
	local a = TownMotion.swayOffset(0.3, 0.4)
	local b = TownMotion.swayOffset(1.4, 0.4)
	assert((a - b).Magnitude > 1e-3, "it moves over time")
	assert(TownMotion.swayOffset(2, 0.5, 0).Magnitude == 0, "zero amplitude is still")
end

function T.birdsCircleTheCentreAtHeight()
	local centre = Vector3.new(-220, 0, -240)
	for i = 1, 5 do
		local pos, dir = TownMotion.birdPosition(centre, 90, i, 5, 3.3)
		local flat = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z).Magnitude
		assert(flat >= TownMotion.BIRD_RADIUS - 6.01 and flat <= TownMotion.BIRD_RADIUS + 6.01, "on the ring")
		assert(pos.Y > 85 and pos.Y < 100, "at height")
		assert(math.abs(dir.Magnitude - 1) < 1e-4 and dir.Y == 0, "flat unit heading")
		local radial = Vector3.new(pos.X - centre.X, 0, pos.Z - centre.Z).Unit
		assert(math.abs(dir:Dot(radial)) < 0.2, "flying round, not outwards")
	end
	local p1 = TownMotion.birdPosition(centre, 90, 1, 5, 0)
	local p2 = TownMotion.birdPosition(centre, 90, 1, 5, 2)
	assert((p1 - p2).Magnitude > 1, "birds move")
	assert(math.abs(TownMotion.flap(1.1, 2)) <= 0.5, "flap is bounded")
end

return T
