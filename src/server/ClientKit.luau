--!strict
-- Publishes a few light kit models where client scripts can clone them
-- (backlog X127). ServerStorage.Kit is server-only; clients read
-- ReplicatedStorage.ClientKit. Only single-mesh models go here, to keep what
-- every client downloads small.
--
--   ClientKit.Cars   one-MeshPart hatchbacks for MatchdayLife's car park cars
--                    and Traffic. Each copy's WorldPivot is the mesh's own
--                    CFrame: pivot Z is the car's length, -Z its front.
--
--   ClientKit.Cruiser the one-mesh cabin cruiser (Kit.Boats.BoatCruiser) for
--                    Cruiser.client's boat on the River Lune. Pivot: waterline,
--                    bow to -Z, as stored in the kit.
--
-- Place-file models that are already in ReplicatedStorage.ClientKit (the swan,
-- X113) are left alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClientKit = {}

ClientKit.CARS = { "HatchbackOrange", "HatchbackNavy", "HatchbackRed", "HatchbackSilver" }
-- X128: checked in Studio: with the mesh unrotated, the store orange car's
-- front faces -Z but the three generated ones face +Z. Published as a
-- FrontYaw attribute (radians to add so the front faces -Z).
ClientKit.FRONT_YAW = { HatchbackNavy = math.pi, HatchbackRed = math.pi, HatchbackSilver = math.pi } :: { [string]: number }

-- X372: the town's double-decker, published to ReplicatedStorage.ClientKit.Bus.
ClientKit.BUS = "BusDoubleDecker"
-- Measured like the cars, with the mesh unrotated (Traffic clones the MeshPart
-- alone): its front already faces -Z. Pi here drove every bus tail first.
ClientKit.BUS_FRONT_YAW = 0

ClientKit.CRUISER = "BoatCruiser"

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
		-- the generated meshes sit turned 45 degrees inside their models: pivot on
		-- the mesh itself, so pivot Z is the car's length and -Z its front
		copy.WorldPivot = mesh.CFrame
		copy:SetAttribute("FrontYaw", ClientKit.FRONT_YAW[name] or 0)
		copy.Parent = cars
		count += 1
	end
	cars.Parent = root

	-- X372: the double-decker, same treatment as the cars. Traffic used to build
	-- buses from primitives at 4.4 x 3.0 x 13.5 studs - three studs tall, so a
	-- 5-stud townsperson stood taller than a bus. This one is scaled to a real
	-- double-decker (2.55 x 4.4 x 11 m at 2.75 studs/m).
	local oldBus = root:FindFirstChild("Bus")
	if oldBus then
		oldBus:Destroy()
	end
	local busTemplate = kit and kit:FindFirstChild(ClientKit.BUS, true)
	local buses = 0
	if busTemplate and busTemplate:IsA("Model") then
		local copy = busTemplate:Clone()
		copy.Name = "Bus"
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
				d:Destroy()
			end
		end
		local mesh = copy:FindFirstChildWhichIsA("BasePart", true)
		if mesh then
			local part = mesh :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			copy.WorldPivot = part.CFrame
			-- checked in Studio against a marker cube: the windscreen faces +Z,
			-- so it needs half a turn to match the cars' "-Z is the front" rule
			copy:SetAttribute("FrontYaw", ClientKit.BUS_FRONT_YAW)
			copy.Parent = root
			buses = 1
		else
			copy:Destroy()
		end
	end

	local oldCruiser = root:FindFirstChild("Cruiser")
	if oldCruiser then
		oldCruiser:Destroy()
	end
	local cruiserTemplate = kit and kit:FindFirstChild(ClientKit.CRUISER, true)
	local cruisers = 0
	if cruiserTemplate and cruiserTemplate:IsA("Model") then
		local copy = cruiserTemplate:Clone()
		copy.Name = "Cruiser"
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		copy.Parent = root
		cruisers = 1
	end
	return ("client kit: %d cars, %d bus, %d cruiser"):format(count, buses, cruisers)
end

return ClientKit
