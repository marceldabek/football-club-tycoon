-- Run once in Studio (Edit mode, command bar or MCP execute_luau). Installs the
-- generated vehicle props (#8 team coach and TV van dish, #36 train) into
-- ServerStorage.Kit.Vehicles, where WorldBuilder / MatchdayLife / Train find
-- them through KitPlacer and ClientKit. They were made with Studio's
-- generate_mesh (AI mesh, allowed for props by CLAUDE.md s27) on 2026-09-23 in
-- the station 3 place; each is one textured MeshPart, no scripts. Same layout
-- as generate_mesh leaves it: <Name>/body/body_geom, pivot at the part.
-- Safe to re-run: an existing template is replaced.
--
--   name            size (studs)             what
--   TeamCoach       11.0 x 10.9 x 31.0       white/blue coach (WorldBuilder stretches it to TEAM_COACH_SIZE)
--   SatelliteDish   2.9 x 3.5 x 1.7          dish for the TV van's roof
--   TrainCarriage   7.4 x 7.1 x 30           passenger carriage
--
-- Without them the code falls back to the primitive coach / dish / train.

local AssetService = game:GetService("AssetService")

local PROPS = {
	{ name = "TeamCoach", mesh = "rbxassetid://120046696435678", texture = "rbxassetid://90979085297377", generation = "11ef7eeb-4cad-44fe-b1ef-04c9476075cf", size = Vector3.new(11.05, 10.9422, 30.9676) },
	{ name = "SatelliteDish", mesh = "rbxassetid://82585593613175", texture = "rbxassetid://97752724184325", generation = "63c32231-891d-46f2-b099-a940e9f2bb47", size = Vector3.new(2.9478, 3.5, 1.6566) },
	{ name = "TrainCarriage", mesh = "rbxassetid://138536647789512", texture = "rbxassetid://132780574619766", generation = "cadef974-deac-4ca8-9fcc-30a47e9c6564", size = Vector3.new(7.4, 7.0797, 30) },
}

local function folder(parent: Instance, name: string): Instance
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local vehicles = folder(folder(game:GetService("ServerStorage"), "Kit"), "Vehicles")

local done, failed = {}, {}
for _, prop in PROPS do
	local ok, err = pcall(function()
		local part = AssetService:CreateMeshPartAsync(prop.mesh)
		part.Name = "body_geom"
		part.TextureID = prop.texture
		part.Size = prop.size -- as installed in the station 3 place (the mesh imports smaller)
		part.Anchored = false -- as generate_mesh left it; KitPlacer anchors the clones
		part.CFrame = CFrame.new()
		local body = Instance.new("Model")
		body.Name = "body"
		part.Parent = body
		body.WorldPivot = CFrame.new()
		local model = Instance.new("Model")
		model.Name = prop.name
		body.Parent = model
		model.WorldPivot = CFrame.new()
		model:SetAttribute("Source", "GenerateMesh")
		model:SetAttribute("License", "Roblox AI generation (generate_mesh, X393)")
		model:SetAttribute("GenerationId", prop.generation) -- RBX_ names are reserved
		model:SetAttribute("MeshId", prop.mesh)
		model:SetAttribute("TextureId", prop.texture)
		local old = vehicles:FindFirstChild(prop.name)
		if old then
			old:Destroy()
		end
		model.Parent = vehicles
	end)
	table.insert(if ok then done else failed, prop.name .. (if ok then "" else ": " .. tostring(err)))
end
print(("[FCT] vehicle props: installed %s; failed %s"):format(table.concat(done, ", "), table.concat(failed, "; ")))
