--!strict
-- Publishes a few light kit models where client scripts can clone them
-- (backlog X127). ServerStorage.Kit is server-only; clients read
-- ReplicatedStorage.ClientKit. Only single-mesh models go here, to keep what
-- every client downloads small.
--
--   ClientKit.Cars   one-MeshPart hatchbacks for MatchdayLife's car park cars.
--                    Each copy's WorldPivot is moved to the mesh centre with no
--                    rotation, so its long axis is the pivot's Z.
--
-- Place-file models that are already in ReplicatedStorage.ClientKit (the swan,
-- X113) are left alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClientKit = {}

ClientKit.CARS = { "HatchbackOrange", "HatchbackNavy", "HatchbackRed", "HatchbackSilver" }

function ClientKit.publish(): string
	local kit = ServerStorage:FindFirstChild("Kit")
	local root = ReplicatedStorage:FindFirstChild("ClientKit")
	if not root then
		root = Instance.new("Folder")
		root.Name = "ClientKit"
		root.Parent = ReplicatedStorage
	end
	local old = root:FindFirstChild("Cars")
	if old then
		old:Destroy()
	end
	local cars = Instance.new("Folder")
	cars.Name = "Cars"
	local count = 0
	for _, name in ClientKit.CARS do
		local template = kit and kit:FindFirstChild(name, true)
		if not (template and template:IsA("Model")) then
			continue
		end
		local meshes = 0
		for _, d in template:GetDescendants() do
			if d:IsA("BasePart") then
				meshes += 1
			end
		end
		if meshes ~= 1 then
			continue -- only one-mesh cars
		end
		local copy = template:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		local mesh = copy:FindFirstChildWhichIsA("BasePart", true) :: BasePart
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		copy.WorldPivot = CFrame.new(mesh.Position)
		copy.Parent = cars
		count += 1
	end
	cars.Parent = root
	return ("client kit: %d cars"):format(count)
end

return ClientKit
