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

export type Ground = { plot: number, phase: string?, position: Vector3 }

-- Which club's match this client should present (I2.1): the player's own
-- while it is in PreMatch/Match, otherwise the nearest other ground within
-- `radius` whose match is live. Returns nil for "own club".
function PlotVisit.spectateTarget(ownPhase: string?, grounds: { Ground }, from: Vector3?, radius: number): number?
	if ownPhase == "PreMatch" or ownPhase == "Match" or from == nil then
		return nil
	end
	local best: number? = nil
	local bestDistance = radius
	for _, g in grounds do
		if g.phase == "Match" then
			local d = (g.position - from).Magnitude
			if d <= bestDistance then
				best, bestDistance = g.plot, d
			end
		end
	end
	return best
end

return PlotVisit
