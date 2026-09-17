--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLifeMath = require(ReplicatedStorage.Shared.TownLifeMath)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

local EPS = 1e-4

function T.bannerTextKeepsNamesAt12CharsOrLess()
	assert(TownLifeMath.bannerText("Rivermere FC") == "Rivermere FC", "12-char name should be kept whole")
	assert(TownLifeMath.bannerText("Your Club") == "Your Club", "short name should be kept whole")
end

function T.bannerTextAbbreviatesLongerNames()
	assert(TownLifeMath.bannerText("Bramblewick Rovers") == "BR", "expected initials BR")
	assert(TownLifeMath.bannerText("Oakhollow United") == "OU", "expected initials OU")
end

function T.bannerTextHandlesASingleLongWord()
	assert(TownLifeMath.bannerText("Superlongclubname") == "S", "single-word initials should be its first letter")
end

function T.stationsAlongMatchesStreetDresserSemantics()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100) }
	local st = TownLifeMath.stationsAlong(points, 40)
	assert(#st == 5, "expected 5 stations, got " .. #st)
	assert((st[1].position - Vector3.new(20, 0, 0)).Magnitude < EPS, "first station")
	assert((st[3].position - Vector3.new(100, 0, 0)).Magnitude < EPS, "third station at the corner")
	assert((st[4].position - Vector3.new(100, 0, 40)).Magnitude < EPS, "fourth station on the second leg")
	assert(st[4].direction.Z > 0.99, "direction follows the second leg")
end

function T.stationsAlongSkipsZeroLengthSegments()
	local points = { Vector3.new(0, 0, 0), Vector3.new(0, 5, 0), Vector3.new(60, 0, 0) }
	local st = TownLifeMath.stationsAlong(points, 60)
	assert(#st == 1, "expected the degenerate first segment to be skipped, got " .. #st)
	assert((st[1].position - Vector3.new(30, 0, 0)).Magnitude < EPS, "station " .. tostring(st[1].position))
end

function T.bladeCFrameRotatesAboutWorldXThroughTheHub()
	local hub = Vector3.new(5, 0, 0)
	local offset = CFrame.new(0, 10, 0)
	-- rotating (0, 10, 0) a quarter turn about X sends it to (0, 0, 10)
	local cf = TownLifeMath.bladeCFrame(hub, offset, math.pi / 2)
	assert((cf.Position - Vector3.new(5, 0, 10)).Magnitude < EPS, "position " .. tostring(cf.Position))
end

function T.bladeCFrameAtZeroAngleIsJustTheOffsetAtTheHub()
	local hub = Vector3.new(2, 0, 0)
	local offset = CFrame.new(1, 0, 0)
	local cf = TownLifeMath.bladeCFrame(hub, offset, 0)
	assert((cf.Position - Vector3.new(3, 0, 0)).Magnitude < EPS, "position " .. tostring(cf.Position))
end

-- ------------------------------------------------------------------ flags

function T.ringPointsSitOnTheCircle()
	local centre = Vector3.new(10, 0.25, -5)
	local pts = TownLifeMath.ringPoints(centre, 52, 4, math.pi / 8)
	assert(#pts == 4, "expected 4 points, got " .. #pts)
	for _, p in pts do
		assert(math.abs((p - centre).Magnitude - 52) < EPS, "radius " .. tostring((p - centre).Magnitude))
		assert(math.abs(p.Y - 0.25) < EPS, "keeps the centre height")
	end
	assert((pts[1] - pts[3]).Magnitude > 103.9, "opposite points are a diameter apart")
end

local function flagChainChecks(t: number)
	local attach = CFrame.fromMatrix(Vector3.new(3, 22, 7), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
	local w = 1.8
	local segs = TownLifeMath.flagSegmentCFrames(attach, w, 3, t)
	assert(#segs == 3, "expected 3 segments, got " .. #segs)
	local inner = segs[1]:PointToWorldSpace(Vector3.new(-w / 2, 0, 0))
	assert((inner - attach.Position).Magnitude < EPS, "first segment starts at the pole, t=" .. t)
	for i = 1, #segs do
		assert(math.abs(segs[i].Position.Y - 22) < EPS, "segment stays at attach height")
		assert(math.abs(segs[i].UpVector.Y - 1) < EPS, "segment stays upright")
		if i < #segs then
			local outer = segs[i]:PointToWorldSpace(Vector3.new(w / 2, 0, 0))
			local nextInner = segs[i + 1]:PointToWorldSpace(Vector3.new(-w / 2, 0, 0))
			assert((outer - nextInner).Magnitude < EPS, "segments joined edge to edge at hinge " .. i)
		end
	end
	-- the flag flies roughly along attach +X (world +Z here): the wave never folds it back
	local tip = segs[#segs]:PointToWorldSpace(Vector3.new(w / 2, 0, 0))
	assert(tip.Z - 7 > 3 * w * 0.8, "tip reach " .. tostring(tip.Z - 7))
end

function T.flagSegmentsStayJoinedThroughTheWave()
	for _, t in { 0, 0.3, 1.1, 2.7, 10 } do
		flagChainChecks(t)
	end
end

function T.flagSegmentsActuallyMove()
	local attach = CFrame.new(0, 20, 0)
	local a = TownLifeMath.flagSegmentCFrames(attach, 2, 3, 0)
	local b = TownLifeMath.flagSegmentCFrames(attach, 2, 3, 0.6)
	assert((a[3].Position - b[3].Position).Magnitude > 0.05, "outer segment should move over time")
end

-- ------------------------------------------------------------------ smoke

function T.positionBucketIsStableAndInRange()
	local p = Vector3.new(-812.4, 30, 455.6)
	local b = TownLifeMath.positionBucket(p, 8)
	assert(b >= 0 and b < 8 and b == math.floor(b), "bucket in 0..7, got " .. b)
	assert(TownLifeMath.positionBucket(Vector3.new(-812.1, 12, 455.9), 8) == b, "same stud -> same bucket")
end

function T.positionBucketPicksAboutOneInEight()
	-- a terrace-like grid of stacks 9 studs apart
	local zero = 0
	local total = 0
	for x = -20, 19 do
		for z = -20, 19 do
			total += 1
			if TownLifeMath.positionBucket(Vector3.new(x * 9 + 0.3, 0, z * 42), 8) == 0 then
				zero += 1
			end
		end
	end
	local share = zero / total
	assert(share > 0.08 and share < 0.17, "share in bucket 0: " .. share)
end

function T.nearestIndicesSortsAndFilters()
	local pts = { Vector3.new(10, 0, 0), Vector3.new(3, 99, 0), Vector3.new(500, 0, 0), Vector3.new(0, 0, -5) }
	local got = TownLifeMath.nearestIndices(pts, Vector3.zero, 3, 100)
	assert(#got == 3, "expected 3, got " .. #got)
	assert(got[1] == 2 and got[2] == 4 and got[3] == 1, "order " .. table.concat(got, ","))
	local capped = TownLifeMath.nearestIndices(pts, Vector3.zero, 2)
	assert(#capped == 2 and capped[1] == 2, "n caps the result")
end

function T.smokeChimneysRespectsBucketRadiusAndMax()
	local tops: { Vector3 } = {}
	for i = 0, 399 do
		table.insert(tops, Vector3.new((i % 20) * 9, 30, math.floor(i / 20) * 40))
	end
	local cam = Vector3.new(90, 40, 400)
	local picked = TownLifeMath.smokeChimneys(tops, cam, 300, 8, 12)
	assert(#picked > 0 and #picked <= 12, "picked " .. #picked)
	local lastD = -1
	for _, i in picked do
		local p = tops[i]
		assert(TownLifeMath.positionBucket(p, 8) == 0, "only bucket-0 chimneys smoke")
		local d = Vector3.new(p.X - cam.X, 0, p.Z - cam.Z).Magnitude
		assert(d <= 300, "within radius")
		assert(d >= lastD, "nearest first")
		lastD = d
	end
	assert(#TownLifeMath.smokeChimneys(tops, Vector3.new(5000, 0, 5000), 300, 8, 12) == 0, "none when far away")
end

-- --------------------------------------------------------------- drinkers

-- A Shopfront like ShopBuilder's: row frame yawed, part at (frontX, g/2, z), front = local -X.
local function pubFront(): (CFrame, Vector3)
	local row = CFrame.new(200, 0, -80) * CFrame.Angles(0, math.rad(35), 0)
	local g = 11
	return row * CFrame.new(-9.1, g / 2, 4), Vector3.new(0.2, g, 12)
end

function T.drinkerSpotsStandOutsideThePubOnThePavement()
	local front, size = pubFront()
	for _, count in { 1, 2, 3, 5, 10 } do
		local spots = TownLifeMath.drinkerSpots(front, size, count, 42)
		assert(#spots == count, ("count %d -> %d spots"):format(count, #spots))
		for _, cf in spots do
			local lp = front:PointToObjectSpace(cf.Position)
			local out = -lp.X - size.X / 2
			assert(out > 4.4 and out < 8.5, "distance out of the front " .. out)
			assert(math.abs(cf.Position.Y - TownLifeMath.PAVEMENT_TOP) < EPS, "feet on the pavement, y " .. cf.Position.Y)
			assert(math.abs(cf.LookVector.Y) < EPS, "stands upright")
			assert(math.abs(lp.Z) < math.max(size.Z * 0.45, count / 3 * 2.5) + 2, "near the frontage, z " .. lp.Z)
		end
	end
end

function T.drinkerSpotsDoNotOverlap()
	local front, size = pubFront()
	for seed = 1, 20 do
		local spots = TownLifeMath.drinkerSpots(front, size, 5, seed)
		for i = 1, #spots do
			for j = i + 1, #spots do
				local d = (spots[i].Position - spots[j].Position).Magnitude
				assert(d >= 1.9, ("seed %d: drinkers %d and %d only %.2f apart"):format(seed, i, j, d))
			end
		end
	end
end

function T.drinkerSpotsHuddleFacesInwards()
	local front, size = pubFront()
	local spots = TownLifeMath.drinkerSpots(front, size, 3, 7)
	local centre = (spots[1].Position + spots[2].Position + spots[3].Position) / 3
	for _, cf in spots do
		local toCentre = (centre - cf.Position).Unit
		assert(cf.LookVector:Dot(toCentre) > 0.99, "faces the huddle centre")
	end
end

function T.drinkerSpotsAreDeterministic()
	local front, size = pubFront()
	local a = TownLifeMath.drinkerSpots(front, size, 5, 99)
	local b = TownLifeMath.drinkerSpots(front, size, 5, 99)
	for i = 1, #a do
		assert((a[i].Position - b[i].Position).Magnitude < EPS, "same seed, same spot")
	end
	assert(#TownLifeMath.drinkerSpots(front, size, 0, 1) == 0, "zero drinkers")
end

function T.figureCFramesStackFromTheFeet()
	local feet = CFrame.new(5, 0.45, 5) * CFrame.Angles(0, 1, 0)
	local plain = TownLifeMath.figureCFrames(feet, false)
	assert(#plain == 6, "6 parts without a pint")
	local F = TownLifeMath.FIGURE
	for _, i in { 3, 4 } do
		local bottom = plain[i].Position.Y - F.leg.Y / 2
		assert(math.abs(bottom - 0.45) < EPS, "legs reach the ground")
	end
	assert(plain[2].Position.Y > plain[1].Position.Y, "head above torso")

	local drinking = TownLifeMath.figureCFrames(feet, true)
	assert(#drinking == 7, "7 parts with a pint")
	local glass = feet:PointToObjectSpace(drinking[7].Position)
	assert(glass.Z < -1, "pint held out in front, z " .. glass.Z)
	assert(glass.Y > F.leg.Y and glass.Y < F.leg.Y + F.torso.Y + F.head, "pint at chest height, y " .. glass.Y)
	assert(math.abs(drinking[7].RightVector.Y) > 0.99, "glass stands upright (cylinder X up)")
	-- raised arm's far end is the hand, right under the glass
	local armTip = drinking[6]:PointToWorldSpace(Vector3.new(0, -F.arm.Y / 2, 0))
	local flatGap = Vector3.new(armTip.X - drinking[7].Position.X, 0, armTip.Z - drinking[7].Position.Z).Magnitude
	assert(flatGap < 0.3, "glass sits over the hand, gap " .. flatGap)
end

function T.muralCountFollowsProgress()
	local first = TownLifeMath.MURAL_FIRST_MATCH
	assert(TownLifeMath.muralCount(0, 1) == 0, "brand new club")
	assert(TownLifeMath.muralCount(first - 1, 3) == 0, "not enough matches even at a high tier")
	assert(TownLifeMath.muralCount(first, 1) == 1, "one mural once established")
	assert(TownLifeMath.muralCount(first + 10, 2) == 2, "second mural from tier 2")
end

function T.gableTowardPicksTheEndFacingTheTarget()
	local body = CFrame.new(100, 10, -160) -- length along world Z
	local s1, out1 = TownLifeMath.gableToward(body, Vector3.new(100, 0, 0))
	assert(s1 == 1 and (out1 - Vector3.new(0, 0, 1)).Magnitude < 1e-6, "target to +Z")
	local s2, out2 = TownLifeMath.gableToward(body, Vector3.new(100, 0, -400))
	assert(s2 == -1 and (out2 - Vector3.new(0, 0, -1)).Magnitude < 1e-6, "target to -Z")
	local turned = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0) -- local Z now along world +X
	local s3, out3 = TownLifeMath.gableToward(turned, Vector3.new(-50, 0, 0))
	assert(s3 == -1 and out3.X < -0.99, "turned body: the -Z end faces -X")
end

function T.distantCrowdRisesThenFadesAcrossTown()
	local M = TownLifeMath
	assert(M.distantCrowdWeight(0) == 0 and M.distantCrowdWeight(M.CROWD_INSIDE) == 0, "silent inside the ground")
	assert(M.distantCrowdWeight(M.CROWD_PEAK) == 1, "loudest at the peak")
	assert(M.distantCrowdWeight(M.CROWD_SILENT) == 0 and M.distantCrowdWeight(5000) == 0, "silent far away")
	local rising = M.distantCrowdWeight((M.CROWD_INSIDE + M.CROWD_PEAK) / 2)
	local falling = M.distantCrowdWeight((M.CROWD_PEAK + M.CROWD_SILENT) / 2)
	assert(math.abs(rising - 0.5) < 1e-6 and math.abs(falling - 0.5) < 1e-6, "linear ramps")
end

function T.seatedFigureSitsFacingForward()
	local seatTop = 1.6
	local seat = CFrame.new(10, seatTop, 20)
	local cfs = TownLifeMath.seatedFigureCFrames(seat)
	assert(#cfs == 8, "eight parts")
	local F, S = TownLifeMath.FIGURE, TownLifeMath.SEATED
	local torso, head = cfs[1].Position, cfs[2].Position
	assert(torso.Y - F.torso.Y / 2 >= seatTop + S.thigh.Y - 0.01, "torso sits on the thighs")
	assert(head.Y > torso.Y, "head above torso")
	local thigh = cfs[3].Position
	assert(math.abs(thigh.Y - S.thigh.Y / 2 - seatTop - 0.02) < 1e-4, "thighs rest on the seat")
	assert(thigh.Z < 20, "thighs point forward (-Z)")
	local shin = cfs[5].Position
	assert(shin.Z < thigh.Z, "shins hang in front of the hips")
	local shinBottom = shin.Y - S.shin.Y / 2
	assert(shinBottom > 0 and shinBottom < 0.3, "feet near the floor, bottom " .. shinBottom)
	local turned = TownLifeMath.seatedFigureCFrames(CFrame.new(0, seatTop, 0) * CFrame.Angles(0, math.pi, 0))
	assert(turned[3].Position.Z > 0, "turning the seat turns the figure")
end

function T.scarvesGrowWithMatchesAndSitInTheUpstairsWindow()
	assert(TownLifeMath.scarfCount(0) == 0 and TownLifeMath.scarfCount(1) == 0, "none before two matches")
	assert(TownLifeMath.scarfCount(7) == 3, "one per two matches")
	assert(TownLifeMath.scarfCount(500) == TownLifeMath.SCARF_MAX, "capped")
	local z, y = TownLifeMath.scarfSpot("front_a", 0, 16, 64, 12)
	assert(math.abs(z - (-32 + 307 / 512 * 16)) < 1e-6, "first house, right of centre")
	assert(y > 0 and y < 6, "upper half of the wall")
	local zb = TownLifeMath.scarfSpot("front_b", 0, 16, 64, 12)
	assert(math.abs((zb + 32) - (16 - (z + 32))) < 1e-6, "front_b mirrored within the tile")
	local z2 = TownLifeMath.scarfSpot("front_a", 2, 16, 64, 12)
	assert(math.abs(z2 - z - 32) < 1e-6, "two houses along")
end

function T.deliveryVanParksHalfOnTheShopKerbFacingWithTraffic()
	local roads = { { name = "High", kind = "main", width = 26, points = { Vector3.new(-200, 0, 0), Vector3.new(200, 0, 0) } } }
	local cf = TownLifeMath.kerbsideSpot(Vector3.new(10, 0, 20), roads)
	assert(cf, "found a spot")
	assert(math.abs(cf.Position.Z - (13 - TownLifeMath.DELIVERY_KERB_IN)) < 1e-3 and math.abs(cf.Position.X - 10) < 1e-3, "shop side kerb, in line with the shop")
	-- UK: on the +Z side (left of travel) traffic goes -X; a van's nose is its LookVector
	local left = Vector3.new(-cf.LookVector.Z, 0, cf.LookVector.X) * -1
	assert(left:Dot(Vector3.new(0, 0, 1)) > 0.99, "the kerb is on the van's left")
	assert(TownLifeMath.kerbsideSpot(Vector3.new(10, 0, 500), roads) == nil, "too far from any road")
end

-- X111: a swan stays on its ellipse over the river, at the water surface,
-- facing along its path, and swims all the way round.
function T.swanGlidesRoundItsEllipseOnTheRiver()
	for _, spot in TownLifeMath.SWAN_SPOTS do
		local river = TownLayout.distanceToPolyline(spot.centre, TownLayout.RIVER.points)
		assert(river + spot.a < TownLayout.RIVER.width / 2 - 4, "ellipse stays inside the river banks")
		local prev: CFrame? = nil
		for k = 0, 40 do
			local t = k / 40 * spot.period
			local cf = TownLifeMath.swanPose(spot.centre, spot.along, spot.a, spot.b, spot.period, 0.25, t)
			assert(math.abs(cf.Position.Y - TownLifeMath.SWAN_WATER_Y) < 1e-4, "on the water")
			local rel = Vector3.new(cf.Position.X - spot.centre.X, 0, cf.Position.Z - spot.centre.Z)
			assert(rel.Magnitude <= spot.a + 1e-3, "inside the ellipse's long radius")
			if prev then
				local step = cf.Position - prev.Position
				if step.Magnitude > 1e-3 then
					assert(step.Unit:Dot(prev.LookVector) > 0.8, "faces the way it swims")
				end
			end
			prev = cf
		end
		local start = TownLifeMath.swanPose(spot.centre, spot.along, spot.a, spot.b, spot.period, 0, 0)
		local lap = TownLifeMath.swanPose(spot.centre, spot.along, spot.a, spot.b, spot.period, 0, spot.period)
		assert((start.Position - lap.Position).Magnitude < 1e-3, "one period is one lap")
	end
end

-- X137: lit houses are stable, a fair share, always at least one, and the
-- window pane fits inside its house bay.
function T.litWindowsAreStableAndInsideTheirBay()
	local a = TownLifeMath.litHouses(Vector3.new(120, 0, -240), 8)
	local b = TownLifeMath.litHouses(Vector3.new(120, 0, -240), 8)
	assert(#a == #b and #a >= 1, "stable and non-empty")
	for i, h in a do
		assert(h == b[i] and h >= 0 and h <= 7, "house index")
	end
	local lit, total = 0, 0
	for k = 1, 200 do
		total += 6
		lit += #TownLifeMath.litHouses(Vector3.new(k * 31.7, 0, k * -17.3), 6)
	end
	assert(math.abs(lit / total - TownLifeMath.LIT_SHARE) < 0.1, ("share %.2f"):format(lit / total))
	for _, facade in { "front_a", "front_b", "front_c" } do
		local z, y, w, h = TownLifeMath.windowPane(facade, 2, 16, 96, 16)
		assert(z - w / 2 > -48 + 2 * 16 and z + w / 2 < -48 + 3 * 16, facade .. " pane outside its bay")
		assert(y + h / 2 < 16 / 2 and y - h / 2 > -16 / 2, facade .. " pane outside the wall")
	end
end

return T
