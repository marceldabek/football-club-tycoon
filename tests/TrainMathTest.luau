--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrainMath = require(ReplicatedStorage.Shared.TrainMath)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local EPS = 1e-3

-- a straight line: 400 flat, a 100-long span up to a viaduct end, 200 of viaduct, 300 back down
local POINTS = { Vector3.new(0, 0, 0), Vector3.new(400, 0, 0), Vector3.new(500, 0, 0), Vector3.new(700, 0, 0), Vector3.new(1000, 0, 0) }
local BRIDGES: { TownLayout.Bridge } = {
	{ name = "Test Viaduct", kind = "rail", from = Vector3.new(500, 0, 0), to = Vector3.new(700, 0, 0), width = 16 },
}

function T.heightFollowsBedRampsAndDeck()
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, 200) - TrainMath.BED_TOP) < EPS, "flat bed")
	-- the 100-long span is all ramp (shorter than RAMP_MAX)
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, 400) - TrainMath.BED_TOP) < EPS, "ramp foot")
	local mid = (TrainMath.BED_TOP + TrainMath.DECK_TOP) / 2
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, 450) - mid) < EPS, "halfway up the ramp")
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, 600) - TrainMath.DECK_TOP) < EPS, "on the viaduct")
	-- the 300-long span down: RAMP_MAX of ramp then flat
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, 700 + 90) - mid) < EPS, "halfway down")
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, 700 + 250) - TrainMath.BED_TOP) < EPS, "flat after the ramp")
	assert(math.abs(TrainMath.heightAt(POINTS, BRIDGES, -50) - TrainMath.BED_TOP) < EPS, "clamped before the start")
end

function T.carriagesTrailTheHeadOnTheLeftTrack()
	local frames = TrainMath.carriageFrames(POINTS, BRIDGES, 300, 1, 3, 30, 2, 4)
	assert(#frames == 3, "three carriages")
	assert(math.abs(frames[1].Position.X - 285) < EPS, "first centre half a carriage behind the head")
	assert(math.abs(frames[2].Position.X - 253) < EPS, "then one carriage and a gap back")
	assert(frames[1].LookVector.X > 0.99, "facing the direction of travel")
	-- travelling +X, left is -Z
	assert(math.abs(frames[1].Position.Z + 4) < EPS, "on the left-hand track")
	local back = TrainMath.carriageFrames(POINTS, BRIDGES, 300, -1, 1, 30, 2, 4)
	assert(math.abs(back[1].Position.X - 315) < EPS and back[1].LookVector.X < -0.99, "reversed direction trails the other way")
	assert(math.abs(back[1].Position.Z - 4) < EPS, "left of travel going -X is +Z")
	-- on a ramp the carriage pitches up
	local ramp = TrainMath.carriageFrames(POINTS, BRIDGES, 470, 1, 1, 30, 2, 4)
	assert(ramp[1].LookVector.Y > 0.05, "nose up on the ramp")
end

function T.theRealLineHasItsViaduct()
	local found = false
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind == "rail" then
			found = true
		end
	end
	assert(found, "the layout still has a rail bridge")
end

return T
