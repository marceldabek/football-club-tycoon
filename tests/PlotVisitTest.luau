--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotVisit = require(ReplicatedStorage.Shared.PlotVisit)

local T = {}

function T.plotIndexParsesOnlyPlotNames()
	assert(PlotVisit.plotIndex("Plot1") == 1, "Plot1")
	assert(PlotVisit.plotIndex("Plot12") == 12, "Plot12")
	assert(PlotVisit.plotIndex("Plot") == nil, "no digits")
	assert(PlotVisit.plotIndex("MyPlot2") == nil, "prefix")
	assert(PlotVisit.plotIndex("Plot2b") == nil, "suffix")
end

function T.plotOfWalksUpToPlots()
	local plots = Instance.new("Folder")
	local plot = Instance.new("Model")
	plot.Name = "Plot2"
	plot.Parent = plots
	local club = Instance.new("Model")
	club.Parent = plot
	local part = Instance.new("Part")
	part.Parent = club
	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = part
	assert(PlotVisit.plotOf(prompt, plots) == 2, "nested prompt in Plot2")
	local outside = Instance.new("ProximityPrompt")
	outside.Parent = Instance.new("Part")
	assert(PlotVisit.plotOf(outside, plots) == nil, "not under plots")
	plots:Destroy()
end

function T.hideOnlyOtherPlots()
	assert(PlotVisit.hidePrompt(nil, 1) == false, "town prompts stay")
	assert(PlotVisit.hidePrompt(1, 1) == false, "own plot stays")
	assert(PlotVisit.hidePrompt(2, 1) == true, "other plot hidden")
	assert(PlotVisit.hidePrompt(2, nil) == true, "no plot yet: hidden")
end

function T.spectateNearestLiveMatch()
	local grounds = {
		{ plot = 2, phase = "Match", position = Vector3.new(100, 0, 0) },
		{ plot = 3, phase = "Match", position = Vector3.new(40, 0, 0) },
		{ plot = 4, phase = "Manage", position = Vector3.new(0, 0, 0) },
	}
	assert(PlotVisit.spectateTarget("Manage", grounds, Vector3.zero, 200) == 3, "nearest live")
	assert(PlotVisit.spectateTarget("Manage", grounds, Vector3.zero, 30) == nil, "out of range")
	assert(PlotVisit.spectateTarget("Match", grounds, Vector3.zero, 200) == nil, "own match wins")
	assert(PlotVisit.spectateTarget("PreMatch", grounds, Vector3.zero, 200) == nil, "own prematch wins")
	assert(PlotVisit.spectateTarget("Manage", grounds, nil, 200) == nil, "no character")
	assert(PlotVisit.spectateTarget("Manage", {}, Vector3.zero, 200) == nil, "nobody playing")
end

return T
