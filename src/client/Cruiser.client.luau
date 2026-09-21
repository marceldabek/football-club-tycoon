--!strict
-- A motor cruiser on the River Lune (backlog X150, RivermereRiverside.png). It
-- laps the straight reach between the swans and the marina along
-- Shared.TownLifeMath.cruiserPose, bobbing a little. Client-only: the kit
-- cruiser mesh plus a wake, moved with one BulkMoveTo, only while the camera is
-- within NEAR of the reach, and gone on Quality "Low". Bow to -Z, like
-- RiverDresser's moored boats.

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

-- the boat itself: the kit cabin cruiser published by the server's ClientKit
-- (pivot on the waterline, bow to -Z). No kit, no cruiser: never primitives.
local clientKit = ReplicatedStorage:WaitForChild("ClientKit", 10)
local template = clientKit and clientKit:WaitForChild("Cruiser", 10)
if not (template and template:IsA("Model")) then
	return
end
local boat = template:Clone()
local pivot = boat:GetPivot()
for _, d in boat:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		-- TownLifeMath.cruiserPose is the old hull centre; the water is 0.9 below it
		table.insert(offsets, CFrame.new(0, -0.9, 0) * pivot:ToObjectSpace(d.CFrame))
	end
end
boat.Parent = folder
-- a short white wash trailing the stern, flat on the water
local wake = Color3.fromRGB(235, 242, 245)
piece("Wake", Vector3.new(4, 0.05, 9), CFrame.new(0, -0.9, LENGTH / 2 + 4), wake)
parts[#parts].Transparency = 0.6 -- a faint wash, not a slab behind the mesh boat

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
