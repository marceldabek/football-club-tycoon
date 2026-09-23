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
--   ClientKit.WheelFace the spoked wheel face for Shared.CarWheels (the cars'
--                    own wheels are baked into their meshes and cannot turn).
--
--   ClientKit.Cruiser the one-mesh cabin cruiser (Kit.Boats.BoatCruiser) for
--                    Cruiser.client's boat on the River Lune. Pivot: waterline,
--                    bow to -Z, as stored in the kit.
--
--   ClientKit.Bicycle the cyclists' bike for Traffic. Pivot: on the ground under the
--                    bottom bracket, front wheel to -Z.
--
--   ClientKit.Van     X393 (playtest #8): the 71-part Kit.Vehicles.VanWhite,
--                    whole model like Cruiser/Bicycle below (not a one-mesh
--                    car). MatchdayLife's broadcast van; front is -Z unrotated.
--
--   ClientKit.Dish    X393: a generated satellite dish (single mesh) for the
--                    same broadcast van. Pivot is the mesh's own CFrame.
--
-- Place-file models that are already in ReplicatedStorage.ClientKit (the swan,
-- X113) are left alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CarWheels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarWheels"))

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

-- The town cyclists' bicycle (Kit.Vehicles.Bicycle, tools/kit/install_bicycle.luau):
-- pivot on the ground under the bottom bracket, front wheel to -Z. May be more than
-- one part. Without it Traffic falls back to its three-part primitive bike.
ClientKit.BICYCLE = "Bicycle"

-- X393 (playtest #8): the team coach's TV/broadcast van and its dish.
ClientKit.VAN = "VanWhite"
ClientKit.DISH = "SatelliteDish"

-- X394 (playtest #36): a generated train carriage, reused for all 3 of the
-- town train's carriages. Single mesh, length along its Z, a cab at each end.
ClientKit.TRAIN_CARRIAGE = "TrainCarriage"

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

	-- the spoked wheel face Traffic and MatchdayLife lay over the cars' baked wheels
	local oldFace = root:FindFirstChild("WheelFace")
	if oldFace then
		oldFace:Destroy()
	end
	local faceKit = kit and kit:FindFirstChild(CarWheels.FACE_KIT, true)
	local face = faceKit and faceKit:FindFirstChild(CarWheels.FACE_PART, true)
	if face and face:IsA("BasePart") then
		local copy = face:Clone()
		copy.Name = "WheelFace"
		copy:ClearAllChildren()
		copy.Anchored = true
		copy.Parent = root
	end

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

	local oldBicycle = root:FindFirstChild("Bicycle")
	if oldBicycle then
		oldBicycle:Destroy()
	end
	local bicycleTemplate = kit and kit:FindFirstChild(ClientKit.BICYCLE, true)
	local bicycles = 0
	if bicycleTemplate and bicycleTemplate:IsA("Model") then
		local copy = bicycleTemplate:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		copy.Parent = root
		bicycles = 1
	end

	-- X393: the broadcast van, whole model (71 parts) like Cruiser above.
	local oldVan = root:FindFirstChild("Van")
	if oldVan then
		oldVan:Destroy()
	end
	local vanTemplate = kit and kit:FindFirstChild(ClientKit.VAN, true)
	local vans = 0
	if vanTemplate and vanTemplate:IsA("Model") then
		local copy = vanTemplate:Clone()
		copy.Name = "Van"
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		copy.Parent = root
		vans = 1
	end

	-- X393: the dish, single mesh like Bus above.
	local oldDish = root:FindFirstChild("Dish")
	if oldDish then
		oldDish:Destroy()
	end
	local dishTemplate = kit and kit:FindFirstChild(ClientKit.DISH, true)
	local dishes = 0
	if dishTemplate and dishTemplate:IsA("Model") then
		local copy = dishTemplate:Clone()
		copy.Name = "Dish"
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
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
			copy.Parent = root
			dishes = 1
		else
			copy:Destroy()
		end
	end

	-- X394: the train carriage, single mesh, pivot already at its own centre.
	local oldCarriage = root:FindFirstChild("TrainCarriage")
	if oldCarriage then
		oldCarriage:Destroy()
	end
	local carriageTemplate = kit and kit:FindFirstChild(ClientKit.TRAIN_CARRIAGE, true)
	local carriages = 0
	if carriageTemplate and carriageTemplate:IsA("Model") then
		local copy = carriageTemplate:Clone()
		copy.Name = "TrainCarriage"
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		copy.Parent = root
		carriages = 1
	end
	return ("client kit: %d cars, %d bus, %d cruiser, %d bicycle, %d van, %d dish, %d train carriage"):format(count, buses, cruisers, bicycles, vans, dishes, carriages)
end

return ClientKit
