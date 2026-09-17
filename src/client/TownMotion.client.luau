--!strict
-- Small motion in town (backlog F4.2): the nearest tree crowns sway in the
-- breeze, and a few birds wheel round the church spire and over the Lune
-- Bridge. Client-only: canopy offsets are local CFrame changes on parts the
-- server built (never replicated back), birds are local parts. Off on
-- Quality "Low". Maths in Shared.TownMotion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownMotion"))
local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local CROWN_NAMES = { Canopy = true, CanopyTop = true, CanopySide = true, Crown = true, CrownLobe = true }
local SWAY_BUDGET = 40 -- TEMP trees swaying at once on High
local SWAY_RADIUS = 160 -- TEMP studs from the camera
local REPICK_SECONDS = 1
local BIRD_RANGE = 700 -- TEMP: birds only exist when the camera is this close to their centre
local BIRDS_PER_FLOCK = 5

local function isLow(): boolean
	return player:GetAttribute("Quality") == "Low"
end

-- --------------------------------------------------------------- tree sway

type Tree = { parts: { BasePart }, base: { CFrame }, position: Vector3, phase: number, height: number }

local trees: { [Instance]: Tree } = {} -- keyed by the tree model
local swaying: { Tree } = {}

local function register(part: BasePart)
	local m = part.Parent
	if not m or not m:IsA("Model") then
		return
	end
	local tree = trees[m]
	if not tree then
		local pivot = m:GetPivot().Position
		tree = { parts = {}, base = {}, position = pivot, phase = TownMotion.phase(pivot), height = 1 }
		trees[m] = tree
		m.Destroying:Connect(function()
			trees[m] = nil
		end)
	end
	table.insert(tree.parts, part)
	table.insert(tree.base, part.CFrame)
end

local function consider(inst: Instance)
	if inst:IsA("BasePart") and CROWN_NAMES[inst.Name] then
		register(inst)
	end
end

for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)
town.DescendantRemoving:Connect(function(inst)
	if inst:IsA("BasePart") and CROWN_NAMES[inst.Name] then
		local m = inst.Parent
		local tree = m and trees[m]
		if tree then
			local i = table.find(tree.parts, inst)
			if i then
				table.remove(tree.parts, i)
				table.remove(tree.base, i)
			end
		end
	end
end)

local function restore(tree: Tree)
	for i, p in tree.parts do
		if p.Parent then
			p.CFrame = tree.base[i]
		end
	end
end

local function repick()
	for _, tree in swaying do
		restore(tree)
	end
	swaying = {}
	if isLow() then
		return
	end
	local cam = workspace.CurrentCamera.CFrame.Position
	local candidates = {}
	for _, tree in trees do
		local d = (tree.position - cam).Magnitude
		if d <= SWAY_RADIUS and #tree.parts > 0 then
			table.insert(candidates, { tree = tree, d = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(SWAY_BUDGET, #candidates) do
		table.insert(swaying, candidates[i].tree)
	end
end

-- --------------------------------------------------------------------- birds

type Bird = { body: BasePart, left: BasePart, right: BasePart }
type Flock = { centre: Vector3, height: number, birds: { Bird }? }

local function landmark(name: string): Vector3?
	for _, l in TownLayout.LANDMARKS do
		if l.name == name then
			return l.position
		end
	end
	return nil
end

local flocks: { Flock } = {}
local spire = landmark("Church Spire")
if spire then
	table.insert(flocks, { centre = spire, height = 95 })
end
local bridge = landmark("Lune Bridge")
if bridge then
	table.insert(flocks, { centre = bridge, height = 28 })
end

local birdFolder = Instance.new("Folder")
birdFolder.Name = "TownBirds"
birdFolder.Parent = workspace

local function birdPart(name: string, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = Color3.fromRGB(34, 34, 38)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = birdFolder
	return p
end

local function spawnFlock(flock: Flock)
	local birds = {}
	for _ = 1, BIRDS_PER_FLOCK do
		table.insert(birds, {
			body = birdPart("Bird", Vector3.new(0.35, 0.3, 0.9)),
			left = birdPart("Wing", Vector3.new(0.9, 0.08, 0.45)),
			right = birdPart("Wing", Vector3.new(0.9, 0.08, 0.45)),
		})
	end
	flock.birds = birds
end

local function clearFlock(flock: Flock)
	for _, b in flock.birds or {} do
		b.body:Destroy()
		b.left:Destroy()
		b.right:Destroy()
	end
	flock.birds = nil
end

local function updateFlocks(t: number)
	local cam = workspace.CurrentCamera.CFrame.Position
	local low = isLow()
	for _, flock in flocks do
		local near = not low and (Vector3.new(flock.centre.X, cam.Y, flock.centre.Z) - cam).Magnitude <= BIRD_RANGE
		if near and not flock.birds then
			spawnFlock(flock)
		elseif not near and flock.birds then
			clearFlock(flock)
		end
		for i, b in flock.birds or {} do
			local pos, dir = TownMotion.birdPosition(flock.centre, flock.height, i, BIRDS_PER_FLOCK, t)
			local cf = CFrame.lookAt(pos, pos + dir)
			local flap = TownMotion.flap(t, i)
			b.body.CFrame = cf
			b.left.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.55, 0, 0)
			b.right.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.55, 0, 0)
		end
	end
end

-- ---------------------------------------------------------------------- loop

local sinceRepick = REPICK_SECONDS
RunService.RenderStepped:Connect(function(dt: number)
	local t = os.clock()
	sinceRepick += dt
	if sinceRepick >= REPICK_SECONDS then
		sinceRepick = 0
		repick()
	end
	for _, tree in swaying do
		local offset = TownMotion.swayOffset(t, tree.phase)
		for i, p in tree.parts do
			if p.Parent then
				p.CFrame = tree.base[i] + offset
			end
		end
	end
	updateFlocks(t)
end)

player:GetAttributeChangedSignal("Quality"):Connect(function()
	sinceRepick = REPICK_SECONDS -- restore or pick again on the next frame
end)
