--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local BusService = require(ServerScriptService.Server.BusService)

local T = {}

function T.excludesTheFromStop()
	local list = BusService.destinationsFor("Town Centre", {})
	for _, d in list do
		assert(d.name ~= "Town Centre", "the stop travelled from should not be its own destination")
	end
end

function T.plotStopsAreClubKindOthersAreTown()
	local list = BusService.destinationsFor("Town Centre", {})
	local kinds: { [string]: string } = {}
	for _, d in list do
		kinds[d.name] = d.kind
	end
	assert(kinds["Plot 1"] == "club", "Plot 1 should be a club destination")
	assert(kinds["Plot 4"] == "club", "Plot 4 should be a club destination")
	assert(kinds["Station"] == "town", "Station should be a town destination")
	assert(kinds["Westdale"] == "town", "Westdale should be a town destination")
end

function T.ownedPlotShowsClubNameUnownedShowsForSale()
	local list = BusService.destinationsFor("Town Centre", { [1] = "Rivermere Rovers" })
	local labels: { [string]: string } = {}
	for _, d in list do
		labels[d.name] = d.label
	end
	assert(labels["Plot 1"] == "Rivermere Rovers", "an owned plot should show the club's name")
	assert(labels["Plot 2"] == "Plot 2 (for sale)", "an unowned plot should show as for sale")
end

function T.emptyClubNameCountsAsUnowned()
	local list = BusService.destinationsFor("Town Centre", { [1] = "" })
	for _, d in list do
		if d.name == "Plot 1" then
			assert(d.label == "Plot 1 (for sale)", "an empty club name should be treated as unowned")
		end
	end
end

function T.clubsComeBeforeTownStops()
	local list = BusService.destinationsFor("Town Centre", {})
	local sawTown = false
	for _, d in list do
		if d.kind == "town" then
			sawTown = true
		elseif sawTown then
			error("a club destination appeared after a town destination")
		end
	end
end

function T.eachGroupIsAlphabeticalByLabel()
	local list = BusService.destinationsFor("Town Centre", { [1] = "Zebra FC", [3] = "Athletic Town" })
	local lastByKind: { [string]: string } = {}
	for _, d in list do
		local last = lastByKind[d.kind]
		if last then
			assert(last:lower() <= d.label:lower(), ("%s should sort after %s"):format(d.label, last))
		end
		lastByKind[d.kind] = d.label
	end
end

function T.excludingAClubStopDoesNotAffectOthers()
	local list = BusService.destinationsFor("Plot 1", { [2] = "Athletic Town" })
	local names: { [string]: boolean } = {}
	for _, d in list do
		names[d.name] = true
	end
	assert(names["Plot 1"] == nil, "Plot 1 should be excluded when travelling from it")
	assert(names["Plot 2"] == true, "other plots should still be listed")
	assert(names["Town Centre"] == true, "town stops should still be listed")
end

-- v3: stops live on StreetFurniture's kit shelters
local ROADS = {
	{ name = "A", kind = "main", width = 30, points = { Vector3.new(0, 0, 0), Vector3.new(200, 0, 0) } },
	{ name = "L", kind = "lane", width = 10, points = { Vector3.new(100, 0, 18), Vector3.new(100, 0, 200) } },
} :: any

function T.nearestRoadPointIgnoresLanes()
	local p = BusService.nearestRoadPoint(Vector3.new(101, 0, 20), ROADS)
	assert(p and (p - Vector3.new(101, 0, 0)).Magnitude < 0.01, "expected the point on road A, got " .. tostring(p))
end

function T.travellerArrivesBetweenShelterAndKerbFacingTheShelter()
	local shelter = Vector3.new(100, 0.4, 20)
	local cf = BusService.shelterStand(shelter, ROADS)
	assert(math.abs(cf.Position.X - 100) < 0.01, "stand should be square to the road")
	assert(math.abs(cf.Position.Z - (20 - BusService.SHELTER_STAND)) < 0.01, "stand should be toward the road, got z " .. cf.Position.Z)
	assert(cf.Position.Z > 15, "stand must stay on the pavement, not the carriageway")
	assert(cf.LookVector:Dot(Vector3.new(0, 0, 1)) > 0.99, "traveller should face the shelter")
end

function T.nearestShelterRespectsTheRange()
	local shelters = { Vector3.new(0, 0, 50), Vector3.new(0, 0, 400) }
	local got = BusService.nearestShelter(Vector3.zero, shelters, 300)
	assert(got == shelters[1], "nearest shelter expected")
	assert(BusService.nearestShelter(Vector3.new(0, 0, 1000), shelters, 300) == nil, "out of range should be nil")
end

return T
