--!strict
-- Cafe sitters (roadmap F3, backlog F3.2): a few people sitting at the cafe
-- tables ForecourtDresser puts outside cafes and pubs, all day, near the
-- camera only. Client-only parts; off on Quality "Low". Pose maths in
-- TownLifeMath.seatedFigureCFrames.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local RADIUS = 200 -- TEMP studs from the camera
local MAX_SETS = 5 -- TEMP cafe sets with sitters at once
local RECHECK = 2 -- seconds
local SKIN = { Color3.fromRGB(230, 190, 150), Color3.fromRGB(190, 140, 100), Color3.fromRGB(120, 85, 60) }
local TOPS = {
	Color3.fromRGB(70, 110, 160),
	Color3.fromRGB(200, 200, 196),
	Color3.fromRGB(160, 60, 70),
	Color3.fromRGB(60, 120, 90),
	Color3.fromRGB(220, 170, 60),
}
local TROUSERS = { Color3.fromRGB(40, 44, 60), Color3.fromRGB(80, 70, 60), Color3.fromRGB(30, 30, 34) }

local folder = Instance.new("Folder")
folder.Name = "CafeSitters"
folder.Parent = workspace

local sets: { [Model]: boolean } = {}
local seated: { [Model]: Model } = {} -- cafe set -> its sitters

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "CafeSet" then
		sets[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)
town.DescendantRemoving:Connect(function(inst)
	if inst:IsA("Model") and inst.Name == "CafeSet" then
		sets[inst] = nil
		local m = seated[inst]
		if m then
			m:Destroy()
			seated[inst] = nil
		end
	end
end)

local function newPart(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function seatSitters(set: Model): Model?
	local table_ = set:FindFirstChild("TableTop")
	if not (table_ and table_:IsA("BasePart")) then
		return nil
	end
	local rng = Random.new(math.floor(table_.Position.X * 7 + table_.Position.Z * 13))
	local m = Instance.new("Model")
	m.Name = "Sitters"
	local F, S = TownLifeMath.FIGURE, TownLifeMath.SEATED
	local sizes = { F.torso, Vector3.one * F.head, S.thigh, S.thigh, S.shin, S.shin, F.arm, F.arm }
	local placed = 0
	for _, seatPart in set:GetChildren() do
		if not (seatPart:IsA("BasePart") and seatPart.Name == "Seat") then
			continue
		end
		-- one in three seats stays empty, but every set gets at least one person
		if placed > 0 and rng:NextNumber() < 0.34 then
			continue
		end
		local top = seatPart.Position + Vector3.new(0, seatPart.Size.Y / 2, 0)
		local toTable = Vector3.new(table_.Position.X - top.X, 0, table_.Position.Z - top.Z)
		if toTable.Magnitude < 1e-3 then
			continue
		end
		local seat = CFrame.lookAt(top, top + toTable.Unit)
		local cfs = TownLifeMath.seatedFigureCFrames(seat)
		local skin = SKIN[rng:NextInteger(1, #SKIN)]
		local topColour = TOPS[rng:NextInteger(1, #TOPS)]
		local trousers = TROUSERS[rng:NextInteger(1, #TROUSERS)]
		local colours = { topColour, skin, trousers, trousers, trousers, trousers, topColour, topColour }
		local names = { "Torso", "Head", "ThighL", "ThighR", "ShinL", "ShinR", "ArmL", "ArmR" }
		for i, cf in cfs do
			local p = newPart(names[i], sizes[i], cf, colours[i], m)
			if names[i] == "Head" then
				(p :: any).Shape = Enum.PartType.Ball
				-- X136: a face, like the other town figures
				local face = Instance.new("Decal")
				face.Name = "Face"
				face.Face = Enum.NormalId.Front
				face.Texture = "rbxasset://textures/face.png"
				face.Parent = p
			end
		end
		placed += 1
	end
	m.Parent = folder
	return m
end

local function refresh()
	local low = player:GetAttribute("Quality") == "Low"
	local cam = workspace.CurrentCamera.CFrame.Position
	local ranked = {}
	if not low then
		for set in sets do
			local t = set:FindFirstChild("TableTop")
			if set.Parent and t and t:IsA("BasePart") then
				local d = (t.Position - cam).Magnitude
				if d <= RADIUS then
					table.insert(ranked, { set = set, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
	end
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(MAX_SETS, #ranked) do
		keep[ranked[i].set] = true
	end
	for set, m in seated do
		if not keep[set] then
			m:Destroy()
			seated[set] = nil
		end
	end
	for set in keep do
		if not seated[set] then
			local m = seatSitters(set)
			if m then
				seated[set] = m
			end
		end
	end
end

while true do
	refresh()
	task.wait(RECHECK)
end
