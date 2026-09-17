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

return T
