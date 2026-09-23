--!strict
-- #7 (ground plan spec s4): the concourse's catering stands inside the wall,
-- on the ground, clear of the stands, the huts and each other, at every stand
-- level and catering tier; each purchase changes something you can see.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConcourseLayout = require(ReplicatedStorage.Shared.ConcourseLayout)
local StandAccess = require(ReplicatedStorage.Shared.StandAccess)
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

type Rect = ConcourseLayout.Rect

local function overlap(a: Rect, b: Rect, pad: number): boolean
	return a.x0 < b.x1 + pad and b.x0 < a.x1 + pad and a.z0 < b.z1 + pad and b.z0 < a.z1 + pad
end

local function describe(r: Rect): string
	return ("%s x %g..%g z %g..%g"):format(r.name, r.x0, r.x1, r.z0, r.z1)
end

local function levelSets(): { ConcourseLayout.Levels }
	local sets = {}
	for e = 1, 4 do
		for w = 0, 4 do
			for n = 0, 4, 2 do
				for s = 0, 4, 2 do
					table.insert(sets, { East = e, West = w, North = n, South = s })
				end
			end
		end
	end
	for _, n in { 1, 3 } do
		table.insert(sets, { East = 4, West = 4, North = n, South = n })
	end
	return sets
end

-- every catering piece at a tier, as rects
local function catering(levels: ConcourseLayout.Levels, tier: number): { Rect }
	local out: { Rect } = {}
	local van = ConcourseLayout.van(levels, tier)
	if van then
		table.insert(out, van.rect)
	end
	for _, s in ConcourseLayout.loos(levels) do
		table.insert(out, s.rect)
	end
	for _, s in ConcourseLayout.kiosks(levels, tier) do
		table.insert(out, s.rect)
	end
	for _, c in ConcourseLayout.counters(levels, tier) do
		table.insert(out, c.rect)
	end
	local zone = ConcourseLayout.fanZone(tier)
	if zone then
		table.insert(out, zone)
	end
	return out
end

function T.eachPurchaseChangesTheConcourse()
	local levels = { East = 2, West = 0, North = 2, South = 0 }
	local function count(tier: number): number
		return #catering(levels, tier) + #ConcourseLayout.gravel(levels, tier) + #ConcourseLayout.paving(tier)
	end
	assert(ConcourseLayout.van(levels, 0) == nil, "no burger van before the Snack Bar is bought")
	assert(ConcourseLayout.van(levels, 1), "the Snack Bar is the burger van")
	assert(#ConcourseLayout.gravel(levels, 1) > 0 and #ConcourseLayout.paving(1) == 0, "tier 1: a gravel strip on the grass")
	assert(#ConcourseLayout.paving(2) == 4 and #ConcourseLayout.gravel(levels, 2) == 0, "tier 2: paved")
	assert(#ConcourseLayout.kiosks(levels, 2) == 3, "tier 2: a kiosk behind each tier-2 stand (two for the East)")
	assert(ConcourseLayout.fanZone(3) and not ConcourseLayout.fanZone(2), "the fan zone is tier 3's")
	assert(count(1) > count(0) and count(2) > count(1) and count(3) >= count(2), "every tier adds something")
	for level = 0, 3 do
		assert(ConcourseLayout.cateringTier(level) == level, "TEMP A2-Q1: amenity level = catering tier")
	end
end

function T.bigStandsServeFromTheirUndercroftAtTierThree()
	local levels = { East = 4, West = 4, North = 4, South = 3 }
	assert(#ConcourseLayout.kiosks(levels, 3) == 0, "no freestanding kiosks behind covered stands")
	local byKey: { [string]: number } = {}
	for _, c in ConcourseLayout.counters(levels, 3) do
		byKey[c.key] = (byKey[c.key] or 0) + 1
	end
	assert((byKey.East or 0) == 4 and (byKey.North or 0) == 4 and (byKey.South or 0) == 4, "four counters under each big side")
	assert((byKey.West or 0) >= 2, "one or two under each west wing")
	local fewer = #ConcourseLayout.counters(levels, 2)
	assert(fewer > 0 and fewer < #ConcourseLayout.counters(levels, 3), "tier 2 opens fewer")
end

-- Counters sit on the back wall between the roof pillars, clear of every
-- vomitory, and face out of the stand.
function T.countersKeepClearOfVomitoriesAndPillars()
	for level = 3, 4 do
		local levels = { East = level, West = level, North = level, South = level }
		for _, c in ConcourseLayout.counters(levels, 3) do
			for _, o in ConcourseLayout.openings(c.key, level) do
				local along = (o.at - c.at):Dot(c.along)
				assert(math.abs(along) >= ConcourseLayout.COUNTER_LENGTH / 2 + StandAccess.OPENING_W / 2,
					("a %s counter covers a vomitory (%g apart)"):format(c.key, along))
			end
			local out = (c.at - Vector3.new(0, 0, 0)):Dot(c.out)
			assert(out > 100, c.key .. " counter faces out of the ground's middle")
		end
	end
end

-- Nothing on the concourse stands in a stand, a hut, a toilet block, a mast,
-- the clubhouse or another piece of catering, and all of it is inside the wall.
function T.cateringStandsClearOfEverything()
	local W = ConcourseLayout.WALL
	for _, levels in levelSets() do
		for tier = 0, 3 do
			local pieces = catering(levels, tier)
			local fixed: { Rect } = {}
			for _, r in ConcourseLayout.obstacles(levels, tier) do
				local n = r.name
				local mine = n == "BurgerVan" or n == "Portaloo" or n == "FanZone" or string.sub(n, 1, 5) == "Kiosk" or string.sub(n, 1, 7) == "Counter"
				if not mine then
					table.insert(fixed, r)
				end
			end
			for i, p in pieces do
				assert(p.x0 > W.x0 and p.x1 < W.x1 and p.z0 > W.z0 and p.z1 < W.z1, "inside the wall: " .. describe(p))
				for _, r in fixed do
					-- the counters are set into their own stand's back wall
					local ownWall = string.sub(p.name, 1, 7) == "Counter" and r.name == "Stand" .. string.sub(p.name, 8)
					if not ownWall then
						assert(not overlap(p, r, 1), ("%s overlaps %s (tier %d)"):format(describe(p), describe(r), tier))
					end
				end
				for j = i + 1, #pieces do
					-- the portaloos stand in one row, side by side
					local row = p.name == "Portaloo" and pieces[j].name == "Portaloo"
					assert(row or not overlap(p, pieces[j], 1), describe(p) .. " overlaps " .. describe(pieces[j]))
				end
			end
		end
	end
end

function T.theVanMovesOutOfABigWestWing()
	local small = ConcourseLayout.van({ East = 1, West = 2, North = 0, South = 0 }, 1) :: ConcourseLayout.Spot
	assert((small.at - ConcourseLayout.VAN_SPOT).Magnitude < 1e-6, "spec spot while the west wing is small")
	assert(small.face.X < 0, "hatch to the open concourse")
	local big = ConcourseLayout.van({ East = 1, West = 3, North = 0, South = 0 }, 1) :: ConcourseLayout.Spot
	assert((big.at - ConcourseLayout.VAN_SPOT_WEST).Magnitude < 1e-6, "west strip once the wing is a covered stand")
	for _, r in ConcourseLayout.standRects("West", 4) do
		assert(not overlap(big.rect, r, 3), "clear of the biggest west wing")
	end
	local signAt = ConcourseLayout.signSpot({ East = 1, West = 4, North = 0, South = 0 })
	assert((signAt - big.at).Magnitude < 20, "the sign stands by the van")
end

function T.portaloosGoWhenTheToiletBlocksCome()
	assert(#ConcourseLayout.loos({ East = 1, West = 0, North = 0, South = 0 }) == 3, "three portaloos at a grassroots ground")
	assert(#ConcourseLayout.loos({ East = 2, West = 0, North = 0, South = 0 }) == 0, "gone at ground tier 2 (toilet blocks)")
	assert(Config.ToiletsFromTier == 2, "matches GroundEnvelope's toilets")
end

-- The surfaces lie between the pitch-side paving and the wall, never on it.
function T.surfacesStayBetweenTheStandLineAndTheWall()
	local W = ConcourseLayout.WALL
	for _, r in ConcourseLayout.paving(2) do
		assert(r.x0 >= W.x0 and r.x1 <= W.x1 and r.z0 >= W.z0 and r.z1 <= W.z1, "paving inside the wall")
		local onPitchside = r.x0 < 121 - 1e-6 and r.x1 > -121 + 1e-6 and r.z0 < 179 - 1e-6 and r.z1 > -179 + 1e-6
		assert(not onPitchside, "paving over the hardstanding: " .. describe(r))
	end
	for _, levels in levelSets() do
		for _, g in ConcourseLayout.gravel(levels, 1) do
			assert(g.x0 >= W.x0 and g.x1 <= W.x1 and g.z0 >= W.z0 and g.z1 <= W.z1, "gravel inside the wall: " .. describe(g))
			for _, plot in Config.StandPlots do
				for _, s in ConcourseLayout.standRects(plot.key, levels[plot.key]) do
					assert(not overlap(g, s, -0.01), "gravel under a stand: " .. describe(g) .. " / " .. describe(s))
				end
			end
		end
	end
end

-- StandAccess.spans / outward match what WorldBuilder builds (lengths 65 /
-- 204 / 254 / 291 along the sides, wings from the clubhouse gap).
function T.standShapesMatchTheBuiltStands()
	local e4 = StandAccess.spans("East", "Z", 4)[1]
	assert(e4[2] - e4[1] == 291, "covered East stand 291 long")
	local n2 = StandAccess.spans("North", "X", 2)[1]
	assert(n2[2] - n2[1] == 138, "North main stand 138 long")
	local w1 = StandAccess.spans("West", "Z", 1)
	assert(#w1 == 2 and w1[2][1] == 41 and w1[2][2] == 73.5, "west bleacher wing 41..73.5")
	assert(StandAccess.backFace(1) == 10.6 and StandAccess.outward(4) == 0.6 + 48 + 1 + 1.75, "back faces")
end

return T
