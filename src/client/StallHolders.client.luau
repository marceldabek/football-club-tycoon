--!strict
-- Stallholders on the market square (backlog X178, RivermereCenter.png).
-- Client-only, like PlayAreaLife: a trader stands behind each MarketStall's
-- counter within NEAR of the camera, facing the shoppers (the stall's -Z),
-- with a slow idle sway. A Townsfolk figure each (X371: no more block
-- people), gone on Quality "Low". The stall frame is recovered from its
-- Counter (SquareDresser.buildStall: counter centre at (0, 1.6, -0.5) in the
-- stall frame).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)
local Townsfolk = require(script.Parent:WaitForChild("Townsfolk"))

local NEAR = 200

type Holder = { fig: Townsfolk.Figure, base: CFrame, phase: number }
local holders: { [Model]: Holder } = {}

local folder = Instance.new("Folder")
folder.Name = "StallHolders"
folder.Parent = workspace

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
	local fig = Townsfolk.build(folder, {
		skin = Townsfolk.SKIN[(i % #Townsfolk.SKIN) + 1],
		shirt = Townsfolk.SHIRTS[(i % #Townsfolk.SHIRTS) + 1],
	})
	if not fig then
		return nil
	end
	Townsfolk.pose(fig, base, 0)
	return { fig = fig, base = base, phase = i * 1.3 }
end

local function clear(h: Holder)
	h.fig.model:Destroy()
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

local elapsed = 0
local recheck = 0

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
	for _, h in holders do
		-- a slow look left and right along the counter
		local sway = CFrame.Angles(0, math.sin(elapsed * 0.4 + h.phase) * 0.35, 0)
		Townsfolk.pose(h.fig, h.base * sway, 0)
	end
end)
