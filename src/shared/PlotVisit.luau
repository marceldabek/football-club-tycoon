--!strict
-- Which world prompts a client may use. Prompts inside another player's plot
-- (workspace.Plots.PlotN) are hidden on this client, so visitors see those
-- clubs read-only; the server's owner checks stay the real guard (B2.1c).

local PlotVisit = {}

-- "Plot3" -> 3; anything else -> nil.
function PlotVisit.plotIndex(name: string): number?
	local digits = string.match(name, "^Plot(%d+)$")
	return if digits then tonumber(digits) else nil
end

-- The plot index an instance sits in, walking up to workspace.Plots.
function PlotVisit.plotOf(inst: Instance, plots: Instance): number?
	local node: Instance? = inst
	while node and node.Parent ~= plots do
		node = node.Parent
	end
	return if node then PlotVisit.plotIndex(node.Name) else nil
end

-- Hide a prompt unless it is outside any plot or inside the player's own plot.
-- Players with no plot yet (still picking) are visitors everywhere.
function PlotVisit.hidePrompt(promptPlot: number?, ownPlot: unknown): boolean
	if promptPlot == nil then
		return false
	end
	return ownPlot ~= promptPlot
end

return PlotVisit
