--!strict
-- People sitting on park benches (backlog X185, RivermereRiverside.png's
-- benches in use). Client-only, like CafeSitters: of the kit park benches
-- ("UKSP__ParkBenches__ParkBench01") within RADIUS of the camera, the nearest
-- MAX_BENCHES are considered and about half get one or two sitters, chosen
-- stably from the bench's position. Off on Quality "Low". Pose maths in
-- TownLifeMath.seatedFigureCFrames.
--
-- The kit bench is one MeshPart: its seat faces the model pivot's LookVector
-- and the seat top is about SEAT_Y above the pivot (ground level).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local BENCH_KIT = "UKSP__ParkBenches__ParkBench01"
local RADIUS = 200 -- TEMP
local MAX_BENCHES = 8 -- TEMP benches considered at once
local RECHECK = 2
local SEAT_Y = 1.45
local SEAT_Z = 0.15 -- seat centre forward of the pivot, towards the view
local SKIN = { Color3.fromRGB(230, 190, 150), Color3.fromRGB(190, 140, 100), Color3.fromRGB(120, 85, 60) }
local TOPS = { Color3.fromRGB(70, 110, 160), Color3.fromRGB(200, 200, 196), Color3.fromRGB(160, 60, 70), Color3.fromRGB(60, 120, 90), Color3.fromRGB(220, 170, 60) }
local TROUSERS = { Color3.fromRGB(40, 44, 60), Color3.fromRGB(80, 70, 60), Color3.fromRGB(30, 30, 34) }

local folder = Instance.new("Folder")
folder.Name = "BenchSitters"
folder.Parent = workspace

local benches: { [Model]: boolean } = {}
local seated: { [Model]: Model } = {}

local function consider(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("Kit") == BENCH_KIT then
		benches[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

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

-- nil when this bench stays empty
local function seatSitters(bench: Model): Model?
	local pivot = bench:GetPivot()
	local rng = Random.new(math.floor(math.abs(pivot.X) * 7 + math.abs(pivot.Z) * 13))
	if rng:NextNumber() < 0.5 then
		return nil
	end
	local spots = if rng:NextNumber() < 0.4 then { -1.6, 1.6 } else { rng:NextNumber(-1.8, 1.8) }
	local m = Instance.new("Model")
	m.Name = "Sitters"
	local F, S = TownLifeMath.FIGURE, TownLifeMath.SEATED
	local sizes = { F.torso, Vector3.one * F.head, S.thigh, S.thigh, S.shin, S.shin, F.arm, F.arm }
	local names = { "Torso", "Head", "ThighL", "ThighR", "ShinL", "ShinR", "ArmL", "ArmR" }
	for _, x in spots do
		-- seatedFigureCFrames wants -Z facing the view: the bench pivot's own -Z
		local seat = pivot * CFrame.new(x, SEAT_Y, -SEAT_Z)
		local skin = SKIN[rng:NextInteger(1, #SKIN)]
		local topColour = TOPS[rng:NextInteger(1, #TOPS)]
		local trousers = TROUSERS[rng:NextInteger(1, #TROUSERS)]
		local colours = { topColour, skin, trousers, trousers, trousers, trousers, topColour, topColour }
		for i, cf in TownLifeMath.seatedFigureCFrames(seat) do
			local p = newPart(names[i], sizes[i], cf, colours[i], m)
			if names[i] == "Head" then
				(p :: any).Shape = Enum.PartType.Ball
				local face = Instance.new("Decal")
				face.Name = "Face"
				face.Face = Enum.NormalId.Front
				face.Texture = "rbxasset://textures/face.png"
				face.Parent = p
			end
		end
	end
	m.Parent = folder
	return m
end

local empty: { [Model]: boolean } = {} -- benches already rolled empty

local function refresh()
	local low = player:GetAttribute("Quality") == "Low"
	local camera = workspace.CurrentCamera
	local cam = if camera then camera.CFrame.Position else Vector3.zero
	local ranked = {}
	if not low then
		for bench in benches do
			if not bench.Parent then
				benches[bench] = nil
			else
				local d = (bench:GetPivot().Position - cam).Magnitude
				if d <= RADIUS then
					table.insert(ranked, { bench = bench, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
	end
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(MAX_BENCHES, #ranked) do
		keep[ranked[i].bench] = true
	end
	for bench in empty do
		if not keep[bench] then
			empty[bench] = nil
		end
	end
	for bench, m in seated do
		if not keep[bench] then
			m:Destroy()
			seated[bench] = nil
		end
	end
	for bench in keep do
		if not seated[bench] and not empty[bench] then
			local m = seatSitters(bench)
			if m then
				seated[bench] = m
			else
				empty[bench] = true
			end
		end
	end
end

while true do
	refresh()
	task.wait(RECHECK)
end
