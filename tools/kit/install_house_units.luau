-- Run once in Studio (Edit mode, command bar or MCP execute_luau). Loads the merged house unit
-- meshes named in Shared/HouseUnits into ServerStorage.Kit.Meshes and builds the tileable brick
-- and slate SurfaceAppearances in ServerStorage.Kit.Appearances. Safe to re-run: a mesh is
-- refetched only when its asset id in HouseUnits changed (each template remembers its id in the
-- AssetId attribute), appearances are rebuilt.

local IS = game:GetService("InsertService")
local inst = game.ReplicatedStorage.Shared.HouseUnits
local HouseUnits = assert(loadstring(inst.Source, "=HouseUnits"))()

local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local kit = folder(game.ServerStorage, "Kit")
local meshes, looks = folder(kit, "Meshes"), folder(kit, "Appearances")

local fetched, failed = 0, {}
for _, unit in HouseUnits.UNITS do
	for _, mesh in unit.meshes do
		local old = meshes:FindFirstChild(mesh.name)
		if old and old:GetAttribute("AssetId") ~= ("%.0f"):format(mesh.assetId) then
			old:Destroy()
			old = nil
		end
		if not old then
			local ok, err = pcall(function()
				assert(mesh.assetId ~= 0, "not uploaded yet")
				local container = IS:LoadAsset(mesh.assetId)
				local model = container:FindFirstChildWhichIsA("Model") or container
				model.Name = mesh.name
				for _, d in model:GetDescendants() do
					if d:IsA("PackageLink") or d:IsA("SurfaceAppearance") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				model:SetAttribute("AssetId", ("%.0f"):format(mesh.assetId))
				model.Parent = meshes
				if container ~= model then
					container:Destroy()
				end
			end)
			if ok then
				fetched += 1
			else
				table.insert(failed, mesh.name .. ": " .. tostring(err))
			end
		end
	end
end

for name, maps in HouseUnits.LOOKS do
	local old = looks:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local sa = Instance.new("SurfaceAppearance")
	sa.Name = name
	sa.ColorMap = "rbxassetid://" .. maps[1]
	sa.NormalMap = "rbxassetid://" .. maps[2]
	sa.RoughnessMap = "rbxassetid://" .. maps[3]
	sa.Parent = looks
end

return ("fetched %d, failed %d: %s"):format(fetched, #failed, table.concat(failed, "; "))
