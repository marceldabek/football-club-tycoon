--!strict
-- Stallholders on the market square (backlog X178, RivermereCenter.png).
-- Client-only, like PlayAreaLife: a trader stands behind each MarketStall's
-- counter within NEAR of the camera, facing the shoppers (the stall's -Z),
-- with a slow idle sway. 4 parts each, gone on Quality "Low". The stall frame
-- is recovered from its Counter (SquareDresser.buildStall: counter centre at
-- (0, 1.6, -0.5) in the stall frame).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)

local NEAR = 200
local SKIN = { Color3.fromRGB(232, 190, 150), Color3.fromRGB(180, 130, 95), Color3.fromRGB(110, 78, 55) }
local APRONS = { Color3.fromRGB(40, 90, 60), Color3.fromRGB(120, 40, 40), Color3.fromRGB(40, 60, 110), Color3.fromRGB(200, 170, 110) }

type Holder = { parts: { BasePart }, offsets: { CFrame }, base: CFrame, phase: number }
local holders: { [Model]: Holder } = {}

local folder = Instance.new("Folder")
folder.Name = "StallHolders"
folder.Parent = workspace

local function part(name: string, size: Vector3, colour: Color3, ball: boolean?): BasePart
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
	if ball then
		p.Shape = Enum.PartType.Ball
		local face = Instance.new("Decal")
		face.Name = "Face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = p
	end
	p.Parent = folder
	return p
end

local function build(stall: Model, i: number): Holder?
	local counter = stall:FindFirstChild("Counter")
	if not (counter and counter:IsA("BasePart")) then
		return nil
	end
	-- stall frame at ground level; the trader stands just behind the counter
	local f = counter.CFrame * CFrame.new(0, -1.6, 0.5)
	-- lifted 1.3 (a step behind the counter, hidden by it) so head and
	-- shoulders show over the heaped produce
	local base = f * CFrame.new(0, 1.3, 1.75)
	local apron = APRONS[(i % #APRONS) + 1]
	local parts = {
		part("Legs", Vector3.new(1.2, 1.8, 0.6), Color3.fromRGB(40, 44, 60)),
		part("Torso", Vector3.new(1.6, 1.8, 0.8), Color3.fromRGB(235, 232, 225)),
		part("Apron", Vector3.new(1.4, 2.2, 0.1), apron),
		part("Head", Vector3.one, SKIN[(i % #SKIN) + 1], true),
	}
	local offsets = {
		CFrame.new(0, 0.9, 0),
		CFrame.new(0, 2.7, 0),
		CFrame.new(0, 2.2, -0.46), -- over the shirt front, facing the counter
		CFrame.new(0, 4.1, 0),
	}
	return { parts = parts, offsets = offsets, base = base, phase = i * 1.3 }
end

local function clear(h: Holder)
	for _, p in h.parts do
		p:Destroy()
	end
end

-- stalls found once and as they stream in (never a per-recheck town scan)
local stalls: { Model } = {}
local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "MarketStall" then
		table.insert(stalls, inst)
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local recheck = 0
local elapsed = 0

RunService.RenderStepped:Connect(function(dt: number)
	elapsed += dt
	recheck -= dt
	if recheck <= 0 then
		recheck = 1.5
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		local low = player:GetAttribute("Quality") == "Low"
		local seen: { [Model]: boolean } = {}
		for i = #stalls, 1, -1 do
			if not stalls[i].Parent then
				table.remove(stalls, i)
			end
		end
		if not low then
			for i, d in stalls do
				if d.Parent then
					local counter = d:FindFirstChild("Counter")
					if counter and counter:IsA("BasePart") and (counter.Position - cam).Magnitude < NEAR then
						seen[d] = true
						if not holders[d] then
							local h = build(d, i)
							if h then
								holders[d] = h
							end
						end
					end
				end
			end
		end
		for stall, h in holders do
			if not seen[stall] or not stall.Parent then
				clear(h)
				holders[stall] = nil
			end
		end
	end
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, h in holders do
		-- a slow look left and right along the counter
		local sway = CFrame.Angles(0, math.sin(elapsed * 0.4 + h.phase) * 0.35, 0)
		for k, p in h.parts do
			table.insert(moveParts, p)
			table.insert(moveCFrames, h.base * sway * h.offsets[k])
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
