-- Run once in Studio (Edit mode, command bar or MCP execute_luau). Installs the
-- concourse catering props (#7, ground plan spec s4) into
-- ServerStorage.Kit.Concourse, where PlotGrounds finds them through KitPlacer.
-- They were made with Studio's generate_mesh (AI mesh, allowed for props by
-- CLAUDE.md s27) on 2026-09-23; each is one textured MeshPart, no scripts.
-- Safe to re-run: an existing template is replaced.
--
--   name            faces            size (studs)          what
--   BurgerVan       hatch on -X      7.3 x 8.5 x 12.6      white/red burger van, front to +Z
--   CateringKiosk   hatch on +Z      8.4 x 8.5 x 5.8       timber kiosk, striped canopy, menu board
--   Portaloo        door on +Z       3.4 x 7.5 x 3.5       green portable toilet
--
-- Without them PlotGrounds falls back to primitive stand-ins (KitMissing).

local AssetService = game:GetService("AssetService")

local PROPS = {
	{ name = "BurgerVan", mesh = "rbxassetid://126225052343317", texture = "rbxassetid://98623056347177" },
	{ name = "CateringKiosk", mesh = "rbxassetid://104519313092885", texture = "rbxassetid://114863198752383" },
	{ name = "Portaloo", mesh = "rbxassetid://102356768762187", texture = "rbxassetid://106266513615296" },
}

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local concourse = folder(folder(game:GetService("ServerStorage"), "Kit"), "Concourse")

local done, failed = {}, {}
for _, prop in PROPS do
	local ok, err = pcall(function()
		local part = AssetService:CreateMeshPartAsync(prop.mesh)
		part.Name = "body_geom"
		part.TextureID = prop.texture
		part.Anchored = true
		part.CFrame = CFrame.new(0, part.Size.Y / 2, 0) -- bottom centre on the pivot
		local model = Instance.new("Model")
		model.Name = prop.name
		part.Parent = model
		model.WorldPivot = CFrame.new()
		model:SetAttribute("MeshId", prop.mesh)
		model:SetAttribute("TextureId", prop.texture)
		local old = concourse:FindFirstChild(prop.name)
		if old then
			old:Destroy()
		end
		model.Parent = concourse
	end)
	table.insert(if ok then done else failed, prop.name .. (if ok then "" else ": " .. tostring(err)))
end
print(("[FCT] concourse props: installed %s; failed %s"):format(table.concat(done, ", "), table.concat(failed, "; ")))
