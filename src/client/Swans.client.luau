--!strict
-- Swans on the River Lune (backlog X111, RivermereRiverside.png). A pair at
-- each spot in Shared.TownLifeMath.SWAN_SPOTS glides slowly round an ellipse
-- on the water, half a lap apart. Client-only: 1 mesh (or 4 parts) a swan moved with one
-- BulkMoveTo, only while the camera is within NEAR of a spot, and gone on
-- Quality "Low".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TownLifeMath = require(Shared:WaitForChild("TownLifeMath"))

local player = Players.LocalPlayer
local NEAR = 500
local PER_SPOT = 2
local WHITE = Color3.fromRGB(246, 246, 242)
local BEAK = Color3.fromRGB(226, 120, 40)

local folder = Instance.new("Folder")
folder.Name = "Swans"

type Swan = { parts: { BasePart }, spot: number, phase: number }
local swans: { Swan } = {}

local function part(name: string, size: Vector3, colour: Color3, ball: boolean): BasePart
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
	end
	p.Parent = folder
	return p
end

-- X113: the free Creator Store "Swan" mesh (asset 15968285610, yiypoo1024;
-- ReplicatedStorage.ClientKit.Swan, place file only, MANIFEST) when it's there:
-- one MeshPart facing +Z, 4 long, sunk SWAN_SINK into the water. Without it,
-- the 4-part primitive swan below (body half in the water, neck rising from
-- the front, head on top, beak forward along -Z).
local SWAN_SINK = 0.6
local clientKit = ReplicatedStorage:WaitForChild("ClientKit", 5)
local swanModel = clientKit and clientKit:FindFirstChild("Swan")
local swanMesh = swanModel and swanModel:FindFirstChildWhichIsA("BasePart", true)

local OFFSETS: { CFrame }
if swanMesh then
	OFFSETS = { CFrame.new(0, swanMesh.Size.Y / 2 - SWAN_SINK, 0) * CFrame.Angles(0, math.pi, 0) }
else
	OFFSETS = {
		CFrame.new(0, 0.25, 0),
		CFrame.new(0, 1.3, -0.95),
		CFrame.new(0, 2.15, -1.05),
		CFrame.new(0, 2.1, -1.45),
	}
end

for i in TownLifeMath.SWAN_SPOTS do
	for k = 1, PER_SPOT do
		local parts: { BasePart }
		if swanMesh then
			local mesh = swanMesh:Clone()
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CastShadow = false
			mesh.Parent = folder
			parts = { mesh }
		else
			parts = {
				part("SwanBody", Vector3.new(1.8, 1.1, 2.6), WHITE, false),
				part("SwanNeck", Vector3.new(0.3, 1.6, 0.3), WHITE, false),
				part("SwanHead", Vector3.one * 0.55, WHITE, true),
				part("SwanBeak", Vector3.new(0.18, 0.18, 0.45), BEAK, false),
			}
		end
		table.insert(swans, { parts = parts, spot = i, phase = (k - 1) / PER_SPOT + i * 0.13 })
	end
end

local function near(camPos: Vector3): boolean
	for _, spot in TownLifeMath.SWAN_SPOTS do
		if (Vector3.new(camPos.X - spot.centre.X, 0, camPos.Z - spot.centre.Z)).Magnitude < NEAR then
			return true
		end
	end
	return false
end

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local checkTimer = 0
local visible = false

RunService.RenderStepped:Connect(function(dt: number)
	checkTimer -= dt
	if checkTimer <= 0 then
		checkTimer = 1
		local camera = workspace.CurrentCamera
		local want = camera ~= nil and player:GetAttribute("Quality") ~= "Low" and near(camera.CFrame.Position)
		if want ~= visible then
			visible = want
			folder.Parent = if visible then workspace else nil
		end
	end
	if not visible then
		return
	end
	local t = workspace:GetServerTimeNow()
	table.clear(moveParts)
	table.clear(moveCFrames)
	for _, swan in swans do
		local s = TownLifeMath.SWAN_SPOTS[swan.spot]
		local pose = TownLifeMath.swanPose(s.centre, s.along, s.a, s.b, s.period, swan.phase, t)
		local bob = CFrame.new(0, math.sin(t * 1.3 + swan.phase * 6) * 0.05, 0)
		for k, p in swan.parts do
			table.insert(moveParts, p)
			table.insert(moveCFrames, pose * bob * OFFSETS[k])
		end
	end
	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end)
