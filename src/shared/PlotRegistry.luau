--!strict
-- Which club plot each connected player owns, on one server. Pure bookkeeping:
-- no Instances, no Players service, no world-building. The server hands out
-- plots as players join and takes them back when they leave; the UI drives
-- which free plot a joining player is previewing before they claim one.
--
-- Browsing a plot does not reserve it (CLAUDE.md s27: 4 plots per server,
-- simplest first version). Two players can preview the same free plot at
-- once; whoever claims it first wins the race and the other caller's claim
-- fails, at which point the caller should move on (e.g. call nextFree again).

local PlotRegistry = {}

export type Registry = {
	claim: (self: Registry, userId: number, plot: number) -> (boolean, string?),
	release: (self: Registry, userId: number) -> number?,
	plotOf: (self: Registry, userId: number) -> number?,
	ownerOf: (self: Registry, plot: number) -> number?,
	freePlots: (self: Registry) -> { number },
	isFull: (self: Registry) -> boolean,
	nextFree: (self: Registry, current: number?, direction: number) -> number?,
	firstFree: (self: Registry) -> number?,
	snapshot: (self: Registry) -> { [number]: number },
}

local DEFAULT_PLOT_COUNT = 4

-- Wraps a (possibly out-of-1..count, including <= 0) plot index back into
-- 1..count. Used so nextFree can step past either end without special-casing.
local function wrap(n: number, count: number): number
	return ((n - 1) % count) + 1
end

function PlotRegistry.new(plotCount: number?): Registry
	local count = plotCount or DEFAULT_PLOT_COUNT

	local owners: { [number]: number } = {} -- plot -> userId
	local plotOfUser: { [number]: number } = {} -- userId -> plot

	local self = {} :: any

	function self:claim(userId: number, plot: number): (boolean, string?)
		if plot < 1 or plot > count then
			return false, "plot out of range"
		end
		local currentOwner = owners[plot]
		if currentOwner == userId then
			return true -- idempotent: claiming the plot you already own
		end
		if currentOwner ~= nil then
			return false, "plot already taken"
		end
		if plotOfUser[userId] ~= nil then
			return false, "already own a plot"
		end
		owners[plot] = userId
		plotOfUser[userId] = plot
		return true
	end

	function self:release(userId: number): number?
		local plot = plotOfUser[userId]
		if not plot then
			return nil
		end
		owners[plot] = nil
		plotOfUser[userId] = nil
		return plot
	end

	function self:plotOf(userId: number): number?
		return plotOfUser[userId]
	end

	function self:ownerOf(plot: number): number?
		return owners[plot]
	end

	function self:freePlots(): { number }
		local free = {}
		for plot = 1, count do
			if owners[plot] == nil then
				table.insert(free, plot)
			end
		end
		return free
	end

	function self:isFull(): boolean
		for plot = 1, count do
			if owners[plot] == nil then
				return false
			end
		end
		return true
	end

	function self:firstFree(): number?
		for plot = 1, count do
			if owners[plot] == nil then
				return plot
			end
		end
		return nil
	end

	-- Cycles over free plots, wrapping past either end. `current` may be nil
	-- (nothing browsed yet: +1 lands on the first free plot, -1 on the last)
	-- or a plot that has since been taken (walks on from where it was).
	function self:nextFree(current: number?, direction: number): number?
		local pos = current or (if direction >= 0 then 0 else 1)
		for _ = 1, count do
			pos = wrap(pos + direction, count)
			if owners[pos] == nil then
				return pos
			end
		end
		return nil
	end

	function self:snapshot(): { [number]: number }
		local copy = {}
		for plot, userId in owners do
			copy[plot] = userId
		end
		return copy
	end

	return self :: Registry
end

return PlotRegistry
