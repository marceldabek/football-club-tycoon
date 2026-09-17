-- Slice placement pass C: street furniture, car park clutter, concourse dressing.
local root = workspace.VerticalSlice
local meshes = game.ServerStorage.Kit.Meshes
local function folder(name) local f = root:FindFirstChild(name); if f then f:Destroy() end; f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f end
local S = folder("KitStreet")
local function ground(m, floorY)
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, -(cf.Position.Y - size.Y/2) + (floorY or 0.02), 0))
end
local function put(templateName, x, z, yawDeg, floorY, name)
	local t = meshes:FindFirstChild(templateName)
	if not t then warn("missing " .. templateName); return nil end
	local m = t:Clone(); m.Name = name or templateName
	m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0))
	ground(m, floorY)
	m.Parent = S
	return m
end
local PAV = 0.5   -- pavement top
local ROAD = 0.0
local ASPH = 0.1  -- car park top
------------------------------------------------------------------ lamp posts (arm overhangs the road)
for i, z in ipairs({1860, 1900, 1940, 1980, 2020, 2060, 2100, 2140}) do
	put(i % 2 == 0 and "UKSP__StreetLights__StreetLight01" or "UKSP__StreetLights__StreetLight02", 3016.5, z, 180, PAV, "Lamp_E" .. i)
end
for i, z in ipairs({1880, 1920, 1960, 2000, 2040, 2080, 2120, 2160}) do
	put(i % 2 == 0 and "UKSP__StreetLights__StreetLight02" or "UKSP__StreetLights__StreetLight01", 2983.5, z, 0, PAV, "Lamp_W" .. i)
end
------------------------------------------------------------------ telegraph poles on the west pavement back edge
for i, z in ipairs({1912, 2002, 2092}) do put("UKSP__TelegraphPoles__A05", 2983.2, z, i * 40, PAV, "Telegraph_" .. i) end
------------------------------------------------------------------ bus stop (east pavement, opening faces the road) + bench + bin + phone box
put("UKSP__BusShelter__BusShelter", 3015, 2085, 90, PAV, "BusShelter")
put("UKSP__ParkBenches__ParkBench01", 3015.5, 2094, -90, PAV, "Bench_BusStop")
put("UKSP__LitterBin__LitterBin", 3013.2, 2078, 0, PAV, "Bin_BusStop")
put("UKSP__RedPhoneBoxes__RedPhoneBoxDirty", 3015.8, 2130, 90, PAV, "PhoneBox")
put("UKSP__TelegraphPoles__UKBin", 2985.5, 1975, 0, PAV, "Bin_W1")
put("UKSP__TelegraphPoles__UKBin", 3013.5, 2112, 0, PAV, "Bin_E2")
put("UKSP__LitterBin__LitterBin", 3093.5, 2023.5, 0, 0.02, "Bin_ClubDoor")
------------------------------------------------------------------ roadworks at the north end of the east pavement
put("UKSP__RoadWorksSign__RoadWorksSignNew", 3015, 1863, 200, PAV, "RoadWorksSign")
put("UKSP__TrafficCones__TrafficCone01", 3012.5, 1866, 0, PAV, "Cone1")
put("UKSP__TrafficCones__TrafficCone02", 3014.5, 1869, 30, PAV, "Cone2")
put("UKSP__TrafficCones__TrafficCone05", 3012, 1872, 70, PAV, "Cone3")
put("UKSP__TrafficCones__TrafficCone07", 3016.5, 1875, 10, PAV, "Cone4")
------------------------------------------------------------------ car park corner clutter: skip, pallets, boxes, tyre
put("UKSP__Skips__Skip02", 3083.5, 2053, 100, ASPH, "Skip")
put("UKSP__WoodPallets__PalletA01", 3086.5, 2044, 8, ASPH, "Pallet1")
put("UKSP__WoodPallets__PalletB02", 3086.5, 2044, 22, ASPH + 0.5, "Pallet2")
put("UKSP__WoodPallets__PalletC03", 3080, 2058.5, -12, ASPH, "Pallet3")
put("UKSP__boxes__Box01", 3081, 2046, 15, ASPH, "Box1")
put("UKSP__boxes__Box05", 3079, 2044.5, -40, ASPH, "Box2")
------------------------------------------------------------------ bins behind the clubhouse north end (dumpster + bags)
put("UKSP__dumpster__DumpsterNew", 3089, 1972, 90, 0.02, "Dumpster")
put("UKSP__dumpster__DumpsterLeftLid", 3089, 1969.5, 90, 5.5, "DumpsterLid1")
put("UKSP__dumpster__DumpsterRightLid", 3089, 1974.5, 90, 5.5, "DumpsterLid2")
put("UKSP__TrashBags__Bag01", 3089.5, 1978.5, 20, 0.02, "Bag1")
put("UKSP__TrashBags__Bag03", 3092.5, 1979.5, 140, 0.02, "Bag2")
put("UKSP__TrachCan__TrashcanBase", 3103, 1950, 0, 0.2, "ConcourseBinBase")
put("UKSP__TrachCan__TrashcanLid", 3103, 1950, 0, 3.0, "ConcourseBinLid")
------------------------------------------------------------------ concourse: crowd barriers as a queue lane in front of the turnstiles, a bench
for i = 0, 3 do put(i % 2 == 0 and "UKSP__CrowdBarrier__CrowdBarrierNewA" or "UKSP__CrowdBarrier__CrowdBarrierOldA", 3102 + i * 5.7, 1947.5, 0, 0.2, "QueueBarrier" .. i) end
put("UKSP__ParkBenches__ParkBench02", 3110, 1957.5, 180, 0.2, "Bench_Concourse")
------------------------------------------------------------------ pedestrian guard rails either side of the club gate on the kerb line
put("UKSP__GuardRails__GuardRailAMiddle", 3011.2, 1984, 90, PAV, "GuardRail_N")
put("UKSP__GuardRails__GuardRailAMiddle", 3011.2, 2016, 90, PAV, "GuardRail_S")
------------------------------------------------------------------ a couple of road signs (checked visually afterwards)
put("UKSP__Signs__SignNew03", 3016.8, 1856, 180, PAV, "Sign_N")
put("UKSP__Signs__SignNew16", 2983.2, 2150, 0, PAV, "Sign_S")
-- rename the test bin from the upload check
local tb = root.StoreProps:FindFirstChild("Test_LitterBin"); if tb then tb.Name = "Bin_Gate" end
return "pass C done: " .. #S:GetChildren() .. " street items"
