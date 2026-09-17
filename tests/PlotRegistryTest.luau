--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotRegistry = require(ReplicatedStorage.Shared.PlotRegistry)

local T = {}

function T.claimThenPlotOfAndOwnerOfAgree()
	local registry = PlotRegistry.new()
	local ok, err = registry:claim(100, 1)
	assert(ok and err == nil, "claim should succeed")
	assert(registry:plotOf(100) == 1, "plotOf should report the claimed plot")
	assert(registry:ownerOf(1) == 100, "ownerOf should report the owner")
end

function T.doubleClaimByAnotherUserFails()
	local registry = PlotRegistry.new()
	assert(registry:claim(1, 1))
	local ok, err = registry:claim(2, 1)
	assert(not ok and err ~= nil, "second user should not be able to claim a taken plot")
	assert(registry:ownerOf(1) == 1, "original owner should be unchanged")
end

function T.userCannotOwnTwoPlots()
	local registry = PlotRegistry.new()
	assert(registry:claim(1, 1))
	local ok, err = registry:claim(1, 2)
	assert(not ok and err ~= nil, "a user already owning a plot should not claim a different one")
	assert(registry:plotOf(1) == 1, "user should still own only their original plot")
	assert(registry:ownerOf(2) == nil, "second plot should remain free")
end

function T.reclaimingYourOwnPlotIsIdempotent()
	local registry = PlotRegistry.new()
	assert(registry:claim(1, 1))
	local ok, err = registry:claim(1, 1)
	assert(ok and err == nil, "reclaiming your own plot should succeed")
	assert(registry:plotOf(1) == 1, "owner should be unchanged")
end

function T.releaseFreesTheePlotAndReturnsIndex()
	local registry = PlotRegistry.new()
	assert(registry:claim(5, 3))
	local released = registry:release(5)
	assert(released == 3, "release should return the plot that was freed")
	assert(registry:plotOf(5) == nil, "user should no longer own a plot")
	assert(registry:ownerOf(3) == nil, "plot should be free again")
end

function T.releaseOfNonOwnerReturnsNil()
	local registry = PlotRegistry.new()
	assert(registry:release(999) == nil, "releasing a user who owns nothing should return nil")
end

function T.releaseThenReclaimByAnotherUser()
	local registry = PlotRegistry.new()
	assert(registry:claim(1, 1))
	assert(registry:release(1) == 1)
	local ok = registry:claim(2, 1)
	assert(ok, "plot should be claimable again once released")
	assert(registry:ownerOf(1) == 2, "new user should own the plot")
end

function T.freePlotsSortedAscending()
	local registry = PlotRegistry.new()
	assert(registry:claim(1, 3))
	local free = registry:freePlots()
	assert(#free == 3, "expected 3 free plots, got " .. #free)
	assert(free[1] == 1 and free[2] == 2 and free[3] == 4, "free plots should be sorted ascending")
end

function T.isFullAfterFourClaimsAndFifthFails()
	local registry = PlotRegistry.new()
	for userId = 1, 4 do
		assert(registry:claim(userId, userId), "claim " .. userId .. " should succeed")
	end
	assert(registry:isFull(), "registry should be full after 4 claims")
	assert(#registry:freePlots() == 0, "no plots should be free")
	local ok, err = registry:claim(5, 1)
	assert(not ok and err ~= nil, "a 5th claim should fail: every plot is taken")
end

function T.outOfRangeClaimFails()
	local registry = PlotRegistry.new(4)
	local okLow, errLow = registry:claim(1, 0)
	assert(not okLow and errLow ~= nil, "plot 0 is out of range")
	local okHigh, errHigh = registry:claim(1, 5)
	assert(not okHigh and errHigh ~= nil, "plot 5 is out of range for a 4-plot registry")
	assert(registry:plotOf(1) == nil, "failed claims should not register ownership")
end

function T.nextFreeHandlesNilCurrentInBothDirections()
	local registry = PlotRegistry.new(4)
	assert(registry:claim(20, 2)) -- free plots are now 1, 3, 4
	assert(registry:nextFree(nil, 1) == 1, "forward from nothing should land on the first free plot")
	assert(registry:nextFree(nil, -1) == 4, "backward from nothing should land on the last free plot")
end

function T.nextFreeSkipsTakenPlotsAndWraps()
	local registry = PlotRegistry.new(4)
	assert(registry:claim(20, 2)) -- free plots are now 1, 3, 4
	assert(registry:nextFree(1, 1) == 3, "should skip the taken plot 2 going forward")
	assert(registry:nextFree(3, 1) == 4, "should advance to the last free plot")
	assert(registry:nextFree(4, 1) == 1, "forward from the end should wrap around, skipping taken plot 2")
	assert(registry:nextFree(1, -1) == 4, "backward from the start should wrap around, skipping taken plot 2")
	assert(registry:nextFree(4, -1) == 3, "should step back to the previous free plot")
	assert(registry:nextFree(3, -1) == 1, "should skip the taken plot 2 going backward")
end

function T.nextFreeFromACurrentThatIsNowTaken()
	local registry = PlotRegistry.new(4)
	assert(registry:claim(20, 2))
	assert(registry:nextFree(2, 1) == 3, "current itself being taken should still find the nearest free plot forward")
	assert(registry:nextFree(2, -1) == 1, "current itself being taken should still find the nearest free plot backward")
end

function T.nextFreeReturnsNilWhenFull()
	local registry = PlotRegistry.new(4)
	for userId = 1, 4 do
		assert(registry:claim(userId, userId))
	end
	assert(registry:nextFree(nil, 1) == nil, "no free plot to cycle to")
	assert(registry:nextFree(2, -1) == nil, "no free plot to cycle to, even from a taken current")
end

function T.snapshotCopiesCurrentOwners()
	local registry = PlotRegistry.new()
	assert(registry:claim(7, 1))
	assert(registry:claim(8, 4))
	local snap = registry:snapshot()
	assert(snap[1] == 7 and snap[4] == 8, "snapshot should reflect current owners")
	snap[1] = 999 -- mutating the copy must not affect the registry
	assert(registry:ownerOf(1) == 7, "snapshot should be a copy, not a live reference")
end

return T
