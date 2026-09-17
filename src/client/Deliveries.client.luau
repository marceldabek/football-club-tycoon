--!strict
-- Deliveries (roadmap F4, backlog X89): a white delivery van parks half on the
-- kerb outside a shop near the camera (the shops' A-boards mark the frontages),
-- rear doors open with a stack of parcels beside it, stays a while, then moves
-- to another shop. One van, client-only, off on Quality "Low". Kerb maths in
-- TownLifeMath.kerbsideSpot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))
local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local RADIUS = 260 -- TEMP studs from the camera
local STAY = 45 -- TEMP seconds at one shop
local VAN_WHITE = Color3.fromRGB(236, 238, 240)
local GLASS = Color3.fromRGB(40, 52, 64)
local TYRE = Color3.fromRGB(24, 24, 26)
local CARD = Color3.fromRGB(176, 140, 96)

local boards: { [Model]: boolean } = {}
local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "ABoard" then
		boards[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

local folder = Instance.new("Folder")
folder.Name = "Deliveries"
folder.Parent = workspace

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A van on the ground at `cf`, nose towards local -Z: 11 parts.
local function buildVan(cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "DeliveryVan"
	newPart(m, "Body", Vector3.new(6, 6.4, 11), cf * CFrame.new(0, 4.4, 2), VAN_WHITE, Enum.Material.SmoothPlastic)
	newPart(m, "Cab", Vector3.new(6, 4.4, 4.2), cf * CFrame.new(0, 3.4, -5.6), VAN_WHITE, Enum.Material.SmoothPlastic)
	newPart(m, "Windscreen", Vector3.new(5.4, 2, 0.2), cf * CFrame.new(0, 4.6, -7.75), GLASS, Enum.Material.Glass)
	local stripe = newPart(m, "Stripe", Vector3.new(6.1, 0.8, 10.6), cf * CFrame.new(0, 3.6, 2), Color3.fromRGB(28, 80, 150), Enum.Material.SmoothPlastic)
	stripe.CastShadow = false
	for _, z in { -5.2, 5.4 } do
		local wheels = newPart(m, "Wheels", Vector3.new(6.4, 2.2, 2.2), cf * CFrame.new(0, 1.1, z), TYRE, Enum.Material.SmoothPlastic)
		;(wheels :: any).Shape = Enum.PartType.Cylinder
	end
	-- rear doors swung open against the sides
	for _, side in { -1, 1 } do
		newPart(m, "RearDoor", Vector3.new(0.2, 5.8, 2.8), cf * CFrame.new(side * 3.15, 4.4, 8.9), VAN_WHITE, Enum.Material.SmoothPlastic)
	end
	-- parcels stacked on the pavement side behind the van
	newPart(m, "Parcel", Vector3.new(2.2, 1.6, 2.2), cf * CFrame.new(-4.6, 0.8, 9.6), CARD, Enum.Material.Cardboard)
	newPart(m, "Parcel", Vector3.new(1.6, 1.2, 1.6), cf * CFrame.new(-4.5, 2.2, 9.5), CARD, Enum.Material.Cardboard)
	newPart(m, "Parcel", Vector3.new(1.8, 1.4, 1.4), cf * CFrame.new(-4.6, 0.7, 12), CARD, Enum.Material.Cardboard)
	m.Parent = folder
	return m
end

local van: Model? = nil
local lastBoard: Model? = nil

local function move()
	if van then
		van:Destroy()
		van = nil
	end
	if player:GetAttribute("Quality") == "Low" then
		return
	end
	local cam = workspace.CurrentCamera.CFrame.Position
	local choices = {}
	for board in boards do
		if not board.Parent then
			boards[board] = nil
		elseif board ~= lastBoard then
			local pos = board:GetPivot().Position
			if (pos - cam).Magnitude <= RADIUS then
				table.insert(choices, board)
			end
		end
	end
	if #choices == 0 then
		return
	end
	local board = choices[math.random(1, #choices)]
	lastBoard = board
	local cf = TownLifeMath.kerbsideSpot(board:GetPivot().Position, TownLayout.ROADS)
	if cf then
		van = buildVan(cf)
	end
end

while true do
	move()
	task.wait(STAY)
end
