--!strict
-- The fans in the stands (#6), built on each client with the shared avatar rig
-- (Townsfolk) so they look like every other NPC in town.
--
-- The server picks the seats (WorldBuilder.buildCrowd) and publishes them as
-- a packed "Seats" attribute on each stand's Crowd folder (Shared.CrowdSeats).
-- This module watches those folders, builds a figure per seat -- within the
-- Quality budget, a few per frame so a filling ground never hitches -- and
-- tears them down when the seats go. A bigger share of the gate only adds
-- fans: seats already shown keep their figure.
--
-- Fans are static between reactions. StandCrowd.react makes one end hop (arms
-- up for a goal); one Heartbeat and one BulkMoveTo move everybody who is
-- mid-hop, then they settle back on their seats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CrowdSeats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrowdSeats"))
local Quality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quality"))
local Townsfolk = require(script.Parent:WaitForChild("Townsfolk"))

local StandCrowd = {}

-- ------------------------------------------------------------------ tuning

local NEAR_RADIUS = 700 -- TEMP: build a ground's fans once the camera is this close to it
local FAR_RADIUS = 800 -- ...and drop them past this (hysteresis)
local SCAN_INTERVAL = 1 -- seconds between looks for new/changed Crowd folders
local BUILD_PER_FRAME = 24 -- TEMP: figures cloned per frame while a ground fills

local HOP_PERIOD = 0.36 -- one up and down, as the old 0.18 s reversing tween
local HOP_COUNT = 3
local HOP_HEIGHT = 1.5

-- ------------------------------------------------------------------ state

type Fan = {
	fig: Townsfolk.Figure,
	base: CFrame,
	rest: { CFrame },
	hopAt: number?,
	hopSize: number,
}

type Stand = {
	crowd: Instance,
	text: string?, -- the Seats string last built from
	fans: { [number]: Fan }, -- by seat seed
	centre: Vector3?,
	near: boolean,
}

local stands: { [Instance]: Stand } = {}
local hopping: { Fan } = {}
local queue: { { stand: Stand, seat: CrowdSeats.Seat, drop: number } } = {}

local root = Instance.new("Folder")
root.Name = "StandCrowd"
root.Parent = workspace

local player = Players.LocalPlayer

local function budget(): number
	return Quality.budget(player and player:GetAttribute(Quality.ATTRIBUTE)).standFans
end

local function cameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function removeFan(fan: Fan)
	fan.fig.model:Destroy()
	fan.hopAt = nil
end

local function clearStand(stand: Stand)
	for seed, fan in stand.fans do
		removeFan(fan)
		stand.fans[seed] = nil
	end
	for i = #queue, 1, -1 do
		if queue[i].stand == stand then
			table.remove(queue, i)
		end
	end
	stand.text = nil
end

-- Diff the stand's published seats against the fans on screen.
local function syncStand(stand: Stand)
	local text = stand.crowd:GetAttribute("Seats")
	local want = if type(text) == "string" then text else ""
	if stand.text == want then
		return
	end
	stand.text = want
	local seats = CrowdSeats.decode(want)
	local drop = stand.crowd:GetAttribute("Drop")
	local dropN = if type(drop) == "number" then drop else CrowdSeats.SEAT_DROP
	if #seats > 0 then
		local sum = Vector3.zero
		for _, seat in seats do
			sum += seat.position
		end
		stand.centre = sum / #seats
	end
	local limit = budget()
	local keep: { [number]: CrowdSeats.Seat } = {}
	for _, seat in seats do
		if CrowdSeats.keep(seat.seed, limit) then
			keep[seat.seed] = seat
		end
	end
	for seed, fan in stand.fans do
		if not keep[seed] then
			removeFan(fan)
			stand.fans[seed] = nil
		end
	end
	for i = #queue, 1, -1 do
		local q = queue[i]
		if q.stand == stand and not keep[q.seat.seed] then
			table.remove(queue, i)
		end
	end
	if not stand.near then
		return
	end
	for seed, seat in keep do
		if not stand.fans[seed] then
			table.insert(queue, { stand = stand, seat = seat, drop = dropN })
		end
	end
end

local function buildQueued()
	if #queue == 0 then
		return
	end
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _ = 1, math.min(BUILD_PER_FRAME, #queue) do
		local q = table.remove(queue) :: any
		local stand: Stand, seat: CrowdSeats.Seat = q.stand, q.seat
		if stand.fans[seat.seed] or not stand.crowd.Parent then
			continue
		end
		local fig = Townsfolk.build(root, { shirt = seat.shirt, rng = Random.new(seat.seed) })
		if not fig then
			table.clear(queue) -- no avatar pipeline: no crowd, never blocks
			return
		end
		fig.model.Name = "Fan"
		for _, d in fig.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
		local base = CFrame.new(seat.position) * CFrame.Angles(0, seat.yaw, 0)
		local rest = Townsfolk.seatedCFrames(base, q.drop)
		stand.fans[seat.seed] = { fig = fig, base = base, rest = rest, hopAt = nil, hopSize = 1 }
		for i = 1, 6 do
			table.insert(parts, fig.all[i])
			table.insert(cframes, rest[i])
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function scan()
	local plots = workspace:FindFirstChild("Plots")
	local seen: { [Instance]: boolean } = {}
	if plots then
		for _, plot in plots:GetChildren() do
			local club = plot:FindFirstChild("Club")
			local standsFolder = club and club:FindFirstChild("Stands")
			if not standsFolder then
				continue
			end
			for _, standModel in standsFolder:GetChildren() do
				local crowd = standModel:FindFirstChild("Crowd")
				if crowd then
					seen[crowd] = true
					if not stands[crowd] then
						stands[crowd] = { crowd = crowd, text = nil, fans = {}, centre = nil, near = false }
					end
				end
			end
		end
	end
	local cam = cameraPosition()
	for crowd, stand in stands do
		if not seen[crowd] or crowd.Parent == nil then
			clearStand(stand)
			stands[crowd] = nil
			continue
		end
		local centre = stand.centre
		local wasNear = stand.near
		if centre then
			local d = (centre - cam).Magnitude
			stand.near = if stand.near then d <= FAR_RADIUS else d <= NEAR_RADIUS
		else
			stand.near = false -- no seats read yet; syncStand finds the centre, next scan decides
		end
		if wasNear and not stand.near then
			clearStand(stand)
		elseif stand.near and not wasNear then
			stand.text = nil -- rebuild from the current seats
		end
		syncStand(stand)
	end
end

-- ------------------------------------------------------------------ reactions

local function hopCFrames(fan: Fan, lift: number, arms: boolean): { CFrame }
	local up = CFrame.new(0, lift, 0)
	local out = table.create(6)
	for i = 1, 6 do
		out[i] = up * fan.rest[i]
	end
	if arms then
		-- arms straight up from the shoulders
		local halfArm = Townsfolk.ARM_SIZE.Y / 2
		local shoulder = Townsfolk.TORSO_SIZE.Y - 0.1
		local raised = CFrame.Angles(math.pi * 0.92, 0, 0) * CFrame.new(0, -halfArm, 0)
		out[5] = up * fan.base * CFrame.new(-Townsfolk.ARM_X, shoulder, 0) * CFrame.Angles(0, 0, -0.15) * raised
		out[6] = up * fan.base * CFrame.new(Townsfolk.ARM_X, shoulder, 0) * CFrame.Angles(0, 0, 0.15) * raised
	end
	return out
end

-- Lifts the fans of one end. `stands` is the ground's Stands folder; `away`
-- picks the visitors' end (X297) instead of the home stands; `size` scales the
-- hop (1 = a goal, with arms up); `share` is the fraction of seats that join
-- in (X344: small moments lift about a third).
function StandCrowd.react(standsFolder: Instance, away: boolean, size: number, share: number)
	local now = os.clock()
	for _, standModel in standsFolder:GetChildren() do
		local crowd = standModel:FindFirstChild("Crowd")
		local stand = crowd and stands[crowd]
		if not (stand and crowd) or (crowd:GetAttribute("AwayEnd") == true) ~= away then
			continue
		end
		for _, fan in stand.fans do
			if share < 1 and math.random() >= share then
				continue
			end
			if not fan.hopAt then
				table.insert(hopping, fan)
			end
			fan.hopAt = now + math.random() * 0.35
			fan.hopSize = size
		end
	end
end

-- How many fans are on screen (probes).
function StandCrowd.count(): number
	local n = 0
	for _, stand in stands do
		for _ in stand.fans do
			n += 1
		end
	end
	return n
end

local function stepHops()
	if #hopping == 0 then
		return
	end
	local now = os.clock()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for i = #hopping, 1, -1 do
		local fan = hopping[i]
		local at = fan.hopAt
		if not at or fan.fig.model.Parent == nil then
			table.remove(hopping, i)
			continue
		end
		local t = now - at
		if t < 0 then
			continue
		end
		local cfs
		if t >= HOP_PERIOD * HOP_COUNT then
			cfs = fan.rest
			fan.hopAt = nil
			table.remove(hopping, i)
		else
			local frac = (t % HOP_PERIOD) / HOP_PERIOD
			cfs = hopCFrames(fan, HOP_HEIGHT * fan.hopSize * math.sin(math.pi * frac), fan.hopSize >= 1)
		end
		for j = 1, 6 do
			table.insert(parts, fan.fig.all[j])
			table.insert(cframes, cfs[j])
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- ------------------------------------------------------------------ run

local started = false
function StandCrowd.start()
	if started then
		return
	end
	started = true
	Townsfolk.prewarm()
	local timer = SCAN_INTERVAL
	local lastBudget = budget()
	RunService.Heartbeat:Connect(function(dt: number)
		timer += dt
		if timer >= SCAN_INTERVAL then
			timer = 0
			local b = budget()
			if b ~= lastBudget then
				lastBudget = b
				for _, stand in stands do
					stand.text = nil -- Quality changed: re-pick within the new budget
				end
			end
			scan()
		end
		buildQueued()
		stepHops()
	end)
end

return StandCrowd
