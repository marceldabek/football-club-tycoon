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

function T.hedgesRingAllFourSidesWithoutFlushEnds()
	local cx, cz, sx, sz, th, overlap = 100, -40, 260, 180, 4, 0.1
	local hedges = Backdrop.hedgeBoxes(cx, cz, sx, sz, th, overlap)
	assert(#hedges == 4, "expected four hedges, got " .. #hedges)
	local sides: { [string]: Backdrop.HedgeBox } = {}
	for _, h in hedges do
		assert(sides[h.side] == nil, "duplicate side " .. h.side)
		sides[h.side] = h
	end
	local n, s, e, w = sides["+Z"], sides["-Z"], sides["+X"], sides["-X"]
	assert(n and s and e and w, "one hedge per side")
	-- each hedge straddles its field edge
	assert(math.abs(n.centre.Z - (cz + sz / 2)) < 1e-4 and math.abs(s.centre.Z - (cz - sz / 2)) < 1e-4, "north/south on the edges")
	assert(math.abs(e.centre.X - (cx + sx / 2)) < 1e-4 and math.abs(w.centre.X - (cx - sx / 2)) < 1e-4, "east/west on the edges")
	-- north/south cover the corners
	assert(math.abs(n.size.X - (sx + th)) < 1e-4 and math.abs(n.size.Z - th) < 1e-4, "north hedge spans the width plus corners")
	-- east/west reach into the north/south hedges by exactly `overlap` (no flush end faces)
	local eMaxZ = e.centre.Z + e.size.Z / 2
	local nMinZ = n.centre.Z - n.size.Z / 2
	assert(math.abs((eMaxZ - nMinZ) - overlap) < 1e-3, ("east hedge overlaps north by %.3f"):format(eMaxZ - nMinZ))
	local eMinZ = e.centre.Z - e.size.Z / 2
	local sMaxZ = s.centre.Z + s.size.Z / 2
	assert(math.abs((sMaxZ - eMinZ) - overlap) < 1e-3, "east hedge overlaps south by the overlap")
end

function T.fieldStylesAreTextureFreeNaturalMaterials()
	local allowed = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true }
	assert(#Backdrop.FIELD_STYLES >= 4, "a varied palette")
	for _, style in Backdrop.FIELD_STYLES do
		assert(allowed[style.material], "field material should be Grass, LeafyGrass or Ground")
	end
end

function T.nearFieldsSitBehindPlotOneWithLanesBetween()
	-- Plot 1's back boundary is z 1195.5 + 380 = 1575.5; the far fields' walls
	-- start no nearer than z 1743.8.
	local rects = Backdrop.nearFieldRects()
	assert(#rects >= 4, "expected a row of fields behind Plot 1, got " .. #rects)
	local behindPlot = 0
	for i, r in rects do
		assert(r.cz - r.sz / 2 >= 1575.5 + 10, "field " .. i .. " starts inside the plot margin")
		assert(r.cz + r.sz / 2 <= 1740, "field " .. i .. " runs into the far fields")
		assert(r.sx >= 60 and r.sz >= 100, "field " .. i .. " is a sliver")
		if r.cx > 670 and r.cx < 1430 then
			behindPlot += 1
		end
		local nextRect = rects[i + 1]
		if nextRect then
			local lane = (nextRect.cx - nextRect.sx / 2) - (r.cx + r.sx / 2)
			assert(lane >= 16 - 1e-6, ("lane after field %d is %.1f wide"):format(i, lane))
		end
	end
	assert(behindPlot >= 2, "fields directly behind the plot, got " .. behindPlot)
end

return T
