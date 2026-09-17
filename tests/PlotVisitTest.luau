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

return T
