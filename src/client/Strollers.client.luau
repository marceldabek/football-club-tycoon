--!strict
-- Strollers where the road-pavement walkers never go (backlog X177 / X182).
-- Client-only, off on Quality "Low", 4 parts a figure:
--   square      SQUARE_WALKERS stroll a ring round the market square between
--               the planters and the stalls (RivermereCenter.png), within
--               SQUARE_NEAR of the camera
--   promenade   PROM_WALKERS walk up and down the riverside promenade
--               (RivermereRiverside.png) on the stretch nearest the camera,
--               within PROM_NEAR. The promenade is RiverDresser's "Promenade"
--               strips (10 studs each), chained into walks where they meet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLayout"))

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local SQUARE_WALKERS = 5
local SQUARE_RING = 30 -- SquareDresser: planters at 17, stalls at 43
local SQUARE_NEAR = 220
local PROM_WALKERS = 6
local PROM_NEAR = 300
local CHAIN_GAP = 12 -- promenade strips closer than this join one walk
local SPEED_MIN, SPEED_MAX = 3.5, 5.5

local SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }
local TOPS = { Color3.fromRGB(70, 110, 160), Color3.fromRGB(200, 200, 196), Color3.fromRGB(160, 60, 70), Color3.fromRGB(60, 120, 90), Color3.fromRGB(220, 170, 60), Color3.fromRGB(120, 90, 150) }
local TROUSERS = { Color3.fromRGB(40, 44, 60), Color3.fromRGB(80, 70, 60), Color3.fromRGB(30, 30, 34) }

local folder = Instance.new("Folder")
folder.Name = "Strollers"

local rng = Random.new()

local function part(name: string, size: Vector3, colour: Color3, face: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	if face then
		p.Shape = Enum.PartType.Ball
		local d = Instance.new("Decal")
		d.Name = "Face"
		d.Face = Enum.NormalId.Front
		d.Texture = "rbxasset://textures/face.png"
		d.Parent = p
	end
	p.Parent = folder
	return p
end

type Walker = { parts: { BasePart }, speed: number, dist: number, dir: number, lateral: number, phase: number }

local function newWalker(): Walker
	local top = TOPS[rng:NextInteger(1, #TOPS)]
	return {
		parts = {
			part("Legs", Vector3.new(1.2, 1.8, 0.6), TROUSERS[rng:NextInteger(1, #TROUSERS)]),
			part("Torso", Vector3.new(1.6, 1.8, 0.8), top),
			part("Head", Vector3.one, SKIN[rng:NextInteger(1, #SKIN)], true),
			part("Hair", Vector3.new(1.02, 0.3, 0.95), Color3.fromRGB(60, 44, 30):Lerp(Color3.fromRGB(200, 170, 110), rng:NextNumber() * 0.6)),
		},
		speed = rng:NextNumber(SPEED_MIN, SPEED_MAX),
		dist = rng:NextNumber(0, 1000),
		dir = if rng:NextNumber() < 0.5 then 1 else -1,
		lateral = rng:NextNumber(-2.5, 2.5),
		phase = rng:NextNumber(0, 10),
	}
end

local squareWalkers: { Walker } = {}
for _ = 1, SQUARE_WALKERS do
	table.insert(squareWalkers, newWalker())
end
local promWalkers: { Walker } = {}
for _ = 1, PROM_WALKERS do
	table.insert(promWalkers, newWalker())
end

-- the market square disc's top (TownBuilder Y.SQUARE)
local SQUARE_TOP = 0.25

-- promenade walks: chains of strip centres along the bank
type Walk = { points: { Vector3 }, lengths: { number }, total: number }
local walks: { Walk } = {}
local function rebuildWalks()
	table.clear(walks)
	local strips = {}
	for _, d in town:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Promenade" then
			table.insert(strips, d)
		end
	end
	table.sort(strips, function(a, b)
		return a.Position.X < b.Position.X
	end)
	local current: { Vector3 } = {}
	local function flush()
		if #current >= 3 then
			local lengths, total = {}, 0
			for i = 2, #current do
				local l = (current[i] - current[i - 1]).Magnitude
				table.insert(lengths, l)
				total += l
			end
			table.insert(walks, { points = current, lengths = lengths, total = total })
		end
		current = {}
	end
	for _, s in strips do
		local top = s.Position + Vector3.new(0, s.Size.Y / 2, 0)
		if #current > 0 and (top - current[#current]).Magnitude > CHAIN_GAP then
			flush()
		end
		table.insert(current, top)
	end
	flush()
end

local function pointOn(walk: Walk, d: number): (Vector3, Vector3)
	d = math.clamp(d, 0, walk.total)
	for i, l in walk.lengths do
		if d <= l or i == #walk.lengths then
			local a, b = walk.points[i], walk.points[i + 1]
			local dir = (b - a)
			local unit = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(1, 0, 0)
			return a + unit * math.min(d, l), unit
		end
		d -= l
	end
	return walk.points[1], Vector3.new(1, 0, 0)
end

local activeWalk: Walk? = nil
local squareOn = false
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local check = 0
local elapsed = 0
local walksBuilt = false
local nextWalkScan = 0 -- a full town scan, so at most every 20 s until found

local function pose(w: Walker, pos: Vector3, facing: Vector3)
	local bob = math.abs(math.sin((elapsed + w.phase) * 6)) * 0.12
	local root = CFrame.lookAt(pos, pos + Vector3.new(facing.X, 0, facing.Z)) * CFrame.new(0, bob, 0)
	table.insert(moveParts, w.parts[1])
	table.insert(moveCFrames, root * CFrame.new(0, 0.9, 0))
	table.insert(moveParts, w.parts[2])
	table.insert(moveCFrames, root * CFrame.new(0, 2.7, 0))
	table.insert(moveParts, w.parts[3])
	table.insert(moveCFrames, root * CFrame.new(0, 4.1, 0))
	table.insert(moveParts, w.parts[4])
	table.insert(moveCFrames, root * CFrame.new(0, 4.55, 0.05))
end

local function hide(list: { Walker })
	for _, w in list do
		for _, p in w.parts do
			p.CFrame = CFrame.new(0, -500, 0)
		end
	end
end
-- new parts start at the origin, which is the middle of the market square
hide(squareWalkers)
hide(promWalkers)

RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	check -= dt
	if check <= 0 then
		check = 2
		if not walksBuilt and elapsed >= nextWalkScan then
			nextWalkScan = elapsed + 20
			rebuildWalks()
			walksBuilt = #walks > 0
		end
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		local low = player:GetAttribute("Quality") == "Low"
		local sq = TownLayout.SQUARE.centre
		local wasSquare = squareOn
		squareOn = not low and Vector3.new(cam.X - sq.X, 0, cam.Z - sq.Z).Magnitude < SQUARE_NEAR
		if wasSquare and not squareOn then
			hide(squareWalkers)
		end
		local best: Walk? = nil
		local bestD = PROM_NEAR
		if not low then
			for _, walk in walks do
				for _, p in walk.points do
					local d = Vector3.new(p.X - cam.X, 0, p.Z - cam.Z).Magnitude
					if d < bestD then
						best, bestD = walk, d
					end
				end
			end
		end
		if best ~= activeWalk then
			activeWalk = best
			if best then
				for _, w in promWalkers do
					w.dist = rng:NextNumber(0, best.total)
				end
			else
				hide(promWalkers)
			end
		end
		folder.Parent = if squareOn or activeWalk then workspace else nil
	end
	if folder.Parent == nil then
		return
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
	if squareOn then
		local sq = TownLayout.SQUARE.centre
		for _, w in squareWalkers do
			w.dist += w.speed * dt
			local r = SQUARE_RING + w.lateral
			local angle = w.dir * w.dist / r
			local pos = Vector3.new(sq.X + math.cos(angle) * r, SQUARE_TOP, sq.Z + math.sin(angle) * r)
			local facing = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * w.dir
			pose(w, pos, facing)
		end
	end
	local walk = activeWalk
	if walk then
		for _, w in promWalkers do
			w.dist += w.speed * dt * w.dir
			if w.dist > walk.total then
				w.dist, w.dir = walk.total, -1
			elseif w.dist < 0 then
				w.dist, w.dir = 0, 1
			end
			local p, along = pointOn(walk, w.dist)
			local side = Vector3.new(-along.Z, 0, along.X)
			pose(w, p + side * w.lateral, along * w.dir)
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
