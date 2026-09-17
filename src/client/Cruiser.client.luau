--!strict
-- A motor cruiser on the River Lune (backlog X150, RivermereRiverside.png). It
-- laps the straight reach between the swans and the marina along
-- Shared.TownLifeMath.cruiserPose, bobbing a little. Client-only: 7 parts moved
-- with one BulkMoveTo, only while the camera is within NEAR of the reach, and
-- gone on Quality "Low". Built like RiverDresser's moored boats (bow to -Z).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TownLifeMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownLifeMath"))

local player = Players.LocalPlayer
local NEAR = 600
local LENGTH = 20

local folder = Instance.new("Folder")
folder.Name = "Cruiser"

local parts: { BasePart } = {}
local offsets: { CFrame } = {}

local function piece(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material?, className: string?)
	local p = (Instance.new :: any)(className or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = folder
	table.insert(parts, p)
	table.insert(offsets, offset)
end

local hull = Color3.fromRGB(245, 245, 245)
piece("Hull", Vector3.new(6, 2.4, LENGTH), CFrame.new(0, 0.2, 0), hull)
piece("Bow", Vector3.new(6, 2.4, 5), CFrame.new(0, 0.2, -LENGTH / 2 - 2.5), hull, nil, "WedgePart")
piece("Stripe", Vector3.new(6.1, 0.4, LENGTH - 0.1), CFrame.new(0, 0.6, 0), Color3.fromRGB(24, 40, 78))
piece("Cabin", Vector3.new(4.6, 2.2, LENGTH * 0.35), CFrame.new(0, 2.5, -LENGTH * 0.1), Color3.fromRGB(240, 240, 235))
piece("Glass", Vector3.new(4.2, 1.2, 0.2), CFrame.new(0, 2.9, -LENGTH * 0.1 - LENGTH * 0.175 - 0.1), Color3.fromRGB(40, 60, 80), Enum.Material.Glass)
-- a short white wash trailing the stern, flat on the water
local wake = Color3.fromRGB(235, 242, 245)
piece("Wake", Vector3.new(5, 0.1, 6), CFrame.new(0, -0.05, LENGTH / 2 + 3), wake)
parts[#parts].Transparency = 0.35

local mid = (TownLifeMath.CRUISER_FROM + TownLifeMath.CRUISER_TO) / 2
local reach = (TownLifeMath.CRUISER_TO - TownLifeMath.CRUISER_FROM).Magnitude / 2

local moveCFrames: { CFrame } = table.create(#parts)
local checkTimer = 0
local visible = false

RunService.RenderStepped:Connect(function(dt: number)
	checkTimer -= dt
	if checkTimer <= 0 then
		checkTimer = 1
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		local want = camera ~= nil and player:GetAttribute("Quality") ~= "Low" and Vector3.new(cam.X - mid.X, 0, cam.Z - mid.Z).Magnitude < NEAR + reach
		if want ~= visible then
			visible = want
			folder.Parent = if visible then workspace else nil
		end
	end
	if not visible then
		return
	end
	local t = workspace:GetServerTimeNow()
	local pose = TownLifeMath.cruiserPose(t) * CFrame.new(0, math.sin(t * 1.1) * 0.08, 0) * CFrame.Angles(math.sin(t * 0.9) * 0.01, 0, 0)
	for i, offset in offsets do
		moveCFrames[i] = pose * offset
	end
	workspace:BulkMoveTo(parts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
