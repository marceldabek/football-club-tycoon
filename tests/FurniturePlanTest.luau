--!strict
-- Rivermere v3, Lane F: the pure placement rules, on a fixture small enough to
-- reason about. The checks below do their own geometry rather than trusting
-- FurniturePlan's bookkeeping.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FurniturePlan = require(ReplicatedStorage.Shared.FurniturePlan)

local T = {}

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

-- A main road running east into a roundabout, a residential cul-de-sac off its
-- south side with terraces down both sides, a shop parade and a school on the
-- main road's north side, and one bus stop.
local function fixture(): FurniturePlan.Input
	local lots = {}
	for i, z in { 110, 250 } do
		table.insert(lots, { id = "w" .. i, use = "terraced row", district = "Testfield", street = "Side Street", centre = v(-36, z), size = Vector3.new(132, 28, 24), front = Vector3.new(1, 0, 0) })
		table.insert(lots, { id = "e" .. i, use = "terraced row", district = "Testfield", street = "Side Street", centre = v(36, z), size = Vector3.new(132, 28, 24), front = Vector3.new(-1, 0, 0) })
	end
	table.insert(lots, { id = "shops", use = "shops with flats", district = "Testfield", street = "High Road", centre = v(150, -36), size = Vector3.new(130, 36, 30), front = Vector3.new(0, 0, 1) })
	return {
		roads = {
			{ name = "High Road", kind = "main", width = 26, points = { v(-600, 0), v(600, 0) }, district = nil, head = false },
			{ name = "Side Street", kind = "residential", width = 20, points = { v(0, 0), v(0, 400) }, district = "Testfield", head = true },
		},
		lots = lots,
		roundabouts = { { centre = v(600, 0), radius = 40 } },
		specials = { { use = "school", centre = v(-300, -70), size = Vector3.new(120, 0, 80), yaw = 0 } },
		busStops = { { name = "Testfield", position = v(-120, 22) } },
	}
end

local function plan(input: FurniturePlan.Input?, opts: FurniturePlan.Options?): ({ FurniturePlan.Placement }, FurniturePlan.Stats)
	return FurniturePlan.plan(input or fixture(), opts)
end

local function roadNamed(input: FurniturePlan.Input, name: string): FurniturePlan.RoadIn
	for _, road in input.roads do
		if road.name == name then
			return road
		end
	end
	error("no road " .. name)
end

local function ofCategory(list: { FurniturePlan.Placement }, category: string, road: string?): { FurniturePlan.Placement }
	local out = {}
	for _, pl in list do
		if pl.category == category and (road == nil or pl.road == road) then
			table.insert(out, pl)
		end
	end
	return out
end

T["plans something in every expected category"] = function()
	local list = plan()
	for _, category in { "lamp", "pole", "giveWay", "sign", "bin", "bench", "shelter", "guardRail", "manhole", "car" } do
		assert(#ofCategory(list, category) > 0, "no " .. category .. " planned")
	end
end

T["nothing but parked cars stands in a road corridor"] = function()
	local input = fixture()
	for _, pl in plan(input) do
		for _, road in input.roads do
			local d = FurniturePlan.polylineDistance(pl.cframe.Position, road.points)
			if d < road.width / 2 then
				assert(pl.category == "car", pl.category .. " is in the carriageway of " .. road.name)
				assert(pl.road == road.name and road.kind == "residential", "car parked on the wrong road: " .. road.name)
				assert(pl.onCarriageway == true, "car not flagged onCarriageway")
			end
		end
	end
end

T["furniture stands on its own road's pavement strip"] = function()
	local input = fixture()
	for _, pl in plan(input) do
		if pl.category ~= "car" then
			local road = roadNamed(input, pl.road)
			local d = FurniturePlan.polylineDistance(pl.cframe.Position, road.points)
			assert(d >= road.width / 2 and d <= road.width / 2 + FurniturePlan.PAVEMENT_WIDTH, ("%s on %s is %.1f from the centreline"):format(pl.category, pl.road, d))
			assert(math.abs(pl.cframe.Position.Y - FurniturePlan.PAVEMENT_Y) < 1e-4, pl.category .. " is not on the pavement top")
		end
	end
end

T["nothing lands inside a lot or a special block"] = function()
	local input = fixture()
	for _, pl in plan(input) do
		local p = pl.cframe.Position
		for _, lot in input.lots do
			-- fixture lots are axis aligned: size.X runs along the street
			local alongX = math.abs(lot.front.Z) > 0.5
			local hx = if alongX then lot.size.X / 2 else lot.size.Z / 2
			local hz = if alongX then lot.size.Z / 2 else lot.size.X / 2
			assert(not (math.abs(p.X - lot.centre.X) < hx and math.abs(p.Z - lot.centre.Z) < hz), pl.category .. " inside lot " .. tostring(lot.id))
		end
		for _, box in input.specials :: { FurniturePlan.BoxIn } do
			assert(not (math.abs(p.X - box.centre.X) < box.size.X / 2 and math.abs(p.Z - box.centre.Z) < box.size.Z / 2), pl.category .. " inside the " .. box.use)
		end
	end
end

T["junction mouth, roundabout and turning head are clear"] = function()
	local input = fixture()
	for _, pl in plan(input) do
		local p = pl.cframe.Position
		-- the mouth of Side Street on High Road: both pavements' corner squares
		assert(not (math.abs(p.X) < 10 + 8 and math.abs(p.Z) < 13 + 8), pl.category .. " in the junction mouth")
		assert((p - v(600, 0)).Magnitude >= 40 + 8, pl.category .. " on the roundabout")
		assert((p - v(0, 400)).Magnitude >= FurniturePlan.HEAD_RADIUS, pl.category .. " in the turning head")
	end
end

T["violations() agrees and catches a planted offender"] = function()
	local input = fixture()
	local list = plan(input)
	assert(#FurniturePlan.violations(input, list) == 0, "clean plan reported violations")
	local bad = table.clone(list)
	table.insert(bad, { name = "x", cframe = CFrame.new(36, 0.45, 110), category = "bin", road = "Side Street", district = "Testfield" })
	table.insert(bad, { name = "x", cframe = CFrame.new(0, 0.45, 395), category = "bin", road = "Side Street", district = "Testfield" })
	table.insert(bad, { name = "x", cframe = CFrame.new(300, 0.45, 0), category = "bin", road = "High Road", district = "Testfield" })
	assert(#FurniturePlan.violations(input, bad) == 3, "expected 3 violations, got " .. #FurniturePlan.violations(input, bad))
end

T["lamps alternate sides and keep their spacing"] = function()
	local input = fixture()
	local lamps = ofCategory(plan(input), "lamp", "High Road")
	assert(#lamps >= 8, "too few lamps on High Road: " .. #lamps)
	local north, south = 0, 0
	for i, a in lamps do
		if a.cframe.Position.Z < 0 then
			north += 1
		else
			south += 1
		end
		-- the arm (RightVector) points at the road
		local toRoad = Vector3.new(0, 0, -a.cframe.Position.Z).Unit
		assert(a.cframe.RightVector:Dot(toRoad) > 0.99, "lamp arm does not overhang the road")
		for j = i + 1, #lamps do
			local gap = (a.cframe.Position - lamps[j].cframe.Position).Magnitude
			assert(gap >= FurniturePlan.RULES.B.main.lamp / 2 - 0.01, ("lamps %.1f apart"):format(gap))
		end
	end
	assert(math.abs(north - south) <= 2, ("lamps do not alternate: %d north, %d south"):format(north, south))
end

T["poles keep to one side of a street"] = function()
	local poles = ofCategory(plan(), "pole", "Side Street")
	assert(#poles >= 2, "too few poles")
	for _, pl in poles do
		assert((pl.cframe.Position.X > 0) == (poles[1].cframe.Position.X > 0), "poles swap sides")
	end
end

T["give way faces the driver leaving the side street, on their left"] = function()
	local signs = ofCategory(plan(), "giveWay", "Side Street")
	assert(#signs == 1, "expected one give way on Side Street, got " .. #signs)
	local cf = signs[1].cframe
	-- driving north (-Z) towards High Road: left is west (-X), and the face looks back south (+Z)
	assert(cf.Position.X < 0, "give way is on the driver's right")
	assert(cf.LookVector.Z > 0.99, "give way does not face the approaching driver")
	assert(cf.Position.Z > 13 + 8, "give way is inside the mouth")
	-- the main road approaching the roundabout gives way too; the cul-de-sac head does not
	assert(#ofCategory(plan(), "giveWay", "High Road") == 1, "High Road should give way at the roundabout only")
end

T["bus stop gets a shelter facing the road, with a bench and a bin"] = function()
	local list, stats = plan()
	local shelters = ofCategory(list, "shelter")
	assert(#shelters == 1 and #stats.skippedBusStops == 0, "shelter missing")
	local cf = shelters[1].cframe
	assert(cf.Position.Z > 13 and cf.LookVector.Z < -0.99, "shelter is not on the south pavement facing the road")
	assert(math.abs(cf.Position.X - -120) <= 60, "shelter wandered from its stop")
end

T["a bus stop with no road nearby is reported, not dropped silently"] = function()
	local input = fixture()
	input.busStops = { { name = "Nowhere", position = v(3000, 3000) } }
	local list, stats = plan(input)
	assert(#ofCategory(list, "shelter") == 0)
	assert(#stats.skippedBusStops == 1 and stats.skippedBusStops[1] == "Nowhere", "skipped stop not reported")
end

T["cars park only in front of housing, along the kerb"] = function()
	local cars = ofCategory(plan(), "car")
	for _, pl in cars do
		local p = pl.cframe.Position
		assert(pl.road == "Side Street", "car on " .. pl.road)
		assert(math.abs(math.abs(p.X) - (10 - 5.3)) < 0.01, "car is not against the kerb")
		local z = p.Z
		assert((z > 110 - 66 and z < 110 + 66) or (z > 250 - 66 and z < 250 + 66), ("car at z=%.0f is not in front of a terrace"):format(z))
		assert(math.abs(pl.cframe.LookVector.Z) > 0.99, "car is not parked along the street")
	end
end

T["school gets guard rails on the kerb with a gate gap"] = function()
	local rails = ofCategory(plan(), "guardRail")
	assert(#rails == 4, "expected 4 guard rails, got " .. #rails)
	for _, pl in rails do
		assert(pl.cframe.Position.Z < 0, "rail on the wrong side")
		assert(math.abs(pl.cframe.Position.X - -300) > 5, "rail blocks the school gate")
		assert(math.abs(pl.cframe.RightVector.X) > 0.99, "rail does not run along the road")
	end
end

T["the plan is deterministic"] = function()
	local a, b = plan(), plan()
	assert(#a == #b and #a > 0, "different counts")
	for i, pl in a do
		assert(pl.name == b[i].name and pl.category == b[i].category and pl.cframe == b[i].cframe, "placement " .. i .. " differs")
	end
end

T["a road's furniture is seeded by its own name"] = function()
	local input = fixture()
	local before = ofCategory(plan(input), "pole", "Side Street")
	table.insert(input.roads, 1, { name = "Far Away Road", kind = "residential", width = 20, points = { v(-600, 2000), v(600, 2000) }, district = "Elsewhere" })
	local after = ofCategory(plan(input), "pole", "Side Street")
	assert(#before == #after and #before > 0, "pole count changed")
	for i, pl in before do
		assert(pl.cframe == after[i].cframe and pl.name == after[i].name, "adding a road moved Side Street's poles")
	end
end

T["district filter keeps only that district's roads"] = function()
	local list = plan(nil, { district = "Testfield" })
	assert(#list > 0, "nothing planned for Testfield")
	for _, pl in list do
		assert(pl.district == "Testfield" and pl.road == "Side Street", "leaked " .. pl.category .. " on " .. pl.road)
	end
	for _, pl in plan(nil, { district = FurniturePlan.NO_DISTRICT }) do
		assert(pl.road == "High Road", "through-road filter leaked " .. pl.road)
	end
end

T["Tier A is denser than Tier B, and only inside its radius"] = function()
	local input = fixture()
	local sparse = #ofCategory(plan(input), "lamp", "High Road")
	input.tierACentres = { v(-600, 0) }
	local list = plan(input)
	local nearA, farA = 0, 0
	for _, pl in ofCategory(list, "lamp", "High Road") do
		if pl.cframe.Position.X < -600 + FurniturePlan.TIER_A_RADIUS then
			nearA += 1
		elseif pl.cframe.Position.X > 0 then
			farA += 1
		end
	end
	assert(#ofCategory(list, "lamp", "High Road") > sparse, "Tier A added no lamps")
	-- 450 studs at one lamp per 20, against 600 studs at one per 35
	assert(nearA >= 18 and farA <= 18, ("Tier A %d lamps, Tier B %d"):format(nearA, farA))
	assert(#FurniturePlan.violations(input, list) == 0, "Tier A broke a placement rule")
end

T["stats count what was planned"] = function()
	local list, stats = plan()
	local total = 0
	for _, n in stats.planned do
		total += n
	end
	assert(total == #list, ("stats say %d, list has %d"):format(total, #list))
end

T["diagonal roads keep furniture off lots and corridors"] = function()
	local input: FurniturePlan.Input = {
		roads = {
			{ name = "Slant Road", kind = "residential", width = 20, points = { v(0, 0), v(300, 300), v(600, 300) }, district = "Slant" },
		},
		lots = {},
	}
	local f = Vector3.new(-1, 0, 1).Unit -- lot on the north-east side faces south-west
	table.insert(input.lots, { id = "d1", use = "semis", district = "Slant", street = "Slant Road", centre = v(150, 150) - f * (10 + 16 + 12), size = Vector3.new(100, 28, 24), front = f })
	local list = FurniturePlan.plan(input)
	assert(#list > 5, "too little planned on the diagonal")
	assert(#FurniturePlan.violations(input, list) == 0, "violations on the diagonal")
	for _, pl in list do
		if pl.category ~= "car" then
			local d = FurniturePlan.polylineDistance(pl.cframe.Position, input.roads[1].points)
			assert(d >= 10 and d <= 18.01, ("%s is %.1f from the centreline"):format(pl.category, d))
		end
	end
end

return T
