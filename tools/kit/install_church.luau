-- Run once in Studio (Edit mode, command bar or MCP execute_luau), then SAVE THE PLACE. Installs
-- the parish church landmark (#34) as ServerStorage.Kit.Town.ChurchMesh, which
-- SquareDresser.dressChurch prefers over the 238-part Creator Store `ChurchSpire` keeper.
--
-- The mesh is free: made 2026-09-23 with Studio's generate_mesh (prompt: "Traditional English
-- village parish church built of pale grey limestone blocks: a long nave with a steep dark slate
-- pitched roof and tall pointed gothic arched windows along both sides, a square stone bell tower
-- at the west end with louvred belfry openings and small corner pinnacles, topped by a tall
-- slender octagonal broach spire in grey stone"), published as asset 76841186162075. It came out
-- 19 x 41 x 45 with the nave along its Z; it is turned so the nave runs along the template's X
-- (as ChurchSpire's did) and stretched to 105 long, 130 tall (the landmark height,
-- docs/TOWN_PLAN.md: the spire must clear 40-stud roofs from 560 studs), 44 wide. The extra
-- height is a 35% vertical stretch: tall gothic windows, a slimmer tower. Safe to re-run.

local ASSET_ID = 76841186162075
local LENGTH, HEIGHT = 105, 130

local kit = game:GetService("ServerStorage"):WaitForChild("Kit")
local town = kit:FindFirstChild("Town") or Instance.new("Folder")
town.Name = "Town"
town.Parent = kit

local old = town:FindFirstChild("ChurchMesh")
if old then
	old:Destroy()
end

local container = game:GetService("InsertService"):LoadAsset(ASSET_ID)
local part = container:FindFirstChildWhichIsA("MeshPart", true)
assert(part, "asset " .. ASSET_ID .. " has no MeshPart")
local s = part.Size
part.Parent = nil
container:Destroy()

part.Name = "Church"
part.Anchored = true
part.Size = Vector3.new(s.X / s.Z * LENGTH, HEIGHT, LENGTH)
-- nave (mesh Z) along the template's X
part.CFrame = CFrame.new(0, HEIGHT / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)

-- SquareDresser.parishName reads the name of the Model inside the placed church
local parish = Instance.new("Model")
parish.Name = "St. Peter's"
part.Parent = parish

local model = Instance.new("Model")
model.Name = "ChurchMesh"
parish.Parent = model
-- The pivot is taken from the first part added, turn and all; KitPlacer measures the template in
-- its pivot's frame, so reset it or the nave is back along Z.
model.WorldPivot = CFrame.new()
parish.WorldPivot = CFrame.new()
model:SetAttribute("AssetId", tostring(ASSET_ID))
model.Parent = town

local _, size = model:GetBoundingBox()
return ("installed Kit.Town.ChurchMesh %.1f x %.1f x %.1f"):format(size.X, size.Y, size.Z)
