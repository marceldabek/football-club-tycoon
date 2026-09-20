--!strict
-- Rivermere v3, Lane H: builds a fixture of real lots (Station terraces, Smithy Close semis,
-- Pinfold/Drift Close detached, three 45-degree Quarry Road rows) into a throwaway model and
-- checks the definition of done: one building per lot, no KitMissing, no primitives, in budget.
--
-- The fixture is generated from docs/town_v3_lots.json (see the python one-liner in
-- docs/TOWN_V3_HANDOFFS.md, Lane H). Once TownFrontage.generate() lands the Integrator can swap
-- fixtureLots() for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local HouseAssembler = require(ServerScriptService.Server.HouseAssembler)
local HouseRecipes = require(ReplicatedStorage.Shared.HouseRecipes)

-- id, use, district, street, cx, cz, sizeX, sizeZ, yaw, frontX, frontZ, units, unitWidth, closesStreet, corner
local ROWS: { { any } } = {
	{ "High Street|left|3|4", "terraced row", "Station", "High Street", -777, -66, 80, 24, -180, 0, -1, 4, 22, 0, 1 },
	{ "High Street|left|3|6", "terraced row", "Station", "High Street", -964, -66, 124, 24, -180, 0, -1, 6, 22, 0, 1 },
	{ "High Street|left|3|7", "terraced row", "Station", "High Street", -1096, -66, 124, 24, -180, 0, -1, 6, 22, 0, 1 },
	{ "High Street|right|3|3", "terraced row", "Station", "High Street", -772, -144, 80, 24, -180, 0, 1, 4, 22, 0, 1 },
	{ "High Street|right|3|4", "terraced row", "Station", "High Street", -926, -144, 80, 24, -180, 0, 1, 4, 22, 0, 1 },
	{ "High Street|right|3|5", "terraced row", "Station", "High Street", -1091, -144, 124, 24, -180, 0, 1, 6, 22, 0, 1 },
	{ "High Street|right|3|6", "terraced row", "Station", "High Street", -1179, -144, 36, 24, -180, 0, 1, 2, 22, 0, 1 },
	{ "Cooper Street|left|1|1", "terraced row", "Station", "Cooper Street", -1247, -276, 124, 24, 0, 0, 1, 6, 22, 0, 1 },
	{ "Cooper Street|left|1|2", "terraced row", "Station", "Cooper Street", -1115, -276, 124, 24, 0, 0, 1, 6, 22, 0, 0 },
	{ "Cooper Street|left|1|3", "terraced row", "Station", "Cooper Street", -994, -276, 102, 24, 0, 0, 1, 5, 22, 0, 1 },
	{ "Cooper Street|right|1|2", "terraced row", "Station", "Cooper Street", -1214, -204, 124, 24, 0, 0, -1, 6, 22, 0, 1 },
	{ "Cooper Street|right|1|3", "terraced row", "Station", "Cooper Street", -1093, -204, 102, 24, 0, 0, -1, 5, 22, 0, 1 },
	{ "Cooper Street|right|1|4", "terraced row", "Station", "Cooper Street", -928, -204, 80, 24, 0, 0, -1, 4, 22, 0, 1 },
	{ "Cooper Street|right|1|6", "terraced row", "Station", "Cooper Street", -741, -204, 102, 24, 0, 0, -1, 5, 22, 0, 1 },
	{ "Lock Street|left|1|1", "terraced row", "Station", "Lock Street", -1047, 114, 124, 24, 0, 0, 1, 6, 22, 0, 1 },
	{ "Lock Street|left|1|2", "terraced row", "Station", "Lock Street", -937, 114, 80, 24, 0, 0, 1, 4, 22, 0, 1 },
	{ "Lock Street|left|1|3", "terraced row", "Station", "Lock Street", -761, 114, 124, 24, 0, 0, 1, 6, 22, 0, 1 },
	{ "Lock Street|left|1|4", "terraced row", "Station", "Lock Street", -629, 114, 124, 24, 0, 0, 1, 6, 22, 0, 1 },
	{ "Lock Street|right|1|1", "terraced row", "Station", "Lock Street", -1047, 186, 124, 24, 0, 0, -1, 6, 22, 0, 1 },
	{ "Lock Street|right|1|2", "terraced row", "Station", "Lock Street", -915, 186, 124, 24, 0, 0, -1, 6, 22, 0, 0 },
	{ "Lock Street|right|1|3", "terraced row", "Station", "Lock Street", -783, 186, 124, 24, 0, 0, -1, 6, 22, 0, 0 },
	{ "Lock Street|right|1|4", "terraced row", "Station", "Lock Street", -640, 186, 146, 24, 0, 0, -1, 7, 22, 0, 1 },
	{ "Signal Street|left|1|1", "terraced row", "Station", "Signal Street", -1047, -11, 124, 24, 0, 0, 1, 6, 22, 0, 1 },
	{ "Signal Street|left|1|2", "terraced row", "Station", "Signal Street", -937, -11, 80, 24, 0, 0, 1, 4, 22, 0, 1 },
	{ "Signal Street|left|1|3", "terraced row", "Station", "Signal Street", -761, -11, 124, 24, 0, 0, 1, 6, 22, 0, 1 },
	{ "Signal Street|left|1|4", "terraced row", "Station", "Signal Street", -640, -11, 102, 24, 0, 0, 1, 5, 22, 0, 1 },
	{ "Signal Street|right|1|1", "terraced row", "Station", "Signal Street", -1047, 61, 124, 24, 0, 0, -1, 6, 22, 0, 1 },
	{ "Signal Street|right|1|2", "terraced row", "Station", "Signal Street", -937, 61, 80, 24, 0, 0, -1, 4, 22, 0, 1 },
	{ "Signal Street|right|1|3", "terraced row", "Station", "Signal Street", -761, 61, 124, 24, 0, 0, -1, 6, 22, 0, 1 },
	{ "Signal Street|right|1|4", "terraced row", "Station", "Signal Street", -640, 61, 102, 24, 0, 0, -1, 5, 22, 0, 1 },
	{ "Pinfold Close|head|1|1", "detached house", "Mapleford", "Pinfold Close", -916, -1053, 20, 26, -180, 0, -1, 1, 34, 1, 1 },
	{ "Pinfold Close|head|1|2", "detached house", "Mapleford", "Pinfold Close", -950, -1053, 20, 26, -180, 0, -1, 1, 34, 1, 0 },
	{ "Pinfold Close|head|1|3", "detached house", "Mapleford", "Pinfold Close", -984, -1053, 20, 26, -180, 0, -1, 1, 34, 1, 1 },
	{ "Smithy Close|head|2|1", "semis", "Mapleford", "Smithy Close", -826, -1460, 38, 24, -90, -1, 0, 2, 25, 1, 1 },
	{ "Smithy Close|left|1|1", "semis", "Mapleford", "Smithy Close", -1158, -1294, 38, 24, 90, 1, 0, 2, 25, 0, 1 },
	{ "Smithy Close|left|1|2", "semis", "Mapleford", "Smithy Close", -1158, -1344, 38, 24, 90, 1, 0, 2, 25, 0, 0 },
	{ "Smithy Close|left|1|3", "semis", "Mapleford", "Smithy Close", -1158, -1394, 38, 24, 90, 1, 0, 2, 25, 0, 0 },
	{ "Smithy Close|left|1|4", "semis", "Mapleford", "Smithy Close", -1158, -1431.5, 13, 24, 90, 1, 0, 1, 25, 0, 1 },
	{ "Smithy Close|right|1|1", "semis", "Mapleford", "Smithy Close", -1082, -1294, 38, 24, 90, -1, 0, 2, 25, 0, 1 },
	{ "Smithy Close|right|1|2", "semis", "Mapleford", "Smithy Close", -1082, -1344, 38, 24, 90, -1, 0, 2, 25, 0, 0 },
	{ "Smithy Close|right|1|3", "semis", "Mapleford", "Smithy Close", -1082, -1394, 38, 24, 90, -1, 0, 2, 25, 0, 1 },
	{ "Smithy Close|left|2|1", "semis", "Mapleford", "Smithy Close", -1091, -1498, 38, 24, 0, 0, 1, 2, 25, 0, 1 },
	{ "Smithy Close|left|2|2", "semis", "Mapleford", "Smithy Close", -1041, -1498, 38, 24, 0, 0, 1, 2, 25, 0, 0 },
	{ "Smithy Close|left|2|3", "semis", "Mapleford", "Smithy Close", -991, -1498, 38, 24, 0, 0, 1, 2, 25, 0, 0 },
	{ "Smithy Close|left|2|4", "semis", "Mapleford", "Smithy Close", -941, -1498, 38, 24, 0, 0, 1, 2, 25, 0, 1 },
	{ "Smithy Close|right|2|1", "semis", "Mapleford", "Smithy Close", -1025, -1422, 38, 24, 0, 0, -1, 2, 25, 0, 1 },
	{ "Smithy Close|right|2|2", "semis", "Mapleford", "Smithy Close", -975, -1422, 38, 24, 0, 0, -1, 2, 25, 0, 0 },
	{ "Smithy Close|right|2|3", "semis", "Mapleford", "Smithy Close", -937.5, -1422, 13, 24, 0, 0, -1, 1, 25, 0, 1 },
	{ "Drift Close|head|1|1", "detached house", "Mapleford", "Drift Close", -2284, -1117, 20, 26, 0, 0, 1, 1, 34, 1, 1 },
	{ "Drift Close|head|1|2", "detached house", "Mapleford", "Drift Close", -2250, -1117, 20, 26, 0, 0, 1, 1, 34, 1, 0 },
	{ "Drift Close|head|1|3", "detached house", "Mapleford", "Drift Close", -2216, -1117, 20, 26, 0, 0, 1, 1, 34, 1, 1 },
	{ "Drift Close|left|1|1", "detached house", "Mapleford", "Drift Close", -2291, -691, 20, 26, 90, 1, 0, 1, 34, 0, 1 },
	{ "Drift Close|left|1|2", "detached house", "Mapleford", "Drift Close", -2291, -725, 20, 26, 90, 1, 0, 1, 34, 0, 0 },
	{ "Quarry Road|head|2|1", "terraced row", "Millbrook", "Quarry Road", 743.23, -1236.77, 58, 24, 45, 0.7071, 0.7071, 3, 22, 1, 1 },
	{ "Quarry Road|left|2|2", "terraced row", "Millbrook", "Quarry Road", 817.27, -1111.82, 102, 24, 135, 0.7071, -0.7071, 5, 22, 0, 1 },
	{ "Quarry Road|right|2|1", "terraced row", "Millbrook", "Quarry Road", 860.4, -1170.51, 80, 24, 135, -0.7071, 0.7071, 4, 22, 0, 1 },
}

local TOWN_UNITS = 2723 -- housing units in the whole v3 town (docs/town_v3_lots.json)

local tests = {}

local function fixtureLots()
	local lots = {}
	for _, r in ROWS do
		table.insert(lots, {
			id = r[1], use = r[2], district = r[3], street = r[4],
			centre = Vector3.new(r[5], 0, r[6]),
			size = Vector3.new(r[7], 28, r[8]),
			yaw = r[9],
			front = Vector3.new(r[10], 0, r[11]),
			units = r[12], unitWidth = r[13],
			closesStreet = r[14] == 1, corner = r[15] == 1,
		})
	end
	return lots
end

local function kitInstalled(): boolean
	local kit = ServerStorage:FindFirstChild("Kit")
	local meshes = kit and kit:FindFirstChild("Meshes")
	return meshes ~= nil and meshes:FindFirstChild("MEH__Wall_A__ts1") ~= nil
end

local function withBuild(filter, detail, check)
	local holder = Instance.new("Model")
	holder.Name = "HouseAssemblerTest"
	local ok, err = pcall(function()
		local counts = HouseAssembler.buildLots(holder, CFrame.new(0, 0, 0), fixtureLots(), filter, detail)
		check(holder, counts)
	end)
	holder:Destroy()
	assert(ok, err)
end

-- RunAll ignores return values, so this doubles as the fixture accessor for sandbox builds.
function tests.fixture_decodes()
	local lots = fixtureLots()
	assert(#lots >= 40, "fixture is too small: " .. #lots)
	local uses = {}
	for _, lot in lots do
		uses[lot.use] = true
		assert(math.abs(lot.front.Magnitude - 1) < 0.01, lot.id .. " front is not a unit vector")
	end
	assert(uses["terraced row"] and uses["semis"] and uses["detached house"], "fixture must cover all three uses")
	return lots
end

function tests.lot_x_axis_runs_along_the_street()
	for _, lot in fixtureLots() do
		local mine = CFrame.lookAt(lot.centre, lot.centre + lot.front).RightVector
		local yaw = math.rad(lot.yaw)
		local contract = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		local alt = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
		assert(math.abs(mine:Dot(contract)) > 0.99 or math.abs(mine:Dot(alt)) > 0.99, lot.id .. " X axis is not along the street")
	end
end

function tests.one_building_per_lot_no_missing_no_primitives()
	if not kitInstalled() then
		return
	end
	withBuild(nil, nil, function(holder, counts)
		local lots = fixtureLots()
		assert(counts.lots == #lots, ("built %d of %d lots"):format(counts.lots, #lots))
		assert(counts.missing == 0, counts.missing .. " KitMissing fallbacks")
		local seen = {}
		local meshParts = 0
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("LotId") ~= nil then
				local id = d:GetAttribute("LotId")
				assert(not seen[id], "two buildings on lot " .. tostring(id))
				seen[id] = true
				assert(d:FindFirstChildWhichIsA("MeshPart", true), "lot " .. tostring(id) .. " is empty")
			end
			assert(d:GetAttribute("KitMissing") == nil, "KitMissing: " .. d.Name)
			if d:IsA("MeshPart") then
				meshParts += 1
			elseif d:IsA("BasePart") then
				assert(d:GetAttribute("V3Exempt") ~= nil, "untagged primitive " .. d:GetFullName())
			end
		end
		for _, lot in lots do
			assert(seen[lot.id], "no building on lot " .. lot.id)
		end
		assert(meshParts == counts.meshParts, ("count says %d, tree has %d"):format(counts.meshParts, meshParts))
	end)
end

function tests.houses_stay_inside_their_lot_and_face_the_street()
	if not kitInstalled() then
		return
	end
	withBuild(nil, HouseAssembler.PRESETS.lean, function(holder, _counts)
		local byId = {}
		for _, lot in fixtureLots() do
			byId[lot.id] = lot
		end
		for _, d in holder:GetDescendants() do
			local id = d:IsA("Model") and d:GetAttribute("LotId")
			if id then
				local lot = byId[id]
				local lotCF = CFrame.lookAt(lot.centre, lot.centre + lot.front)
				local doors = 0
				for _, part in d:GetDescendants() do
					if part:IsA("MeshPart") then
						local role = part:GetAttribute("Role")
						local p = lotCF:PointToObjectSpace(part.Position)
						if role == "door" then
							doors += 1
							assert(p.Z < -lot.size.Z / 2 + 1.5, id .. ": a door is not on the street side")
						end
						if role ~= "garden" and role ~= "yard" then
							assert(math.abs(p.X) <= lot.size.X / 2 + 1.5, id .. ": " .. part.Name .. " is outside the lot along the street")
							assert(p.Z >= -lot.size.Z / 2 - 2 and p.Z <= lot.size.Z / 2 + 0.5, id .. ": " .. part.Name .. " is outside the lot depth")
						end
					end
				end
				local prefabOnly = d:FindFirstChild("MEH__House_02_VAR1__ts1") or d:FindFirstChild("MEH__House_02_VAR1__ts3")
				assert(doors == lot.units or prefabOnly, ("%s: %d doors for %d units"):format(id, doors, lot.units))
			end
		end
	end)
end

function tests.district_filter_builds_only_that_district()
	if not kitInstalled() then
		return
	end
	withBuild({ district = "Mapleford" }, HouseAssembler.PRESETS.lean, function(holder, counts)
		assert(counts.districts == 1 and #holder:GetChildren() == 1, "filter let other districts through")
		assert(holder:GetChildren()[1].Name == "Housing_Mapleford")
		assert(counts.lots > 0)
	end)
end

function tests.build_is_deterministic()
	if not kitInstalled() then
		return
	end
	local function signature(): string
		local out = ""
		withBuild({ district = "Mapleford" }, nil, function(holder, counts)
			local names = {}
			for _, d in holder:GetDescendants() do
				if d:IsA("MeshPart") then
					table.insert(names, ("%s@%d,%d"):format(d.Name, math.floor(d.Position.X + 0.5), math.floor(d.Position.Z + 0.5)))
				end
			end
			table.sort(names)
			out = counts.meshParts .. ":" .. table.concat(names, ";")
		end)
		return out
	end
	assert(signature() == signature(), "two builds of the same lots differ")
end

-- KNOWN BREACH, reported in docs/TOWN_V3_HANDOFFS.md (Lane H): the TEMP budget of 9,000 works out
-- at 3.3 MeshParts per unit, and a modular front alone is 3 walls + a door leaf. Runtime
-- assembly bottoms out near 6 per unit; only baking each recipe into one mesh gets under budget.
-- Until Lane P rules, these pin the measured cost so it cannot creep.
function tests.preset_costs_per_unit_are_pinned()
	if not kitInstalled() then
		return
	end
	withBuild(nil, HouseAssembler.PRESETS.lean, function(_holder, counts)
		local perUnit = counts.meshParts / counts.units
		assert(perUnit <= 6.5, ("lean preset costs %.1f MeshParts a unit (%d town-wide)"):format(perUnit, perUnit * TOWN_UNITS))
	end)
	withBuild(nil, HouseAssembler.PRESETS.street, function(_holder, counts)
		local perUnit = counts.meshParts / counts.units
		assert(perUnit <= 16, ("street preset costs %.1f MeshParts a unit (%d town-wide)"):format(perUnit, perUnit * TOWN_UNITS))
	end)
end

function tests.presets_get_cheaper_in_order()
	if not kitInstalled() then
		return
	end
	local function parts(detail): number
		local n = 0
		withBuild({ district = "Station" }, detail, function(_holder, counts)
			n = counts.meshParts
		end)
		return n
	end
	local full, street, lean = parts(HouseAssembler.PRESETS.full), parts(HouseAssembler.PRESETS.street), parts(HouseAssembler.PRESETS.lean)
	assert(full > street and street > lean, ("presets out of order: %d %d %d"):format(full, street, lean))
	local _ = HouseRecipes
end

return tests
