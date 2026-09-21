-- EDIT MODE ONLY (command bar / MCP execute_luau). Rebuilds
-- ServerStorage.Kit.Vehicles.Bicycle from a free Creator Store model
-- ("Bicycle bike cycle" by Wish Game, 91358100215341: three MeshParts, no scripts,
-- no textures). Rojo can't own it, so re-run this on a fresh place file, then save
-- the place.
--
-- The template ends up: anchored, no collision, front wheel towards -Z, 4.8 studs
-- long (a 1.75 m bike at the town's 2.75 studs a metre), pivot on the ground under
-- the middle of its length. That is what ClientKit's Bicycle and Traffic.client's
-- buildBike expect. The frame is the part named "Body": Traffic paints it.
--
-- Measured on the mesh at this size (Traffic.client's BIKE_* numbers come from
-- these): saddle top 2.43 up and 0.77 behind the pivot, grips 2.8 up and 0.9 ahead,
-- bottom bracket 0.83 up and 0.29 behind.

local ASSET = 91358100215341
local LENGTH = 4.8
local LONG_PART = "Black" -- tyres, saddle and grips: spans the whole bike; its local +X is the front

local kit = game:GetService("ServerStorage"):FindFirstChild("Kit")
assert(kit, "ServerStorage.Kit is missing")
local vehicles = kit:FindFirstChild("Vehicles")
if not vehicles then
	vehicles = Instance.new("Folder")
	vehicles.Name = "Vehicles"
	vehicles.Parent = kit
end
local old = vehicles:FindFirstChild("Bicycle")
if old then
	old:Destroy()
end

local m = Instance.new("Model")
m.Name = "Bicycle"
for _, o in game:GetObjects("rbxassetid://" .. ASSET) do
	o.Parent = m
end
local parts = {}
for _, d in m:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
		d:Destroy()
	elseif d:IsA("BasePart") then
		table.insert(parts, d)
	end
end
-- flatten: just the MeshParts under the model
for _, p in parts do
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = m
end
for _, c in m:GetChildren() do
	if not c:IsA("BasePart") then
		c:Destroy()
	end
end

local long = m:FindFirstChild(LONG_PART) :: BasePart
assert(long, "no part named " .. LONG_PART)
-- turn the whole bike so the long part's local +X (the front) points to world -Z
local want = CFrame.Angles(0, math.rad(90), 0)
local turn = want * long.CFrame:Inverse()
for _, p in parts do
	p.CFrame = turn * p.CFrame
end
m.WorldPivot = CFrame.new(long.Position)
m.Parent = workspace -- ScaleTo needs the model in the DataModel
m:ScaleTo(LENGTH / long.Size.X)
-- pivot on the ground under the middle of the bike, axes square to the world
m.WorldPivot = CFrame.new(long.Position - Vector3.new(0, long.Size.Y / 2, 0))
m:PivotTo(CFrame.new(0, 0, 0))
m.Parent = vehicles

local _, size = m:GetBoundingBox()
print(("[kit] Bicycle: %d parts, %.2f x %.2f x %.2f"):format(#parts, size.X, size.Y, size.Z))
return ("Bicycle: %d parts, %.2f x %.2f x %.2f"):format(#parts, size.X, size.Y, size.Z)
