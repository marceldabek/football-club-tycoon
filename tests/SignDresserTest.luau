--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local SignDresser = require(game:GetService("ServerScriptService").Server.SignDresser)

local T = {}

local function roadNamed(name: string): TownLayout.Road
	for _, r in TownLayout.ROADS do
		if r.name == name then
			return r
		end
	end
	error("no road " .. name)
end

function T.everyNamedRoadIsAskedAboutOnce()
	local all = SignDresser.unsigned({})
	assert(#all == #TownLayout.ROADS, ("%d of %d roads"):format(#all, #TownLayout.ROADS))
	local seen: { [string]: boolean } = {}
	for _, road in all do
		assert(not seen[road.name], "a road came round twice: " .. road.name)
		seen[road.name] = true
	end
	-- the ones the other passes sign are left alone
	local some = SignDresser.unsigned({ ["Mill Street"] = true, ["Hayfield Close"] = true })
	assert(#some == #all - 2, ("%d, expected %d"):format(#some, #all - 2))
	for _, road in some do
		assert(road.name ~= "Mill Street" and road.name ~= "Hayfield Close", road.name .. " was already signed")
	end
end

function T.aPlateStandsOnThePavementFacingTheRoad()
	for _, name in { "High Street", "Church Lane", "Station Road", "Cherry Close" } do
		local road = roadNamed(name)
		local spots = SignDresser.plateSpots(road, TownLayout.ROADS)
		assert(#spots > 0, name .. " got no plate spot")
		for _, cf in spots do
			local p = cf.Position
			local d = TownLayout.distanceToPolyline(p, road.points)
			assert(d > road.width / 2, ("%s: a plate in the carriageway (%.1f from the middle of a %d-wide road)"):format(name, d, road.width))
			assert(d < road.width / 2 + TownLayout.PAVEMENT_WIDTH + 2, ("%s: a plate %.1f out, off the pavement"):format(name, d))
			-- it faces the traffic: a step along its LookVector gets nearer the road
			local ahead = TownLayout.distanceToPolyline(p + cf.LookVector * 4, road.points)
			assert(ahead < d, ("%s: a plate with its back to the street (%.1f -> %.1f)"):format(name, d, ahead))
		end
	end
end

function T.aRoadOutOfTownStillGetsOne()
	-- Mapleford Road runs off the map and meets nothing at its far end
	local road = roadNamed("Mapleford Road")
	local spots = SignDresser.plateSpots(road, TownLayout.ROADS)
	assert(#spots > 0, "no plate on the way out of town")
end

function T.aFingerpostStandsClearOfEveryCarriageway()
	local found = 0
	for _, roundabout in TownLayout.ROUNDABOUTS do
		local at = SignDresser.fingerSpot(roundabout, TownLayout.ROADS)
		if not at then
			continue
		end
		found += 1
		local gap = (Vector3.new(at.X, 0, at.Z) - roundabout.centre).Magnitude
		assert(gap > roundabout.radius, ("%s: a post on the island"):format(roundabout.name))
		for _, road in TownLayout.ROADS do
			local d = TownLayout.distanceToPolyline(at, road.points)
			assert(d > road.width / 2 + 1, ("%s: a post in %s"):format(roundabout.name, road.name))
		end
		local river = TownLayout.distanceToPolyline(at, TownLayout.RIVER.points)
		assert(river > TownLayout.RIVER.width / 2, ("%s: a post in the Lune"):format(roundabout.name))
	end
	assert(found >= 8, ("only %d of %d roundabouts found room"):format(found, #TownLayout.ROUNDABOUTS))
end

function T.bladesPointAtSomewhereWorthWalkingTo()
	for _, roundabout in TownLayout.ROUNDABOUTS do
		local blades = SignDresser.blades(roundabout)
		assert(#blades >= 1 and #blades <= 3, ("%s: %d blades"):format(roundabout.name, #blades))
		local seen: { [string]: boolean } = {}
		local ground = 0
		for _, b in blades do
			assert(not seen[b.name], roundabout.name .. ": two blades for " .. b.name)
			seen[b.name] = true
			local gap = (Vector3.new(b.position.X, 0, b.position.Z) - roundabout.centre).Magnitude
			if b.name:match("Ground$") then
				ground += 1
			else
				assert(gap >= SignDresser.MIN_BLADE_DISTANCE,
					("%s points at %s, only %.0f studs away"):format(roundabout.name, b.name, gap))
			end
		end
		assert(ground == 1, ("%s: %d grounds"):format(roundabout.name, ground))
	end
end

function T.theNearestGroundIsTheOneItPointsAt()
	for _, roundabout in TownLayout.ROUNDABOUTS do
		local named: string? = nil
		for _, b in SignDresser.blades(roundabout) do
			if b.name:match("Ground$") then
				named = b.name
			end
		end
		local nearest, nearestGap = nil, math.huge
		for _, plot in TownLayout.PLOTS do
			local gap = (Vector3.new(plot.busStop.X, 0, plot.busStop.Z) - roundabout.centre).Magnitude
			if gap < nearestGap then
				nearest, nearestGap = plot.name .. " Ground", gap
			end
		end
		assert(named == nearest, ("%s points at %s, but %s is nearer"):format(roundabout.name, tostring(named), tostring(nearest)))
	end
end

function T.theWholePassStaysInsideItsBudget()
	local plates = 0
	for _, road in SignDresser.unsigned({}) do
		if #SignDresser.plateSpots(road, TownLayout.ROADS) > 0 then
			plates += 1
		end
	end
	-- one plate is three parts; the pass stops at PLATE_BUDGET either way
	local plateParts = math.min(plates * 3, SignDresser.PLATE_BUDGET)
	local postParts = 0
	for _, roundabout in TownLayout.ROUNDABOUTS do
		postParts += 2 + #SignDresser.blades(roundabout) * 2
	end
	assert(plateParts + postParts <= SignDresser.PART_BUDGET,
		("%d plate parts + %d post parts is over the %d budget"):format(plateParts, postParts, SignDresser.PART_BUDGET))
end

return T
