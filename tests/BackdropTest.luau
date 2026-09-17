--!strict
-- Pure checks for Backdrop.isClear; nothing is built into workspace.
local ServerScriptService = game:GetService("ServerScriptService")
local Backdrop = require(ServerScriptService.Server.Backdrop)

local T = {}

function T.rejectsInsidePlot()
	-- TownLayout.PLOTS[1].centre: dead centre of Plot 1's square, so the
	-- distance to the square is 0 regardless of the plot's yaw.
	assert(not Backdrop.isClear(Vector3.new(1050, 0, 1250), 0), "plot centre should be blocked")
end

function T.rejectsOnRoad()
	-- North Road runs straight down x = 0 from z -60 to z -1050; (0, -500)
	-- sits exactly on its centreline.
	assert(not Backdrop.isClear(Vector3.new(0, 0, -500), 0), "point on North Road should be blocked")
end

function T.rejectsInRiver()
	-- (300, 420) is one of TownLayout.RIVER's own centreline points.
	assert(not Backdrop.isClear(Vector3.new(300, 0, 420), 0), "point on the river centreline should be blocked")
end

function T.rejectsInVerticalSlice()
	-- Centre of Workspace.VerticalSlice's site box (docs/SLICE_PLAN.md: x 2880..3400, z 1820..2180).
	assert(not Backdrop.isClear(Vector3.new(3140, 0, 2000), 0), "VerticalSlice centre should be blocked")
end

function T.acceptsOpenFieldPoint()
	-- (0, 1900): just past the town extent (maxZ = 1700), inside the field
	-- band, and clear of everything isClear checks.
	--   * extent: z 1900 > 1700, so it's outside the extent and the
	--     interior-only-near-the-edge rule doesn't apply.
	--   * plots: nearest is Plot 1 (centre 1050,1250); raw centre distance is
	--     sqrt(1050^2 + 650^2) =~ 1235, and the square's half-diagonal is
	--     380*sqrt(2) =~ 537, so the point is at least ~700 studs clear of
	--     the square no matter how the plot is rotated.
	--   * roads: the closest points on record are Sports Centre Road's
	--     (0, 1200) and Greenbridge Road's (-1100, 1100), both 600-1000+
	--     studs away, far past width/2 + 20.
	--   * river: RIVER.points sit around z 350-450, roughly 1450+ studs away.
	--   * VerticalSlice: its box starts at x 2880, so even though z 1900
	--     falls inside its z-range, the point is 2880 studs away on x alone.
	assert(Backdrop.isClear(Vector3.new(0, 0, 1900), 0), "open field point should be clear")
end

return T
