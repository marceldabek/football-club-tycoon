-- Slice placement pass A: perimeter fences, road frontage, garden walls, houses.
-- Run through the MCP execute_luau tool AFTER kit meshes exist in ServerStorage.Kit.Meshes
-- (see fetch table generated from assets/kit/_export/asset_ids_merged.json).
-- Conventions: a kit mesh's "front" is its LookVector (-Z at identity); long fence pieces run along +X.
local root = workspace.VerticalSlice
local meshes = game.ServerStorage.Kit.Meshes
local function folder(name) local f = root:FindFirstChild(name); if f then f:Destroy() end; f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f end
local F = { Fences = folder("KitFences"), Gardens = folder("KitGardens"), Houses = folder("Houses") }
local function ground(m, lift)
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, -(cf.Position.Y - size.Y/2) + (lift or 0.02), 0))
end
-- place a template so its pivot sits at (x, z) facing `dir` (unit XZ vector)
local function put(templateName, parent, x, z, dir, name, lift)
	local t = meshes:FindFirstChild(templateName)
	if not t then warn("missing template " .. templateName); return nil end
	local m = t:Clone(); m.Name = name or templateName
	m:PivotTo(CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + dir.X, 0, z + dir.Z)))
	ground(m, lift)
	m.Parent = parent
	return m
end
-- lay pieces of length `len` along a line from (x0,z0) to (x1,z1); piece's +X axis runs along the line
local function run(templateNames, parent, x0, z0, x1, z1, len, name)
	local dx, dz = x1 - x0, z1 - z0
	local total = math.sqrt(dx*dx + dz*dz)
	local ux, uz = dx/total, dz/total
	local n = math.floor(total / len + 0.5)
	local step = total / n
	-- a piece whose +X runs along (ux,uz) has LookVector (-Z) = rotate (ux,uz) by +90deg about Y -> (uz, -ux)... use RightVector directly
	for i = 0, n - 1 do
		local cx, cz = x0 + ux*(i + 0.5)*step, z0 + uz*(i + 0.5)*step
		local tn = templateNames[(i % #templateNames) + 1]
		local t = meshes:FindFirstChild(tn)
		if t then
			local m = t:Clone(); m.Name = (name or tn) .. "_" .. i
			local right = Vector3.new(ux, 0, uz)
			local look = Vector3.new(-uz, 0, ux) -- right x up
			m:PivotTo(CFrame.fromMatrix(Vector3.new(cx, 0, cz), right, Vector3.new(0, 1, 0), -look))
			ground(m)
			m.Parent = parent
		end
	end
end
------------------------------------------------------------------ remove part placeholders
for _, n in ipairs({"Fence_Road_N", "Fence_Road_S", "Fence_N", "Fence_S", "Fence_PitchN", "Fence_PitchS", "Fence_PitchE", "Fence_CarParkN_a", "Fence_CarParkN_b"}) do
	local p = root.Fences:FindFirstChild(n); if p then p:Destroy() end
end
------------------------------------------------------------------ road frontage: corrugated fence, gate gap 1990..2010
run({"UKSP__CorrugatedFence__CorrugatedFenceA01", "UKSP__CorrugatedFence__CorrugatedFenceB02", "UKSP__CorrugatedFence__CorrugatedFenceA03", "UKSP__CorrugatedFence__CorrugatedFenceB01"}, F.Fences, 3020, 1880, 3020, 1989, 8.3, "RoadFence")
run({"UKSP__CorrugatedFence__CorrugatedFenceB03", "UKSP__CorrugatedFence__CorrugatedFenceA02", "UKSP__CorrugatedFence__CorrugatedFenceA01", "UKSP__CorrugatedFence__CorrugatedFenceB02"}, F.Fences, 3020, 2011, 3020, 2120, 8.3, "RoadFence")
------------------------------------------------------------------ chain-link boundaries
run({"UKSP__Fences__FenceNewA01", "UKSP__Fences__FenceNewA02"}, F.Fences, 3020, 1880, 3118, 1880, 13.8, "FenceN")
run({"UKSP__Fences__FenceMediumRustA01", "UKSP__Fences__FenceMediumRustA02"}, F.Fences, 3020, 2120, 3140, 2120, 13.8, "FenceS")
run({"UKSP__Fences__FenceRustedA01", "UKSP__Fences__FenceRustedA02"}, F.Fences, 3140, 1840, 3345, 1840, 13.8, "FencePitchN")
run({"UKSP__Fences__FenceRustedA02", "UKSP__Fences__FenceRustedA01"}, F.Fences, 3140, 2160, 3345, 2160, 13.8, "FencePitchS")
run({"UKSP__Fences__FenceMediumRustA01", "UKSP__Fences__FenceMediumRustA02"}, F.Fences, 3345, 1840, 3345, 2160, 13.8, "FencePitchE")
run({"UKSP__Fences__FenceNewA01"}, F.Fences, 3090, 1940, 3100, 1940, 10, "FenceCarParkA")
run({"UKSP__Fences__FenceNewA02"}, F.Fences, 3112, 1940, 3118, 1940, 6, "FenceCarParkB")
------------------------------------------------------------------ house plots (centres Z 1900..2020 step 30), fronts facing east (+X)
local houseNames = { "MEH__House_01_VAR01__ts1", "MEH__House_02_VAR1__ts1", "MEH__House_03_VAR01__ts1", "MEH__House_04_VAR01__ts1", "MEH__House_05_VAR01__ts3" }
for i, zc in ipairs({1900, 1930, 1960, 1990, 2020}) do
	put(houseNames[i], F.Houses, 2957, zc, Vector3.new(1, 0, 0), "House_" .. i)
	-- frontage: wall pieces either side of a 4-stud gate gap at zc, along X = 2981
	local styles = { {"UKSP__GardenWallA__GardenWallAWithFence"}, {"UKSP__GardenWallB__WallBStraightWithRailing"}, {"hedge"}, {"UKSP__GardenWallA__GardenWallAWithoutFence"}, {"UKSP__GardenWall__Wall"} }
	local style = styles[i][1]
	if style == "hedge" then
		local h = game.ServerStorage.Kit.Vegetation.HedgeLong
		for _, zz in ipairs({zc - 9, zc + 9}) do
			local m = Instance.new("Model"); m.Name = "PlotHedge_" .. i
			for _, d in ipairs(h:GetDescendants()) do if d:IsA("BasePart") then local q = d:Clone(); q.Anchored = true; q.Parent = m end end
			local cf, size = m:GetBoundingBox()
			m:PivotTo(CFrame.new(2981, cf.Position.Y, zz) * CFrame.Angles(0, math.pi/2, 0)); ground(m); m.Parent = F.Gardens
		end
	else
		local len = (style == "UKSP__GardenWall__Wall") and 8.2 or 5.7
		run({style}, F.Gardens, 2981, zc - 15, 2981, zc - 2.2, len, "PlotWall_" .. i)
		run({style}, F.Gardens, 2981, zc + 2.2, 2981, zc + 15, len, "PlotWall_" .. i)
		-- gate posts / caps either side of the gap
		local capName = (style:find("GardenWallA")) and "UKSP__GardenWallA__GardenWallACap" or ((style:find("WallB")) and "UKSP__GardenWallB__WallBCap" or "UKSP__GardenWall__PostA")
		put(capName, F.Gardens, 2981, zc - 2.6, Vector3.new(1, 0, 0), "GatePost_" .. i)
		put(capName, F.Gardens, 2981, zc + 2.6, Vector3.new(1, 0, 0), "GatePost_" .. i)
	end
	-- garden path from gate to front door
	local p = Instance.new("Part"); p.Anchored = true; p.Name = "Path_" .. i; p.Size = Vector3.new(11, 0.1, 3); p.Position = Vector3.new(2975.5, 0.05, zc)
	p.Material = Enum.Material.Concrete; p.Color = Color3.fromRGB(160, 156, 148); p.Parent = F.Gardens
end
-- a garage beside plot 5 and the old hedge placements removed
local veg = root:FindFirstChild("Vegetation")
if veg then for _, c in ipairs(veg:GetChildren()) do if c.Name:sub(1, 5) == "Hedge" then c:Destroy() end end end
put("MEH__Garage_01_VAR01__ts1", F.Houses, 2950, 2040, Vector3.new(1, 0, 0), "Garage_5")
return "pass A done: fences=" .. #F.Fences:GetChildren() .. " gardens=" .. #F.Gardens:GetChildren() .. " houses=" .. #F.Houses:GetChildren()
