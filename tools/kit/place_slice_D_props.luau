-- Slice placement pass D: Poly Haven interior props + exterior utility clutter.
local root = workspace.VerticalSlice
local meshes = game.ServerStorage.Kit.Meshes
local Int = root.Interior
local function folder(name) local f = root:FindFirstChild(name); if f then f:Destroy() end; f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f end
local P = folder("KitProps")
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
	m.Parent = P
	return m
end
local function kill(...) for _, n in ipairs({...}) do for _, c in ipairs(Int:GetChildren()) do if c.Name == n then c:Destroy() end end end end
------------------------------------------------------------------ office (floor top 0.45)
kill("Office_DeskTop", "Office_DeskPed", "Office_Monitor", "Office_ChairSeat", "Office_ChairBack", "Office_ChairPost", "Office_FilingCab")
local desk = put("PH__metal_office_desk", 3121, 2031, 180, 0.45, "Office_Desk")
put("PH__modern_arm_chair_01", 3121, 2035, 180, 0.45, "Office_Chair")
put("PH__classic_laptop", 3121.5, 2030.6, 180, 2.95, "Office_Laptop")
put("PH__office_notepads", 3118.6, 2031.4, 20, 2.95, "Office_Notepads")
put("PH__stationery_supplies", 3123.4, 2030.3, -30, 2.95, "Office_Stationery")
put("PH__Television_01", 3108, 2026.5, 200, 2.95, "Office_TV")
put("PH__drawer_cabinet", 3127.5, 2041.5, 0, 0.45, "Office_Cabinet")
put("PH__wooden_bookshelf_worn", 3112.5, 2042, 0, 0.45, "Office_Bookshelf")
put("PH__cardboard_box_01", 3129.5, 2025.5, 15, 0.45, "Office_Box")
put("PH__WetFloorSign_01", 3100.5, 2030, 30, 0.45, "Lobby_WetFloor")
put("PH__korean_fire_extinguisher_01", 3098, 2005, 90, 0.45, "Corridor_Extinguisher")
------------------------------------------------------------------ dressing rooms
put("PH__football", 3112, 1990, 0, 0.45, "DR_Ball1")
put("PH__dirty_football", 3118.5, 1988.5, 40, 0.45, "DR_Ball2")
put("PH__rubber_boots", 3100, 1987, 60, 0.45, "DR_Boots")
put("PH__medical_box", 3130.6, 1990, -90, 5.5, "DR_MedicalBox")
put("PH__football", 3116, 2018, 0, 0.45, "DR2_Ball")
put("PH__painted_wooden_bench", 3126, 2022, 0, 0.45, "DR2_Bench")
------------------------------------------------------------------ kiosk / store
put("PH__CashRegister_01", 3112, 1966.4, 180, 3.2, "Kiosk_Till")
for i, spot in ipairs({ {3099.5, 1979}, {3099.5, 1981.8}, {3102.5, 1980}, {3128, 1980} }) do put("PH__cardboard_box_01", spot[1], spot[2], i * 23, 0.45, "Store_Box" .. i) end
put("PH__CoffeeCart_01", 3108, 1948, 90, 0.2, "Concourse_TeaCart")
------------------------------------------------------------------ exterior utility on the clubhouse and around the site
put("PH__utility_box_01", 3094.5, 2000, 90, 0.02, "Ext_UtilityBox")
put("PH__power_box_01", 3094.7, 1996, 90, 3.0, "Ext_PowerBox")
put("PH__security_camera_01", 3095.2, 2043.5, 135, 9.5, "Ext_Camera")
put("PH__exterior_aircon_unit", 3126, 1962.4, 0, 6.5, "Ext_Aircon")
put("PH__water_manhole_cover", 3014, 2000, 0, 0.5, "Ext_Manhole1")
put("PH__water_manhole_cover", 2986, 1948, 0, 0.5, "Ext_Manhole2")
put("PH__old_tyre", 3086, 2056, 0, 0.12, "Ext_Tyre")
put("PH__wooden_ladder", 3117.3, 1875, 90, 0.02, "Ext_Ladder")
put("PH__rollershutter_door", 3109, 1963.9, 0, 0.4, "Ext_KioskShutter")
return "pass D done: " .. #P:GetChildren() .. " props"
